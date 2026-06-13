import { describe, expect, it } from 'vitest'
import { addMoney, formatMoney, parseMoney } from '../ui/money'

describe('parseMoney', () => {
  it('parses whole and fractional amounts', () => {
    expect(parseMoney('12', 'USD')).toEqual({ currency_code: 'USD', units: 12, nanos: 0 })
    expect(parseMoney('12.5', 'USD')).toEqual({
      currency_code: 'USD',
      units: 12,
      nanos: 500_000_000,
    })
    expect(parseMoney('12.05', 'USD')).toEqual({
      currency_code: 'USD',
      units: 12,
      nanos: 50_000_000,
    })
  })
  it('rejects junk', () => {
    expect(parseMoney('', 'USD')).toBeNull()
    expect(parseMoney('-1', 'USD')).toBeNull()
    expect(parseMoney('1.234', 'USD')).toBeNull()
    expect(parseMoney('1,50', 'USD')).toBeNull()
    expect(parseMoney('abc', 'USD')).toBeNull()
  })
})

describe('formatMoney', () => {
  it('formats whole units with currency code', () => {
    expect(formatMoney({ currency_code: 'USD', units: 1234, nanos: 0 })).toBe('USD 1,234.00')
  })
  it('formats nanos as cents', () => {
    expect(formatMoney({ currency_code: 'USD', units: 5, nanos: 500_000_000 })).toBe('USD 5.50')
  })
  it('handles negative amounts', () => {
    expect(formatMoney({ currency_code: 'USD', units: -3, nanos: -250_000_000 })).toBe(
      '-USD 3.25',
    )
  })
  it('omits prefix when currency empty', () => {
    expect(formatMoney({ currency_code: '', units: 0, nanos: 0 })).toBe('0.00')
  })
  it('rounds nanos to hundredths', () => {
    expect(formatMoney({ currency_code: 'USD', units: 1, nanos: 999_999_999 })).toBe('USD 2.00')
  })
})

describe('addMoney', () => {
  it('carries nanos overflow into units', () => {
    const sum = addMoney(
      { currency_code: 'USD', units: 1, nanos: 600_000_000 },
      { currency_code: 'USD', units: 2, nanos: 700_000_000 },
    )
    expect(sum).toEqual({ currency_code: 'USD', units: 4, nanos: 300_000_000 })
  })
})
