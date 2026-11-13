# ADR-024: The scenario #3 test operator is created by hand, outside CI

**Status:** Accepted
**Date:** 2026-11-12
**Milestone:** M3 (week 10)

Index of all decisions: [README.md](README.md).

---

## Context

Scenario #3 (pre-registered in #74) tests a network change made outside CI: a
delegated administrator, compromised or careless, adds a VNet peering that lets
tier 1 reach tier 0 without crossing the NVA. The scenario needs an identity that
can make that change. Its remediation then removes that identity's write access.

That identity cannot be the author's account or the CI service principal
(ADR-008):

- The author holds `Owner` on the subscription. RBAC cannot restrict an Owner, so
  a remediation applied to that account would show nothing (ADR-000 L2).
- The CI service principal is the sanctioned change path. A change made through it
  is not a change outside CI.

Everything else in the lab is built by CI from Terraform. Building this identity
the same way would need:

- the `azuread` provider and the Microsoft Graph permission `User.ReadWrite.All`
  for the CI service principal, to create a user;
- the right to assign Azure roles (`Microsoft.Authorization/roleAssignments/write`).
  CI holds `Contributor`, which excludes it (ADR-008). An identity that can assign
  roles can assign itself `Owner`;
- an initial password for the user, which Terraform stores in state in plain text.

## Decision

- A test user, `lab.operator@<tenant>.onmicrosoft.com`, is created by hand in
  Microsoft Entra ID. It holds no directory role.
- The user is given the Azure role `Network Contributor` on `rg-cne-lab`, by hand.
  This is enough to create a VNet peering and nothing outside that resource group.
- The author does both, as tenant Global Administrator and subscription Owner. The
  commands are steps 1 and 2 of the #3 runbook
  (`attack/scenarios/scenario-3-routing-misconfiguration.md`).
- The password is kept by the author outside the repository. It does not appear in
  the repository, the evidence or Terraform state.
- The #3 remediation replaces `Network Contributor` with `Reader` on `rg-cne-lab`,
  by the same manual path. The re-run then repeats the peering creation, which is
  expected to fail with `AuthorizationFailed`. The change is recorded in the #3
  evidence.
- The role assignment is scoped to `rg-cne-lab`, which the nightly destroy
  deletes, and the assignment goes with it. It is made again in each lab session
  that runs #3. The user itself is in Entra ID and survives the destroy.
- The user exists only for #3. It is deleted after the re-run that follows the
  remediation. The final run creates it again, with `Reader` only (the state
  after the remediation), and deletes it when the final run ends.

## Alternatives considered

- *Terraform, applied by CI* — needs Graph and role-assignment permissions for CI,
  which would let CI grant itself `Owner`, and puts the password in state.
- *A separate Terraform layer, applied by the author from a workstation* — keeps CI
  at least privilege, but still puts the password in state, and adds a third state
  file for one user.
- *The author's own account* — RBAC cannot restrict an Owner, so the remediation
  could not be shown.
- *The CI service principal* — the change would go through the sanctioned path, so
  the scenario would not test a change outside CI.

## Known limitations

- The setup is itself a manual change outside CI, which is what #3 tests. It is
  recorded in the runbook and the evidence as setup, not as part of the scenario.
- The remediation restricts delegated identities only. The author, as Owner, can
  still change any resource (ADR-000 L2). A detection on `AzureActivity` for
  network writes by any identity other than CI would also cover the Owner; it is
  planned as part of the #3 remediation.
- Reproducing #3 needs a tenant administrator to create the user. It cannot be
  reproduced from the repository's code alone.
- The tenant may require multi-factor registration when the user first signs in.

---

## Verification

Before the first run of #3: `az ad user show` returns the user, and
`az role assignment list --assignee <user-object-id> --all` shows only
`Network Contributor` on `rg-cne-lab`. After the remediation, the same list shows
only `Reader` on `rg-cne-lab`. After the re-run, and again after the final run,
`az ad user show` returns not found.
