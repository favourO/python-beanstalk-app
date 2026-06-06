import OperationalPage from "@/components/OperationalPage";

export default function ContentPage() {
  return (
    <OperationalPage
      title="Content"
      subtitle="Manage the words users see across onboarding, notifications, legal screens, AI disclaimers, and subscription prompts."
      sections={[
        { title: "Required content inventory", items: [
          "Landing page copy must describe Vyla as cycle tracking and wellbeing information, not a clinical, diagnostic, or treatment product.",
          "App Store and Play Store text should match the in-app subscription price and the actual Premium feature set.",
          "AI surfaces need a visible information-only disclaimer and should direct users to qualified professionals for medical decisions.",
          "Notification copy should be calm, configurable, and clear about whether it is a reminder, prediction, billing message, or support alert.",
        ] },
        { title: "Publishing process", items: [
          "Keep privacy policy, terms of use, cookie settings, landing page copy, and in-app legal links versioned together.",
          "Route pricing changes through subscription configuration, app copy, landing page copy, and store metadata in the same release window.",
          "Record meaningful content changes in the audit log or release notes so support can answer user questions accurately.",
          "Add an editable CMS endpoint later only after role permissions and approval flow are in place.",
        ] },
      ]}
      links={[
        { label: "Privacy & Compliance", href: "/privacy", note: "Review data protection obligations and policy controls." },
        { label: "Notifications", href: "/notifications", note: "Inspect delivered and scheduled user messages." },
        { label: "App Config", href: "/app-config", note: "Track environment-driven product settings." },
      ]}
    />
  );
}
