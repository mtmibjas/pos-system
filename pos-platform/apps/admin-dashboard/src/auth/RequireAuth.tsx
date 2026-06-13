import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { useAuth } from './AuthContext'

// Route guard: unauthenticated → /login, remembering where the user
// was headed so login can bounce them back.
export function RequireAuth() {
  const { session } = useAuth()
  const location = useLocation()
  if (!session) {
    return <Navigate to="/login" state={{ from: location.pathname }} replace />
  }
  return <Outlet />
}
