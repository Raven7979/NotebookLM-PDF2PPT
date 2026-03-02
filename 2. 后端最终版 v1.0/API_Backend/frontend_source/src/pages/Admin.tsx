import React, { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { getUsers, getStats, updateCredits, getOrders, getCodes, getUserDetails, type AdminStats, type Order, type UserDetail } from '../api/admin';
import { codesApi, type CreditCode } from '../api/codes';
import type { User } from '../api/auth';
import { ShieldCheck, Users, FileText, DollarSign, Loader2, Edit2, Check, X, ShoppingCart, Eye, User as UserIcon, CreditCard, Zap, Copy, Search, ArrowUpDown, Upload } from 'lucide-react';

export const AdminDashboard: React.FC = () => {
  const { user } = useAuth();
  const [users, setUsers] = useState<User[]>([]);
  const [orders, setOrders] = useState<Order[]>([]);
  const [codes, setCodes] = useState<CreditCode[]>([]);
  const [stats, setStats] = useState<AdminStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [activeTab, setActiveTab] = useState<'overview' | 'users' | 'orders' | 'codes'>('overview');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editCredits, setEditCredits] = useState<number>(0);

  // User Details Modal State
  const [selectedUser, setSelectedUser] = useState<UserDetail | null>(null);
  const [isDetailsModalOpen, setIsDetailsModalOpen] = useState(false);
  const [detailsLoading, setDetailsLoading] = useState(false);

  // Credit Code Generator State
  const [codePoints, setCodePoints] = useState(15);
  const [codeCount, setCodeCount] = useState(10);
  const [generating, setGenerating] = useState(false);
  const [generatedCodes, setGeneratedCodes] = useState<CreditCode[]>([]);

  // Search and Sort State
  const [searchQuery, setSearchQuery] = useState('');
  const [sortConfig, setSortConfig] = useState<{ key: keyof User; direction: 'asc' | 'desc' } | null>(null);

  const sortedUsers = React.useMemo(() => {
    let sortableUsers = [...users];
    if (searchQuery) {
      sortableUsers = sortableUsers.filter(u => u.phone_number.includes(searchQuery));
    }
    if (sortConfig !== null) {
      sortableUsers.sort((a, b) => {
        // @ts-ignore
        const aValue = a[sortConfig.key] ?? 0;
        // @ts-ignore
        const bValue = b[sortConfig.key] ?? 0;
        if (aValue < bValue) {
          return sortConfig.direction === 'asc' ? -1 : 1;
        }
        if (aValue > bValue) {
          return sortConfig.direction === 'asc' ? 1 : -1;
        }
        return 0;
      });
    }
    return sortableUsers;
  }, [users, sortConfig, searchQuery]);

  const requestSort = (key: keyof User) => {
    let direction: 'asc' | 'desc' = 'asc';
    if (sortConfig && sortConfig.key === key && sortConfig.direction === 'asc') {
      direction = 'desc';
    }
    setSortConfig({ key, direction });
  };

  const handleGenerateCodes = async () => {
    if (!user) return;
    setGenerating(true);
    try {
      const codes = await codesApi.generate(codePoints, codeCount, user.phone_number);
      setGeneratedCodes(codes);
      setError(''); // Clear errors
    } catch (err) {
      console.error('Generates failed', err);
      setError('生成卡密失败');
    } finally {
      setGenerating(false);
    }
  };

  const handleCopyCodes = () => {
    const text = generatedCodes.map(c => `${c.code},${c.points}`).join('\n');
    navigator.clipboard.writeText(text);
    alert('已复制到剪贴板');
  };
  useEffect(() => {
    const fetchData = async () => {
      if (!user || !user.is_superuser) return;

      try {
        const [usersData, statsData, ordersData, codesData] = await Promise.all([
          getUsers(user.phone_number),
          getStats(user.phone_number),
          getOrders(user.phone_number),
          getCodes(user.phone_number)
        ]);
        setUsers(usersData);
        setStats(statsData);
        setOrders(ordersData);
        setCodes(codesData);
      } catch (err) {
        setError('无法获取数据，权限不足或网络错误');
        console.error(err);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [user]);

  const handleEditClick = (targetUser: User) => {
    setEditingId(targetUser.id);
    setEditCredits(targetUser.credits);
  };

  const handleSaveCredits = async (userId: string) => {
    if (!user) return;
    try {
      await updateCredits(user.phone_number, userId, editCredits);
      setUsers(users.map(u => u.id === userId ? { ...u, credits: editCredits } : u));
      setEditingId(null);
    } catch (err) {
      console.error('Failed to update credits', err);
      setError('更新积分失败');
      setTimeout(() => setError(''), 3000);
    }
  };

  const handleViewDetails = async (targetUserId: string) => {
    if (!user) return;
    setDetailsLoading(true);
    setIsDetailsModalOpen(true);
    try {
      const details = await getUserDetails(user.phone_number, targetUserId);
      setSelectedUser(details);
    } catch (err) {
      console.error('Failed to get user details', err);
      setError('获取用户详情失败');
    } finally {
      setDetailsLoading(false);
    }
  };

  if (!user?.is_superuser) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen text-gray-500">
        <ShieldCheck className="w-16 h-16 mb-4 text-gray-300" />
        <p>需要管理员权限</p>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <Loader2 className="w-8 h-8 animate-spin text-blue-500" />
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      <h1 className="text-3xl font-bold text-gray-900 mb-8 flex items-center gap-3">
        <ShieldCheck className="w-8 h-8 text-blue-600" />
        后台管理系统
      </h1>

      {error && (
        <div className="bg-red-50 text-red-600 p-4 rounded-lg mb-8">
          {error}
        </div>
      )}

      {/* Tabs */}
      <div className="flex border-b border-gray-200 mb-8 overflow-x-auto">
        <button
          onClick={() => setActiveTab('overview')}
          className={`px-6 py-3 font-medium text-sm border-b-2 whitespace-nowrap transition-colors ${activeTab === 'overview' ? 'border-blue-600 text-blue-600' : 'border-transparent text-gray-500 hover:text-gray-700'}`}
        >
          概览 & 生成
        </button>
        <button
          onClick={() => setActiveTab('users')}
          className={`px-6 py-3 font-medium text-sm border-b-2 whitespace-nowrap transition-colors ${activeTab === 'users' ? 'border-blue-600 text-blue-600' : 'border-transparent text-gray-500 hover:text-gray-700'}`}
        >
          用户管理 ({users.length})
        </button>
        <button
          onClick={() => setActiveTab('orders')}
          className={`px-6 py-3 font-medium text-sm border-b-2 whitespace-nowrap transition-colors ${activeTab === 'orders' ? 'border-blue-600 text-blue-600' : 'border-transparent text-gray-500 hover:text-gray-700'}`}
        >
          订单 ({orders.length})
        </button>
        <button
          onClick={() => setActiveTab('codes')}
          className={`px-6 py-3 font-medium text-sm border-b-2 whitespace-nowrap transition-colors ${activeTab === 'codes' ? 'border-blue-600 text-blue-600' : 'border-transparent text-gray-500 hover:text-gray-700'}`}
        >
          卡密库 ({codes.length})
        </button>
        <a
          href="/admin/versions"
          className="px-6 py-3 font-medium text-sm border-b-2 border-transparent text-gray-500 hover:text-gray-700 whitespace-nowrap transition-colors flex items-center gap-2"
        >
          <Upload className="w-4 h-4" />
          App 版本
        </a>
      </div>

      {activeTab === 'overview' && (
        <>
          {/* Stats Cards */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
            <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4">
              <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center text-blue-600">
                <Users className="w-6 h-6" />
              </div>
              <div>
                <p className="text-sm text-gray-500">总用户数</p>
                <p className="text-2xl font-bold text-gray-900">{stats?.user_count || 0}</p>
              </div>
            </div>

            <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4">
              <div className="w-12 h-12 bg-purple-100 rounded-full flex items-center justify-center text-purple-600">
                <FileText className="w-6 h-6" />
              </div>
              <div>
                <p className="text-sm text-gray-500">总文件转换数</p>
                <p className="text-2xl font-bold text-gray-900">{stats?.file_count || 0}</p>
              </div>
            </div>

            <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4">
              <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center text-green-600">
                <DollarSign className="w-6 h-6" />
              </div>
              <div>
                <p className="text-sm text-gray-500">总收入</p>
                <p className="text-2xl font-bold text-gray-900">¥{stats?.revenue || 0}</p>
              </div>
            </div>
          </div>

          {/* Credit Code Generator */}
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden mb-12">
            <div className="px-6 py-4 border-b border-gray-100 flex justify-between items-center">
              <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
                <CreditCard className="w-5 h-5 text-purple-600" />
                卡密生成器
              </h2>
            </div>
            <div className="p-6">
              <div className="flex flex-wrap items-end gap-4 mb-6">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">面额 (积分)</label>
                  <select
                    value={codePoints}
                    onChange={(e) => setCodePoints(Number(e.target.value))}
                    className="block w-40 rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                  >
                    <option value={15}>15 积分 (体验包)</option>
                    <option value={45}>45 积分 (标准包)</option>
                    <option value={150}>150 积分 (专业包)</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">数量 (张)</label>
                  <input
                    type="number"
                    value={codeCount}
                    onChange={(e) => setCodeCount(Number(e.target.value))}
                    min={1}
                    max={100}
                    className="block w-32 rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                  />
                </div>
                <button
                  onClick={handleGenerateCodes}
                  disabled={generating}
                  className="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 disabled:opacity-50 flex items-center gap-2"
                >
                  {generating ? <Loader2 className="w-4 h-4 animate-spin" /> : <Zap className="w-4 h-4" />}
                  生成卡密
                </button>
                {generatedCodes.length > 0 && (
                  <button
                    onClick={handleCopyCodes}
                    className="px-4 py-2 bg-white border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 flex items-center gap-2"
                  >
                    <Copy className="w-4 h-4" />
                    复制全部
                  </button>
                )}
              </div>

              {/* Generated Codes Preview */}
              {generatedCodes.length > 0 && (
                <div className="bg-gray-50 rounded-lg p-4 max-h-60 overflow-y-auto border border-gray-200">
                  <table className="w-full text-left text-sm">
                    <thead>
                      <tr className="text-gray-500 border-b border-gray-200">
                        <th className="pb-2">卡密代码</th>
                        <th className="pb-2">面额</th>
                        <th className="pb-2">状态</th>
                      </tr>
                    </thead>
                    <tbody className="font-mono">
                      {generatedCodes.map((c) => (
                        <tr key={c.code}>
                          <td className="py-1 text-gray-900 select-all">{c.code}</td>
                          <td className="py-1 text-gray-600">{c.points}</td>
                          <td className="py-1 text-gray-500">{c.status}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          </div>
        </>
      )}

      {activeTab === 'users' && (
        /* Users Table */
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden mb-12 animate-in fade-in">
          <div className="px-6 py-4 border-b border-gray-100 flex justify-between items-center">
            <h2 className="text-lg font-semibold text-gray-900">用户列表</h2>
            <div className="relative">
              <input
                type="text"
                placeholder="搜索手机号..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-9 pr-4 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent w-64"
              />
              <Search className="w-4 h-4 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
            </div>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-left">
              <thead className="bg-gray-50 text-gray-500 text-sm">
                <tr>
                  <th className="px-6 py-3 font-medium">ID</th>
                  <th className="px-6 py-3 font-medium">手机号</th>
                  <th
                    className="px-6 py-3 font-medium cursor-pointer hover:bg-gray-100 transition-colors group"
                    onClick={() => requestSort('credits')}
                  >
                    <div className="flex items-center gap-1">
                      剩余积分
                      <ArrowUpDown className={`w-3 h-3 ${sortConfig?.key === 'credits' ? 'text-blue-600' : 'text-gray-300 group-hover:text-gray-500'}`} />
                    </div>
                  </th>
                  <th
                    className="px-6 py-3 font-medium cursor-pointer hover:bg-gray-100 transition-colors group"
                    onClick={() => requestSort('total_redeemed_points')}
                  >
                    <div className="flex items-center gap-1">
                      已兑换积分
                      <ArrowUpDown className={`w-3 h-3 ${sortConfig?.key === 'total_redeemed_points' ? 'text-blue-600' : 'text-gray-300 group-hover:text-gray-500'}`} />
                    </div>
                  </th>
                  <th className="px-6 py-3 font-medium">邀请人</th>
                  <th
                    className="px-6 py-3 font-medium cursor-pointer hover:bg-gray-100 transition-colors group"
                    onClick={() => requestSort('total_converted_pages')}
                  >
                    <div className="flex items-center gap-1">
                      转换页数
                      <ArrowUpDown className={`w-3 h-3 ${sortConfig?.key === 'total_converted_pages' ? 'text-blue-600' : 'text-gray-300 group-hover:text-gray-500'}`} />
                    </div>
                  </th>
                  <th
                    className="px-6 py-3 font-medium cursor-pointer hover:bg-gray-100 transition-colors group"
                    onClick={() => requestSort('total_payment_amount')}
                  >
                    <div className="flex items-center gap-1">
                      累积消费
                      <ArrowUpDown className={`w-3 h-3 ${sortConfig?.key === 'total_payment_amount' ? 'text-blue-600' : 'text-gray-300 group-hover:text-gray-500'}`} />
                    </div>
                  </th>
                  <th className="px-6 py-3 font-medium">注册时间</th>
                  <th className="px-6 py-3 font-medium">状态</th>
                  <th className="px-6 py-3 font-medium">操作</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {sortedUsers.map((u) => (
                  <tr key={u.id} className="hover:bg-gray-50 transition-colors">
                    <td className="px-6 py-4 text-sm text-gray-500 font-mono truncate max-w-[100px]">{u.id}</td>
                    <td className="px-6 py-4 text-sm font-medium text-gray-900">{u.phone_number}</td>
                    <td className="px-6 py-4 text-sm text-gray-900">
                      {editingId === u.id ? (
                        <div className="flex items-center gap-2">
                          <input
                            type="number"
                            value={editCredits}
                            onChange={(e) => setEditCredits(parseInt(e.target.value) || 0)}
                            className="w-24 border rounded px-2 py-1 text-sm"
                            autoFocus
                          />
                          <button
                            onClick={() => handleSaveCredits(u.id)}
                            className="p-1 text-green-600 hover:text-green-800 bg-green-50 rounded"
                            title="Save"
                          >
                            <Check className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() => setEditingId(null)}
                            className="p-1 text-gray-500 hover:text-gray-700 bg-gray-100 rounded"
                            title="Cancel"
                          >
                            <X className="w-4 h-4" />
                          </button>
                        </div>
                      ) : (
                        <div className="flex items-center gap-2 group">
                          <span className="font-mono">{u.credits}</span>
                          <button
                            onClick={() => handleEditClick(u)}
                            className="opacity-0 group-hover:opacity-100 transition-opacity p-1 text-blue-600 hover:text-blue-800 hover:bg-blue-50 rounded"
                            title="Edit Credits"
                          >
                            <Edit2 className="w-3 h-3" />
                          </button>
                        </div>
                      )}
                    </td>
                    <td className="px-6 py-4 text-sm font-mono text-gray-900">{u.total_redeemed_points || 0}</td>
                    <td className="px-6 py-4 text-sm font-mono text-gray-500">{u.invited_by_code || '-'}</td>
                    <td className="px-6 py-4 text-sm font-mono text-gray-900">{u.total_converted_pages || 0}</td>
                    <td className="px-6 py-4 text-sm font-mono text-gray-900">¥{(u.total_payment_amount || 0).toFixed(2)}</td>
                    <td className="px-6 py-4 text-sm text-gray-500">{new Date(u.created_at).toLocaleDateString()}</td>
                    <td className="px-6 py-4">
                      {u.is_superuser ? (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
                          管理员
                        </span>
                      ) : (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                          用户
                        </span>
                      )}
                    </td>
                    <td className="px-6 py-4">
                      <button
                        onClick={() => handleViewDetails(u.id)}
                        className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                        title="查看详情"
                      >
                        <Eye className="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {activeTab === 'orders' && (
        /* Orders Table */
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden animate-in fade-in">
          <div className="px-6 py-4 border-b border-gray-100">
            <h2 className="text-lg font-semibold text-gray-900">订单列表</h2>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-left">
              <thead className="bg-gray-50 text-gray-500 text-sm">
                <tr>
                  <th className="px-6 py-3 font-medium">订单号</th>
                  <th className="px-6 py-3 font-medium">用户ID</th>
                  <th className="px-6 py-3 font-medium">金额</th>
                  <th className="px-6 py-3 font-medium">积分</th>
                  <th className="px-6 py-3 font-medium">状态</th>
                  <th className="px-6 py-3 font-medium">创建时间</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {orders.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="px-6 py-8 text-center text-gray-500">
                      <ShoppingCart className="w-8 h-8 mx-auto mb-2 text-gray-300" />
                      暂无订单数据
                    </td>
                  </tr>
                ) : (
                  orders.map((order) => (
                    <tr key={order.id} className="hover:bg-gray-50 transition-colors">
                      <td className="px-6 py-4 text-sm text-gray-500 font-mono truncate max-w-[100px]">{order.id}</td>
                      <td className="px-6 py-4 text-sm text-gray-500 font-mono truncate max-w-[100px]">{order.user_id}</td>
                      <td className="px-6 py-4 text-sm font-medium text-gray-900">¥{order.amount}</td>
                      <td className="px-6 py-4 text-sm text-gray-900">{order.credits}</td>
                      <td className="px-6 py-4">
                        <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${order.status === 'completed' ? 'bg-green-100 text-green-800' :
                          order.status === 'pending' ? 'bg-yellow-100 text-yellow-800' :
                            'bg-red-100 text-red-800'
                          }`}>
                          {order.status === 'completed' ? '已完成' :
                            order.status === 'pending' ? '待支付' : '失败'}
                        </span>
                      </td>
                      <td className="px-6 py-4 text-sm text-gray-500">{new Date(order.created_at).toLocaleString()}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {activeTab === 'codes' && (
        /* Credit Codes Table */
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden animate-in fade-in">
          <div className="px-6 py-4 border-b border-gray-100 flex justify-between items-center">
            <h2 className="text-lg font-semibold text-gray-900">卡密库</h2>
            <div className="text-sm text-gray-500">共 {codes.length} 张</div>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-left">
              <thead className="bg-gray-50 text-gray-500 text-sm">
                <tr>
                  <th className="px-6 py-3 font-medium">卡密</th>
                  <th className="px-6 py-3 font-medium">面额</th>
                  <th className="px-6 py-3 font-medium">状态</th>
                  <th className="px-6 py-3 font-medium">创建时间</th>
                  <th className="px-6 py-3 font-medium">使用详情</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100 font-mono text-sm">
                {codes.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="px-6 py-8 text-center text-gray-500">
                      暂无卡密
                    </td>
                  </tr>
                ) : (
                  codes.map((code) => (
                    <tr key={code.code} className="hover:bg-gray-50">
                      <td className="px-6 py-3 text-gray-900 font-medium select-all">{code.code}</td>
                      <td className="px-6 py-3 text-gray-900">{code.points}</td>
                      <td className="px-6 py-3">
                        <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${code.status === 'used' ? 'bg-gray-100 text-gray-600' : 'bg-green-50 text-green-700'
                          }`}>
                          {code.status === 'used' ? '已使用' : '未使用'}
                        </span>
                      </td>
                      <td className="px-6 py-3 text-gray-500 text-xs">
                        {new Date(code.created_at).toLocaleString()}
                      </td>
                      <td className="px-6 py-3 text-gray-500 text-xs">
                        {code.status === 'used' ? (
                          <span title={code.used_at ? new Date(code.used_at).toLocaleString() : ''}>
                            被 {code.used_by || 'Unknown'} 使用
                          </span>
                        ) : '-'}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* User Details Modal */}
      {isDetailsModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-xl w-full max-w-4xl max-h-[90vh] overflow-hidden flex flex-col animate-in fade-in zoom-in duration-200">
            {/* Header */}
            <div className="px-6 py-4 border-b border-gray-100 flex justify-between items-center bg-gray-50">
              <h3 className="text-xl font-bold text-gray-900 flex items-center gap-2">
                <UserIcon className="w-5 h-5 text-blue-600" />
                用户详情: {selectedUser?.phone_number || '加载中...'}
              </h3>
              <button
                onClick={() => {
                  setIsDetailsModalOpen(false);
                  setSelectedUser(null);
                }}
                className="text-gray-400 hover:text-gray-600 p-1 rounded-full hover:bg-gray-200 transition-colors"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            {/* Content */}
            <div className="flex-1 overflow-y-auto p-6">
              {detailsLoading ? (
                <div className="flex justify-center items-center h-40">
                  <Loader2 className="w-8 h-8 animate-spin text-blue-500" />
                </div>
              ) : selectedUser ? (
                <div className="space-y-8">
                  {/* Summary Stats */}
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                    <div className="bg-blue-50 p-4 rounded-xl border border-blue-100">
                      <p className="text-sm text-blue-600 mb-1">当前积分</p>
                      <p className="text-2xl font-bold text-blue-900">{selectedUser.credits}</p>
                    </div>
                    <div className="bg-purple-50 p-4 rounded-xl border border-purple-100">
                      <p className="text-sm text-purple-600 mb-1">累计转换页数</p>
                      <p className="text-2xl font-bold text-purple-900">{selectedUser.total_converted_pages || 0}</p>
                    </div>
                    <div className="bg-green-50 p-4 rounded-xl border border-green-100">
                      <p className="text-sm text-green-600 mb-1">累计充值金额</p>
                      <p className="text-2xl font-bold text-green-900">
                        ¥{selectedUser.orders.reduce((sum, order) => sum + order.amount, 0).toFixed(2)}
                      </p>
                    </div>
                  </div>

                  {/* Conversion History */}
                  <div>
                    <h4 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
                      <FileText className="w-5 h-5 text-gray-500" />
                      转换历史
                    </h4>
                    <div className="border border-gray-200 rounded-lg overflow-hidden">
                      <table className="w-full text-left text-sm">
                        <thead className="bg-gray-50 text-gray-500">
                          <tr>
                            <th className="px-4 py-2 font-medium">文件名</th>
                            <th className="px-4 py-2 font-medium">页数</th>
                            <th className="px-4 py-2 font-medium">消耗积分</th>
                            <th className="px-4 py-2 font-medium">时间</th>
                            <th className="px-4 py-2 font-medium">状态</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-100">
                          {selectedUser.file_records.length > 0 ? (
                            selectedUser.file_records.map((file) => (
                              <tr key={file.id} className="hover:bg-gray-50">
                                <td className="px-4 py-2 text-gray-900 truncate max-w-[200px]" title={file.filename}>{file.filename}</td>
                                <td className="px-4 py-2 text-gray-600">{file.page_count}</td>
                                <td className="px-4 py-2 text-gray-600">{file.cost}</td>
                                <td className="px-4 py-2 text-gray-500">{new Date(file.created_at).toLocaleString()}</td>
                                <td className="px-4 py-2">
                                  <span className={`px-2 py-0.5 rounded-full text-xs font-medium 
                                                            ${file.status === 'completed' ? 'bg-green-100 text-green-700' :
                                      file.status === 'failed' ? 'bg-red-100 text-red-700' :
                                        'bg-blue-100 text-blue-700'}`}>
                                    {file.status}
                                  </span>
                                </td>
                              </tr>
                            ))
                          ) : (
                            <tr>
                              <td colSpan={5} className="px-4 py-8 text-center text-gray-400">暂无转换记录</td>
                            </tr>
                          )}
                        </tbody>
                      </table>
                    </div>
                  </div>

                  {/* Order History */}
                  <div>
                    <h4 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
                      <DollarSign className="w-5 h-5 text-gray-500" />
                      充值记录
                    </h4>
                    <div className="border border-gray-200 rounded-lg overflow-hidden">
                      <table className="w-full text-left text-sm">
                        <thead className="bg-gray-50 text-gray-500">
                          <tr>
                            <th className="px-4 py-2 font-medium">订单号</th>
                            <th className="px-4 py-2 font-medium">金额</th>
                            <th className="px-4 py-2 font-medium">获得积分</th>
                            <th className="px-4 py-2 font-medium">时间</th>
                            <th className="px-4 py-2 font-medium">状态</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-100">
                          {selectedUser.orders.length > 0 ? (
                            selectedUser.orders.map((order) => (
                              <tr key={order.id} className="hover:bg-gray-50">
                                <td className="px-4 py-2 text-gray-500 font-mono text-xs">{order.id}</td>
                                <td className="px-4 py-2 text-gray-900 font-medium">¥{order.amount}</td>
                                <td className="px-4 py-2 text-gray-600">{order.credits}</td>
                                <td className="px-4 py-2 text-gray-500">{new Date(order.created_at).toLocaleString()}</td>
                                <td className="px-4 py-2">
                                  <span className={`px-2 py-0.5 rounded-full text-xs font-medium 
                                                            ${order.status === 'completed' ? 'bg-green-100 text-green-700' :
                                      order.status === 'pending' ? 'bg-yellow-100 text-yellow-700' :
                                        'bg-gray-100 text-gray-700'}`}>
                                    {order.status}
                                  </span>
                                </td>
                              </tr>
                            ))
                          ) : (
                            <tr>
                              <td colSpan={5} className="px-4 py-8 text-center text-gray-400">暂无充值记录</td>
                            </tr>
                          )}
                        </tbody>
                      </table>
                    </div>
                  </div>
                </div>
              ) : (
                <div className="text-center text-gray-500 py-12">未找到用户信息</div>
              )}
            </div>
          </div>
        </div>
      )}


    </div>
  );
};
