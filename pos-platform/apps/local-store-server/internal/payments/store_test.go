package payments_test

import (
	"context"
	"database/sql"
	"errors"
	"path/filepath"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
)

func newTestStore(t *testing.T) (*payments.Store, *sql.DB) {
	t.Helper()
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "pay.db")
	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))
	return payments.NewStore(sqlDB), sqlDB
}

func newPayment(sale uuid.UUID, units int64, nanos int32) payments.Payment {
	return payments.Payment{
		PaymentID: uuid.New(),
		SaleID:    sale,
		Method:    payments.MethodCash,
		Amount:    payments.Money{CurrencyCode: "USD", Units: units, Nanos: nanos},
		CreatedAt: time.Now().UTC(),
	}
}

func TestMoney_Validate(t *testing.T) {
	cases := []struct {
		name string
		m    payments.Money
		ok   bool
	}{
		{"valid positive", payments.Money{"USD", 1, 500_000_000}, true},
		{"valid negative", payments.Money{"USD", -1, -500_000_000}, true},
		{"valid zero-units negative-nanos", payments.Money{"USD", 0, -250_000_000}, true},
		{"valid positive-units zero-nanos", payments.Money{"USD", 5, 0}, true},
		{"missing currency", payments.Money{"", 1, 0}, false},
		{"nanos out of range high", payments.Money{"USD", 0, 1_000_000_000}, false},
		{"nanos out of range low", payments.Money{"USD", 0, -1_000_000_000}, false},
		{"mixed signs positive units", payments.Money{"USD", 1, -1}, false},
		{"mixed signs negative units", payments.Money{"USD", -1, 1}, false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			err := c.m.Validate()
			if c.ok {
				require.NoError(t, err)
			} else {
				require.Error(t, err)
			}
		})
	}
}

func TestMoney_Add(t *testing.T) {
	t.Run("simple", func(t *testing.T) {
		a := payments.Money{"USD", 1, 500_000_000} // 1.50
		b := payments.Money{"USD", 2, 250_000_000} // 2.25
		got, err := a.Add(b)
		require.NoError(t, err)
		require.Equal(t, payments.Money{"USD", 3, 750_000_000}, got)
	})
	t.Run("carry", func(t *testing.T) {
		a := payments.Money{"USD", 0, 700_000_000}
		b := payments.Money{"USD", 0, 500_000_000}
		got, err := a.Add(b)
		require.NoError(t, err)
		require.Equal(t, payments.Money{"USD", 1, 200_000_000}, got)
	})
	t.Run("subtract with borrow", func(t *testing.T) {
		a := payments.Money{"USD", 5, 0}
		b := payments.Money{"USD", -1, -500_000_000} // -1.50
		got, err := a.Add(b)
		require.NoError(t, err)
		require.Equal(t, payments.Money{"USD", 3, 500_000_000}, got)
	})
	t.Run("currency mismatch", func(t *testing.T) {
		_, err := payments.Money{"USD", 1, 0}.Add(payments.Money{"EUR", 1, 0})
		require.Error(t, err)
	})
}

func TestMoney_Equal(t *testing.T) {
	a := payments.Money{"USD", 1, 500_000_000}
	require.True(t, a.Equal(payments.Money{"USD", 1, 500_000_000}))
	require.False(t, a.Equal(payments.Money{"USD", 1, 500_000_001}), "nanos differ")
	require.False(t, a.Equal(payments.Money{"EUR", 1, 500_000_000}), "currency differs")
	// Zero values with different currencies are NOT equal — currency is part of the value.
	require.False(t, payments.Money{"USD", 0, 0}.Equal(payments.Money{"EUR", 0, 0}))
}

func TestMoney_Mul(t *testing.T) {
	t.Run("integer scaling", func(t *testing.T) {
		// $1.50 * 3 = $4.50
		got, err := payments.Money{"USD", 1, 500_000_000}.Mul(3)
		require.NoError(t, err)
		require.Equal(t, payments.Money{"USD", 4, 500_000_000}, got)
	})
	t.Run("carry through units", func(t *testing.T) {
		// $0.75 * 5 = $3.75 (nanos = 3.75e9, carry 3 into units, leave 0.75)
		got, err := payments.Money{"USD", 0, 750_000_000}.Mul(5)
		require.NoError(t, err)
		require.Equal(t, payments.Money{"USD", 3, 750_000_000}, got)
	})
	t.Run("negative multiplier flips sign", func(t *testing.T) {
		got, err := payments.Money{"USD", 2, 250_000_000}.Mul(-2)
		require.NoError(t, err)
		require.Equal(t, payments.Money{"USD", -4, -500_000_000}, got)
	})
	t.Run("zero multiplier keeps currency", func(t *testing.T) {
		got, err := payments.Money{"USD", 5, 0}.Mul(0)
		require.NoError(t, err)
		require.Equal(t, payments.Money{"USD", 0, 0}, got)
	})
	t.Run("zero money keeps currency", func(t *testing.T) {
		got, err := payments.Money{"USD", 0, 0}.Mul(7)
		require.NoError(t, err)
		require.Equal(t, payments.Money{"USD", 0, 0}, got)
	})
	t.Run("overflow on units", func(t *testing.T) {
		// 2^62 * 4 overflows int64.
		_, err := payments.Money{"USD", 1 << 62, 0}.Mul(4)
		require.Error(t, err)
	})
}

func TestInsert_IdempotentOnPaymentID(t *testing.T) {
	s, _ := newTestStore(t)
	ctx := context.Background()
	sale := uuid.New()
	p := newPayment(sale, 10, 0)

	saved, idempotent, err := s.Insert(ctx, p)
	require.NoError(t, err)
	require.False(t, idempotent)
	require.Equal(t, p.PaymentID, saved.PaymentID)

	// Re-insert same id — must succeed with idempotent=true and return original row.
	dup := p
	dup.Reference = "should-be-ignored"
	saved2, idempotent2, err := s.Insert(ctx, dup)
	require.NoError(t, err)
	require.True(t, idempotent2)
	require.Equal(t, "", saved2.Reference, "duplicate insert must not overwrite existing row")
}

func TestInsert_ValidationErrors(t *testing.T) {
	s, _ := newTestStore(t)
	ctx := context.Background()
	sale := uuid.New()

	cases := []struct {
		name string
		mut  func(*payments.Payment)
	}{
		{"missing PaymentID", func(p *payments.Payment) { p.PaymentID = uuid.Nil }},
		{"missing SaleID", func(p *payments.Payment) { p.SaleID = uuid.Nil }},
		{"missing Method", func(p *payments.Payment) { p.Method = "" }},
		{"missing currency", func(p *payments.Payment) { p.Amount.CurrencyCode = "" }},
		{"zero amount", func(p *payments.Payment) { p.Amount = payments.Money{CurrencyCode: "USD"} }},
		{"zero CreatedAt", func(p *payments.Payment) { p.CreatedAt = time.Time{} }},
		{"parent on positive amount", func(p *payments.Payment) { p.ParentPaymentID = uuid.New() }},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			p := newPayment(sale, 1, 0)
			c.mut(&p)
			_, _, err := s.Insert(ctx, p)
			require.Error(t, err)
		})
	}
}

func TestRefund_LinksToParent(t *testing.T) {
	s, _ := newTestStore(t)
	ctx := context.Background()
	sale := uuid.New()

	pay := newPayment(sale, 10, 0)
	_, _, err := s.Insert(ctx, pay)
	require.NoError(t, err)

	refund := payments.Payment{
		PaymentID:       uuid.New(),
		SaleID:          sale,
		Method:          payments.MethodCash,
		Amount:          payments.Money{"USD", -10, 0},
		ParentPaymentID: pay.PaymentID,
		CreatedAt:       time.Now().UTC(),
	}
	_, _, err = s.Insert(ctx, refund)
	require.NoError(t, err)

	got, err := s.Balance(ctx, sale)
	require.NoError(t, err)
	require.True(t, got.IsZero(), "balance after full refund should be zero, got %+v", got)
}

func TestRefund_ParentMustExist(t *testing.T) {
	s, _ := newTestStore(t)
	ctx := context.Background()
	sale := uuid.New()

	refund := payments.Payment{
		PaymentID:       uuid.New(),
		SaleID:          sale,
		Method:          payments.MethodCash,
		Amount:          payments.Money{"USD", -5, 0},
		ParentPaymentID: uuid.New(), // never inserted
		CreatedAt:       time.Now().UTC(),
	}
	_, _, err := s.Insert(ctx, refund)
	require.ErrorIs(t, err, payments.ErrParentNotFound)
}

func TestBalance_SplitAndPartialRefund(t *testing.T) {
	s, _ := newTestStore(t)
	ctx := context.Background()
	sale := uuid.New()

	// Split: $7.00 cash + $3.50 card → $10.50.
	cash := newPayment(sale, 7, 0)
	card := newPayment(sale, 3, 500_000_000)
	card.Method = payments.MethodCard
	_, _, err := s.Insert(ctx, cash)
	require.NoError(t, err)
	_, _, err = s.Insert(ctx, card)
	require.NoError(t, err)

	// Partial refund of $2.00 against the cash payment.
	refund := payments.Payment{
		PaymentID:       uuid.New(),
		SaleID:          sale,
		Method:          payments.MethodCash,
		Amount:          payments.Money{"USD", -2, 0},
		ParentPaymentID: cash.PaymentID,
		CreatedAt:       time.Now().UTC(),
	}
	_, _, err = s.Insert(ctx, refund)
	require.NoError(t, err)

	bal, err := s.Balance(ctx, sale)
	require.NoError(t, err)
	require.Equal(t, payments.Money{"USD", 8, 500_000_000}, bal, "net = 7 + 3.50 - 2 = 8.50")
}

func TestBalance_MixedCurrencyError(t *testing.T) {
	// We don't expect mixed currencies in practice, but we make the bug loud
	// rather than silently returning a meaningless sum.
	s, _ := newTestStore(t)
	ctx := context.Background()
	sale := uuid.New()

	usd := newPayment(sale, 1, 0)
	eur := newPayment(sale, 1, 0)
	eur.Amount.CurrencyCode = "EUR"
	_, _, err := s.Insert(ctx, usd)
	require.NoError(t, err)
	_, _, err = s.Insert(ctx, eur)
	require.NoError(t, err)

	_, err = s.Balance(ctx, sale)
	require.Error(t, err)
}

func TestGet_NotFound(t *testing.T) {
	s, _ := newTestStore(t)
	_, err := s.Get(context.Background(), uuid.New())
	require.True(t, errors.Is(err, sql.ErrNoRows), "expected sql.ErrNoRows, got %v", err)
}

func TestListForSale_OldestFirst(t *testing.T) {
	s, _ := newTestStore(t)
	ctx := context.Background()
	sale := uuid.New()
	base := time.Now().UTC()
	for i := 0; i < 3; i++ {
		p := newPayment(sale, int64(i+1), 0)
		p.CreatedAt = base.Add(time.Duration(i) * time.Second)
		_, _, err := s.Insert(ctx, p)
		require.NoError(t, err)
	}
	out, err := s.ListForSale(ctx, sale)
	require.NoError(t, err)
	require.Len(t, out, 3)
	for i := 1; i < len(out); i++ {
		require.True(t, out[i-1].CreatedAt.UnixNano() <= out[i].CreatedAt.UnixNano())
	}
}
