"use client";

import { hasValidAuthSession } from "@/shared/auth/session";
import { Container } from "@/shared/ui/container";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { SignupForm } from "../components/signup-form";

export function SignupScreen() {
  const router = useRouter();

  useEffect(() => {
    if (hasValidAuthSession()) {
      router.replace("/dashboard");
    }
  }, [router]);

  return (
    <main className="relative min-h-screen overflow-hidden bg-[#f8faf8] text-[var(--charcoal)]">
      <div className="absolute inset-0 bg-[linear-gradient(180deg,color-mix(in_oklab,var(--accent-teal)_30%,white)_0%,#f9fbfb_40%,color-mix(in_oklab,var(--insight-gold)_14%,white)_100%)]" />
      <div className="absolute inset-0 opacity-60 [background-image:linear-gradient(to_right,color-mix(in_oklab,var(--charcoal)_8%,transparent)_1px,transparent_1px),linear-gradient(to_bottom,color-mix(in_oklab,var(--charcoal)_8%,transparent)_1px,transparent_1px)] [background-size:24px_24px]" />

      <Container className="relative z-10 flex min-h-screen flex-col items-center justify-start py-3 md:justify-center md:py-12">
        <MobileStatusBar />

        <section className="w-full max-w-[470px] rounded-3xl border border-[var(--border)] bg-[var(--surface)] p-5 shadow-[0_28px_60px_-48px_rgba(11,19,43,0.75)] dark:border-[var(--border-strong)] dark:bg-[var(--charcoal)] md:p-6">
          <div className="mb-4 flex items-center gap-2.5">
            <BrandIcon />
            <span className="text-[30px] font-semibold tracking-tight text-[var(--deep-navy)] dark:text-[var(--foreground)]">
              Demycorp
            </span>
          </div>

          <header className="mb-4">
            <h1 className="text-[46px] font-semibold leading-tight text-[var(--deep-navy)] dark:text-[var(--foreground)] md:text-[42px]">
              Let&apos;s get you started
            </h1>
            <p className="mt-1 text-xs text-[var(--muted)]">
              Start turning your data uploads into insights in minutes.
            </p>
          </header>

          <SignupForm />
        </section>

        <footer className="mt-6 hidden flex-wrap items-center justify-center gap-4 text-xs text-[var(--muted)] md:flex">
          <a href="#" className="hover:text-[var(--electric-blue)] hover:underline">
            Terms of Services
          </a>
          <a href="#" className="hover:text-[var(--electric-blue)] hover:underline">
            Privacy Policy
          </a>
          <span>© 2026 Demy Corp Ltd.</span>
        </footer>
      </Container>

      <Decoration className="bottom-0 left-0" />
      <Decoration className="bottom-0 right-0" mirrored />
    </main>
  );
}

function MobileStatusBar() {
  return (
    <div className="mb-4 flex w-full max-w-[470px] items-center justify-between px-2 text-[14px] font-semibold text-[var(--charcoal)] dark:text-[var(--foreground)] md:hidden">
      <span>9:41</span>
      <div className="flex items-end gap-1">
        <span className="h-2.5 w-1 rounded bg-current" />
        <span className="h-3.5 w-1 rounded bg-current" />
        <span className="h-4.5 w-1 rounded bg-current" />
        <span className="h-5.5 w-1 rounded bg-current" />
      </div>
    </div>
  );
}

function BrandIcon() {
  return (
    <span className="relative inline-flex h-5 w-5 items-center justify-center">
      <Image
        src="/logo-dark.png"
        alt=""
        width={20}
        height={20}
        className="h-5 w-5 object-contain dark:hidden"
      />
      <Image
        src="/logo-light.png"
        alt=""
        width={20}
        height={20}
        className="hidden h-5 w-5 object-contain dark:block"
      />
    </span>
  );
}

type DecorationProps = {
  className: string;
  mirrored?: boolean;
};

function Decoration({ className, mirrored }: DecorationProps) {
  return (
    <div className={`pointer-events-none absolute ${className}`}>
      <div className={`relative h-20 w-24 md:h-28 md:w-36 ${mirrored ? "scale-x-[-1]" : ""}`}>
        <span className="ornament-float absolute -left-4 top-10 h-10 w-10 rounded-full bg-[var(--electric-blue)] md:-left-5 md:top-12 md:h-12 md:w-12" />
        <span className="ornament-spin absolute right-2 top-4 h-6 w-6 rotate-45 bg-[var(--insight-gold)] md:right-3 md:h-7 md:w-7" />
        <span className="ornament-twinkle absolute left-7 top-2 text-[20px] text-[var(--electric-blue)] md:left-10 md:text-[28px]">
          ★
        </span>
        <span className="ornament-float-delayed absolute -bottom-1 left-11 text-[20px] text-[#ff5f8f] md:left-14 md:text-[24px]">
          ♥
        </span>
      </div>
    </div>
  );
}
