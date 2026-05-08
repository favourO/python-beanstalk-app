"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";
import { adminLogin, setToken, ApiError } from "@/lib/api";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
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
        setError(err.status === 403 ? "Admin access required." : "Invalid credentials.");
      } else {
        setError("Could not reach the server. Is the API running?");
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-[#1E0C16] flex items-center justify-center px-4">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <Image src="/vyla-logo.png" alt="Vyla" width={120} height={40} className="h-12 w-auto mx-auto mb-4" unoptimized />
          <p className="text-[11px] font-medium tracking-[0.14em] uppercase text-[#FF7A33] mb-1">DemyCorp Ltd</p>
          <p className="text-white/60 text-sm">Internal admin portal</p>
        </div>

        <form onSubmit={handleSubmit} className="bg-white/5 border border-white/10 rounded-2xl p-7 space-y-4">
          {error && (
            <div className="bg-red-900/30 border border-red-500/30 text-red-300 text-sm px-4 py-3 rounded-lg">
              {error}
            </div>
          )}
          <div>
            <label className="block text-xs font-medium text-white/50 mb-1.5">Email</label>
            <input
              type="email"
              value={email}
              onChange={e => setEmail(e.target.value)}
              required
              className="w-full bg-white/5 border border-white/15 rounded-lg px-3 py-2.5 text-sm text-white placeholder-white/30 focus:outline-none focus:border-[#FF7A33]/60"
              placeholder="admin@vyla.health"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-white/50 mb-1.5">Password</label>
            <input
              type="password"
              value={password}
              onChange={e => setPassword(e.target.value)}
              required
              className="w-full bg-white/5 border border-white/15 rounded-lg px-3 py-2.5 text-sm text-white placeholder-white/30 focus:outline-none focus:border-[#FF7A33]/60"
              placeholder="••••••••"
            />
          </div>
          <button
            type="submit"
            disabled={loading}
            className="w-full bg-[#FF7A33] hover:bg-[#e86a22] disabled:opacity-60 text-white font-semibold py-2.5 rounded-lg text-sm transition-colors"
          >
            {loading ? "Signing in…" : "Sign in"}
          </button>
        </form>

        <p className="text-center text-xs text-white/20 mt-6">
          For authorised DemyCorp Ltd personnel only
        </p>
      </div>
    </div>
  );
}
