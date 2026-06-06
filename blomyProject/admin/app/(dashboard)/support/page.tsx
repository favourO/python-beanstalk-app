import OperationalPage from "@/components/OperationalPage";

export default function SupportPage() {
  return (
    <OperationalPage
      title="Support"
      subtitle="A practical operating view for handling account, subscription, AI, wearable, and privacy support cases."
      sections={[
        { title: "Support workflow", items: [
          "Start in Users: search by email or user ID, confirm account mode, onboarding state, and whether the account is suspended or active.",
          "For payment issues, check Subscriptions, Billing, and Webhook Errors before asking the user to retry a purchase.",
          "For AI questions, check AI Threads for usage volume and thread timing, but do not present AI output as medical advice.",
          "For wearable sync issues, check Wearables for latest sync time, device type, and metric count before escalating to engineering.",
        ] },
        { title: "Escalation rules", items: [
          "Escalate any request for diagnosis, medication, urgent symptoms, pregnancy risk, fertility treatment, or abnormal bleeding to professional medical care language.",
          "Escalate privacy requests for export, correction, deletion, or objection to the data protection owner at DemyCorp Ltd.",
          "Do not manually grant Premium unless there is a documented billing, referral, support, or goodwill reason.",
          "Use Audit Log after sensitive actions so internal reviews can see who did what and when.",
        ] },
      ]}
      links={[
        { label: "Users", href: "/users", note: "Look up accounts and perform suspend/reactivate actions." },
        { label: "Billing", href: "/billing", note: "Review invoices and payment provider references." },
        { label: "Webhook Errors", href: "/webhook-errors", note: "Find payment-event processing failures." },
      ]}
    />
  );
}
