import type { WearableTimelineEntry } from "@/lib/api";
import { formatDate } from "./status";

export default function OrderStatusTimeline({ entries }: { entries: WearableTimelineEntry[] }) {
  return (
    <div className="space-y-3">
      {entries.map(entry => {
        const done = Boolean(entry.completed_at);
        return (
          <div key={entry.status} className="flex gap-3">
            <span className={`mt-0.5 h-5 w-5 rounded-full border flex items-center justify-center text-[10px] ${
              done ? "bg-[#FF7A33] border-[#FF7A33] text-white" : "bg-gray-50 border-gray-200 text-gray-400"
            }`}>
              {done ? "✓" : ""}
            </span>
            <div className="min-w-0">
              <p className="text-[13px] font-semibold text-[#1E0C16]">{entry.title}</p>
              <p className="text-[12px] text-[#A06A52]">{entry.description}</p>
              <p className="text-[11px] text-[#B0938A] mt-0.5">{formatDate(entry.completed_at)}</p>
            </div>
          </div>
        );
      })}
    </div>
  );
}
