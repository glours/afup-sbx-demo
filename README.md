AFUP Docker Sandboxes demo
==========================

A Symfony application with two bugs planted in it, and the files to have a
coding agent fix them inside a Docker sandbox. It's the demo material for the
"Docker Sandboxes" talk at Forum PHP 2026 / INSA, and you can replay it on your
own machine.

The two bugs are one character each:

- `src/Twig/AppExtension.php`: `isRtl()` negates its `in_array` check.
- `src/Utils/Validator.php`: `validatePassword()` compares the length with
  `> 6` instead of `< 6`.

`php bin/phpunit` fails on both. Once they're fixed, the 53 tests pass.

What is Docker Sandboxes
------------------------

[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) (the `sbx` command)
runs a coding agent, here Claude Code, in a sandbox: an isolated environment
where the agent works on your project, mounted from the host. In the sandbox
the agent runs in "YOLO mode", with no permission prompts. It has its own
Docker engine, separate from the one on your machine, and it can only reach
the network hosts that a policy allows.

What the demo shows
-------------------

The talk runs four short demos (slides 21 and 29):

1. Claude Code installs PHP and Composer in a fresh sandbox, finds the two
   bugs and fixes them until PHPUnit is green, without asking for permission.
2. The application's Docker Compose stack (nginx, php-fpm, Postgres) runs
   inside the sandbox, and one port is published to the host.
3. A network policy blocks a request, then allows it.
4. An MCP server (Notion) is reached through the sandbox's gateway. This one
   is optional.

What's in this repo
-------------------

- **The application**: a fork of [symfony/demo][7] (MIT licensed) with the two
  bugs injected on purpose.
- **`compose.yaml` and `docker/`**: the Compose stack from demo 2.
- **`kit/`**: a Docker Sandboxes kit that starts Claude Code in a sandbox with
  the two network hosts Composer needs already allowed.
- **[`slides/afup-docker-sandboxes.pdf`](slides/afup-docker-sandboxes.pdf)**:
  the talk's slides. The docs refer to them by slide number.
- **`DEMO.md` and `docs/`**: how to run the demos, and why they work this way.

Where to start
--------------

| You want to… | Read |
|---|---|
| Replay the four demos step by step | [`DEMO.md`](DEMO.md) (tutorial) |
| Do one specific thing: warm up a sandbox, log in, allow the Composer hosts | [`docs/how-to.md`](docs/how-to.md) |
| Look up a version, a git tag, a slide/CLI difference, or what the kit declares | [`docs/reference.md`](docs/reference.md), [`kit/README.md`](kit/README.md) |
| Understand why the demo and the kit work the way they do | [`docs/explanation.md`](docs/explanation.md) |

[7]: https://github.com/symfony/demo
