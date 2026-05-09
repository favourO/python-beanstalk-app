import type { Metadata } from "next";
import SeoPageLayout from "@/components/SeoPageLayout";
import { buildMetadata } from "@/lib/seo";

export const metadata: Metadata = buildMetadata({
  title: "BBT Tracking App — Basal Body Temperature Chart & Cycle Insights",
  description:
    "Log and chart your basal body temperature (BBT) with Vyla. Understand temperature shifts around ovulation, track cycle phases, and spot patterns — private and free on iPhone and Android.",
  keywords: [
    "BBT tracking",
    "basal body temperature tracking",
    "BBT chart app",
    "BBT thermometer app",
    "temperature charting cycle",
    "BBT ovulation tracking",
    "basal temperature app",
    "fertility temperature tracking",
  ],
  path: "/bbt-tracking",
});

const features = [
  {
    icon: "https://vyla.health/assets/icons/icon-chart.png",
    iconBg: "#F0F0FF",
    title: "Daily BBT log",
    body: "Record your waking temperature each morning before getting up. Vyla charts your readings alongside cycle phases to reveal temperature patterns.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-radar.png",
    iconBg: "#E6FDF9",
    title: "Thermal shift detection",
    body: "Vyla identifies the sustained temperature rise that typically occurs after ovulation — the post-ovulatory thermal shift — in your logged BBT data.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-sound.png",
    iconBg: "#FFF6DD",
    title: "Wearable temperature integration",
    body: "Connect an Oura Ring on Premium to supplement manual BBT logs with continuous overnight temperature data for a fuller cycle picture.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-note.png",
    iconBg: "#FFF0F8",
    title: "Multi-cycle BBT chart",
    body: "View your temperature history across multiple cycles to spot recurring patterns, unusual readings, and how your BBT shifts with lifestyle changes.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-shield.png",
    iconBg: "#EDFEF1",
    title: "Private temperature data",
    body: "Your BBT and cycle data is never shared with advertisers or third parties. Export or delete your records at any time.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-people.png",
    iconBg: "#FFF0F8",
    title: "Combined signal view",
    body: "Overlay your BBT chart with LH test results and cervical mucus notes to see a complete picture of your cycle's hormonal and temperature patterns.",
  },
];

const faqItems = [
  {
    q: "What is basal body temperature (BBT)?",
    a: "Basal body temperature is your body's lowest resting temperature, measured first thing in the morning before any activity. BBT typically rises slightly — by 0.2–0.5°C — after ovulation due to increased progesterone, and stays elevated until your next period.",
  },
  {
    q: "How do I measure BBT accurately?",
    a: "Use a basal thermometer (which measures to two decimal places) and take your temperature at the same time each morning before getting out of bed. Even minor disturbances like talking or moving can affect the reading.",
  },
  {
    q: "How does Vyla display my BBT data?",
    a: "Vyla charts your logged BBT readings on a timeline alongside your cycle phases, period dates, and other logged symptoms. On Premium, you can also view overlaid LH test results and identify thermal shift patterns.",
  },
  {
    q: "Can I track BBT with a wearable in Vyla?",
    a: "Yes. Vyla Premium integrates with Oura Ring to pull in continuous overnight temperature trends, which can complement your manual morning BBT logs.",
  },
  {
    q: "What is a BBT thermal shift?",
    a: "A thermal shift is the sustained rise in basal body temperature — typically at least 0.2°C above your pre-ovulatory baseline — that is understood to occur after ovulation. Identifying this shift in your BBT chart can help you confirm that ovulation has likely taken place.",
  },
  {
    q: "Is BBT tracking free in Vyla?",
    a: "Manual BBT logging and basic charting are free. Deeper temperature analysis, wearable temperature integration, and multi-cycle BBT pattern views are available on Vyla Premium.",
  },
];

export default function BBTTrackingPage() {
  return (
    <SeoPageLayout
      breadcrumb="BBT Tracking"
      breadcrumbPath="/bbt-tracking"
      label="Basal body temperature"
      heading={
        <>
          BBT tracking that shows<br />
          <span className="text-[#FF7A33]">your full cycle picture.</span>
        </>
      }
      subheading="Log your morning temperature, chart thermal shifts, and understand how your basal body temperature changes throughout your cycle — all in one private app."
      features={features}
      faqItems={faqItems}
      faqTitle="BBT tracking — common questions"
      faqSubtitle="How Vyla helps you understand basal body temperature and what it tells you about your cycle."
    />
  );
}
