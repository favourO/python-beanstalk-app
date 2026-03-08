"use client";

import { clearAuthSession } from "@/shared/auth/session";
import { NotificationBell } from "@/shared/ui/notification-bell";
import Image from "next/image";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";

const quickNav = [
  { label: "New Task", iconSrc: "/file.svg", href: "/dashboard" },
  { label: "Library", iconSrc: "/library.png", href: "/library" },
  { label: "Search", iconSrc: "/search.png", href: "/search" },
  { label: "Projects", iconSrc: "/projects.png", href: "/projects" },
  { label: "Billing", iconSrc: "/window.svg", href: "/billing/manage" },
];

const allTasks = [
  { label: "Top 10 Transacting Merchants...", iconSrc: "/library.png", href: "#" },
  { label: "How to Run a Query to find th...", iconSrc: "/file.svg", href: "#" },
  { label: "Settings", iconSrc: "/window.svg", href: "/settings" },
];

export function BillingShell({
  children,
  drawerOpen,
  setDrawerOpen,
}: {
  children: React.ReactNode;
  drawerOpen: boolean;
  setDrawerOpen: (value: boolean) => void;
}) {
  const pathname = usePathname();
  const router = useRouter();

  const sidebar = (
    <aside className="flex h-full w-full flex-col border-r border-[var(--border)] bg-[color-mix(in_oklab,var(--surface)_96%,#eef3f8)] px-4 py-4">
      <div className="mb-4 flex items-center gap-2">
        <BrandWordmark />
      </div>

      <nav className="space-y-1.5">
        {quickNav.map((item) => (
          <Link
            key={item.label}
            href={item.href}
            className={`flex items-center gap-2 rounded-md px-2 py-1.5 text-[13px] ${
              pathname.startsWith(item.href)
                ? "bg-[var(--surface)] text-[var(--electric-blue)]"
                : "text-[var(--muted)] hover:bg-[var(--surface)]"
            }`}
          >
            <Image src={item.iconSrc} alt="" width={12} height={12} className="h-3 w-3 object-contain" />
            {item.label}
          </Link>
        ))}
      </nav>

      <p className="mt-6 px-2 text-[11px] font-medium uppercase tracking-[0.08em] text-[var(--muted)]">
        All Tasks
      </p>

      <nav className="mt-2 space-y-1.5">
        {allTasks.map((item) => (
          <Link
            key={item.label}
            href={item.href}
            className={`flex items-center gap-2 rounded-md px-2 py-1.5 text-[13px] ${
              pathname.startsWith(item.href)
                ? "bg-[var(--surface)] text-[var(--electric-blue)]"
                : "text-[var(--muted)] hover:bg-[var(--surface)]"
            }`}
          >
            <Image src={item.iconSrc} alt="" width={11} height={11} className="h-[11px] w-[11px] object-contain" />
            {item.label}
          </Link>
        ))}
      </nav>

      <button
        type="button"
        onClick={() => {
          clearAuthSession();
          router.replace("/login");
        }}
        className="mt-auto px-2 pb-2 text-left text-[13px] text-[#ef4444] hover:underline"
      >
        ← Logout
      </button>
    </aside>
  );

  return (
    <main className="h-screen w-screen overflow-hidden bg-[#f4f4f5] dark:bg-[var(--charcoal)]">
      <section className="h-full w-full overflow-hidden bg-[#f4f4f5] dark:bg-[var(--charcoal)]">
        <div className="grid h-full md:grid-cols-[290px_1fr]">
          <div className="hidden md:block">{sidebar}</div>

          <div className="relative flex h-full flex-col overflow-y-auto px-3 py-3 md:px-5 md:py-4">
            <TopBar onOpenMenu={() => setDrawerOpen(true)} />
            <div className="mx-auto w-full max-w-5xl pb-8 pt-3 md:pt-0">{children}</div>

            {drawerOpen ? (
              <div className="absolute inset-0 z-30 md:hidden">
                <button
                  type="button"
                  aria-label="Close drawer backdrop"
                  className="absolute inset-0 bg-black/25"
                  onClick={() => setDrawerOpen(false)}
                />
                <div className="relative z-10 h-full w-[74%] max-w-[290px]">
                  <div className="absolute right-3 top-3 z-20">
                    <button
                      type="button"
                      onClick={() => setDrawerOpen(false)}
                      className="inline-flex h-6 w-6 items-center justify-center rounded bg-[color-mix(in_oklab,var(--charcoal)_8%,white)] text-[var(--muted)]"
                      aria-label="Close drawer"
                    >
                      ×
                    </button>
                  </div>
                  {sidebar}
                </div>
              </div>
            ) : null}
          </div>
        </div>
      </section>
    </main>
  );
}

function TopBar({ onOpenMenu }: { onOpenMenu: () => void }) {
  return (
    <div className="flex items-center justify-between gap-2 border-b border-[var(--border)] pb-3 md:border-b-0 md:pb-0">
      <button
        type="button"
        onClick={onOpenMenu}
        className="inline-flex h-7 w-7 items-center justify-center rounded border border-[var(--border)] text-[var(--deep-navy)] dark:text-[var(--foreground)] md:hidden"
        aria-label="Open menu"
      >
        ☰
      </button>

      <div className="flex items-center gap-2 md:hidden">
        <button className="rounded-full border border-[var(--border)] bg-[var(--surface)] px-2 py-1 text-[11px] text-[var(--electric-blue)]">
          Upgrade Plan
        </button>
        <NotificationBell />
        <span className="inline-flex h-7 w-7 items-center justify-center rounded-full bg-[linear-gradient(140deg,#f9d576,#f39f6a)] text-[13px]">
          🧑
        </span>
      </div>
    </div>
  );
}

function BrandWordmark() {
  return (
    <picture>
      <source media="(prefers-color-scheme: dark)" srcSet="/icon-light.png" />
      <img src="/icon-dark.png" alt="Demycorp" className="h-6 w-auto" />
    </picture>
  );
}
