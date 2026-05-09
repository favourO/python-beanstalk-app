import type { Metadata } from "next";
import Link from "next/link";
import Image from "next/image";
import ContactForm from "@/components/ContactForm";
import JsonLd from "@/components/JsonLd";

export const metadata: Metadata = {
  title: "Contact Us",
  description:
    "Get in touch with the Vyla team. We respond within 1–2 business days. Reach us for support, billing, privacy questions, or press enquiries.",
  alternates: { canonical: "https://vyla.health/contact" },
  robots: { index: true, follow: true },
};

const breadcrumbSchema = {
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  itemListElement: [
    { "@type": "ListItem", position: 1, name: "Home", item: "https://vyla.health" },
    { "@type": "ListItem", position: 2, name: "Contact", item: "https://vyla.health/contact" },
  ],
};

export default function ContactPage() {
  return (
    <div className="min-h-screen bg-[#FFF6F0]">
      <JsonLd data={breadcrumbSchema} />

      <header className="bg-white border-b border-[#FFD9C2]">
        <div className="max-w-[1200px] mx-auto px-6 h-16 flex items-center justify-between">
          <Link href="/" aria-label="Vyla home">
            <Image
              src="https://vyla.health/assets/vyla-logo.png"
              alt="Vyla"
              width={1536}
              height={1024}
              className="h-26 w-auto"
              unoptimized
            />
          </Link>
          <Link
            href="/"
            className="text-sm font-medium text-[#A06A52] hover:text-[#1E0C16] transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#FF7A33] rounded"
          >
            ← Back to home
          </Link>
        </div>
      </header>

      <main id="main-content" className="max-w-[680px] mx-auto px-6 py-16">
        <nav aria-label="Breadcrumb" className="mb-8">
          <ol className="flex items-center gap-2 text-xs text-[#A06A52]" role="list">
            <li>
              <Link href="/" className="hover:text-[#FF7A33] transition-colors">
                Home
              </Link>
            </li>
            <li aria-hidden="true">/</li>
            <li aria-current="page" className="text-[#1E0C16]">
              Contact
            </li>
          </ol>
        </nav>

        <div className="mb-12">
          <p className="text-xs font-medium tracking-[0.12em] uppercase text-[#FF7A33] mb-3">
            Get in touch
          </p>
          <h1 className="font-serif text-[52px] leading-[1.08] tracking-[-0.02em] text-[#1E0C16] mb-4">
            Contact Us
          </h1>
          <p className="text-base font-light text-[#7A4A32] leading-relaxed">
            Have a question, feedback, or need support? Fill in the form below
            and we&apos;ll get back to you within 1–2 business days.
          </p>
        </div>

        <ContactForm />
      </main>

      <footer className="border-t border-[#FFD9C2] py-8">
        <div className="max-w-[680px] mx-auto px-6 flex flex-col sm:flex-row items-center justify-between gap-4">
          <p className="text-xs text-[#A06A52]">
            © 2026 DemyCorp Ltd. All rights reserved.
          </p>
          <Link
            href="/"
            className="text-xs font-medium text-[#FF7A33] hover:text-[#e86a22] transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#FF7A33] rounded"
          >
            ← Back to home
          </Link>
        </div>
      </footer>
    </div>
  );
}
