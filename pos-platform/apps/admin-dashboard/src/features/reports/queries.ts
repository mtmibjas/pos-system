import { useQuery } from '@tanstack/react-query'
import { api } from '../../api/client'
import type { SalesByMethodBucket, SalesSummaryBucket, StoreSummary } from '../../api/types'

// Local-date ISO (YYYY-MM-DD) — matches cloud-api's ParseDateRange.
export function isoDate(d: Date): string {
  const y = String(d.getFullYear()).padStart(4, '0')
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

export function useSalesSummary(from: string, to?: string, period = 'day', storeId = '') {
  const params = new URLSearchParams({ from, period })
  if (to) params.set('to', to)
  if (storeId) params.set('store_id', storeId)
  return useQuery({
    queryKey: ['sales-summary', from, to, period, storeId],
    queryFn: () =>
      api.get<{ buckets: SalesSummaryBucket[] | null }>(
        `/v1/reports/sales-summary?${params}`,
      ),
  })
}

export function useSalesByMethod(from: string, to?: string) {
  const params = new URLSearchParams({ from })
  if (to) params.set('to', to)
  return useQuery({
    queryKey: ['sales-by-method', from, to],
    queryFn: () =>
      api.get<{ buckets: SalesByMethodBucket[] | null }>(
        `/v1/reports/sales-by-method?${params}`,
      ),
  })
}

export function useStores() {
  return useQuery({
    queryKey: ['stores'],
    queryFn: () => api.get<{ stores: StoreSummary[] | null }>('/v1/reports/stores'),
  })
}
