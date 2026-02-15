# Maintainers

This folder is for *maintainers* (not required for end-users).

Goal: create a repeatable maintenance system that:
- preserves the original intent and past成果
- enables stable, incremental iteration
- minimizes “works on my machine” and copy/paste breakage for non-technical users
- never leaks secrets or personal identifiers

## Operating principles

- **Incremental changes only** (small blast radius).
- **CLI-first verification**: every change should include a way to verify locally.
- **Compatibility-first**: prefer minimal config snippets over shipping full `openclaw.json`.
- **Desensitized by default**: no real tokens, IDs, user names, or absolute `/Users/...` paths.

## What to update when…

- Targeting a new OpenClaw version:
  - Add a new config snippet doc `docs/CONFIG_SNIPPET_<version>.md`.
  - Keep the old snippet; don’t overwrite it.
  - Update README to point to the newest snippet.

- Changing workflows / shared rules:
  - Update `shared/*.md` and relevant `workspaces/*/*.md`.
  - Add a note to `docs/DECISIONS.md`.

- Publishing a release:
  - Push to `main` first.
  - Test deploy on a clean machine/user.
  - Only then tag (e.g. `v0.1.0`).
