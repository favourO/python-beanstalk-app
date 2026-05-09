const BASE_URL = "https://vyla.health";

export function organizationSchema() {
  return {
    "@context": "https://schema.org",
    "@type": "Organization",
    name: "Vyla",
    alternateName: "Vyla Health Technologies",
    url: BASE_URL,
    logo: {
      "@type": "ImageObject",
      url: `${BASE_URL}/assets/vyla-logo.png`,
      width: 200,
      height: 60,
    },
    contactPoint: {
      "@type": "ContactPoint",
      contactType: "customer support",
      url: `${BASE_URL}/contact`,
      availableLanguage: "English",
    },
    address: {
      "@type": "PostalAddress",
      streetAddress: "6 Giles Avenue",
      addressLocality: "London",
      postalCode: "RM13",
      addressCountry: "GB",
    },
    sameAs: [
      "https://apps.apple.com/app/vyla",
      "https://play.google.com/store/apps/vyla",
    ],
  };
}

export function mobileApplicationSchema() {
  return {
    "@context": "https://schema.org",
    "@type": "MobileApplication",
    name: "Vyla — Cycle & Wellness Tracking",
    operatingSystem: "iOS, Android",
    applicationCategory: "HealthApplication",
    applicationSubCategory: "Women's Health",
    offers: [
      {
        "@type": "Offer",
        name: "Free",
        price: "0",
        priceCurrency: "GBP",
      },
      {
        "@type": "Offer",
        name: "Premium",
        price: "3.99",
        priceCurrency: "GBP",
        billingIncrement: "P1M",
      },
    ],
    aggregateRating: {
      "@type": "AggregateRating",
      ratingValue: "4.8",
      reviewCount: "50000",
      bestRating: "5",
    },
    description:
      "Track your menstrual cycle, BBT temperature, symptoms, moods, fertile window, and wearable wellness trends. Get AI-powered cycle insights and ovulation tracking in one private, easy-to-use app.",
    author: {
      "@type": "Organization",
      name: "Vyla",
      url: BASE_URL,
    },
    screenshot: `${BASE_URL}/assets/images/hero-app-mockup.png`,
    featureList: [
      "Period and cycle tracking",
      "BBT temperature logging",
      "Ovulation tracking",
      "Wearable integration (Oura Ring)",
      "AI-powered cycle insights",
      "Symptom and mood logging",
      "Fertile window predictions",
      "Privacy-first data controls",
    ],
  };
}

export function webSiteSchema() {
  return {
    "@context": "https://schema.org",
    "@type": "WebSite",
    name: "Vyla",
    url: BASE_URL,
    description:
      "Vyla is an AI-powered cycle and wellness tracking app for iPhone and Android. Track periods, BBT temperature, symptoms, and wearable insights privately.",
    potentialAction: {
      "@type": "SearchAction",
      target: {
        "@type": "EntryPoint",
        urlTemplate: `${BASE_URL}/blog?q={search_term_string}`,
      },
      "query-input": "required name=search_term_string",
    },
  };
}

export function faqSchema(items: { q: string; a: string }[]) {
  return {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: items.map(({ q, a }) => ({
      "@type": "Question",
      name: q,
      acceptedAnswer: {
        "@type": "Answer",
        text: a,
      },
    })),
  };
}

export function breadcrumbSchema(
  crumbs: { name: string; url: string }[]
) {
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: crumbs.map((crumb, i) => ({
      "@type": "ListItem",
      position: i + 1,
      name: crumb.name,
      item: crumb.url,
    })),
  };
}
