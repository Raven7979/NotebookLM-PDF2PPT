import React, { useEffect, useState } from 'react'
import { Check, Zap, Crown } from 'lucide-react'
import { getLatestAppVersion } from '../api/misc'

const FALLBACK_DOWNLOAD_URL = '/downloads/NotePDF2PPT_v1.1_b0.dmg'

export const Home: React.FC = () => {
  const [downloadUrl, setDownloadUrl] = useState(FALLBACK_DOWNLOAD_URL)
  const [latestVersion, setLatestVersion] = useState('')
  const [latestBuild, setLatestBuild] = useState<number | null>(null)

  useEffect(() => {
    let active = true
    const fetchLatest = async () => {
      try {
        const latest = await getLatestAppVersion()
        if (!active) return
        setLatestVersion(latest.version)
        setLatestBuild(latest.build)
        setDownloadUrl(latest.download_url || FALLBACK_DOWNLOAD_URL)
      } catch {
        if (!active) return
        setDownloadUrl(FALLBACK_DOWNLOAD_URL)
        setLatestBuild(null)
      }
    }
    fetchLatest()
    return () => {
      active = false
    }
  }, [])

  return (
    <div className="max-w-4xl mx-auto flex flex-col items-center justify-center min-h-[60vh] text-center space-y-16 mt-12 mb-20">
      <div className="space-y-6">
        <h1 className="text-5xl font-extrabold tracking-tight text-gray-900 sm:text-6xl">
          NotebookLM幻灯片转PPT <br />
          <span className="text-blue-600">就是那么简单</span>
        </h1>
        <p className="text-xl text-gray-500 max-w-2xl mx-auto mt-6">
          <span className="block">利用 AI 智能识别布局，完美还原排版。</span>
          <span className="block">支持大文件并发处理，效率提升 5 倍。</span>
        </p>
        <a
          href={downloadUrl}
          target="_blank"
          rel="noreferrer"
          className="inline-flex items-center justify-center rounded-xl bg-black px-6 py-3 text-white text-sm font-semibold hover:bg-gray-800 transition-colors"
        >
          下载 Mac 客户端{latestVersion ? ` v${latestVersion}${latestBuild !== null ? ` (Build ${latestBuild})` : ''}` : ' v1.1 (Build 0)'}
        </a>
      </div>

      {/* Features Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-8 w-full mt-12">
        {[
          { icon: Zap, title: "极速转换", desc: "智能并发，秒级响应" },
          { icon: Crown, title: "排版还原", desc: "保留原始字体与布局" },
          { icon: Check, title: "安全加密", desc: "传输过程全程加密" },
        ].map((item, idx) => (
          <div key={idx} className="flex flex-col items-center text-center p-8 bg-white rounded-2xl shadow-sm border border-gray-100 hover:shadow-md transition-shadow">
            <item.icon className="w-12 h-12 text-blue-600 mb-4" />
            <h3 className="text-lg font-semibold text-gray-900">{item.title}</h3>
            <p className="text-md text-gray-500 mt-2">{item.desc}</p>
          </div>
        ))}
      </div>
    </div>
  )
}
