# AFUP PHP Demo kit

Reference for the Docker Sandboxes kit used in the "Docker Sandboxes" talk
(Forum PHP 2026 / INSA). It runs Claude Code exactly the way Demo 1 does
without a kit — same template, same agent — but pre-allows the two network
hosts Composer's own installer needs, which the `balanced` network policy
blocks (confirmed by rehearsal).

- To run it: [`../DEMO.md`](../DEMO.md), or
  [Create or re-attach the demo sandbox](../docs/how-to.md#create-or-re-attach-the-demo-sandbox).
- To understand the choices: [`../docs/explanation.md`](../docs/explanation.md).
- The talk introduces kits on slide 30 of
  [the slides](../slides/afup-docker-sandboxes.pdf).

```
sbx run --name afup ./kit/ .
```

## Files

| File | Role |
|---|---|
| `afup-php-demo.yaml` | The v3 descriptor: metadata and capabilities. |
| `afup-php-demo.dockerfile` | The recipe: base image and entrypoint. |
| `afup-php-demo-context.md` | The instructions the agent reads. |

## What it declares

| Declaration | Value |
|---|---|
| Format | v3 (`# syntax=docker/sandbox-kit:3`, `schemaVersion: "3"`), `kind: workload` |
| Version, license | `0.1.0`, MIT |
| Base image | `docker/sandbox-templates:claude-code-docker` |
| Entrypoint | `claude --dangerously-skip-permissions` |
| `sbx@1` | The host launches the agent rather than running the image entrypoint as PID 1. |
| `network-policy@1` | `runtime` allow: `getcomposer.org:443`, `composer.github.io:443`. No install-phase hosts, no deny rules. |
| `agent-context@1` | `CLAUDE.md`, built from `afup-php-demo-context.md`. |
| Credentials | None. |

## What it changes vs. plain `sbx run claude .`

- **Network**: pre-allows `getcomposer.org:443` and `composer.github.io:443`,
  so `composer install`'s official installer works without any
  `sbx policy allow` step. Why they're blocked otherwise:
  [explanation](../docs/explanation.md#why-the-composer-hosts-are-blocked).
- **Agent instructions**: adds a short note, staged at
  `/usr/share/sandbox/kit/afup-php-demo/afup-php-demo-context.md` and
  referenced from the generated `CLAUDE.md`, mentioning that those two hosts
  are already allowed.
- Nothing else. Same `docker/sandbox-templates:claude-code-docker` image,
  same `claude` binary — this kit is a thin permissions/instructions layer,
  not a custom environment.

## Requirements

- `sbx` v0.45 or later. A v3 kit can't be combined with v1 or v2 kits in the
  same sandbox.
- A buildx builder that can export OCI images:
  [Let sbx build the kit](../docs/how-to.md#let-sbx-build-the-kit).
- The kit reference (`./kit/`) goes where the agent name normally goes. The
  old `--kit` form no longer works, see the
  [version table](../docs/reference.md#sbx-versions).

## Differences from the v2 kit

This kit replaces a v2 `spec.yaml`. See
[What changed between the v2 and v3 kit](../docs/explanation.md#what-changed-between-the-v2-and-v3-kit).

## Verification status

Checked on `sbx` v0.47.0 on 2026-10-08:
- `sbx kit inspect ./kit/` → `Schema: v3`, `Run Options:
  --dangerously-skip-permissions`, `Network: 2 allow, 0 deny`.
- `docker buildx build ./kit -f ./kit/afup-php-demo.yaml` builds and validates
  the descriptor. The image config comes out as `user=agent`,
  `workdir=/home/agent/workspace`,
  `entrypoint=[claude, --dangerously-skip-permissions]`.
- `sbx run --detached ./kit/ .` creates the sandbox; `getcomposer.org` and
  `composer.github.io` return `200`, `example.com` stays blocked (`403`).
- The staged instructions file contains the expected text, and the generated
  `CLAUDE.md` points to it.

**Not re-run on v3**: an interactive `sbx run` (the permission-prompt-free
entrypoint and the `/login` flow) and the full Demo 1 flow.
