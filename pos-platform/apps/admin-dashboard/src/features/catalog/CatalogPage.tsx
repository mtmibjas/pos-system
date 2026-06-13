import { useQuery } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { api } from '../../api/client'
import type { Money } from '../../api/types'
import { formatMoney, parseMoney } from '../../ui/money'
import {
  useCatalogEdits,
  useCreateEdit,
  type EditWithAcks,
  type ItemEditPayload,
} from './edits'

// Mirrors local-store-server's catalogsync.Snapshot JSON.
interface CatalogItem {
  sku: string
  name: string
  price: Money
  tax_category_id?: string
  archived: boolean
}

interface TaxCategory {
  id: string
  name: string
  price_includes_tax: boolean
  archived: boolean
}

interface Snapshot {
  node_id: string
  updated_at: string
  payload: {
    captured_at: string
    items: CatalogItem[]
    tax_categories: TaxCategory[]
  }
}

export function CatalogPage() {
  const [showArchived, setShowArchived] = useState(false)
  const [editing, setEditing] = useState<CatalogItem | null>(null)
  const [adding, setAdding] = useState(false)
  const q = useQuery({
    queryKey: ['admin-catalog'],
    queryFn: () => api.get<{ snapshots: Snapshot[] }>('/v1/admin/catalog'),
    refetchInterval: 10_000,
  })

  if (q.isLoading) return <p className="text-slate-500">Loading…</p>
  if (q.isError) return <p className="text-red-600">{(q.error as Error).message}</p>

  const snapshots = q.data?.snapshots ?? []
  // Tax categories from the first snapshot drive the edit dialogs'
  // dropdown (tenant catalogs are shared across nodes by design).
  const taxCategories = snapshots[0]?.payload.tax_categories ?? []

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <label className="flex items-center gap-2 text-sm text-slate-600">
          <input
            type="checkbox"
            checked={showArchived}
            onChange={(e) => setShowArchived(e.target.checked)}
          />
          Show archived
        </label>
        <button
          onClick={() => setAdding(true)}
          className="ml-auto rounded bg-teal-600 text-white px-4 py-1.5 text-sm font-medium hover:bg-teal-700"
        >
          Add item
        </button>
      </div>

      {snapshots.length === 0 ? (
        <div className="bg-white rounded-xl shadow-sm p-6 text-slate-500">
          <p>No catalog snapshots yet.</p>
          <p className="text-sm mt-2">
            Each store uploads its catalog a few seconds after boot. Check that
            local-store-server is running and can reach cloud-api.
          </p>
        </div>
      ) : (
        snapshots.map((s) => (
          <NodeCatalog
            key={s.node_id}
            snapshot={s}
            showArchived={showArchived}
            onEdit={setEditing}
          />
        ))
      )}

      <PendingEdits />

      {editing && (
        <ItemDialog
          title={`Edit ${editing.sku}`}
          initial={editing}
          skuLocked
          taxCategories={taxCategories}
          onClose={() => setEditing(null)}
        />
      )}
      {adding && (
        <ItemDialog
          title="Add item"
          initial={null}
          skuLocked={false}
          taxCategories={taxCategories}
          onClose={() => setAdding(false)}
        />
      )}
    </div>
  )
}

function NodeCatalog({
  snapshot,
  showArchived,
  onEdit,
}: {
  snapshot: Snapshot
  showArchived: boolean
  onEdit: (i: CatalogItem) => void
}) {
  const items = (snapshot.payload.items ?? []).filter((i) => showArchived || !i.archived)
  const taxes = (snapshot.payload.tax_categories ?? []).filter(
    (t) => showArchived || !t.archived,
  )
  return (
    <div className="bg-white rounded-xl shadow-sm overflow-hidden">
      <div className="px-4 py-3 border-b border-slate-100 flex items-baseline gap-3">
        <span className="font-medium text-slate-800">{snapshot.node_id}</span>
        <span className="text-xs text-slate-400">
          updated {new Date(snapshot.updated_at).toLocaleString()}
        </span>
      </div>
      <table className="w-full text-sm">
        <thead className="bg-slate-50 text-left text-slate-500">
          <tr>
            <th className="px-4 py-2 font-medium">SKU</th>
            <th className="px-4 py-2 font-medium">Name</th>
            <th className="px-4 py-2 font-medium text-right">Price</th>
            <th className="px-4 py-2 font-medium">Tax category</th>
            <th className="px-4 py-2" />
          </tr>
        </thead>
        <tbody>
          {items.map((i) => (
            <tr
              key={i.sku}
              className={`border-t border-slate-100 ${i.archived ? 'opacity-50' : ''}`}
            >
              <td className="px-4 py-2 font-mono text-xs">{i.sku}</td>
              <td className="px-4 py-2">
                {i.name}
                {i.archived && <span className="ml-2 text-xs text-slate-400">archived</span>}
              </td>
              <td className="px-4 py-2 text-right">{formatMoney(i.price)}</td>
              <td className="px-4 py-2">{i.tax_category_id || '—'}</td>
              <td className="px-4 py-2 text-right">
                <button
                  onClick={() => onEdit(i)}
                  className="text-slate-600 underline hover:text-slate-900"
                >
                  Edit
                </button>
              </td>
            </tr>
          ))}
          {items.length === 0 && (
            <tr>
              <td colSpan={5} className="px-4 py-3 text-slate-500">
                No items
              </td>
            </tr>
          )}
        </tbody>
      </table>
      {taxes.length > 0 && (
        <div className="px-4 py-3 border-t border-slate-100 text-sm text-slate-600">
          <span className="font-medium">Tax categories: </span>
          {taxes
            .map((t) => `${t.id} (${t.name}${t.price_includes_tax ? ', inclusive' : ''})`)
            .join(' · ')}
        </div>
      )}
    </div>
  )
}

function ItemDialog({
  title,
  initial,
  skuLocked,
  taxCategories,
  onClose,
}: {
  title: string
  initial: CatalogItem | null
  skuLocked: boolean
  taxCategories: TaxCategory[]
  onClose: () => void
}) {
  const create = useCreateEdit()
  const currency = initial?.price.currency_code || 'USD'
  const [sku, setSku] = useState(initial?.sku ?? '')
  const [name, setName] = useState(initial?.name ?? '')
  const [price, setPrice] = useState(
    initial ? formatMoney(initial.price).replace(`${currency} `, '').replace(/,/g, '') : '',
  )
  const [taxId, setTaxId] = useState(initial?.tax_category_id ?? '')
  const [archived, setArchived] = useState(initial?.archived ?? false)
  const [error, setError] = useState<string | null>(null)

  async function submit(e: FormEvent) {
    e.preventDefault()
    const money = parseMoney(price, currency)
    if (!money) {
      setError('price must be a plain decimal like 12.50')
      return
    }
    const payload: ItemEditPayload = {
      sku: sku.trim(),
      name: name.trim(),
      price: money,
      tax_category_id: taxId || undefined,
      archived,
    }
    try {
      await create.mutateAsync({ kind: 'upsert_item', payload })
      onClose()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'failed')
    }
  }

  return (
    <div className="fixed inset-0 bg-black/30 flex items-center justify-center z-10">
      <form onSubmit={submit} className="bg-white rounded-xl shadow-lg p-6 w-full max-w-md space-y-3">
        <h2 className="font-medium text-slate-800">{title}</h2>
        <label className="block text-sm">
          <span className="text-slate-500">SKU</span>
          <input
            value={sku}
            onChange={(e) => setSku(e.target.value)}
            disabled={skuLocked}
            required
            className="mt-1 w-full border border-slate-300 rounded px-2 py-1.5 disabled:bg-slate-100"
          />
        </label>
        <label className="block text-sm">
          <span className="text-slate-500">Name</span>
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            required
            className="mt-1 w-full border border-slate-300 rounded px-2 py-1.5"
          />
        </label>
        <label className="block text-sm">
          <span className="text-slate-500">Price ({currency})</span>
          <input
            value={price}
            onChange={(e) => setPrice(e.target.value)}
            placeholder="12.50"
            required
            className="mt-1 w-full border border-slate-300 rounded px-2 py-1.5"
          />
        </label>
        <label className="block text-sm">
          <span className="text-slate-500">Tax category</span>
          <select
            value={taxId}
            onChange={(e) => setTaxId(e.target.value)}
            className="mt-1 w-full border border-slate-300 rounded px-2 py-1.5"
          >
            <option value="">Exempt (none)</option>
            {taxCategories
              .filter((t) => !t.archived)
              .map((t) => (
                <option key={t.id} value={t.id}>
                  {t.id} — {t.name}
                </option>
              ))}
          </select>
        </label>
        <label className="flex items-center gap-2 text-sm text-slate-600">
          <input
            type="checkbox"
            checked={archived}
            onChange={(e) => setArchived(e.target.checked)}
          />
          Archived (hidden from POS)
        </label>
        {error && <p className="text-sm text-red-600">{error}</p>}
        <div className="flex justify-end gap-3 pt-2">
          <button type="button" onClick={onClose} className="text-sm text-slate-600 underline">
            Cancel
          </button>
          <button
            type="submit"
            disabled={create.isPending}
            className="rounded bg-teal-600 text-white px-4 py-1.5 text-sm font-medium hover:bg-teal-700 disabled:opacity-50"
          >
            Save change
          </button>
        </div>
        <p className="text-xs text-slate-400">
          Saves as a pending change; each store applies it within ~30 s and the
          table refreshes from the store's own data.
        </p>
      </form>
    </div>
  )
}

function PendingEdits() {
  const q = useCatalogEdits()
  const edits = q.data?.edits ?? []
  if (edits.length === 0) return null
  return (
    <div className="bg-white rounded-xl shadow-sm overflow-hidden">
      <div className="px-4 py-3 border-b border-slate-100 font-medium text-slate-800">
        Recent changes
      </div>
      <table className="w-full text-sm">
        <thead className="bg-slate-50 text-left text-slate-500">
          <tr>
            <th className="px-4 py-2 font-medium">Change</th>
            <th className="px-4 py-2 font-medium">By</th>
            <th className="px-4 py-2 font-medium">When</th>
            <th className="px-4 py-2 font-medium">Store status</th>
          </tr>
        </thead>
        <tbody>
          {edits.map((e) => (
            <tr key={e.seq} className="border-t border-slate-100 align-top">
              <td className="px-4 py-2">{describeEdit(e)}</td>
              <td className="px-4 py-2 text-slate-600">{e.created_by}</td>
              <td className="px-4 py-2 text-slate-600">
                {new Date(e.created_at).toLocaleString()}
              </td>
              <td className="px-4 py-2 space-y-1">
                {e.acks.length === 0 && <span className="text-amber-600">pending…</span>}
                {e.acks.map((a) => (
                  <div key={a.node_id}>
                    {a.status === 'applied' ? (
                      <span className="text-green-700">{a.node_id}: applied</span>
                    ) : (
                      <span className="text-red-600" title={a.detail}>
                        {a.node_id}: conflict — {a.detail}
                      </span>
                    )}
                  </div>
                ))}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

function describeEdit(e: EditWithAcks): string {
  if (e.kind === 'upsert_item') {
    const p = e.payload as ItemEditPayload
    return `${p.archived ? 'Archive' : 'Update'} item ${p.sku} — ${p.name}, ${formatMoney(p.price)}`
  }
  const p = e.payload as { id: string; name: string }
  return `Tax category ${p.id} — ${p.name}`
}
