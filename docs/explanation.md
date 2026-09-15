# Explanation

Background on why the demo and its kit are set up the way they are. Nothing
here is a step to follow: for steps see [`../DEMO.md`](../DEMO.md) and
[`how-to.md`](how-to.md).

## Why a kit instead of `sbx policy allow` by hand

The manual command still works and is the no-kit fallback in the
[how-to](how-to.md#allow-the-composer-hosts-without-the-kit). The kit exists
so anyone cloning this repo to replay the demo gets the same reproducible
environment without having to know about the gotchas first.

Slide 30 presents kits as a way to "ship network rules with the kit".

## Why the Composer hosts are blocked

`getcomposer.org` and `composer.github.io` are blocked, so the official
Composer installer can't be used as-is. The demo assumes the `balanced` global
network policy ([reference](reference.md#global-network-policy)): it allows
AI services and package registries, and denies every host it doesn't list.
`github.com` and `objects.githubusercontent.com`, used for the Sass build step,
are in that allow list, but the two Composer hosts aren't. You can check with
`sbx policy check network getcomposer.org`.

With `allow-all` nothing is blocked. With `deny-all` more is blocked than this
page describes.

Without the kit, the agent routes around the block on its own: in our
rehearsal it installed Composer via `apt` in about 2 minutes. That works, but
it's slower and not guaranteed. The kit pre-allows both hosts, so either path
works without any `sbx policy allow` step.

## Why the entrypoint carries `--dangerously-skip-permissions`

A custom kit's entrypoint is not automatically YOLO mode just because the
binary is `claude`. The flag that gives the built-in `claude` agent its
permission-free start lives in that agent's own, otherwise invisible,
entrypoint definition, not in the binary name. A kit that only runs `claude`
starts Claude in normal permission-prompt mode, which defeats the point of
Demo 1. (Slide 6 lists what the flag gives an agent on a bare host; slide 15
argues for a boundary rather than prompts.)

A non-interactive test (`sbx exec ... claude -p ...
--dangerously-skip-permissions`) can't catch this: `sbx exec` runs an
arbitrary command and bypasses the sandbox's own entrypoint resolution, so it
"worked" whatever the kit said. Only a real interactive `sbx run` exercises
the entrypoint.

In the v3 kit the flag is in `kit/afup-php-demo.dockerfile`'s `ENTRYPOINT`.
`sbx kit inspect ./kit/` reports it as `Run Options`.

## Why you log in once per sandbox

A kit that renames the agent (`kit` for this v3 kit, `afup-php-demo` for the
v2 one, not `claude`) does not inherit the built-in `claude` agent's automatic
reuse of the host's Claude login. In rehearsal `claude -p ...` failed with
"Not logged in", even with an `anthropic` OAuth credential declared in the v2
`spec.yaml` and bound via `~/.config/sbx/credentials.yaml`. Re-declaring the
OAuth wiring didn't work cleanly (`SBX_CRED_ANTHROPIC_MODE` stayed `none`, and
adding `apiKey` alongside it caused "Invalid API key"), so that path was
abandoned. The v3 kit has no credential declaration and the question has not
been re-tried.

The fix: attach once, interactively, and
[log in the normal Claude Code way](how-to.md#log-in-to-claude-inside-a-kit-sandbox).
It persists for the life of that sandbox.

## Why Demo 4 uses the built-in `claude` agent

A custom kit-named agent doesn't get the sbx-managed MCP gateway wiring at all.
Confirmed in rehearsal: `sbx mcp load` reports success, but no server becomes
visible to Claude inside a kit-based sandbox. Demos 1 to 3 create `afup` with
the kit, so Demo 4 can't reuse that sandbox: it needs a different name, or a
recreated `afup` with plain `claude`.

## Why Compose containers don't survive an idle stop

A sandbox left idle for a few minutes gets auto-stopped, which kills every
container inside it (all exited 255 in our test). `sbx exec` silently restarts
a stopped sandbox, but Docker Compose containers don't come back with it: you
see an empty `docker ps`. To recover,
[run `docker compose up -d` again](how-to.md#bring-compose-back-after-an-idle-stop).

## What the agent decides on its own in Demo 1

Run for real, non-interactively (`claude -p "..."
--dangerously-skip-permissions` inside a real `sbx` sandbox): **2 min 07 s**
end to end. The agent's own choices, worth knowing before you run it:

- It installed **PHP 8.5** via `apt` (Ubuntu 26.04 ships 8.5, not 8.4).
  Harmless: `composer.json`'s `platform.php: 8.4.1` only pins dependency
  resolution.
- It installed **Composer via `apt`**, not the official installer, after
  noticing the Composer hosts were blocked (403/empty body); see
  [why they're blocked](#why-the-composer-hosts-are-blocked).
- It ran `composer install --no-scripts` on its own initiative, side-stepping
  the Sass build step. It didn't need to, since `github.com` turned out to be
  reachable, but the outcome was correct either way.
- It diagnosed both one-line bugs and reverted them to match `HEAD`.

## What changed between the v2 and v3 kit

The kit moved from the v2 `spec.yaml` grammar to the v3 format. The visible
differences:

- **No `name:` field.** Identity is the reference the kit is consumed by.
  `sbx ls` shows the agent as `kit`, not `afup-php-demo`.
- **Instructions are staged, not appended.** The v2 kit appended its
  instructions to the template's auto-generated `CLAUDE.md`. The v3 kit stages
  them at `/usr/share/sandbox/kit/afup-php-demo/afup-php-demo-context.md` and
  `CLAUDE.md` points there.
- **There's a build step.** The v2 `sandbox.image` was only a reference. A v3
  kit is an image, built with `docker buildx` the first time you run it, hence
  the [builder prerequisite](how-to.md#let-sbx-build-the-kit).
- **Version and mixing limits.** See the kit's
  [requirements](../kit/README.md#requirements).

The base image, the entrypoint and the two allowed hosts are unchanged.
