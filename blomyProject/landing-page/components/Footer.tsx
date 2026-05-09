import Image from "next/image";
import Link from "next/link";

const links: Record<string, { label: string; href: string }[]> = {
  Product: [
    { label: "Features", href: "#features" },
    { label: "How it works", href: "#how-it-works" },
    { label: "Vyla AI", href: "#vyla-ai" },
    { label: "Pricing", href: "#pricing" },
    { label: "Download", href: "#" },
  ],
  Company: [
    { label: "Blog", href: "#" },
    { label: "Press", href: "#" },
    { label: "Contact", href: "/contact" },
  ],
  Support: [
    { label: "Privacy policy", href: "/privacy" },
    { label: "Terms of service", href: "/terms" },
    { label: "Cookie settings", href: "#" },
  ],
};

export default function Footer() {
  return (
    <footer className="bg-[#1E0C16] border-t border-white/10">
      <div className="max-w-[1200px] mx-auto px-6 py-16">
        <div className="flex flex-col gap-8 mb-12">
          {/* Top row: logo + links */}
          <div className="flex flex-col lg:flex-row items-start gap-12 lg:gap-20">
            {/* Logo */}
            <a href="#" className="block shrink-0">
              <Image src="https://vyla.health/assets/vyla-logo.png" alt="Vyla" width={1536} height={1024} className="h-30 w-auto" unoptimized />
            </a>

            {/* Links */}
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-8 flex-1">
              {Object.entries(links).map(([category, items]) => (
                <div key={category}>
                  <p className="text-xs font-medium tracking-wider uppercase text-white/30 mb-4">{category}</p>
                  <ul className="flex flex-col gap-3">
                    {items.map((item) => (
                      <li key={item.label}>
                        <Link href={item.href} className="text-sm text-white/60 hover:text-white transition-colors">
                          {item.label}
                        </Link>
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>
          </div>

          {/* Brand text — centered under full row */}
          <div className="text-center">
            <p className="text-sm font-light text-white/35 leading-relaxed mb-3">
              Know your rhythm. Understand your patterns.
            </p>
            <p className="text-xs font-light text-white/20 leading-relaxed max-w-[480px] mx-auto">
              Cycle tracking, predictions, and wellness insights for everyday use. Vyla is not a medical device and does not provide medical advice.
            </p>
          </div>
        </div>

        {/* Bottom bar */}
        <div className="border-t border-white/10 pt-6 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <p className="text-xs text-white/20">© 2026 DemyCorp Ltd. All rights reserved.</p>
          <div className="flex gap-6">
            <Link href="/privacy" className="text-xs text-white/30 hover:text-white/60 transition-colors">Privacy</Link>
            <Link href="/terms" className="text-xs text-white/30 hover:text-white/60 transition-colors">Terms</Link>
            <a href="#" className="text-xs text-white/30 hover:text-white/60 transition-colors">Cookies</a>
          </div>
        </div>
      </div>
    </footer>
  );
}
