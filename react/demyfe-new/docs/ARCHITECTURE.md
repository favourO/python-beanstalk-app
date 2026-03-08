# Architecture Overview

This project follows a layered architecture optimized for production scale.

## Layers

- `src/app`: Next.js routing, layouts, metadata, and route-level composition.
- `src/modules`: domain modules (feature screens, components, and data).
- `src/shared`: cross-domain primitives (config, utilities, reusable UI).

## Rules

- Keep route files thin; delegate implementation to `src/modules`.
- Keep module logic domain-scoped; avoid cross-module imports by default.
- Put generic primitives in `src/shared` only when reusable across modules.
- Keep environment access centralized in `src/shared/config/env.ts`.

## Figma Integration Strategy

- Create one screen module per page or major frame group.
- Extract repeatable sections/components before building variants.
- Keep tokens (spacing, colors, typography) in global CSS variables.
