package api

import (
	"context"
	"errors"

	"connectrpc.com/connect"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/inventory"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/items"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
	"github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1/posv1connect"
)

// InventoryHandler adapts inventory.Store + items.Store to
// posv1connect.InventoryServiceHandler.
//
// tenantID is pinned from server config (single-tenant per instance).
// store_id on the wire selects the store; we don't filter items by
// store because the items catalog is store-agnostic.
type InventoryHandler struct {
	posv1connect.UnimplementedInventoryServiceHandler
	inv      *inventory.Store
	items    *items.Store
	tenantID string
}

// NewInventoryHandler wires both stores. Both must be non-nil.
func NewInventoryHandler(inv *inventory.Store, itemStore *items.Store, tenantID string) *InventoryHandler {
	if inv == nil {
		panic("api: NewInventoryHandler requires a non-nil *inventory.Store")
	}
	if itemStore == nil {
		panic("api: NewInventoryHandler requires a non-nil *items.Store")
	}
	if tenantID == "" {
		panic("api: NewInventoryHandler requires tenantID")
	}
	return &InventoryHandler{inv: inv, items: itemStore, tenantID: tenantID}
}

// ListOnHand returns one row per SKU that has movements at store_id,
// joined with the item catalog for name/price. SKUs without catalog
// entries still render (empty name + zero price); catalog SKUs with
// no movements are omitted (would always be zero — not useful noise).
func (h *InventoryHandler) ListOnHand(
	ctx context.Context,
	req *connect.Request[posv1.ListOnHandRequest],
) (*connect.Response[posv1.ListOnHandResponse], error) {
	storeID := req.Msg.GetStoreId().GetValue()
	if storeID == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument,
			errors.New("store_id: required"))
	}

	onHand, err := h.inv.ListOnHand(ctx, storeID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	cat, err := h.items.List(ctx, h.tenantID, false)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}
	bySKU := make(map[string]items.Item, len(cat))
	for _, it := range cat {
		bySKU[it.SKU] = it
	}

	out := make([]*posv1.OnHandRow, 0, len(onHand))
	for _, r := range onHand {
		row := &posv1.OnHandRow{Sku: r.SKU, OnHand: r.OnHand}
		if it, ok := bySKU[r.SKU]; ok {
			row.Name = it.Name
			row.Price = moneyToProto(it.Price)
		}
		out = append(out, row)
	}

	return connect.NewResponse(&posv1.ListOnHandResponse{Rows: out}), nil
}
