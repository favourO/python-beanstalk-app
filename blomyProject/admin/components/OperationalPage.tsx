import TopBar from "@/components/TopBar";
import Badge from "@/components/Badge";

type Section = { title: string; items: string[] };
type LinkItem = { label: string; href: string; note: string };

export default function OperationalPage({
  title,
  subtitle,
  sections,
  links,
}: {
  title: string;
  subtitle: string;
  metrics?: unknown[];
  sections: Section[];
  links?: LinkItem[];
}) {
  return (
    <main className="space-y-6">
      <TopBar title={title} subtitle={subtitle} />

      <section className="rounded-2xl border border-[#FFD9C2] bg-[#FFF6F0] p-5">
        <p className="text-[12px] font-semibold uppercase tracking-wider text-[#A06A52]">No synthetic metrics</p>
        <p className="mt-2 text-[13px] leading-6 text-[#3D1F2E]">
          This page is an operational guide only. It does not display counts, rates, statuses, or health-data values unless those values are returned by a backend admin endpoint.
        </p>
      </section>

      <section className="grid grid-cols-1 gap-4 xl:grid-cols-2">
        {sections.map((section) => (
          <div key={section.title} className="rounded-2xl border border-[#FFD9C2] bg-white p-5">
            <div className="mb-4 flex items-center justify-between gap-3">
              <h2 className="text-[15px] font-bold text-[#1E0C16]">{section.title}</h2>
              <Badge label="guide" />
            </div>
            <ul className="space-y-3">
              {section.items.map((item) => (
                <li key={item} className="flex gap-3 text-[13px] leading-6 text-[#3D1F2E]">
                  <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-[#FF7A33]" />
                  <span>{item}</span>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </section>

      {links && links.length > 0 && (
        <section className="rounded-2xl border border-[#FFD9C2] bg-white p-5">
          <h2 className="mb-4 text-[15px] font-bold text-[#1E0C16]">Related live admin areas</h2>
          <div className="grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-3">
            {links.map((link) => (
              <a key={link.href} href={link.href} className="rounded-xl border border-[#F0E8E4] p-4 transition-colors hover:border-[#FF7A33] hover:bg-[#FFF6F0]">
                <p className="text-[13px] font-semibold text-[#1E0C16]">{link.label}</p>
                <p className="mt-1 text-[12px] leading-5 text-[#9E7B6E]">{link.note}</p>
              </a>
            ))}
          </div>
        </section>
      )}
    </main>
  );
}
