package events_test

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/proto"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/events"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

func validMeta() events.Meta {
	return events.Meta{
		OperationID: uuid.NewString(),
		TenantID:    "tenant-A",
		OriginNode:  &posv1.OriginNode{NodeId: "node-1"},
		Lamport:     42,
		OccurredAt:  time.Unix(1700000000, 0).UTC(),
	}
}

func TestPack_Unpack_RoundTrip_SaleCreated(t *testing.T) {
	sale := &posv1.SaleCreated{
		SaleId: "sale-1",
		Lines: []*posv1.SaleLine{
			{Sku: "SKU1", Quantity: 2, UnitPrice: &posv1.Money{CurrencyCode: "USD", Units: 5}},
		},
		GrandTotal: &posv1.Money{CurrencyCode: "USD", Units: 10},
	}
	env, wire, err := events.Pack(sale, validMeta())
	require.NoError(t, err)
	require.Equal(t, "sale_created", env.EventType)
	require.NotEmpty(t, wire)
	require.Equal(t, uint32(1), env.SchemaVersion, "default schema_version=1")
	require.Equal(t, uint64(42), env.Clock.Counter)
	require.Equal(t, "node-1", env.Clock.NodeId)

	gotEnv, gotMsg, err := events.Unpack(wire)
	require.NoError(t, err)
	require.Equal(t, env.EventType, gotEnv.EventType)
	got, ok := gotMsg.(*posv1.SaleCreated)
	require.True(t, ok)
	require.Equal(t, "sale-1", got.SaleId)
	require.Equal(t, int64(2), got.Lines[0].Quantity)
}

// TestPack_EachPayloadType ensures every oneof case in events.proto is
// wired through setPayload — if someone adds a new event message but
// forgets the switch arm, this test fails for that case.
func TestPack_EachPayloadType(t *testing.T) {
	cases := []struct {
		name    string
		payload proto.Message
		want    string
	}{
		{"SaleCreated", &posv1.SaleCreated{SaleId: "x"}, "sale_created"},
		{"PaymentAdded", &posv1.PaymentAdded{PaymentId: "x"}, "payment_added"},
		{"PaymentRefunded", &posv1.PaymentRefunded{RefundId: "x"}, "payment_refunded"},
		{"InventoryAdjusted", &posv1.InventoryAdjusted{Sku: "x"}, "inventory_adjusted"},
		{"StockTransferred", &posv1.StockTransferred{TransferId: "x"}, "stock_transferred"},
		{"SyncCompleted", &posv1.SyncCompleted{BatchId: "x"}, "sync_completed"},
		{"SyncFailed", &posv1.SyncFailed{BatchId: "x"}, "sync_failed"},
		{"UserLoggedIn", &posv1.UserLoggedIn{DeviceId: "x"}, "user_logged_in"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			env, wire, err := events.Pack(c.payload, validMeta())
			require.NoError(t, err)
			require.Equal(t, c.want, env.EventType)

			// Round-trip back and confirm the unwrapped concrete type matches.
			_, got, err := events.Unpack(wire)
			require.NoError(t, err)
			require.IsType(t, c.payload, got)
		})
	}
}

func TestPack_UnsupportedPayloadTypeErrors(t *testing.T) {
	// A message that isn't wired in setPayload must error explicitly —
	// the failure mode is loud, never silent.
	_, _, err := events.Pack(&posv1.EventEnvelope{}, validMeta())
	require.Error(t, err)
}

func TestPack_ValidationErrors(t *testing.T) {
	cases := []struct {
		name string
		mut  func(*events.Meta)
	}{
		{"missing OperationID", func(m *events.Meta) { m.OperationID = "" }},
		{"missing TenantID", func(m *events.Meta) { m.TenantID = "" }},
		{"missing OriginNode", func(m *events.Meta) { m.OriginNode = nil }},
		{"missing OriginNode.NodeId", func(m *events.Meta) { m.OriginNode = &posv1.OriginNode{} }},
		{"zero OccurredAt", func(m *events.Meta) { m.OccurredAt = time.Time{} }},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			m := validMeta()
			c.mut(&m)
			_, _, err := events.Pack(&posv1.SaleCreated{SaleId: "x"}, m)
			require.Error(t, err)
		})
	}
}

func TestPack_DefaultSchemaVersion(t *testing.T) {
	// Zero -> 1; explicit -> preserved.
	env, _, err := events.Pack(&posv1.SaleCreated{SaleId: "x"}, validMeta())
	require.NoError(t, err)
	require.Equal(t, uint32(1), env.SchemaVersion)

	m := validMeta()
	m.SchemaVersion = 7
	env, _, err = events.Pack(&posv1.SaleCreated{SaleId: "x"}, m)
	require.NoError(t, err)
	require.Equal(t, uint32(7), env.SchemaVersion)
}

func TestUnpack_EmptyPayloadError(t *testing.T) {
	// An envelope with no payload set must error from Unpack — we never want
	// the consumer to receive a nil message and silently no-op.
	env := &posv1.EventEnvelope{
		OperationId: &posv1.OperationId{Value: uuid.NewString()},
		EventType:   "unknown",
	}
	wire, err := proto.Marshal(env)
	require.NoError(t, err)
	_, _, err = events.Unpack(wire)
	require.Error(t, err)
}

func TestUnpack_MalformedBytes(t *testing.T) {
	_, _, err := events.Unpack([]byte{0xff, 0xff, 0xff})
	require.Error(t, err)
}
