import type { Metadata } from "next";
import SeoPageLayout from "@/components/SeoPageLayout";
import { buildMetadata } from "@/lib/seo";

export const metadata: Metadata = buildMetadata({
  title: "Wearable Cycle Insights — Smartwatch & Ring Period Tracking",
  description:
    "Use your wearable's health data to understand your menstrual cycle better. Vyla integrates with Oura Ring to layer temperature and wellness trends on top of your cycle tracking.",
  keywords: [
    "wearable cycle tracking",
    "smartwatch period tracker",
    "wearable menstrual insights",
    "wearable health cycle",
    "Oura ring cycle",
    "wearable temperature cycle",
    "cycle insights wearable",
    "period tracking smartwatch",
  ],
  path: "/wearable-cycle-insights",
});

const features = [
  {
    icon: "https://vyla.health/assets/icons/icon-radar.png",
    iconBg: "#E6FDF9",
    title: "Temperature from your wearable",
    body: "Devices like Oura Ring measure continuous skin temperature throughout the night. Vyla layers this data over your cycle timeline to reveal temperature patterns you might miss with manual logging alone.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-chart.png",
    iconBg: "#F0F0FF",
    title: "Cycle-phase wellness view",
    body: "See how your HRV, resting heart rate, sleep quality, and activity levels track across your menstrual, follicular, ovulatory, and luteal phases.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-sound.png",
    iconBg: "#FFF6DD",
    title: "Ovulation temperature signal",
    body: "Wearable temperature data can reveal the thermal shift that typically occurs after ovulation — giving you a passive signal to complement manual BBT and LH logs.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-note.png",
    iconBg: "#FFF0F8",
    title: "Unified data timeline",
    body: "Your wearable's readings sit alongside your logged symptoms, period dates, mood, and energy in a single continuous Vyla timeline — no switching between apps.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-ai.png",
    iconBg: "#FFF0F8",
    title: "AI-powered pattern questions",
    body: "Ask Vyla AI why your sleep or heart rate might dip at certain points in your cycle. Get clear, jargon-free explanations based on your combined wearable and cycle data.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-shield.png",
    iconBg: "#EDFEF1",
    title: "Private sync",
    body: "Vyla accesses only the wearable data you authorise. It's never sold to advertisers or third parties. You can disconnect your device or delete your data at any time.",
  },
];

const faqItems = [
  {
    q: "What wearables does Vyla support?",
    a: "Vyla currently integrates with Oura Ring (Generation 3 and later). Support for additional wearables may be added — check the Vyla app for the latest device compatibility.",
  },
  {
    q: "What health data does Vyla pull from my wearable?",
    a: "Vyla uses body temperature deviation, and may also include HRV, sleep score, and activity data from supported devices, displayed in the context of your logged cycle phases.",
  },
  {
    q: "Can wearable data predict my period?",
    a: "Wearable data enhances Vyla's cycle picture but does not replace the core prediction engine, which is based on your logged period history and cycle lengths. Temperature trends from wearables can help confirm ovulation timing and luteal phase length.",
  },
  {
    q: "Do I need a wearable to use Vyla?",
    a: "No. Vyla is fully functional without any wearable — you can manually log BBT, LH tests, symptoms, and period dates. Wearable integration is an optional Premium feature that adds richer passive data.",
  },
  {
    q: "Is wearable integration included in the free plan?",
    a: "No. Wearable integration is a Vyla Premium feature. The free plan includes full manual cycle tracking, period logging, and basic predictions.",
  },
];

export default function WearableCycleInsightsPage() {
  return (
    <SeoPageLayout
      breadcrumb="Wearable Cycle Insights"
      breadcrumbPath="/wearable-cycle-insights"
      pageTitle="Wearable Cycle Insights — Smartwatch & Ring Period Tracking"
      pageDescription="Use your wearable's health data to understand your menstrual cycle better. Vyla integrates with Oura Ring to layer temperature and wellness trends on top of your cycle tracking."
      label="Wearable wellness & cycle"
      heading={
        <>
          Your wearable data,<br />
          <span className="text-[#FF7A33]">in cycle context.</span>
        </>
      }
      subheading="Vyla connects your wearable's temperature, HRV, and sleep data to your menstrual cycle — so every health signal has the context it needs to make sense."
      features={features}
      faqItems={faqItems}
      faqTitle="Wearable cycle tracking — questions"
      faqSubtitle="How Vyla uses wearable data to deepen your understanding of cycle-related wellness patterns."
    />
  );
}
