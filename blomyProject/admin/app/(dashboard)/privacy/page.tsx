import OperationalPage from "@/components/OperationalPage";

export default function PrivacyPage() {
  return (
    <OperationalPage
      title="Privacy & Compliance"
      subtitle="Coordinate data protection, user rights, sensitive health-data handling, and internal accountability for Vyla."
      sections={[
        { title: "Core obligations", items: [
          "Keep Vyla positioned as a wellbeing and cycle information app, not a clinical diagnosis or treatment service.",
          "Give users working routes to export, correct, delete, and question their data from support and in-app flows.",
          "Limit internal access to personal and health data to staff who need it for support, security, billing, or legal compliance.",
          "Maintain current privacy policy, terms, cookie notice, AI disclaimer, and processor list for every release.",
        ] },
        { title: "Admin checks", items: [
          "Use Audit Log to investigate sensitive access and account actions by actor, action prefix, and timestamp.",
          "Use Health Data to understand what data categories exist before responding to access or deletion requests.",
          "Use Billing and Subscriptions to separate financial record retention from account deletion requests.",
          "Document manual Premium grants, account suspensions, and support escalations with a clear reason.",
        ] },
      ]}
      links={[
        { label: "Audit Log", href: "/audit-log", note: "Trace admin activity and sensitive access." },
        { label: "Health Data", href: "/health-data", note: "Review data categories and access boundaries." },
        { label: "Content", href: "/content", note: "Keep legal and product copy aligned." },
      ]}
    />
  );
}
