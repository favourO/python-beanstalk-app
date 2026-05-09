"use client";
import { useEffect, useState, Suspense } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import Link from "next/link";
import Image from "next/image";
import Footer from "@/components/Footer";
import JsonLd from "@/components/JsonLd";
import { blogPageSchema } from "@/lib/jsonld";

const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? "https://stage.vyla.health";

type BlogPost = {
  id: string;
  slug: string;
  title: string;
  excerpt: string;
  body: string;
  cover_image_url: string | null;
  category: string | null;
  tags: string[];
  author_name: string;
  published: boolean;
  published_at: string | null;
  created_at: string;
  updated_at: string;
};

function readingTime(body: string): number {
  const words = body.trim().split(/\s+/).filter(Boolean).length;
  return Math.max(1, Math.ceil(words / 200));
}

function formatDate(iso: string | null): string {
  if (!iso) return "";
  return new Date(iso).toLocaleDateString("en-GB", { day: "numeric", month: "long", year: "numeric" });
}

const CATEGORY_COLORS: Record<string, string> = {
  "Cycle Tracking": "#FFF6DD",
  "BBT & Temperature": "#EDFEF1",
  "Ovulation Awareness": "#FFF0F8",
  "Wearable Insights": "#E6FDF9",
  "Wellness": "#F0F0FF",
  "App Updates": "#FFF6F0",
};

function renderMarkdown(body: string): string {
  return body
    .split("\n")
    .map(line => {
      if (line.startsWith("# ")) return `<h1 class="text-[32px] lg:text-[38px] font-serif text-[#1E0C16] mt-10 mb-5 leading-tight tracking-[-0.02em]">${line.slice(2)}</h1>`;
      if (line.startsWith("## ")) return `<h2 class="text-[24px] font-serif text-[#1E0C16] mt-8 mb-4 leading-snug">${line.slice(3)}</h2>`;
      if (line.startsWith("### ")) return `<h3 class="text-[18px] font-semibold text-[#1E0C16] mt-6 mb-3">${line.slice(4)}</h3>`;
      if (line.startsWith("- ") || line.startsWith("* ")) return `<li class="text-[16px] text-[#4A2E1E] leading-relaxed ml-5 list-disc mb-1">${applyInline(line.slice(2))}</li>`;
      if (/^\d+\. /.test(line)) return `<li class="text-[16px] text-[#4A2E1E] leading-relaxed ml-5 list-decimal mb-1">${applyInline(line.replace(/^\d+\. /, ""))}</li>`;
      if (line.trim() === "") return `<div class="h-4"/>`;
      return `<p class="text-[16px] text-[#4A2E1E] leading-[1.8] mb-4">${applyInline(line)}</p>`;
    })
    .join("");
}

function applyInline(text: string): string {
  return text
    .replace(/\*\*(.+?)\*\*/g, '<strong class="font-semibold text-[#1E0C16]">$1</strong>')
    .replace(/\*(.+?)\*/g, '<em>$1</em>')
    .replace(/`(.+?)`/g, '<code class="bg-[#FFF0E8] text-[#FF7A33] px-1.5 py-0.5 rounded text-sm font-mono">$1</code>')
    .replace(/\[(.+?)\]\((.+?)\)/g, '<a href="$2" class="text-[#FF7A33] underline underline-offset-2 hover:text-[#e86a22]">$1</a>');
}

// ── Inline topics (shown when no posts exist) ──────────────────────────────
const TOPICS = [
  { title: "Cycle Tracking", description: "Guides on logging your period, understanding cycle phases, spotting patterns, and getting the most from Vyla's tracking features.", href: "/cycle-tracking/", color: "#FFF6DD" },
  { title: "BBT & Temperature", description: "How to measure basal body temperature accurately, chart thermal shifts, and use temperature data to understand ovulation timing.", href: "/bbt-tracking/", color: "#EDFEF1" },
  { title: "Ovulation Awareness", description: "Understanding LH surges, cervical mucus, fertile windows, and how to interpret ovulation signals across multiple cycles.", href: "/ovulation-tracking/", color: "#FFF0F8" },
  { title: "Wearable Insights", description: "Using Oura Ring and other wearables alongside cycle tracking — what temperature and HRV data can reveal about your cycle.", href: "/wearable-cycle-insights/", color: "#E6FDF9" },
];

// ── Post card ──────────────────────────────────────────────────────────────
function PostCard({ post, onOpen }: { post: BlogPost; onOpen: (post: BlogPost) => void }) {
  const bg = post.category ? (CATEGORY_COLORS[post.category] ?? "#FFF6F0") : "#FFF6F0";
  return (
    <article
      className="bg-white rounded-[20px] border border-[#FFD9C2]/60 overflow-hidden hover:shadow-lg hover:shadow-[#FF7A33]/5 transition-all cursor-pointer group"
      onClick={() => onOpen(post)}
    >
      {post.cover_image_url ? (
        <div className="w-full h-44 overflow-hidden">
          <img
            src={post.cover_image_url}
            alt={post.title}
            className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
          />
        </div>
      ) : (
        <div className="w-full h-44 flex items-center justify-center" style={{ backgroundColor: bg }}>
          <span className="text-4xl opacity-30">✦</span>
        </div>
      )}
      <div className="p-6">
        {post.category && (
          <span className="inline-block text-[10px] font-bold tracking-[0.14em] uppercase text-[#FF7A33] mb-3">
            {post.category}
          </span>
        )}
        <h2 className="font-serif text-[20px] leading-[1.2] text-[#1E0C16] mb-2 group-hover:text-[#FF7A33] transition-colors">
          {post.title}
        </h2>
        <p className="text-[13px] font-light text-[#A06A52] leading-relaxed line-clamp-2 mb-4">{post.excerpt}</p>
        <div className="flex items-center justify-between text-[11px] text-[#B0938A]">
          <span>{post.author_name}</span>
          <div className="flex items-center gap-3">
            <span>{readingTime(post.body)} min read</span>
            {post.published_at && <span>{formatDate(post.published_at)}</span>}
          </div>
        </div>
      </div>
    </article>
  );
}

// ── Post detail view ───────────────────────────────────────────────────────
function PostDetail({ post, onClose }: { post: BlogPost; onClose: () => void }) {
  useEffect(() => {
    document.title = `${post.title} | Vyla`;
    return () => { document.title = "Vyla — AI-Powered Cycle & Wellness Tracking App"; };
  }, [post.title]);

  return (
    <div className="min-h-screen bg-[#FFF6F0]">
      {/* Nav */}
      <header className="bg-white border-b border-[#FFD9C2] sticky top-0 z-50">
        <div className="max-w-[1200px] mx-auto px-6 h-16 flex items-center justify-between">
          <Link href="/" aria-label="Vyla home">
            <Image src="https://vyla.health/assets/vyla-logo.png" alt="Vyla" width={1536} height={1024} className="h-26 w-auto" unoptimized />
          </Link>
          <button
            onClick={onClose}
            className="flex items-center gap-2 text-sm font-medium text-[#A06A52] hover:text-[#FF7A33] transition-colors"
          >
            ← Back to Blog
          </button>
        </div>
      </header>

      <main>
        {/* Hero */}
        {post.cover_image_url && (
          <div className="w-full h-64 lg:h-96 overflow-hidden">
            <img src={post.cover_image_url} alt={post.title} className="w-full h-full object-cover" />
          </div>
        )}

        <div className="max-w-[720px] mx-auto px-6 py-12">
          {/* Breadcrumb */}
          <nav aria-label="Breadcrumb" className="mb-8">
            <ol className="flex items-center gap-2 text-xs text-[#A06A52]">
              <li><Link href="/" className="hover:text-[#FF7A33] transition-colors">Home</Link></li>
              <li aria-hidden>/</li>
              <li><button onClick={onClose} className="hover:text-[#FF7A33] transition-colors">Blog</button></li>
              <li aria-hidden>/</li>
              <li className="text-[#1E0C16] truncate max-w-[200px]">{post.title}</li>
            </ol>
          </nav>

          {/* Category */}
          {post.category && (
            <span className="inline-block text-[10px] font-bold tracking-[0.16em] uppercase text-[#FF7A33] mb-4">
              {post.category}
            </span>
          )}

          {/* Title */}
          <h1 className="font-serif text-[42px] lg:text-[52px] leading-[1.06] tracking-[-0.03em] text-[#1E0C16] mb-5">
            {post.title}
          </h1>

          {/* Excerpt */}
          {post.excerpt && (
            <p className="text-[18px] font-light text-[#7A4A32] leading-relaxed mb-6 italic">{post.excerpt}</p>
          )}

          {/* Meta */}
          <div className="flex items-center gap-4 text-[12px] text-[#B0938A] mb-10 pb-8 border-b border-[#FFD9C2]/60">
            <div className="flex items-center gap-2.5">
              <div className="w-7 h-7 rounded-full bg-gradient-to-br from-[#FF7A33] to-[#FFB38A] flex items-center justify-center text-white text-[10px] font-bold">
                {post.author_name[0]?.toUpperCase()}
              </div>
              <span className="font-medium text-[#7A4A32]">{post.author_name}</span>
            </div>
            <span>·</span>
            <span>{readingTime(post.body)} min read</span>
            {post.published_at && (
              <>
                <span>·</span>
                <span>{formatDate(post.published_at)}</span>
              </>
            )}
          </div>

          {/* Body */}
          <div
            className="prose-vyla"
            dangerouslySetInnerHTML={{ __html: renderMarkdown(post.body) }}
          />

          {/* Tags */}
          {post.tags.length > 0 && (
            <div className="flex flex-wrap gap-2 mt-12 pt-8 border-t border-[#FFD9C2]/60">
              {post.tags.map(tag => (
                <span key={tag} className="text-[11px] text-[#A06A52] bg-[#FFF0E8] px-3 py-1 rounded-full border border-[#FFD9C2]/60">
                  {tag}
                </span>
              ))}
            </div>
          )}

          {/* Back CTA */}
          <div className="mt-12 pt-8 border-t border-[#FFD9C2]/60 flex items-center justify-between">
            <button
              onClick={onClose}
              className="text-sm font-medium text-[#FF7A33] hover:text-[#e86a22] transition-colors"
            >
              ← More articles
            </button>
            <a
              href="#"
              className="text-sm font-medium bg-[#FF7A33] text-white px-5 py-2.5 rounded-full hover:bg-[#e86a22] transition-colors"
            >
              Download Vyla free
            </a>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  );
}

// ── Main Blog page ─────────────────────────────────────────────────────────
function BlogContent() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const postSlug = searchParams.get("post");

  const [posts, setPosts] = useState<BlogPost[]>([]);
  const [loading, setLoading] = useState(true);
  const [activePost, setActivePost] = useState<BlogPost | null>(null);
  const [postLoading, setPostLoading] = useState(false);

  useEffect(() => {
    fetch(`${API_BASE}/api/v1/public/blog?page_size=20`)
      .then(r => r.ok ? r.json() : { items: [] })
      .then(d => setPosts(d.items ?? []))
      .catch(() => setPosts([]))
      .finally(() => setLoading(false));
  }, []);

  // Load post from URL ?post=slug
  useEffect(() => {
    if (!postSlug) { setActivePost(null); return; }
    const existing = posts.find(p => p.slug === postSlug);
    if (existing) { setActivePost(existing); return; }
    setPostLoading(true);
    fetch(`${API_BASE}/api/v1/public/blog/${postSlug}`)
      .then(r => r.ok ? r.json() : null)
      .then(p => setActivePost(p))
      .catch(() => setActivePost(null))
      .finally(() => setPostLoading(false));
  }, [postSlug, posts]);

  function openPost(post: BlogPost) {
    const params = new URLSearchParams({ post: post.slug });
    router.push(`/blog/?${params.toString()}`, { scroll: false });
    setActivePost(post);
  }

  function closePost() {
    router.push("/blog/", { scroll: false });
    setActivePost(null);
  }

  if (postLoading) {
    return (
      <div className="min-h-screen bg-[#FFF6F0] flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-[#FF7A33] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (activePost) {
    return <PostDetail post={activePost} onClose={closePost} />;
  }

  return (
    <div className="min-h-screen bg-[#FFF6F0]">
      <JsonLd data={blogPageSchema()} />

      {/* Nav */}
      <header className="bg-white border-b border-[#FFD9C2] sticky top-0 z-50">
        <div className="max-w-[1200px] mx-auto px-6 h-16 flex items-center justify-between">
          <Link href="/" aria-label="Vyla home">
            <Image src="https://vyla.health/assets/vyla-logo.png" alt="Vyla" width={1536} height={1024} className="h-26 w-auto" unoptimized />
          </Link>
          <a href="#" className="text-sm font-medium bg-[#FF7A33] text-white px-5 py-2 rounded-full hover:bg-[#e86a22] transition-colors">
            Download free
          </a>
        </div>
      </header>

      <main id="main-content">
        {/* Hero */}
        <section className="bg-[#FFF6F0] pt-16 pb-20">
          <div className="max-w-[1200px] mx-auto px-6">
            <nav aria-label="Breadcrumb" className="mb-10">
              <ol className="flex items-center gap-2 text-xs text-[#A06A52]" role="list">
                <li><Link href="/" className="hover:text-[#FF7A33] transition-colors">Home</Link></li>
                <li aria-hidden>/</li>
                <li aria-current="page" className="text-[#1E0C16]">Blog</li>
              </ol>
            </nav>

            <div className="max-w-[640px]">
              <p className="text-[11px] font-medium tracking-[0.12em] uppercase text-[#FF7A33] mb-4">Articles & guides</p>
              <h1 className="font-serif text-[58px] lg:text-[68px] leading-[1.06] tracking-[-0.03em] text-[#1E0C16] mb-5">
                Cycle health,<br />
                <span className="text-[#FF7A33]">clearly explained.</span>
              </h1>
              <p className="text-lg font-light text-[#A06A52] leading-relaxed">
                In-depth guides on cycle tracking, BBT temperature charting, ovulation awareness, wearable health insights, and women&apos;s wellness — from the Vyla team.
              </p>
            </div>
          </div>
        </section>

        {/* Posts grid */}
        {loading ? (
          <section className="bg-white py-20 border-t border-[#FFD9C2]/40">
            <div className="max-w-[1200px] mx-auto px-6">
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
                {[...Array(3)].map((_, i) => (
                  <div key={i} className="bg-[#FFF6F0] rounded-[20px] border border-[#FFD9C2]/40 h-72 animate-pulse" />
                ))}
              </div>
            </div>
          </section>
        ) : posts.length > 0 ? (
          <section className="bg-white py-20 border-t border-[#FFD9C2]/40" aria-labelledby="posts-heading">
            <div className="max-w-[1200px] mx-auto px-6">
              <h2 id="posts-heading" className="font-serif text-[32px] text-[#1E0C16] tracking-[-0.02em] mb-10">
                Latest articles
              </h2>
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
                {posts.map(post => (
                  <PostCard key={post.id} post={post} onOpen={openPost} />
                ))}
              </div>
            </div>
          </section>
        ) : null}

        {/* Topics grid — always visible */}
        <section className={`py-20 border-t border-[#FFD9C2]/40 ${posts.length > 0 ? "bg-[#FFF6F0]" : "bg-white"}`}>
          <div className="max-w-[1200px] mx-auto px-6">
            <h2 className="font-serif text-[32px] text-[#1E0C16] tracking-[-0.02em] mb-10">
              Browse by topic
            </h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
              {TOPICS.map(topic => (
                <article
                  key={topic.title}
                  className="rounded-[20px] border border-[#FFD9C2]/60 p-7 hover:shadow-md hover:shadow-[#FF7A33]/5 transition-shadow"
                  style={{ backgroundColor: topic.color }}
                >
                  <h3 className="text-[20px] font-semibold text-[#1E0C16] mb-3">{topic.title}</h3>
                  <p className="text-sm font-light text-[#7A4A32] leading-relaxed mb-5">{topic.description}</p>
                  <Link href={topic.href} className="text-sm font-medium text-[#FF7A33] hover:text-[#e86a22] transition-colors">
                    Read more →
                  </Link>
                </article>
              ))}
            </div>
          </div>
        </section>

        {/* Coming soon — only when no posts */}
        {posts.length === 0 && (
          <section className="bg-[#FFF6F0] py-16 border-t border-[#FFD9C2]/40">
            <div className="max-w-[600px] mx-auto px-6 text-center">
              <div className="w-14 h-14 rounded-full bg-[#FFF0E8] border border-[#FFD9C2] flex items-center justify-center mx-auto mb-5" aria-hidden="true">
                <span className="text-[#FF7A33] text-xl">✦</span>
              </div>
              <h2 className="font-serif text-[28px] text-[#1E0C16] tracking-[-0.02em] mb-3">More articles coming soon</h2>
              <p className="text-sm font-light text-[#A06A52] leading-relaxed mb-6">
                The Vyla blog is growing. Articles on cycle health, hormone wellness, wearable insights, and BBT charting are being published regularly.
              </p>
              <Link href="/" className="inline-flex items-center gap-2 text-sm font-medium text-[#FF7A33] hover:text-[#e86a22] transition-colors">
                ← Back to Vyla home
              </Link>
            </div>
          </section>
        )}
      </main>

      <Footer />
    </div>
  );
}

export default function BlogPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-[#FFF6F0] flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-[#FF7A33] border-t-transparent rounded-full animate-spin" />
      </div>
    }>
      <BlogContent />
    </Suspense>
  );
}
