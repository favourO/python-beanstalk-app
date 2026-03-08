# Demy FE Architecture

Architecture-only Next.js starter.

## Stack

- Next.js 16 + React 19 + TypeScript (strict)
- Tailwind CSS v4
- ESLint

## Quick Start

```bash
npm run dev
```

## Architecture Layout

- `src/app`: route composition and global layout
- `src/modules`: domain-owned screens/components/data
- `src/shared`: reusable config, utilities, and UI primitives
- `docs/ARCHITECTURE.md`: architecture rules and layering guidance

## Validation

```bash
npm run lint
npm run typecheck
npm run build
```
