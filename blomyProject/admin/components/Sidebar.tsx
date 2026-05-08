"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";

const nav = [
  { label: "Dashboard",      href: "/",                icon: "▦" },
  { label: "Users",          href: "/users",           icon: "👤" },
  { label: "Subscriptions",  href: "/subscriptions",   icon: "💳" },
  { label: "Billing",        href: "/billing",         icon: "🧾" },
  { label: "Webhook Errors", href: "/webhook-errors",  icon: "⚠" },
];

export default function Sidebar() {
  const path = usePathname();
  return (
    <aside className="w-60 shrink-0 bg-[#1E0C16] min-h-screen flex flex-col">
      {/* Brand */}
      <div className="px-6 pt-7 pb-6 border-b border-white/10">
        <p className="text-[11px] font-medium tracking-[0.14em] uppercase text-[#FF7A33] mb-0.5">DemyCorp Ltd</p>
        <p className="text-lg font-semibold text-white leading-tight">Vyla Admin</p>
      </div>

      {/* Nav */}
      <nav className="flex-1 px-3 py-5 flex flex-col gap-0.5">
        {nav.map(({ label, href, icon }) => {
          const active = href === "/" ? path === "/" : path.startsWith(href);
          return (
            <Link
              key={href}
              href={href}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-colors ${
                active
                  ? "bg-[#FF7A33]/15 text-white font-medium"
                  : "text-white/50 hover:text-white/80 hover:bg-white/5"
              }`}
            >
              <span className="text-base w-5 text-center">{icon}</span>
              {label}
            </Link>
          );
        })}
      </nav>

      {/* Footer */}
      <div className="px-6 py-5 border-t border-white/10">
        <p className="text-[11px] text-white/25 leading-relaxed">Vyla Health</p>
        <p className="text-[11px] text-white/20">Internal use only</p>
      </div>
    </aside>
  );
}
