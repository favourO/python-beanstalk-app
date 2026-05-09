import Image from "next/image";
import FadeIn from "./FadeIn";
import SectionLabel from "./SectionLabel";

const features = [
  {
    icon: "https://vyla.health/assets/icons/icon-people.png",
    bg: "#FFF0F8",
    title: "Personal to your logs",
    body: "Answers can reference your recorded patterns, such as repeated symptom timing or changes in mood, sleep, or energy across recent cycles.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-radar.png",
    bg: "#E6FDF9",
    title: "Clear, practical explanations",
    body: "Understand common cycle-related patterns in plain language, including possible links with hormones, lifestyle, and your own logged trends.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-messages.png",
    bg: "#FFF1E4",
    title: "Premium access",
    body: "Vyla AI chat requires Premium in the app. Premium also unlocks deeper cycle insights, advanced prediction features, and wearable-supported trends where available.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-ai.png",
    bg: "#FFF0F8",
    title: "Not medical advice",
    body: "Vyla AI provides general health and wellness information. It does not diagnose conditions, provide treatment plans, or replace a qualified healthcare professional.",
  },
];

export default function AiSection() {
  return (
    <section id="vyla-ai" className="bg-white py-24 lg:py-32 border-t border-[#FFD9C2]/40">
      <div className="max-w-[1200px] mx-auto px-6">
        <div className="flex flex-col lg:flex-row gap-16 items-start">
          {/* Left: copy + features */}
          <div className="flex-1 max-w-[520px]">
            <FadeIn>
              <SectionLabel>Vyla AI</SectionLabel>
              <h2 className="font-serif text-[52px] lg:text-[62px] leading-[1.08] tracking-[-0.02em] text-[#1E0C16] mb-5">
                Ask questions about{" "}
                <span className="text-[#FF7A33]">your cycle data</span>
              </h2>
              <p className="text-base font-light text-[#A06A52] leading-relaxed mb-8">
                Vyla AI helps explain patterns in your logs using general health information and the cycle data you choose to record.
              </p>
              <a
                href="#"
                className="inline-flex items-center gap-2 bg-[#FF7A33] text-white text-sm font-medium px-6 py-3 rounded-full hover:bg-[#e86a22] transition-colors mb-12"
              >
                Explore Vyla AI →
              </a>
            </FadeIn>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {features.map((f, i) => (
                <FadeIn key={f.title} delay={i * 0.08}>
                  <div className="flex gap-3">
                    <div
                      className="w-9 h-9 rounded-lg flex items-center justify-center shrink-0"
                      style={{ backgroundColor: f.bg }}
                    >
                      <Image src={f.icon} alt={f.title} width={22} height={22} unoptimized />
                    </div>
                    <div>
                      <p className="text-[14px] font-medium text-[#1E0C16] mb-1">{f.title}</p>
                      <p className="text-xs font-light text-[#A06A52] leading-relaxed">{f.body}</p>
                    </div>
                  </div>
                </FadeIn>
              ))}
            </div>
          </div>

          {/* Right: AI chat card */}
          <FadeIn className="flex-shrink-0 w-full lg:w-[440px]" delay={0.2} direction="right">
            <div className="bg-[#1E0C16] rounded-[24px] p-6 shadow-2xl shadow-[#1E0C16]/20">
              <p className="text-xs font-medium text-[#FF7A33]/70 mb-1">Vyla AI · Example</p>
              <p className="text-xs text-white/40 mb-6">Based on your logged cycle data</p>

              {/* User message */}
              <div className="flex justify-end mb-4">
                <div className="bg-[#FF7A33] text-white text-sm px-4 py-3 rounded-[16px_16px_4px_16px] max-w-[75%] leading-relaxed">
                  Why do I feel more tired before my period?
                </div>
              </div>

              {/* AI response */}
              <div className="mb-4">
                <div className="bg-white/10 border border-white/10 rounded-[16px_16px_16px_4px] p-4">
                  <p className="text-white/90 text-sm leading-relaxed">
                    Vyla AI can help you explore whether your tiredness often appears in the same part of your cycle, how it lines up with your recent sleep or symptom logs, and what general wellness habits may support you during that time.
                  </p>
                </div>
                <div className="mt-2 bg-white/5 border border-white/10 rounded-lg px-3 py-2">
                  <p className="text-[11px] text-white/40">Based on your logged data · General health information</p>
                </div>
              </div>

              {/* Disclaimer */}
              <div className="border-t border-white/10 pt-4">
                <p className="text-[11px] text-white/25 leading-relaxed">
                  Vyla AI provides health information, not medical advice. Always consult a healthcare professional for personal medical decisions.
                </p>
              </div>
            </div>
          </FadeIn>
        </div>
      </div>
    </section>
  );
}
