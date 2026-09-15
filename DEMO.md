# Tutorial — Replay the Docker Sandboxes demo

By the end of this tutorial you will have used an agent inside a Docker
sandbox to fix a failing Symfony app, run its Docker Compose stack in the same
sandbox, published its port to your host, and watched a network policy block a
request and then allow it. A fourth, optional demo adds an MCP server.

It follows the four demos of the "Docker Sandboxes" talk (Forum PHP 2026 /
INSA). The [slides](slides/afup-docker-sandboxes.pdf) introduce them on slide 21
(demos 1 and 2) and slide 29 (demos 3 and 4). The sandbox is called `afup`
throughout.

## What you need

1. **Docker Sandboxes (`sbx`) v0.45 or newer**, with a Docker Engine it can
   use (Docker Desktop or any other engine). See
   https://docs.docker.com/ai/sandboxes/. The kit in `kit/` uses the v3 format,
   which needs v0.45. Other versions are covered in the
   [reference](docs/reference.md#sbx-versions).
2. **A buildx builder that can export OCI images.** `sbx` builds the kit with
   it. Follow [Let sbx build the kit](docs/how-to.md#let-sbx-build-the-kit)
   once. If you create a dedicated builder, run `export BUILDX_BUILDER=sbx-kit`
   in each terminal where you use `sbx`. The first build takes about 8 minutes
   on a cold machine, so do it before you start.
3. **The `balanced` global network policy.** The first time it runs, `sbx` asks
   which default network policy to use: `allow-all`, `balanced` or `deny-all`.
   The demo assumes `balanced`, which allows typical development traffic (AI
   services, package registries) and denies the rest. Check it:
   ```
   sbx policy check network github.com        # Allowed
   sbx policy check network getcomposer.org   # Denied
   ```
   With `allow-all` nothing is blocked, so Demo 3 can't show a block. With
   `deny-all`, more hosts are blocked than this tutorial describes. To change
   the mode, see [Set the global network policy](docs/how-to.md#set-the-global-network-policy).
4. **A Claude account or API access** the `claude` agent can use inside the
   sandbox (the same auth you'd use for Claude Code normally).
5. **This repo**, cloned:
   ```
   git clone https://github.com/glours/afup-sbx-demo.git
   cd afup-sbx-demo
   ```

## Step 1 — Check out the starting point

```
git checkout demo-start
```

This is the starting point of the demo: two one-line bugs are present,
nothing is installed, nothing is running. (`demo-fixed` has the bugs already
fixed; see [Choose a starting point](docs/how-to.md#choose-a-starting-point).)

## Demo 1 — Claude in YOLO mode on a PHP project

*Slides 6 (what `--dangerously-skip-permissions` gives an agent), 16 (`sbx run`,
one command) and 21 (this demo).*

Create the sandbox and attach to it in one command:

```
sbx run --name afup ./kit/ .
```

The kit runs the same `claude` agent and template as plain
`sbx run claude --name afup .`, with two extra network hosts pre-allowed.

If Claude says it isn't logged in, type `/login` once. See
[Log in to Claude inside a kit sandbox](docs/how-to.md#log-in-to-claude-inside-a-kit-sandbox).

Give the agent this prompt:

> Install PHP, Composer and this project's dependencies, then make the PHPUnit
> test suite pass.

You should see:
- The agent installs PHP/extensions and Composer via `sudo apt-get` — nothing
  was preinstalled on the host.
- `composer install` (~25-30s, ~40 packages). It may print a `sass:build`
  failure (a `dart-sass` binary architecture mismatch). That's noisy but
  harmless: it doesn't affect the PHPUnit result.
- `php bin/phpunit` fails on exactly 2 spots:
  - `tests/Twig/AppExtensionTest.php::testIsRtl` — `src/Twig/AppExtension.php`
    negates the `in_array` check in `isRtl()`.
  - `tests/Utils/ValidatorTest.php::testValidatePassword` /
    `testValidatePasswordInvalid` — `src/Utils/Validator.php` uses `>` instead
    of `<` in `validatePassword()`'s length check.
- The agent fixes both one-character bugs and reruns the suite: 53 tests green.
- No permission prompt for any of this — installing system packages, running
  Composer, editing files.

Expect one to two minutes. The agent makes some choices
of its own (PHP version, how it installs Composer); see
[What the agent decides on its own](docs/explanation.md#what-the-agent-decides-on-its-own-in-demo-1).

## Demo 2 — Compose stack inside the sandbox, published to the host

*Slides 17 (architecture: the agent and its own `dockerd` in one microVM), 19
(workspace modes), 20 (credential isolation) and 21 (this demo).*

*(To start here from a fresh sandbox, check out `demo-fixed` first. Don't leave
a long gap after Demo 1: an idle sandbox stops and Compose with it, see
[Bring Compose back after an idle stop](docs/how-to.md#bring-compose-back-after-an-idle-stop).)*

In a second terminal, same sandbox:

```
sbx exec afup -- docker compose up -d
```

`compose.yaml` starts `nginx` (port 8000), `php-fpm` (Postgres via
`DATABASE_URL`, schema and fixtures loaded automatically on container start)
and `postgres`. No extra commands are needed: the page is ready as soon as the
containers report healthy.

The first run builds the app image, compiling `pdo_pgsql` and `intl` (about
70 s). To skip that wait, run `sbx exec afup -- docker compose build` first.

```
sbx exec afup -- ps aux
```

You should see the agent process **and** `dockerd` in the same container.

```
sbx exec afup -- docker ps
docker ps   # on the host: nothing from the sandbox — two different engines
```

Real `sbx exec afup -- docker ps` output, captured during rehearsal (the host's
`docker ps` at the same instant was empty):

```
NAMES                      IMAGE                STATUS                   PORTS
afup-sbx-demo-nginx-1      nginx:alpine         Up Less than a second    80/tcp, 0.0.0.0:8000->8000/tcp, [::]:8000->8000/tcp
afup-sbx-demo-php-1        afup-sbx-demo-php    Up Less than a second    9000/tcp
afup-sbx-demo-postgres-1   postgres:16-alpine   Up 3 seconds (healthy)   5432/tcp
```

`sbx exec afup -- ps aux` also shows `dockerd`, `containerd`, and every compose
container's process (postgres, php-fpm, nginx workers) as children in that one
agent container: one boundary, two engines (slides 16 and 17).

Publish the port and open it. The CLI command is `ports`, plural:

```
sbx ports afup --publish 8000:8000
```

Open http://localhost:8000/en/blog/ — the Symfony Demo blog, 10 posts.

Remove the mapping and the page dies, while the app keeps running inside:

```
sbx ports afup --unpublish 8000:8000
```

Optional, if you
[stored a token](docs/how-to.md#store-a-token-for-the-credential-isolation-aside):

```
sbx exec afup -- env | grep -i github
```

You should see a proxy-managed placeholder, not the real token (credential
isolation, slide 20).

## Demo 3 — Network policy blocking a request

*Slides 24 (default deny, deny wins), 25 (network rules), 28 (audit logs) and 29
(this demo).*

Use a plain `curl`, without `-I`, so the block message's body prints. With `-I`
you only see the proxy's `403 Forbidden` headers.

```
sbx exec afup -- curl https://event.afup.org
```

You should see a body like this one, captured on a still-blocked host during
rehearsal (`getcomposer.org`, which takes the same proxy path as
`event.afup.org`):

```
Blocked by network policy: domain getcomposer.org:443
  detail: no matching allow rule — blocked by default deny policy
```

On the host, list the policy, allow the domain, and retry:

```
sbx policy ls afup
sbx policy allow network event.afup.org
sbx exec afup -- curl https://event.afup.org
```

The request now returns 200.

```
sbx policy log afup
```

The output has two sections, more columns than slide 28's simplified table
(see the [mismatches](docs/reference.md#slide--cli-mismatches)). It shows the
prior denies, and the new allow with its rule.

## Demo 4 — MCP gateway: register a server and call a tool

*Slides 27 (MCP gateway) and 29 (this demo).*

Optional, and **not yet rehearsed live**. First register the Notion MCP server.
This opens a one-time OAuth flow in your browser, against your own Notion
account:

```
sbx mcp add notion --url https://mcp.notion.com/mcp
sbx mcp ls
```

Confirm that `sbx mcp ls` shows it as usable. (More in
[the how-to](docs/how-to.md#register-the-notion-mcp-server-for-demo-4).)

Start, or re-attach, a sandbox with the MCP server attached. Use the built-in
`claude` agent, not `./kit/`, and not the `afup` sandbox you created with the
kit (see [why](docs/explanation.md#why-demo-4-uses-the-built-in-claude-agent)).
If `afup` was created with the kit, use another sandbox name or `sbx rm afup`
first:

```
sbx run claude --name afup --static-mcp notion
```

Ask the agent to call one read-only tool, for example `notion-search` for a
page you own, or list a database.

End on:

```
sbx policy log afup
```

or the TUI (`sbx`, Tab → Network), to see every decision recorded.

## Where next

- Do one thing on its own: [`docs/how-to.md`](docs/how-to.md).
- Look something up: [`docs/reference.md`](docs/reference.md) and
  [`kit/README.md`](kit/README.md).
- Understand why it works this way: [`docs/explanation.md`](docs/explanation.md).
