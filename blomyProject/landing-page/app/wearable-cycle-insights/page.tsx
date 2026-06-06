import type { Metadata } from "next";
import SeoPageLayout from "@/components/SeoPageLayout";
import { buildMetadata } from "@/lib/seo";

export const metadata: Metadata = buildMetadata({
  title: "Wearable Cycle Insights — Apple Watch & Fitbit Period Tracking",
  description:
    "Connect your Apple Watch Series 8+ or Fitbit to Vyla for cycle-phase-aware temperature trends, heart rate, and wellness insights alongside your period and ovulation tracking.",
  keywords: [
    "Apple Watch cycle tracking",
    "Fitbit cycle tracking",
    "Apple Watch period tracker",
    "Fitbit period tracking",
    "Apple Watch Series 8 cycle",
    "wearable period tracker",
    "wearable cycle insights",
    "smartwatch menstrual tracking",
    "Apple Watch ovulation",
    "Fitbit women's health",
  ],
  path: "/wearable-cycle-insights",
});

const features = [
  {
    icon: "https://vyla.health/assets/icons/icon-ai.png",
    iconBg: "#FFF0F8",
    title: "Vyla Band — built for cycle tracking",
    body: "The Vyla Band is Vyla's own dedicated wearable, available for just £25 with your first annual Premium upgrade. Designed specifically for women's cycle tracking, it streams continuous temperature, heart rate, sleep, and activity data directly into Vyla — no third-party app required.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-radar.png",
    iconBg: "#E6FDF9",
    title: "Temperature trends from your wrist",
    body: "Apple Watch Series 8 and above track wrist skin temperature during sleep. Vyla layers this data over your cycle timeline to reveal temperature patterns across your menstrual, follicular, ovulatory, and luteal phases.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-chart.png",
    iconBg: "#F0F0FF",
    title: "Cycle-phase wellness view",
    body: "See how your heart rate, resting heart rate, sleep quality, and activity levels from your Apple Watch or Fitbit track across each phase of your cycle — all in one place.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-sound.png",
    iconBg: "#FFF6DD",
    title: "Ovulation temperature signal",
    body: "Apple Watch Series 8+ can detect the subtle overnight temperature rise that typically follows ovulation, giving you a passive signal to complement your BBT and LH test logs in Vyla.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-note.png",
    iconBg: "#FFF0F8",
    title: "Unified data timeline",
    body: "Your wearable's readings sit alongside your logged symptoms, period dates, mood, and energy in a single Vyla timeline — no switching between the Health app or Fitbit app.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-ai.png",
    iconBg: "#FFF0F8",
    title: "AI-powered pattern questions",
    body: "Ask Vyla AI why your sleep or heart rate dips at certain points in your cycle. Get clear, jargon-free explanations based on your combined wearable and cycle data.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-shield.png",
    iconBg: "#EDFEF1",
    title: "Private sync",
    body: "Vyla accesses only the wearable data you authorise via Apple Health or Fitbit. Your data is never sold to advertisers or third parties. Disconnect your device or delete your data at any time.",
  },
];

const faqItems = [
  {
    q: "What is the Vyla Band?",
    a: "The Vyla Band is Vyla's own dedicated wearable built for women's cycle tracking. It tracks temperature, heart rate, HRV, sleep, and activity 24/7 and syncs directly to Vyla — no third-party app needed. Add it to your first annual Premium upgrade for just £25.",
  },
  {
    q: "What wearables does Vyla support?",
    a: "Vyla integrates with Apple Watch Series 8 and above (via Apple Health) and Fitbit devices. These wearables provide temperature, heart rate, sleep, and activity data that Vyla layers over your cycle phases.",
  },
  {
    q: "Which Apple Watch models work with Vyla?",
    a: "Apple Watch Series 8 and above are required for wrist skin temperature tracking, which is the key data Vyla uses for cycle-phase insights. Earlier models still sync heart rate, sleep, and activity data via Apple Health.",
  },
  {
    q: "Does Vyla work with Fitbit?",
    a: "Yes. Vyla connects to Fitbit devices to pull heart rate, sleep, and activity data. This data is displayed in the context of your logged cycle phases to show how your body responds across each phase.",
  },
  {
    q: "Can Apple Watch detect ovulation?",
    a: "Apple Watch Series 8+ measures wrist skin temperature during sleep, which can reflect the small overnight rise that typically follows ovulation. It is not a definitive indicator of ovulation — Vyla combines it with your logged BBT, LH tests, and symptoms for a fuller picture.",
  },
  {
    q: "Do I need a wearable to use Vyla?",
    a: "No. Vyla works fully without any wearable. You can manually log BBT, LH tests, symptoms, and period dates. Wearable integration is an optional Premium feature that adds richer passive data.",
  },
  {
    q: "Is wearable integration included in the free plan?",
    a: "Wearable integration is a Vyla Premium feature. The free plan includes full manual cycle tracking, period logging, and basic predictions.",
  },
];

export default function WearableCycleInsightsPage() {
  return (
    <SeoPageLayout
      breadcrumb="Wearable Cycle Insights"
      breadcrumbPath="/wearable-cycle-insights"
      pageTitle="Wearable Cycle Insights — Apple Watch & Fitbit Period Tracking"
      pageDescription="Connect your Apple Watch Series 8+ or Fitbit to Vyla for cycle-phase-aware temperature trends, heart rate, and wellness insights alongside your period and ovulation tracking."
      label="Wearable wellness & cycle"
      heading={
        <>
          Your wearable data,<br />
          <span className="text-[#FF7A33]">in cycle context.</span>
        </>
      }
      subheading="Vyla connects Apple Watch Series 8+ and Fitbit data to your menstrual cycle — so every health signal has the context it needs to make sense."
      features={features}
      faqItems={faqItems}
      faqTitle="Apple Watch & Fitbit cycle tracking — questions"
      faqSubtitle="How Vyla uses wearable data from Apple Watch and Fitbit to deepen your understanding of cycle wellness patterns."
    />
  );
}
