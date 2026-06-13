import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { api } from '../../api/client'
import type { UserRecord } from '../../api/types'
import { useAuth } from '../../auth/AuthContext'

const ROLE_OPTIONS = ['owner', 'cashier']

export function UsersPage() {
  const qc = useQueryClient()
  const { session } = useAuth()
  const me = mySubject(session?.token)

  const list = useQuery({
    queryKey: ['admin-users'],
    queryFn: () => api.get<{ users: UserRecord[] }>('/v1/admin/users'),
  })

  const invalidate = () => qc.invalidateQueries({ queryKey: ['admin-users'] })

  const toggleDisabled = useMutation({
    mutationFn: (u: UserRecord) =>
      api.patch<UserRecord>(`/v1/admin/users/${encodeURIComponent(u.username)}`, {
        disabled: !u.disabled,
      }),
    onSuccess: invalidate,
  })

  const resetPassword = useMutation({
    mutationFn: ({ username, password }: { username: string; password: string }) =>
      api.patch<UserRecord>(`/v1/admin/users/${encodeURIComponent(username)}`, { password }),
  })

  const users = list.data?.users ?? []

  return (
    <div className="space-y-6">
      <div className="bg-white rounded-xl shadow-sm overflow-hidden">
        <div className="px-4 py-3 border-b border-slate-100 font-medium text-slate-800">
          Users
        </div>
        {list.isLoading ? (
          <p className="p-6 text-slate-500">Loading…</p>
        ) : list.isError ? (
          <p className="p-6 text-red-600">{(list.error as Error).message}</p>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-slate-50 text-left text-slate-500">
              <tr>
                <th className="px-4 py-2 font-medium">Username</th>
                <th className="px-4 py-2 font-medium">Roles</th>
                <th className="px-4 py-2 font-medium">Status</th>
                <th className="px-4 py-2 font-medium text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {users.map((u) => (
                <UserRow
                  key={u.username}
                  user={u}
                  isSelf={u.username === me}
                  onToggle={() => toggleDisabled.mutate(u)}
                  onResetPassword={(pw) =>
                    resetPassword.mutateAsync({ username: u.username, password: pw })
                  }
                />
              ))}
            </tbody>
          </table>
        )}
      </div>

      <CreateUserCard onCreated={invalidate} />
    </div>
  )
}

function UserRow({
  user,
  isSelf,
  onToggle,
  onResetPassword,
}: {
  user: UserRecord
  isSelf: boolean
  onToggle: () => void
  onResetPassword: (pw: string) => Promise<unknown>
}) {
  const [resetting, setResetting] = useState(false)
  const [pw, setPw] = useState('')
  const [msg, setMsg] = useState<string | null>(null)

  async function submitReset(e: FormEvent) {
    e.preventDefault()
    setMsg(null)
    try {
      await onResetPassword(pw)
      setMsg('password updated')
      setPw('')
      setResetting(false)
    } catch (err) {
      setMsg(err instanceof Error ? err.message : 'failed')
    }
  }

  return (
    <tr className="border-t border-slate-100 align-top">
      <td className="px-4 py-2">
        {user.username}
        {isSelf && <span className="ml-2 text-xs text-slate-400">(you)</span>}
      </td>
      <td className="px-4 py-2">{user.roles.join(', ') || '—'}</td>
      <td className="px-4 py-2">
        {user.disabled ? (
          <span className="text-red-600">disabled</span>
        ) : (
          <span className="text-green-700">active</span>
        )}
      </td>
      <td className="px-4 py-2 text-right space-x-3 whitespace-nowrap">
        {!isSelf && (
          <button onClick={onToggle} className="text-slate-600 underline hover:text-slate-900">
            {user.disabled ? 'Enable' : 'Disable'}
          </button>
        )}
        <button
          onClick={() => setResetting((v) => !v)}
          className="text-slate-600 underline hover:text-slate-900"
        >
          Reset password
        </button>
        {resetting && (
          <form onSubmit={submitReset} className="mt-2 flex gap-2 justify-end">
            <input
              type="password"
              value={pw}
              onChange={(e) => setPw(e.target.value)}
              placeholder="new password (8+ chars)"
              minLength={8}
              required
              className="border border-slate-300 rounded px-2 py-1 text-sm w-48"
            />
            <button type="submit" className="text-sm rounded bg-teal-600 text-white px-3 py-1">
              Save
            </button>
          </form>
        )}
        {msg && <p className="text-xs text-slate-500 mt-1">{msg}</p>}
      </td>
    </tr>
  )
}

function CreateUserCard({ onCreated }: { onCreated: () => void }) {
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [roles, setRoles] = useState<string[]>(['cashier'])
  const [error, setError] = useState<string | null>(null)

  const create = useMutation({
    mutationFn: () => api.post<UserRecord>('/v1/admin/users', { username, password, roles }),
    onSuccess: () => {
      setUsername('')
      setPassword('')
      setRoles(['cashier'])
      setError(null)
      onCreated()
    },
    onError: (err) => setError(err instanceof Error ? err.message : 'create failed'),
  })

  function toggleRole(r: string) {
    setRoles((cur) => (cur.includes(r) ? cur.filter((x) => x !== r) : [...cur, r]))
  }

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault()
        create.mutate()
      }}
      className="bg-white rounded-xl shadow-sm p-4 space-y-3"
    >
      <h2 className="font-medium text-slate-800">Add user</h2>
      <div className="flex flex-wrap gap-3 items-end">
        <label className="text-sm">
          <span className="block text-slate-500">Username</span>
          <input
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            required
            className="border border-slate-300 rounded px-2 py-1.5 w-56"
          />
        </label>
        <label className="text-sm">
          <span className="block text-slate-500">Password</span>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            minLength={8}
            required
            className="border border-slate-300 rounded px-2 py-1.5 w-56"
          />
        </label>
        <fieldset className="text-sm">
          <span className="block text-slate-500">Roles</span>
          <div className="flex gap-3 mt-1.5">
            {ROLE_OPTIONS.map((r) => (
              <label key={r} className="flex items-center gap-1">
                <input
                  type="checkbox"
                  checked={roles.includes(r)}
                  onChange={() => toggleRole(r)}
                />
                {r}
              </label>
            ))}
          </div>
        </fieldset>
        <button
          type="submit"
          disabled={create.isPending}
          className="rounded bg-teal-600 text-white px-4 py-1.5 text-sm font-medium hover:bg-teal-700 disabled:opacity-50"
        >
          Create
        </button>
      </div>
      {error && <p className="text-sm text-red-600">{error}</p>}
    </form>
  )
}

// Decode the JWT payload to find our own username (sub claim) so the
// UI can hide self-lockout actions. Display-only — authorization is
// enforced server-side.
function mySubject(token?: string): string {
  if (!token) return ''
  try {
    const payload = JSON.parse(atob(token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')))
    return typeof payload.sub === 'string' ? payload.sub : ''
  } catch {
    return ''
  }
}
