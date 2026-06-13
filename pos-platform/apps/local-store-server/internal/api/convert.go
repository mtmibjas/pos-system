// Package api is the Connect-RPC adapter layer.
//
// Each handler in this package is a thin translator:
//   1. proto request → domain request (sales / refunds / tax types)
//   2. invoke the domain Service
//   3. domain response → proto response
//   4. domain error → connect.Error with appropriate connect.Code
//
// No business logic lives here. The handlers exist so the desktop client
// (Phase 2 Dart codegen) and any future SDK consumer can talk to the
// local-store-server over HTTP/Connect without learning Go types.
package api

import (
	"time"

	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// moneyFromProto converts a wire Money to the domain Money. nil → zero.
func moneyFromProto(m *posv1.Money) payments.Money {
	if m == nil {
		return payments.Money{}
	}
	return payments.Money{
		CurrencyCode: m.GetCurrencyCode(),
		Units:        m.GetUnits(),
		Nanos:        m.GetNanos(),
	}
}

// moneyToProto converts a domain Money to the wire shape.
func moneyToProto(m payments.Money) *posv1.Money {
	return &posv1.Money{
		CurrencyCode: m.CurrencyCode,
		Units:        m.Units,
		Nanos:        m.Nanos,
	}
}

// timeFromProto converts a wire Timestamp to time.Time. nil → zero.
func timeFromProto(t *timestamppb.Timestamp) time.Time {
	if t == nil {
		return time.Time{}
	}
	return t.AsTime()
}

// timeToProto converts a time.Time to the wire Timestamp.
func timeToProto(t time.Time) *timestamppb.Timestamp {
	if t.IsZero() {
		return nil
	}
	return timestamppb.New(t)
}

// storeIDValue / counterIDValue / userIDValue dereference the wrapper types
// safely. The wire wrappers exist so the contracts can evolve (e.g. carry
// store metadata) without breaking callers; today we only read .Value.
func storeIDValue(s *posv1.StoreId) string {
	if s == nil {
		return ""
	}
	return s.GetValue()
}

func counterIDValue(c *posv1.CounterId) string {
	if c == nil {
		return ""
	}
	return c.GetValue()
}

func userIDValue(u *posv1.UserId) string {
	if u == nil {
		return ""
	}
	return u.GetValue()
}
