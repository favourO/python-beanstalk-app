"use client";
import Link from "next/link";
import Image from "next/image";
import { usePathname, useRouter } from "next/navigation";
import { clearToken } from "@/lib/api";

const mainNav = [
  { label: "Overview",      href: "/",               icon: <OverviewIcon /> },
  { label: "Health Data",   href: "/health-data",     icon: <HealthIcon /> },
  { label: "Predictions",   href: "/predictions",     icon: <PredictionsIcon /> },
  { label: "Wearables",     href: "/wearables",       icon: <WearableIcon /> },
  { label: "Subscriptions", href: "/subscriptions",   icon: <SubIcon /> },
  { label: "Orders",        href: "/billing",         icon: <OrdersIcon /> },
  { label: "Notifications", href: "/notifications",   icon: <BellIcon /> },
  { label: "Blog",          href: "/blog",            icon: <BlogIcon /> },
  { label: "Content",       href: "/content",         icon: <ContentIcon /> },
  { label: "AI Threads",    href: "/ai-threads",      icon: <AIIcon /> },
  { label: "Referrals",     href: "/referrals",       icon: <ReferralIcon /> },
  { label: "Support",       href: "/support",         icon: <SupportIcon /> },
  { label: "Contacts",      href: "/contacts",        icon: <ContactIcon /> },
  { label: "Downloads",     href: "/download-requests", icon: <DownloadIcon /> },
];

const secondNav = [
  { label: "App Config",    href: "/app-config",      icon: <ConfigIcon /> },
  { label: "Audit Log",     href: "/audit-log",       icon: <AuditIcon /> },
];

const thirdNav = [
  { label: "Privacy & Compliance", href: "/privacy",  icon: <PrivacyIcon /> },
  { label: "Settings",             href: "/settings",  icon: <SettingsIcon /> },
];

function NavItem({ label, href, icon, active }: { label: string; href: string; icon: React.ReactNode; active: boolean }) {
  return (
    <Link
      href={href}
      className={`flex items-center gap-3 px-3 py-2 rounded-lg text-[13px] transition-colors relative ${
        active
          ? "bg-[#FFF0E8] text-[#FF7A33] font-semibold"
          : "text-[#7C6B65] hover:bg-[#FFF6F2] hover:text-[#1E0C16]"
      }`}
    >
      {active && <span className="absolute left-0 top-1/2 -translate-y-1/2 w-[3px] h-5 bg-[#FF7A33] rounded-r-full" />}
      <span className={`w-4 h-4 shrink-0 ${active ? "text-[#FF7A33]" : "text-[#B0938A]"}`}>{icon}</span>
      {label}
    </Link>
  );
}

export default function Sidebar() {
  const path = usePathname();
  const router = useRouter();

  function isActive(href: string) {
    return href === "/" ? path === "/" : path.startsWith(href);
  }

  function logout() {
    clearToken();
    router.push("/login");
  }

  return (
    <aside className="w-56 shrink-0 bg-white border-r border-[#F0E8E4] min-h-screen flex flex-col">
      {/* Logo */}
      <div className="px-5 pt-6 pb-5 flex items-center gap-2">
        <Image src="/vyla-logo.png" alt="Vyla" width={56} height={22} className="h-[22px] w-auto" unoptimized />
        <span className="text-[9px] font-bold tracking-[0.2em] uppercase text-[#C4895A] border-l border-[#E8D5CA] pl-2">
          Admin Portal
        </span>
      </div>

      {/* Main nav */}
      <nav className="flex-1 px-3 space-y-0.5 overflow-y-auto">
        {mainNav.map(({ label, href, icon }) => (
          <NavItem key={href} label={label} href={href} icon={icon} active={isActive(href)} />
        ))}

        <div className="my-3 border-t border-[#F0E8E4]" />

        {secondNav.map(({ label, href, icon }) => (
          <NavItem key={href} label={label} href={href} icon={icon} active={isActive(href)} />
        ))}

        <div className="my-3 border-t border-[#F0E8E4]" />

        {thirdNav.map(({ label, href, icon }) => (
          <NavItem key={href} label={label} href={href} icon={icon} active={isActive(href)} />
        ))}
      </nav>

      {/* User profile */}
      <div className="px-4 py-4 border-t border-[#F0E8E4]">
        <div className="flex items-center gap-3 mb-2">
          <div className="w-8 h-8 rounded-full bg-gradient-to-br from-[#FF7A33] to-[#FFB38A] flex items-center justify-center text-white text-xs font-bold shrink-0">
            A
          </div>
          <div className="min-w-0">
            <p className="text-[12px] font-semibold text-[#1E0C16] truncate">Admin</p>
            <p className="text-[11px] text-[#B0938A] truncate">DemyCorp Ltd</p>
          </div>
        </div>
        <button
          onClick={logout}
          className="w-full text-left text-[11px] text-[#B0938A] hover:text-[#FF7A33] transition-colors flex items-center gap-1.5"
        >
          <LogoutIcon />
          Log out
        </button>
      </div>
    </aside>
  );
}

// ── Icons ──────────────────────────────────────────────────────────────────

function OverviewIcon() {
  return <svg viewBox="0 0 16 16" fill="currentColor"><rect x="1" y="1" width="6" height="6" rx="1"/><rect x="9" y="1" width="6" height="6" rx="1"/><rect x="1" y="9" width="6" height="6" rx="1"/><rect x="9" y="9" width="6" height="6" rx="1"/></svg>;
}
function HealthIcon() {
  return <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><path d="M8 13.5S2 10 2 5.5a3.5 3.5 0 017 0 3.5 3.5 0 017 0c0 4.5-6 8-6 8z"/></svg>;
}
function PredictionsIcon() {
  return <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"><polyline points="1,12 5,7 8,10 11,5 15,3"/><polyline points="11,3 15,3 15,7"/></svg>;
}
function WearableIcon() {
  return <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><rect x="4" y="4" width="8" height="8" rx="2"/><path d="M6 2h4M6 14h4"/></svg>;
}
function SubIcon() {
  return <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><rect x="1" y="3" width="14" height="10" rx="1.5"/><path d="M1 6h14"/></svg>;
}
function OrdersIcon() {
  return <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><path d="M2 2h2l2 7h6l2-5H6"/><circle cx="7" cy="13" r="1"/><circle cx="12" cy="13" r="1"/></svg>;
}
function BlogIcon() {
  return <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><path d="M2 2h12v12H2z" rx="1.5"/><path d="M5 5h6M5 8h6M5 11h4"/></svg>;
}
function BellIcon() {
  return <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><path d="M8 1a5 5 0 015 5v3l1 2H2l1-2V6a5 5 0 015-5z"/><path d="M6.5 13a1.5 1.5 0 003 0"/></svg>;
}
function ContentIcon() {
  return <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><rect x="2" y="2" width="12" height="12" rx="1.5"/><path d="M5 6h6M5 9h4"/></svg>;
}
function AIIcon() {
  return <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><circle cx="8" cy="8" r="6"/><path d="M5.5 8.5l2 2 3-4"/></svg>;
}
function ReferralIcon() {
  return <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><circle cx="5" cy="5" r="2.5"/><circle cx="11" cy="5" r="2.5"/><circle cx="8" cy="12" r="2.5"/><path d="M7 7l-1 3M9 7l1 3M7.5 7.5h1"/></svg>;
}
function SupportIcon() {
  return <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><circle cx="8" cy="8" r="6.5"/><path d="M8 9V8a2 2 0 10-2-2"/><circle cx="8" cy="11.5" r=".5" fill="currentColor"/></svg>;
}
function ConfigIcon() {
  return <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><circle cx="8" cy="8" r="2"/><path d="M8 1v2M8 13v2M1 8h2M13 8h2M3.05 3.05l1.41 1.41M11.54 11.54l1.41 1.41M3.05 12.95l1.41-1.41M11.54 4.46l1.41-1.41"/></svg>;
}
function AuditIcon() {
  return <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><path d="M10 2H4a1 1 0 00-1 1v10a1 1 0 001 1h8a1 1 0 001-1V5l-3-3z"/><path d="M10 2v3h3M5 7h6M5 10h4"/></svg>;
}
function PrivacyIcon() {
  return <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><path d="M8 1L2 4v4c0 4 3 6.5 6 7.5C11 14.5 14 12 14 8V4L8 1z"/></svg>;
}
function SettingsIcon() {
  return <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><circle cx="8" cy="8" r="2.5"/><path d="M8 1.5v1.8M8 12.7v1.8M1.5 8h1.8M12.7 8h1.8M3.4 3.4l1.27 1.27M11.33 11.33l1.27 1.27M3.4 12.6l1.27-1.27M11.33 4.67l1.27-1.27"/></svg>;
}
function LogoutIcon() {
  return <svg width="11" height="11" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"><path d="M6 2H3a1 1 0 00-1 1v10a1 1 0 001 1h3M11 11l3-3-3-3M7 8h7"/></svg>;
}
function ContactIcon() {
  return <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><path d="M13 2H3a1 1 0 00-1 1v7a1 1 0 001 1h3l2 3 2-3h3a1 1 0 001-1V3a1 1 0 00-1-1z"/></svg>;
}
function DownloadIcon() {
  return <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><path d="M8 2v8M5 7l3 3 3-3M2 12v1a1 1 0 001 1h10a1 1 0 001-1v-1"/></svg>;
}
