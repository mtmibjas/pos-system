package api_test

import (
	"context"
	"path/filepath"
	"testing"
	"time"

	"connectrpc.com/connect"
	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/api"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/devices"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/users"
	"github.com/mibjas/pos-platform/packages/sdk-go/auth"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

const (
	authTenant = "tenant-A"
	authStore  = "store-1"
	authSecret = "auth-test-secret"
)

func newAuthHandler(t *testing.T) (*api.AuthHandler, *auth.Verifier) {
	t.Helper()
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "auth.db")
	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))

	userStore := users.NewStore(sqlDB)
	deviceStore := devices.NewStore(sqlDB)
	// Seed an owner (can register devices) and a plain cashier.
	require.NoError(t, userStore.Create(ctx, "owner@a", authTenant, "ownerpw", []string{"owner"}, "Shop Owner"))
	require.NoError(t, userStore.Create(ctx, "cash@a", authTenant, "cashpw", []string{"cashier"}, ""))

	issuer, err := auth.NewIssuer(authSecret, time.Hour)
	require.NoError(t, err)
	verifier, err := auth.NewVerifier(authSecret)
	require.NoError(t, err)

	h := api.NewAuthHandler(userStore, deviceStore, issuer, authTenant, authStore, nil)
	return h, verifier
}

func TestRegisterDevice_OwnerHappyPath(t *testing.T) {
	ctx := context.Background()
	h, _ := newAuthHandler(t)

	resp, err := h.RegisterDevice(ctx, connect.NewRequest(&posv1.RegisterDeviceRequest{
		ManagerUsername: "owner@a",
		ManagerPassword: "ownerpw",
		DeviceName:      "Front till",
	}))
	require.NoError(t, err)
	require.NotEmpty(t, resp.Msg.GetDeviceId())
	require.NotEmpty(t, resp.Msg.GetDeviceSecret())
	require.Equal(t, authStore, resp.Msg.GetStoreId())
	require.Equal(t, "counter-1", resp.Msg.GetCounterId())
}

func TestRegisterDevice_BadManagerPassword(t *testing.T) {
	ctx := context.Background()
	h, _ := newAuthHandler(t)

	_, err := h.RegisterDevice(ctx, connect.NewRequest(&posv1.RegisterDeviceRequest{
		ManagerUsername: "owner@a",
		ManagerPassword: "wrong",
		DeviceName:      "Front till",
	}))
	require.Equal(t, connect.CodeUnauthenticated, connect.CodeOf(err))
}

func TestRegisterDevice_NonOwnerDenied(t *testing.T) {
	ctx := context.Background()
	h, _ := newAuthHandler(t)

	_, err := h.RegisterDevice(ctx, connect.NewRequest(&posv1.RegisterDeviceRequest{
		ManagerUsername: "cash@a", // valid creds, but not an owner
		ManagerPassword: "cashpw",
		DeviceName:      "Front till",
	}))
	require.Equal(t, connect.CodePermissionDenied, connect.CodeOf(err))
}

func TestRegisterDevice_ReplaceUnknownCounter(t *testing.T) {
	ctx := context.Background()
	h, _ := newAuthHandler(t)

	_, err := h.RegisterDevice(ctx, connect.NewRequest(&posv1.RegisterDeviceRequest{
		ManagerUsername:  "owner@a",
		ManagerPassword:  "ownerpw",
		DeviceName:       "Replacement",
		ReplaceCounterId: "counter-9",
	}))
	require.Equal(t, connect.CodeNotFound, connect.CodeOf(err))
}

func TestLogin_HappyPath_MintsValidToken(t *testing.T) {
	ctx := context.Background()
	h, verifier := newAuthHandler(t)

	// Register a device first to get credentials.
	reg, err := h.RegisterDevice(ctx, connect.NewRequest(&posv1.RegisterDeviceRequest{
		ManagerUsername: "owner@a", ManagerPassword: "ownerpw", DeviceName: "Front till",
	}))
	require.NoError(t, err)

	// Cashier logs in on that device.
	resp, err := h.Login(ctx, connect.NewRequest(&posv1.LoginRequest{
		DeviceId:     reg.Msg.GetDeviceId(),
		DeviceSecret: reg.Msg.GetDeviceSecret(),
		Username:     "cash@a",
		Password:     "cashpw",
	}))
	require.NoError(t, err)
	require.NotEmpty(t, resp.Msg.GetAccessToken())
	require.Equal(t, []string{"cashier"}, resp.Msg.GetRoles())
	require.Equal(t, "cash@a", resp.Msg.GetUserDisplayName(), "empty display_name falls back to username")
	require.Equal(t, "counter-1", resp.Msg.GetCounterId())

	// The token must carry the identity claims the server will later trust.
	claims, err := verifier.Verify(resp.Msg.GetAccessToken())
	require.NoError(t, err)
	require.Equal(t, "cash@a", claims.Subject)
	require.Equal(t, authTenant, claims.TenantID)
	require.Equal(t, authStore, claims.StoreID)
	require.Equal(t, "counter-1", claims.CounterID)
	require.Equal(t, reg.Msg.GetDeviceId(), claims.DeviceID)
	require.True(t, claims.HasRole("cashier"))
}

func TestLogin_BadDeviceSecret(t *testing.T) {
	ctx := context.Background()
	h, _ := newAuthHandler(t)
	reg, err := h.RegisterDevice(ctx, connect.NewRequest(&posv1.RegisterDeviceRequest{
		ManagerUsername: "owner@a", ManagerPassword: "ownerpw", DeviceName: "Front till",
	}))
	require.NoError(t, err)

	_, err = h.Login(ctx, connect.NewRequest(&posv1.LoginRequest{
		DeviceId:     reg.Msg.GetDeviceId(),
		DeviceSecret: "tampered",
		Username:     "cash@a",
		Password:     "cashpw",
	}))
	require.Equal(t, connect.CodeUnauthenticated, connect.CodeOf(err))
}

func TestLogin_BadUserPassword(t *testing.T) {
	ctx := context.Background()
	h, _ := newAuthHandler(t)
	reg, err := h.RegisterDevice(ctx, connect.NewRequest(&posv1.RegisterDeviceRequest{
		ManagerUsername: "owner@a", ManagerPassword: "ownerpw", DeviceName: "Front till",
	}))
	require.NoError(t, err)

	_, err = h.Login(ctx, connect.NewRequest(&posv1.LoginRequest{
		DeviceId:     reg.Msg.GetDeviceId(),
		DeviceSecret: reg.Msg.GetDeviceSecret(),
		Username:     "cash@a",
		Password:     "wrong",
	}))
	require.Equal(t, connect.CodeUnauthenticated, connect.CodeOf(err))
}
