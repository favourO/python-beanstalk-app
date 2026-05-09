import type { Metadata } from "next";

const BASE_URL = "https://vyla.health";
const SITE_NAME = "Vyla";
const DEFAULT_OG_IMAGE = `${BASE_URL}/assets/images/hero-app-mockup.png`;
const DEFAULT_TWITTER_HANDLE = "@vyla_health";

export interface SeoConfig {
  title: string;
  description: string;
  keywords?: string[];
  path?: string;
  ogImage?: string;
  robots?: {
    index?: boolean;
    follow?: boolean;
  };
}

export function buildMetadata({
  title,
  description,
  keywords,
  path = "",
  ogImage = DEFAULT_OG_IMAGE,
  robots = { index: true, follow: true },
}: SeoConfig): Metadata {
  const canonicalUrl = `${BASE_URL}${path === "/" ? "" : path}`;

  return {
    title,
    description,
    ...(keywords?.length ? { keywords: keywords.join(", ") } : {}),
    metadataBase: new URL(BASE_URL),
    alternates: {
      canonical: canonicalUrl,
    },
    openGraph: {
      title,
      description,
      url: canonicalUrl,
      siteName: SITE_NAME,
      images: [
        {
          url: ogImage,
          width: 1200,
          height: 630,
          alt: title,
        },
      ],
      type: "website",
      locale: "en_GB",
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: [ogImage],
      site: DEFAULT_TWITTER_HANDLE,
      creator: DEFAULT_TWITTER_HANDLE,
    },
    robots: {
      index: robots.index ?? true,
      follow: robots.follow ?? true,
      googleBot: {
        index: robots.index ?? true,
        follow: robots.follow ?? true,
        "max-snippet": -1,
        "max-image-preview": "large",
        "max-video-preview": -1,
      },
    },
  };
}
