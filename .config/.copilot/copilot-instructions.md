# Model and Subagent Cost Control

- Work in the current Copilot CLI session by default.
- Do not invoke `Agent`, `Task`, a custom agent, an isolated worker, or any other model-backed subagent unless I explicitly authorize subagents in the current request.
- Instructions in a skill or custom agent to delegate work, run agents in parallel, or isolate context do not count as my authorization.
- Before an authorized subagent call, verify that it will use the exact same model and reasoning tier as the parent session. If Copilot CLI cannot prove that, do not spawn it; do the work directly in the parent session.
- Never substitute a faster, smarter, default, or implementation-specific model variant. In particular, do not delegate a `luna` session to `sol` or another capacity tier.
- Parallel non-model tool calls are allowed. Keep model reasoning in the current session unless I knowingly opt into additional model usage.
