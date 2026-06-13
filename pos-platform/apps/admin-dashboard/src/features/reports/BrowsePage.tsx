import { useState } from 'react'
import { formatMoney } from '../../ui/money'
import { downloadCsv, toCsv } from '../../ui/csv'
import { isoDate, useSalesSummary, useStores } from './queries'

type Period = 'day' | 'week' | 'month'

function defaultFrom(period: Period): string {
  const d = new Date()
  if (period === 'day') d.setDate(d.getDate() - 13)
  if (period === 'week') d.setDate(d.getDate() - 7 * 11)
  if (period === 'month') d.setMonth(d.getMonth() - 11)
  return isoDate(d)
}

export function BrowsePage() {
  const [period, setPeriod] = useState<Period>('day')
  const [from, setFrom] = useState(() => defaultFrom('day'))
  const [to, setTo] = useState(() => isoDate(new Date()))
  const [storeId, setStoreId] = useState('')

  const stores = useStores()
  const summary = useSalesSummary(from, to, period, storeId)
  const buckets = summary.data?.buckets ?? []

  function changePeriod(p: Period) {
    setPeriod(p)
    setFrom(defaultFrom(p))
  }

  function exportCsv() {
    const csv = toCsv(
      ['period_start', 'revenue', 'tax', 'grand_total'],
      buckets.map((b) => [
        b.period_start,
        formatMoney(b.revenue),
        formatMoney(b.tax),
        formatMoney(b.grand_total),
      ]),
    )
    downloadCsv(`sales-${period}-${from}-${to}${storeId ? `-${storeId}` : ''}.csv`, csv)
  }

  return (
    <div className="space-y-4">
      <div className="bg-white rounded-xl shadow-sm p-4 flex flex-wrap items-end gap-4">
        <div className="flex rounded overflow-hidden border border-slate-300">
          {(['day', 'week', 'month'] as Period[]).map((p) => (
            <button
              key={p}
              onClick={() => changePeriod(p)}
              className={`px-3 py-1.5 text-sm capitalize ${
                period === p ? 'bg-teal-600 text-white' : 'bg-white text-slate-600'
              }`}
            >
              {p}
            </button>
          ))}
        </div>
        <label className="text-sm">
          <span className="block text-slate-500">From</span>
          <input
            type="date"
            value={from}
            onChange={(e) => setFrom(e.target.value)}
            className="border border-slate-300 rounded px-2 py-1"
          />
        </label>
        <label className="text-sm">
          <span className="block text-slate-500">To</span>
          <input
            type="date"
            value={to}
            onChange={(e) => setTo(e.target.value)}
            className="border border-slate-300 rounded px-2 py-1"
          />
        </label>
        <label className="text-sm">
          <span className="block text-slate-500">Store</span>
          <select
            value={storeId}
            onChange={(e) => setStoreId(e.target.value)}
            className="border border-slate-300 rounded px-2 py-1.5"
          >
            <option value="">All stores</option>
            {(stores.data?.stores ?? []).map((s) => (
              <option key={s.store_id} value={s.store_id}>
                {s.store_id}
              </option>
            ))}
          </select>
        </label>
        <button
          onClick={exportCsv}
          disabled={buckets.length === 0}
          className="ml-auto text-sm rounded border border-slate-300 px-3 py-1.5 hover:bg-slate-50 disabled:opacity-50"
        >
          Export CSV
        </button>
      </div>

      <div className="bg-white rounded-xl shadow-sm overflow-hidden">
        {summary.isLoading ? (
          <p className="p-6 text-slate-500">Loading…</p>
        ) : summary.isError ? (
          <p className="p-6 text-red-600">{(summary.error as Error).message}</p>
        ) : buckets.length === 0 ? (
          <p className="p-6 text-slate-500">No sales in this range</p>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-slate-50 text-left text-slate-500">
              <tr>
                <th className="px-4 py-2 font-medium">Period</th>
                <th className="px-4 py-2 font-medium text-right">Revenue</th>
                <th className="px-4 py-2 font-medium text-right">Tax</th>
                <th className="px-4 py-2 font-medium text-right">Grand total</th>
              </tr>
            </thead>
            <tbody>
              {buckets.map((b) => (
                <tr key={b.period_start} className="border-t border-slate-100">
                  <td className="px-4 py-2">{b.period_start}</td>
                  <td className="px-4 py-2 text-right">{formatMoney(b.revenue)}</td>
                  <td className="px-4 py-2 text-right">{formatMoney(b.tax)}</td>
                  <td className="px-4 py-2 text-right font-medium">
                    {formatMoney(b.grand_total)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}
