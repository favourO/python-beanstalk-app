import Image from "next/image";
import FadeIn from "./FadeIn";
import SectionLabel from "./SectionLabel";

const cards = [
  {
    icon: "https://vyla.health/assets/icons/icon-sound.png",
    iconBg: "#FFF6DD",
    title: "Smarter cycle predictions",
    body: "Track your period history, cycle length, symptoms, and fertility signs. Vyla uses your logged data to estimate upcoming periods, fertile windows, and ovulation timing, with predictions that improve as your history grows.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-note.png",
    iconBg: "#FFF0F8",
    title: "Insights from your own patterns",
    body: "See how symptoms, mood, energy, sleep, temperature, LH tests, cervical mucus, and daily habits may line up with different parts of your cycle.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-shield.png",
    iconBg: "#EDFEF1",
    title: "Privacy-first tracking",
    body: "Your cycle data is personal. Vyla is built around private tracking, clear controls, and the ability to export or delete your data when you choose.",
  },
];

export default function WhyVylaSection() {
  return (
    <section id="why-vyla" className="bg-[#FFF6F0] py-24 lg:py-32">
      <div className="max-w-[1200px] mx-auto px-6">
        <FadeIn>
          <SectionLabel>Why Vyla</SectionLabel>
          <h2 className="font-serif text-[52px] lg:text-[62px] leading-[1.08] tracking-[-0.02em] text-[#1E0C16] mb-5 max-w-[540px]">
            Designed for real cycles,{" "}
            <span className="text-[#FF7A33]">not perfect calendars</span>
          </h2>
          <p className="text-base font-light text-[#A06A52] leading-relaxed max-w-[580px] mb-16">
            Your cycle can shift with sleep, stress, travel, illness, age, contraception, and everyday life. Vyla helps you notice those changes, record what matters, and make sense of recurring patterns over time.
          </p>
        </FadeIn>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
          {cards.map((card, i) => (
            <FadeIn key={card.title} delay={i * 0.1}>
              <div className="bg-white rounded-[24px] border border-[#FFD9C2]/60 p-6 h-full hover:shadow-lg hover:shadow-[#FF7A33]/5 transition-shadow">
                <div
                  className="w-14 h-14 rounded-2xl flex items-center justify-center mb-5"
                  style={{ backgroundColor: card.iconBg }}
                >
                  <Image src={card.icon} alt={card.title} width={30} height={30} unoptimized />
                </div>
                <h3 className="text-[17px] font-semibold text-[#1E0C16] mb-3 leading-snug">{card.title}</h3>
                <p className="text-sm font-light text-[#A06A52] leading-relaxed">{card.body}</p>
              </div>
            </FadeIn>
          ))}
        </div>
      </div>
    </section>
  );
}
