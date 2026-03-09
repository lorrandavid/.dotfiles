import type { Plugin } from "@opencode-ai/plugin"

// Prevents excessive Copilot premium request consumption.
//
// The built-in copilot plugin uses `last?.role !== "user"` which fails for
// synthetic user messages created by OpenCode (compaction, tool attachments,
// subtasks). This plugin detects those cases and correctly marks them as
// agent-initiated via the x-initiator header.
//
// Reference: https://github.com/anomalyco/opencode/pull/8721

const SYNTHETIC_PATTERNS = [
  /^Tool \w+ returned an attachment:/,
  /^What did we do so far\?/,
  /^The following tool was executed by the user$/,
  /^Tool result:/i,
  /^Tool output:/i,
]

function isSyntheticText(text: string): boolean {
  if (!text || typeof text !== "string") return false
  return SYNTHETIC_PATTERNS.some((p) => p.test(text.trim()))
}

function detectAgent(messages: { info: any; parts: any[] }[]): boolean {
  if (!Array.isArray(messages) || messages.length === 0) return false

  // Only override when the last user message is synthetic (compaction, tool
  // result, subtask). The built-in plugin already correctly handles
  // assistant/tool as last message via `last?.role !== "user"`.
  // Genuine user follow-ups must remain "user" so each is billed.
  const last = messages[messages.length - 1]
  if (last?.info.role === "user") {
    for (const part of last.parts ?? []) {
      if (part.type !== "text") continue
      if (part.synthetic || isSyntheticText(part.text)) return true
    }
  }

  return false
}

// Bridge between the transform hook (has message data) and headers hook (sets headers).
// Safe in single-threaded JS: transform always fires before headers for the same request.
let pendingAgent: boolean | undefined

export const CopilotPremiumGuard: Plugin = async () => {
  return {
    // Runs during message preparation, before the LLM request.
    // Analyzes the full message list to detect agent-initiated requests.
    "experimental.chat.messages.transform": async (_input, output) => {
      pendingAgent = detectAgent(output.messages)
    },

    // Runs when building the LLM request headers.
    // Overrides x-initiator when synthetic/continuation is detected.
    // Only sets "agent" (never "user") to avoid downgrading the built-in
    // subagent detection that may have already set it.
    "chat.headers": async (input, output) => {
      if (!input.model.providerID.includes("github-copilot")) return
      const isAgent = pendingAgent
      pendingAgent = undefined
      if (isAgent) {
        output.headers["x-initiator"] = "agent"
      }
    },
  }
}
