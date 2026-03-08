"use client";

import { clearAuthSession, hasValidAuthSession } from "@/shared/auth/session";
import { NotificationBell } from "@/shared/ui/notification-bell";
import Image from "next/image";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

const quickNav = [
  { label: "New Task", iconSrc: "/file.svg", href: "/dashboard" },
  { label: "Library", iconSrc: "/library.png", href: "/library" },
  { label: "Search", iconSrc: "/search.png", href: "/search" },
  { label: "Projects", iconSrc: "/projects.png", href: "/projects" },
];

const allTasks = [
  { label: "Top 10 Transacting Merchants...", iconSrc: "/library.png", href: "#" },
  { label: "How to Run a Query to find th...", iconSrc: "/file.svg", href: "#" },
  { label: "Settings", iconSrc: "/window.svg", href: "/settings" },
];

const cards = [
  {
    title: "Customer Overview Dashboard",
    description:
      "View a summary of all customers, including key demographics and signup trends",
    iconSrc: "/overview.png",
  },
  {
    title: "Key Insights Summary",
    description: "Get processed insights and highlights from your data",
    iconSrc: "/insights.png",
  },
  {
    title: "Growth Analysis",
    description: "Track customer growth trends and historical signups",
    iconSrc: "/growth.png",
  },
  {
    title: "Advanced Filters",
    description: "Combine multiple conditions to narrow down customer segments",
    iconSrc: "/filters.png",
  },
];

const searchGroups = [
  {
    label: "",
    rows: [{ icon: "/file.svg", text: "New Task" }],
  },
  {
    label: "Yesterday",
    rows: [
      { icon: "/library.png", text: "Top 10 Transacting Merchants..." },
      { icon: "/window.svg", text: "How to Run a Query to find th...." },
    ],
  },
  {
    label: "Previous 7 Days",
    rows: [
      { icon: "/library.png", text: "Top 10 Transacting Merchants..." },
      { icon: "/window.svg", text: "How to Run a Query to find th...." },
    ],
  },
  {
    label: "Previous 30 Days",
    rows: [
      { icon: "/library.png", text: "Top 10 Transacting Merchants..." },
      { icon: "/window.svg", text: "How to Run a Query to find th...." },
    ],
  },
];

export function SearchScreen() {
  const pathname = usePathname();
  const router = useRouter();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [searchOpen, setSearchOpen] = useState(true);

  useEffect(() => {
    if (!hasValidAuthSession()) {
      router.replace("/login");
    }
  }, [router]);

  useEffect(() => {
    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setSearchOpen(false);
      }
    };

    window.addEventListener("keydown", handleEscape);
    return () => window.removeEventListener("keydown", handleEscape);
  }, []);

  const sidebar = useMemo(() => {
    return (
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
                pathname === item.href
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
              className="flex items-center gap-2 rounded-md px-2 py-1.5 text-[13px] text-[var(--muted)] hover:bg-[var(--surface)]"
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
  }, [pathname, router]);

  return (
    <main className="h-screen w-screen overflow-hidden bg-[#f4f4f5] dark:bg-[var(--charcoal)]">
      <section className="h-full w-full overflow-hidden">
        <div className="grid h-full md:grid-cols-[290px_1fr]">
          <div className="hidden md:block">{sidebar}</div>

          <div className="relative flex h-full flex-col overflow-y-auto px-3 py-3 md:px-5 md:py-4">
            <TopBar onOpenMenu={() => setDrawerOpen(true)} />

            <section className="mx-auto mt-10 w-full max-w-[720px] text-center md:mt-12">
              <h2 className="text-[28px] font-semibold leading-tight text-[var(--deep-navy)] dark:text-[var(--foreground)] md:text-[44px]">
                Start Anywhere With Demycorp
              </h2>
              <p className="mx-auto mt-2 max-w-[620px] text-xs leading-5 text-[var(--muted)] md:text-sm">
                Upload data files, connect live sources, and query your data using natural
                language*. clean, direct, ideal for an action prompt under an AI input box.
              </p>
            </section>

            <section className="mx-auto mt-6 w-full max-w-[720px]">
              <div className="grid grid-cols-2 gap-2">
                {cards.map((card) => (
                  <article key={card.title} className="rounded-lg border border-[var(--border)] bg-[var(--surface)] p-3">
                    <div className="inline-flex h-7 w-7 items-center justify-center rounded-md bg-[color-mix(in_oklab,var(--electric-blue)_12%,white)]">
                      <Image src={card.iconSrc} alt="" width={16} height={16} className="h-4 w-4 object-contain" />
                    </div>
                    <h3 className="mt-2 text-[13px] font-semibold leading-tight text-[var(--deep-navy)] dark:text-[var(--foreground)]">
                      {card.title}
                    </h3>
                    <p className="mt-1 hidden text-[11px] leading-4 text-[var(--muted)] md:block">
                      {card.description}
                    </p>
                  </article>
                ))}
              </div>
            </section>

            <section className="flex flex-1 items-end justify-center py-6 md:py-8">
              <div className="mx-auto flex w-full max-w-[720px] items-center justify-between gap-2 rounded-2xl border border-[var(--border)] bg-[var(--surface)] px-4 py-3 min-h-16 md:min-h-20 md:px-5">
                <p className="text-sm text-[var(--muted)] md:text-base">Assign a task or ask anything</p>
                <div className="flex items-center gap-2">
                  <button className="inline-flex h-7 w-7 items-center justify-center rounded-full bg-[color-mix(in_oklab,var(--charcoal)_10%,white)] text-sm text-[var(--charcoal)] dark:text-[var(--foreground)]">
                    +
                  </button>
                  <button className="inline-flex h-7 w-7 items-center justify-center rounded-full bg-[var(--electric-blue)] text-sm text-white">
                    ↑
                  </button>
                </div>
              </div>
            </section>

            {searchOpen ? (
              <>
                <button
                  type="button"
                  aria-label="Close search overlay"
                  className="absolute inset-0 z-20 bg-black/28"
                  onClick={() => setSearchOpen(false)}
                />
                <SearchOverlay onClose={() => setSearchOpen(false)} />
              </>
            ) : null}

            {drawerOpen ? (
              <div className="absolute inset-0 z-40 md:hidden">
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

function SearchOverlay({ onClose }: { onClose: () => void }) {
  return (
    <section className="pointer-events-auto absolute left-1/2 top-[16%] z-30 w-[95%] max-w-[760px] -translate-x-1/2 rounded-2xl bg-[var(--surface)] shadow-[0_16px_48px_rgba(0,0,0,0.18)] md:top-[18%]">
      <div className="flex items-center gap-3 rounded-t-2xl bg-[color-mix(in_oklab,var(--surface)_95%,#eaf3f3)] px-4 py-3 md:px-6">
        <span className="text-base text-[var(--muted)]">⌕</span>
        <input
          type="text"
          placeholder="Search through chats....."
          className="h-8 w-full border-0 bg-transparent text-[15px] text-[var(--foreground)] outline-none placeholder:text-[var(--muted)]"
        />
        <button
          type="button"
          aria-label="Close search panel"
          onClick={onClose}
          className="inline-flex h-8 w-8 items-center justify-center rounded-md bg-[color-mix(in_oklab,var(--charcoal)_8%,white)] text-lg leading-none text-[var(--muted)]"
        >
          ×
        </button>
      </div>

      <div className="space-y-4 px-4 py-4 md:px-6 md:py-5">
        {searchGroups.map((group, groupIndex) => (
          <div key={`${group.label}-${groupIndex}`}>
            {group.label ? <p className="mb-1 text-[14px] text-[var(--muted)]">{group.label}</p> : null}
            <div className="space-y-2">
              {group.rows.map((row, rowIndex) => (
                <button
                  key={`${row.text}-${rowIndex}`}
                  type="button"
                  className="flex w-full items-center gap-3 text-left text-[31px] text-[var(--deep-navy)] dark:text-[var(--foreground)]"
                >
                  <Image src={row.icon} alt="" width={18} height={18} className="h-[18px] w-[18px] object-contain" />
                  <span className="text-[clamp(14px,2.2vw,34px)] leading-tight">{row.text}</span>
                </button>
              ))}
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}

function TopBar({ onOpenMenu }: { onOpenMenu: () => void }) {
  return (
    <div className="flex items-center justify-between gap-2 border-b border-[var(--border)] pb-3 md:border-b-0 md:pb-0">
      <div className="flex items-center gap-2">
        <button
          type="button"
          onClick={onOpenMenu}
          className="inline-flex h-7 w-7 items-center justify-center rounded border border-[var(--border)] text-[var(--deep-navy)] dark:text-[var(--foreground)] md:hidden"
          aria-label="Open menu"
        >
          ☰
        </button>
        <button className="inline-flex items-center rounded-full border border-[var(--border)] bg-[var(--surface)] px-2.5 py-1 text-[11px] text-[var(--deep-navy)] dark:text-[var(--foreground)]">
          Demydata
        </button>
      </div>

      <div className="hidden items-center gap-1.5 md:flex">
        <span className="rounded-full border border-[var(--border)] bg-[var(--surface)] px-2 py-1 text-[11px] text-[var(--electric-blue)]">
          Free Plan
        </span>
        <span className="rounded-full border border-[var(--border)] bg-[var(--surface)] px-2 py-1 text-[11px] text-[var(--muted)]">
          Upgrade
        </span>
      </div>

      <div className="flex items-center gap-2">
        <button className="rounded-full border border-[var(--border)] bg-[var(--surface)] px-2 py-1 text-[11px] text-[var(--electric-blue)] md:hidden">
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
