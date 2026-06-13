// Catalog edit intents — slice 6.6 client side. An edit POSTs an
// intent; stores apply and ack; status arrives via the edits list and
// the refreshed snapshot.

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { api } from '../../api/client'
import type { Money } from '../../api/types'

export interface ItemEditPayload {
  sku: string
  name: string
  price: Money
  tax_category_id?: string
  archived: boolean
}

export interface TaxCategoryEditPayload {
  id: string
  name: string
  price_includes_tax: boolean
  archived: boolean
}

export interface EditAck {
  node_id: string
  status: 'applied' | 'conflict'
  detail?: string
  acked_at: string
}

export interface EditWithAcks {
  seq: number
  edit_id: string
  kind: string
  payload: ItemEditPayload | TaxCategoryEditPayload
  created_by: string
  created_at: string
  acks: EditAck[]
}

export function useCatalogEdits() {
  return useQuery({
    queryKey: ['catalog-edits'],
    queryFn: () => api.get<{ edits: EditWithAcks[] }>('/v1/admin/catalog/edits'),
    // Edits land on stores within ~30s; poll so acks appear without a
    // manual refresh while the panel is on screen.
    refetchInterval: 10_000,
  })
}

export function useCreateEdit() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (edit: { kind: string; payload: ItemEditPayload | TaxCategoryEditPayload }) =>
      api.post<{ seq: number; edit_id: string }>('/v1/admin/catalog/edits', edit),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['catalog-edits'] })
      // Snapshot refreshes too (post-apply re-upload) — invalidate so
      // the table picks it up on the next poll/focus.
      qc.invalidateQueries({ queryKey: ['admin-catalog'] })
    },
  })
}
