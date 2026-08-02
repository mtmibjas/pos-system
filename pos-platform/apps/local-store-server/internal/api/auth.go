package api

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"log/slog"

	"connectrpc.com/connect"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/devices"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/users"
	"github.com/mibjas/pos-platform/packages/sdk-go/auth"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
	"github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1/posv1connect"
)

// AuthHandler implements posv1connect.AuthServiceHandler — the terminal's
// door into the store server. See docs/store-server-auth-contract.md.
//
// Both procedures are UNAUTHENTICATED (the auth interceptor exempts them):
// RegisterDevice gates on the manager's own credentials + owner role; Login
// gates on the device credential + user credentials.
//
// tenantID and storeID are pinned from server config — a device is always
// registered to THIS store/tenant, never to whatever a client claims.
type AuthHandler struct {
	posv1connect.UnimplementedAuthServiceHandler

	users    *users.Store
	devices  *devices.Store
	issuer   *auth.Issuer
	tenantID string
	storeID  string
	logger   *slog.Logger
}

// NewAuthHandler wires the handler. All deps are required — a nil dep is a
// boot-time wiring bug, so we panic rather than nil-guard per call.
func NewAuthHandler(u *users.Store, d *devices.Store, issuer *auth.Issuer, tenantID, storeID string, logger *slog.Logger) *AuthHandler {
	switch {
	case u == nil || d == nil || issuer == nil:
		panic("api: NewAuthHandler requires users, devices, and issuer")
	case tenantID == "" || storeID == "":
		panic("api: NewAuthHandler requires tenantID and storeID")
	}
	if logger == nil {
		logger = slog.Default()
	}
	return &AuthHandler{
		users: u, devices: d, issuer: issuer,
		tenantID: tenantID, storeID: storeID, logger: logger,
	}
}

// errInvalidCredentials is the single generic credential failure surfaced to
// clients (same wording for every cause → no enumeration).
var errInvalidCredentials = errors.New("invalid credentials")

// RegisterDevice provisions this terminal after verifying the manager.
func (h *AuthHandler) RegisterDevice(
	ctx context.Context,
	req *connect.Request[posv1.RegisterDeviceRequest],
) (*connect.Response[posv1.RegisterDeviceResponse], error) {
	in := req.Msg

	mgr, err := h.users.Authenticate(ctx, in.GetManagerUsername(), in.GetManagerPassword())
	if err != nil {
		// Log username only — never the password, never the cause.
		h.logger.Warn("auth: device registration failed: bad manager credentials",
			"username", in.GetManagerUsername())
		return nil, connect.NewError(connect.CodeUnauthenticated, errInvalidCredentials)
	}
	if !mgr.HasRole(auth.RoleOwner) {
		h.logger.Warn("auth: device registration denied: not owner",
			"username", mgr.Username, "roles", mgr.Roles)
		return nil, connect.NewError(connect.CodePermissionDenied, errors.New("owner role required"))
	}

	deviceID := uuid.NewString()
	secret, err := newDeviceSecret()
	if err != nil {
		h.logger.Error("auth: mint device secret", "err", err)
		return nil, connect.NewError(connect.CodeInternal, errors.New("could not register device"))
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(secret), bcrypt.DefaultCost)
	if err != nil {
		h.logger.Error("auth: hash device secret", "err", err)
		return nil, connect.NewError(connect.CodeInternal, errors.New("could not register device"))
	}

	dev, err := h.devices.Register(ctx, devices.RegisterParams{
		DeviceID:         deviceID,
		TenantID:         h.tenantID,
		StoreID:          h.storeID,
		DeviceName:       in.GetDeviceName(),
		SecretBcryptHash: string(hash),
		RegisteredBy:     mgr.Username,
		ReplaceCounterID: in.GetReplaceCounterId(),
	})
	if errors.Is(err, devices.ErrCounterNotFound) {
		return nil, connect.NewError(connect.CodeNotFound,
			fmt.Errorf("no active device on counter %q to replace", in.GetReplaceCounterId()))
	}
	if err != nil {
		h.logger.Error("auth: register device", "err", err)
		return nil, connect.NewError(connect.CodeInternal, errors.New("could not register device"))
	}

	h.logger.Info("auth: device registered",
		"device_id", dev.DeviceID, "counter_id", dev.CounterID,
		"registered_by", mgr.Username, "replaced", in.GetReplaceCounterId() != "")

	return connect.NewResponse(&posv1.RegisterDeviceResponse{
		DeviceId:     dev.DeviceID,
		DeviceSecret: secret, // returned ONCE; server kept only the hash
		StoreId:      dev.StoreID,
		CounterId:    dev.CounterID,
	}), nil
}

// Login validates the device + user and mints a session token.
func (h *AuthHandler) Login(
	ctx context.Context,
	req *connect.Request[posv1.LoginRequest],
) (*connect.Response[posv1.LoginResponse], error) {
	in := req.Msg

	dev, err := h.devices.Authenticate(ctx, in.GetDeviceId(), in.GetDeviceSecret())
	if err != nil {
		h.logger.Warn("auth: login failed: bad device credential", "device_id", in.GetDeviceId())
		return nil, connect.NewError(connect.CodeUnauthenticated, errInvalidCredentials)
	}

	u, err := h.users.Authenticate(ctx, in.GetUsername(), in.GetPassword())
	if err != nil {
		h.logger.Warn("auth: login failed: bad user credentials",
			"username", in.GetUsername(), "device_id", in.GetDeviceId())
		return nil, connect.NewError(connect.CodeUnauthenticated, errInvalidCredentials)
	}

	displayName := u.DisplayName
	if displayName == "" {
		displayName = u.Username
	}

	token, exp, err := h.issuer.Mint(auth.Claims{
		TenantID:  u.TenantID,
		Subject:   u.Username,
		Issuer:    "local-store-server",
		Roles:     u.Roles,
		StoreID:   dev.StoreID,
		CounterID: dev.CounterID,
		DeviceID:  dev.DeviceID,
	})
	if err != nil {
		h.logger.Error("auth: mint session token", "err", err, "username", u.Username)
		return nil, connect.NewError(connect.CodeInternal, errors.New("could not issue token"))
	}

	h.logger.Info("auth: login ok",
		"username", u.Username, "roles", u.Roles,
		"counter_id", dev.CounterID, "device_id", dev.DeviceID, "exp", exp)

	return connect.NewResponse(&posv1.LoginResponse{
		AccessToken:     token,
		ExpiresAt:       timestamppb.New(exp),
		TenantId:        u.TenantID,
		Roles:           u.Roles,
		UserDisplayName: displayName,
		StoreId:         dev.StoreID,
		CounterId:       dev.CounterID,
	}), nil
}

// newDeviceSecret returns a 32-byte cryptographically-random secret,
// base64url-encoded. Returned to the terminal once; only its hash persists.
func newDeviceSecret() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}
