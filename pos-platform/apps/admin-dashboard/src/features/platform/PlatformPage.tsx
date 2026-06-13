// Platform-admin area — slice 6.7. Only reachable by tokens carrying
// the platform_admin role; the server enforces this, the nav merely
// hides the entry for everyone else.

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { api } from '../../api/client'
import type { UserRecord } from '../../api/types'

interface TenantUsage {
  user_count: number
  event_count: number
  node_count: number
  last_event?: string
}

interface Tenant {
  tenant_id: string
  name: string
  status: 'active' | 'suspended'
  created_at: string
  usage: TenantUsage
}

export function PlatformPage() {
  const qc = useQueryClient()
  const [expanded, setExpanded] = useState<string | null>(null)

  const list = useQuery({
    queryKey: ['platform-tenants'],
    queryFn: () => api.get<{ tenants: Tenant[] }>('/v1/platform/tenants'),
  })

  const setStatus = useMutation({
    mutationFn: ({ id, status }: { id: string; status: string }) =>
      api.patch<Tenant>(`/v1/platform/tenants/${encodeURIComponent(id)}`, { status }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['platform-tenants'] }),
  })

  if (list.isLoading) return <p className="text-slate-500">Loading…</p>
  if (list.isError) return <p className="text-red-600">{(list.error as Error).message}</p>

  const tenants = list.data?.tenants ?? []

  return (
    <div className="space-y-6">
      <div className="bg-white rounded-xl shadow-sm overflow-hidden">
        <div className="px-4 py-3 border-b border-slate-100 font-medium text-slate-800">
          Tenants
        </div>
        <table className="w-full text-sm">
          <thead className="bg-slate-50 text-left text-slate-500">
            <tr>
              <th className="px-4 py-2 font-medium">Tenant</th>
              <th className="px-4 py-2 font-medium">Status</th>
              <th className="px-4 py-2 font-medium text-right">Users</th>
              <th className="px-4 py-2 font-medium text-right">Events</th>
              <th className="px-4 py-2 font-medium text-right">Stores</th>
              <th className="px-4 py-2 font-medium">Last activity</th>
              <th className="px-4 py-2" />
            </tr>
          </thead>
          <tbody>
            {tenants.map((t) => (
              <>
                <tr key={t.tenant_id} className="border-t border-slate-100">
                  <td className="px-4 py-2">
                    <button
                      onClick={() =>
                        setExpanded(expanded === t.tenant_id ? null : t.tenant_id)
                      }
                      className="font-medium text-slate-800 hover:underline"
                    >
                      {t.tenant_id}
                    </button>
                    {t.name && t.name !== t.tenant_id && (
                      <span className="ml-2 text-slate-500">{t.name}</span>
                    )}
                  </td>
                  <td className="px-4 py-2">
                    {t.status === 'active' ? (
                      <span className="text-green-700">active</span>
                    ) : (
                      <span className="text-red-600">suspended</span>
                    )}
                  </td>
                  <td className="px-4 py-2 text-right">{t.usage.user_count}</td>
                  <td className="px-4 py-2 text-right">{t.usage.event_count}</td>
                  <td className="px-4 py-2 text-right">{t.usage.node_count}</td>
                  <td className="px-4 py-2 text-slate-600">
                    {t.usage.last_event ? new Date(t.usage.last_event).toLocaleString() : '—'}
                  </td>
                  <td className="px-4 py-2 text-right">
                    <button
                      onClick={() =>
                        setStatus.mutate({
                          id: t.tenant_id,
                          status: t.status === 'active' ? 'suspended' : 'active',
                        })
                      }
                      className="text-slate-600 underline hover:text-slate-900"
                    >
                      {t.status === 'active' ? 'Suspend' : 'Activate'}
                    </button>
                  </td>
                </tr>
                {expanded === t.tenant_id && (
                  <tr key={`${t.tenant_id}-users`} className="bg-slate-50">
                    <td colSpan={7} className="px-6 py-3">
                      <TenantUsers tenantId={t.tenant_id} />
                    </td>
                  </tr>
                )}
              </>
            ))}
            {tenants.length === 0 && (
              <tr>
                <td colSpan={7} className="px-4 py-3 text-slate-500">
                  No tenants yet
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <CreateTenantCard onCreated={() => qc.invalidateQueries({ queryKey: ['platform-tenants'] })} />

      <p className="text-xs text-slate-400">
        Suspending a tenant blocks logins and sync ingestion immediately; stores keep
        operating offline on local data. There is no delete — suspended tenants keep their
        data and ids (retention/offboarding is a production-phase concern).
      </p>
    </div>
  )
}

function TenantUsers({ tenantId }: { tenantId: string }) {
  const q = useQuery({
    queryKey: ['platform-tenant-users', tenantId],
    queryFn: () =>
      api.get<{ users: UserRecord[] }>(
        `/v1/platform/tenants/${encodeURIComponent(tenantId)}/users`,
      ),
  })
  if (q.isLoading) return <p className="text-slate-500 text-sm">Loading users…</p>
  if (q.isError) return <p className="text-red-600 text-sm">{(q.error as Error).message}</p>
  const users = q.data?.users ?? []
  if (users.length === 0) return <p className="text-slate-500 text-sm">No users</p>
  return (
    <ul className="text-sm space-y-1">
      {users.map((u) => (
        <li key={u.username}>
          <span className="font-mono">{u.username}</span>
          <span className="text-slate-500"> — {u.roles.join(', ') || 'no roles'}</span>
          {u.disabled && <span className="text-red-600"> (disabled)</span>}
        </li>
      ))}
    </ul>
  )
}

function CreateTenantCard({ onCreated }: { onCreated: () => void }) {
  const [id, setId] = useState('')
  const [name, setName] = useState('')
  const [error, setError] = useState<string | null>(null)

  const create = useMutation({
    mutationFn: () => api.post('/v1/platform/tenants', { tenant_id: id.trim(), name: name.trim() }),
    onSuccess: () => {
      setId('')
      setName('')
      setError(null)
      onCreated()
    },
    onError: (err) => setError(err instanceof Error ? err.message : 'create failed'),
  })

  function submit(e: FormEvent) {
    e.preventDefault()
    create.mutate()
  }

  return (
    <form onSubmit={submit} className="bg-white rounded-xl shadow-sm p-4 space-y-3">
      <h2 className="font-medium text-slate-800">Create tenant</h2>
      <div className="flex flex-wrap gap-3 items-end">
        <label className="text-sm">
          <span className="block text-slate-500">Tenant ID</span>
          <input
            value={id}
            onChange={(e) => setId(e.target.value)}
            placeholder="tenant-B"
            required
            className="border border-slate-300 rounded px-2 py-1.5 w-48"
          />
        </label>
        <label className="text-sm">
          <span className="block text-slate-500">Display name</span>
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="border border-slate-300 rounded px-2 py-1.5 w-64"
          />
        </label>
        <button
          type="submit"
          disabled={create.isPending}
          className="rounded bg-teal-600 text-white px-4 py-1.5 text-sm font-medium hover:bg-teal-700 disabled:opacity-50"
        >
          Create
        </button>
      </div>
      {error && <p className="text-sm text-red-600">{error}</p>}
      <p className="text-xs text-slate-400">
        After creating: add an owner user for it (Users page of that tenant comes after
        their first login, or seed via cmd/seed-dev + hand-merge into the DB).
      </p>
    </form>
  )
}
