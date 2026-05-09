"use client";
import { useEffect, useState, Suspense } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import Link from "next/link";
import Image from "next/image";
import { motion, useReducedMotion } from "framer-motion";
import Nav from "@/components/Nav";
import Footer from "@/components/Footer";
import JsonLd from "@/components/JsonLd";
import { blogPageSchema } from "@/lib/jsonld";

const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? "https://stage.vyla.health";
const BASE_URL = "https://vyla.health";

type Post = {
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

// ── utils ──────────────────────────────────────────────────────────────────

function readingTime(body: string): number {
  return Math.max(1, Math.ceil(body.trim().split(/\s+/).filter(Boolean).length / 200));
}

function fmtDate(iso: string | null): string {
  if (!iso) return "";
  return new Date(iso).toLocaleDateString("en-GB", { day: "numeric", month: "long", year: "numeric" });
}

function fmtDateShort(iso: string | null): string {
  if (!iso) return "";
  return new Date(iso).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
}

// ── markdown renderer ──────────────────────────────────────────────────────

function inline(t: string): string {
  return t
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.+?)\*/g, '<em>$1</em>')
    .replace(/`(.+?)`/g, '<code>$1</code>')
    .replace(/\[(.+?)\]\((.+?)\)/g, '<a href="$2">$1</a>');
}

function renderMarkdown(body: string): string {
  const lines = body.split("\n");
  const out: string[] = [];
  let inList: "ul" | "ol" | null = null;
  let inCode = false;
  let codeLines: string[] = [];

  function flushList() {
    if (!inList) return;
    out.push(inList === "ul" ? "</ul>" : "</ol>");
    inList = null;
  }

  for (const raw of lines) {
    const line = raw;

    if (line.startsWith("```")) {
      if (!inCode) { inCode = true; codeLines = []; continue; }
      out.push(`<pre><code>${codeLines.join("\n")}</code></pre>`);
      inCode = false; codeLines = [];
      continue;
    }
    if (inCode) { codeLines.push(line); continue; }

    if (line.startsWith("# ")) { flushList(); out.push(`<h2>${inline(line.slice(2))}</h2>`); continue; }
    if (line.startsWith("## ")) { flushList(); out.push(`<h3>${inline(line.slice(3))}</h3>`); continue; }
    if (line.startsWith("### ")) { flushList(); out.push(`<h4>${inline(line.slice(4))}</h4>`); continue; }
    if (line.startsWith("> ")) { flushList(); out.push(`<blockquote>${inline(line.slice(2))}</blockquote>`); continue; }
    if (/^---+$/.test(line.trim())) { flushList(); out.push(`<hr/>`); continue; }

    const isUl = line.startsWith("- ") || line.startsWith("* ");
    const olMatch = line.match(/^(\d+)\. (.+)/);
    if (isUl) {
      if (inList !== "ul") { flushList(); out.push("<ul>"); inList = "ul"; }
      out.push(`<li>${inline(line.slice(2))}</li>`);
      continue;
    }
    if (olMatch) {
      if (inList !== "ol") { flushList(); out.push("<ol>"); inList = "ol"; }
      out.push(`<li>${inline(olMatch[2])}</li>`);
      continue;
    }

    flushList();
    if (line.trim() === "") { out.push("<br/>"); continue; }
    out.push(`<p>${inline(line)}</p>`);
  }
  flushList();
  return out.join("");
}

// ── category colours ───────────────────────────────────────────────────────

const CAT_PILL: Record<string, string> = {
  "Cycle Tracking": "bg-[#FFF1CC] text-[#8A6000]",
  "BBT & Temperature": "bg-[#E2FAE8] text-[#1A6B36]",
  "Ovulation Awareness": "bg-[#FFE8F5] text-[#8B2260]",
  "Wearable Insights": "bg-[#DCF9F4] text-[#0D6A5A]",
  "Wellness": "bg-[#ECE8FF] text-[#4A28AE]",
  "App Updates": "bg-[#FFF0E8] text-[#8B3800]",
};

const CAT_BG: Record<string, string> = {
  "Cycle Tracking": "#FFFBEE",
  "BBT & Temperature": "#F2FDF5",
  "Ovulation Awareness": "#FFF4FB",
  "Wearable Insights": "#EEFCFA",
  "Wellness": "#F5F3FF",
  "App Updates": "#FFF6F0",
};

function pillClass(cat: string | null) {
  return cat ? (CAT_PILL[cat] ?? "bg-[#FFF0E8] text-[#8B3800]") : "bg-[#FFF0E8] text-[#8B3800]";
}

function cardBg(cat: string | null) {
  return cat ? (CAT_BG[cat] ?? "#FFF6F0") : "#FFF6F0";
}

// ── article JSON-LD ────────────────────────────────────────────────────────

function articleSchema(post: Post) {
  return {
    "@context": "https://schema.org",
    "@type": "BlogPosting",
    headline: post.title,
    description: post.excerpt,
    url: `${BASE_URL}/blog/?post=${post.slug}`,
    datePublished: post.published_at ?? post.created_at,
    dateModified: post.updated_at,
    author: { "@type": "Person", name: post.author_name },
    publisher: {
      "@type": "Organization",
      name: "Vyla",
      url: BASE_URL,
      logo: { "@type": "ImageObject", url: `${BASE_URL}/assets/vyla-logo.png` },
    },
    ...(post.cover_image_url ? { image: post.cover_image_url } : {}),
    mainEntityOfPage: { "@type": "WebPage", "@id": `${BASE_URL}/blog/?post=${post.slug}` },
  };
}

// ── components ─────────────────────────────────────────────────────────────

function CategoryPill({ cat }: { cat: string | null }) {
  if (!cat) return null;
  return (
    <span className={`inline-block text-[10px] font-semibold tracking-[0.12em] uppercase px-2.5 py-1 rounded-full ${pillClass(cat)}`}>
      {cat}
    </span>
  );
}

function AuthorMeta({ post, dark = false }: { post: Post; dark?: boolean }) {
  const textColor = dark ? "text-white/70" : "text-[#B0938A]";
  const nameColor = dark ? "text-white/90" : "text-[#7A4A32]";
  return (
    <div className={`flex items-center gap-3 text-[12px] ${textColor}`}>
      <div className="w-6 h-6 rounded-full bg-gradient-to-br from-[#FF7A33] to-[#FFB38A] flex items-center justify-center text-white text-[9px] font-bold shrink-0">
        {(post.author_name[0] ?? "V").toUpperCase()}
      </div>
      <span className={`font-medium ${nameColor}`}>{post.author_name}</span>
      <span aria-hidden>·</span>
      <span>{readingTime(post.body)} min read</span>
      {post.published_at && (
        <>
          <span aria-hidden>·</span>
          <time dateTime={post.published_at}>{fmtDateShort(post.published_at)}</time>
        </>
      )}
    </div>
  );
}

// Featured hero card (first post)
function FeaturedCard({ post, onOpen }: { post: Post; onOpen: () => void }) {
  const shouldReduceMotion = useReducedMotion();
  return (
    <motion.article
      initial={shouldReduceMotion ? {} : { opacity: 0, y: 24 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.55 }}
      className="group cursor-pointer"
      onClick={onOpen}
      aria-label={`Read article: ${post.title}`}
    >
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-0 rounded-[24px] overflow-hidden border border-[#FFD9C2]/50 shadow-sm hover:shadow-xl hover:shadow-[#FF7A33]/6 transition-shadow duration-300">
        {/* Image / colour block */}
        <div className="relative h-72 lg:h-auto lg:min-h-[380px] overflow-hidden" style={{ backgroundColor: cardBg(post.category) }}>
          {post.cover_image_url ? (
            <img
              src={post.cover_image_url}
              alt={post.title}
              className="w-full h-full object-cover group-hover:scale-[1.03] transition-transform duration-700"
            />
          ) : (
            <div className="absolute inset-0 flex items-center justify-center" aria-hidden>
              <span className="text-7xl opacity-10 select-none">✦</span>
            </div>
          )}
          {/* Gradient overlay for the image */}
          {post.cover_image_url && (
            <div className="absolute inset-0 bg-gradient-to-t from-black/20 to-transparent" aria-hidden />
          )}
        </div>

        {/* Copy */}
        <div className="bg-white p-8 lg:p-12 flex flex-col justify-between">
          <div>
            <div className="flex items-center gap-3 mb-5">
              <span className="text-[10px] font-bold tracking-[0.16em] uppercase text-[#FF7A33]">Featured</span>
              {post.category && (
                <>
                  <span className="w-1 h-1 rounded-full bg-[#FFD9C2]" aria-hidden />
                  <CategoryPill cat={post.category} />
                </>
              )}
            </div>
            <h2 className="font-serif text-[32px] lg:text-[38px] leading-[1.08] tracking-[-0.02em] text-[#1E0C16] mb-4 group-hover:text-[#FF7A33] transition-colors duration-200">
              {post.title}
            </h2>
            {post.excerpt && (
              <p className="text-[15px] font-light text-[#7A4A32] leading-relaxed mb-6 line-clamp-3">
                {post.excerpt}
              </p>
            )}
          </div>
          <div className="flex items-center justify-between">
            <AuthorMeta post={post} />
            <span className="text-[13px] font-medium text-[#FF7A33] group-hover:gap-2 flex items-center gap-1.5 transition-all">
              Read <span aria-hidden>→</span>
            </span>
          </div>
        </div>
      </div>
    </motion.article>
  );
}

// Regular post card
function PostCard({ post, onOpen, index = 0 }: { post: Post; onOpen: () => void; index?: number }) {
  const shouldReduceMotion = useReducedMotion();
  return (
    <motion.article
      initial={shouldReduceMotion ? {} : { opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.45, delay: index * 0.06 }}
      className="group cursor-pointer bg-white rounded-[20px] border border-[#FFD9C2]/50 overflow-hidden hover:shadow-lg hover:shadow-[#FF7A33]/5 transition-all duration-300"
      onClick={onOpen}
      aria-label={`Read article: ${post.title}`}
    >
      {/* Thumbnail */}
      {post.cover_image_url ? (
        <div className="h-48 overflow-hidden">
          <img
            src={post.cover_image_url}
            alt={post.title}
            className="w-full h-full object-cover group-hover:scale-[1.04] transition-transform duration-500"
          />
        </div>
      ) : (
        <div className="h-48 flex items-center justify-center" style={{ backgroundColor: cardBg(post.category) }} aria-hidden>
          <span className="text-5xl opacity-10 select-none">✦</span>
        </div>
      )}

      <div className="p-6">
        <CategoryPill cat={post.category} />
        <h3 className="font-serif text-[22px] leading-[1.15] text-[#1E0C16] mt-3 mb-2 group-hover:text-[#FF7A33] transition-colors duration-200 line-clamp-2">
          {post.title}
        </h3>
        <p className="text-[13px] font-light text-[#A06A52] leading-relaxed line-clamp-2 mb-5">
          {post.excerpt}
        </p>
        <AuthorMeta post={post} />
      </div>
    </motion.article>
  );
}

// Skeleton card
function SkeletonCard({ featured = false }: { featured?: boolean }) {
  if (featured) {
    return (
      <div className="grid grid-cols-1 lg:grid-cols-2 rounded-[24px] overflow-hidden border border-[#FFD9C2]/40 h-80 lg:h-[380px] animate-pulse bg-[#FFF6F0]" />
    );
  }
  return (
    <div className="bg-[#FFF6F0] rounded-[20px] border border-[#FFD9C2]/40 h-72 animate-pulse" />
  );
}

// ── Post detail ────────────────────────────────────────────────────────────

function PostDetail({ post, allPosts, onClose }: { post: Post; allPosts: Post[]; onClose: () => void }) {
  const related = allPosts.filter(p => p.id !== post.id && p.category === post.category).slice(0, 3);
  const others = related.length < 3
    ? [...related, ...allPosts.filter(p => p.id !== post.id && p.category !== post.category)].slice(0, 3)
    : related;

  useEffect(() => {
    const prev = document.title;
    document.title = `${post.title} | Vyla`;
    window.scrollTo({ top: 0, behavior: "instant" as ScrollBehavior });
    return () => { document.title = prev; };
  }, [post.title]);

  return (
    <div className="min-h-screen bg-[#FFF6F0]">
      <JsonLd data={articleSchema(post)} />
      <Nav />

      <main className="pt-16" id="main-content">
        {/* Cover image */}
        {post.cover_image_url && (
          <div className="w-full h-72 lg:h-[420px] overflow-hidden">
            <img
              src={post.cover_image_url}
              alt={post.title}
              className="w-full h-full object-cover"
            />
          </div>
        )}

        <div className="max-w-[740px] mx-auto px-6 py-14">
          {/* Breadcrumb */}
          <nav aria-label="Breadcrumb" className="mb-8">
            <ol className="flex items-center gap-2 text-[11px] text-[#A06A52]">
              <li><Link href="/" className="hover:text-[#FF7A33] transition-colors">Home</Link></li>
              <li aria-hidden>/</li>
              <li><button onClick={onClose} className="hover:text-[#FF7A33] transition-colors">Blog</button></li>
              <li aria-hidden>/</li>
              <li className="text-[#1E0C16] truncate max-w-[220px]" aria-current="page">{post.title}</li>
            </ol>
          </nav>

          <CategoryPill cat={post.category} />

          <h1 className="font-serif text-[44px] lg:text-[56px] leading-[1.05] tracking-[-0.03em] text-[#1E0C16] mt-4 mb-5">
            {post.title}
          </h1>

          {post.excerpt && (
            <p className="text-[18px] lg:text-[20px] font-light text-[#7A4A32] leading-relaxed italic mb-8">
              {post.excerpt}
            </p>
          )}

          {/* Meta row */}
          <div className="flex flex-wrap items-center gap-x-4 gap-y-2 text-[13px] text-[#B0938A] pb-8 border-b border-[#FFD9C2]/60 mb-10">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-full bg-gradient-to-br from-[#FF7A33] to-[#FFB38A] flex items-center justify-center text-white text-[11px] font-bold">
                {(post.author_name[0] ?? "V").toUpperCase()}
              </div>
              <span className="font-medium text-[#7A4A32]">{post.author_name}</span>
            </div>
            <span aria-hidden>·</span>
            <span>{readingTime(post.body)} min read</span>
            {post.published_at && (
              <>
                <span aria-hidden>·</span>
                <time dateTime={post.published_at}>{fmtDate(post.published_at)}</time>
              </>
            )}
          </div>

          {/* Body */}
          <div className="blog-body" dangerouslySetInnerHTML={{ __html: renderMarkdown(post.body) }} />

          {/* Tags */}
          {post.tags.length > 0 && (
            <div className="flex flex-wrap gap-2 mt-14 pt-8 border-t border-[#FFD9C2]/60">
              {post.tags.map(tag => (
                <span key={tag} className="text-[12px] text-[#A06A52] bg-white px-3 py-1 rounded-full border border-[#FFD9C2]/70">
                  {tag}
                </span>
              ))}
            </div>
          )}

          {/* Bottom CTA */}
          <div className="mt-12 pt-8 border-t border-[#FFD9C2]/60 flex flex-col sm:flex-row items-start sm:items-center gap-4 justify-between">
            <button
              onClick={onClose}
              className="text-[14px] font-medium text-[#A06A52] hover:text-[#FF7A33] transition-colors flex items-center gap-1.5"
            >
              ← Back to all articles
            </button>
            <a
              href="https://apps.apple.com/app/vyla"
              className="text-[14px] font-medium bg-[#FF7A33] text-white px-6 py-3 rounded-full hover:bg-[#e86a22] transition-colors"
            >
              Try Vyla free →
            </a>
          </div>
        </div>

        {/* Related articles */}
        {others.length > 0 && (
          <section className="bg-white border-t border-[#FFD9C2]/40 py-16">
            <div className="max-w-[1200px] mx-auto px-6">
              <h2 className="font-serif text-[28px] text-[#1E0C16] tracking-[-0.02em] mb-8">
                More articles
              </h2>
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
                {others.map((p, i) => (
                  <PostCard key={p.id} post={p} index={i} onOpen={() => {
                    // push to URL without a router dependency in this sub-component
                    window.history.pushState({}, "", `/blog/?post=${p.slug}`);
                    window.dispatchEvent(new PopStateEvent("popstate"));
                  }} />
                ))}
              </div>
            </div>
          </section>
        )}
      </main>

      <Footer />
    </div>
  );
}

// ── Topics (shown when no posts or below grid) ─────────────────────────────

const TOPICS = [
  { title: "Cycle Tracking", desc: "Guides on logging periods, reading cycle phases, and getting the most from Vyla's tracking features.", href: "/cycle-tracking/", color: "#FFFBEE" },
  { title: "BBT & Temperature", desc: "How to measure basal body temperature, chart thermal shifts, and understand ovulation timing.", href: "/bbt-tracking/", color: "#F2FDF5" },
  { title: "Ovulation Awareness", desc: "LH surges, cervical mucus, fertile windows, and interpreting ovulation signals across cycles.", href: "/ovulation-tracking/", color: "#FFF4FB" },
  { title: "Wearable Insights", desc: "Using Oura Ring alongside cycle tracking — what temperature and HRV data reveal about your cycle.", href: "/wearable-cycle-insights/", color: "#EEFCFA" },
];

// ── Main blog listing ──────────────────────────────────────────────────────

function BlogListing({ posts, loading }: { posts: Post[]; loading: boolean }) {
  const shouldReduceMotion = useReducedMotion();
  const [activeCategory, setActiveCategory] = useState<string | null>(null);
  const router = useRouter();

  const categories = Array.from(new Set(posts.map(p => p.category).filter(Boolean) as string[]));
  const filtered = activeCategory ? posts.filter(p => p.category === activeCategory) : posts;
  const featured = filtered[0] ?? null;
  const rest = filtered.slice(1);

  function openPost(slug: string) {
    router.push(`/blog/?post=${slug}`, { scroll: false });
  }

  return (
    <div className="min-h-screen bg-[#FFF6F0]">
      <JsonLd data={blogPageSchema()} />
      <Nav />

      <main className="pt-16" id="main-content">
        {/* Hero header */}
        <section className="bg-[#FFF6F0] pt-20 pb-16 lg:pt-24 lg:pb-20">
          <div className="max-w-[1200px] mx-auto px-6">
            <nav aria-label="Breadcrumb" className="mb-10">
              <ol className="flex items-center gap-2 text-[11px] text-[#A06A52]">
                <li><Link href="/" className="hover:text-[#FF7A33] transition-colors">Home</Link></li>
                <li aria-hidden>/</li>
                <li aria-current="page" className="text-[#1E0C16]">Blog</li>
              </ol>
            </nav>

            <div className="max-w-[680px]">
              <motion.p
                initial={shouldReduceMotion ? {} : { opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.5 }}
                className="text-[11px] font-semibold tracking-[0.14em] uppercase text-[#FF7A33] mb-4"
              >
                Articles &amp; guides
              </motion.p>
              <motion.h1
                initial={shouldReduceMotion ? {} : { opacity: 0, y: 16 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.55, delay: 0.06 }}
                className="font-serif text-[54px] lg:text-[72px] leading-[1.04] tracking-[-0.03em] text-[#1E0C16] mb-5"
              >
                Cycle health,<br />
                <em className="text-[#FF7A33] not-italic">clearly explained.</em>
              </motion.h1>
              <motion.p
                initial={shouldReduceMotion ? {} : { opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.5, delay: 0.12 }}
                className="text-[17px] font-light text-[#A06A52] leading-relaxed"
              >
                In-depth guides on cycle tracking, BBT temperature charting, ovulation awareness, wearable insights, and women&apos;s wellness — from the Vyla team.
              </motion.p>
            </div>
          </div>
        </section>

        {/* Category filter */}
        {!loading && categories.length > 1 && (
          <section className="bg-white border-y border-[#FFD9C2]/40 py-4 sticky top-16 z-30">
            <div className="max-w-[1200px] mx-auto px-6">
              <div className="flex items-center gap-2 overflow-x-auto scrollbar-hide pb-0.5">
                <button
                  onClick={() => setActiveCategory(null)}
                  className={`shrink-0 text-[12px] font-medium px-4 py-1.5 rounded-full border transition-colors ${
                    activeCategory === null
                      ? "bg-[#1E0C16] text-white border-[#1E0C16]"
                      : "bg-white text-[#A06A52] border-[#FFD9C2] hover:border-[#FF7A33] hover:text-[#FF7A33]"
                  }`}
                >
                  All
                </button>
                {categories.map(cat => (
                  <button
                    key={cat}
                    onClick={() => setActiveCategory(activeCategory === cat ? null : cat)}
                    className={`shrink-0 text-[12px] font-medium px-4 py-1.5 rounded-full border transition-colors ${
                      activeCategory === cat
                        ? "bg-[#FF7A33] text-white border-[#FF7A33]"
                        : "bg-white text-[#A06A52] border-[#FFD9C2] hover:border-[#FF7A33] hover:text-[#FF7A33]"
                    }`}
                  >
                    {cat}
                  </button>
                ))}
              </div>
            </div>
          </section>
        )}

        {/* Posts */}
        <section className="bg-white py-16 lg:py-20 border-t border-[#FFD9C2]/40">
          <div className="max-w-[1200px] mx-auto px-6">
            {loading ? (
              <div className="space-y-10">
                <SkeletonCard featured />
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
                  <SkeletonCard /><SkeletonCard /><SkeletonCard />
                </div>
              </div>
            ) : filtered.length > 0 ? (
              <div className="space-y-10">
                {featured && (
                  <FeaturedCard post={featured} onOpen={() => openPost(featured.slug)} />
                )}
                {rest.length > 0 && (
                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
                    {rest.map((post, i) => (
                      <PostCard key={post.id} post={post} index={i} onOpen={() => openPost(post.slug)} />
                    ))}
                  </div>
                )}
              </div>
            ) : (
              <div className="py-16 text-center">
                <div className="w-14 h-14 rounded-full bg-[#FFF0E8] border border-[#FFD9C2] flex items-center justify-center mx-auto mb-5" aria-hidden>
                  <span className="text-[#FF7A33] text-xl">✦</span>
                </div>
                <p className="font-serif text-[24px] text-[#1E0C16] mb-2">
                  {activeCategory ? `No articles in "${activeCategory}" yet` : "Articles coming soon"}
                </p>
                <p className="text-[14px] font-light text-[#A06A52] leading-relaxed">
                  {activeCategory
                    ? "Try a different category or browse all articles."
                    : "The Vyla blog is growing — check back soon for guides on cycle health, BBT charting, and wearable insights."}
                </p>
                {activeCategory && (
                  <button onClick={() => setActiveCategory(null)} className="mt-5 text-[13px] font-medium text-[#FF7A33] hover:text-[#e86a22] transition-colors">
                    View all articles →
                  </button>
                )}
              </div>
            )}
          </div>
        </section>

        {/* Topics */}
        <section className="bg-[#FFF6F0] py-16 lg:py-20 border-t border-[#FFD9C2]/40" aria-labelledby="topics-heading">
          <div className="max-w-[1200px] mx-auto px-6">
            <h2 id="topics-heading" className="font-serif text-[32px] lg:text-[36px] text-[#1E0C16] tracking-[-0.02em] mb-10">
              Browse by topic
            </h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
              {TOPICS.map(topic => (
                <Link
                  key={topic.title}
                  href={topic.href}
                  className="group rounded-[20px] border border-[#FFD9C2]/60 p-7 hover:shadow-md hover:shadow-[#FF7A33]/5 hover:border-[#FFD9C2] transition-all"
                  style={{ backgroundColor: topic.color }}
                >
                  <h3 className="text-[20px] font-semibold text-[#1E0C16] mb-3 group-hover:text-[#FF7A33] transition-colors">{topic.title}</h3>
                  <p className="text-[14px] font-light text-[#7A4A32] leading-relaxed mb-5">{topic.desc}</p>
                  <span className="text-[13px] font-medium text-[#FF7A33] flex items-center gap-1.5">
                    Explore <span aria-hidden>→</span>
                  </span>
                </Link>
              ))}
            </div>
          </div>
        </section>

        {/* Download CTA */}
        <section className="bg-[#1E0C16] py-16 lg:py-20">
          <div className="max-w-[680px] mx-auto px-6 text-center">
            <p className="font-serif text-[36px] lg:text-[44px] leading-[1.1] tracking-[-0.02em] text-white mb-4">
              Put the knowledge to work.
            </p>
            <p className="text-[16px] font-light text-white/60 leading-relaxed mb-8">
              Download Vyla and start tracking your cycle, BBT, and wearable data — all in one private app.
            </p>
            <div className="flex flex-col sm:flex-row items-center justify-center gap-3">
              <a
                href="https://apps.apple.com/app/vyla"
                className="flex items-center gap-2 bg-white text-[#1E0C16] px-6 py-3 rounded-full text-[14px] font-semibold hover:bg-[#FFF0E8] transition-colors"
              >
                <AppleIcon /> App Store
              </a>
              <a
                href="https://play.google.com/store/apps/details?id=com.vyla.app"
                className="flex items-center gap-2 bg-[#FF7A33] text-white px-6 py-3 rounded-full text-[14px] font-semibold hover:bg-[#e86a22] transition-colors"
              >
                <GoogleIcon /> Google Play
              </a>
            </div>
          </div>
        </section>
      </main>

      <Footer />
    </div>
  );
}

// ── Store icons ────────────────────────────────────────────────────────────

function AppleIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
    </svg>
  );
}

function GoogleIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden>
      <path d="M3.18 23.54c.37.2.8.22 1.19.07l11.44-6.6L13.1 14.3 3.18 23.54z" fill="#EA4335" />
      <path d="M20.32 10.14 17.5 8.47l-3.2 2.9 3.2 3.2 2.84-1.64c.81-.47.81-1.32-.02-1.79z" fill="#FBBC05" />
      <path d="M3.18.46c-.12.22-.18.47-.18.73v21.62l9.92-9.9L3.18.46z" fill="#4285F4" />
      <path d="M13.1 9.7 4.37.37C3.98.21 3.55.23 3.18.46l9.92 9.24L13.1 9.7z" fill="#34A853" />
    </svg>
  );
}

// ── Root component ─────────────────────────────────────────────────────────

function BlogContent() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const postSlug = searchParams.get("post");

  const [posts, setPosts] = useState<Post[]>([]);
  const [loading, setLoading] = useState(true);
  const [activePost, setActivePost] = useState<Post | null>(null);
  const [postLoading, setPostLoading] = useState(false);

  useEffect(() => {
    fetch(`${API_BASE}/api/v1/public/blog?page_size=50`)
      .then(r => r.ok ? r.json() : { items: [] })
      .then(d => setPosts(d.items ?? []))
      .catch(() => setPosts([]))
      .finally(() => setLoading(false));
  }, []);

  // Load post from ?post=slug
  useEffect(() => {
    if (!postSlug) { setActivePost(null); return; }
    const existing = posts.find(p => p.slug === postSlug);
    if (existing) { setActivePost(existing); return; }
    if (loading) return; // wait for initial load
    setPostLoading(true);
    fetch(`${API_BASE}/api/v1/public/blog/${postSlug}`)
      .then(r => r.ok ? r.json() : null)
      .then(p => setActivePost(p))
      .catch(() => setActivePost(null))
      .finally(() => setPostLoading(false));
  }, [postSlug, posts, loading]);

  function closePost() {
    router.push("/blog/", { scroll: false });
    setActivePost(null);
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  if (postLoading) {
    return (
      <div className="min-h-screen bg-[#FFF6F0] flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-[#FF7A33] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (activePost) {
    return <PostDetail post={activePost} allPosts={posts} onClose={closePost} />;
  }

  return <BlogListing posts={posts} loading={loading} />;
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
