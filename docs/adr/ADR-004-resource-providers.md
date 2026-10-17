# ADR-004: Resource providers registered explicitly

Decision D4. Written during bootstrap and M1 as a section of
[ADR-000-bootstrap.md](ADR-000-bootstrap.md), which keeps the shared context
(constraints and the staged-hardening principle) and the known limitations
L1 to L3. Index: [README.md](README.md).

---

**Context**
`Microsoft.Compute` and `Microsoft.Storage` were `NotRegistered` on the fresh
subscription; `Microsoft.Network` had been auto-registered by earlier portal use.
Automatic registration on first use requires the calling identity to hold
`*/register/action`. A CI identity with a narrowed custom role would not, and the
resulting `MissingSubscriptionRegistration` failure surfaces mid-apply, after
state has already been partially written.

**Decision**
All required resource providers are registered manually during bootstrap rather
than left to first-use auto-registration.

**Consequences**
- (+) Provider registration is never a failure mode inside a pipeline run.
- (+) A future narrowing of the CI identity's role does not introduce a new failure.
- Registration state is runtime state, not a fixed property of the subscription,
  so it is verified rather than assumed.
