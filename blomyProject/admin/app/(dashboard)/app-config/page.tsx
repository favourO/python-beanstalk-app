import OperationalPage from "@/components/OperationalPage";

export default function AppConfigPage() {
  return (
    <OperationalPage
      title="App Config"
      subtitle="Track the operational settings that control the Vyla app, admin portal, payments, notifications, AI, and deployment environments."
      sections={[
        { title: "Configuration areas", items: [
          "API base URLs, admin URLs, and release environment names should be visible per deployment so support knows which system they are using.",
          "Subscription product IDs, provider keys, and price labels must match the mobile app and store configuration before release.",
          "Notification categories, reminder timing, and delivery channels should be reviewed before enabling campaigns or nudges.",
          "AI provider, model version, safety prompt version, and daily limits should be tracked with every production change.",
        ] },
        { title: "Controls still needed", items: [
          "Add a read-only config endpoint for current runtime settings that are safe for admins to see.",
          "Add feature flag visibility for AI, wearables, referrals, notifications, and Premium entitlements.",
          "Add an environment banner that distinguishes local, stage, and production in the admin UI.",
          "Add admin-only mutation endpoints only after audit events and role permissions are complete.",
        ] },
      ]}
      links={[
        { label: "Audit Log", href: "/audit-log", note: "Review changes and sensitive admin activity." },
        { label: "Subscriptions", href: "/subscriptions", note: "Check active plan and provider state." },
        { label: "Notifications", href: "/notifications", note: "Inspect notification status and delivery behavior." },
      ]}
    />
  );
}
