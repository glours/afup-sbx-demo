# v2's sandbox.image, as content. Same template Demo 1 uses without a kit.
FROM docker/sandbox-templates:claude-code-docker

# v2's sandbox.entrypoint.
#
# --dangerously-skip-permissions is NOT the default just because the agent
# is named "claude": it's the built-in claude kit's own entrypoint. Omitting
# it here (confirmed by rehearsal) starts Claude in normal permission-prompt
# mode, defeating the point of Demo 1 (no prompts on stage).
ENTRYPOINT ["claude", "--dangerously-skip-permissions"]
