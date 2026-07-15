# CDD review rubric

## Contents

1. Theory boundary
2. Working definition
3. Reader-task model
4. Evidence catalog
5. Cognitive Complexity as a signal
6. Assessment dimensions
7. Remedy patterns
8. False improvements
9. Finding template
10. Sources

## Theory boundary

Cognitive Load Theory (CLT) describes learning under limited working-memory capacity and the role of schemas held in long-term memory. Use it here as a disciplined analogy for software comprehension, not as proof that a code property causes a fixed quantity of mental load.

Use the revised two-source framing:

- **Intrinsic load** depends on the interacting elements inherent in a task and on the reader's prior knowledge. In a code review, call this **essential task load** so it is not confused with an immutable property of a file.
- **Extraneous load** comes from how information is organized or presented. In code, this includes accidental structure a maintainer must decode without advancing the task.
- **Germane processing** is the working-memory effort directed toward learning and schema construction, not a third independent source to maximize. In code, assess whether the design supports accurate, reusable mental models.

Do not claim that a function, metric, or repository has an objective amount of human cognitive load. State the reader, task, evidence, and uncertainty.

## Working definition

Apply this CDD principle:

> Make essential domain reasoning visible and coherent; remove accidental reasoning; let maintainers solve realistic tasks with the smallest stable working set.

Optimize the total burden across a task, not the appearance of an individual function. A good design commonly has:

- one discoverable path for each important behavior;
- domain rules stated once in domain language;
- invariants encoded close to the state they govern;
- complexity hidden behind a small, truthful interface when callers do not need it;
- enough examples and tests to establish the intended schema;
- predictable repetition where consistency is more valuable than novelty.

## Reader-task model

Choose a reader before judging code. Unless the user says otherwise, assume a competent maintainer familiar with the language and repository conventions but unfamiliar with this change.

Choose concrete tasks rather than asking whether code is "readable" in general:

- explain the happy path and one important failure path;
- add, remove, or alter one domain rule;
- diagnose an incorrect result from an observed symptom;
- verify that an invariant holds across state transitions;
- identify every place affected by a contract change;
- onboard to the module well enough to make a safe first change.

Trace what must remain simultaneously active in the reader's working set. Count interacting concepts, not lines.

## Evidence catalog

### Essential task load

Look for inherently interacting elements:

- business rules whose results depend on one another;
- state machines and allowed transitions;
- concurrency, ordering, retries, and partial failure;
- security, consistency, or transactional guarantees;
- protocol or external-contract constraints.

Do not demand that essential complexity disappear. Prefer a representation that exposes the right decisions together while hiding irrelevant mechanics from each reader task.

### Extraneous load

Look for avoidable mental work:

- **Split attention** — one rule must be reconstructed from distant files, parallel representations, comments, or configuration.
- **Hidden dependencies** — behavior depends on ambient state, initialization order, mutation, reflection, or undocumented conventions.
- **Incidental branching** — nested conditionals or mode flags encode a missing state model or policy.
- **Vocabulary translation** — the same concept has different names or one name means different things across layers.
- **Temporal coupling** — calls must occur in an order the interface does not express.
- **Invalid representable states** — combinations are legal in types but illegal in behavior, forcing readers to remember exclusions.
- **Change amplification** — one conceptual change requires synchronized edits in many locations.
- **Needless indirection** — wrappers, forwarding layers, generic frameworks, or helper chains add navigation without hiding meaningful complexity.
- **Leaky seams** — callers must know implementation details, error mechanics, or lifecycle facts unrelated to their task.
- **Nonlocal control flow** — callbacks, events, exceptions, middleware, or asynchronous work obscure what runs next.
- **Representation noise** — ceremony, duplication, casts, sentinel values, or dense syntax obscures intent.
- **Inconsistent patterns** — similar tasks use different shapes without a domain reason, preventing schema reuse.

### Schema support

Look for structures that let many facts become one meaningful chunk:

- names and types aligned with the domain's established vocabulary;
- cohesive modules with small, truthful interfaces;
- one canonical source for rules and state transitions;
- explicit inputs, outputs, effects, error modes, and invariants;
- consistent control-flow and data-model patterns;
- focused examples or tests that demonstrate contracts and edge cases;
- local documentation for non-obvious rationale rather than narration of syntax;
- progressive disclosure: a caller can use a module without learning its internals, while a maintainer can still find the implementation.

Treat unfamiliar abstractions skeptically. An abstraction supports a schema only when it compresses stable knowledge for a real reader task.

## Cognitive Complexity as a signal

Prefer values from an analyzer already configured by the repository. Sonar's Cognitive Complexity is a language-neutral control-flow heuristic intended to represent relative understandability. Its core signals include:

- breaks in linear flow such as conditionals, loops, catches, switches, recursion, and jumps;
- extra cost when flow-breaking structures are nested;
- sequences of mixed logical operators;
- discounts for readable shorthand that does not require additional flow tracking.

Use the exact rules of the configured analyzer when reporting numbers; implementations and thresholds can vary by language and tool version.

Interpret the metric narrowly:

- Use function-level scores to locate control-flow hotspots.
- Compare changed code with its baseline when possible.
- Explain which structures create the score and how they affect the reader task.
- Do not use a universal pass threshold unless the repository defines one.
- Do not infer architectural quality, domain complexity, naming quality, coupling, or navigation cost from the score.
- Do not add file or project scores as if they represented one reader task.
- Do not reward extraction that merely resets a function score while increasing call chasing.

Cyclomatic Complexity answers a different question: it primarily counts independent control-flow paths and is useful for testability. Do not substitute it silently for Cognitive Complexity.

## Assessment dimensions

Rate each dimension with evidence:

| Level | Meaning |
| --- | --- |
| Low | The reader task follows a coherent path with a small, stable working set. |
| Moderate | Some deliberate tracing or context switching is needed, but the model remains recoverable. |
| High | Many interacting elements, hidden facts, or transitions must be coordinated; mistakes are plausible. |
| Critical | The task has no reliable local model; safe change or diagnosis depends on exhaustive reconstruction or author knowledge. |

Apply the levels to:

1. **Essential task complexity** — inherent interacting domain or systems elements relative to the assumed reader.
2. **Local control flow** — nesting, interruptions, boolean logic, and path structure within functions.
3. **Navigation and working set** — files, modules, call hops, and simultaneous facts needed for the task.
4. **State and invariants** — visibility and enforcement of legal states, transitions, ordering, and effects.
5. **Schema formation burden** — how much work remains after names, types, modules, tests, and conventions help the reader compress knowledge.
6. **Change amplification** — how broadly one conceptual change must propagate and how reliably those sites can be found.

An overall average is not meaningful. A critical state-model problem must not disappear inside a favorable arithmetic score.

## Remedy patterns

Match the remedy to the source of load:

- Make one representation canonical and derive secondary forms.
- Replace interacting booleans and nullable modes with an explicit state model.
- Move an invariant beside the state or operation that owns it.
- Gather a scattered rule behind one truthful interface.
- Collapse pass-through layers that add no useful abstraction.
- Introduce a deep module when it lets callers ignore stable mechanics.
- Separate orchestration from decisions when each becomes independently traceable.
- Flatten nesting with guard clauses only when the main path and exit semantics become clearer.
- Replace condition chains with data, dispatch, or polymorphism only when the variation is stable and discoverable.
- Align names across types, behavior, tests, and documentation.
- Add a contract test or focused example when behavior is correct but the intended schema is not recoverable.
- Keep tightly coupled facts together even when this permits a somewhat larger cohesive function or file.

State the direction before prescribing a detailed refactor when multiple designs could lower the load.

## False improvements

Reject these common forms of metric or style gaming:

- splitting a cohesive flow into tiny helpers that force constant jumping;
- replacing explicit domain decisions with a generic framework or clever expression;
- applying DRY across concepts that only look similar and will evolve independently;
- moving branches into configuration without making behavior easier to trace;
- hiding state transitions behind events or callbacks merely to shorten a function;
- replacing precise domain vocabulary with vague, supposedly simple names;
- adding comments that duplicate code while leaving the actual invariant implicit;
- lowering a local score while increasing the number of concepts, seams, or files a maintainer must understand.

Use this extraction test: if the reader still needs to open the extracted implementation to complete the chosen task, the extraction did not create a useful chunk for that task.

## Finding template

Require this chain of evidence:

1. **Location** — Where is the burden introduced or exposed?
2. **Reader task** — What is the maintainer trying to accomplish?
3. **Mechanism** — Which interacting elements or avoidable representation choices occupy the working set?
4. **Consequence** — What mistake, delay, or unsafe change becomes more likely?
5. **Direction** — What design move lowers total task-level load without hiding essential complexity?

Avoid claims such as "this is hard to read" without the chain above.

## Sources

- John Sweller, Jeroen J. G. van Merriënboer, and Fred Paas, [Cognitive Architecture and Instructional Design: 20 Years Later](https://doi.org/10.1007/s10648-019-09465-5), 2019. Use for the current CLT framing, element interactivity, and the revised role of germane load.
- G. Ann Campbell, [Cognitive Complexity: A New Way of Measuring Understandability](https://assets-eu-01.kc-usercontent.com/5a869490-919a-0159-3da4-b8c3c397c0bc/39475230-c3ff-4e73-8ab3-fe0c9f21e9dd/Cognitive_Complexity_Sonar_Guide_2023.pdf), version 1.7, 2023. Use for the metric's specification and worked examples.
- SonarSource, [Understanding measures and metrics](https://docs.sonarsource.com/sonarqube-server/user-guide/code-metrics/metrics-definition). Use to distinguish Cognitive Complexity from Cyclomatic Complexity and to verify current Sonar metric terminology.
