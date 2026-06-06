"use client";
import { useEffect, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import { api, getToken, ApiError, type BlogImageUploadOut, type BlogPostItem, type BlogPostListOut, type BlogPostCreate } from "@/lib/api";
import Badge from "@/components/Badge";
import { Table, Thead, Th, Tbody, Tr, Td } from "@/components/Table";
import { LoadingRows } from "@/components/PageShell";

const CATEGORIES = ["Cycle Tracking", "BBT & Temperature", "Ovulation Awareness", "Wearable Insights", "Wellness", "App Updates"];

type View = "list" | "create" | "edit";

function slugify(t: string) {
  return t.toLowerCase().replace(/[^\w\s-]/g, "").replace(/[\s_]+/g, "-").replace(/^-+|-+$/g, "").replace(/\//g, "-");
}

function readingTime(body: string) {
  return Math.max(1, Math.ceil(body.trim().split(/\s+/).filter(Boolean).length / 200));
}

// ── Post form ─────────────────────────────────────────────────────────────────
interface FormState {
  title: string; slug: string; excerpt: string; body: string;
  coverUrl: string; category: string; tags: string; authorName: string; published: boolean;
}

const emptyForm = (): FormState => ({
  title: "", slug: "", excerpt: "", body: "", coverUrl: "",
  category: "", tags: "", authorName: "Vyla Team", published: false,
});

function fromPost(p: BlogPostItem): FormState {
  return {
    title: p.title, slug: p.slug, excerpt: p.excerpt, body: p.body,
    coverUrl: p.cover_image_url ?? "", category: p.category ?? "",
    tags: p.tags.join(", "), authorName: p.author_name, published: p.published,
  };
}

function PostForm({
  initial, editId, onSaved, onCancel,
}: {
  initial: FormState; editId: string | null; onSaved: (p: BlogPostItem) => void; onCancel: () => void;
}) {
  const router = useRouter();
  const [f, setF] = useState<FormState>(initial);
  const [slugManual, setSlugManual] = useState(!!editId);
  const [saving, setSaving] = useState(false);
  const [uploadingImage, setUploadingImage] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [preview, setPreview] = useState(false);

  function set<K extends keyof FormState>(k: K, v: FormState[K]) {
    setF(prev => ({ ...prev, [k]: v }));
  }

  function handleTitle(v: string) {
    set("title", v);
    if (!slugManual) set("slug", slugify(v));
  }

  async function save(asDraft = false) {
    if (uploadingImage) { setErr("Wait for the image upload to finish."); return; }
    if (!f.title.trim()) { setErr("Title is required."); return; }
    if (!f.slug.trim()) { setErr("Slug is required."); return; }
    const token = getToken();
    if (!token) { router.push("/login"); return; }

    const payload: BlogPostCreate = {
      title: f.title.trim(), slug: f.slug.trim(), excerpt: f.excerpt.trim(),
      body: f.body.trim(), cover_image_url: f.coverUrl.trim() || null,
      category: f.category || null,
      tags: f.tags.split(",").map(t => t.trim()).filter(Boolean),
      author_name: f.authorName.trim() || "Vyla Team",
      published: asDraft ? false : f.published,
    };

    setSaving(true); setErr(null);
    try {
      const saved = editId
        ? await api.put<BlogPostItem>(`/admin/blog/${editId}`, token, payload)
        : await api.post<BlogPostItem>("/admin/blog", token, payload);
      onSaved(saved);
    } catch (e) {
      if (e instanceof ApiError) {
        if (e.status === 409) setErr("A post with this slug already exists.");
        else if (e.status === 401 || e.status === 403) router.push("/login");
        else setErr("Failed to save post. " + e.message);
      } else setErr("Failed to save post.");
    } finally { setSaving(false); }
  }

  async function uploadCoverImage(file: File | null) {
    if (!file) return;
    const token = getToken();
    if (!token) { router.push("/login"); return; }

    const form = new FormData();
    form.append("image", file);
    if (f.slug.trim()) form.append("slug", f.slug.trim());

    setUploadingImage(true); setErr(null);
    try {
      const uploaded = await api.upload<BlogImageUploadOut>("/admin/blog/image", token, form);
      set("coverUrl", uploaded.url);
    } catch (e) {
      if (e instanceof ApiError) {
        if (e.status === 401 || e.status === 403) router.push("/login");
        else setErr("Failed to upload image. " + e.message);
      } else setErr("Failed to upload image.");
    } finally {
      setUploadingImage(false);
    }
  }

  const lines = f.body.split("\n").map(line => {
    if (line.startsWith("# ")) return `<h1 class="text-2xl font-bold mb-3">${line.slice(2)}</h1>`;
    if (line.startsWith("## ")) return `<h2 class="text-xl font-semibold mb-2 mt-5">${line.slice(3)}</h2>`;
    if (line.startsWith("### ")) return `<h3 class="text-lg font-semibold mb-2 mt-4">${line.slice(4)}</h3>`;
    if (line.startsWith("- ") || line.startsWith("* ")) return `<li class="ml-5 list-disc mb-1 text-sm">${line.slice(2)}</li>`;
    if (line.trim() === "") return `<div class="h-3"/>`;
    return `<p class="text-sm mb-3 leading-relaxed">${line.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>").replace(/\*(.+?)\*/g, "<em>$1</em>")}</p>`;
  }).join("");

  return (
    <div className="max-w-[900px]">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <button onClick={onCancel} className="text-[#B0938A] hover:text-[#FF7A33] transition-colors text-sm">← Blog</button>
          <span className="text-[#E0CEC8]">/</span>
          <h1 className="text-[16px] font-bold text-[#1E0C16]">{editId ? "Edit post" : "New post"}</h1>
        </div>
        <div className="flex items-center gap-2">
          <button onClick={() => setPreview(p => !p)} className="text-[13px] font-medium text-[#9E7B6E] hover:text-[#FF7A33] px-3 py-2 transition-colors">
            {preview ? "← Edit" : "Preview →"}
          </button>
          {!editId && (
            <button onClick={() => save(true)} disabled={saving || uploadingImage}
              className="text-[13px] font-medium text-[#9E7B6E] border border-[#E0CEC8] px-4 py-2 rounded-xl hover:border-[#B0938A] transition-colors disabled:opacity-50">
              Save draft
            </button>
          )}
          <button onClick={() => save(false)} disabled={saving || uploadingImage}
            className="text-[13px] font-semibold bg-[#FF7A33] text-white px-5 py-2 rounded-xl hover:bg-[#e86a22] transition-colors disabled:opacity-50">
            {saving ? "Saving…" : uploadingImage ? "Uploading…" : editId ? "Save changes" : f.published ? "Publish" : "Save draft"}
          </button>
        </div>
      </div>

      {err && (
        <div className="mb-4 px-4 py-3 bg-red-50 border border-red-200 rounded-xl text-[13px] text-red-700 flex items-center justify-between">
          {err}<button onClick={() => setErr(null)} className="ml-3 text-red-400 hover:text-red-600">✕</button>
        </div>
      )}

      {preview ? (
        <div className="bg-white rounded-2xl border border-[#F0E8E4] overflow-hidden max-w-[680px] p-8">
          {f.coverUrl && <img src={f.coverUrl} alt="" className="w-full h-48 object-cover rounded-xl mb-6" />}
          {f.category && <span className="text-[10px] font-bold tracking-widest uppercase text-[#FF7A33] block mb-3">{f.category}</span>}
          <h1 className="font-serif text-[30px] text-[#1E0C16] mb-3">{f.title || "Untitled"}</h1>
          {f.excerpt && <p className="text-[15px] text-[#7A4A32] italic mb-5">{f.excerpt}</p>}
          <p className="text-[11px] text-[#B0938A] mb-6">{f.authorName} · ~{readingTime(f.body)} min read</p>
          <div className="text-[#4A2E1E]" dangerouslySetInnerHTML={{ __html: lines }} />
        </div>
      ) : (
        <div className="grid grid-cols-[1fr_260px] gap-5">
          {/* Main */}
          <div className="space-y-4">
            <div className="bg-white rounded-2xl border border-[#F0E8E4] p-5 space-y-4">
              <div>
                <label className="block text-[10px] font-bold text-[#9E7B6E] uppercase tracking-wider mb-1.5">Title *</label>
                <input type="text" value={f.title} onChange={e => handleTitle(e.target.value)} placeholder="Post title…"
                  className="w-full text-[20px] font-semibold text-[#1E0C16] placeholder:text-[#C0A898] border-0 outline-none bg-transparent" />
              </div>
              <div>
                <label className="block text-[10px] font-bold text-[#9E7B6E] uppercase tracking-wider mb-1">Slug</label>
                <div className="flex items-center gap-1 text-[12px]">
                  <span className="text-[#B0938A] shrink-0">blog/?post=</span>
                  <input type="text" value={f.slug} onChange={e => { set("slug", e.target.value); setSlugManual(true); }}
                    className="flex-1 text-[#1E0C16] border-b border-[#E0CEC8] focus:border-[#FF7A33] outline-none py-0.5 bg-transparent" />
                </div>
              </div>
              <div>
                <label className="block text-[10px] font-bold text-[#9E7B6E] uppercase tracking-wider mb-1.5">Excerpt</label>
                <textarea value={f.excerpt} onChange={e => set("excerpt", e.target.value)} rows={2} placeholder="Short summary for the blog listing…"
                  className="w-full text-[13px] text-[#1E0C16] placeholder:text-[#C0A898] border border-[#F0E8E4] rounded-xl p-3 outline-none focus:border-[#FF7A33] resize-none bg-[#FAFAFA]" />
              </div>
            </div>

            <div className="bg-white rounded-2xl border border-[#F0E8E4] p-5">
              <div className="flex items-center justify-between mb-2">
                <label className="text-[10px] font-bold text-[#9E7B6E] uppercase tracking-wider">Body (Markdown)</label>
                <span className="text-[11px] text-[#C0A898]">~{readingTime(f.body)} min · {f.body.trim().split(/\s+/).filter(Boolean).length} words</span>
              </div>
              <textarea value={f.body} onChange={e => set("body", e.target.value)} rows={24}
                placeholder={"# Heading\n\nStart writing in Markdown…\n\n**Bold**, *italic*, [links](url)\n\n## Section\n\nParagraph text."}
                className="w-full text-[13px] font-mono text-[#1E0C16] placeholder:text-[#C0A898] border border-[#F0E8E4] rounded-xl p-4 outline-none focus:border-[#FF7A33] resize-y bg-[#FAFAFA] leading-relaxed" />
              <p className="text-[11px] text-[#C0A898] mt-1.5">Markdown: **bold**, *italic*, # headings, - lists, `code`, [link](url)</p>
            </div>
          </div>

          {/* Sidebar */}
          <div className="space-y-4">
            {/* Publish toggle */}
            <div className="bg-white rounded-2xl border border-[#F0E8E4] p-4">
              <p className="text-[10px] font-bold text-[#9E7B6E] uppercase tracking-wider mb-3">Visibility</p>
              <label className="flex items-center justify-between cursor-pointer">
                <span className="text-[13px] font-medium text-[#1E0C16]">{f.published ? "Published" : "Draft"}</span>
                <button type="button" role="switch" aria-checked={f.published} onClick={() => set("published", !f.published)}
                  className={`relative rounded-full transition-colors ${f.published ? "bg-[#FF7A33]" : "bg-[#E0CEC8]"}`}
                  style={{ width: 40, height: 22 }}>
                  <span className={`absolute top-[3px] w-4 h-4 bg-white rounded-full shadow transition-transform ${f.published ? "translate-x-5" : "translate-x-0.5"}`} />
                </button>
              </label>
              <p className="text-[11px] text-[#C0A898] mt-2">{f.published ? "Live on vyla.health/blog" : "Not visible to visitors"}</p>
            </div>

            {/* Category */}
            <div className="bg-white rounded-2xl border border-[#F0E8E4] p-4">
              <label className="block text-[10px] font-bold text-[#9E7B6E] uppercase tracking-wider mb-2">Category</label>
              <select value={f.category} onChange={e => set("category", e.target.value)}
                className="w-full text-[13px] text-[#1E0C16] border border-[#F0E8E4] rounded-lg px-3 py-2 outline-none focus:border-[#FF7A33] bg-white">
                <option value="">No category</option>
                {CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
              </select>
            </div>

            {/* Tags */}
            <div className="bg-white rounded-2xl border border-[#F0E8E4] p-4">
              <label className="block text-[10px] font-bold text-[#9E7B6E] uppercase tracking-wider mb-2">Tags</label>
              <input type="text" value={f.tags} onChange={e => set("tags", e.target.value)} placeholder="cycle, health, ovulation"
                className="w-full text-[13px] text-[#1E0C16] placeholder:text-[#C0A898] border border-[#F0E8E4] rounded-lg px-3 py-2 outline-none focus:border-[#FF7A33]" />
              <p className="text-[11px] text-[#C0A898] mt-1">Comma-separated</p>
            </div>

            {/* Cover URL */}
            <div className="bg-white rounded-2xl border border-[#F0E8E4] p-4">
              <label className="block text-[10px] font-bold text-[#9E7B6E] uppercase tracking-wider mb-2">Cover image</label>
              <label className="block text-center cursor-pointer text-[13px] font-semibold text-[#FF7A33] border border-dashed border-[#E0CEC8] rounded-lg px-3 py-3 hover:border-[#FF7A33] transition-colors">
                {uploadingImage ? "Uploading…" : "Upload image"}
                <input type="file" accept="image/jpeg,image/png,image/webp,image/gif" disabled={uploadingImage}
                  onChange={e => uploadCoverImage(e.target.files?.[0] ?? null)}
                  className="hidden" />
              </label>
              <input type="url" value={f.coverUrl} onChange={e => set("coverUrl", e.target.value)} placeholder="https://…"
                className="mt-3 w-full text-[13px] text-[#1E0C16] placeholder:text-[#C0A898] border border-[#F0E8E4] rounded-lg px-3 py-2 outline-none focus:border-[#FF7A33]" />
              {f.coverUrl && (
                <img src={f.coverUrl} alt="" className="mt-3 w-full h-24 object-cover rounded-lg border border-[#F0E8E4]"
                  onError={e => { (e.target as HTMLImageElement).style.display = "none"; }} />
              )}
            </div>

            {/* Author */}
            <div className="bg-white rounded-2xl border border-[#F0E8E4] p-4">
              <label className="block text-[10px] font-bold text-[#9E7B6E] uppercase tracking-wider mb-2">Author</label>
              <input type="text" value={f.authorName} onChange={e => set("authorName", e.target.value)}
                className="w-full text-[13px] text-[#1E0C16] border border-[#F0E8E4] rounded-lg px-3 py-2 outline-none focus:border-[#FF7A33]" />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// ── Blog list view ────────────────────────────────────────────────────────────
export default function BlogPage() {
  const router = useRouter();
  const [view, setView] = useState<View>("list");
  const [editPost, setEditPost] = useState<BlogPostItem | null>(null);
  const [posts, setPosts] = useState<BlogPostItem[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [deleteConfirm, setDeleteConfirm] = useState<string | null>(null);
  const [deleting, setDeleting] = useState<string | null>(null);

  const load = useCallback(() => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }
    setLoading(true);
    api.get<BlogPostListOut>("/admin/blog?page_size=100", token)
      .then(d => { setPosts(d.items); setTotal(d.total); })
      .catch(e => {
        if (e instanceof ApiError && (e.status === 401 || e.status === 403)) router.push("/login");
        else setErr("Failed to load posts.");
      })
      .finally(() => setLoading(false));
  }, [router]);

  useEffect(() => { load(); }, [load]);

  async function handleDelete(id: string) {
    if (deleteConfirm !== id) { setDeleteConfirm(id); return; }
    const token = getToken();
    if (!token) return;
    setDeleting(id); setDeleteConfirm(null);
    try {
      await api.del(`/admin/blog/${id}`, token);
      setPosts(p => p.filter(x => x.id !== id));
      setTotal(t => t - 1);
    } catch { setErr("Failed to delete post."); }
    finally { setDeleting(null); }
  }

  async function togglePublished(post: BlogPostItem) {
    const token = getToken();
    if (!token) return;
    try {
      const updated = await api.put<BlogPostItem>(`/admin/blog/${post.id}`, token, { published: !post.published });
      setPosts(p => p.map(x => x.id === post.id ? updated : x));
    } catch { setErr("Failed to update."); }
  }

  function onSaved(p: BlogPostItem) {
    if (view === "create") {
      setPosts(prev => [p, ...prev]);
      setTotal(t => t + 1);
    } else {
      setPosts(prev => prev.map(x => x.id === p.id ? p : x));
    }
    setView("list"); setEditPost(null);
  }

  if (view === "create") {
    return <PostForm initial={emptyForm()} editId={null} onSaved={onSaved} onCancel={() => setView("list")} />;
  }
  if (view === "edit" && editPost) {
    return <PostForm initial={fromPost(editPost)} editId={editPost.id} onSaved={onSaved} onCancel={() => { setView("list"); setEditPost(null); }} />;
  }

  return (
    <div>
      <div className="flex items-start justify-between mb-6">
        <div>
          <h1 className="text-[22px] font-bold text-[#1E0C16] tracking-tight">Blog</h1>
          <p className="text-[13px] text-[#9E7B6E] mt-0.5">{total} post{total !== 1 ? "s" : ""}</p>
        </div>
        <button onClick={() => setView("create")}
          className="inline-flex items-center gap-2 bg-[#FF7A33] text-white text-[13px] font-semibold px-4 py-2 rounded-xl hover:bg-[#e86a22] transition-colors">
          <span className="text-base leading-none">+</span> New post
        </button>
      </div>

      {err && (
        <div className="mb-4 px-4 py-3 bg-red-50 border border-red-200 rounded-xl text-[13px] text-red-700 flex items-center justify-between">
          {err}<button onClick={() => setErr(null)} className="ml-3 text-red-400 hover:text-red-600">✕</button>
        </div>
      )}

      <div className="bg-white rounded-2xl border border-[#F0E8E4] overflow-hidden">
        <Table>
          <Thead>
            <Tr>
              <Th>Title</Th><Th>Category</Th><Th>Status</Th><Th>Published</Th><Th>Created</Th><Th>&nbsp;</Th>
            </Tr>
          </Thead>
          <Tbody>
            {loading && <LoadingRows cols={6} />}
            {!loading && posts.length === 0 && (
              <tr><td colSpan={6} className="px-6 py-12 text-center text-sm text-[#A06A52]">
                No blog posts yet.{" "}
                <button onClick={() => setView("create")} className="text-[#FF7A33] font-medium">Create your first post</button>
              </td></tr>
            )}
            {!loading && posts.map(post => (
              <Tr key={post.id}>
                <Td>
                  <div className="max-w-[260px]">
                    <p className="text-[13px] font-medium text-[#1E0C16] truncate">{post.title}</p>
                    <p className="text-[11px] text-[#B0938A] truncate">/{post.slug}</p>
                  </div>
                </Td>
                <Td>{post.category ? <Badge label={post.category} /> : <span className="text-[12px] text-[#C0A898]">—</span>}</Td>
                <Td>
                  <button onClick={() => togglePublished(post)}
                    className={`inline-flex items-center gap-1.5 text-[11px] font-semibold px-2.5 py-1 rounded-full transition-colors ${
                      post.published ? "bg-emerald-50 text-emerald-700 hover:bg-emerald-100" : "bg-[#F5F0ED] text-[#9E7B6E] hover:bg-[#EDE5E0]"
                    }`}>
                    <span className={`w-1.5 h-1.5 rounded-full ${post.published ? "bg-emerald-500" : "bg-[#B0938A]"}`} />
                    {post.published ? "Published" : "Draft"}
                  </button>
                </Td>
                <Td>
                  <span className="text-[12px] text-[#9E7B6E]">
                    {post.published_at ? new Date(post.published_at).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" }) : "—"}
                  </span>
                </Td>
                <Td>
                  <span className="text-[12px] text-[#9E7B6E]">
                    {new Date(post.created_at).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" })}
                  </span>
                </Td>
                <Td>
                  <div className="flex items-center gap-3 justify-end">
                    <button onClick={() => { setEditPost(post); setView("edit"); }}
                      className="text-[12px] font-medium text-[#FF7A33] hover:text-[#e86a22] transition-colors">
                      Edit
                    </button>
                    <button onClick={() => handleDelete(post.id)} disabled={deleting === post.id}
                      className={`text-[12px] font-medium transition-colors disabled:opacity-50 ${
                        deleteConfirm === post.id ? "text-red-600 hover:text-red-800" : "text-[#C0A898] hover:text-red-500"
                      }`}>
                      {deleteConfirm === post.id ? "Confirm?" : deleting === post.id ? "…" : "Delete"}
                    </button>
                    {deleteConfirm === post.id && (
                      <button onClick={() => setDeleteConfirm(null)} className="text-[12px] text-[#B0938A] hover:text-[#1E0C16]">Cancel</button>
                    )}
                  </div>
                </Td>
              </Tr>
            ))}
          </Tbody>
        </Table>
      </div>
      <p className="text-[11px] text-[#C0A898] mt-4">Published posts appear on <span className="font-medium">vyla.health/blog</span> immediately.</p>
    </div>
  );
}
