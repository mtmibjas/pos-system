import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { AuthProvider } from './auth/AuthContext'
import { LoginPage } from './auth/LoginPage'
import { RequireAuth } from './auth/RequireAuth'
import { CatalogPage } from './features/catalog/CatalogPage'
import { PlatformPage } from './features/platform/PlatformPage'
import { BrowsePage } from './features/reports/BrowsePage'
import { TodayPage } from './features/reports/TodayPage'
import { UsersPage } from './features/users/UsersPage'
import { Layout } from './ui/Layout'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: { retry: 1, staleTime: 15_000, refetchOnWindowFocus: false },
  },
})

export function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <AuthProvider>
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route element={<RequireAuth />}>
              <Route element={<Layout />}>
                <Route index element={<TodayPage />} />
                <Route path="browse" element={<BrowsePage />} />
                <Route path="users" element={<UsersPage />} />
                <Route path="catalog" element={<CatalogPage />} />
                <Route path="platform" element={<PlatformPage />} />
              </Route>
            </Route>
          </Routes>
        </AuthProvider>
      </BrowserRouter>
    </QueryClientProvider>
  )
}
