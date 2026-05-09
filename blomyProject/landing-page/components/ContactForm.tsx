"use client";

import { useState } from "react";
import { motion } from "framer-motion";
import Link from "next/link";

export default function ContactForm() {
  const [form, setForm] = useState({
    name: "",
    email: "",
    subject: "",
    message: "",
  });
  const [sent, setSent] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleChange = (
    e: React.ChangeEvent<
      HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement
    >
  ) => {
    setForm((f) => ({ ...f, [e.target.name]: e.target.value }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.name || !form.email || !form.subject || !form.message) return;
    setLoading(true);
    setError("");
    try {
      const base =
        process.env.NEXT_PUBLIC_API_URL ??
        "https://vyla-stage-api.875kda1e0109p.eu-west-2.cs.amazonlightsail.com";
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

  if (sent) {
    return (
      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        className="bg-white border border-[#FFD9C2] rounded-2xl p-10 text-center"
        role="alert"
        aria-live="polite"
      >
        <div
          className="w-14 h-14 rounded-full bg-[#FFF0E8] flex items-center justify-center mx-auto mb-5"
          aria-hidden="true"
        >
          <svg
            width="28"
            height="28"
            viewBox="0 0 24 24"
            fill="none"
            stroke="#FF7A33"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M20 6L9 17l-5-5" />
          </svg>
        </div>
        <h2 className="font-serif text-2xl text-[#1E0C16] mb-3">
          Message received!
        </h2>
        <p className="text-[15px] font-light text-[#7A4A32] leading-relaxed mb-6">
          Thanks for reaching out. We&apos;ve sent a confirmation to{" "}
          <strong>{form.email}</strong> and will respond within 1–2 business
          days.
        </p>
        <Link
          href="/"
          className="inline-block bg-[#FF7A33] text-white text-sm font-semibold px-7 py-3 rounded-full hover:bg-[#e86a22] transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#FF7A33] focus-visible:ring-offset-2"
        >
          Back to home
        </Link>
      </motion.div>
    );
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="bg-white border border-[#FFD9C2] rounded-2xl p-8 space-y-5"
      noValidate
    >
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
        <div>
          <label
            htmlFor="name"
            className="block text-[13px] font-medium text-[#1E0C16] mb-1.5"
          >
            Name
          </label>
          <input
            type="text"
            id="name"
            name="name"
            value={form.name}
            onChange={handleChange}
            placeholder="Your full name"
            required
            autoComplete="name"
            className="w-full bg-[#FFF6F0] border border-[#FFD9C2] rounded-xl px-4 py-3 text-sm text-[#1E0C16] placeholder-[#C0988A] outline-none focus:border-[#FF7A33] focus:ring-2 focus:ring-[#FF7A33]/20 transition"
          />
        </div>
        <div>
          <label
            htmlFor="email"
            className="block text-[13px] font-medium text-[#1E0C16] mb-1.5"
          >
            Email
          </label>
          <input
            type="email"
            id="email"
            name="email"
            value={form.email}
            onChange={handleChange}
            placeholder="you@example.com"
            required
            autoComplete="email"
            className="w-full bg-[#FFF6F0] border border-[#FFD9C2] rounded-xl px-4 py-3 text-sm text-[#1E0C16] placeholder-[#C0988A] outline-none focus:border-[#FF7A33] focus:ring-2 focus:ring-[#FF7A33]/20 transition"
          />
        </div>
      </div>

      <div>
        <label
          htmlFor="subject"
          className="block text-[13px] font-medium text-[#1E0C16] mb-1.5"
        >
          Subject
        </label>
        <select
          id="subject"
          name="subject"
          value={form.subject}
          onChange={handleChange}
          required
          className="w-full bg-[#FFF6F0] border border-[#FFD9C2] rounded-xl px-4 py-3 text-sm text-[#1E0C16] outline-none focus:border-[#FF7A33] focus:ring-2 focus:ring-[#FF7A33]/20 transition appearance-none"
        >
          <option value="" disabled>
            Select a subject
          </option>
          <option>General enquiry</option>
          <option>Technical support</option>
          <option>Billing &amp; subscriptions</option>
          <option>Privacy &amp; data</option>
          <option>Press &amp; partnerships</option>
          <option>Other</option>
        </select>
      </div>

      <div>
        <label
          htmlFor="message"
          className="block text-[13px] font-medium text-[#1E0C16] mb-1.5"
        >
          Message
        </label>
        <textarea
          id="message"
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
        <p role="alert" className="text-sm text-red-500">
          {error}
        </p>
      )}

      <button
        type="submit"
        disabled={loading}
        className="w-full bg-[#FF7A33] hover:bg-[#e86a22] disabled:opacity-60 text-white text-sm font-semibold py-3.5 rounded-xl transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#FF7A33] focus-visible:ring-offset-2"
      >
        {loading ? "Sending…" : "Send message"}
      </button>

      <p className="text-[12px] text-[#B0938A] text-center">
        Vyla Health Technologies Inc · 6 Giles Avenue, London RM13
      </p>
    </form>
  );
}
