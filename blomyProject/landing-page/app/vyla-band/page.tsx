import type { Metadata } from "next";
import { buildMetadata } from "@/lib/seo";
import Nav from "@/components/Nav";
import Footer from "@/components/Footer";
import FadeIn from "@/components/FadeIn";
import JsonLd from "@/components/JsonLd";

export const metadata: Metadata = buildMetadata({
  title: "Vyla Band — Wearable Built for Women's Cycle Tracking",
  description:
    "The Vyla Band is a dedicated women's health wearable that tracks temperature, heart rate, and sleep 24/7 to give you continuous cycle-phase insights. Add it to your first annual Premium upgrade for just £25.",
  keywords: [
    "Vyla Band",
    "Vyla wearable",
    "women's health wearable",
    "cycle tracking wearable",
    "period tracking band",
    "menstrual cycle wearable",
    "temperature tracking wearable",
    "women's health tracker",
    "cycle health band",
    "Vyla Band £25",
  ],
  path: "/vyla-band",
});

const features = [
  {
    icon: "🌡️",
    title: "Continuous temperature tracking",
    body: "The Vyla Band measures your skin temperature every 10 minutes throughout the day and night. Vyla uses this stream to reveal your cycle's natural temperature rhythm and the post-ovulation thermal shift — without a morning thermometer.",
  },
  {
    icon: "💓",
    title: "Heart rate & HRV",
    body: "Continuous heart rate and heart rate variability monitoring across your cycle. See how your resting heart rate and HRV shift in your follicular versus luteal phases — a signal many women notice once they start tracking.",
  },
  {
    icon: "😴",
    title: "Sleep quality by phase",
    body: "The Band tracks sleep duration and sleep quality overnight. Vyla maps your sleep data to your cycle phases so you can see whether your sleep changes around ovulation or in the days before your period.",
  },
  {
    icon: "🏃",
    title: "Activity & energy",
    body: "Daily step count and active minutes sit alongside your cycle phase in Vyla, letting you notice whether your energy and motivation for movement follow a pattern across your cycle.",
  },
  {
    icon: "🔗",
    title: "Direct Vyla sync — no third-party app",
    body: "The Vyla Band syncs directly with the Vyla app via Bluetooth. There is no third-party platform, no separate account, and no data leaving your control. Everything appears in your existing Vyla cycle timeline.",
  },
  {
    icon: "🔋",
    title: "Up to 7 days battery",
    body: "Designed for continuous wear, the Vyla Band lasts up to 7 days on a single charge with all sensors active. Charge it in under 90 minutes with the included magnetic charger.",
  },
];

const faqs = [
  {
    q: "How do I get the Vyla Band?",
    a: "The Vyla Band is available as an add-on when you upgrade to your first annual Vyla Premium plan for just £25. After checkout, your Band ships to the address you provide — typically within 3–5 business days.",
  },
  {
    q: "Is the Vyla Band included automatically with Premium?",
    a: "The Vyla Band is an optional physical add-on at £25 on your first annual Premium upgrade — it is not included automatically. You choose to add it at checkout.",
  },
  {
    q: "Can I get the Vyla Band without a Premium plan?",
    a: "The £25 Vyla Band offer is exclusive to first-time annual Premium upgraders. The Band requires the Vyla app to function and is designed to work with Vyla Premium features.",
  },
  {
    q: "What does the Vyla Band track?",
    a: "The Vyla Band continuously tracks skin temperature, heart rate, heart rate variability (HRV), sleep quality, and daily activity. All data streams directly into your Vyla cycle timeline.",
  },
  {
    q: "Is the Vyla Band waterproof?",
    a: "Yes. The Vyla Band is water-resistant to 50 metres (5 ATM), suitable for showering and swimming. We recommend removing it during high-impact water sports.",
  },
  {
    q: "Does the Vyla Band work alongside Apple Watch or Fitbit?",
    a: "Yes. If you already use Apple Watch or Fitbit, you can connect both to Vyla. The Vyla Band's data will appear alongside any Apple Health or Fitbit data you have authorised.",
  },
  {
    q: "Is the Vyla Band available internationally?",
    a: "The Vyla Band currently ships to the UK and select European countries. International shipping options will be announced — check vyla.health/vyla-band for the latest availability.",
  },
];

const bandSchema = {
  "@context": "https://schema.org",
  "@type": "Product",
  name: "Vyla Band",
  description:
    "A dedicated women's health wearable that tracks temperature, heart rate, and sleep continuously to power cycle-phase insights in the Vyla app.",
  brand: { "@type": "Brand", name: "Vyla" },
  offers: {
    "@type": "Offer",
    price: "25",
    priceCurrency: "GBP",
    availability: "https://schema.org/InStock",
    url: "https://vyla.health/vyla-band",
    description: "Available as an add-on with your first annual Vyla Premium upgrade",
  },
  url: "https://vyla.health/vyla-band",
};

export default function VylaBandPage() {
  return (
    <>
      <JsonLd data={bandSchema} />
      <Nav />

      <main className="bg-[#FFF6F0] pt-16">

        {/* Hero */}
        <section className="max-w-[1200px] mx-auto px-6 pt-20 pb-16 lg:pt-28 lg:pb-24 text-center">
          <FadeIn>
            <div className="inline-flex items-center gap-2 mb-6 bg-white border border-[#FFD9C2] rounded-full px-4 py-1.5">
              <span className="w-2 h-2 rounded-full bg-[#FF7A33] animate-pulse" aria-hidden="true" />
              <span className="text-[11px] font-semibold tracking-[0.1em] uppercase text-[#FF7A33]">
                Now available
              </span>
            </div>
            <h1 className="font-serif text-[64px] lg:text-[80px] leading-[1.0] tracking-[-0.03em] text-[#1E0C16] mb-6">
              Vyla Band
            </h1>
            <p className="text-lg font-light text-[#7A4A32] leading-relaxed max-w-[520px] mx-auto mb-10">
              A wearable built for women&apos;s cycle tracking. Continuous temperature,
              heart rate, and sleep data — synced directly to Vyla.
            </p>

            {/* Price callout */}
            <div className="inline-flex flex-col sm:flex-row items-center gap-3 bg-[#1E0C16] rounded-2xl px-8 py-5 mb-10">
              <div className="text-left">
                <p className="text-xs font-medium tracking-[0.08em] uppercase text-white/50 mb-1">
                  With your first annual Premium upgrade
                </p>
                <p className="text-3xl font-bold text-white leading-none">
                  £25 <span className="text-base font-normal text-white/50 ml-1">one-time</span>
                </p>
              </div>
              <div className="hidden sm:block w-px h-10 bg-white/15" />
              <div className="text-left">
                <p className="text-xs text-white/50 mb-1">Annual Premium plan</p>
                <p className="text-xl font-semibold text-[#FF7A33]">£35 / year</p>
              </div>
            </div>

            <div className="flex flex-wrap gap-3 justify-center">
              <a
                href="#"
                className="bg-[#FF7A33] text-white text-sm font-semibold px-8 py-3.5 rounded-full hover:bg-[#e86a22] transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#FF7A33]"
              >
                Get Premium + Vyla Band
              </a>
              <a
                href="#features"
                className="bg-white border border-[#FFD9C2] text-[#1E0C16] text-sm font-medium px-8 py-3.5 rounded-full hover:bg-[#FFF6F0] transition-colors"
              >
                Learn more
              </a>
            </div>
          </FadeIn>
        </section>

        {/* What it tracks */}
        <section id="features" className="bg-white py-24 border-t border-[#FFD9C2]/40">
          <div className="max-w-[1200px] mx-auto px-6">
            <FadeIn>
              <div className="text-center mb-14">
                <span className="text-[11px] font-medium tracking-[0.1em] uppercase text-[#FF7A33] mb-3 block">
                  What it tracks
                </span>
                <h2 className="font-serif text-[48px] lg:text-[56px] leading-[1.08] tracking-[-0.02em] text-[#1E0C16]">
                  Every signal,{" "}
                  <span className="text-[#FF7A33]">in cycle context.</span>
                </h2>
              </div>
            </FadeIn>

            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
              {features.map((f, i) => (
                <FadeIn key={f.title} delay={i * 0.07}>
                  <div className="bg-[#FFF6F0] border border-[#FFD9C2]/60 rounded-[22px] p-6 h-full flex flex-col gap-4">
                    <span className="text-2xl" aria-hidden="true">{f.icon}</span>
                    <div>
                      <p className="text-[15px] font-semibold text-[#1E0C16] mb-2">{f.title}</p>
                      <p className="text-[14px] font-light text-[#7A4A32] leading-relaxed">{f.body}</p>
                    </div>
                  </div>
                </FadeIn>
              ))}
            </div>
          </div>
        </section>

        {/* Pricing CTA */}
        <section className="bg-[#FFF6F0] py-24 border-t border-[#FFD9C2]/40">
          <div className="max-w-[640px] mx-auto px-6 text-center">
            <FadeIn>
              <h2 className="font-serif text-[44px] lg:text-[52px] leading-[1.08] tracking-[-0.02em] text-[#1E0C16] mb-4">
                Add the Band for{" "}
                <span className="text-[#FF7A33]">just £25.</span>
              </h2>
              <p className="text-[15px] font-light text-[#7A4A32] leading-relaxed mb-8 max-w-[460px] mx-auto">
                Available exclusively when you upgrade to your first annual Vyla Premium plan.
                App subscription + wearable — everything you need to understand your cycle.
              </p>
              <div className="bg-white border border-[#FFD9C2] rounded-2xl p-7 mb-8 text-left">
                <div className="flex items-start justify-between mb-5 pb-5 border-b border-[#FFD9C2]">
                  <div>
                    <p className="text-sm font-semibold text-[#1E0C16]">Vyla Premium — annual</p>
                    <p className="text-xs text-[#A06A52] mt-0.5">12 months · cancel anytime</p>
                  </div>
                  <p className="text-sm font-semibold text-[#1E0C16]">£35</p>
                </div>
                <div className="flex items-start justify-between mb-5 pb-5 border-b border-[#FFD9C2]">
                  <div>
                    <p className="text-sm font-semibold text-[#1E0C16]">Vyla Band</p>
                    <p className="text-xs text-[#A06A52] mt-0.5">First upgrade offer only</p>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-semibold text-[#1E0C16]">£25</p>
                    <p className="text-[11px] text-[#3BAC6A]">one-time</p>
                  </div>
                </div>
                <div className="flex items-center justify-between">
                  <p className="text-sm font-semibold text-[#1E0C16]">Total today</p>
                  <p className="text-lg font-bold text-[#FF7A33]">£60</p>
                </div>
              </div>
              <a
                href="#"
                className="inline-flex items-center justify-center bg-[#FF7A33] text-white text-sm font-semibold px-10 py-4 rounded-full hover:bg-[#e86a22] transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#FF7A33] w-full sm:w-auto"
              >
                Get Premium + Vyla Band — £60
              </a>
              <p className="text-xs text-[#B0938A] mt-4">
                Secure checkout · Ships in 3–5 business days · UK & EU
              </p>
            </FadeIn>
          </div>
        </section>

        {/* FAQ */}
        <section className="bg-white py-24 border-t border-[#FFD9C2]/40">
          <div className="max-w-[740px] mx-auto px-6">
            <FadeIn>
              <h2 className="font-serif text-[40px] lg:text-[48px] leading-[1.1] tracking-[-0.02em] text-[#1E0C16] mb-10 text-center">
                Vyla Band — questions
              </h2>
            </FadeIn>
            <div className="flex flex-col divide-y divide-[#FFD9C2]/60">
              {faqs.map((item, i) => (
                <FadeIn key={i} delay={i * 0.05}>
                  <div className="py-6">
                    <p className="text-[15px] font-semibold text-[#1E0C16] mb-2">{item.q}</p>
                    <p className="text-[14px] font-light text-[#7A4A32] leading-relaxed">{item.a}</p>
                  </div>
                </FadeIn>
              ))}
            </div>
          </div>
        </section>

      </main>

      <Footer />
    </>
  );
}
