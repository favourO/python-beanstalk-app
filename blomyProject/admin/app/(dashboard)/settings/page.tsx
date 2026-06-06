import OperationalPage from "@/components/OperationalPage";

export default function SettingsPage() {
  return (
    <OperationalPage
      title="Settings"
      subtitle="Admin portal settings, operational ownership, environment notes, and access-management requirements."
      sections={[
        { title: "Current admin behavior", items: [
          "Admin authentication uses the Vyla backend admin login and stores the session token in browser session storage.",
          "The sidebar exposes account, health-data, prediction, wearable, subscription, billing, notification, AI, referral, support, audit, privacy, and configuration areas.",
          "Logout clears the admin session token and returns the user to the login screen.",
          "Stage admin is live at https://admin.stage.vyla.health and served by the vyla-stage-admin Lightsail container service.",
        ] },
        { title: "Settings still needed", items: [
          "Add admin profile details from the authenticated token or /me endpoint instead of the static Admin label.",
          "Add role and permission management for owner, operations, support, billing, and read-only reviewers.",
          "Add session expiry visibility, forced logout, and device/session management for admin accounts.",
          "Add production/stage environment banners and deploy metadata so operators can avoid working in the wrong environment.",
        ] },
      ]}
      links={[
        { label: "App Config", href: "/app-config", note: "Track product and environment configuration." },
        { label: "Audit Log", href: "/audit-log", note: "Review administrative actions." },
        { label: "Privacy & Compliance", href: "/privacy", note: "Coordinate legal and data-rights workflows." },
      ]}
    />
  );
}
