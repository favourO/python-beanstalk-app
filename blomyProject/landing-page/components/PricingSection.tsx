import Image from "next/image";
import FadeIn from "./FadeIn";

const freeFeatures = [
  "Calendar and period tracking",
  "Manual symptom and mood logging",
  "Reminders",
  "Basic cycle insights",
  "Data export and delete controls",
];

const premiumFeatures = [
  "Everything in Free",
  "Advanced cycle and ovulation predictions",
  "Vyla AI chat",
  "Detailed insights and reports",
  "Stress monitoring and ovulation shift insights",
  "Health insight sync with supported devices",
  "Vyla Band — add for just £25 with first upgrade",
  "Priority experience",
];

function FeatureRow({ text }: { text: string }) {
  return (
    <div className="flex items-center gap-[9px]">
      <span className="text-[13px] w-[11px] shrink-0 leading-none text-[#3BAC6A]">✓</span>
      <span className="text-[14px] leading-none text-white">{text}</span>
    </div>
  );
}

export default function PricingSection() {
  return (
    <section id="pricing" className="relative py-24 lg:py-32 overflow-hidden">
      {/* Dark background image */}
      <div className="absolute inset-0">
        <Image
          src="https://vyla.health/assets/images/pricing-bg.png"
          alt=""
          fill
          className="object-cover object-center"
          sizes="100vw"
        />
      </div>

      <div className="relative max-w-[1200px] mx-auto px-6">
        {/* Centred header */}
        <FadeIn>
          <div className="flex flex-col items-center text-center mb-16">
            <div className="flex items-center gap-3 mb-5">
              <span className="w-6 h-px bg-[#FF7A33]" />
              <span className="text-[11px] font-medium tracking-[0.12em] uppercase text-[#FF7A33]">
                Pricing
              </span>
            </div>

            <h2 className="font-serif font-semibold text-[52px] lg:text-[56px] leading-[1.1] tracking-[-0.02em] max-w-[320px]">
              <span className="text-white">Simple pricing.</span>
              <br />
              <span className="text-[#FF7A33]">Start free.</span>
            </h2>
          </div>
        </FadeIn>

        {/* Cards row */}
        <div className="flex flex-col lg:flex-row justify-center gap-[18px] mb-10">
          {/* ── Free card ── */}
          <FadeIn delay={0.05} className="w-full lg:w-[390px] shrink-0">
            <div
              className="rounded-[24px] border border-white/[0.32] overflow-hidden flex flex-col h-full"
              style={{ background: "rgba(0,0,0,0.3)", backdropFilter: "blur(34px)" }}
            >
              {/* Card header — cream bg */}
              <div className="relative h-[149px] bg-[#FFF6F0] px-7">
                <p className="absolute top-[22px] font-serif text-[28px] font-medium leading-none text-[#1E0C16]">
                  Free
                </p>
                <p className="absolute top-[63px] text-[52px] font-semibold leading-none text-[#1E0C16]">
                  £0
                </p>
                <p className="absolute bottom-[12px] text-[13px] font-light text-[#C68D6A]">
                  Forever
                </p>
              </div>

              {/* Card body */}
              <div className="flex flex-col flex-1 px-6 pt-[22px] pb-6">
                <div className="flex flex-col gap-[19px]">
                  {freeFeatures.map((f) => (
                    <FeatureRow key={f} text={f} />
                  ))}
                </div>

                <div className="mt-auto pt-10">
                  <a href="#" className="text-[15px] font-medium text-[#FF7A33]">
                    Download free
                  </a>
                </div>
              </div>
            </div>
          </FadeIn>

          {/* ── Premium card ── */}
          <FadeIn delay={0.1} className="w-full lg:w-[390px] shrink-0">
            <div
              className="rounded-[24px] border border-white/[0.32] overflow-hidden flex flex-col h-full"
              style={{ background: "rgba(0,0,0,0.3)", backdropFilter: "blur(34px)" }}
            >
              {/* Card header — orange bg */}
              <div className="relative h-[149px] bg-[#FF7A33] px-7">
                <p className="absolute top-[22px] font-serif text-[28px] font-medium leading-none text-[#1E0C16]">
                  Premium
                </p>
                <p className="absolute top-[63px] text-[52px] font-semibold leading-none text-[#1E0C16]">
                  £3.99
                </p>
                <p className="absolute bottom-[12px] text-[13px] font-light text-white">
                  Per month{" "}
                  <span className="text-[11px] text-white/60">· or £35 per year</span>
                </p>

                {/* Most popular badge */}
                <div
                  className="absolute top-[30px] right-[14px] rounded-full px-3 h-[21px] flex items-center"
                  style={{ background: "rgba(255,255,255,0.15)" }}
                >
                  <span className="text-[10px] font-medium tracking-[0.08em] uppercase text-white/80">
                    Most popular
                  </span>
                </div>
              </div>

              {/* Card body */}
              <div className="flex flex-col flex-1 px-6 pt-[22px] pb-6">
                <div className="flex flex-col gap-[19px]">
                  {premiumFeatures.map((f) => (
                    <FeatureRow key={f} text={f} />
                  ))}
                </div>

                <div className="mt-auto pt-10">
                  <a
                    href="#"
                    className="inline-flex items-center justify-center bg-[#FF7A33] text-white text-[15px] font-medium rounded-full px-7 py-[14px] hover:bg-[#e86a22] transition-colors"
                  >
                    Get Premium
                  </a>
                </div>
              </div>
            </div>
          </FadeIn>
        </div>

        {/* Footer note */}
        <FadeIn delay={0.2}>
          <p className="text-center text-[13px] font-light text-white">
            No credit card required to use Free. Secure payments for Premium. Cancel anytime.
          </p>
        </FadeIn>
      </div>
    </section>
  );
}
