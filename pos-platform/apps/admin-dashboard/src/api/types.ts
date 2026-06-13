// Wire types — mirror cloud-api's JSON responses. Money is integer
// units+nanos (google.type.Money convention); never do float math on
// it, format via ui/money.ts.

export interface Money {
  currency_code: string
  units: number
  nanos: number
}

export interface LoginResponse {
  token: string
  expires_at: string
  tenant_id: string
  roles: string[]
}

export interface SalesSummaryBucket {
  period_start: string
  revenue: Money
  tax: Money
  grand_total: Money
}

export interface SalesByMethodBucket {
  period_start: string
  method: string
  amount: Money
}

export interface StoreSummary {
  store_id: string
  first_sale_date?: string
  last_sale_date?: string
}

export interface UserRecord {
  username: string
  tenant_id: string
  roles: string[]
  disabled: boolean
  created_at: string
  updated_at: string
}

export const ZERO_MONEY: Money = { currency_code: '', units: 0, nanos: 0 }
