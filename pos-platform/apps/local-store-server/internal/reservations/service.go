package reservations

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/hub"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/inventory"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/txn"
)

// Service is the reservation lifecycle entry point.
type Service struct {
	db        *sql.DB
	store     *Store
	inv       *inventory.Store
	publisher hub.RawPublisher
	now       func() time.Time
	ttl       time.Duration
}

// Config groups the constructor inputs.
type Config struct {
	DB        *sql.DB
	Store     *Store
	Inv       *inventory.Store
	Publisher hub.RawPublisher // nil → hub.NopPublisher{}; receives inventory_available_changed frames
	Now       func() time.Time // nil → time.Now
	TTL       time.Duration    // zero → DefaultTTL
}

// NewService validates required fields.
func NewService(c Config) (*Service, error) {
	switch {
	case c.DB == nil:
		return nil, errors.New("reservations: Config.DB is required")
	case c.Store == nil:
		return nil, errors.New("reservations: Config.Store is required")
	case c.Inv == nil:
		return nil, errors.New("reservations: Config.Inv is required")
	}
	if c.Publisher == nil {
		c.Publisher = hub.NopPublisher{}
	}
	if c.Now == nil {
		c.Now = func() time.Time { return time.Now().UTC() }
	}
	if c.TTL == 0 {
		c.TTL = DefaultTTL
	}
	return &Service{
		db:        c.DB,
		store:     c.Store,
		inv:       c.Inv,
		publisher: c.Publisher,
		now:       c.Now,
		ttl:       c.TTL,
	}, nil
}

// ReserveRequest is the in-process input.
type ReserveRequest struct {
	ReservationID uuid.UUID // optional; auto-assigned when uuid.Nil
	SKU           string
	StoreID       string
	CounterID     string
	Quantity      int64
}

// ReserveResponse mirrors the inserted reservation.
type ReserveResponse struct {
	Reservation Reservation
	Available   int64 // available after this reservation
}

// Reserve creates a new active hold if available stock allows. The check
// runs inside the inventory per-SKU lock + a SQL transaction so two
// counters racing for the last unit cannot both win.
func (s *Service) Reserve(ctx context.Context, req ReserveRequest) (ReserveResponse, error) {
	if req.SKU == "" || req.StoreID == "" || req.CounterID == "" {
		return ReserveResponse{}, errors.New("reservations: SKU, StoreID, CounterID are required")
	}
	if req.Quantity <= 0 {
		return ReserveResponse{}, errors.New("reservations: Quantity must be positive")
	}

	id := req.ReservationID
	if id == uuid.Nil {
		id = uuid.New()
	}
	now := s.now()
	r := Reservation{
		ID:        id,
		SKU:       req.SKU,
		StoreID:   req.StoreID,
		CounterID: req.CounterID,
		Quantity:  req.Quantity,
		CreatedAt: now,
		ExpiresAt: now.Add(s.ttl),
		Status:    StatusActive,
	}

	var (
		availableAfter int64
		expired        []StoreSKU
	)
	err := s.inv.WithSKULock(req.StoreID, req.SKU, func() error {
		return txn.Apply(ctx, s.db, func(tx *sql.Tx) error {
			// Lazy expiry inside the txn so the Available check below
			// doesn't see a soon-to-be-expired hold.
			ex, err := s.store.ExpireDueTx(ctx, tx, now.UnixNano())
			if err != nil {
				return err
			}
			expired = ex

			avail, err := s.inv.AvailableTx(ctx, tx, req.StoreID, req.SKU, now.UnixNano())
			if err != nil {
				return err
			}
			if avail < req.Quantity {
				return &ErrInsufficientAvailable{
					SKU:       req.SKU,
					StoreID:   req.StoreID,
					Available: avail,
					Requested: req.Quantity,
				}
			}
			if err := s.store.Insert(ctx, tx, r); err != nil {
				return err
			}
			availableAfter = avail - req.Quantity
			return nil
		})
	})
	if err != nil {
		return ReserveResponse{}, err
	}

	// Broadcast: this SKU changed, plus any others lazily expired in
	// the same txn (their available went UP, others' tiles must refresh).
	s.publishAvailable(ctx, req.StoreID, req.SKU, availableAfter)
	for _, k := range expired {
		if k.StoreID == req.StoreID && k.SKU == req.SKU {
			continue // already broadcast above
		}
		s.publishStoreSKU(ctx, k)
	}

	return ReserveResponse{Reservation: r, Available: availableAfter}, nil
}

// Get loads a reservation by id. Surface for read-side handlers.
func (s *Service) Get(ctx context.Context, id uuid.UUID) (Reservation, error) {
	return s.store.Get(ctx, id)
}

// Release marks an active reservation as released. Idempotent on a row
// that's already terminal in the same target status — re-releases are no-ops.
func (s *Service) Release(ctx context.Context, id uuid.UUID) error {
	return s.terminate(ctx, id, StatusReleased)
}

// Finalize marks an active reservation as consumed by a sale. Use this
// only when NOT consuming the reservation inside a sales.Service.Finalize
// txn.Apply (the sales service uses FinalizeTx directly to keep the
// status flip atomic with the sale commit).
func (s *Service) Finalize(ctx context.Context, id uuid.UUID) error {
	return s.terminate(ctx, id, StatusFinalized)
}

// FinalizeTx is the *sql.Tx variant for callers that need the status
// flip inside their own transaction (sales.Service.Finalize). On
// success, the caller is responsible for publishing the available
// change AFTER commit (so a rollback doesn't fire a spurious update).
func (s *Service) FinalizeTx(ctx context.Context, tx *sql.Tx, id uuid.UUID) (Reservation, error) {
	r, err := s.store.GetTx(ctx, tx, id)
	if err != nil {
		return Reservation{}, err
	}
	if r.Status != StatusActive {
		return Reservation{}, ErrNotActive
	}
	if err := s.store.TransitionTx(ctx, tx, id, StatusFinalized); err != nil {
		return Reservation{}, err
	}
	return r, nil
}

// PublishAvailableChange recomputes Available for (storeID, sku) and
// emits an inventory_available_changed frame. Callers that committed a
// state change in their own txn use this to broadcast post-commit.
func (s *Service) PublishAvailableChange(ctx context.Context, storeID, sku string) {
	avail, err := s.inv.Available(ctx, storeID, sku, s.now().UnixNano())
	if err != nil {
		return
	}
	s.publishAvailable(ctx, storeID, sku, avail)
}

func (s *Service) terminate(ctx context.Context, id uuid.UUID, to Status) error {
	var (
		storeID string
		sku     string
	)
	err := txn.Apply(ctx, s.db, func(tx *sql.Tx) error {
		r, err := s.store.GetTx(ctx, tx, id)
		if err != nil {
			return err
		}
		storeID, sku = r.StoreID, r.SKU
		if r.Status == to {
			// Idempotent: already in target status.
			return nil
		}
		if r.Status != StatusActive {
			return ErrNotActive
		}
		return s.store.TransitionTx(ctx, tx, id, to)
	})
	if err != nil {
		return err
	}
	// Post-commit broadcast: recompute current Available.
	s.PublishAvailableChange(ctx, storeID, sku)
	return nil
}

// availableChangedFrame is the JSON wire shape for the
// inventory_available_changed frame. Lives next to publish below so the
// schema is colocated with its only emitter.
type availableChangedFrame struct {
	Type      string `json:"type"`
	StoreID   string `json:"store_id"`
	SKU       string `json:"sku"`
	Available int64  `json:"available_qty"`
}

const eventTypeAvailableChanged = "inventory_available_changed"

func (s *Service) publishAvailable(_ context.Context, storeID, sku string, available int64) {
	payload, err := json.Marshal(availableChangedFrame{
		Type:      eventTypeAvailableChanged,
		StoreID:   storeID,
		SKU:       sku,
		Available: available,
	})
	if err != nil {
		return
	}
	s.publisher.PublishRaw(eventTypeAvailableChanged, payload)
}

func (s *Service) publishStoreSKU(ctx context.Context, k StoreSKU) {
	avail, err := s.inv.Available(ctx, k.StoreID, k.SKU, s.now().UnixNano())
	if err != nil {
		return
	}
	s.publishAvailable(ctx, k.StoreID, k.SKU, avail)
}

