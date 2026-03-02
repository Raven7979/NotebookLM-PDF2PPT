import React, { useState, useEffect } from 'react';
import { X, Smartphone, ShieldCheck, UserPlus, Loader2 } from 'lucide-react';
import { sendVerificationCode, loginOrRegister } from '../api/auth';
import { useAuth } from '../context/AuthContext';

interface AuthModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const AuthModal: React.FC<AuthModalProps> = ({ isOpen, onClose }) => {
  const [phoneNumber, setPhoneNumber] = useState('');
  const [code, setCode] = useState('');
  // const [password, setPassword] = useState(''); // Removed
  const [inviteCode] = useState('');
  // const [loginMethod, setLoginMethod] = useState<'code' | 'password'>('code'); // Removed
  const [isLoading, setIsLoading] = useState(false);
  const isSubmittingRef = React.useRef(false);
  const [countdown, setCountdown] = useState(0);
  const [error, setError] = useState('');

  const { login } = useAuth();

  useEffect(() => {
    let timer: ReturnType<typeof setTimeout>;
    if (countdown > 0) {
      timer = setTimeout(() => setCountdown(countdown - 1), 1000);
    }
    return () => clearTimeout(timer);
  }, [countdown]);

  if (!isOpen) return null;

  const handleSendCode = async () => {
    if (!phoneNumber || phoneNumber.length !== 11) {
      setError('请输入正确的11位手机号');
      return;
    }
    setError('');
    setIsLoading(true);
    try {
      await sendVerificationCode(phoneNumber);
      setCountdown(60);
    } catch (err) {
      setError('发送验证码失败，请重试');
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    e.stopPropagation();

    if (isSubmittingRef.current) return;
    isSubmittingRef.current = true;
    setIsLoading(true);

    if (!phoneNumber) {
      setError('请输入手机号');
      setIsLoading(false);
      isSubmittingRef.current = false;
      return;
    }

    if (!code) {
      setError('请输入验证码');
      setIsLoading(false);
      isSubmittingRef.current = false;
      return;
    }

    setError('');

    try {
      // Always use code login
      const data = await loginOrRegister(
        phoneNumber,
        code,
        undefined, // password
        inviteCode || undefined
      );

      const user = data.user;

      // 仅允许管理员登录
      if (!user.is_superuser) {
        setError('仅管理员可登录后台管理系统');
        // 可选：如果不希望保留 Session，可以不调用 login(user)
        return;
      }

      login(user);
      onClose();
    } catch (err: any) {
      const msg = err.response?.data?.detail || '登录失败，请重试';
      setError(msg);
      console.error(err);
    } finally {
      setIsLoading(false);
      isSubmittingRef.current = false;
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
        <div className="p-8 pb-0 text-center">
          <div className="mx-auto w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center mb-4">
            <UserPlus className="w-6 h-6 text-blue-600" />
          </div>
          <h2 className="text-2xl font-bold text-gray-900">
            管理员登录
          </h2>
          <p className="text-gray-500 mt-2 text-sm">
            NotePDF 2 PPT 后台管理系统
          </p>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="p-8 space-y-4 pt-6">
          {error && (
            <div className="bg-red-50 text-red-600 text-sm p-3 rounded-lg border border-red-100">
              {error}
            </div>
          )}

          {/* Phone Input */}
          <div className="space-y-1">
            <label className="text-sm font-medium text-gray-700">手机号</label>
            <div className="relative">
              <input
                type="tel"
                value={phoneNumber}
                onChange={(e) => setPhoneNumber(e.target.value.replace(/\D/g, '').slice(0, 11))}
                className="w-full px-4 py-2 pl-10 bg-gray-50 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all"
                placeholder="请输入手机号"
              />
              <Smartphone className="w-5 h-5 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
            </div>
          </div>

          {/* Verification Code Input */}
          <div className="space-y-1">
            <label className="text-sm font-medium text-gray-700">验证码</label>
            <div className="flex gap-2">
              <div className="relative flex-1">
                <input
                  type="text"
                  value={code}
                  onChange={(e) => setCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                  className="w-full px-4 py-2 pl-10 bg-gray-50 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all"
                  placeholder="6位验证码"
                />
                <ShieldCheck className="w-5 h-5 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
              </div>
              <button
                type="button"
                onClick={handleSendCode}
                disabled={countdown > 0 || isLoading}
                className="px-4 py-2 bg-blue-50 text-blue-600 rounded-lg font-medium hover:bg-blue-100 transition-colors disabled:opacity-50 disabled:cursor-not-allowed whitespace-nowrap min-w-[100px]"
              >
                {countdown > 0 ? `${countdown}s` : '获取验证码'}
              </button>
            </div>
          </div>

          <button
            type="submit"
            disabled={isLoading}
            className="w-full bg-black text-white py-3 rounded-xl font-medium hover:bg-gray-800 transition-colors disabled:opacity-70 flex items-center justify-center gap-2 mt-2"
          >
            {isLoading ? (
              <>
                <Loader2 className="w-5 h-5 animate-spin" />
                登录中...
              </>
            ) : (
              '登录'
            )}
          </button>
        </form>
      </div>
    </div>
  );
};
