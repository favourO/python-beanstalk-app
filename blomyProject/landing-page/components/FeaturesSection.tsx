"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import Image from "next/image";
import FadeIn from "./FadeIn";
import SectionLabel from "./SectionLabel";

const tabs = [
  {
    id: "today",
    pill: { label: "Today", bg: "#FFE0CC", color: "#6E1836" },
    title: "Today screen",
    description:
      "See where you are in your current cycle, what may be coming next, and what is useful to log today.",
  },
  {
    id: "predictions",
    pill: { label: "Predict", bg: "#C8ECD9", color: "#1D6A3D" },
    title: "Cycle predictions",
    description:
      "View estimated period dates, fertile windows, and ovulation timing based on the information you record.",
  },
  {
    id: "log",
    pill: { label: "Log", bg: "#FFE0CC", color: "#6E1836" },
    title: "Daily logging",
    description:
      "Record periods, flow, symptoms, mood, pain, discharge, temperature, LH tests, intimacy, notes, and more in seconds.",
  },
  {
    id: "insights",
    pill: null,
    title: "Cycle insights",
    description:
      "Spot recurring patterns across cycles, including changes in energy, mood, cravings, sleep, stress, and symptoms.",
  },
  {
    id: "reminders",
    pill: { label: "Remind", bg: "#FAE3B0", color: "#72440B" },
    title: "Reminders",
    description:
      "Set gentle reminders for period tracking, fertile window awareness, daily logs, and other cycle-related prompts. You control what you receive.",
  },
];

export default function FeaturesSection() {
  const [activeTab, setActiveTab] = useState("reminders");

  return (
    <section id="features" className="bg-[#FFF6F0] py-24 lg:py-32">
      <div className="max-w-[1200px] mx-auto px-6">
        <div className="flex flex-col lg:flex-row gap-10 items-start">
          {/* Left: Label + Heading + Tab list */}
          <FadeIn className="w-full lg:w-[463px] shrink-0">
            <div className="flex flex-col">
              <SectionLabel>Features</SectionLabel>
              <h2 className="font-serif text-[52px] lg:text-[56px] leading-[1.1] tracking-[-0.02em] text-[#1E0C16] mb-10 max-w-[480px]">
                Everything you need to{" "}
                <span className="text-[#FF7A33]">follow your cycle</span>
              </h2>
              {tabs.map((tab) => {
                const isActive = activeTab === tab.id;
                return (
                  <button
                    key={tab.id}
                    onClick={() => setActiveTab(tab.id)}
                    className={`w-full text-left rounded-[14px] transition-all duration-200 cursor-pointer ${
                      isActive
                        ? "bg-white shadow-[0px_4px_16px_0px_rgba(74,44,26,0.08)] px-5 py-4"
                        : "px-5 py-[18px] hover:bg-white/50"
                    }`}
                  >
                    {/* Pill + Title row */}
                    <div className="flex items-center gap-4">
                      {tab.pill ? (
                        <span
                          className="shrink-0 rounded-full px-2.5 py-1 text-[9px] font-medium tracking-[0.1em]"
                          style={{ backgroundColor: tab.pill.bg, color: tab.pill.color }}
                        >
                          {tab.pill.label}
                        </span>
                      ) : (
                        /* AI tab — plain label text, no pill */
                        <span className="shrink-0 text-[9px] font-medium tracking-[0.1em] text-[#1E0C16] px-2.5 py-1">
                          AI
                        </span>
                      )}
                      <span className={`text-[15px] font-medium leading-snug ${isActive ? "text-[#1E0C16]" : "text-[#1E0C16]/60"}`}>
                        {tab.title}
                      </span>
                    </div>

                    {/* Description — only on active tab */}
                    <AnimatePresence initial={false}>
                      {isActive && (
                        <motion.p
                          key="desc"
                          initial={{ opacity: 0, height: 0 }}
                          animate={{ opacity: 1, height: "auto" }}
                          exit={{ opacity: 0, height: 0 }}
                          transition={{ duration: 0.2 }}
                          className="text-[13px] font-light text-[#A06A52] leading-[1.55] mt-2 overflow-hidden"
                          style={{ paddingLeft: "calc(2.5rem + 16px)" /* align under title */ }}
                        >
                          {tab.description}
                        </motion.p>
                      )}
                    </AnimatePresence>
                  </button>
                );
              })}
            </div>
          </FadeIn>

          {/* Right: App screenshot — 603×544 from Figma, top-aligned */}
          <FadeIn className="flex-1 w-full" delay={0.2}>
            <div className="relative w-full rounded-[19px] overflow-hidden aspect-[603/544] lg:aspect-auto lg:h-[544px]">
              <Image
                src="https://vyla.health/assets/images/features-app.png"
                alt="Vyla app features"
                fill
                className="object-cover object-center"
                sizes="(max-width: 1024px) 100vw, 603px"
              />
            </div>
          </FadeIn>
        </div>
      </div>
    </section>
  );
}
