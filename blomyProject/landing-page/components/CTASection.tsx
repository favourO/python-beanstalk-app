"use client";

import { useState } from "react";
import { motion } from "framer-motion";
import FadeIn from "./FadeIn";

function AppleIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
      <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
    </svg>
  );
}

function GooglePlayIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
      <path d="M3.18 23.54c.37.2.8.22 1.19.07l11.44-6.6L13.1 14.3 3.18 23.54z" fill="#EA4335"/>
      <path d="M20.32 10.14 17.5 8.47l-3.2 2.9 3.2 3.2 2.84-1.64c.81-.47.81-1.32-.02-1.79z" fill="#FBBC05"/>
      <path d="M3.18.46c-.12.22-.18.47-.18.73v21.62l9.92-9.9L3.18.46z" fill="#4285F4"/>
      <path d="M13.1 9.7 4.37.37C3.98.21 3.55.23 3.18.46l9.92 9.24L13.1 9.7z" fill="#34A853"/>
    </svg>
  );
}

export default function CTASection() {
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);

  const [error, setError] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email) return;
    setError("");
    try {
      const base = process.env.NEXT_PUBLIC_API_URL ?? "https://stage.api.vyla.health";
      const res = await fetch(`${base}/api/v1/public/send-download`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
      });
      if (!res.ok) throw new Error("Failed");
      setSent(true);
    } catch {
      setError("Something went wrong. Please try again.");
    }
  };

  return (
    <section className="relative bg-[#1E0C16] py-32 overflow-hidden">
      {/* Concentric rings */}
      {[400, 300, 210, 130].map((size, i) => (
        <motion.div
          key={i}
          className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 border border-white/8 pointer-events-none"
          style={{ width: size * 2, height: size * 2, borderRadius: size }}
          animate={{ scale: [1, 1.06, 1], opacity: [0.4, 1, 0.4] }}
          transition={{ duration: 5, repeat: Infinity, delay: i * 0.7, ease: "easeInOut" }}
        />
      ))}

      <div className="relative max-w-[640px] mx-auto px-6 text-center">
        <FadeIn>
          <p className="text-[11px] font-medium tracking-[0.12em] uppercase text-[#FF7A33]/70 mb-4">Get Vyla</p>
          <h2 className="font-serif text-[64px] lg:text-[72px] leading-[1.0] tracking-[-0.03em] text-white mb-4">
            Start tracking your
            <br />cycle today.
          </h2>
          <p className="text-base font-light text-white/40 mb-10">Free to download. No credit card needed.</p>

          {/* App Store buttons */}
          <div className="flex flex-wrap gap-3 justify-center mb-10">
            <a
              href="#"
              className="flex items-center gap-3 bg-[#1E0C16] border border-white/20 text-white px-5 h-[56px] rounded-[14px] hover:bg-white/5 transition-colors min-w-[160px]"
            >
              <AppleIcon />
              <div className="text-left">
                <p className="text-[9px] opacity-65 leading-none mb-1">Download on the</p>
                <p className="text-[14px] font-medium leading-none">App Store</p>
              </div>
            </a>
            <a
              href="#"
              className="flex items-center gap-3 bg-white text-[#1E0C16] px-5 h-[56px] rounded-[14px] hover:bg-[#FFF6F0] transition-colors min-w-[160px]"
            >
              <GooglePlayIcon />
              <div className="text-left">
                <p className="text-[9px] opacity-65 leading-none mb-1">Get it on</p>
                <p className="text-[14px] font-medium leading-none">Google Play</p>
              </div>
            </a>
          </div>

          {/* Email form */}
          <p className="text-sm text-white/30 mb-4">Or get the download link sent to you</p>
          {sent ? (
            <motion.p
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              className="text-sm text-[#FF7A33]"
            >
              ✓ Check your inbox — link on its way!
            </motion.p>
          ) : (
            <>
              <form onSubmit={handleSubmit} className="flex gap-0 max-w-[420px] mx-auto">
                <div className="flex-1 bg-white/8 border border-white/15 rounded-full flex items-center pl-5 pr-2 gap-2">
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="Your email address"
                    className="flex-1 bg-transparent text-sm text-white placeholder-white/30 outline-none py-3.5"
                  />
                  <button
                    type="submit"
                    className="bg-white text-[#1E0C16] text-sm font-medium px-5 py-2.5 rounded-full hover:bg-[#FFF6F0] transition-colors shrink-0"
                  >
                    Send me the link
                  </button>
                </div>
              </form>
              {error && (
                <p className="text-xs text-red-400 mt-2">{error}</p>
              )}
            </>
          )}
        </FadeIn>
      </div>
    </section>
  );
}
