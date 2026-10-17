# ADR-010: Federated credential subject: `ref:refs/heads/main`

Decision D10. Written during bootstrap and M1 as a section of
[ADR-000-bootstrap.md](ADR-000-bootstrap.md), which keeps the shared context
(constraints and the staged-hardening principle) and the known limitations
L1 to L3. Index: [README.md](README.md).

---

**Context**
The `subject` claim is the entire security boundary of D9: it is matched
character-for-character, and an attacker cannot forge it because GitHub sets it
from the repository actually executing the workflow.

Two forms were considered. Binding to a branch (`ref:refs/heads/main`) grants any
job running on `main` the ability to obtain a token. Binding to a GitHub
Environment (`environment:production`) makes token issuance conditional on the
job declaring that environment — and where that environment carries a required
reviewer, on a human approval having already occurred.

**Decision**
Two federated credentials, both branch/event-scoped:

| Name      | Subject                                                          |
|-----------|------------------------------------------------------------------|
| `gh-main` | `repo:joeycodes/m709-configured-not-effective:ref:refs/heads/main` |
| `gh-pr`   | `repo:joeycodes/m709-configured-not-effective:pull_request`        |

Credential definitions are archived in `docs/adr/assets/`.

**Consequences**
- (−) A job on `main` that does not declare an environment can still obtain a
  deployment token. The approval gate, once it exists, will be a GitHub-side
  control rather than a precondition of credential issuance.
- (−) The `pull_request` subject matches any pull request against the repository.
  `terraform plan` executes code from the pull request, so this is a supply-chain
  boundary. Three factors mitigate it:
  1. Workflows triggered by `pull_request` **from a fork** cannot obtain an OIDC
     token. This is long-standing GitHub Actions behaviour rather than a recent
     restriction: fork-triggered `pull_request` runs have no access to Actions
     secrets, and the OIDC token falls under the same rule. GitHub's documentation
     has listed the `id-token` permission for fork pull requests as `read`; Actions
     engineers confirmed in a documentation issue that this is incorrect — the
     permission exists only to mint a token, so there is nothing to read, and fork
     pull requests receive none.
  2. Workflow approval is required for first-time contributors.
  3. The pull request workflow runs `plan` only, never `apply`.

  `pull_request_target` does **not** carry this protection — it executes in the
  context of the target repository — and is not used in this project.

**Alternatives considered**
- *`environment:production`* — stronger, and the intended end state. Deferred under
  the staged-hardening principle; see D11. Note that adopting it requires
  *removing* `gh-main`: while both exist, the weaker subject still matches.

**Open item — verify before the first pipeline run**
Since 15 July 2026, newly created or renamed repositories are issued OIDC tokens
whose `sub` claim uses a format built on immutable repository and owner IDs. This
repository was created after that date, so the `sub` GitHub actually emits may not
be the `repo:<owner>/<repo>:ref:refs/heads/main` form registered above. The symptom
would be a token exchange failure indistinguishable from a mistyped subject.

**Open item resolved — the subject format was not what the documentation implied**

Expected (the form every tutorial still shows):

    repo:<owner>/<repo>:ref:refs/heads/main

Actually emitted:

    repo:<owner>@<owner_id>/<repo>@<repo_id>:ref:refs/heads/main

Since 15 July 2026, newly created repositories receive a `sub` claim built on
immutable numeric IDs. The intent is sound — renaming a user or repository no
longer silently breaks a trust relationship — but it invalidates every federated
credential written in the older form. Both credentials registered during
bootstrap would have failed.

Found before it could fail, by running an authentication-only workflow that
requested an OIDC token and printed its claims, before any Terraform was
involved. Had the probe been skipped, the failure would have surfaced during
`terraform init` as an opaque token exchange error, indistinguishable from a
mistyped subject, a misconfigured provider, or a backend permission problem.

This is the staged-hardening principle paying for itself: each mechanism was
proven alone before the next was layered on, so the failure had exactly one
possible cause.

The first task of BOOTSTRAP.md step 6 is therefore to have a workflow fetch its own
OIDC token, decode it, and compare the `sub` claim against what is registered here
— before concluding anything else about the pipeline.
