import type { Metadata } from "next";
import SeoPageLayout from "@/components/SeoPageLayout";
import { buildMetadata } from "@/lib/seo";

export const metadata: Metadata = buildMetadata({
  title: "Fitbit Cycle Tracking — Period & Ovulation Insights with Fitbit",
  description:
    "Connect your Fitbit to Vyla to layer heart rate, sleep, and activity data over your menstrual cycle phases. Understand how your body changes throughout your cycle with Fitbit and Vyla.",
  keywords: [
    "Fitbit cycle tracking",
    "Fitbit period tracker",
    "Fitbit menstrual cycle",
    "Fitbit women's health",
    "Fitbit ovulation tracking",
    "Fitbit heart rate cycle",
    "Fitbit sleep cycle",
    "Fitbit Sense cycle tracking",
    "Fitbit Versa period tracking",
    "wearable cycle tracking",
  ],
  path: "/fitbit-cycle-tracking",
});

const features = [
  {
    icon: "https://vyla.health/assets/icons/icon-radar.png",
    iconBg: "#E6FDF9",
    title: "Heart rate across cycle phases",
    body: "Fitbit tracks your resting heart rate continuously. Vyla maps this data across your cycle phases — many women notice their resting heart rate shifts slightly higher in the luteal phase after ovulation.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-chart.png",
    iconBg: "#F0F0FF",
    title: "Sleep quality by cycle phase",
    body: "See how your Fitbit sleep scores and sleep stages — light, deep, and REM — change across your menstrual, follicular, ovulatory, and luteal phases, all in one Vyla timeline.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-sound.png",
    iconBg: "#FFF6DD",
    title: "Activity and energy patterns",
    body: "Fitbit step counts and active minutes sit alongside your logged cycle phases so you can see whether your energy and motivation for movement follow a pattern across your cycle.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-note.png",
    iconBg: "#FFF0F8",
    title: "Unified symptom timeline",
    body: "Your Fitbit data sits alongside manually logged symptoms, mood, period dates, and BBT in a single Vyla timeline — no need to switch between the Fitbit app and your cycle tracker.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-ai.png",
    iconBg: "#FFF0F8",
    title: "AI-powered cycle questions",
    body: "Ask Vyla AI why your sleep or resting heart rate changes at certain points in your cycle. Get plain-language answers based on your combined Fitbit and cycle data.",
  },
  {
    icon: "https://vyla.health/assets/icons/icon-shield.png",
    iconBg: "#EDFEF1",
    title: "Private Fitbit sync",
    body: "Vyla only accesses the Fitbit data you authorise. Your health data is never sold or shared with advertisers. Disconnect your Fitbit or delete all data at any time from your profile.",
  },
];

const faqItems = [
  {
    q: "Which Fitbit models work with Vyla?",
    a: "Vyla connects to Fitbit devices that support the Fitbit API, including Fitbit Sense, Sense 2, Versa 3, Versa 4, Charge 5, Charge 6, and Luxe. Check the Vyla app for the latest device compatibility list.",
  },
  {
    q: "What Fitbit data does Vyla use?",
    a: "Vyla uses resting heart rate, heart rate variability (HRV), sleep score, sleep stages, and daily activity data from your Fitbit. This data is displayed in the context of your logged cycle phases.",
  },
  {
    q: "Can Fitbit detect ovulation?",
    a: "Fitbit does not measure skin temperature on most models, so it cannot detect the post-ovulation temperature rise directly. However, patterns in resting heart rate and HRV data often shift around ovulation, and Vyla displays these signals alongside your logged LH tests and BBT for a combined view.",
  },
  {
    q: "Does Fitbit Sense 2 support temperature tracking in Vyla?",
    a: "Fitbit Sense 2 includes a skin temperature sensor. Vyla can use this data where available via the Fitbit API to enhance your cycle phase picture alongside heart rate and sleep data.",
  },
  {
    q: "Do I need a Fitbit to use Vyla?",
    a: "No. Vyla works fully without any wearable. You can manually log BBT, LH tests, symptoms, and period dates. Fitbit integration is an optional Premium feature that adds richer passive health data.",
  },
  {
    q: "Is Fitbit integration free in Vyla?",
    a: "Fitbit integration is a Vyla Premium feature. The free plan includes full manual cycle tracking, period logging, symptom logging, and basic predictions.",
  },
  {
    q: "What is the Vyla Band?",
    a: "The Vyla Band is Vyla's own dedicated wearable built for women's cycle tracking. It tracks temperature, heart rate, HRV, sleep, and activity 24/7 and syncs directly to Vyla. Add it to your first annual Premium upgrade for just £25.",
  },
];

export default function FitbitCycleTrackingPage() {
  return (
    <SeoPageLayout
      breadcrumb="Fitbit Cycle Tracking"
      breadcrumbPath="/fitbit-cycle-tracking"
      pageTitle="Fitbit Cycle Tracking — Period & Ovulation Insights with Fitbit"
      pageDescription="Connect your Fitbit to Vyla to layer heart rate, sleep, and activity data over your menstrual cycle phases. Understand how your body changes throughout your cycle."
      label="Fitbit & cycle insights"
      heading={
        <>
          Fitbit meets<br />
          <span className="text-[#FF7A33]">cycle tracking.</span>
        </>
      }
      subheading="Connect your Fitbit to Vyla and see your heart rate, sleep, and activity data in the context of your cycle phases — all in one private app."
      features={features}
      faqItems={faqItems}
      faqTitle="Fitbit cycle tracking — questions"
      faqSubtitle="How Vyla works with Fitbit to give you richer cycle and wellness insights."
    />
  );
}
