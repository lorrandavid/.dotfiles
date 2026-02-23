---
name: angular-ngrx-patterns
description: Enforces NgRx best practices while adapting to the existing NgRx implementation in the project. The Copilot agent must inspect the current NgRx patterns and match them, prioritizing consistency over introducing new paradigms. This skill is mandatory when generating or modifying NgRx-related code.
---

# Critical Thinking & Adaptation Rules for NgRx Copilot Agent

> ⚠️ **This section is mandatory and overrides stylistic preferences**
>
> The Copilot agent must **adapt to the existing NgRx implementation in the
> project**.  
> Best practices are important, but **consistency with the current codebase is
> more important**.

This prevents:
- Fragmented architectures
- Mixed paradigms
- Hard‑to‑maintain state layers

---

## Core Principle

> **Extend the existing NgRx style — do not introduce a new one.**

The agent must **observe first, then act**.

---

## Step 1: Inspect the Existing NgRx Style

Before generating or modifying code, the agent must check:

### ✅ Actions
- Are actions created with:
  - `createAction`
  - Action classes (`implements Action`)
  - Plain objects

### ✅ Reducers
- Are reducers defined with:
  - `createReducer`
  - `switch (action.type)`
- Are entity adapters used?

### ✅ Effects
- Are effects present?
- Do they return actions or manually dispatch?
- Are they class‑based or function‑based?

### ✅ Selectors
- Are selectors:
  - Centralized in selector files?
  - Inline in components?
- Are feature selectors used?

### ✅ Facades
- Is there a facade layer?
- Do components inject `Store` directly?

---

## Step 2: Match the Existing Pattern

### Actions — Adapt, Don’t Migrate

| Existing Project Uses | Agent Must Use |
|----------------------|----------------|
| `createAction` | `createAction` |
| Action classes | Action classes |
| Mixed | Follow majority pattern |

❌ Do NOT auto‑convert action classes to creators  
❌ Do NOT introduce action creators into a class‑based codebase

---

### Reducers — Preserve Style

| Existing Reducer Style | Agent Behavior |
|-----------------------|----------------|
| `createReducer` | Continue using it |
| `switch(action.type)` | Continue using it |
| Entity adapter | Use entity adapter |
| Plain arrays | Keep plain arrays |

❌ Do NOT refactor reducers unless explicitly asked

---

### Facades — Never Introduce Implicitly

| Project Uses Facades? | Agent Action |
|----------------------|-------------|
| ✅ Yes | Use facades |
| ❌ No | Do NOT introduce |

✅ If facades exist:
- Components must not inject `Store`
- Actions/selectors stay hidden

❌ If facades do not exist:
- Components may use `Store` directly
- Agent should **not suggest facades unless asked**

---

### Selectors — Match Existing Access Style

| Project Pattern | Agent Must |
|----------------|-----------|
| Central selectors | Use selectors |
| Inline `store.select(...)` | Continue inline |
| Mixed | Follow local feature style |

✅ Prefer selectors when they already exist  
❌ Do not introduce selectors just to “clean up” code

---

### Effects — Follow Established Flow

| Existing Effects Style | Agent Must |
|-----------------------|-----------|
| Single‑purpose effects | Keep single‑purpose |
| Multi‑action effects | Match style |
| Manual dispatch | Do not change |

❌ Do not normalize effects unless requested

---

## Step 3: Apply Best Practices *Within* the Existing Style

Even when adapting, the agent must still:

✅ Keep reducers pure  
✅ Avoid side effects in reducers  
✅ Avoid cyclic effects  
✅ Avoid duplicated logic  
✅ Keep action naming consistent  
✅ Preserve action → effect → reducer flow  

> **Best practices should be applied subtly, not disruptively**

---

## Anti‑Pattern Detection (Warn, Don’t Rewrite)

If the agent detects:
- Multiple actions dispatched for one intent
- Business logic in components
- Side effects in reducers

✅ The agent may:
- Add comments
- Suggest improvements
- Ask before refactoring

❌ The agent must not rewrite architecture unprompted

---

## Decision Hierarchy (Most Important First)

1. ✅ Match existing project conventions
2. ✅ Preserve architectural consistency
3. ✅ Avoid breaking changes
4. ✅ Apply NgRx best practices
5. ✅ Suggest improvements only when safe

---

## Agent Self‑Check (Before Responding)

```text
[ ] Did I inspect existing NgRx patterns first?
[ ] Did I avoid introducing new paradigms?
[ ] Did I match action/reducer/effect style?
[ ] Did I preserve architectural consistency?
[ ] Did I avoid unsolicited refactors?
```

If any answer is **NO**, the agent must revise its response.

---

## Final Contract

> The Copilot agent is an **architectural collaborator**, not a refactoring tool.

Consistency beats perfection.  
Incremental improvement beats sweeping change.

✅ Safe for NgRx v7+  
✅ Safe for legacy codebases  
✅ Safe to embed in nested Markdown

---