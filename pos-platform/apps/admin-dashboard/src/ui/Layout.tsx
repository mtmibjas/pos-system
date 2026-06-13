import { NavLink, Outlet } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'

const navItems = [
  { to: '/', label: 'Today' },
  { to: '/browse', label: 'Browse' },
  { to: '/users', label: 'Users' },
  { to: '/catalog', label: 'Catalog' },
]

export function Layout() {
  const { session, signOut } = useAuth()
  const items = session?.roles.includes('platform_admin')
    ? [...navItems, { to: '/platform', label: 'Platform' }]
    : navItems
  return (
    <div className="min-h-screen bg-slate-100">
      <header className="bg-white border-b border-slate-200">
        <div className="max-w-5xl mx-auto px-4 h-14 flex items-center gap-6">
          <span className="font-semibold text-slate-800">POS Admin</span>
          <nav className="flex gap-1">
            {items.map((n) => (
              <NavLink
                key={n.to}
                to={n.to}
                end={n.to === '/'}
                className={({ isActive }) =>
                  `px-3 py-1.5 rounded text-sm ${
                    isActive
                      ? 'bg-teal-50 text-teal-700 font-medium'
                      : 'text-slate-600 hover:bg-slate-100'
                  }`
                }
              >
                {n.label}
              </NavLink>
            ))}
          </nav>
          <div className="ml-auto flex items-center gap-3 text-sm text-slate-500">
            <span>{session?.tenantId}</span>
            <button onClick={signOut} className="text-slate-600 hover:text-slate-900 underline">
              Sign out
            </button>
          </div>
        </div>
      </header>
      <main className="max-w-5xl mx-auto px-4 py-6">
        <Outlet />
      </main>
    </div>
  )
}
