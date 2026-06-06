import { fulfillmentTone, labelStatus } from "./status";

export default function ShipmentStatusBadge({ status }: { status: string }) {
  const key = status.toLowerCase();
  const cls = fulfillmentTone[key] ?? "bg-gray-50 text-gray-600 border-gray-200";
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-md text-[11px] font-medium border ${cls}`}>
      {labelStatus(status)}
    </span>
  );
}
