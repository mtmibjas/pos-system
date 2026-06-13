package invoices_test

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"path/filepath"
	"sort"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/proto"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/invoices"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

const testStore = "store-001"

func newStore(t *testing.T, tz *time.Location) (*invoices.Store, *sql.DB) {
	t.Helper()
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "inv.db")
	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))
	return invoices.NewStore(sqlDB, tz), sqlDB
}

func snapshot(saleID uuid.UUID) *posv1.SaleCreated {
	return &posv1.SaleCreated{
		SaleId:    saleID.String(),
		StoreId:   &posv1.StoreId{Value: testStore},
		Subtotal:  &posv1.Money{CurrencyCode: "USD", Units: 10},
		TaxTotal:  &posv1.Money{CurrencyCode: "USD"},
		GrandTotal: &posv1.Money{CurrencyCode: "USD", Units: 10},
	}
}

func issueReq(saleID uuid.UUID, finalizedAt time.Time) invoices.IssueRequest {
	return invoices.IssueRequest{
		InvoiceID:   uuid.New(),
		SaleID:      saleID,
		StoreID:     testStore,
		CounterID:   "counter-1",
		CashierID:   "user-1",
		Subtotal:    payments.Money{CurrencyCode: "USD", Units: 10},
		TaxTotal:    payments.Money{CurrencyCode: "USD"},
		GrandTotal:  payments.Money{CurrencyCode: "USD", Units: 10},
		Snapshot:    snapshot(saleID),
		FinalizedAt: finalizedAt,
	}
}

func TestIssue_HappyPath_AssignsNumberAndPersistsSnapshot(t *testing.T) {
	s, _ := newStore(t, time.UTC)
	saleID := uuid.New()
	occurredAt := time.Date(2026, 1, 15, 10, 0, 0, 0, time.UTC)

	inv, err := s.Issue(context.Background(), issueReq(saleID, occurredAt))
	require.NoError(t, err)
	require.Equal(t, "INV-2026-000001", inv.InvoiceNumber)
	require.NotEmpty(t, inv.Snapshot)
	require.NotEmpty(t, inv.SnapshotJSON)

	// Round-trip the proto snapshot.
	var got posv1.SaleCreated
	require.NoError(t, proto.Unmarshal(inv.Snapshot, &got))
	require.Equal(t, saleID.String(), got.SaleId)

	// Fetch by both keys.
	byID, err := s.Get(context.Background(), inv.InvoiceID)
	require.NoError(t, err)
	require.Equal(t, inv.InvoiceNumber, byID.InvoiceNumber)

	bySale, err := s.GetBySale(context.Background(), saleID)
	require.NoError(t, err)
	require.Equal(t, inv.InvoiceID, bySale.InvoiceID)
}

func TestIssue_DuplicateSale_ReturnsErrAlreadyIssued(t *testing.T) {
	s, _ := newStore(t, time.UTC)
	saleID := uuid.New()
	occurredAt := time.Date(2026, 1, 15, 10, 0, 0, 0, time.UTC)

	_, err := s.Issue(context.Background(), issueReq(saleID, occurredAt))
	require.NoError(t, err)

	_, err = s.Issue(context.Background(), issueReq(saleID, occurredAt))
	require.ErrorIs(t, err, invoices.ErrAlreadyIssued)
}

func TestIssue_ValidationErrors(t *testing.T) {
	s, _ := newStore(t, time.UTC)
	base := func() invoices.IssueRequest { return issueReq(uuid.New(), time.Now().UTC()) }
	cases := []struct {
		name string
		mut  func(*invoices.IssueRequest)
	}{
		{"missing InvoiceID", func(r *invoices.IssueRequest) { r.InvoiceID = uuid.Nil }},
		{"missing SaleID", func(r *invoices.IssueRequest) { r.SaleID = uuid.Nil }},
		{"missing StoreID", func(r *invoices.IssueRequest) { r.StoreID = "" }},
		{"missing FinalizedAt", func(r *invoices.IssueRequest) { r.FinalizedAt = time.Time{} }},
		{"missing Snapshot", func(r *invoices.IssueRequest) { r.Snapshot = nil }},
		{"missing currency", func(r *invoices.IssueRequest) { r.GrandTotal.CurrencyCode = "" }},
		{"mixed currency", func(r *invoices.IssueRequest) { r.TaxTotal.CurrencyCode = "EUR" }},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			req := base()
			c.mut(&req)
			_, err := s.Issue(context.Background(), req)
			require.Error(t, err)
		})
	}
}

func TestIssue_SequenceIsGaplessUnderConcurrency(t *testing.T) {
	s, _ := newStore(t, time.UTC)
	const N = 25
	occurredAt := time.Date(2026, 3, 1, 12, 0, 0, 0, time.UTC)

	var wg sync.WaitGroup
	numbers := make(chan string, N)
	errs := make(chan error, N)

	for i := 0; i < N; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			inv, err := s.Issue(context.Background(), issueReq(uuid.New(), occurredAt))
			if err != nil {
				errs <- err
				return
			}
			numbers <- inv.InvoiceNumber
		}()
	}
	wg.Wait()
	close(numbers)
	close(errs)

	for err := range errs {
		t.Fatalf("concurrent Issue failed: %v", err)
	}

	got := make([]string, 0, N)
	for n := range numbers {
		got = append(got, n)
	}
	require.Len(t, got, N)
	sort.Strings(got)
	for i, n := range got {
		require.Equal(t, fmt.Sprintf("INV-2026-%06d", i+1), n)
	}
}

func TestIssue_SequencePerStoreIndependent(t *testing.T) {
	s, _ := newStore(t, time.UTC)
	occurredAt := time.Date(2026, 5, 10, 9, 0, 0, 0, time.UTC)

	a1, err := s.Issue(context.Background(), withStore(issueReq(uuid.New(), occurredAt), "store-A"))
	require.NoError(t, err)
	a2, err := s.Issue(context.Background(), withStore(issueReq(uuid.New(), occurredAt), "store-A"))
	require.NoError(t, err)
	b1, err := s.Issue(context.Background(), withStore(issueReq(uuid.New(), occurredAt), "store-B"))
	require.NoError(t, err)

	require.Equal(t, "INV-2026-000001", a1.InvoiceNumber)
	require.Equal(t, "INV-2026-000002", a2.InvoiceNumber)
	require.Equal(t, "INV-2026-000001", b1.InvoiceNumber, "store-B has its own sequence")
}

func TestIssue_YearBoundary_UsesStoreTimezone(t *testing.T) {
	// Use IST (UTC+5:30). A UTC instant at 2025-12-31 20:00 is already
	// 2026-01-01 01:30 IST, so the invoice belongs to series 2026.
	ist, err := time.LoadLocation("Asia/Kolkata")
	require.NoError(t, err)
	s, _ := newStore(t, ist)

	utcInstant := time.Date(2025, 12, 31, 20, 0, 0, 0, time.UTC)
	inv, err := s.Issue(context.Background(), issueReq(uuid.New(), utcInstant))
	require.NoError(t, err)
	require.Equal(t, "INV-2026-000001", inv.InvoiceNumber)

	// And a 2025-year invoice using the same store but an earlier instant
	// that is still in 2025 in IST.
	earlier := time.Date(2025, 12, 30, 12, 0, 0, 0, time.UTC) // 17:30 IST same day
	inv2, err := s.Issue(context.Background(), issueReq(uuid.New(), earlier))
	require.NoError(t, err)
	require.Equal(t, "INV-2025-000001", inv2.InvoiceNumber, "year buckets are independent")
}

func TestList_FilterByStoreAndDateRange(t *testing.T) {
	s, _ := newStore(t, time.UTC)
	base := time.Date(2026, 4, 1, 9, 0, 0, 0, time.UTC)

	// 3 invoices for store-A, 1 for store-B.
	for i := 0; i < 3; i++ {
		_, err := s.Issue(context.Background(), withStore(issueReq(uuid.New(), base.Add(time.Duration(i)*time.Hour)), "store-A"))
		require.NoError(t, err)
	}
	_, err := s.Issue(context.Background(), withStore(issueReq(uuid.New(), base), "store-B"))
	require.NoError(t, err)

	out, err := s.List(context.Background(), invoices.ListFilter{StoreID: "store-A"})
	require.NoError(t, err)
	require.Len(t, out, 3)
	// Most-recent first.
	for i := 1; i < len(out); i++ {
		require.True(t, out[i-1].FinalizedAt.After(out[i].FinalizedAt) ||
			out[i-1].FinalizedAt.Equal(out[i].FinalizedAt))
	}

	limited, err := s.List(context.Background(), invoices.ListFilter{StoreID: "store-A", Limit: 2})
	require.NoError(t, err)
	require.Len(t, limited, 2)

	ranged, err := s.List(context.Background(), invoices.ListFilter{
		StoreID: "store-A",
		Since:   base.Add(30 * time.Minute),
		Until:   base.Add(2*time.Hour + 30*time.Minute),
	})
	require.NoError(t, err)
	require.Len(t, ranged, 2)
}

func TestGet_NotFound(t *testing.T) {
	s, _ := newStore(t, time.UTC)
	_, err := s.Get(context.Background(), uuid.New())
	require.True(t, errors.Is(err, invoices.ErrNotFound))
	_, err = s.GetBySale(context.Background(), uuid.New())
	require.True(t, errors.Is(err, invoices.ErrNotFound))
}

func withStore(r invoices.IssueRequest, store string) invoices.IssueRequest {
	r.StoreID = store
	return r
}
