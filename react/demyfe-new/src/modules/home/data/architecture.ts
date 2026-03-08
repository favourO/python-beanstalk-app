export const architectureSummary = {
  title: "Production Architecture Baseline",
  description:
    "This repository is intentionally reduced to architecture-only scaffolding: route composition, domain modules, and shared primitives.",
};

export const architectureLayers = [
  {
    name: "App Layer",
    path: "src/app",
    purpose: "Routing, layout, metadata, and page composition entry points.",
  },
  {
    name: "Modules Layer",
    path: "src/modules",
    purpose: "Domain-owned screens, components, and data contracts.",
  },
  {
    name: "Shared Layer",
    path: "src/shared",
    purpose: "Reusable utilities, configuration, and cross-domain UI primitives.",
  },
];

export const architectureRules = [
  "Keep route files thin and delegate implementation to modules.",
  "Keep domain logic inside module boundaries.",
  "Move code into shared only when used by multiple modules.",
  "Keep environment access centralized in shared config.",
];

export const architectureFiles = [
  "src/app/(marketing)/page.tsx",
  "src/modules/home/screens/home-screen.tsx",
  "src/shared/config/*",
  "docs/ARCHITECTURE.md",
];
