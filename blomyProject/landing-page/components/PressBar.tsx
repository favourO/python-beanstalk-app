const launchFacts = [
  { text: "Now available on iOS & Android", style: "bold" as const },
  { text: "Free to download", style: "normal" as const },
  { text: "No credit card needed", style: "normal" as const },
  { text: "Private by design", style: "bold" as const },
  { text: "AI-powered cycle insights", style: "normal" as const },
  { text: "BBT & wearable sync", style: "normal" as const },
  { text: "Early access open", style: "bold" as const },
  { text: "Ovulation & fertility tracking", style: "normal" as const },
  { text: "Join our first users", style: "bold" as const },
  { text: "Vyla Band — £25 with first year upgrade", style: "bold" as const },
];

function FactItem({ fact }: { fact: (typeof launchFacts)[0] }) {
  return (
    <div className="flex items-center shrink-0">
      <span
        className={`px-7 text-[#282624]/50 whitespace-nowrap ${
          fact.style === "bold"
            ? "text-[13px] font-semibold tracking-[-0.01em]"
            : "text-[13px] font-light tracking-[0.01em]"
        }`}
      >
        {fact.text}
      </span>
      <span className="w-1 h-1 rounded-full bg-[#FFB38A] shrink-0" />
    </div>
  );
}

export default function PressBar() {
  const doubled = [...launchFacts, ...launchFacts];

  return (
    <div className="border-t border-b border-[#FFD9C2] bg-white overflow-hidden">
      <div className="flex items-center h-[72px]">
        {/* Static launch badge */}
        <div className="shrink-0 flex items-center pl-8 pr-6 gap-2.5 border-r border-[#FFD9C2]">
          <span className="w-2 h-2 rounded-full bg-[#FF7A33] animate-pulse" aria-hidden="true" />
          <span className="text-[11px] font-semibold tracking-[0.1em] uppercase text-[#FF7A33] whitespace-nowrap">
            New launch
          </span>
        </div>

        {/* Scrolling marquee — decorative */}
        <div className="overflow-hidden flex-1" aria-hidden="true">
          <div
            className="flex items-center animate-marquee"
            style={{ width: "max-content" }}
          >
            {doubled.map((fact, i) => (
              <FactItem key={i} fact={fact} />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
