import Image from "next/image";
import FadeIn from "./FadeIn";
import SectionLabel from "./SectionLabel";

const privacyCards = [
  {
    icon: "🔐",
    title: "Private by design",
    body: "Vyla keeps your cycle tracking focused on your own use, without turning your data into advertising profiles.",
  },
  {
    icon: "🚫",
    title: "Never sold to advertisers",
    body: "Your cycle data is not sold to advertisers or data brokers.",
  },
  {
    icon: "👻",
    title: "Anonymous mode",
    body: "Use Vyla without creating a standard account if you prefer a more private start.",
  },
  {
    icon: "📖",
    title: "Export or delete",
    body: "Download your data or permanently delete it from your profile when you choose.",
  },
];

export default function PrivacySection() {
  return (
    <section id="privacy" className="bg-[#1E0C16] py-24 lg:py-32">
      <div className="max-w-[1200px] mx-auto px-6">
        <div className="flex flex-col lg:flex-row gap-16 items-start">
          {/* Left: Copy + Cards */}
          <div className="flex-1 max-w-[500px]">
            <FadeIn>
              <SectionLabel light>Privacy</SectionLabel>
              <h2 className="font-serif text-[52px] lg:text-[62px] leading-[1.08] tracking-[-0.02em] text-white mb-5">
                Your cycle data{" "}
                <span className="text-[#FF7A33]">belongs to you.</span>
              </h2>
              <p className="text-base font-light text-white/50 leading-relaxed mb-10">
                Cycle data can be deeply personal. Vyla is designed to give you control over what you record, how you use it, and when you remove it.
              </p>
            </FadeIn>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {privacyCards.map((card, i) => (
                <FadeIn key={card.title} delay={i * 0.08}>
                  <div className="bg-white/5 border border-white/10 rounded-[16px] p-5 hover:bg-white/8 transition-colors">
                    <div className="text-2xl mb-3" aria-hidden="true">{card.icon}</div>
                    <h3 className="text-[15px] font-semibold text-white mb-2">{card.title}</h3>
                    <p className="text-sm font-light text-white/50 leading-relaxed">{card.body}</p>
                  </div>
                </FadeIn>
              ))}
            </div>
          </div>

          {/* Right: Privacy image */}
          <FadeIn className="flex-shrink-0 w-full lg:w-[420px]" delay={0.2} direction="right">
            <div className="relative w-full aspect-square rounded-[24px] overflow-hidden">
              <Image
                src="https://vyla.health/assets/images/privacy-bg.png"
                alt="Privacy — your data, your terms"
                fill
                className="object-cover"
                sizes="(max-width: 1024px) 100vw, 420px"
              />
              <div className="absolute inset-0 bg-[#1E0C16]/20" />
            </div>
          </FadeIn>
        </div>
      </div>
    </section>
  );
}
