import JsonLd from "./JsonLd";
import { faqSchema } from "@/lib/jsonld";

export const FAQ_ITEMS = [
  {
    q: "Is Vyla free to use?",
    a: "Yes. Vyla is free to download and includes core cycle tracking, period logging, symptom logging, reminders, and basic cycle insights at no cost. Premium unlocks advanced predictions, Vyla AI chat, detailed reports, and wearable integration.",
  },
  {
    q: "How does Vyla predict my period and fertile window?",
    a: "Vyla uses your logged period dates, cycle lengths, and symptoms to estimate upcoming periods, fertile windows, and ovulation timing. Predictions improve as your cycle history grows — typically becoming more accurate after 3 or more logged cycles.",
  },
  {
    q: "Does Vyla support BBT temperature tracking?",
    a: "Yes. You can manually log your basal body temperature (BBT) each morning. Vyla displays your BBT trends alongside your cycle phases so you can notice temperature shifts that typically occur around ovulation.",
  },
  {
    q: "Can I use Vyla with Oura Ring or other wearables?",
    a: "Yes. Vyla integrates with Oura Ring to pull in temperature trends and wellness signals, which can enhance cycle phase awareness. Wearable integration is available on Vyla Premium.",
  },
  {
    q: "Is my cycle data private and secure?",
    a: "Your privacy is a priority. Vyla never sells your cycle data to advertisers or data brokers. You can use anonymous mode without registering an email address, and you can export or permanently delete your data from your profile at any time.",
  },
  {
    q: "Does Vyla provide medical or fertility advice?",
    a: "No. Vyla is a wellness app that helps you understand your own body's patterns. It does not diagnose medical conditions, provide fertility treatment guidance, or replace advice from a qualified healthcare professional.",
  },
  {
    q: "What is ovulation tracking in Vyla?",
    a: "Vyla's ovulation tracking uses your logged cycle history, LH test results, BBT readings, and cervical mucus observations to estimate your fertile window and likely ovulation timing each cycle.",
  },
  {
    q: "Is Vyla available on iPhone and Android?",
    a: "Yes. Vyla is available on both iOS (App Store) and Android (Google Play Store). Downloading is free.",
  },
];

interface FAQSectionProps {
  items?: typeof FAQ_ITEMS;
  title?: string;
  subtitle?: string;
}

export default function FAQSection({
  items = FAQ_ITEMS,
  title = "Frequently asked questions",
  subtitle = "Everything you need to know about Vyla.",
}: FAQSectionProps) {
  return (
    <section
      id="faq"
      className="bg-[#FFF6F0] py-24 lg:py-32 border-t border-[#FFD9C2]/40"
      aria-labelledby="faq-heading"
    >
      <JsonLd data={faqSchema(items)} />

      <div className="max-w-[1200px] mx-auto px-6">
        <div className="flex flex-col lg:flex-row gap-16">
          {/* Left: heading */}
          <div className="lg:w-[380px] shrink-0">
            <div className="flex items-center gap-3 mb-4">
              <span className="w-6 h-px bg-[#FF7A33]" aria-hidden="true" />
              <span className="text-[11px] font-medium tracking-[0.12em] uppercase text-[#FF7A33]">
                FAQ
              </span>
            </div>
            <h2
              id="faq-heading"
              className="font-serif text-[42px] lg:text-[52px] leading-[1.1] tracking-[-0.02em] text-[#1E0C16] mb-4"
            >
              {title}
            </h2>
            <p className="text-base font-light text-[#A06A52] leading-relaxed mb-6">
              {subtitle}
            </p>
            <a
              href="/contact"
              className="inline-flex items-center gap-2 text-sm font-medium text-[#FF7A33] hover:text-[#e86a22] transition-colors"
            >
              Still have questions? Contact us
              <span aria-hidden="true">→</span>
            </a>
          </div>

          {/* Right: accordion */}
          <div className="flex-1">
            <dl className="divide-y divide-[#FFD9C2]/60">
              {items.map(({ q, a }) => (
                <details key={q} className="group py-5">
                  <summary className="flex items-center justify-between gap-4 cursor-pointer list-none text-[15px] font-medium text-[#1E0C16] hover:text-[#FF7A33] transition-colors focus-visible:outline-none focus-visible:text-[#FF7A33]">
                    <dt>{q}</dt>
                    <span
                      className="shrink-0 w-6 h-6 rounded-full border border-[#FFD9C2] flex items-center justify-center text-[#FF7A33] group-open:rotate-45 transition-transform duration-200"
                      aria-hidden="true"
                    >
                      <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                        <path d="M5 1v8M1 5h8" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                      </svg>
                    </span>
                  </summary>
                  <dd className="mt-3 text-sm font-light text-[#7A4A32] leading-relaxed pr-10">
                    {a}
                  </dd>
                </details>
              ))}
            </dl>
          </div>
        </div>
      </div>
    </section>
  );
}
