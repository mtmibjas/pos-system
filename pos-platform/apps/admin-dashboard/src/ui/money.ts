import type { Money } from '../api/types'

// Format integer units+nanos without float math on the value itself.
// nanos is always < 1e9; two decimal places is enough for retail
// currencies in scope (matches mobile-owner's money_format).
export function formatMoney(m: Money): string {
  const negative = m.units < 0 || m.nanos < 0
  const units = Math.abs(m.units)
  const cents = Math.round(Math.abs(m.nanos) / 1e7) // nanos → hundredths
  const carry = cents >= 100 ? 1 : 0
  const c = cents % 100
  const whole = (units + carry).toLocaleString('en-US')
  const sign = negative ? '-' : ''
  const code = m.currency_code ? `${m.currency_code} ` : ''
  return `${sign}${code}${whole}.${String(c).padStart(2, '0')}`
}

// Parse a user-typed decimal ("12.50") into units+nanos without float
// math. Returns null on anything that isn't a plain non-negative
// decimal with ≤2 fraction digits.
export function parseMoney(input: string, currencyCode: string): Money | null {
  const m = /^(\d+)(?:\.(\d{1,2}))?$/.exec(input.trim())
  if (!m) return null
  const units = Number(m[1])
  if (!Number.isSafeInteger(units)) return null
  const frac = (m[2] ?? '').padEnd(2, '0')
  return { currency_code: currencyCode, units, nanos: Number(frac) * 1e7 }
}

export function addMoney(a: Money, b: Money): Money {
  let nanos = a.nanos + b.nanos
  let units = a.units + b.units
  if (nanos >= 1e9) {
    units += 1
    nanos -= 1e9
  } else if (nanos <= -1e9) {
    units -= 1
    nanos += 1e9
  }
  return { currency_code: a.currency_code || b.currency_code, units, nanos }
}
