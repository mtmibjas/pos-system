// Session state: token + tenant + roles, persisted to sessionStorage
// (survives reload, dies with the tab — UAT-grade tradeoff; httpOnly
// cookies are a production delta, see docs/admin-dashboard-plan.md §8).

import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react'
import { configureClient, loginRequest } from '../api/client'

const STORAGE_KEY = 'pos_admin_session_v1'

export interface Session {
  token: string
  tenantId: string
  roles: string[]
  expiresAt: string
}

interface AuthValue {
  session: Session | null
  signIn: (username: string, password: string) => Promise<void>
  signOut: () => void
}

const AuthContext = createContext<AuthValue | null>(null)

function loadSession(): Session | null {
  try {
    const raw = sessionStorage.getItem(STORAGE_KEY)
    if (!raw) return null
    const s = JSON.parse(raw) as Session
    if (!s.token) return null
    if (s.expiresAt && new Date(s.expiresAt) <= new Date()) return null
    return s
  } catch {
    return null
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(loadSession)

  const signOut = useCallback(() => {
    sessionStorage.removeItem(STORAGE_KEY)
    setSession(null)
  }, [])

  const signIn = useCallback(async (username: string, password: string) => {
    const resp = await loginRequest(username, password)
    const s: Session = {
      token: resp.token,
      tenantId: resp.tenant_id,
      roles: resp.roles,
      expiresAt: resp.expires_at,
    }
    sessionStorage.setItem(STORAGE_KEY, JSON.stringify(s))
    setSession(s)
  }, [])

  // The api client reads the token through this closure so React state
  // and request auth can never drift apart.
  configureClient({
    getToken: () => loadSession()?.token ?? null,
    onUnauthorized: signOut,
  })

  const value = useMemo(() => ({ session, signIn, signOut }), [session, signIn, signOut])
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(): AuthValue {
  const v = useContext(AuthContext)
  if (!v) throw new Error('useAuth outside AuthProvider')
  return v
}
