package api

import (
	"context"

	"connectrpc.com/connect"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/tax"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
	"github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1/posv1connect"
)

// TaxAdminHandler adapts tax.Store to posv1connect.TaxAdminServiceHandler.
//
// tenantID is pinned from server config — the wire tenant_id on TaxCategory
// is ignored (single-tenant per server instance, see TaxAdminService proto
// doc).
type TaxAdminHandler struct {
	posv1connect.UnimplementedTaxAdminServiceHandler
	store    *tax.Store
	tenantID string
}

// NewTaxAdminHandler wraps a non-nil tax.Store.
func NewTaxAdminHandler(store *tax.Store, tenantID string) *TaxAdminHandler {
	if store == nil {
		panic("api: NewTaxAdminHandler requires a non-nil *tax.Store")
	}
	if tenantID == "" {
		panic("api: NewTaxAdminHandler requires tenantID")
	}
	return &TaxAdminHandler{store: store, tenantID: tenantID}
}

// UpsertTaxCategory writes a category. Components on the inbound proto are
// ignored — the proto contract documents that callers must use
// UpsertTaxComponent for individual rates.
func (h *TaxAdminHandler) UpsertTaxCategory(
	ctx context.Context,
	req *connect.Request[posv1.UpsertTaxCategoryRequest],
) (*connect.Response[posv1.UpsertTaxCategoryResponse], error) {
	in := req.Msg.GetCategory()
	if in == nil {
		return nil, connect.NewError(connect.CodeInvalidArgument,
			errMissingCategory)
	}
	cat := tax.Category{
		ID:               in.GetId(),
		Name:             in.GetName(),
		TenantID:         h.tenantID, // server-pinned
		PriceIncludesTax: in.GetPriceIncludesTax(),
	}
	if err := h.store.UpsertCategory(ctx, cat); err != nil {
		return nil, toConnectErr(err)
	}
	// Reload to return the canonical row + components.
	stored, err := h.store.GetCategory(ctx, h.tenantID, cat.ID)
	if err != nil {
		return nil, toConnectErr(err)
	}
	return connect.NewResponse(&posv1.UpsertTaxCategoryResponse{
		Category: categoryToProto(stored),
	}), nil
}

// UpsertTaxComponent writes a single rate component.
func (h *TaxAdminHandler) UpsertTaxComponent(
	ctx context.Context,
	req *connect.Request[posv1.UpsertTaxComponentRequest],
) (*connect.Response[posv1.UpsertTaxComponentResponse], error) {
	in := req.Msg.GetComponent()
	if in == nil {
		return nil, connect.NewError(connect.CodeInvalidArgument,
			errMissingComponent)
	}
	comp := tax.Component{
		ID:            in.GetId(),
		Name:          in.GetName(),
		RateBP:        in.GetRateBasisPoints(),
		SortOrder:     in.GetSortOrder(),
		TaxCategoryID: in.GetTaxCategoryId(),
	}
	if err := h.store.UpsertComponent(ctx, comp); err != nil {
		return nil, toConnectErr(err)
	}
	// Reload via parent category so the returned component reflects the
	// stored row (including any normalization).
	stored, err := h.store.GetCategory(ctx, h.tenantID, comp.TaxCategoryID)
	if err != nil {
		return nil, toConnectErr(err)
	}
	for _, c := range stored.Components {
		if c.ID == comp.ID {
			return connect.NewResponse(&posv1.UpsertTaxComponentResponse{
				Component: componentToProto(c),
			}), nil
		}
	}
	// The component is gone right after we wrote it — surface as Internal.
	return nil, connect.NewError(connect.CodeInternal,
		errComponentNotPersisted)
}

// GetTaxCategory returns a category + components for the server tenant.
func (h *TaxAdminHandler) GetTaxCategory(
	ctx context.Context,
	req *connect.Request[posv1.GetTaxCategoryRequest],
) (*connect.Response[posv1.GetTaxCategoryResponse], error) {
	cat, err := h.store.GetCategory(ctx, h.tenantID, req.Msg.GetId())
	if err != nil {
		return nil, toConnectErr(err)
	}
	return connect.NewResponse(&posv1.GetTaxCategoryResponse{
		Category: categoryToProto(cat),
	}), nil
}

// --- helpers ---

func categoryToProto(c tax.Category) *posv1.TaxCategory {
	comps := make([]*posv1.TaxComponent, 0, len(c.Components))
	for _, comp := range c.Components {
		comps = append(comps, componentToProto(comp))
	}
	return &posv1.TaxCategory{
		Id:               c.ID,
		Name:             c.Name,
		TenantId:         c.TenantID,
		PriceIncludesTax: c.PriceIncludesTax,
		Components:       comps,
	}
}

func componentToProto(c tax.Component) *posv1.TaxComponent {
	return &posv1.TaxComponent{
		Id:              c.ID,
		TaxCategoryId:   c.TaxCategoryID,
		Name:            c.Name,
		RateBasisPoints: c.RateBP,
		SortOrder:       c.SortOrder,
	}
}
