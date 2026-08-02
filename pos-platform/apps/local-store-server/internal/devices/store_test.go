package devices_test

import (
	"context"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
	"golang.org/x/crypto/bcrypt"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/devices"
)

const (
	testTenant = "tenant-A"
	testStore  = "store-1"
)

func newStore(t *testing.T) *devices.Store {
	t.Helper()
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "devices.db")
	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))
	return devices.NewStore(sqlDB)
}

// register is the test stand-in for the service layer: hash the secret and
// insert. Returns the registered Device.
func register(t *testing.T, store *devices.Store, deviceID, secret, name, replaceCounter string) devices.Device {
	t.Helper()
	hash, err := bcrypt.GenerateFromPassword([]byte(secret), bcrypt.MinCost) // MinCost: tests are fast
	require.NoError(t, err)
	d, err := store.Register(context.Background(), devices.RegisterParams{
		DeviceID:         deviceID,
		TenantID:         testTenant,
		StoreID:          testStore,
		DeviceName:       name,
		SecretBcryptHash: string(hash),
		RegisteredBy:     "owner@a",
		ReplaceCounterID: replaceCounter,
	})
	require.NoError(t, err)
	return d
}

func TestRegister_AssignsSequentialCounters(t *testing.T) {
	store := newStore(t)

	d1 := register(t, store, "dev-1", "secret-1", "Front till", "")
	require.Equal(t, "counter-1", d1.CounterID)
	require.Equal(t, testStore, d1.StoreID)

	d2 := register(t, store, "dev-2", "secret-2", "Back till", "")
	require.Equal(t, "counter-2", d2.CounterID)
}

func TestAuthenticate_Success(t *testing.T) {
	ctx := context.Background()
	store := newStore(t)
	register(t, store, "dev-1", "topsecret", "Front till", "")

	d, err := store.Authenticate(ctx, "dev-1", "topsecret")
	require.NoError(t, err)
	require.Equal(t, "dev-1", d.DeviceID)
	require.Equal(t, "counter-1", d.CounterID)
	require.Equal(t, testTenant, d.TenantID)
	require.False(t, d.LastSeenAt.IsZero(), "Authenticate should stamp last_seen_at")
}

func TestAuthenticate_WrongSecret(t *testing.T) {
	ctx := context.Background()
	store := newStore(t)
	register(t, store, "dev-1", "topsecret", "Front till", "")

	_, err := store.Authenticate(ctx, "dev-1", "wrong")
	require.ErrorIs(t, err, devices.ErrInvalidDevice)
}

func TestAuthenticate_UnknownDevice(t *testing.T) {
	store := newStore(t)
	_, err := store.Authenticate(context.Background(), "ghost", "whatever")
	require.ErrorIs(t, err, devices.ErrInvalidDevice)
}

func TestRegister_ReplaceRevokesOldAndReusesCounter(t *testing.T) {
	ctx := context.Background()
	store := newStore(t)

	old := register(t, store, "dev-old", "old-secret", "Front till", "")
	require.Equal(t, "counter-1", old.CounterID)

	// Replace the till on counter-1.
	newDev := register(t, store, "dev-new", "new-secret", "Front till v2", "counter-1")
	require.Equal(t, "counter-1", newDev.CounterID, "replacement reuses the counter_id")

	// Old device is revoked → can no longer authenticate.
	_, err := store.Authenticate(ctx, "dev-old", "old-secret")
	require.ErrorIs(t, err, devices.ErrInvalidDevice, "replaced device must be revoked")

	// New device works.
	_, err = store.Authenticate(ctx, "dev-new", "new-secret")
	require.NoError(t, err)

	// A subsequent NEW registration gets counter-2 (replace did not consume
	// a fresh counter number).
	d3 := register(t, store, "dev-3", "s3", "Third till", "")
	require.Equal(t, "counter-2", d3.CounterID)
}

func TestRegister_ReplaceUnknownCounter(t *testing.T) {
	store := newStore(t)
	hash, err := bcrypt.GenerateFromPassword([]byte("s"), bcrypt.MinCost)
	require.NoError(t, err)

	_, err = store.Register(context.Background(), devices.RegisterParams{
		DeviceID:         "dev-x",
		TenantID:         testTenant,
		StoreID:          testStore,
		DeviceName:       "Nowhere",
		SecretBcryptHash: string(hash),
		RegisteredBy:     "owner@a",
		ReplaceCounterID: "counter-9", // no active device here
	})
	require.ErrorIs(t, err, devices.ErrCounterNotFound)
}
