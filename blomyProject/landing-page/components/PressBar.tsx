const publications = [
  { name: "Vogue", style: "italic" as const },
  { name: "GLAMOUR", style: "bold" as const },
  { name: "Cosmopolitan", style: "italic" as const },
  { name: "ELLE", style: "bold" as const },
  { name: "Women's Health", style: "bold" as const },
  { name: "Harper's Bazaar", style: "italic" as const },
  { name: "50,000+ users", style: "bold" as const },
];

function PubItem({ pub }: { pub: (typeof publications)[0] }) {
  return (
    <div className="flex items-center shrink-0">
      <span
        className={`text-[#282624]/40 px-8 ${
          pub.style === "italic"
            ? "text-[20px] tracking-[-0.01em]"
            : "text-[16px] font-semibold tracking-[-0.01em]"
        }`}
        style={{
          fontFamily: pub.style === "italic" ? "var(--font-cormorant)" : undefined,
          fontStyle: pub.style === "italic" ? "italic" : undefined,
        }}
      >
        {pub.name}
      </span>
      <span className="w-px h-5 bg-[#FFD9C2] shrink-0" />
    </div>
  );
}

export default function PressBar() {
  const doubled = [...publications, ...publications];

  return (
    <div className="border-t border-b border-[#FFD9C2] bg-[#FFF6F0] overflow-hidden">
      <div className="flex items-center h-[81px]">
        {/* Static label */}
        <div className="shrink-0 flex items-center pl-8 pr-6 gap-3 border-r border-[#FFD9C2]">
          <span className="w-px h-5 bg-[#FFD9C2]" />
          <span className="text-[11px] font-medium tracking-[0.08em] uppercase text-[#A06A52]/60 whitespace-nowrap">
            As seen in
          </span>
          <span className="w-px h-5 bg-[#FFD9C2]" />
        </div>

        {/* Scrolling marquee — decorative, hidden from screen readers */}
        <div className="overflow-hidden flex-1" aria-hidden="true">
          <div
            className="flex items-center animate-marquee"
            style={{ width: "max-content" }}
          >
            {doubled.map((pub, i) => (
              <PubItem key={i} pub={pub} />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
