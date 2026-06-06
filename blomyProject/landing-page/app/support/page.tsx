import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import ContactForm from "@/components/ContactForm";
import JsonLd from "@/components/JsonLd";

export const metadata: Metadata = {
  title: "Vyla Support",
  description:
    "Get help with Vyla account access, cycle tracking, LH tests, subscriptions, wearable sync, privacy requests, and technical issues.",
  alternates: { canonical: "https://vyla.health/support" },
  robots: { index: true, follow: true },
};

const supportTopics = [
  {
    title: "Account access",
    body: "Help with sign in, email verification, password reset, Apple Sign In, Google Sign In, and account deletion.",
  },
  {
    title: "Cycle tracking",
    body: "Questions about period logs, ovulation predictions, fertile windows, symptoms, mood, sleep, stress, and reports.",
  },
  {
    title: "LH tests and images",
    body: "Support for camera access, photo library uploads, manual LH results, and test strip analysis availability.",
  },
  {
    title: "Wearables",
    body: "Help connecting Vyla Band or supported health sources, syncing Bluetooth data, and reviewing wearable wellness signals.",
  },
  {
    title: "Billing",
    body: "Questions about Premium, trials, renewals, cancellations, receipts, and subscription access.",
  },
  {
    title: "Privacy and data",
    body: "Requests for data export, data deletion, privacy settings, sensitive health data questions, and policy support.",
  },
];

const quickLinks = [
  { label: "Privacy Policy", href: "/privacy" },
  { label: "Terms of Use", href: "/terms" },
  { label: "Contact", href: "/contact" },
  { label: "Vyla Band", href: "/vyla-band" },
];

const faq = [
  {
    q: "How quickly does Vyla respond?",
    a: "We aim to respond within 1-2 business days. Please include the email address on your Vyla account so we can find the right record.",
  },
  {
    q: "Should I include health details in a support request?",
    a: "Only include sensitive health details if they are needed to resolve the request. For privacy or data rights requests, include your account email and the action you want us to take.",
  },
  {
    q: "Can support give medical advice?",
    a: "No. Vyla is a wellness and cycle tracking app, not a medical device or healthcare provider. For medical concerns, contact a qualified healthcare professional.",
  },
];

const breadcrumbSchema = {
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  itemListElement: [
    { "@type": "ListItem", position: 1, name: "Home", item: "https://vyla.health" },
    { "@type": "ListItem", position: 2, name: "Support", item: "https://vyla.health/support" },
  ],
};

const supportSchema = {
  "@context": "https://schema.org",
  "@type": "ContactPage",
  name: "Vyla Support",
  url: "https://vyla.health/support",
  description:
    "Support page for Vyla account, cycle tracking, subscriptions, wearable sync, and privacy requests.",
  contactPoint: {
    "@type": "ContactPoint",
    contactType: "customer support",
    email: "support@vyla.health",
    url: "https://vyla.health/support",
    availableLanguage: ["en-GB", "en"],
  },
};

export default function SupportPage() {
  return (
    <div className="min-h-screen bg-[#FFF6F0]">
      <JsonLd data={breadcrumbSchema} />
      <JsonLd data={supportSchema} />

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
            Back to home
          </Link>
        </div>
      </header>

      <main id="main-content" className="max-w-[1040px] mx-auto px-6 py-16">
        <nav aria-label="Breadcrumb" className="mb-8">
          <ol className="flex items-center gap-2 text-xs text-[#A06A52]" role="list">
            <li>
              <Link href="/" className="hover:text-[#FF7A33] transition-colors">
                Home
              </Link>
            </li>
            <li aria-hidden="true">/</li>
            <li aria-current="page" className="text-[#1E0C16]">
              Support
            </li>
          </ol>
        </nav>

        <section className="grid gap-10 lg:grid-cols-[1fr_360px] lg:items-start mb-14">
          <div>
            <p className="text-xs font-medium tracking-[0.12em] uppercase text-[#FF7A33] mb-3">
              Support
            </p>
            <h1 className="font-serif text-[44px] sm:text-[56px] leading-[1.08] text-[#1E0C16] mb-5">
              How can we help?
            </h1>
            <p className="text-base font-light text-[#7A4A32] leading-relaxed max-w-[680px]">
              Get help with Vyla account access, cycle tracking, LH test logging,
              wearable sync, subscriptions, and privacy requests. Support is
              available by email or through the form below.
            </p>
          </div>

          <aside className="bg-white border border-[#FFD9C2] rounded-2xl p-6">
            <h2 className="text-sm font-semibold text-[#1E0C16] mb-4">
              Contact details
            </h2>
            <div className="space-y-3 text-sm text-[#7A4A32]">
              <p>
                Email:{" "}
                <a
                  href="mailto:support@vyla.health"
                  className="font-medium text-[#FF7A33] hover:text-[#e86a22] transition-colors"
                >
                  support@vyla.health
                </a>
              </p>
              <p>Typical response time: 1-2 business days.</p>
              <p>
                Please include your Vyla account email and a short description
                of the issue.
              </p>
            </div>
          </aside>
        </section>

        <section aria-labelledby="support-topics" className="mb-14">
          <h2 id="support-topics" className="font-serif text-3xl text-[#1E0C16] mb-6">
            Support topics
          </h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {supportTopics.map((topic) => (
              <article
                key={topic.title}
                className="bg-white border border-[#FFD9C2] rounded-2xl p-6"
              >
                <h3 className="text-base font-semibold text-[#1E0C16] mb-2">
                  {topic.title}
                </h3>
                <p className="text-sm font-light text-[#7A4A32] leading-relaxed">
                  {topic.body}
                </p>
              </article>
            ))}
          </div>
        </section>

        <section className="grid gap-8 lg:grid-cols-[minmax(0,1fr)_360px] lg:items-start">
          <div>
            <h2 className="font-serif text-3xl text-[#1E0C16] mb-6">
              Send a support request
            </h2>
            <ContactForm />
          </div>

          <div className="space-y-6">
            <section className="bg-white border border-[#FFD9C2] rounded-2xl p-6">
              <h2 className="text-sm font-semibold text-[#1E0C16] mb-4">
                Quick links
              </h2>
              <ul className="space-y-3" role="list">
                {quickLinks.map((item) => (
                  <li key={item.href}>
                    <Link
                      href={item.href}
                      className="text-sm font-medium text-[#FF7A33] hover:text-[#e86a22] transition-colors"
                    >
                      {item.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </section>

            <section className="bg-white border border-[#FFD9C2] rounded-2xl p-6">
              <h2 className="text-sm font-semibold text-[#1E0C16] mb-4">
                Common questions
              </h2>
              <div className="space-y-5">
                {faq.map((item) => (
                  <div key={item.q}>
                    <h3 className="text-sm font-semibold text-[#1E0C16] mb-1">
                      {item.q}
                    </h3>
                    <p className="text-sm font-light text-[#7A4A32] leading-relaxed">
                      {item.a}
                    </p>
                  </div>
                ))}
              </div>
            </section>
          </div>
        </section>
      </main>
    </div>
  );
}
