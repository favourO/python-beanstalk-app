"use client";

import { useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { motion } from "framer-motion";

export default function ContactPage() {
  const [form, setForm] = useState({ name: "", email: "", subject: "", message: "" });
  const [sent, setSent] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    setForm(f => ({ ...f, [e.target.name]: e.target.value }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.name || !form.email || !form.subject || !form.message) return;
    setLoading(true);
    setError("");
    try {
      const base = process.env.NEXT_PUBLIC_API_URL ?? "https://vyla-stage-api.875kda1e0109p.eu-west-2.cs.amazonlightsail.com";
      const res = await fetch(`${base}/api/v1/public/contact`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(form),
      });
      if (!res.ok) throw new Error("Failed");
      setSent(true);
    } catch {
      setError("Something went wrong. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#FFF6F0]">
      <header className="bg-white border-b border-[#FFD9C2]">
        <div className="max-w-[1200px] mx-auto px-6 h-16 flex items-center justify-between">
          <Link href="/">
            <Image src="https://vyla.health/assets/vyla-logo.png" alt="Vyla" width={1536} height={1024} className="h-26 w-auto" unoptimized />
          </Link>
          <Link href="/" className="text-sm font-medium text-[#A06A52] hover:text-[#1E0C16] transition-colors">
            ← Back to home
          </Link>
        </div>
      </header>

      <main className="max-w-[680px] mx-auto px-6 py-16">
        <div className="mb-12">
          <p className="text-xs font-medium tracking-[0.12em] uppercase text-[#FF7A33] mb-3">Get in touch</p>
          <h1 className="font-serif text-[52px] leading-[1.08] tracking-[-0.02em] text-[#1E0C16] mb-4">Contact Us</h1>
          <p className="text-base font-light text-[#7A4A32] leading-relaxed">
            Have a question, feedback, or need support? Fill in the form below and we'll get back to you within 1–2 business days.
          </p>
        </div>

        {sent ? (
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            className="bg-white border border-[#FFD9C2] rounded-2xl p-10 text-center"
          >
            <div className="w-14 h-14 rounded-full bg-[#FFF0E8] flex items-center justify-center mx-auto mb-5">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#FF7A33" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M20 6L9 17l-5-5"/>
              </svg>
            </div>
            <h2 className="font-serif text-2xl text-[#1E0C16] mb-3">Message received!</h2>
            <p className="text-[15px] font-light text-[#7A4A32] leading-relaxed mb-6">
              Thanks for reaching out. We've sent a confirmation to <strong>{form.email}</strong> and will respond within 1–2 business days.
            </p>
            <Link
              href="/"
              className="inline-block bg-[#FF7A33] text-white text-sm font-semibold px-7 py-3 rounded-full hover:bg-[#e86a22] transition-colors"
            >
              Back to home
            </Link>
          </motion.div>
        ) : (
          <form onSubmit={handleSubmit} className="bg-white border border-[#FFD9C2] rounded-2xl p-8 space-y-5">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
              <div>
                <label className="block text-[13px] font-medium text-[#1E0C16] mb-1.5">Name</label>
                <input
                  type="text"
                  name="name"
                  value={form.name}
                  onChange={handleChange}
                  placeholder="Your full name"
                  required
                  className="w-full bg-[#FFF6F0] border border-[#FFD9C2] rounded-xl px-4 py-3 text-sm text-[#1E0C16] placeholder-[#C0988A] outline-none focus:border-[#FF7A33] focus:ring-2 focus:ring-[#FF7A33]/20 transition"
                />
              </div>
              <div>
                <label className="block text-[13px] font-medium text-[#1E0C16] mb-1.5">Email</label>
                <input
                  type="email"
                  name="email"
                  value={form.email}
                  onChange={handleChange}
                  placeholder="you@example.com"
                  required
                  className="w-full bg-[#FFF6F0] border border-[#FFD9C2] rounded-xl px-4 py-3 text-sm text-[#1E0C16] placeholder-[#C0988A] outline-none focus:border-[#FF7A33] focus:ring-2 focus:ring-[#FF7A33]/20 transition"
                />
              </div>
            </div>

            <div>
              <label className="block text-[13px] font-medium text-[#1E0C16] mb-1.5">Subject</label>
              <select
                name="subject"
                value={form.subject}
                onChange={handleChange}
                required
                className="w-full bg-[#FFF6F0] border border-[#FFD9C2] rounded-xl px-4 py-3 text-sm text-[#1E0C16] outline-none focus:border-[#FF7A33] focus:ring-2 focus:ring-[#FF7A33]/20 transition appearance-none"
              >
                <option value="" disabled>Select a subject</option>
                <option>General enquiry</option>
                <option>Technical support</option>
                <option>Billing & subscriptions</option>
                <option>Privacy & data</option>
                <option>Press & partnerships</option>
                <option>Other</option>
              </select>
            </div>

            <div>
              <label className="block text-[13px] font-medium text-[#1E0C16] mb-1.5">Message</label>
              <textarea
                name="message"
                value={form.message}
                onChange={handleChange}
                placeholder="Tell us how we can help..."
                required
                rows={5}
                className="w-full bg-[#FFF6F0] border border-[#FFD9C2] rounded-xl px-4 py-3 text-sm text-[#1E0C16] placeholder-[#C0988A] outline-none focus:border-[#FF7A33] focus:ring-2 focus:ring-[#FF7A33]/20 transition resize-none"
              />
            </div>

            {error && (
              <p className="text-sm text-red-500">{error}</p>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-[#FF7A33] hover:bg-[#e86a22] disabled:opacity-60 text-white text-sm font-semibold py-3.5 rounded-xl transition-colors"
            >
              {loading ? "Sending…" : "Send message"}
            </button>

            <p className="text-[12px] text-[#B0938A] text-center">
              Vyla Health Technologies Inc · 6 Giles Avenue, London RM13
            </p>
          </form>
        )}
      </main>

      <footer className="border-t border-[#FFD9C2] py-8">
        <div className="max-w-[680px] mx-auto px-6 flex flex-col sm:flex-row items-center justify-between gap-4">
          <p className="text-xs text-[#A06A52]">© 2026 DemyCorp Ltd. All rights reserved.</p>
          <Link href="/" className="text-xs font-medium text-[#FF7A33] hover:text-[#e86a22] transition-colors">
            ← Back to home
          </Link>
        </div>
      </footer>
    </div>
  );
}
