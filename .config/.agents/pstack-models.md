# pstack role bindings. One line per role. Delete a line to fall back to defaults.
# budget: small (medium)
worker:  haiku
builder: sonnet medium
judge:   opus medium
# peer fallback: if copilot:gpt-6.1-sol is unavailable or the spawn errors, run a fresh-context pass on the judge model (opus medium) and say so in the reply.
peer:    copilot:gpt-6.1-sol medium    # different family than judge; id from pi.dev, not run-validated (Copilot CLI unauthenticated)
