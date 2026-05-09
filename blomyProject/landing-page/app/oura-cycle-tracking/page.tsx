import type { Metadata } from "next";
import SeoPageLayout from "@/components/SeoPageLayout";
import { buildMetadata } from "@/lib/seo";

export const metadata: Metadata = buildMetadata({
  title: "Oura Ring Cycle Tracking — Period & Ovulation Insights with Oura",
  description:
    "Connect your Oura Ring to Vyla for cycle-phase-aware temperature trends, heart rate variability, and wellness insights alongside your period and ovulation tracking.",
  keywords: [
    "Oura ring cycle tracking",
    "Oura period tracking",
    "Oura ring ovulation",
    "Oura ring women's health",
    "Oura ring temperature cycle",
    "wearable period tracker",
    "Oura ring BBT",
    "Oura cycle insights",
  ],
  path: "/oura-cycle-tracking",
});

const features = [
  {
    icon: "https://vyla.health/assets/icons/icon-radar.png",
    iconBg: "#E6FDF9",
    title: "Oura temperature trends",
    body: "Vyla pulls continuous overnight temperature data from your Oura Ring to reveal temperature patterns across your cycle phases — without manual thermometer readings each morning.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-chart.png",
    iconBg: "#F0F0FF",
    title: "Cycle-phase context",
    body: "See your Oura Ring's temperature, HRV, sleep, and activity data in the context of your logged cycle phases — menstrual, follicular, ovulatory, and luteal.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-sound.png",
    iconBg: "#FFF6DD",
    title: "Ovulation pattern awareness",
    body: "Oura's temperature sensor can detect the subtle rise that often follows ovulation, complementing your LH test and cervical mucus logs in Vyla.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-note.png",
    iconBg: "#FFF0F8",
    title: "Combined log view",
    body: "See your Oura data alongside manually logged symptoms, mood, energy, and period dates — all on the same Vyla timeline.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-shield.png",
    iconBg: "#EDFEF1",
    title: "Private wearable sync",
    body: "Vyla only accesses the Oura data you explicitly connect. Your cycle and health data is never shared with advertisers.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-ai.png",
    iconBg: "#FFF0F8",
    title: "AI insights from your data",
    body: "Ask Vyla AI about patterns in your combined Oura and cycle data — get plain-language explanations without medical jargon.",
  },
];

const faqItems = [
  {
    q: "Does Vyla integrate with Oura Ring?",
    a: "Yes. Vyla Premium integrates with Oura Ring to pull in overnight temperature trends and wellness data, which are displayed alongside your logged period dates, symptoms, and cycle predictions.",
  },
  {
    q: "What Oura Ring data does Vyla use?",
    a: "Vyla uses Oura's body temperature deviation data to identify temperature patterns across your cycle. HRV, sleep, and activity data may also be viewable in the combined timeline view.",
  },
  {
    q: "Can Oura Ring detect ovulation?",
    a: "Oura Ring measures continuous skin temperature, which can reflect the small rise in body temperature that typically follows ovulation. However, temperature alone is not a definitive indicator of ovulation — Vyla combines it with your other logged signals for a fuller picture.",
  },
  {
    q: "Do I need an Oura Ring to use Vyla?",
    a: "No. Vyla works fully without any wearable. Oura Ring integration is an optional feature on Vyla Premium that enhances the temperature and wellness data available to you.",
  },
  {
    q: "Is Oura Ring integration available on the free plan?",
    a: "Oura Ring integration is a Vyla Premium feature. The free plan includes manual logging, period tracking, basic predictions, and reminders.",
  },
  {
    q: "Which Oura Ring models work with Vyla?",
    a: "Vyla is designed to work with Oura Ring Generation 3 and later. Check the Vyla app for the most up-to-date device compatibility information.",
  },
];

export default function OuraCycleTrackingPage() {
  return (
    <SeoPageLayout
      breadcrumb="Oura Cycle Tracking"
      breadcrumbPath="/oura-cycle-tracking"
      pageTitle="Oura Ring Cycle Tracking — Period & Ovulation Insights with Oura"
      pageDescription="Connect your Oura Ring to Vyla for cycle-phase-aware temperature trends, heart rate variability, and wellness insights alongside your period and ovulation tracking."
      label="Wearable cycle integration"
      heading={
        <>
          Oura Ring meets<br />
          <span className="text-[#FF7A33]">cycle tracking.</span>
        </>
      }
      subheading="Connect your Oura Ring to Vyla and see your continuous temperature trends, sleep, and wellness data in the context of your cycle phases — all in one private app."
      features={features}
      faqItems={faqItems}
      faqTitle="Oura Ring cycle tracking — questions"
      faqSubtitle="How Vyla works with Oura Ring to give you richer cycle and wellness insights."
    />
  );
}
