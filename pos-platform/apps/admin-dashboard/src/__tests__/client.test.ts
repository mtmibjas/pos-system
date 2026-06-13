import { afterEach, describe, expect, it, vi } from 'vitest'
import { api, ApiError, configureClient } from '../api/client'

function mockFetch(status: number, body: unknown) {
  const fn = vi.fn(async () => ({
    ok: status >= 200 && status < 300,
    status,
    statusText: `status ${status}`,
    json: async () => body,
  }))
  vi.stubGlobal('fetch', fn)
  return fn
}

afterEach(() => vi.unstubAllGlobals())

describe('api client', () => {
  it('injects bearer token from the configured source', async () => {
    const fetchFn = mockFetch(200, { ok: true })
    configureClient({ getToken: () => 'tok-123', onUnauthorized: () => {} })

    await api.get('/v1/test')
    const [, init] = fetchFn.mock.calls[0] as unknown as [string, RequestInit]
    expect(new Headers(init.headers).get('Authorization')).toBe('Bearer tok-123')
  })

  it('fires onUnauthorized and throws on 401', async () => {
    mockFetch(401, { error: 'expired' })
    const onUnauthorized = vi.fn()
    configureClient({ getToken: () => 'stale', onUnauthorized })

    await expect(api.get('/v1/test')).rejects.toThrow('session expired')
    expect(onUnauthorized).toHaveBeenCalledOnce()
  })

  it('maps error envelope to ApiError message', async () => {
    mockFetch(409, { error: 'username already taken' })
    configureClient({ getToken: () => null, onUnauthorized: () => {} })

    try {
      await api.post('/v1/admin/users', {})
      expect.unreachable()
    } catch (e) {
      expect(e).toBeInstanceOf(ApiError)
      expect((e as ApiError).status).toBe(409)
      expect((e as ApiError).message).toBe('username already taken')
    }
  })
})
