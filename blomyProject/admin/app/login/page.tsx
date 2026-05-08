"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";
import { adminLogin, setToken, ApiError } from "@/lib/api";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [remember, setRemember] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const token = await adminLogin(email, password);
      setToken(token);
      router.push("/");
    } catch (err) {
      if (err instanceof ApiError) {
        setError(err.status === 403 ? "Admin access required. This account is not authorised." : "Invalid email or password.");
      } else {
        setError("Could not reach the server. Please try again.");
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex">
      {/* ── Left panel ── */}
      <div className="hidden lg:flex lg:w-[45%] bg-[#FEF3EC] flex-col px-12 py-10 relative overflow-hidden">
        {/* Logo */}
        <div className="flex items-center gap-2 z-10">
          <Image src="/vyla-logo.png" alt="Vyla" width={72} height={28} className="h-7 w-auto" unoptimized />
          <span className="text-[10px] font-semibold tracking-[0.18em] uppercase text-[#C4895A] border-l border-[#C4895A]/40 pl-2 ml-0.5">
            Admin Portal
          </span>
        </div>

        {/* Welcome copy */}
        <div className="mt-20 z-10">
          <h1 className="text-4xl font-bold text-[#1E0C16] leading-tight mb-4">
            Welcome back,<br />Admin
          </h1>
          <p className="text-[#7C5C4E] text-sm leading-relaxed max-w-xs">
            Securely access the Vyla Admin Portal to manage users, subscriptions, insights and more.
          </p>
        </div>

        {/* Illustration */}
        <div className="absolute bottom-0 right-0 w-[340px] h-[340px] z-0">
          {/* Peach blob */}
          <div className="absolute bottom-[-60px] right-[-60px] w-[340px] h-[340px] rounded-full bg-[#FFCFAB]/50" />
          {/* Dashboard card mock */}
          <div className="absolute bottom-24 right-8 w-[180px] bg-white rounded-2xl shadow-lg p-4 z-10">
            <div className="flex items-center justify-between mb-3">
              <div className="w-16 h-2 bg-[#FFD9C2] rounded-full" />
              <div className="w-4 h-4 rounded-full bg-[#FF7A33]/20 flex items-center justify-center">
                <div className="w-2 h-2 rounded-full bg-[#FF7A33]" />
              </div>
            </div>
            <div className="space-y-1.5 mb-3">
              {[70, 50, 85, 40].map((w, i) => (
                <div key={i} className="flex items-center gap-2">
                  <div
                    className="h-2 rounded-full bg-gradient-to-r from-[#FF7A33] to-[#FFB38A]"
                    style={{ width: `${w}%` }}
                  />
                </div>
              ))}
            </div>
            <div className="flex gap-1">
              {[40, 65, 55, 80, 45, 70].map((h, i) => (
                <div
                  key={i}
                  className="flex-1 bg-[#FF7A33]/20 rounded-sm"
                  style={{ height: `${h * 0.5}px` }}
                />
              ))}
            </div>
          </div>
          {/* Shield / lock badge */}
          <div className="absolute bottom-12 right-44 w-14 h-14 bg-white rounded-2xl shadow-lg flex items-center justify-center z-20">
            <svg width="28" height="28" viewBox="0 0 24 24" fill="none">
              <path d="M12 2L4 6v6c0 5.25 3.5 10.15 8 11.35C16.5 22.15 20 17.25 20 12V6l-8-4z"
                fill="#FF7A33" fillOpacity="0.15" stroke="#FF7A33" strokeWidth="1.5" strokeLinejoin="round" />
              <rect x="9" y="11" width="6" height="5" rx="1" fill="#FF7A33" />
              <circle cx="12" cy="10" r="1.5" fill="#FF7A33" />
              <path d="M10.5 10.5V9a1.5 1.5 0 013 0v1.5" stroke="#FF7A33" strokeWidth="1.2" strokeLinecap="round" />
            </svg>
          </div>
        </div>

        {/* Bottom decoration circle */}
        <div className="absolute bottom-[-120px] left-[-80px] w-[280px] h-[280px] rounded-full border border-[#FFCFAB]/40" />
      </div>

      {/* ── Right panel ── */}
      <div className="flex-1 flex flex-col justify-between bg-white px-8 py-10 sm:px-16">
        <div className="flex-1 flex flex-col justify-center max-w-md mx-auto w-full">
          {/* Mobile logo */}
          <div className="lg:hidden flex items-center gap-2 mb-10">
            <Image src="/vyla-logo.png" alt="Vyla" width={64} height={24} className="h-6 w-auto" unoptimized />
            <span className="text-[10px] font-semibold tracking-[0.18em] uppercase text-[#C4895A] border-l border-[#C4895A]/40 pl-2">
              Admin Portal
            </span>
          </div>

          <h2 className="text-2xl font-bold text-[#1E0C16] mb-1">Admin Sign In</h2>
          <p className="text-sm text-[#9E7B6E] mb-8">Please enter your credentials to continue</p>

          {error && (
            <div className="mb-5 flex items-start gap-3 bg-red-50 border border-red-200 text-red-700 text-sm px-4 py-3 rounded-xl">
              <svg className="mt-0.5 shrink-0" width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
                <path d="M8 1a7 7 0 100 14A7 7 0 008 1zm-.75 4a.75.75 0 011.5 0v3.5a.75.75 0 01-1.5 0V5zm.75 7a1 1 0 110-2 1 1 0 010 2z" />
              </svg>
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-5">
            {/* Email */}
            <div>
              <label className="block text-xs font-semibold text-[#1E0C16] mb-1.5">Email address</label>
              <div className="relative">
                <span className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[#C4895A]">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                    <rect x="2" y="4" width="20" height="16" rx="2" />
                    <path d="M2 7l10 7 10-7" />
                  </svg>
                </span>
                <input
                  type="email"
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  required
                  placeholder="admin@vyla.com"
                  className="w-full pl-10 pr-4 py-2.5 border border-[#E8DDD9] rounded-xl text-sm text-[#1E0C16] placeholder-[#C4A89A] focus:outline-none focus:border-[#FF7A33] focus:ring-1 focus:ring-[#FF7A33]/20 transition-colors"
                />
              </div>
            </div>

            {/* Password */}
            <div>
              <div className="flex items-center justify-between mb-1.5">
                <label className="block text-xs font-semibold text-[#1E0C16]">Password</label>
                <button type="button" className="text-xs text-[#FF7A33] hover:underline">Forgot password?</button>
              </div>
              <div className="relative">
                <span className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[#C4895A]">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                    <rect x="3" y="11" width="18" height="11" rx="2" />
                    <path d="M7 11V7a5 5 0 0110 0v4" />
                  </svg>
                </span>
                <input
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  required
                  placeholder="••••••••••"
                  className="w-full pl-10 pr-10 py-2.5 border border-[#E8DDD9] rounded-xl text-sm text-[#1E0C16] placeholder-[#C4A89A] focus:outline-none focus:border-[#FF7A33] focus:ring-1 focus:ring-[#FF7A33]/20 transition-colors"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(v => !v)}
                  className="absolute right-3.5 top-1/2 -translate-y-1/2 text-[#C4895A] hover:text-[#FF7A33]"
                >
                  {showPassword ? (
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94" />
                      <path d="M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19" />
                      <line x1="1" y1="1" x2="23" y2="23" />
                    </svg>
                  ) : (
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M1 12S5 4 12 4s11 8 11 8-4 8-11 8S1 12 1 12z" />
                      <circle cx="12" cy="12" r="3" />
                    </svg>
                  )}
                </button>
              </div>
            </div>

            {/* Remember device */}
            <label className="flex items-center gap-2.5 cursor-pointer select-none">
              <div
                onClick={() => setRemember(v => !v)}
                className={`w-4 h-4 rounded border flex items-center justify-center transition-colors ${remember ? "bg-[#FF7A33] border-[#FF7A33]" : "border-[#D6C8C2]"}`}
              >
                {remember && (
                  <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                    <path d="M1.5 5l2.5 2.5 4.5-4.5" stroke="white" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                )}
              </div>
              <span className="text-xs text-[#7C5C4E]">Remember this device for 30 days</span>
            </label>

            {/* Sign in button */}
            <button
              type="submit"
              disabled={loading}
              className="w-full bg-[#FF7A33] hover:bg-[#e86a22] disabled:opacity-60 text-white font-semibold py-2.5 rounded-xl text-sm transition-colors shadow-sm shadow-[#FF7A33]/30"
            >
              {loading ? "Signing in…" : "Sign In"}
            </button>
          </form>

          {/* Divider */}
          <div className="flex items-center gap-3 my-5">
            <div className="flex-1 h-px bg-[#EDE5E0]" />
            <span className="text-xs text-[#C4A89A]">or</span>
            <div className="flex-1 h-px bg-[#EDE5E0]" />
          </div>

          {/* Google SSO (visual only) */}
          <button
            type="button"
            disabled
            className="w-full flex items-center justify-center gap-3 border border-[#E8DDD9] rounded-xl py-2.5 text-sm text-[#7C5C4E] font-medium hover:bg-[#FFF8F4] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <svg width="18" height="18" viewBox="0 0 48 48">
              <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
              <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
              <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
              <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.18 1.48-4.97 2.31-8.16 2.31-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
            </svg>
            Sign in with Google
          </button>

          {/* Security note */}
          <div className="flex items-center justify-center gap-1.5 mt-6 text-xs text-[#C4A89A]">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M12 2L4 6v6c0 5.25 3.5 10.15 8 11.35C16.5 22.15 20 17.25 20 12V6l-8-4z" />
            </svg>
            Secure access for authorized personnel only
          </div>
        </div>

        {/* Footer */}
        <footer className="text-center text-[11px] text-[#C4A89A] mt-8">
          <p>© 2024 Vyla Health Technologies Inc. All rights reserved.</p>
          <div className="flex items-center justify-center gap-3 mt-1">
            <a href="/privacy" className="hover:text-[#FF7A33] transition-colors">Privacy Policy</a>
            <span>·</span>
            <a href="/terms" className="hover:text-[#FF7A33] transition-colors">Terms of Use</a>
            <span>·</span>
            <a href="mailto:support@vyla.health" className="hover:text-[#FF7A33] transition-colors">Support</a>
          </div>
        </footer>
      </div>
    </div>
  );
}
