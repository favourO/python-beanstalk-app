import Link from "next/link";
import Image from "next/image";
import Footer from "./Footer";
import FAQSection from "./FAQSection";
import JsonLd from "./JsonLd";
import { breadcrumbSchema, webPageSchema } from "@/lib/jsonld";
import type { FAQ_ITEMS } from "./FAQSection";

interface Feature {
  icon: string;
  iconBg: string;
  title: string;
  body: string;
}

interface SeoPageLayoutProps {
  breadcrumb: string;
  breadcrumbPath: string;
  label: string;
  heading: React.ReactNode;
  subheading: string;
  pageTitle: string;
  pageDescription: string;
  features: Feature[];
  faqItems: typeof FAQ_ITEMS;
  faqTitle?: string;
  faqSubtitle?: string;
}

export default function SeoPageLayout({
  breadcrumb,
  breadcrumbPath,
  label,
  heading,
  subheading,
  pageTitle,
  pageDescription,
  features,
  faqItems,
  faqTitle,
  faqSubtitle,
}: SeoPageLayoutProps) {
  const crumbs = [
    { name: "Home", url: "https://vyla.health" },
    { name: breadcrumb, url: `https://vyla.health${breadcrumbPath}` },
  ];

  return (
    <div className="min-h-screen bg-[#FFF6F0]">
      <JsonLd
        data={[
          breadcrumbSchema(crumbs),
          webPageSchema({
            name: pageTitle,
            description: pageDescription,
            url: `https://vyla.health${breadcrumbPath}`,
            breadcrumbs: crumbs,
          }),
        ]}
      />

      {/* Minimal nav */}
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
          <div className="flex items-center gap-4">
            <Link
              href="/#pricing"
              className="hidden sm:block text-sm font-medium text-[#A06A52] hover:text-[#1E0C16] transition-colors"
            >
              Pricing
            </Link>
            <a
              href="#"
              className="text-sm font-medium bg-[#FF7A33] text-white px-5 py-2 rounded-full hover:bg-[#e86a22] transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#FF7A33] focus-visible:ring-offset-2"
            >
              Download free
            </a>
          </div>
        </div>
      </header>

      <main id="main-content">
        {/* Hero */}
        <section
          className="bg-[#FFF6F0] pt-16 pb-20 lg:pt-20 lg:pb-28"
          aria-labelledby="seo-hero-heading"
        >
          <div className="max-w-[1200px] mx-auto px-6">
            {/* Breadcrumb */}
            <nav aria-label="Breadcrumb" className="mb-10">
              <ol className="flex items-center gap-2 text-xs text-[#A06A52]" role="list">
                <li>
                  <Link href="/" className="hover:text-[#FF7A33] transition-colors">
                    Home
                  </Link>
                </li>
                <li aria-hidden="true">/</li>
                <li aria-current="page" className="text-[#1E0C16]">
                  {breadcrumb}
                </li>
              </ol>
            </nav>

            <div className="max-w-[720px]">
              <p className="text-[11px] font-medium tracking-[0.12em] uppercase text-[#FF7A33] mb-5">
                {label}
              </p>
              <h1
                id="seo-hero-heading"
                className="font-serif text-[58px] lg:text-[72px] leading-[1.06] tracking-[-0.03em] text-[#1E0C16] mb-6"
              >
                {heading}
              </h1>
              <p className="text-lg font-light text-[#A06A52] leading-relaxed mb-10 max-w-[580px]">
                {subheading}
              </p>

              {/* Download CTAs */}
              <div className="flex flex-wrap gap-3">
                <a
                  href="#"
                  aria-label="Download Vyla on the App Store"
                  className="inline-flex items-center gap-2 bg-[#1E0C16] text-white text-sm font-medium px-6 py-3 rounded-full hover:bg-[#2e1a26] transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#FF7A33]"
                >
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                    <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
                  </svg>
                  App Store
                </a>
                <a
                  href="#"
                  aria-label="Get Vyla on Google Play"
                  className="inline-flex items-center gap-2 bg-white border border-[#FFD9C2] text-[#1E0C16] text-sm font-medium px-6 py-3 rounded-full hover:bg-[#FFF6F0] transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#FF7A33]"
                >
                  Google Play
                </a>
                <Link
                  href="/#features"
                  className="inline-flex items-center gap-2 text-sm font-medium text-[#FF7A33] hover:text-[#e86a22] transition-colors"
                >
                  See all features →
                </Link>
              </div>
            </div>
          </div>
        </section>

        {/* Features grid */}
        <section className="bg-white py-20 border-t border-[#FFD9C2]/40" aria-labelledby="features-heading">
          <div className="max-w-[1200px] mx-auto px-6">
            <h2 id="features-heading" className="sr-only">Key features</h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
              {features.map((feature) => (
                <article
                  key={feature.title}
                  className="bg-[#FFF6F0] rounded-[20px] border border-[#FFD9C2]/60 p-6"
                >
                  <div
                    className="w-12 h-12 rounded-xl flex items-center justify-center mb-4"
                    style={{ backgroundColor: feature.iconBg }}
                    aria-hidden="true"
                  >
                    <Image
                      src={feature.icon}
                      alt=""
                      width={26}
                      height={26}
                      unoptimized
                    />
                  </div>
                  <h3 className="text-[16px] font-semibold text-[#1E0C16] mb-2 leading-snug">
                    {feature.title}
                  </h3>
                  <p className="text-sm font-light text-[#A06A52] leading-relaxed">
                    {feature.body}
                  </p>
                </article>
              ))}
            </div>
          </div>
        </section>

        {/* Trust bar */}
        <section className="bg-[#FFF6F0] py-12 border-t border-[#FFD9C2]/40">
          <div className="max-w-[1200px] mx-auto px-6 flex flex-col sm:flex-row items-center justify-center gap-8 text-center sm:text-left">
            <div>
              <p className="text-[32px] font-semibold text-[#1E0C16] leading-none">4.8</p>
              <p className="text-[#E8A135]">★★★★★</p>
              <p className="text-xs text-[#A06A52] mt-1">App Store</p>
            </div>
            <div className="w-px h-10 bg-[#FFD9C2] hidden sm:block" aria-hidden="true" />
            <div>
              <p className="text-[32px] font-semibold text-[#1E0C16] leading-none">50k+</p>
              <p className="text-xs text-[#A06A52] mt-1">Active users</p>
            </div>
            <div className="w-px h-10 bg-[#FFD9C2] hidden sm:block" aria-hidden="true" />
            <div>
              <p className="text-[32px] font-semibold text-[#1E0C16] leading-none">Free</p>
              <p className="text-xs text-[#A06A52] mt-1">To download</p>
            </div>
          </div>
        </section>

        {/* FAQ */}
        <FAQSection
          items={faqItems}
          title={faqTitle}
          subtitle={faqSubtitle}
        />

        {/* CTA */}
        <section className="bg-[#1E0C16] py-20 text-center">
          <div className="max-w-[600px] mx-auto px-6">
            <h2 className="font-serif text-[48px] leading-[1.1] tracking-[-0.02em] text-white mb-4">
              Start tracking today.
            </h2>
            <p className="text-base font-light text-white/50 mb-8">
              Free to download. No credit card needed.
            </p>
            <div className="flex flex-wrap gap-3 justify-center">
              <a
                href="#"
                aria-label="Download Vyla on the App Store"
                className="inline-flex items-center gap-2 bg-white text-[#1E0C16] text-sm font-medium px-6 py-3 rounded-full hover:bg-[#FFF6F0] transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white"
              >
                App Store
              </a>
              <a
                href="#"
                aria-label="Get Vyla on Google Play"
                className="inline-flex items-center gap-2 border border-white/30 text-white text-sm font-medium px-6 py-3 rounded-full hover:bg-white/10 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white"
              >
                Google Play
              </a>
            </div>
          </div>
        </section>
      </main>

      <Footer />
    </div>
  );
}
