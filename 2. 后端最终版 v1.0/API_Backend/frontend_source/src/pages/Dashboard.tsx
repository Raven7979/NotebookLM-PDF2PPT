import { useState, useEffect } from 'react'
import { Coins, History, CreditCard, CheckCircle, XCircle, FileText, Users } from 'lucide-react'
import { useAuth } from '../context/AuthContext'
import { codesApi, type Transaction } from '../api/codes'
import { userApi, type FileRecord } from '../api/user'

export function Dashboard() {
    const { user, login } = useAuth()
    const [code, setCode] = useState('')
    const [loading, setLoading] = useState(false)
    const [message, setMessage] = useState<{ type: 'success' | 'error', text: string } | null>(null)
    const [transactions, setTransactions] = useState<Transaction[]>([])
    const [files, setFiles] = useState<FileRecord[]>([])

    const [activeTab, setActiveTab] = useState<'files' | 'transactions'>('files')

    // Invite Bind State
    const [showInviteModal, setShowInviteModal] = useState(false)
    const [inviteCode, setInviteCode] = useState('')
    const [binding, setBinding] = useState(false)

    useEffect(() => {
        if (user) {
            fetchHistory()
            fetchFiles()
        }
    }, [user])

    const fetchFiles = async () => {
        if (!user) return
        try {
            const data = await userApi.getFiles(user.phone_number)
            setFiles(data)
        } catch (error) {
            console.error("Failed to fetch files", error)
        }
    }

    const fetchHistory = async () => {
        if (!user) return
        try {
            const res = await codesApi.getHistory(user.phone_number)
            setTransactions(res)
        } catch (error) {
            console.error("Failed to fetch history", error)
        }
    }

    const handleRedeem = async (e: React.FormEvent) => {
        e.preventDefault()
        if (!code.trim() || !user) return

        setLoading(true)
        setMessage(null)

        try {
            const result: any = await codesApi.redeem(code, user.phone_number)

            // Refetch data immediately
            const updatedUser = await userApi.getMe(user.phone_number)
            login(updatedUser)
            fetchHistory()

            setCode('')

            // Check for invite reward prompt
            if (result.message === 'success_no_invite') {
                setMessage({ type: 'success', text: '兑换成功！绑定邀请码可再领 15 积分！' })
                setTimeout(() => setShowInviteModal(true), 1500)
            } else {
                setMessage({ type: 'success', text: '兑换成功！积分已到账。' })
            }

        } catch (err: any) {
            setMessage({ type: 'error', text: err.response?.data?.detail || '兑换失败，请检查卡密是否正确' })
        } finally {
            setLoading(false)
        }
    }

    const handleBindInvite = async () => {
        if (!inviteCode.trim() || !user) return
        setBinding(true)
        try {
            await userApi.bindInviteCode(user.phone_number, inviteCode)
            setShowInviteModal(false)
            setMessage({ type: 'success', text: '绑定成功！奖励已到账。' })

            // Global refresh
            login(await userApi.getMe(user.phone_number))
            fetchHistory()

        } catch (err: any) {
            alert(err.response?.data?.detail || '绑定失败')
        } finally {
            setBinding(false)
        }
    }

    if (!user) return <div>请先登录</div>

    return (
        <div className="max-w-4xl mx-auto space-y-8 animate-fade-in">

            {/* Header Section */}
            <div className="bg-white rounded-2xl p-8 shadow-sm border border-gray-100 flex flex-col md:flex-row justify-between items-center gap-6">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900 mb-2">个人中心</h1>
                    <p className="text-gray-500">管理您的积分与查看使用记录</p>
                </div>
                <div className="bg-gradient-to-r from-blue-50 to-indigo-50 px-8 py-6 rounded-xl flex items-center gap-4 border border-blue-100">
                    <div className="bg-white p-3 rounded-full shadow-sm text-blue-600">
                        <Coins className="w-8 h-8" />
                    </div>
                    <div>
                        <div className="text-sm text-blue-600 font-medium mb-1">当前余额</div>
                        <div className="text-3xl font-bold text-gray-900">{user.credits} <span className="text-sm font-normal text-gray-500">积分</span></div>
                    </div>
                </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-8">

                {/* Left Column: Redeem */}
                <div className="md:col-span-1 space-y-6">
                    <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 h-full">
                        <div className="flex items-center gap-2 mb-6 text-gray-900 font-bold text-lg">
                            <CreditCard className="w-5 h-5 text-purple-600" />
                            卡密兑换
                        </div>

                        <form onSubmit={handleRedeem} className="space-y-4">
                            <div>
                                <label className="block text-sm font-medium text-gray-700 mb-2">请输入兑换码</label>
                                <input
                                    type="text"
                                    value={code}
                                    onChange={(e) => setCode(e.target.value)}
                                    placeholder="例如: ABC123XYZ"
                                    className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:border-purple-500 focus:ring-2 focus:ring-purple-200 outline-none transition-all font-mono text-center uppercase"
                                />
                            </div>

                            <button
                                type="submit"
                                disabled={loading || !code}
                                className="w-full bg-black text-white py-3 rounded-xl font-medium hover:bg-gray-800 disabled:opacity-50 disabled:cursor-not-allowed transition-all flex justify-center items-center"
                            >
                                {loading ? '兑换中...' : '立即兑换'}
                            </button>

                            {message && (
                                <div className={`p-3 rounded-lg text-sm flex items-center gap-2 ${message.type === 'success' ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700'}`}>
                                    {message.type === 'success' ? <CheckCircle className="w-4 h-4" /> : <XCircle className="w-4 h-4" />}
                                    {message.text}
                                </div>
                            )}
                        </form>

                        <div className="mt-6 pt-6 border-t border-gray-100 text-xs text-gray-400 leading-relaxed">
                            <p>• 卡密可通过官方渠道购买</p>
                            <p>• 请区分大小写（通常为自动大写）</p>
                            <p>• 遇到问题请联系客服</p>
                        </div>
                    </div>
                </div>

                {/* Right Column: Content Tabs */}
                <div className="md:col-span-2">
                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden min-h-[500px] flex flex-col">
                        <div className="border-b border-gray-100 flex">
                            <button
                                onClick={() => setActiveTab('files')}
                                className={`px-6 py-4 text-sm font-medium flex items-center gap-2 border-b-2 transition-colors ${activeTab === 'files' ? 'border-blue-600 text-blue-600' : 'border-transparent text-gray-500 hover:text-gray-700'}`}
                            >
                                <FileText className="w-4 h-4" />
                                我的文件
                            </button>
                            <button
                                onClick={() => setActiveTab('transactions')}
                                className={`px-6 py-4 text-sm font-medium flex items-center gap-2 border-b-2 transition-colors ${activeTab === 'transactions' ? 'border-blue-600 text-blue-600' : 'border-transparent text-gray-500 hover:text-gray-700'}`}
                            >
                                <History className="w-4 h-4" />
                                交易记录
                            </button>
                        </div>

                        <div className="flex-1 overflow-x-auto p-0">
                            {activeTab === 'files' ? (
                                <table className="w-full text-sm text-left">
                                    <thead className="bg-gray-50 text-gray-500 font-medium">
                                        <tr>
                                            <th className="px-6 py-4">文件名</th>
                                            <th className="px-6 py-4">页数/消耗</th>
                                            <th className="px-6 py-4">状态</th>
                                            <th className="px-6 py-4 text-right">时间</th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-gray-100">
                                        {files.length === 0 ? (
                                            <tr>
                                                <td colSpan={4} className="px-6 py-12 text-center text-gray-400">
                                                    暂无文件记录
                                                </td>
                                            </tr>
                                        ) : (
                                            files.map((file) => (
                                                <tr key={file.id} className="hover:bg-gray-50 transition-colors">
                                                    <td className="px-6 py-4 font-medium text-gray-900">
                                                        <div className="truncate max-w-[200px]" title={file.filename}>{file.filename}</div>
                                                    </td>
                                                    <td className="px-6 py-4 text-gray-500">
                                                        {file.page_count}页 / -{file.cost}积分
                                                    </td>
                                                    <td className="px-6 py-4">
                                                        <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${file.status === 'completed' ? 'bg-green-100 text-green-800' :
                                                            file.status === 'failed' ? 'bg-red-100 text-red-800' :
                                                                'bg-blue-100 text-blue-800'
                                                            }`}>
                                                            {file.status === 'completed' ? '已完成' :
                                                                file.status === 'failed' ? '失败' : '处理中'}
                                                        </span>
                                                    </td>
                                                    <td className="px-6 py-4 text-right text-gray-500 whitespace-nowrap">
                                                        {new Date(file.created_at).toLocaleDateString()}
                                                    </td>
                                                </tr>
                                            ))
                                        )}
                                    </tbody>
                                </table>
                            ) : (
                                <table className="w-full text-sm text-left">
                                    <thead className="bg-gray-50 text-gray-500 font-medium">
                                        <tr>
                                            <th className="px-6 py-4">时间</th>
                                            <th className="px-6 py-4">类型/详情</th>
                                            <th className="px-6 py-4 text-right">变动</th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-gray-100">
                                        {transactions.length === 0 ? (
                                            <tr>
                                                <td colSpan={3} className="px-6 py-12 text-center text-gray-400">
                                                    暂无记录
                                                </td>
                                            </tr>
                                        ) : (
                                            transactions.map((tx) => (
                                                <tr key={tx.id} className="hover:bg-gray-50 transition-colors">
                                                    <td className="px-6 py-4 text-gray-500 whitespace-nowrap">
                                                        {new Date(tx.created_at).toLocaleString('zh-CN')}
                                                    </td>
                                                    <td className="px-6 py-4">
                                                        <div className="font-medium text-gray-900 mb-0.5">
                                                            {tx.type === 'redemption' ? '积分充值' : tx.type === 'conversion' ? '文档转换' : '系统赠送'}
                                                        </div>
                                                        <div className="text-gray-400 text-xs truncate max-w-[200px]" title={tx.description}>
                                                            {tx.description}
                                                        </div>
                                                    </td>
                                                    <td className={`px-6 py-4 text-right font-bold ${tx.amount > 0 ? 'text-green-600' : 'text-gray-900'}`}>
                                                        {tx.amount > 0 ? '+' : ''}{tx.amount}
                                                    </td>
                                                </tr>
                                            ))
                                        )}
                                    </tbody>
                                </table>
                            )}
                        </div>
                    </div>
                </div>

            </div>

            {/* Invite Bind Modal */}
            {showInviteModal && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-in fade-in">
                    <div className="bg-white rounded-2xl p-8 w-full max-w-sm shadow-xl relative text-center">
                        <button
                            onClick={() => setShowInviteModal(false)}
                            className="absolute top-4 right-4 text-gray-400 hover:text-gray-600"
                        >
                            <XCircle className="w-6 h-6" />
                        </button>

                        <div className="mx-auto w-16 h-16 bg-yellow-100 text-yellow-600 rounded-full flex items-center justify-center mb-6">
                            <Users className="w-8 h-8" />
                        </div>

                        <h3 className="text-xl font-bold text-gray-900 mb-2">恭喜获得额外奖励资格!</h3>
                        <p className="text-gray-500 mb-6 text-sm">
                            填写邀请码，您和邀请人将各获赠 <span className="text-yellow-600 font-bold">15 积分</span>。
                        </p>

                        <div className="space-y-4">
                            <input
                                type="text"
                                placeholder="输入对方邀请码"
                                className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl text-center font-mono uppercase focus:ring-2 focus:ring-yellow-500 outline-none"
                                value={inviteCode}
                                onChange={e => setInviteCode(e.target.value)}
                            />
                            <button
                                onClick={handleBindInvite}
                                disabled={binding || !inviteCode}
                                className="w-full bg-yellow-500 text-white font-bold py-3 rounded-xl hover:bg-yellow-600 transition-colors disabled:opacity-50"
                            >
                                {binding ? '领取中...' : '立即领取奖励'}
                            </button>
                            <button
                                onClick={() => setShowInviteModal(false)}
                                className="text-sm text-gray-400 hover:text-gray-600"
                            >
                                我没有邀请码，放弃奖励
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    )
}
