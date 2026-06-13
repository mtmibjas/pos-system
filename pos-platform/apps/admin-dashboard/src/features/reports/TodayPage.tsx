import { ZERO_MONEY } from '../../api/types'
import { formatMoney } from '../../ui/money'
import { isoDate, useSalesByMethod, useSalesSummary } from './queries'

const METHOD_LABELS: Record<string, string> = {
  cash: 'Cash',
  card: 'Card',
  upi: 'UPI',
}

export function TodayPage() {
  const today = isoDate(new Date())
  const summary = useSalesSummary(today)
  const methods = useSalesByMethod(today)

  if (summary.isLoading || methods.isLoading) {
    return <p className="text-slate-500">Loading…</p>
  }
  if (summary.isError || methods.isError) {
    const err = (summary.error ?? methods.error) as Error
    return <p className="text-red-600">Could not load today: {err.message}</p>
  }

  const bucket = summary.data?.buckets?.[0]
  const revenue = bucket?.revenue ?? ZERO_MONEY
  const tax = bucket?.tax ?? ZERO_MONEY
  const grand = bucket?.grand_total ?? ZERO_MONEY
  const methodRows = methods.data?.buckets ?? []

  return (
    <div className="space-y-6">
      <div className="bg-white rounded-xl shadow-sm p-6">
        <p className="text-sm text-slate-500">{today}</p>
        <p className="text-4xl font-semibold text-slate-900 mt-2">{formatMoney(grand)}</p>
        <p className="text-sm text-slate-500">Grand total</p>
        <div className="border-t border-slate-100 mt-4 pt-4 grid grid-cols-2 gap-4 text-sm">
          <div className="flex justify-between">
            <span className="text-slate-600">Revenue</span>
            <span>{formatMoney(revenue)}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-slate-600">Tax</span>
            <span>{formatMoney(tax)}</span>
          </div>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm p-6">
        <h2 className="font-medium text-slate-800 mb-3">Payments</h2>
        {methodRows.length === 0 ? (
          <p className="text-sm text-slate-500">No payments today</p>
        ) : (
          <table className="w-full text-sm">
            <tbody>
              {methodRows.map((m) => (
                <tr key={m.method} className="border-t border-slate-100 first:border-0">
                  <td className="py-2 text-slate-600">{METHOD_LABELS[m.method] ?? 'Other'}</td>
                  <td className="py-2 text-right">{formatMoney(m.amount)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}
