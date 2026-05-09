import type { Metadata } from "next";
import SeoPageLayout from "@/components/SeoPageLayout";
import { buildMetadata } from "@/lib/seo";

export const metadata: Metadata = buildMetadata({
  title: "Ovulation Tracking App — Fertile Window & Cycle Insights",
  description:
    "Track ovulation with Vyla — log BBT temperature, LH tests, and cervical mucus to understand your fertile window. Private, AI-powered ovulation tracking for iPhone and Android.",
  keywords: [
    "ovulation tracking",
    "ovulation tracker app",
    "fertile window tracker",
    "LH test tracker",
    "cervical mucus tracking",
    "ovulation calculator",
    "ovulation symptoms",
    "women's health app",
  ],
  path: "/ovulation-tracking",
});

const features = [
  {
    icon: "https://vyla.health/assets/icons/icon-chart.png",
    iconBg: "#F0F0FF",
    title: "Fertile window estimates",
    body: "Vyla estimates your fertile window and likely ovulation day based on your logged cycle history, so you know when to pay closer attention each month.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-note.png",
    iconBg: "#FFF0F8",
    title: "LH test logging",
    body: "Record your LH (luteinising hormone) test results daily to track the surge that typically occurs 24–48 hours before ovulation.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-sound.png",
    iconBg: "#FFF6DD",
    title: "BBT temperature trends",
    body: "Log your basal body temperature each morning. Vyla charts your BBT alongside cycle phases so you can see the temperature shift that follows ovulation.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-people.png",
    iconBg: "#FFF0F8",
    title: "Cervical mucus tracking",
    body: "Track changes in cervical mucus texture and quantity. Combined with BBT and LH data, this gives a fuller picture of your ovulatory patterns.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-shield.png",
    iconBg: "#EDFEF1",
    title: "Private data controls",
    body: "Your ovulation and cycle data belongs to you. Vyla never shares it with advertisers. Export or delete your data whenever you choose.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-radar.png",
    iconBg: "#E6FDF9",
    title: "Multi-cycle pattern view",
    body: "Review your ovulation timing across multiple cycles to understand your natural rhythm and notice any shifts over time.",
  },
];

const faqItems = [
  {
    q: "What is ovulation tracking?",
    a: "Ovulation tracking involves monitoring biological signals — such as basal body temperature, LH hormone levels, and cervical mucus — to identify when ovulation is likely to occur in your cycle, and understand your fertile window.",
  },
  {
    q: "How does Vyla track ovulation?",
    a: "Vyla combines your logged cycle history, BBT temperature readings, LH test results, and cervical mucus observations to estimate your fertile window and likely ovulation timing each cycle.",
  },
  {
    q: "What is a fertile window?",
    a: "The fertile window is the days in your cycle when conception is biologically possible — typically the 5 days before ovulation and the day of ovulation itself, as sperm can survive for several days. Vyla estimates this window based on your individual cycle patterns.",
  },
  {
    q: "How do I log LH tests in Vyla?",
    a: "In the Vyla daily log, you can record your LH test result as negative, low, high, or peak surge. Over several days around your expected fertile window, this helps identify the LH surge that typically precedes ovulation.",
  },
  {
    q: "Does Vyla provide fertility advice?",
    a: "No. Vyla is a wellness app that helps you understand your body's patterns. It does not provide fertility treatment guidance, diagnose conditions, or replace advice from a reproductive healthcare professional.",
  },
  {
    q: "Is ovulation tracking free in Vyla?",
    a: "Basic fertile window estimates and LH test logging are available on the free plan. BBT trend analysis and deeper ovulation insights are available on Vyla Premium.",
  },
];

export default function OvulationTrackingPage() {
  return (
    <SeoPageLayout
      breadcrumb="Ovulation Tracking"
      breadcrumbPath="/ovulation-tracking"
      pageTitle="Ovulation Tracking App — Fertile Window & Cycle Insights"
      pageDescription="Track ovulation with Vyla — log BBT temperature, LH tests, and cervical mucus to understand your fertile window. Private, AI-powered ovulation tracking for iPhone and Android."
      label="Ovulation & fertile window"
      heading={
        <>
          Ovulation tracking<br />
          <span className="text-[#FF7A33]">that goes beyond the calendar.</span>
        </>
      }
      subheading="Log BBT temperature, LH test results, and cervical mucus. Vyla combines your signals to estimate your fertile window and help you understand your ovulatory patterns."
      features={features}
      faqItems={faqItems}
      faqTitle="Ovulation tracking — common questions"
      faqSubtitle="How Vyla helps you understand your fertile window and ovulatory patterns."
    />
  );
}
