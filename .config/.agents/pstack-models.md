# pstack role bindings. One line per role. Delete a line to fall back to defaults.
# budget: small (medium)
# Host selects the bindings: on Claude use the block below; on copilot-cli use the copilot-cli block instead.
worker:  haiku
builder: sonnet medium
judge:   opus medium
peer:    copilot-cli:gpt-6.1-sol medium
# peer fallback: if copilot:gpt-6.1-sol is unavailable or the spawn errors, run a fresh-context pass on the judge model (opus medium) and say so in the reply.
# copilot-cli bindings (replace the three Claude lines and the peer line below when the host is copilot-cli):
#   worker:  gpt-6-luna medium
#   builder: gpt-6-luna xhigh
#   judge:   gpt-6.1-sol medium
#   peer:    claude:opus-5.5 medium
#   peer fallback: if opus-5.5 is unavailable or the spawn errors, run a fresh-context pass on the judge model (gpt-6.1-sol medium) and say so in the reply.
