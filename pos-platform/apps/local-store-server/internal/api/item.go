package api

import (
	"context"
	"errors"
	"time"

	"connectrpc.com/connect"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/items"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
	"github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1/posv1connect"
)

// api-layer sentinels for ItemService input validation.
var errMissingItem = errors.New("api: UpsertItemRequest.item is required")

// ItemHandler adapts items.Store to posv1connect.ItemServiceHandler.
//
// tenantID is pinned from server config — the wire tenant_id on the
// Item message is ignored (single-tenant per server instance, see
// ItemService proto doc).
type ItemHandler struct {
	posv1connect.UnimplementedItemServiceHandler
	store    *items.Store
	tenantID string
}

// NewItemHandler wraps a non-nil items.Store.
func NewItemHandler(store *items.Store, tenantID string) *ItemHandler {
	if store == nil {
		panic("api: NewItemHandler requires a non-nil *items.Store")
	}
	if tenantID == "" {
		panic("api: NewItemHandler requires tenantID")
	}
	return &ItemHandler{store: store, tenantID: tenantID}
}

func (h *ItemHandler) UpsertItem(
	ctx context.Context,
	req *connect.Request[posv1.UpsertItemRequest],
) (*connect.Response[posv1.UpsertItemResponse], error) {
	in := req.Msg.GetItem()
	if in == nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, errMissingItem)
	}
	domain := items.Item{
		SKU:           in.GetSku(),
		TenantID:      h.tenantID, // server-pinned
		Name:          in.GetName(),
		Price:         moneyFromProto(in.GetPrice()),
		TaxCategoryID: in.GetTaxCategoryId(),
	}
	if in.GetArchived() {
		now := time.Now().UTC()
		domain.ArchivedAt = &now
	}
	stored, err := h.store.Upsert(ctx, domain)
	if err != nil {
		return nil, toConnectErr(err)
	}
	return connect.NewResponse(&posv1.UpsertItemResponse{
		Item: itemToProto(stored),
	}), nil
}

func (h *ItemHandler) GetItem(
	ctx context.Context,
	req *connect.Request[posv1.GetItemRequest],
) (*connect.Response[posv1.GetItemResponse], error) {
	it, err := h.store.Get(ctx, h.tenantID, req.Msg.GetSku())
	if err != nil {
		return nil, toConnectErr(err)
	}
	return connect.NewResponse(&posv1.GetItemResponse{
		Item: itemToProto(it),
	}), nil
}

func (h *ItemHandler) ListItems(
	ctx context.Context,
	req *connect.Request[posv1.ListItemsRequest],
) (*connect.Response[posv1.ListItemsResponse], error) {
	rows, err := h.store.List(ctx, h.tenantID, req.Msg.GetIncludeArchived())
	if err != nil {
		return nil, toConnectErr(err)
	}
	out := make([]*posv1.Item, 0, len(rows))
	for _, it := range rows {
		out = append(out, itemToProto(it))
	}
	return connect.NewResponse(&posv1.ListItemsResponse{
		Items: out,
	}), nil
}

// --- helpers ---

func itemToProto(i items.Item) *posv1.Item {
	return &posv1.Item{
		Sku:           i.SKU,
		TenantId:      i.TenantID,
		Name:          i.Name,
		Price:         moneyToProto(i.Price),
		TaxCategoryId: i.TaxCategoryID,
		Archived:      i.IsArchived(),
		CreatedAt:     timeToProto(i.CreatedAt),
		UpdatedAt:     timeToProto(i.UpdatedAt),
	}
}
