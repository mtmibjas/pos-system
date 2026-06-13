package api

import (
	"context"
	"fmt"

	"connectrpc.com/connect"
	"github.com/google/uuid"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/refunds"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
	"github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1/posv1connect"
)

// RefundHandler adapts refunds.Service to posv1connect.RefundServiceHandler.
type RefundHandler struct {
	posv1connect.UnimplementedRefundServiceHandler
	svc *refunds.Service
}

// NewRefundHandler wraps a non-nil refunds.Service.
func NewRefundHandler(svc *refunds.Service) *RefundHandler {
	if svc == nil {
		panic("api: NewRefundHandler requires a non-nil *refunds.Service")
	}
	return &RefundHandler{svc: svc}
}

// VoidSale translates the wire request and invokes refunds.Service.Void.
func (h *RefundHandler) VoidSale(
	ctx context.Context,
	req *connect.Request[posv1.VoidSaleRequest],
) (*connect.Response[posv1.VoidSaleResponse], error) {
	in := req.Msg

	voidID, err := uuid.Parse(in.GetVoidId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument,
			fmt.Errorf("void_id: %w", err))
	}
	saleID, err := uuid.Parse(in.GetSaleId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument,
			fmt.Errorf("sale_id: %w", err))
	}

	out, err := h.svc.Void(ctx, refunds.VoidRequest{
		VoidID:     voidID,
		SaleID:     saleID,
		StoreID:    storeIDValue(in.GetStoreId()),
		CounterID:  counterIDValue(in.GetCounterId()),
		CashierID:  userIDValue(in.GetCashierId()),
		Reason:     in.GetReason(),
		OccurredAt: timeFromProto(in.GetOccurredAt()),
	})
	if err != nil {
		return nil, toConnectErr(err)
	}

	return connect.NewResponse(&posv1.VoidSaleResponse{
		VoidId:     out.VoidID.String(),
		BatchId:    out.BatchID.String(),
		Lamport:    out.Lamport,
		Void:       voidToProto(out.Void),
		Idempotent: out.Idempotent,
	}), nil
}

// RefundSale translates the wire request and invokes refunds.Service.Refund.
func (h *RefundHandler) RefundSale(
	ctx context.Context,
	req *connect.Request[posv1.RefundSaleRequest],
) (*connect.Response[posv1.RefundSaleResponse], error) {
	in := req.Msg

	refundID, err := uuid.Parse(in.GetRefundId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument,
			fmt.Errorf("refund_id: %w", err))
	}
	saleID, err := uuid.Parse(in.GetSaleId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument,
			fmt.Errorf("sale_id: %w", err))
	}

	lines, err := refundLinesFromProto(in.GetLines())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, err)
	}
	tenders, err := refundTendersFromProto(in.GetTenders())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, err)
	}

	out, err := h.svc.Refund(ctx, refunds.RefundRequest{
		RefundID:   refundID,
		SaleID:     saleID,
		StoreID:    storeIDValue(in.GetStoreId()),
		CounterID:  counterIDValue(in.GetCounterId()),
		CashierID:  userIDValue(in.GetCashierId()),
		Reason:     in.GetReason(),
		OccurredAt: timeFromProto(in.GetOccurredAt()),
		Lines:      lines,
		Tenders:    tenders,
	})
	if err != nil {
		return nil, toConnectErr(err)
	}

	return connect.NewResponse(&posv1.RefundSaleResponse{
		RefundId:   out.RefundID.String(),
		BatchId:    out.BatchID.String(),
		Lamport:    out.Lamport,
		Refund:     refundToProto(out.Refund),
		Idempotent: out.Idempotent,
	}), nil
}

// --- proto → domain ---

func refundLinesFromProto(in []*posv1.RefundSaleLine) ([]refunds.RefundLineRequest, error) {
	out := make([]refunds.RefundLineRequest, 0, len(in))
	for i, ln := range in {
		if ln == nil {
			return nil, fmt.Errorf("lines[%d]: nil", i)
		}
		saleLineID, err := uuid.Parse(ln.GetSaleLineId())
		if err != nil {
			return nil, fmt.Errorf("lines[%d].sale_line_id: %w", i, err)
		}
		out = append(out, refunds.RefundLineRequest{
			SaleLineID:    saleLineID,
			SKU:           ln.GetSku(),
			Quantity:      ln.GetQuantity(),
			Restock:       ln.GetRestock(),
			UnitPrice:     moneyFromProto(ln.GetUnitPrice()),
			LineTotal:     moneyFromProto(ln.GetLineTotal()),
			TaxCategoryID: ln.GetTaxCategoryId(),
		})
	}
	return out, nil
}

func refundTendersFromProto(in []*posv1.RefundSaleTender) ([]refunds.RefundTenderRequest, error) {
	out := make([]refunds.RefundTenderRequest, 0, len(in))
	for i, t := range in {
		if t == nil {
			return nil, fmt.Errorf("tenders[%d]: nil", i)
		}
		refundPayID, err := uuid.Parse(t.GetRefundPaymentId())
		if err != nil {
			return nil, fmt.Errorf("tenders[%d].refund_payment_id: %w", i, err)
		}
		originalPayID, err := uuid.Parse(t.GetOriginalPaymentId())
		if err != nil {
			return nil, fmt.Errorf("tenders[%d].original_payment_id: %w", i, err)
		}
		out = append(out, refunds.RefundTenderRequest{
			RefundPaymentID:   refundPayID,
			OriginalPaymentID: originalPayID,
			Method:            payments.Method(t.GetMethod()),
			Amount:            moneyFromProto(t.GetAmount()),
			Reference:         t.GetReference(),
		})
	}
	return out, nil
}

// --- domain → proto ---

func voidToProto(v refunds.Void) *posv1.Void {
	return &posv1.Void{
		VoidId:    v.VoidID.String(),
		SaleId:    v.SaleID.String(),
		InvoiceId: v.InvoiceID.String(),
		StoreId:   &posv1.StoreId{Value: v.StoreID},
		CounterId: &posv1.CounterId{Value: v.CounterID},
		CashierId: &posv1.UserId{Value: v.CashierID},
		Reason:    v.Reason,
		Snapshot:  v.Snapshot,
		VoidedAt:  timeToProto(v.VoidedAt),
	}
}

func refundToProto(r refunds.Refund) *posv1.Refund {
	return &posv1.Refund{
		RefundId:         r.RefundID.String(),
		SaleId:           r.SaleID.String(),
		InvoiceId:        r.InvoiceID.String(),
		CreditNoteNumber: r.CreditNoteNumber,
		StoreId:          &posv1.StoreId{Value: r.StoreID},
		CounterId:        &posv1.CounterId{Value: r.CounterID},
		CashierId:        &posv1.UserId{Value: r.CashierID},
		Reason:           r.Reason,
		Subtotal:         moneyToProto(r.Subtotal),
		TaxTotal:         moneyToProto(r.TaxTotal),
		GrandTotal:       moneyToProto(r.GrandTotal),
		Snapshot:         r.Snapshot,
		RefundedAt:       timeToProto(r.RefundedAt),
	}
}
