import type { Metadata } from "next";
import Link from "next/link";
import Image from "next/image";
import Footer from "@/components/Footer";
import { buildMetadata } from "@/lib/seo";

export const metadata: Metadata = buildMetadata({
  title: "Blog — Cycle Health, Wellness & BBT Tracking Guides",
  description:
    "In-depth articles on cycle tracking, BBT temperature charting, ovulation awareness, wearable health insights, and women's wellness from the Vyla team.",
  keywords: [
    "cycle tracking guide",
    "period health articles",
    "BBT temperature charting",
    "ovulation awareness",
    "women's wellness blog",
    "menstrual health",
  ],
  path: "/blog",
});

const topics = [
  {
    title: "Cycle Tracking",
    description:
      "Guides on logging your period, understanding cycle phases, spotting patterns, and getting the most from Vyla's tracking features.",
    href: "/cycle-tracking",
    color: "#FFF6DD",
    label: "Read more →",
  },
  {
    title: "BBT & Temperature",
    description:
      "How to measure basal body temperature accurately, chart thermal shifts, and use temperature data to understand ovulation timing.",
    href: "/bbt-tracking",
    color: "#EDFEF1",
    label: "Read more →",
  },
  {
    title: "Ovulation Awareness",
    description:
      "Understanding LH surges, cervical mucus, fertile windows, and how to interpret ovulation signals across multiple cycles.",
    href: "/ovulation-tracking",
    color: "#FFF0F8",
    label: "Read more →",
  },
  {
    title: "Wearable Insights",
    description:
      "Using Oura Ring and other wearables alongside cycle tracking — what temperature and HRV data can reveal about your cycle.",
    href: "/wearable-cycle-insights",
    color: "#E6FDF9",
    label: "Read more →",
  },
];

export default function BlogPage() {
  return (
    <div className="min-h-screen bg-[#FFF6F0]">
      <header className="bg-white border-b border-[#FFD9C2] sticky top-0 z-50">
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
          <a
            href="#"
            className="text-sm font-medium bg-[#FF7A33] text-white px-5 py-2 rounded-full hover:bg-[#e86a22] transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#FF7A33] focus-visible:ring-offset-2"
          >
            Download free
          </a>
        </div>
      </header>

      <main id="main-content">
        {/* Hero */}
        <section className="bg-[#FFF6F0] pt-16 pb-20">
          <div className="max-w-[1200px] mx-auto px-6">
            <nav aria-label="Breadcrumb" className="mb-10">
              <ol className="flex items-center gap-2 text-xs text-[#A06A52]" role="list">
                <li>
                  <Link href="/" className="hover:text-[#FF7A33] transition-colors">
                    Home
                  </Link>
                </li>
                <li aria-hidden="true">/</li>
                <li aria-current="page" className="text-[#1E0C16]">Blog</li>
              </ol>
            </nav>

            <div className="max-w-[640px]">
              <p className="text-[11px] font-medium tracking-[0.12em] uppercase text-[#FF7A33] mb-4">
                Articles & guides
              </p>
              <h1 className="font-serif text-[58px] lg:text-[68px] leading-[1.06] tracking-[-0.03em] text-[#1E0C16] mb-5">
                Cycle health,
                <br />
                <span className="text-[#FF7A33]">clearly explained.</span>
              </h1>
              <p className="text-lg font-light text-[#A06A52] leading-relaxed">
                In-depth guides on cycle tracking, BBT temperature charting,
                ovulation awareness, wearable health insights, and women&apos;s
                wellness — from the Vyla team.
              </p>
            </div>
          </div>
        </section>

        {/* Topic grid */}
        <section className="bg-white py-20 border-t border-[#FFD9C2]/40">
          <div className="max-w-[1200px] mx-auto px-6">
            <h2 className="font-serif text-[36px] text-[#1E0C16] tracking-[-0.02em] mb-10">
              Browse by topic
            </h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
              {topics.map((topic) => (
                <article
                  key={topic.title}
                  className="rounded-[20px] border border-[#FFD9C2]/60 p-7 hover:shadow-md hover:shadow-[#FF7A33]/5 transition-shadow"
                  style={{ backgroundColor: topic.color }}
                >
                  <h2 className="text-[20px] font-semibold text-[#1E0C16] mb-3">
                    {topic.title}
                  </h2>
                  <p className="text-sm font-light text-[#7A4A32] leading-relaxed mb-5">
                    {topic.description}
                  </p>
                  <Link
                    href={topic.href}
                    className="text-sm font-medium text-[#FF7A33] hover:text-[#e86a22] transition-colors focus-visible:outline-none focus-visible:underline"
                  >
                    {topic.label}
                  </Link>
                </article>
              ))}
            </div>
          </div>
        </section>

        {/* Coming soon notice */}
        <section className="bg-[#FFF6F0] py-16 border-t border-[#FFD9C2]/40">
          <div className="max-w-[600px] mx-auto px-6 text-center">
            <div className="w-14 h-14 rounded-full bg-[#FFF0E8] border border-[#FFD9C2] flex items-center justify-center mx-auto mb-5" aria-hidden="true">
              <span className="text-[#FF7A33] text-xl">✦</span>
            </div>
            <h2 className="font-serif text-[28px] text-[#1E0C16] tracking-[-0.02em] mb-3">
              More articles coming soon
            </h2>
            <p className="text-sm font-light text-[#A06A52] leading-relaxed mb-6">
              The Vyla blog is growing. Articles on cycle health, hormone
              wellness, wearable insights, and BBT charting are being published
              regularly.
            </p>
            <Link
              href="/"
              className="inline-flex items-center gap-2 text-sm font-medium text-[#FF7A33] hover:text-[#e86a22] transition-colors"
            >
              ← Back to Vyla home
            </Link>
          </div>
        </section>
      </main>

      <Footer />
    </div>
  );
}
