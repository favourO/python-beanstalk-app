import OperationalPage from "@/components/OperationalPage";

export default function HealthDataPage() {
  return (
    <OperationalPage
      title="Health Data"
      subtitle="Govern sensitive cycle, symptom, prediction, and wearable information without exposing more data than support needs."
      sections={[
        { title: "What admins should review", items: [
          "Use the user detail page for account status, onboarding state, cycle-record counts, daily-log counts, AI-thread counts, wearable type, and subscription state.",
          "Use Predictions to review generated cycle phase snapshots, confidence, warning flags, model versions, and source metadata.",
          "Use Wearables to confirm connection type, latest sync time, and metric volume when investigating sync issues.",
          "Avoid exposing raw symptom notes or intimate health entries in general support workflows unless a verified data request requires it.",
        ] },
        { title: "Controls still needed", items: [
          "Add a dedicated subject-access export action with audit logging before exposing downloadable health data.",
          "Add a deletion workflow that separates account suspension from irreversible health-data erasure.",
          "Add role-based permissions so support staff can triage accounts without reading sensitive health details.",
          "Add consent-state visibility for AI, wearable import, notifications, analytics, and email communication.",
        ] },
      ]}
      links={[
        { label: "Users", href: "/users", note: "Open profile counts, subscription state, and account controls." },
        { label: "Predictions", href: "/predictions", note: "Review generated cycle intelligence metadata." },
        { label: "Wearables", href: "/wearables", note: "Check device sync state and metric counts." },
      ]}
    />
  );
}
