"use client";

import { Container } from "@/shared/ui/container";
import { hasValidAuthSession } from "@/shared/auth/session";
import Image from "next/image";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { type ChangeEvent, useEffect, useMemo, useRef, useState } from "react";

type Card = {
  id: string;
  title: string;
  description: string;
  iconSrc: string;
  tone: "navy" | "teal" | "blue" | "gold";
  order: string;
};

const cards: Card[] = [
  {
    id: "customer-overview",
    title: "Customer Overview Dashboard",
    description:
      "View a summary of all customers, including key demographics and signup trends",
    iconSrc: "/overview.png",
    tone: "navy",
    order: "order-1 md:order-1",
  },
  {
    id: "advanced-filters",
    title: "Advanced Filters",
    description: "Combine multiple conditions to narrow down customer segments",
    iconSrc: "/filters.png",
    tone: "gold",
    order: "order-2 md:order-4",
  },
  {
    id: "growth-analysis",
    title: "Growth Analysis",
    description: "Track customer growth trends and historical signups",
    iconSrc: "/growth.png",
    tone: "blue",
    order: "order-3 md:order-3",
  },
  {
    id: "key-insights",
    title: "Key Insights Summary",
    description: "Get processed insights and highlights from your data",
    iconSrc: "/insights.png",
    tone: "teal",
    order: "order-4 md:order-2",
  },
];

const toneStyles: Record<Card["tone"], string> = {
  navy: "bg-[color-mix(in_oklab,var(--deep-navy)_10%,white)]",
  teal: "bg-[color-mix(in_oklab,var(--cyan-teal)_26%,white)]",
  blue: "bg-[color-mix(in_oklab,var(--electric-blue)_16%,white)]",
  gold: "bg-[color-mix(in_oklab,var(--insight-gold)_30%,white)]",
};

export function HomeScreen() {
  const router = useRouter();
  const [taskInput, setTaskInput] = useState("");
  const [animatedHint, setAnimatedHint] = useState("");
  const [hintIndex, setHintIndex] = useState(0);
  const [isLoggedIn] = useState(() => {
    return hasValidAuthSession();
  });
  const [showLoginPrompt, setShowLoginPrompt] = useState(false);
  const [uploadMenuOpen, setUploadMenuOpen] = useState(false);
  const [uploadedFiles, setUploadedFiles] = useState<Array<{ name: string; sizeLabel: string }>>([]);
  const uploadMenuRef = useRef<HTMLDivElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const hints = useMemo(
    () => [
      "Assign a task or ask anything",
      "Summarize customer growth for this quarter",
      "Find top 10 transacting merchants",
      "Create an insights report for leadership",
    ],
    [],
  );

  useEffect(() => {
    if (hasValidAuthSession()) {
      router.replace("/dashboard");
    }
  }, [router]);

  useEffect(() => {
    if (taskInput) return;

    const fullText = hints[hintIndex % hints.length];
    let charIndex = 0;
    const resetTimer = setTimeout(() => setAnimatedHint(""), 0);
    let holdTimer: ReturnType<typeof setTimeout> | undefined;

    const typeTimer = setInterval(() => {
      charIndex += 1;
      setAnimatedHint(fullText.slice(0, charIndex));
      if (charIndex >= fullText.length) {
        clearInterval(typeTimer);
        holdTimer = setTimeout(() => {
          setHintIndex((prev) => (prev + 1) % hints.length);
        }, 1200);
      }
    }, 35);

    return () => {
      clearTimeout(resetTimer);
      clearInterval(typeTimer);
      if (holdTimer) clearTimeout(holdTimer);
    };
  }, [hintIndex, hints, taskInput]);

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (!uploadMenuRef.current) return;
      if (!uploadMenuRef.current.contains(event.target as Node)) {
        setUploadMenuOpen(false);
      }
    }

    if (uploadMenuOpen) {
      document.addEventListener("mousedown", handleClickOutside);
    }

    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, [uploadMenuOpen]);

  const handleUploadFromComputer = () => {
    setUploadMenuOpen(false);
    fileInputRef.current?.click();
  };

  const handleFileChange = (event: ChangeEvent<HTMLInputElement>) => {
    const files = event.target.files;
    if (!files || files.length === 0) return;

    const mapped = Array.from(files).map((file) => ({
      name: file.name,
      sizeLabel: file.size > 1024 * 1024 ? `${(file.size / (1024 * 1024)).toFixed(1)} MB` : `${Math.max(1, Math.round(file.size / 1024))} KB`,
    }));

    setUploadedFiles((prev) => [...prev, ...mapped]);
    event.target.value = "";
  };

  const removeUploadedFile = (name: string) => {
    setUploadedFiles((prev) => prev.filter((file) => file.name !== name));
  };

  const handleProcess = () => {
    if (!isLoggedIn) {
      setShowLoginPrompt(true);
      return;
    }
  };

  return (
    <main className="h-screen w-screen overflow-hidden bg-[#f4f4f5] text-[var(--deep-navy)] dark:bg-[var(--charcoal)] dark:text-[var(--foreground)]">
      <Container className="flex h-full flex-col px-3 py-3 md:px-5 md:py-4">
        <header className="rounded-md bg-[var(--surface)] px-3 py-2">
          <div className="flex items-center justify-between">
            <BrandWordmark />
            <Link
              href="/login"
              className="inline-flex h-8 items-center justify-center rounded-md bg-[var(--electric-blue)] px-4 text-xs font-medium text-white"
            >
              Log In
            </Link>
          </div>
        </header>

        <section className="mx-auto mt-10 w-full max-w-[700px] text-center md:mt-12">
          <h1 className="text-[28px] font-semibold leading-tight tracking-tight md:text-[44px]">
            Start Anywhere With Demycorp
          </h1>
          <p className="mx-auto mt-2 max-w-[620px] text-xs leading-5 text-[var(--muted)] md:text-sm">
            Upload data files, connect live sources, and query your data using natural
            language*. clean, direct, ideal for an AI input box.
          </p>
        </section>

        <section className="mx-auto mt-6 w-full max-w-[700px]">
          <div className="grid grid-cols-2 gap-2">
            {cards.map((card, index) => (
              <article
                key={card.id}
                className={`${card.order} rounded-lg border border-[var(--border)] bg-[var(--surface)] p-3`}
              >
                <div className={`inline-flex h-7 w-7 items-center justify-center rounded-md ${toneStyles[card.tone]}`}>
                  <Image src={card.iconSrc} alt="" width={16} height={16} className="h-4 w-4 object-contain" />
                </div>
                <h2 className="mt-2 text-[13px] font-semibold leading-tight">{card.title}</h2>
                <p className={`mt-1 text-[11px] leading-4 text-[var(--muted)] ${index < 2 ? "hidden md:block" : "hidden md:block"}`}>
                  {card.description}
                </p>
              </article>
            ))}
          </div>
        </section>

        <section className="mt-auto pb-2 pt-8">
          <div className="mx-auto w-full max-w-[700px] rounded-2xl border border-[var(--border)] bg-[var(--surface)] px-4 py-3 transition focus-within:border-[var(--electric-blue)] focus-within:shadow-[0_0_0_2px_color-mix(in_oklab,var(--electric-blue)_24%,transparent)] md:px-5">
            {uploadedFiles.length > 0 ? (
              <div className="mb-2 flex flex-wrap gap-2">
                {uploadedFiles.map((file) => (
                  <span
                    key={`${file.name}-${file.sizeLabel}`}
                    className="inline-flex items-center gap-1 rounded-full bg-[color-mix(in_oklab,var(--electric-blue)_12%,white)] px-2 py-1 text-[11px] text-[var(--deep-navy)] dark:text-[var(--foreground)]"
                  >
                    <span className="max-w-[180px] truncate">{file.name}</span>
                    <span className="text-[10px] text-[var(--muted)]">{file.sizeLabel}</span>
                    <button
                      type="button"
                      onClick={() => removeUploadedFile(file.name)}
                      className="inline-flex h-4 w-4 items-center justify-center rounded-full text-[10px] text-[var(--muted)] hover:bg-[color-mix(in_oklab,var(--charcoal)_12%,white)]"
                      aria-label={`Remove ${file.name}`}
                    >
                      ×
                    </button>
                  </span>
                ))}
              </div>
            ) : null}

            <div className="flex min-h-16 items-center justify-between gap-2 md:min-h-20">
              <div className="relative w-full">
                <input
                  type="text"
                  value={taskInput}
                  onChange={(e) => setTaskInput(e.target.value)}
                  aria-label="Task input"
                  className="h-11 w-full border-0 bg-transparent text-base text-[var(--foreground)] outline-none md:h-12 md:text-lg"
                />
                {!taskInput ? (
                  <span className="pointer-events-none absolute left-0 top-1/2 -translate-y-1/2 text-base text-[var(--muted)] md:text-lg">
                    {animatedHint}
                    <span className="ml-0.5 inline-block animate-pulse">|</span>
                  </span>
                ) : null}
              </div>

              <div className="flex items-center gap-2">
                <div className="relative" ref={uploadMenuRef}>
                  <button
                    type="button"
                    aria-label="Upload"
                    onClick={() => setUploadMenuOpen((prev) => !prev)}
                    className="inline-flex h-7 w-7 items-center justify-center rounded-full bg-[color-mix(in_oklab,var(--charcoal)_10%,white)] text-sm font-semibold text-[var(--charcoal)] transition hover:scale-105 hover:brightness-95 dark:bg-[color-mix(in_oklab,var(--cool-gray)_12%,var(--charcoal))] dark:text-[var(--foreground)] md:h-8 md:w-8"
                  >
                    +
                  </button>
                  {uploadMenuOpen ? (
                    <div className="absolute bottom-full right-0 z-20 mb-2 min-w-[190px] rounded-lg border border-[var(--border)] bg-[var(--surface)] p-1 shadow-[0_10px_30px_rgba(0,0,0,0.12)]">
                      <button
                        type="button"
                        onClick={handleUploadFromComputer}
                        className="w-full rounded-md px-2 py-2 text-left text-sm text-[var(--deep-navy)] hover:bg-[color-mix(in_oklab,var(--electric-blue)_10%,white)] dark:text-[var(--foreground)]"
                      >
                        Upload from computer
                      </button>
                    </div>
                  ) : null}
                </div>

                <button
                  type="button"
                  onClick={handleProcess}
                  className="inline-flex h-8 items-center justify-center rounded-full bg-[var(--electric-blue)] px-4 text-xs font-semibold text-white transition hover:scale-105 hover:brightness-95 md:h-9 md:px-5 md:text-sm"
                >
                  Process
                </button>
              </div>
            </div>

            <input
              ref={fileInputRef}
              type="file"
              className="hidden"
              multiple
              onChange={handleFileChange}
              aria-hidden="true"
            />
          </div>
        </section>
      </Container>

      {showLoginPrompt ? (
        <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/40 px-4">
          <div className="w-full max-w-[360px] rounded-xl border border-[var(--border)] bg-[var(--surface)] p-4 shadow-[0_18px_48px_rgba(0,0,0,0.18)]">
            <h2 className="text-lg font-semibold text-[var(--deep-navy)] dark:text-[var(--foreground)]">Login required</h2>
            <p className="mt-1 text-sm text-[var(--muted)]">
              Please log in to process prompts and uploaded files.
            </p>
            <div className="mt-4 flex items-center justify-end gap-2">
              <button
                type="button"
                onClick={() => setShowLoginPrompt(false)}
                className="inline-flex h-9 items-center justify-center rounded-md border border-[var(--border)] px-3 text-sm text-[var(--muted)]"
              >
                Cancel
              </button>
              <Link
                href="/login"
                className="inline-flex h-9 items-center justify-center rounded-md bg-[var(--electric-blue)] px-3 text-sm font-medium text-white"
              >
                Log in
              </Link>
            </div>
          </div>
        </div>
      ) : null}
    </main>
  );
}

function BrandWordmark() {
  return (
    <picture>
      <source media="(prefers-color-scheme: dark)" srcSet="/icon-light.png" />
      <img src="/icon-dark.png" alt="Demycorp" className="h-5 w-auto" />
    </picture>
  );
}
