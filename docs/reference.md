# Reference

Facts to look up: versions, tags, and how the slides and the real CLI differ.
For the kit's own declarations, see [`../kit/README.md`](../kit/README.md).

## `sbx` versions

| Version | What matters |
|---|---|
| `v0.45` or later | Required by the v3 kit in `kit/`. |
| `v0.42.1` | `--kit` is repurposed for **mixins** (an additional layer on a built-in agent, e.g. `sbx run claude --kit ./my-mixin/`) and no longer accepts a full agent kit. The old form `sbx run --kit ./kit/ afup-php-demo .` warns "deprecated", then fails. Mountless mode (`sbx create --name scratch claude`, no PATH; slide 19's example) works as written and reports `workspace: none · no workspace bind mount`. |
| `v0.39.0` | Mountless mode fails with `ERROR: requires at least 1 argument: PATH`. That's a version-support gap, not a slide bug. Most of the rehearsal log was run on this version. |
| `v0.47.0` | The kit was checked on this version, see [`../kit/README.md`](../kit/README.md#verification-status). |

A Docker Engine `sbx` can use is also required (Docker Desktop or any other
engine; there's no dependency on Desktop specifically). See
https://docs.docker.com/ai/sandboxes/.

## Global network policy

`sbx` asks for a global network policy the first time it runs. It's a one-time
setup; `sbx policy reset` clears all policies so you can start over.

| Mode | Effect |
|---|---|
| `allow-all` | All outbound network traffic is allowed. |
| `balanced` | Typical development traffic is allowed, such as AI services and package registries. |
| `deny-all` | All outbound network traffic is blocked. |

The demo assumes `balanced`. Kit rules apply on top, for the kit's own
sandbox. Commands: `sbx policy init <mode>`, `sbx policy check network <host>`,
`sbx policy ls`. See [Set the global network policy](how-to.md#set-the-global-network-policy).

## Git tags

| Tag | Contents |
|---|---|
| `demo-start` | The starting point of the demo: the 2 one-line bugs from Demo 1 are present, nothing is installed, nothing is running. |
| `demo-fixed` | Same repo, bugs already fixed, tests green. |

`git diff demo-start demo-fixed -- src/` shows what the fix touches.

## Slides

The slide numbers in these docs refer to
[`slides/afup-docker-sandboxes.pdf`](../slides/afup-docker-sandboxes.pdf) as it
was on 2026-10-08. If you reorder the deck, update them.

| Slides | Topic | Used in |
|---|---|---|
| 5–8 | Permission fatigue: what an agent inherits when you accept every prompt | [Why the entrypoint carries the flag](explanation.md#why-the-entrypoint-carries---dangerously-skip-permissions) |
| 15–18 | The boundary, `sbx run`, architecture, isolation layers | Demos 1 and 2 |
| 19 | Workspace modes: mountless, direct mount, clone | Demo 2, [version table](#sbx-versions) |
| 20 | Credential isolation | Demo 2, optional aside |
| 21 | Live demo: demos 1 and 2 | Demos 1 and 2 |
| 23–26 | Policies, rule evaluation, network rules, filesystem rules | Demo 3 |
| 27 | MCP gateway | Demo 4 |
| 28 | Audit logs, `sbx policy log` | Demo 3 |
| 29 | Live demo: demos 3 and 4 | Demos 3 and 4 |
| 30 | Beyond the basics, including templates and kits | The kit |

## Slide / CLI mismatches

Verified live against a real `sbx` sandbox, not just `--help`.

| Slide / README says | Real CLI / behavior | Fix needed |
|---|---|---|
| `sbx port afup 8000:8000` (slide 21) | Command is **`sbx ports`** (plural): `sbx ports afup --publish 8000:8000`. Confirmed live — publish/curl 200, unpublish/curl fails. | Fix slide 21's command |
| `sbx secret set GITHUB_TOKEN --from-env` (slide 20) | No `--from-env` flag. Service name is lowercase (`github`, one of a fixed list); value comes from stdin or `-t`: `echo "$GITHUB_TOKEN" \| sbx secret set github` | Fix slide 20's command and the env-var-shaped service name |
| Blocked request shows a one-line "hint: sbx policy allow network ..." (slide 25) | Real body is two lines, no `sbx policy allow` hint at all: `Blocked by network policy: domain X:443` / `detail: no matching allow rule — blocked by default deny policy`. Confirmed live on `getcomposer.org`. Also: `-I`/HEAD-only curl shows just `403 Forbidden`, no body — use plain `curl`. | Fix slide 25's example body, and note the `-I` gotcha |
| `sbx policy log` shows one flat table (slide 28) | Real output has **two sections** ("Blocked requests" / "Allowed requests") with more columns: `SANDBOX TYPE HOST PROXY RULE REASON LAST SEEN COUNT`. Confirmed live. | Fix slide 28's table shape, or crop a real screenshot instead of retyping it |
| `sbx policy deny network **.ads.example` (slide 25) | Not exercised live (nothing to demonstrate it on) — `--help` only documents `*.example.com` (one level) and bare `**` (all hosts) | Still to verify; if unsupported, fix slide 25's pattern table |
| Filesystem rules implied settable like network, e.g. "Typical org policy: Allow `~/src/**` read + write" (slide 26) | Filesystem rules exist and are inspectable locally (`sbx policy ls --type filesystem`, `sbx policy inspect <rule-id>`) — default is `read: allow **` / `write: allow **`, i.e. unrestricted by default. But `sbx policy allow`/`deny`/`rm` only have a `network` subcommand, never `filesystem`. `sbx policy inspect default-fs-read-allow-all` says outright: "Editable: no — filesystem rules cannot be modified with the CLI". Confirmed live on `sbx v0.42.1`. | Slide 26's example is only reachable via org governance (Docker Home / Governance API), not a local CLI command the way network rules are — worth saying explicitly, since the network/filesystem symmetry on slides 25 and 26 suggests otherwise |

Confirmed to match reality as written, live: `sbx create --name <name> claude .`,
`sbx exec <name> -- <cmd>`, `sbx policy allow network <host>`, `sbx policy ls <name>`,
`sbx policy log <name>`, `sbx mcp ls`. Believed correct but not exercised live
(no OAuth done): `sbx mcp add <name> --url <url>`, `sbx mcp load <name> --sandbox <name>`,
`sbx run claude --name <name> --static-mcp <name>`.

One thing that turned out **not** to be a mismatch: `github.com` and
`objects.githubusercontent.com` are reachable under the `balanced` policy
(200/404, not blocked) — only `getcomposer.org` and `composer.github.io` are
blocked.
