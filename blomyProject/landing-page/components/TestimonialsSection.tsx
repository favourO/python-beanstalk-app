import Image from "next/image";
import FadeIn from "./FadeIn";
import SectionLabel from "./SectionLabel";

const reviews = [
  {
    quote:
      '"Vyla helped me see that my mood and energy changes were happening at similar points each cycle. It made tracking feel useful, not stressful."',
    name: "Amara, 31",
    tag: "Cycle tracking",
    usePhoto: true,
  },
  {
    quote:
      '"I like that it explains patterns without making everything sound like a diagnosis."',
    name: "Maya, 27",
    tag: "Symptoms and mood tracking",
    usePhoto: false,
    initials: "M",
    color: "#E8A135",
  },
  {
    quote:
      '"The logging is quick, and the reminders are calm enough that I actually keep using them."',
    name: "Leah, 34",
    tag: "Period and wellness tracking",
    usePhoto: false,
    initials: "L",
    color: "#3BAC6A",
  },
];

export default function TestimonialsSection() {
  return (
    <section id="testimonials" className="bg-white py-24 lg:py-32 border-t border-[#FFD9C2]/40">
      <div className="max-w-[1200px] mx-auto px-6">
        <div className="flex flex-col lg:flex-row gap-12 items-start mb-12">
          <FadeIn className="flex-1">
            <SectionLabel>What users say</SectionLabel>
            <h2 className="font-serif text-[52px] lg:text-[62px] leading-[1.08] tracking-[-0.02em] text-[#1E0C16] max-w-[540px]">
              Built for women who want to{" "}
              <span className="text-[#FF7A33]">understand their cycle</span>
            </h2>
          </FadeIn>

          <FadeIn delay={0.1} direction="right">
            <div className="text-right shrink-0">
              <p className="text-[64px] font-semibold text-[#1E0C16] leading-none">4.8</p>
              <p className="text-[#E8A135] text-xl tracking-wide mt-1">★★★★★</p>
              <p className="text-sm text-[#A06A52] mt-1">App Store average</p>
            </div>
          </FadeIn>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
          {reviews.map((review, i) => (
            <FadeIn key={review.name} delay={i * 0.1}>
              <div className="bg-[#FFF6F0] border border-[#FFD9C2]/60 rounded-[22px] p-6 h-full flex flex-col">
                <p className="text-[15px] font-medium text-[#1E0C16] leading-relaxed flex-1 mb-6">{review.quote}</p>
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-full overflow-hidden shrink-0">
                    {review.usePhoto ? (
                      <Image
                        src="https://vyla.health/assets/images/testimonial-avatar.png"
                        alt={review.name}
                        width={40}
                        height={40}
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <div
                        className="w-full h-full flex items-center justify-center text-sm font-semibold text-white"
                        style={{ backgroundColor: review.color }}
                      >
                        {review.initials}
                      </div>
                    )}
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-[#1E0C16]">{review.name}</p>
                    <p className="text-xs text-[#A06A52]">{review.tag}</p>
                  </div>
                </div>
              </div>
            </FadeIn>
          ))}
        </div>
      </div>
    </section>
  );
}
