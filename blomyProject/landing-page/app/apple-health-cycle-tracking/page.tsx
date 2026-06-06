import type { Metadata } from "next";
import SeoPageLayout from "@/components/SeoPageLayout";
import { buildMetadata } from "@/lib/seo";

export const metadata: Metadata = buildMetadata({
  title: "Apple Health Cycle Tracking — Apple Watch & iPhone Period Tracker",
  description:
    "Connect Vyla to Apple Health and Apple Watch Series 8+ for temperature trends, heart rate, and sleep data mapped to your menstrual cycle phases. Private cycle tracking powered by HealthKit.",
  keywords: [
    "Apple Health cycle tracking",
    "Apple Watch period tracker",
    "Apple Watch Series 8 cycle",
    "HealthKit cycle tracking",
    "Apple Watch ovulation tracking",
    "Apple Watch temperature cycle",
    "iPhone period tracker",
    "Apple Health menstrual cycle",
    "Apple Watch women's health",
    "Apple Watch Series 9 cycle",
  ],
  path: "/apple-health-cycle-tracking",
});

const features = [
  {
    icon: "https://vyla.health/assets/icons/icon-radar.png",
    iconBg: "#E6FDF9",
    title: "Wrist temperature from Apple Watch",
    body: "Apple Watch Series 8 and above measure wrist skin temperature during sleep using the new temperature sensor. Vyla layers this data over your cycle timeline to reveal the post-ovulation temperature rise and other phase-based patterns.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-chart.png",
    iconBg: "#F0F0FF",
    title: "Heart rate and HRV by phase",
    body: "See how your resting heart rate and heart rate variability from Apple Watch shift across your menstrual, follicular, ovulatory, and luteal phases — all displayed in your Vyla cycle view.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-sound.png",
    iconBg: "#FFF6DD",
    title: "Sleep data in cycle context",
    body: "Apple Watch sleep stages and sleep duration data from Apple Health are mapped to your cycle phases in Vyla — helping you see whether your sleep quality follows a hormonal pattern across your cycle.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-note.png",
    iconBg: "#FFF0F8",
    title: "HealthKit unified timeline",
    body: "Vyla reads from Apple Health via HealthKit so your Apple Watch data sits alongside your manually logged symptoms, period dates, BBT, and LH tests in one continuous timeline.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-ai.png",
    iconBg: "#FFF0F8",
    title: "Ask Vyla AI about your data",
    body: "Ask Vyla AI what your Apple Health temperature or heart rate data means in the context of your current cycle phase. Get plain-language answers without having to interpret raw health graphs.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-shield.png",
    iconBg: "#EDFEF1",
    title: "Private HealthKit access",
    body: "Vyla requests only the Apple Health data types you explicitly approve. Your data never leaves your control — it is never sold to advertisers or third parties. Revoke access at any time in iPhone Settings → Privacy → Health.",
  },
];

const faqItems = [
  {
    q: "Which Apple Watch models work with Vyla?",
    a: "Vyla works with all Apple Watch models via Apple Health for heart rate, HRV, sleep, and activity data. Apple Watch Series 8, Series 9, Ultra, and Ultra 2 add wrist skin temperature data, which is the most valuable signal for cycle-phase temperature tracking.",
  },
  {
    q: "How does Vyla connect to Apple Health?",
    a: "Vyla connects to Apple Health via HealthKit on iPhone. When you enable wearable sync in the Vyla app, you will be prompted to allow access to specific health data types. You can grant or revoke access at any time in iPhone Settings → Privacy & Security → Health → Vyla.",
  },
  {
    q: "Can Apple Watch detect ovulation?",
    a: "Apple Watch Series 8+ tracks wrist skin temperature during sleep, which can reflect the small overnight rise that typically follows ovulation. It is not a definitive ovulation indicator on its own — Vyla combines this signal with your logged BBT readings, LH test results, and cervical mucus observations for a fuller picture.",
  },
  {
    q: "Does Apple Watch Series 9 have a temperature sensor?",
    a: "Yes. Apple Watch Series 9 includes the same wrist temperature sensor as Series 8, measuring overnight skin temperature variation. Vyla uses this data to reveal temperature patterns across your cycle phases.",
  },
  {
    q: "What Apple Health data types does Vyla read?",
    a: "Vyla can read wrist skin temperature (Series 8+), resting heart rate, heart rate variability, sleep analysis, and step count from Apple Health. Each data type is requested individually — you choose what to share.",
  },
  {
    q: "Do I need an Apple Watch to use Vyla on iPhone?",
    a: "No. Vyla works fully on iPhone without any wearable. You can manually log BBT, LH tests, symptoms, and period dates. Apple Health integration is an optional Premium feature that adds passive health data from Apple Watch.",
  },
  {
    q: "What is the Vyla Band?",
    a: "The Vyla Band is Vyla's own dedicated wearable built for women's cycle tracking. It tracks temperature, heart rate, HRV, sleep, and activity 24/7 and syncs directly to Vyla — no third-party app required. Add it to your first annual Premium upgrade for just £25.",
  },
];

export default function AppleHealthCycleTrackingPage() {
  return (
    <SeoPageLayout
      breadcrumb="Apple Health Cycle Tracking"
      breadcrumbPath="/apple-health-cycle-tracking"
      pageTitle="Apple Health Cycle Tracking — Apple Watch & iPhone Period Tracker"
      pageDescription="Connect Vyla to Apple Health and Apple Watch Series 8+ for temperature trends, heart rate, and sleep data mapped to your menstrual cycle phases."
      label="Apple Health & cycle"
      heading={
        <>
          Apple Watch meets<br />
          <span className="text-[#FF7A33]">cycle tracking.</span>
        </>
      }
      subheading="Connect Vyla to Apple Health and see your Apple Watch temperature, heart rate, and sleep data in the context of your cycle phases — all in one private app."
      features={features}
      faqItems={faqItems}
      faqTitle="Apple Health cycle tracking — questions"
      faqSubtitle="How Vyla uses Apple Watch and HealthKit data to give you richer, phase-aware cycle insights."
    />
  );
}
