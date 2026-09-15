# How-to guides

Short recipes for one task each. For a guided walk-through, follow
[`../DEMO.md`](../DEMO.md); for the reasons behind a step, see
[`explanation.md`](explanation.md).

## Create or re-attach the demo sandbox

```
sbx run --name afup ./kit/ .
```

`sbx run` creates the sandbox if it doesn't exist and attaches in one step.
To re-attach later, `sbx run --name afup` alone is enough: the agent is read
back from the sandbox's own spec.

This needs a buildx builder that can export OCI images, see
[Let sbx build the kit](#let-sbx-build-the-kit).

Without the kit, use the built-in agent and
[allow the Composer hosts yourself](#allow-the-composer-hosts-without-the-kit):

```
sbx run claude --name afup .
```

## Let sbx build the kit

`sbx` builds a source kit with `docker buildx` and an OCI export. Docker's
default `docker` driver can't do that and fails with:

```
ERROR: failed to build: OCI exporter is not supported for the docker driver.
```

Pick one fix.

**A dedicated builder** (leaves your default builder alone):

```
docker buildx create --name sbx-kit --driver docker-container
BUILDX_BUILDER=sbx-kit sbx run --name afup ./kit/ .
```

Remove it later with `docker buildx rm sbx-kit`.

**Or turn on the containerd image store** in your Docker settings.

The first build pulls the kit frontend image (`docker/sandbox-kit:3`) and the
base image. On a cold machine it took about 8 minutes, mostly for one 323 MB
base layer. Do it once, ahead of time.

## Log in to Claude inside a kit sandbox

Do this once per sandbox. A kit sandbox doesn't reuse your host's Claude login
(see [why](explanation.md#why-you-log-in-once-per-sandbox)).

```
sbx run --name afup
# inside the session: /login
```

Then detach and leave the sandbox running. The login lives in that sandbox's
home directory and is lost with `sbx rm`.

## Warm up a sandbox

Do these ahead of time, so the demos don't wait on slow steps.

1. Create, attach and [log in](#log-in-to-claude-inside-a-kit-sandbox), then
   detach.
2. Pre-build the app's Docker image so nothing compiles during Demo 2
   (compiles `pdo_pgsql` and `intl`, about 70 s the first time):
   ```
   sbx exec afup -- docker compose build
   ```
3. Keep this sandbox. Don't `sbx rm` it, or you lose the login. When you're
   ready, [re-attach](#create-or-re-attach-the-demo-sandbox).
4. [Register the MCP server](#register-the-notion-mcp-server-for-demo-4) used
   in Demo 4.
5. Optional, for the credential aside in Demo 2:
   [store a token](#store-a-token-for-the-credential-isolation-aside).
6. Make sure the Composer hosts are allowed: the kit does it, otherwise
   [allow them by hand](#allow-the-composer-hosts-without-the-kit).

## Set the global network policy

`sbx` has one global network policy, chosen once, with three modes. See the
[reference](reference.md#global-network-policy). The demo assumes `balanced`.

Check what applies to a host, and list the rules:

```
sbx policy check network getcomposer.org
sbx policy ls
```

On a machine where the policy isn't set yet, pick the mode:

```
sbx policy init balanced
```

To change a mode that is already set, `sbx policy reset` clears all policies,
including rules you added yourself, so look at `sbx policy ls` first. Then run
`sbx policy init balanced`.

## Allow the Composer hosts without the kit

```
sbx policy allow network "getcomposer.org,composer.github.io"
```

Why they're blocked: [explanation](explanation.md#why-the-composer-hosts-are-blocked).

## Choose a starting point

Two git tags mark the starting points.

```
git checkout demo-start    # the 2 bugs are present, nothing installed
git checkout demo-fixed    # bugs fixed, tests green
git diff demo-start demo-fixed -- src/    # what the fix touches
```

See [reference](reference.md#git-tags) for what each tag contains.

## Bring Compose back after an idle stop

An idle sandbox is auto-stopped, and Compose containers don't survive that
restart. Start them again:

```
sbx exec afup -- docker compose up -d
```

Why: [explanation](explanation.md#why-compose-containers-dont-survive-an-idle-stop).

## Register the Notion MCP server for Demo 4

This opens an OAuth flow in a browser against your own Notion account. It's a
one-time, interactive step; you can't script it. The MCP gateway is covered on
slide 27.

```
sbx mcp add notion --url https://mcp.notion.com/mcp
sbx mcp ls
```

Confirm that `sbx mcp ls` shows it as usable. Then start a sandbox with the
server attached, **using the built-in `claude` agent, not the kit**:

```
sbx run claude --name afup --static-mcp notion
```

or, on an already-running sandbox: `sbx mcp load notion --sandbox afup`.

If `afup` was created with the kit, use another sandbox name or `sbx rm afup`
first. Why: [explanation](explanation.md#why-demo-4-uses-the-built-in-claude-agent).

Status: not yet rehearsed live. The commands above are believed correct, not
exercised.

## Store a token for the credential-isolation aside

Store a real token so the proxy has something to inject (slide 20 explains
the mechanism):

```
echo "$GITHUB_TOKEN" | sbx secret set github
```

Then, in Demo 2, `sbx exec afup -- env | grep -i github` shows a
proxy-managed placeholder, not the real token.

## Check the kit without starting a sandbox

```
BUILDX_BUILDER=sbx-kit sbx kit inspect ./kit/
```

It builds the kit and prints its resolved declarations. Compare them with
[what the kit declares](../kit/README.md#what-it-declares). `sbx kit validate`
doesn't accept v3 source kits.
