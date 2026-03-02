import React, { useState } from 'react';
import { X, Copy, Gift, CheckCircle2 } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

interface InviteModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const InviteModal: React.FC<InviteModalProps> = ({ isOpen, onClose }) => {
  const { user } = useAuth();
  const [copied, setCopied] = useState(false);

  if (!isOpen || !user) return null;

  const handleCopy = () => {
    if (user.invite_code) {
      navigator.clipboard.writeText(user.invite_code);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-md overflow-hidden relative animate-in fade-in zoom-in duration-200">
        {/* Close Button */}
        <button 
          onClick={onClose}
          className="absolute top-4 right-4 text-gray-400 hover:text-gray-600 transition-colors"
        >
          <X className="w-6 h-6" />
        </button>

        {/* Header */}
        <div className="bg-gradient-to-r from-orange-500 to-pink-500 p-8 text-center text-white">
          <div className="mx-auto w-16 h-16 bg-white/20 rounded-full flex items-center justify-center mb-4 backdrop-blur-sm">
            <Gift className="w-8 h-8 text-white" />
          </div>
          <h2 className="text-2xl font-bold">
            邀请好友，获赠积分
          </h2>
          <p className="mt-2 text-white/90 text-sm">
            好友填写你的邀请码注册并充值，双方各得 15 积分
          </p>
        </div>

        {/* Content */}
        <div className="p-8 space-y-6">
          
          {/* Invite Code Box */}
          <div className="space-y-2">
            <label className="text-sm font-medium text-gray-500 block text-center">你的专属邀请码</label>
            <div 
              onClick={handleCopy}
              className="bg-gray-50 border-2 border-dashed border-gray-300 rounded-xl p-4 flex items-center justify-between cursor-pointer hover:border-orange-400 hover:bg-orange-50 transition-all group"
            >
              <span className="text-3xl font-mono font-bold text-gray-800 tracking-wider pl-4">
                {user.invite_code}
              </span>
              <div className="flex items-center gap-2 pr-2">
                <span className={`text-xs font-medium transition-colors ${copied ? 'text-green-600' : 'text-gray-400 group-hover:text-orange-500'}`}>
                  {copied ? '已复制' : '点击复制'}
                </span>
                {copied ? (
                  <CheckCircle2 className="w-5 h-5 text-green-500" />
                ) : (
                  <Copy className="w-5 h-5 text-gray-400 group-hover:text-orange-500" />
                )}
              </div>
            </div>
          </div>

          {/* Rules */}
          <div className="bg-blue-50 rounded-xl p-4 space-y-3">
            <h3 className="font-semibold text-blue-900 text-sm">奖励规则</h3>
            <ul className="text-sm text-blue-700 space-y-2">
              <li className="flex gap-2">
                <span className="bg-blue-200 text-blue-700 rounded-full w-5 h-5 flex items-center justify-center text-xs flex-shrink-0 mt-0.5">1</span>
                分享邀请码给好友
              </li>
              <li className="flex gap-2">
                <span className="bg-blue-200 text-blue-700 rounded-full w-5 h-5 flex items-center justify-center text-xs flex-shrink-0 mt-0.5">2</span>
                好友注册时填写你的邀请码
              </li>
              <li className="flex gap-2">
                <span className="bg-blue-200 text-blue-700 rounded-full w-5 h-5 flex items-center justify-center text-xs flex-shrink-0 mt-0.5">3</span>
                好友首次付费充值后，你将获得 <span className="font-bold text-orange-600">15 积分</span> 奖励
              </li>
            </ul>
          </div>

        </div>
      </div>
    </div>
  );
};
