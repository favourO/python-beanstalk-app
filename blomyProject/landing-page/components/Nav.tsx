"use client";

import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import Image from "next/image";

export default function Nav() {
  const [scrolled, setScrolled] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    const handler = () => setScrolled(window.scrollY > 20);
    window.addEventListener("scroll", handler);
    return () => window.removeEventListener("scroll", handler);
  }, []);

  return (
    <motion.nav
      initial={{ y: -80, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.6, ease: "easeOut" }}
      aria-label="Main navigation"
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
        scrolled
          ? "bg-white/95 backdrop-blur-md shadow-[0_1px_0_#FFD9C2]"
          : "bg-white"
      }`}
    >
      <div className="max-w-[1200px] mx-auto px-6 h-16 flex items-center justify-between">
        {/* Logo */}
        <a href="/" className="flex items-center" aria-label="Vyla home">
          <Image src="https://vyla.health/assets/vyla-logo.png" alt="Vyla" width={1536} height={1024} className="h-26 w-auto" unoptimized priority />
        </a>

        {/* Desktop Nav */}
        <div className="hidden md:flex items-center gap-8">
          {["Features", "How it works", "Pricing", "Blog"].map((item) => (
            <a
              key={item}
              href={`#${item.toLowerCase().replace(/ /g, "-")}`}
              className="text-sm font-medium text-[#A06A52] hover:text-[#1E0C16] transition-colors"
            >
              {item}
            </a>
          ))}
        </div>

        {/* CTA */}
        <div className="hidden md:flex items-center gap-4">
          <a href="#" className="text-sm font-medium text-[#1E0C16] hover:text-[#FF7A33] transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#FF7A33] rounded">
            Sign in
          </a>
          <a
            href="#"
            className="text-sm font-medium bg-[#FF7A33] text-white px-5 py-2.5 rounded-full hover:bg-[#e86a22] transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#FF7A33] focus-visible:ring-offset-2"
          >
            Download free
          </a>
        </div>

        {/* Mobile menu button */}
        <button
          className="md:hidden p-2 text-[#1E0C16]"
          onClick={() => setMobileOpen(!mobileOpen)}
          aria-label="Toggle menu"
        >
          <div className="w-5 h-0.5 bg-current mb-1.5 transition-all" style={{ transform: mobileOpen ? "rotate(45deg) translateY(8px)" : "" }} />
          <div className="w-5 h-0.5 bg-current mb-1.5 transition-all" style={{ opacity: mobileOpen ? 0 : 1 }} />
          <div className="w-5 h-0.5 bg-current transition-all" style={{ transform: mobileOpen ? "rotate(-45deg) translateY(-8px)" : "" }} />
        </button>
      </div>

      {/* Mobile menu */}
      {mobileOpen && (
        <motion.div
          initial={{ opacity: 0, y: -8 }}
          animate={{ opacity: 1, y: 0 }}
          className="md:hidden bg-white border-t border-[#FFD9C2] px-6 py-4 flex flex-col gap-4"
        >
          {["Features", "How it works", "Pricing", "Blog"].map((item) => (
            <a
              key={item}
              href={`#${item.toLowerCase().replace(/ /g, "-")}`}
              className="text-sm font-medium text-[#A06A52]"
              onClick={() => setMobileOpen(false)}
            >
              {item}
            </a>
          ))}
          <div className="flex gap-3 pt-2">
            <a href="#" className="text-sm font-medium text-[#1E0C16]">Sign in</a>
            <a href="#" className="text-sm font-medium bg-[#FF7A33] text-white px-4 py-2 rounded-full">Download free</a>
          </div>
        </motion.div>
      )}
    </motion.nav>
  );
}
