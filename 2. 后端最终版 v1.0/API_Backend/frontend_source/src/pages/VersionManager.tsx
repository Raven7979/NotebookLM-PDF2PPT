import React, { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { getAppVersions, createAppVersion, deleteAppVersion, type AppVersion } from '../api/misc';
import { Loader2, Upload, Trash2, Download, AlertCircle } from 'lucide-react';

export const VersionManager: React.FC = () => {
    const { user } = useAuth();
    const [versions, setVersions] = useState<AppVersion[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [isUploading, setIsUploading] = useState(false);
    const [error, setError] = useState('');

    // Form State
    const [newVersion, setNewVersion] = useState('');
    const [newBuild, setNewBuild] = useState('');
    const [releaseNotes, setReleaseNotes] = useState('');
    const [uploadProgress, setUploadProgress] = useState(0);
    const [forceUpdate, setForceUpdate] = useState(false);
    const [selectedFile, setSelectedFile] = useState<File | null>(null);

    useEffect(() => {
        fetchVersions();
    }, []);

    const fetchVersions = async () => {
        try {
            const data = await getAppVersions();
            setVersions(data);
        } catch (err) {
            console.error('Failed to fetch versions:', err);
        } finally {
            setIsLoading(false);
        }
    };

    const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        if (e.target.files && e.target.files[0]) {
            const file = e.target.files[0];
            // Basic validation
            if (!file.name.endsWith('.dmg') && !file.name.endsWith('.pkg')) {
                setError('只支持 .dmg 或 .pkg 文件');
                return;
            }
            setSelectedFile(file);
            setError('');
        }
    };



    const handleUpload = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!selectedFile || !newVersion || !newBuild) {
            setError('请填写完整信息并选择文件');
            return;
        }

        setIsUploading(true);
        setUploadProgress(0);
        setError('');

        const formData = new FormData();
        formData.append('version', newVersion);
        formData.append('build', newBuild);
        formData.append('release_notes', releaseNotes);
        formData.append('force_update', String(forceUpdate));
        formData.append('file', selectedFile);

        try {
            await createAppVersion(formData, (progressEvent) => {
                const percentCompleted = Math.round((progressEvent.loaded * 100) / progressEvent.total);
                setUploadProgress(percentCompleted);
            });
            // Reset form
            setNewVersion('');
            setNewBuild('');
            setReleaseNotes('');
            setForceUpdate(false);
            setSelectedFile(null);
            setUploadProgress(0);
            // Refresh list
            await fetchVersions();
        } catch (err: any) {
            console.error('Upload failed:', err);
            let msg = '上传失败，请重试';
            if (err.code === 'ECONNABORTED') msg = '上传超时，请检查网络后重试';
            else if (err.response?.data?.detail) msg = err.response.data.detail;
            setError(msg);
        } finally {
            setIsUploading(false);
        }
    };

    const handleDelete = async (id: number) => {
        if (!confirm('确定要删除此版本吗？文件也将被删除。')) return;
        try {
            await deleteAppVersion(id);
            await fetchVersions();
        } catch (err) {
            console.error('Delete failed:', err);
            alert('删除失败');
        }
    };

    if (!user?.is_superuser) {
        return <div className="p-8 text-center text-gray-500">需要管理员权限</div>;
    }

    return (
        <div className="max-w-4xl mx-auto p-6">
            <h1 className="text-2xl font-bold mb-6">App 版本管理</h1>

            {/* Upload Section */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 mb-8">
                <h2 className="text-lg font-semibold mb-4">发布新版本</h2>
                <form onSubmit={handleUpload} className="space-y-4">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">版本号 (Version)</label>
                            <input
                                type="text"
                                value={newVersion}
                                onChange={e => setNewVersion(e.target.value)}
                                placeholder="例如 2.8"
                                className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-black"
                            />
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">构建号 (Build)</label>
                            <input
                                type="number"
                                value={newBuild}
                                onChange={e => setNewBuild(e.target.value)}
                                placeholder="例如 28"
                                className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-black"
                            />
                        </div>
                    </div>

                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">更新日志</label>
                        <textarea
                            value={releaseNotes}
                            onChange={e => setReleaseNotes(e.target.value)}
                            rows={3}
                            className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-black"
                            placeholder="此次更新包含了..."
                        />
                    </div>

                    <div className="flex items-center gap-4">
                        <div className="flex-1">
                            <label className="block text-sm font-medium text-gray-700 mb-1">安装包 (.dmg)</label>
                            <input
                                type="file"
                                accept=".dmg,.pkg"
                                onChange={handleFileChange}
                                className="w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
                            />
                        </div>

                        <div className="flex items-center pt-6">
                            <input
                                type="checkbox"
                                id="force"
                                checked={forceUpdate}
                                onChange={e => setForceUpdate(e.target.checked)}
                                className="mr-2"
                            />
                            <label htmlFor="force" className="text-sm text-gray-700">强制更新</label>
                        </div>
                    </div>

                    {error && (
                        <div className="flex items-center gap-2 text-red-600 text-sm bg-red-50 p-3 rounded-lg">
                            <AlertCircle className="w-4 h-4" />
                            {error}
                        </div>
                    )}

                    <button
                        type="submit"
                        disabled={isUploading}
                        className="w-full bg-black text-white py-2 rounded-lg font-medium hover:bg-gray-800 transition-colors disabled:opacity-50 flex flex-col items-center justify-center gap-1 overflow-hidden relative"
                    >
                        {isUploading && (
                            <div
                                className="absolute inset-0 bg-blue-600/20 transition-all duration-300 ease-out"
                                style={{ width: `${uploadProgress}%` }}
                            />
                        )}
                        <div className="flex items-center justify-center gap-2 relative z-10 font-bold">
                            {isUploading ? (
                                <>
                                    <Loader2 className="w-4 h-4 animate-spin" />
                                    <span>正在上传发布 {uploadProgress}%</span>
                                </>
                            ) : (
                                <>
                                    <Upload className="w-4 h-4" />
                                    <span>发布新版本</span>
                                </>
                            )}
                        </div>
                    </button>
                </form>
            </div>

            {/* History List */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
                <div className="px-6 py-4 border-b border-gray-100">
                    <h2 className="text-lg font-semibold">历史版本</h2>
                </div>

                {isLoading ? (
                    <div className="p-8 text-center"><Loader2 className="w-6 h-6 animate-spin mx-auto text-gray-400" /></div>
                ) : versions.length === 0 ? (
                    <div className="p-8 text-center text-gray-500">暂无发布记录</div>
                ) : (
                    <div className="divide-y divide-gray-100">
                        {versions.map(v => (
                            <div key={v.id} className="p-6 flex items-start justify-between hover:bg-gray-50 transition-colors">
                                <div>
                                    <div className="flex items-center gap-3 mb-1">
                                        <h3 className="font-semibold text-lg">v{v.version} <span className="text-sm font-normal text-gray-500">(Build {v.build})</span></h3>
                                        {v.force_update && <span className="px-2 py-0.5 bg-red-100 text-red-700 text-xs rounded-full">强制更新</span>}
                                        <span className="text-xs text-gray-400">{new Date(v.created_at).toLocaleString()}</span>
                                    </div>
                                    <p className="text-gray-600 text-sm mb-2 whitespace-pre-wrap">{v.release_notes || '无更新日志'}</p>
                                    <div className="text-xs text-gray-400 font-mono bg-gray-50 inline-block px-2 py-1 rounded">
                                        {v.download_url}
                                    </div>
                                </div>

                                <div className="flex items-center gap-2">
                                    <a
                                        href={v.download_url.startsWith('http') ? v.download_url : `${import.meta.env.VITE_API_URL || 'http://localhost:8000'}${v.download_url}`}
                                        target="_blank"
                                        rel="noreferrer"
                                        className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                                        title="下载"
                                    >
                                        <Download className="w-4 h-4" />
                                    </a>
                                    <button
                                        onClick={() => handleDelete(v.id)}
                                        className="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                                        title="删除"
                                    >
                                        <Trash2 className="w-4 h-4" />
                                    </button>
                                </div>
                            </div>
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
};
