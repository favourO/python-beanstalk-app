"use client";
import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import TopBar from "@/components/TopBar";
import Badge from "@/components/Badge";
import StatCard from "@/components/StatCard";
import { Table, Thead, Th, Tbody, Tr, Td } from "@/components/Table";
import { LoadingRows, ErrorBanner, EmptyState } from "@/components/PageShell";
import { api, getToken, ApiError, type ContactListOut, type ContactMessageItem } from "@/lib/api";

function fmtDate(v: string) { return v.slice(0, 16).replace("T", " "); }

function ReplyModal({ msg, onClose, onSent }: { msg: ContactMessageItem; onClose: () => void; onSent: () => void }) {
  const [reply, setReply] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");

  async function send() {
    if (!reply.trim()) return;
    const token = getToken();
    if (!token) return;
    setSending(true); setError("");
    try {
      await api.post(`/admin/contacts/${msg.id}/reply`, token, { message: reply });
      onSent();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to send reply");
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4" onClick={onClose}>
      <div className="bg-white rounded-2xl p-6 w-full max-w-lg shadow-xl" onClick={e => e.stopPropagation()}>
        <h2 className="text-base font-semibold text-[#1E0C16] mb-1">Reply to {msg.name}</h2>
        <p className="text-xs text-[#A06A52] mb-1">{msg.email}</p>
        <p className="text-xs text-[#B0938A] mb-4 bg-[#FFF6F0] rounded-lg p-3 border border-[#FFD9C2]">
          <span className="block font-medium text-[#7A4A32] mb-1">{msg.subject}</span>
          {msg.message}
        </p>
        <textarea
          value={reply}
          onChange={e => setReply(e.target.value)}
          placeholder="Type your reply…"
          rows={5}
          className="w-full border border-[#FFD9C2] rounded-xl px-4 py-3 text-sm text-[#1E0C16] placeholder-[#C0988A] outline-none focus:border-[#FF7A33] focus:ring-2 focus:ring-[#FF7A33]/20 resize-none mb-3"
        />
        {error && <p className="text-xs text-red-500 mb-2">{error}</p>}
        <div className="flex gap-3 justify-end">
          <button onClick={onClose} className="text-sm px-4 py-2 rounded-lg border border-[#FFD9C2] text-[#A06A52] hover:bg-[#FFF6F0]">Cancel</button>
          <button onClick={send} disabled={sending || !reply.trim()} className="text-sm px-5 py-2 rounded-lg bg-[#FF7A33] text-white font-semibold disabled:opacity-50 hover:bg-[#e86a22]">
            {sending ? "Sending…" : "Send reply"}
          </button>
        </div>
      </div>
    </div>
  );
}

export default function ContactsPage() {
  const router = useRouter();
  const [data, setData] = useState<ContactListOut | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [selected, setSelected] = useState<ContactMessageItem | null>(null);

  const load = useCallback(async () => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }
    setLoading(true); setError(null);
    const params = new URLSearchParams({ page: String(page), page_size: "50" });
    try { setData(await api.get<ContactListOut>(`/admin/contacts?${params}`, token)); }
    catch (e) {
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) router.push("/login");
      else setError(e instanceof Error ? e.message : "Failed to load contacts");
    } finally { setLoading(false); }
  }, [router, page]);

  useEffect(() => { load(); }, [load]);

  async function markRead(id: string) {
    const token = getToken();
    if (!token) return;
    await api.patch(`/admin/contacts/${id}/read`, token, {}).catch(() => null);
    load();
  }

  const items = data?.items ?? [];

  return (
    <>
      {selected && (
        <ReplyModal
          msg={selected}
          onClose={() => setSelected(null)}
          onSent={() => { setSelected(null); load(); }}
        />
      )}
      <TopBar
        title="Contacts"
        subtitle={data ? `${data.total.toLocaleString()} messages · ${data.unread} unread` : "Customer contact messages"}
      />
      {error && <ErrorBanner message={error} />}
      <div className="grid grid-cols-2 lg:grid-cols-3 gap-4 mb-8">
        <StatCard label="Total" value={String(data?.total ?? 0)} sub="All messages" accent />
        <StatCard label="Unread" value={String(data?.unread ?? 0)} sub="Awaiting response" />
        <StatCard label="Replied" value={String(items.filter(m => m.replied_at).length)} sub="Current page" />
      </div>
      <Table>
        <Thead>
          <Th>Name</Th><Th>Email</Th><Th>Subject</Th><Th>Status</Th><Th>Received</Th><Th>&nbsp;</Th>
        </Thead>
        <Tbody>
          {loading ? <LoadingRows cols={6} /> : items.length === 0 ? <EmptyState label="No contact messages yet" /> : items.map(m => (
            <Tr key={m.id}>
              <Td><span className={m.read ? "" : "font-semibold text-[#1E0C16]"}>{m.name}</span></Td>
              <Td muted>{m.email}</Td>
              <Td>
                <button
                  className="text-left text-sm text-[#FF7A33] hover:underline max-w-[220px] truncate block"
                  onClick={() => { setSelected(m); if (!m.read) markRead(m.id); }}
                  title={m.subject}
                >
                  {m.subject}
                </button>
              </Td>
              <Td>
                {m.replied_at
                  ? <Badge label="replied" />
                  : m.read
                  ? <Badge label="read" />
                  : <Badge label="unread" />}
              </Td>
              <Td muted>{fmtDate(m.created_at)}</Td>
              <Td>
                <button
                  onClick={() => setSelected(m)}
                  className="text-xs px-3 py-1.5 rounded-lg bg-[#FFF0E8] text-[#FF7A33] font-medium hover:bg-[#FFE0CC] transition-colors"
                >
                  Reply
                </button>
              </Td>
            </Tr>
          ))}
        </Tbody>
      </Table>
      {data && data.total > 50 && <Pager page={page} total={data.total} onPage={setPage} />}
    </>
  );
}

function Pager({ page, total, onPage }: { page: number; total: number; onPage: (n: number) => void }) {
  return (
    <div className="flex items-center justify-between mt-4 text-sm text-[#A06A52]">
      <span>Page {page} · {total.toLocaleString()} total</span>
      <div className="flex gap-2">
        <button onClick={() => onPage(Math.max(1, page - 1))} disabled={page === 1} className="px-3 py-1 rounded border border-[#FFD9C2] disabled:opacity-40">Prev</button>
        <button onClick={() => onPage(page + 1)} disabled={page * 50 >= total} className="px-3 py-1 rounded border border-[#FFD9C2] disabled:opacity-40">Next</button>
      </div>
    </div>
  );
}
