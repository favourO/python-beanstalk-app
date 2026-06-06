"use client";

import Image from "next/image";
import { motion, useReducedMotion } from "framer-motion";

function AppleIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
    </svg>
  );
}

function GooglePlayIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M3.18 23.54c.37.2.8.22 1.19.07l11.44-6.6L13.1 14.3 3.18 23.54z" fill="#EA4335" />
      <path d="M20.32 10.14 17.5 8.47l-3.2 2.9 3.2 3.2 2.84-1.64c.81-.47.81-1.32-.02-1.79z" fill="#FBBC05" />
      <path d="M3.18.46c-.12.22-.18.47-.18.73v21.62l9.92-9.9L3.18.46z" fill="#4285F4" />
      <path d="M13.1 9.7 4.37.37C3.98.21 3.55.23 3.18.46l9.92 9.24L13.1 9.7z" fill="#34A853" />
    </svg>
  );
}

export default function HeroSection() {
  const shouldReduceMotion = useReducedMotion();

  const fadeUp = (delay: number) =>
    shouldReduceMotion
      ? {}
      : { initial: { opacity: 0, y: 20 }, animate: { opacity: 1, y: 0 }, transition: { delay, duration: 0.6 } };

  return (
    <section
      id="hero"
      aria-labelledby="hero-heading"
      className="relative min-h-screen bg-[#FFF6F0] overflow-hidden pt-16"
    >
      {/* Decorative background gradients — hidden from assistive tech */}
      <div
        aria-hidden="true"
        className="absolute pointer-events-none"
        style={{ left: -150, top: -200, width: 700, height: 700, borderRadius: "50%", background: "radial-gradient(circle at 50% 50%, rgba(255,138,76,0.10) 0%, rgba(255,138,76,0) 65%)" }}
      />
      <div
        aria-hidden="true"
        className="absolute pointer-events-none"
        style={{ right: -100, bottom: -50, width: 500, height: 500, borderRadius: "50%", background: "radial-gradient(circle at 50% 50%, rgba(224,107,46,0.08) 0%, rgba(224,107,46,0) 65%)" }}
      />
      <div
        aria-hidden="true"
        className="absolute pointer-events-none"
        style={{ right: 200, top: 100, width: 300, height: 300, borderRadius: "50%", background: "radial-gradient(circle at 50% 50%, rgba(59,172,106,0.06) 0%, rgba(59,172,106,0) 65%)" }}
      />

      <div className="relative max-w-[1200px] mx-auto px-6 flex flex-col lg:flex-row items-center gap-12 pt-16 pb-24 lg:pt-20 lg:pb-32">
        {/* Left: Copy */}
        <div className="flex-1 max-w-[560px]">
          {/* Badge */}
          <motion.div
            {...fadeUp(0.1)}
            className="inline-flex items-center gap-2 mb-8"
          >
            <motion.span
              aria-hidden="true"
              className="w-1.5 h-1.5 rounded-full"
              animate={shouldReduceMotion ? {} : { backgroundColor: ["#C0392B", "#E8A135", "#3BAC6A", "#8E6BBF", "#C0392B"] }}
              transition={{ duration: 4, repeat: Infinity, ease: "easeInOut", times: [0, 0.25, 0.5, 0.75, 1] }}
            />
            <span className="text-[11px] font-medium tracking-[0.1em] uppercase text-[#FF7A33]">
              Built for private, everyday cycle tracking
            </span>
          </motion.div>

          {/* H1 — rendered immediately (no opacity:0 initial) for LCP */}
          <h1
            id="hero-heading"
            className="font-serif text-[68px] lg:text-[79px] leading-[1.05] tracking-[-0.03em] text-[#1E0C16] mb-6"
          >
            Your cycle,
            <br />
            <span className="text-[#FF7A33]">made clearer.</span>
          </h1>

          {/* Subtext */}
          <motion.p
            {...fadeUp(0.2)}
            className="text-base font-light leading-[2.08] text-[#A06A52] mb-10 max-w-[470px]"
          >
            Vyla helps you track periods, symptoms, moods, fertility signs, and
            daily patterns in one calm place. Get AI-powered cycle insights,
            BBT temperature trends, and ovulation tracking so you can understand
            your body without turning every change into a medical concern.
          </motion.p>

          {/* Download buttons */}
          <motion.div
            {...fadeUp(0.3)}
            className="flex flex-wrap gap-3 mb-8"
          >
            <a
              href="#"
              aria-label="Download Vyla on the App Store"
              className="flex items-center gap-3 bg-[#1E0C16] text-white px-5 h-[59px] rounded-[14px] hover:bg-[#2e1a26] transition-colors min-w-[168px] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#FF7A33]"
            >
              <AppleIcon />
              <div>
                <p className="text-[10px] opacity-65 leading-none mb-1">Download on the</p>
                <p className="text-[15px] font-medium leading-none">App Store</p>
              </div>
            </a>
            <a
              href="#"
              aria-label="Get Vyla on Google Play"
              className="flex items-center gap-3 bg-white text-[#1E0C16] border border-[#FFE5D6] px-5 h-[59px] rounded-[14px] hover:bg-[#FFF6F0] transition-colors min-w-[176px] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#FF7A33]"
            >
              <GooglePlayIcon />
              <div>
                <p className="text-[10px] opacity-65 leading-none mb-1">Get it on</p>
                <p className="text-[15px] font-medium leading-none">Google Play</p>
              </div>
            </a>
          </motion.div>

          {/* Launch proof */}
          <motion.div
            {...fadeUp(0.4)}
            className="flex items-center gap-2.5"
          >
            <span className="w-2 h-2 rounded-full bg-[#FF7A33] shrink-0 animate-pulse" aria-hidden="true" />
            <span className="text-[13px] font-medium text-[#A06A52]">
              Now live · Free to download · No credit card needed
            </span>
          </motion.div>
        </div>

        {/* Right: App mockup */}
        <motion.div
          initial={shouldReduceMotion ? { opacity: 0 } : { opacity: 0, x: 40, scale: 0.96 }}
          animate={shouldReduceMotion ? { opacity: 1 } : { opacity: 1, x: 0, scale: 1 }}
          transition={{ delay: 0.3, duration: 0.8, ease: "easeOut" }}
          className="flex-shrink-0 relative"
        >
          <div className="relative w-[340px] lg:w-[378px] rounded-[24px] overflow-hidden bg-[#FFF6F0]">
            <Image
              src="https://vyla.health/assets/images/hero-app-mockup.png"
              alt="Vyla app showing cycle calendar, period predictions, and symptom logging on iPhone"
              width={378}
              height={738}
              className="w-full h-auto"
              priority
              fetchPriority="high"
            />
          </div>
        </motion.div>
      </div>
    </section>
  );
}
