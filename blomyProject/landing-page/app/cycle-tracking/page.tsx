import type { Metadata } from "next";
import SeoPageLayout from "@/components/SeoPageLayout";
import { buildMetadata } from "@/lib/seo";

export const metadata: Metadata = buildMetadata({
  title: "Cycle Tracking App — Period & Menstrual Cycle Tracker",
  description:
    "Vyla is a free cycle tracking app for iPhone and Android. Log your period, track symptoms, predict fertile windows, and understand your menstrual cycle with AI-powered insights.",
  keywords: [
    "cycle tracking app",
    "period tracker",
    "menstrual cycle tracker",
    "cycle tracking",
    "period tracking",
    "menstrual health",
    "women's cycle app",
    "free period tracker",
  ],
  path: "/cycle-tracking",
});

const features = [
  {
    icon: "https://vyla.health/assets/icons/icon-sound.png",
    iconBg: "#FFF6DD",
    title: "Accurate period predictions",
    body: "Log your period dates and cycle lengths. Vyla estimates upcoming periods and fertile windows with predictions that improve as your history grows.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-note.png",
    iconBg: "#FFF0F8",
    title: "Daily symptom logging",
    body: "Record flow, cramps, mood, energy, sleep, cervical mucus, and over 80 other symptoms in seconds. Spot patterns across your cycle.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-shield.png",
    iconBg: "#EDFEF1",
    title: "Private by design",
    body: "Your cycle data is never sold to advertisers. Use anonymous mode, or export and delete your data whenever you choose.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-chart.png",
    iconBg: "#F0F0FF",
    title: "Cycle length insights",
    body: "View your average cycle length, variation, and how factors like stress, travel, and sleep affect your timing across multiple cycles.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-mobile.png",
    iconBg: "#FFF6DD",
    title: "Gentle reminders",
    body: "Get calm, timely reminders to log your period, note symptoms, or check your fertile window — always on your terms.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-people.png",
    iconBg: "#FFF0F8",
    title: "AI-powered cycle chat",
    body: "Ask Vyla AI questions about your logged patterns in plain language. Understand possible links between your symptoms and cycle phases.",
  },
];

const faqItems = [
  {
    q: "What is cycle tracking?",
    a: "Cycle tracking means recording and monitoring your menstrual cycle — including period dates, cycle length, symptoms, mood, and other wellness signals — to understand your body's patterns over time.",
  },
  {
    q: "How accurate are Vyla's period predictions?",
    a: "Vyla's predictions are based on the cycle data you log. They become more accurate as you add more cycles. The app also accounts for real-life variation — cycles can shift with stress, travel, illness, or lifestyle changes.",
  },
  {
    q: "What can I track with the free version?",
    a: "The free version includes period and cycle tracking, daily symptom and mood logging, reminders, basic cycle insights, and data export and delete controls.",
  },
  {
    q: "Does Vyla work for irregular cycles?",
    a: "Yes. Vyla is designed for real cycles — not just textbook 28-day ones. It tracks your individual history and adjusts predictions based on your actual logged patterns, even if they vary significantly.",
  },
  {
    q: "Is Vyla available for both iPhone and Android?",
    a: "Yes. Vyla is free to download on the App Store (iPhone/iPad) and Google Play Store (Android).",
  },
];

export default function CycleTrackingPage() {
  return (
    <SeoPageLayout
      breadcrumb="Cycle Tracking"
      breadcrumbPath="/cycle-tracking"
      label="Period & cycle tracking"
      heading={
        <>
          The cycle tracking app<br />
          <span className="text-[#FF7A33]">that understands you.</span>
        </>
      }
      subheading="Track your period, symptoms, moods, fertile window, and daily patterns in one private, easy-to-use app. Vyla's predictions improve with every cycle you log."
      features={features}
      faqItems={faqItems}
      faqTitle="Cycle tracking — common questions"
      faqSubtitle="Everything you need to know about tracking your period and menstrual cycle with Vyla."
    />
  );
}
