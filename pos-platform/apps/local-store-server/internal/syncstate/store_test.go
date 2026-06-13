package syncstate_test

import (
	"context"
	"path/filepath"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/syncstate"
)

func newTestStore(t *testing.T) *syncstate.Store {
	t.Helper()
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "sync.db")
	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))
	return syncstate.NewStore(sqlDB)
}

func TestSetGet_RoundTrip(t *testing.T) {
	s := newTestStore(t)
	ctx := context.Background()
	require.NoError(t, s.Set(ctx, "foo", "bar"))
	got, err := s.Get(ctx, "foo")
	require.NoError(t, err)
	require.Equal(t, "bar", got)
}

func TestSet_Upsert(t *testing.T) {
	s := newTestStore(t)
	ctx := context.Background()
	require.NoError(t, s.Set(ctx, "k", "v1"))
	require.NoError(t, s.Set(ctx, "k", "v2"))
	got, _ := s.Get(ctx, "k")
	require.Equal(t, "v2", got)
}

func TestGet_NotFound(t *testing.T) {
	s := newTestStore(t)
	_, err := s.Get(context.Background(), "never-written")
	require.ErrorIs(t, err, syncstate.ErrNotFound)
}

func TestTypedRoundTrips(t *testing.T) {
	s := newTestStore(t)
	ctx := context.Background()

	// Time
	now := time.Now().UTC().Truncate(time.Nanosecond)
	require.NoError(t, s.SetTime(ctx, syncstate.KeyLastSyncAt, now))
	gotT, err := s.GetTime(ctx, syncstate.KeyLastSyncAt)
	require.NoError(t, err)
	require.Equal(t, now.UnixNano(), gotT.UnixNano())

	// Uint64
	require.NoError(t, s.SetUint64(ctx, syncstate.KeyNextLamport, 42))
	gotU, err := s.GetUint64(ctx, syncstate.KeyNextLamport)
	require.NoError(t, err)
	require.Equal(t, uint64(42), gotU)

	// UUID
	id := uuid.New()
	require.NoError(t, s.SetUUID(ctx, syncstate.KeyLastSyncBatchID, id))
	gotID, err := s.GetUUID(ctx, syncstate.KeyLastSyncBatchID)
	require.NoError(t, err)
	require.Equal(t, id, gotID)
}

func TestSet_EmptyKey(t *testing.T) {
	s := newTestStore(t)
	require.Error(t, s.Set(context.Background(), "", "v"))
}
