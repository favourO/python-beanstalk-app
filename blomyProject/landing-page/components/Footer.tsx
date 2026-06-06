import Image from "next/image";
import Link from "next/link";

const links: Record<string, { label: string; href: string }[]> = {
  Product: [
    { label: "Features", href: "#features" },
    { label: "How it works", href: "#how-it-works" },
    { label: "Vyla AI", href: "#vyla-ai" },
    { label: "Pricing", href: "#pricing" },
    { label: "Vyla Band", href: "/vyla-band" },
    { label: "Download", href: "#download" },
  ],
  Company: [
    { label: "Blog", href: "/blog" },
    { label: "Contact", href: "/contact" },
  ],
  Support: [
    { label: "Support", href: "/support" },
    { label: "Privacy policy", href: "/privacy" },
    { label: "Terms of service", href: "/terms" },
    { label: "Cookie settings", href: "#" },
  ],
};

const seoLinks = [
  { label: "Cycle tracking", href: "/cycle-tracking" },
  { label: "Ovulation tracking", href: "/ovulation-tracking" },
  { label: "BBT tracking", href: "/bbt-tracking" },
  { label: "Apple Health tracking", href: "/apple-health-cycle-tracking" },
  { label: "Fitbit cycle tracking", href: "/fitbit-cycle-tracking" },
  { label: "Wearable cycle insights", href: "/wearable-cycle-insights" },
  { label: "Vyla Band", href: "/vyla-band" },
];

export default function Footer() {
  return (
    <footer className="bg-[#1E0C16] border-t border-white/10">
      <div className="max-w-[1200px] mx-auto px-6 py-16">

        {/* Logo — centered */}
        <div className="flex justify-center mb-10">
          <Link href="/" aria-label="Vyla home">
            <Image
              src="https://vyla.health/assets/vyla-logo.png"
              alt="Vyla"
              width={1536}
              height={1024}
              className="h-28 w-auto"
              unoptimized
            />
          </Link>
        </div>

        {/* Nav links — centered grid */}
        <nav aria-label="Footer navigation" className="flex justify-center mb-10">
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-x-16 gap-y-8">
            {Object.entries(links).map(([category, items]) => (
              <div key={category} className="text-center sm:text-left">
                <p className="text-xs font-medium tracking-wider uppercase text-white/30 mb-4">
                  {category}
                </p>
                <ul className="flex flex-col gap-3" role="list">
                  {items.map((item) => (
                    <li key={item.label}>
                      <Link
                        href={item.href}
                        className="text-sm text-white/60 hover:text-white transition-colors focus-visible:outline-none focus-visible:text-white"
                      >
                        {item.label}
                      </Link>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        </nav>

        {/* SEO / Explore links — centered */}
        <nav aria-label="Feature pages" className="border-t border-white/10 pt-8 mb-8">
          <p className="text-xs font-medium tracking-wider uppercase text-white/30 mb-4 text-center">
            Explore
          </p>
          <ul className="flex flex-wrap justify-center gap-x-6 gap-y-2" role="list">
            {seoLinks.map((link) => (
              <li key={link.label}>
                <Link
                  href={link.href}
                  className="text-xs text-white/40 hover:text-white/70 transition-colors focus-visible:outline-none focus-visible:text-white"
                >
                  {link.label}
                </Link>
              </li>
            ))}
          </ul>
        </nav>

        {/* Brand text — centered */}
        <div className="text-center mb-10">
          <p className="text-sm font-light text-white/35 leading-relaxed mb-3">
            Know your rhythm. Understand your patterns.
          </p>
          <p className="text-xs font-light text-white/20 leading-relaxed max-w-[480px] mx-auto">
            Cycle tracking, predictions, and wellness insights for everyday
            use. Vyla is not a medical device and does not provide medical
            advice.
          </p>
        </div>

        {/* Bottom bar — Demycorp section (unchanged) */}
        <div className="border-t border-white/10 pt-6 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <p className="text-xs text-white/20">
            © 2026 Vyla Health, a product of Demycorp Ltd. All rights reserved.
          </p>
          <div className="flex gap-6">
            <Link
              href="/privacy"
              className="text-xs text-white/30 hover:text-white/60 transition-colors focus-visible:outline-none focus-visible:text-white"
            >
              Privacy
            </Link>
            <Link
              href="/terms"
              className="text-xs text-white/30 hover:text-white/60 transition-colors focus-visible:outline-none focus-visible:text-white"
            >
              Terms
            </Link>
            <a
              href="#"
              className="text-xs text-white/30 hover:text-white/60 transition-colors focus-visible:outline-none focus-visible:text-white"
            >
              Cookies
            </a>
          </div>
        </div>
      </div>
    </footer>
  );
}
