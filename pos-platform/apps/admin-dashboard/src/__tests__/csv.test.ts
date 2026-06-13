import { describe, expect, it } from 'vitest'
import { toCsv } from '../ui/csv'

describe('toCsv', () => {
  it('joins headers and rows', () => {
    expect(toCsv(['a', 'b'], [['1', '2']])).toBe('a,b\n1,2\n')
  })
  it('quotes fields containing commas and quotes', () => {
    expect(toCsv(['x'], [['hello, "world"']])).toBe('x\n"hello, ""world"""\n')
  })
  it('quotes embedded newlines', () => {
    expect(toCsv(['x'], [['line1\nline2']])).toBe('x\n"line1\nline2"\n')
  })
})
