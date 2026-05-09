import type { Metadata } from "next";
import { DM_Sans, Cormorant_Garamond } from "next/font/google";
import "./globals.css";
import SkipNav from "@/components/SkipNav";
import JsonLd from "@/components/JsonLd";
import {
  organizationSchema,
  mobileApplicationSchema,
  webSiteSchema,
} from "@/lib/jsonld";

const dmSans = DM_Sans({
  variable: "--font-dm-sans",
  subsets: ["latin"],
  weight: ["300", "400", "500", "600"],
  display: "swap",
});

const cormorant = Cormorant_Garamond({
  variable: "--font-cormorant",
  subsets: ["latin"],
  weight: ["400", "600"],
  style: ["normal", "italic"],
  display: "swap",
});

const BASE_URL = "https://vyla.health";

export const metadata: Metadata = {
  metadataBase: new URL(BASE_URL),
  title: {
    default: "Vyla — AI-Powered Cycle & Wellness Tracking App",
    template: "%s | Vyla",
  },
  description:
    "Track your period, BBT temperature, ovulation, symptoms, and wearable wellness trends with Vyla. AI-powered cycle insights in a private, easy-to-use app for iPhone and Android.",
  keywords:
    "cycle tracking app, period tracker, BBT tracking, ovulation tracking, menstrual cycle tracker, wearable cycle insights, Oura ring period tracking, AI wellness, women's health app",
  authors: [{ name: "Vyla", url: BASE_URL }],
  creator: "Vyla",
  publisher: "Vyla",
  category: "health",
  alternates: {
    canonical: BASE_URL,
  },
  openGraph: {
    type: "website",
    locale: "en_GB",
    url: BASE_URL,
    siteName: "Vyla",
    title: "Vyla — AI-Powered Cycle & Wellness Tracking App",
    description:
      "Track your period, BBT temperature, ovulation, symptoms, and wearable wellness trends. AI-powered cycle insights in a private app for iPhone and Android.",
    images: [
      {
        url: `${BASE_URL}/assets/images/hero-app-mockup.png`,
        width: 1200,
        height: 630,
        alt: "Vyla cycle tracking app — period, BBT, and ovulation insights",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    site: "@vyla_health",
    creator: "@vyla_health",
    title: "Vyla — AI-Powered Cycle & Wellness Tracking App",
    description:
      "Track your period, BBT temperature, ovulation, symptoms, and wearable wellness trends privately.",
    images: [`${BASE_URL}/assets/images/hero-app-mockup.png`],
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-snippet": -1,
      "max-image-preview": "large",
      "max-video-preview": -1,
    },
  },
  icons: {
    icon: [
      { url: "/favicon.ico", sizes: "any" },
      { url: "/icon.png", type: "image/png" },
    ],
    apple: "/apple-icon.png",
  },
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={`${dmSans.variable} ${cormorant.variable}`}>
      <head>
        <link
          rel="preconnect"
          href="https://vyla.health"
          crossOrigin="anonymous"
        />
      </head>
      <body className="min-h-full antialiased">
        <JsonLd
          data={[organizationSchema(), mobileApplicationSchema(), webSiteSchema()]}
        />
        <SkipNav />
        {children}
      </body>
    </html>
  );
}
