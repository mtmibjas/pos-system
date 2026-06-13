// Typed fetch wrapper. Token injection + uniform error mapping; 401
// triggers the onUnauthorized callback (wired to signOut in App.tsx)
// so an expired token anywhere routes back to login — same pattern as
// mobile-owner.

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message)
  }
}

type TokenSource = () => string | null
let getToken: TokenSource = () => null
let onUnauthorized: () => void = () => {}

export function configureClient(opts: { getToken: TokenSource; onUnauthorized: () => void }) {
  getToken = opts.getToken
  onUnauthorized = opts.onUnauthorized
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const headers = new Headers(init?.headers)
  headers.set('Accept', 'application/json')
  if (init?.body) headers.set('Content-Type', 'application/json')
  const token = getToken()
  if (token) headers.set('Authorization', `Bearer ${token}`)

  const resp = await fetch(path, { ...init, headers })
  if (resp.status === 401) {
    onUnauthorized()
    throw new ApiError(401, 'session expired')
  }
  if (!resp.ok) {
    let msg = resp.statusText
    try {
      const body = await resp.json()
      if (typeof body?.error === 'string') msg = body.error
    } catch {
      /* non-JSON error body — keep statusText */
    }
    throw new ApiError(resp.status, msg)
  }
  return (await resp.json()) as T
}

export const api = {
  get: <T>(path: string) => request<T>(path),
  post: <T>(path: string, body: unknown) =>
    request<T>(path, { method: 'POST', body: JSON.stringify(body) }),
  patch: <T>(path: string, body: unknown) =>
    request<T>(path, { method: 'PATCH', body: JSON.stringify(body) }),
}

// login is special: no token injection, no 401-redirect (a wrong
// password on the login page must show inline, not bounce the route).
export async function loginRequest(username: string, password: string) {
  const resp = await fetch('/v1/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify({ username, password }),
  })
  if (!resp.ok) {
    // The vite dev proxy answers 502/504 with an HTML body when
    // cloud-api is down — surface that as "unreachable", not a generic
    // failure the operator will misread as a wrong password.
    let msg =
      resp.status === 502 || resp.status === 504
        ? 'cloud-api unreachable — is the server running?'
        : `login failed (${resp.status})`
    try {
      const body = await resp.json()
      if (typeof body?.error === 'string') msg = body.error
    } catch {
      /* keep status-based message */
    }
    throw new ApiError(resp.status, msg)
  }
  return (await resp.json()) as import('./types').LoginResponse
}
