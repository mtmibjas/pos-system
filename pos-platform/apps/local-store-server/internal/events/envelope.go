// Package events is the typed boundary between domain payloads and the
// opslog wire format. Callers build a typed Event* message, hand it to
// Pack along with envelope Meta, and get back both the *EventEnvelope
// (for in-process consumers like the websocket broadcaster) and the
// serialized []byte (for opslog.Operation.Payload).
//
// Why a thin layer instead of generating helpers per event type: the
// envelope shape is stable; only the payload oneof varies. A single
// switch keeps the surface tiny and the codegen output uncluttered.
package events

import (
	"errors"
	"fmt"
	"time"

	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/timestamppb"

	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// Meta is the per-call envelope metadata the caller must supply — these
// are the fields events.Pack cannot derive from the payload itself.
type Meta struct {
	OperationID  string // UUID; idempotency key — REQUIRED
	TenantID     string // REQUIRED for multi-tenant cloud routing
	OriginNode   *posv1.OriginNode
	Lamport      uint64
	OccurredAt   time.Time
	SchemaVersion uint32 // bump when payload shape changes; 1 by default
}

// Pack wraps a typed event in an EventEnvelope, populates event_type from
// the payload's proto name, and returns both the envelope (for in-process
// consumers) and its serialized bytes (for opslog.Operation.Payload).
func Pack(payload proto.Message, m Meta) (*posv1.EventEnvelope, []byte, error) {
	if err := m.validate(); err != nil {
		return nil, nil, err
	}
	env := &posv1.EventEnvelope{
		OperationId:   &posv1.OperationId{Value: m.OperationID},
		TenantId:      &posv1.TenantId{Value: m.TenantID},
		Origin:        m.OriginNode,
		Clock:         &posv1.LamportClock{Counter: m.Lamport, NodeId: nodeIDOf(m.OriginNode)},
		OccurredAt:    timestamppb.New(m.OccurredAt.UTC()),
		SchemaVersion: defaultSchemaVersion(m.SchemaVersion),
	}
	if err := setPayload(env, payload); err != nil {
		return nil, nil, err
	}
	wire, err := proto.Marshal(env)
	if err != nil {
		return nil, nil, fmt.Errorf("events: marshal envelope: %w", err)
	}
	return env, wire, nil
}

// Unpack parses a wire payload (typically opslog.Operation.Payload) back
// into the envelope and the underlying typed event. Returns an error on
// malformed bytes or an empty oneof.
func Unpack(wire []byte) (*posv1.EventEnvelope, proto.Message, error) {
	env := &posv1.EventEnvelope{}
	if err := proto.Unmarshal(wire, env); err != nil {
		return nil, nil, fmt.Errorf("events: unmarshal envelope: %w", err)
	}
	inner := innerOf(env)
	if inner == nil {
		return nil, nil, errors.New("events: envelope has no payload set")
	}
	return env, inner, nil
}

// --- internal ---

func (m Meta) validate() error {
	if m.OperationID == "" {
		return errors.New("events: Meta.OperationID is required")
	}
	if m.TenantID == "" {
		return errors.New("events: Meta.TenantID is required")
	}
	if m.OriginNode == nil || m.OriginNode.NodeId == "" {
		return errors.New("events: Meta.OriginNode.NodeId is required")
	}
	if m.OccurredAt.IsZero() {
		return errors.New("events: Meta.OccurredAt is required")
	}
	return nil
}

func defaultSchemaVersion(v uint32) uint32 {
	if v == 0 {
		return 1
	}
	return v
}

func nodeIDOf(o *posv1.OriginNode) string {
	if o == nil {
		return ""
	}
	return o.NodeId
}

// setPayload populates the oneof and event_type from the typed message.
// New event types added to events.proto must be wired here — the failure
// mode is explicit (an error at runtime) rather than silent dropping.
func setPayload(env *posv1.EventEnvelope, p proto.Message) error {
	switch v := p.(type) {
	case *posv1.SaleCreated:
		env.Payload = &posv1.EventEnvelope_SaleCreated{SaleCreated: v}
		env.EventType = "sale_created"
	case *posv1.PaymentAdded:
		env.Payload = &posv1.EventEnvelope_PaymentAdded{PaymentAdded: v}
		env.EventType = "payment_added"
	case *posv1.PaymentRefunded:
		env.Payload = &posv1.EventEnvelope_PaymentRefunded{PaymentRefunded: v}
		env.EventType = "payment_refunded"
	case *posv1.InventoryAdjusted:
		env.Payload = &posv1.EventEnvelope_InventoryAdjusted{InventoryAdjusted: v}
		env.EventType = "inventory_adjusted"
	case *posv1.StockTransferred:
		env.Payload = &posv1.EventEnvelope_StockTransferred{StockTransferred: v}
		env.EventType = "stock_transferred"
	case *posv1.SyncCompleted:
		env.Payload = &posv1.EventEnvelope_SyncCompleted{SyncCompleted: v}
		env.EventType = "sync_completed"
	case *posv1.SyncFailed:
		env.Payload = &posv1.EventEnvelope_SyncFailed{SyncFailed: v}
		env.EventType = "sync_failed"
	case *posv1.UserLoggedIn:
		env.Payload = &posv1.EventEnvelope_UserLoggedIn{UserLoggedIn: v}
		env.EventType = "user_logged_in"
	case *posv1.SaleVoided:
		env.Payload = &posv1.EventEnvelope_SaleVoided{SaleVoided: v}
		env.EventType = "sale_voided"
	case *posv1.SaleRefunded:
		env.Payload = &posv1.EventEnvelope_SaleRefunded{SaleRefunded: v}
		env.EventType = "sale_refunded"
	default:
		return fmt.Errorf("events: unsupported payload type %T (wire it in events.proto + setPayload)", p)
	}
	return nil
}

// innerOf unwraps the oneof.
func innerOf(env *posv1.EventEnvelope) proto.Message {
	switch p := env.Payload.(type) {
	case *posv1.EventEnvelope_SaleCreated:
		return p.SaleCreated
	case *posv1.EventEnvelope_PaymentAdded:
		return p.PaymentAdded
	case *posv1.EventEnvelope_PaymentRefunded:
		return p.PaymentRefunded
	case *posv1.EventEnvelope_InventoryAdjusted:
		return p.InventoryAdjusted
	case *posv1.EventEnvelope_StockTransferred:
		return p.StockTransferred
	case *posv1.EventEnvelope_SyncCompleted:
		return p.SyncCompleted
	case *posv1.EventEnvelope_SyncFailed:
		return p.SyncFailed
	case *posv1.EventEnvelope_UserLoggedIn:
		return p.UserLoggedIn
	case *posv1.EventEnvelope_SaleVoided:
		return p.SaleVoided
	case *posv1.EventEnvelope_SaleRefunded:
		return p.SaleRefunded
	default:
		return nil
	}
}
