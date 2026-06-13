package api

import (
	"context"
	"errors"

	"connectrpc.com/connect"
	"github.com/google/uuid"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/reservations"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
	"github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1/posv1connect"
)

// ReservationHandler adapts reservations.Service to
// posv1connect.ReservationServiceHandler — Phase 4 slice 4.3.
type ReservationHandler struct {
	posv1connect.UnimplementedReservationServiceHandler
	svc *reservations.Service
}

// NewReservationHandler requires a non-nil *reservations.Service.
func NewReservationHandler(svc *reservations.Service) *ReservationHandler {
	if svc == nil {
		panic("api: NewReservationHandler requires a non-nil *reservations.Service")
	}
	return &ReservationHandler{svc: svc}
}

// Reserve creates a soft hold or returns FailedPrecondition if available
// stock can't cover it.
func (h *ReservationHandler) Reserve(
	ctx context.Context,
	req *connect.Request[posv1.ReserveRequest],
) (*connect.Response[posv1.ReserveResponse], error) {
	in := req.Msg

	var rid uuid.UUID
	if s := in.GetReservationId(); s != "" {
		id, err := uuid.Parse(s)
		if err != nil {
			return nil, connect.NewError(connect.CodeInvalidArgument, err)
		}
		rid = id
	}

	out, err := h.svc.Reserve(ctx, reservations.ReserveRequest{
		ReservationID: rid,
		SKU:           in.GetSku(),
		StoreID:       in.GetStoreId().GetValue(),
		CounterID:     in.GetCounterId().GetValue(),
		Quantity:      in.GetQuantity(),
	})
	if err != nil {
		return nil, toConnectErr(err)
	}
	return connect.NewResponse(&posv1.ReserveResponse{
		Reservation:  reservationToProto(out.Reservation),
		AvailableQty: out.Available,
	}), nil
}

// Release cancels a hold. Idempotent on already-released rows.
func (h *ReservationHandler) Release(
	ctx context.Context,
	req *connect.Request[posv1.ReleaseRequest],
) (*connect.Response[posv1.ReleaseResponse], error) {
	idStr := req.Msg.GetReservationId()
	if idStr == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument,
			errors.New("reservation_id: required"))
	}
	id, err := uuid.Parse(idStr)
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, err)
	}
	if err := h.svc.Release(ctx, id); err != nil {
		return nil, toConnectErr(err)
	}
	// Echo the row's post-release state so the client can refresh its UI.
	r, err := h.svc.Get(ctx, id)
	if err != nil {
		return nil, toConnectErr(err)
	}
	return connect.NewResponse(&posv1.ReleaseResponse{
		Reservation: reservationToProto(r),
	}), nil
}

func reservationToProto(r reservations.Reservation) *posv1.Reservation {
	return &posv1.Reservation{
		ReservationId: r.ID.String(),
		Sku:           r.SKU,
		StoreId:       &posv1.StoreId{Value: r.StoreID},
		CounterId:     &posv1.CounterId{Value: r.CounterID},
		Quantity:      r.Quantity,
		CreatedAt:     timestamppb.New(r.CreatedAt),
		ExpiresAt:     timestamppb.New(r.ExpiresAt),
		Status:        string(r.Status),
	}
}
