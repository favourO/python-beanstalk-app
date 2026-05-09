import Image from "next/image";
import FadeIn from "./FadeIn";

const steps = [
  {
    icon: "https://vyla.health/assets/icons/icon-mobile.png",
    title: "Download and choose how to start",
    body: "Create an account or use anonymous mode if you prefer not to sign up with an email.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-profile.png",
    title: "Add your cycle basics",
    body: "Tell Vyla your last period date, typical cycle length, and what you want to track. Setup only takes a few minutes.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-chart.png",
    title: "Start logging and learning",
    body: "Use Vyla daily or only when something changes. The more you log, the more useful your predictions and insights become.",
  },
];

export default function HowItWorksSection() {
  return (
    <section id="how-it-works" className="bg-[#FFF6F0] py-24 lg:py-32">
      <div className="max-w-[1200px] mx-auto px-6">

        {/* Centred header */}
        <FadeIn>
          <div className="flex flex-col items-center text-center mb-16">
            {/* Section label with side divider */}
            <div className="flex items-center gap-3 mb-5">
              <span className="w-6 h-px bg-[#FF7A33]" />
              <span className="text-[11px] font-medium tracking-[0.12em] uppercase text-[#FF7A33]">
                Getting started
              </span>
            </div>

            <h2
              className="font-serif text-[52px] lg:text-[56px] leading-[1.1] tracking-[-0.02em] text-[#1E0C16] max-w-[420px] mb-5"
            >
              Three steps to
              <br />
              <span className="text-[#FF7A33]">a clearer cycle</span>
            </h2>

          </div>
        </FadeIn>

        {/* Steps */}
        <div className="relative">

          {/* Horizontal divider line — desktop only */}
          <div className="hidden lg:block absolute top-7 left-[calc(16.666%)] right-[calc(16.666%)] h-px bg-[#FFD9C2]" />

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-12 lg:gap-8">
            {steps.map((step, i) => (
              <FadeIn key={step.title} delay={i * 0.12}>
                <div className="flex flex-col items-center text-center">

                  {/* Icon — sits on the divider line */}
                  <div className="relative z-10 w-14 h-14 bg-white rounded-[28px] border border-[#FFD9C2]/60 flex items-center justify-center mb-6 shadow-sm">
                    <Image
                      src={step.icon}
                      alt={step.title}
                      width={28}
                      height={28}
                      unoptimized
                    />
                  </div>

                  {/* Step title — Cormorant SemiBold 22px */}
                  <h3
                    className="font-serif font-semibold text-[22px] text-[#1E0C16] mb-3 leading-snug"
                  >
                    {step.title}
                  </h3>

                  {/* Body — DM Sans Light 14px */}
                  <p className="text-[14px] font-light text-[#A06A52] leading-[1.65] max-w-[280px]">
                    {step.body}
                  </p>
                </div>
              </FadeIn>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
