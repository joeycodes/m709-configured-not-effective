# ADR-002: Region: `westus`

Decision D2. Written during bootstrap and M1 as a section of
[ADR-000-bootstrap.md](ADR-000-bootstrap.md), which keeps the shared context
(constraints and the staged-hardening principle) and the known limitations
L1 to L3. Index: [README.md](README.md).

---

> Superseded by D16. The policy this decision was constrained by no longer
> exists; it was removed automatically when the subscription offer changed.

**Context**
The subscription carries a subscription-scoped Azure Policy assignment whose
`listOfAllowedLocations` parameter permits only:

    norwayeast, centralus, westus, mexicocentral, belgiumcentral

No Canadian region is available. The policy is assigned at
`/subscriptions/<subscription-id>` and applies to the subscription Owner, so it
cannot be worked around from within the subscription.

**Decision**
`westus` is used for all resources. It is the allowed region geographically
closest to the author (Edmonton, Alberta).

**Consequences**
- (+) The constraint is documented evidence, not an assumption: the policy
  parameter was read directly rather than inferred from a failed deployment.
- (−) All Azure-side resources sit outside Canada. The project measures control
  effectiveness and detectability, not latency, so this does not affect results.
