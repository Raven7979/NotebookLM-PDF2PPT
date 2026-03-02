import { useState } from 'react'
import { FileText, User, LogOut, ShieldCheck } from 'lucide-react'
import { Routes, Route, Link, useNavigate } from 'react-router-dom'
import { useAuth } from './context/AuthContext'
import { AuthModal } from './components/AuthModal'
import { Home } from './pages/Home'
import { AdminDashboard } from './pages/Admin'
import { VersionManager } from './pages/VersionManager'
import { Dashboard } from './pages/Dashboard'

function App() {
  const [isAuthModalOpen, setIsAuthModalOpen] = useState(false)
  const { user, logout } = useAuth()
  const navigate = useNavigate()

  const handleLogout = () => {
    logout();
    navigate('/');
  }

  return (
    <div className="min-h-screen bg-gray-50 text-gray-900 font-sans">
      {/* 1. 顶部导航栏 */}
      <nav className="bg-white border-b border-gray-200 sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16 items-center">
            {/* Logo */}
            <Link to="/" className="flex items-center gap-2">
              <div className="bg-blue-600 p-1.5 rounded-lg">
                <FileText className="h-6 w-6 text-white" />
              </div>
              <span className="text-xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-blue-600 to-indigo-600">
                NotebookLM PDF 2 PPT
              </span>
            </Link>

            {/* Auth Buttons */}
            <div className="flex items-center gap-4">
              {user ? (
                <>
                  {user.is_superuser && (
                    <Link
                      to="/admin"
                      className="flex items-center gap-2 px-3 py-1.5 bg-purple-50 text-purple-700 rounded-lg text-sm font-medium hover:bg-purple-100 transition-colors"
                    >
                      <ShieldCheck className="w-4 h-4" />
                      <span>管理后台</span>
                    </Link>
                  )}
                  <Link
                    to="/dashboard"
                    className="flex items-center gap-2 text-sm font-medium text-gray-700 hover:text-blue-600 transition-colors"
                  >
                    <User className="w-4 h-4" />
                    <span className="hidden sm:inline">个人中心</span>
                  </Link>
                  <div className="flex items-center gap-2 text-sm font-medium text-gray-700 hidden sm:flex">
                    <User className="w-4 h-4" />
                    {user.phone_number}
                  </div>
                  <button
                    onClick={handleLogout}
                    className="text-gray-500 hover:text-red-600 transition-colors p-2 rounded-md hover:bg-red-50"
                    title="退出登录"
                  >
                    <LogOut className="w-4 h-4" />
                  </button>
                </>
              ) : (
                <>
                  <button
                    onClick={() => setIsAuthModalOpen(true)}
                    className="bg-black text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-gray-800 transition-colors flex items-center gap-2"
                  >
                    登录后台
                  </button>
                </>
              )}
            </div>
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/admin" element={<AdminDashboard />} />
          <Route path="/admin/versions" element={<VersionManager />} />
          <Route path="/dashboard" element={<Dashboard />} />
        </Routes>
      </main>

      <AuthModal isOpen={isAuthModalOpen} onClose={() => setIsAuthModalOpen(false)} />
    </div>
  )
}

export default App
