# ADR-009: CI authentication: workload identity federation, no client secret

Decision D9. Written during bootstrap and M1 as a section of
[ADR-000-bootstrap.md](ADR-000-bootstrap.md), which keeps the shared context
(constraints and the staged-hardening principle) and the known limitations
L1 to L3. Index: [README.md](README.md).

---

**Context**
A client secret is a long-lived credential: it must be stored in GitHub, rotated
on a schedule, and its disclosure is undetectable. Workload identity federation
replaces it with a trust relationship. GitHub signs a short-lived JWT asserting
which repository and ref is executing; Entra ID validates that signature and
matches the `subject` claim against a registered federated credential before
issuing an Azure token.

**Decision**
An app registration (`gh-m709-configured-not-effective`, appId
`8d9d812c-…`) with no credentials of any kind, a service principal
(`596978ed-…`) carrying the role assignments in D8, and federated credentials
registering the trusted subjects. GitHub holds only three identifiers —
client ID, tenant ID, subscription ID — stored as repository **Variables**, not
Secrets, because none of them is a credential.

**Consequences**
- (+) Nothing exists that can be stolen and replayed. Identity is a function of
  where the code is running.
- (+) Attack surface narrows to one assumption: that GitHub's signing
  infrastructure is sound and that GitHub asserts the executing repository truthfully.
- (−) That assumption is now a dependency of the whole deployment path.

**Evidence**
`keyCredentials: []` and `passwordCredentials: []` on both the application object
and the service principal.
