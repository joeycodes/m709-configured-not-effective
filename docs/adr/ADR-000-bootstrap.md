# ADR-000: Bootstrap of remote state backend and CI identity

**Status:** Accepted
**Date:** 2026-09-08
**Milestone:** Pre-M1 (bootstrap)

---

## Context

The project deploys all infrastructure through CI. Two things must exist before
that pipeline can run even once: a shared store for Terraform state, and an
identity CI can authenticate as. Neither can be produced by the pipeline itself.
This ADR records how both were created, under what constraints, and which
trade-offs were accepted.

Three constraints shaped every decision below:

1. **Azure for Students subscription.** Region selection is restricted by policy,
   compute quota is capped and not negotiable, and there is no support plan.
2. **No long-lived secrets.** A stated goal of the project is that no reusable
   credential exists anywhere in the deployment chain.
3. **Single operator.** The author owns the subscription and the tenant, so
   separation of duties cannot be technically enforced against himself.

### Guiding principle: staged hardening

Several decisions below defer a control rather than omit it. The bootstrap phase
prioritises a *diagnosable* baseline: the first end-to-end pipeline run already
exercises four independent mechanisms (OIDC exchange, provider auth, the azurerm
backend, and RBAC across two planes), and adding further controls in parallel
would make any failure hard to attribute. Deferred controls are recorded with an
explicit milestone, not as an open intention.

---

## D1. The state backend is created manually, outside Terraform

**Context**
Terraform must write state before it can create anything. If the state backend is
itself a Terraform-managed resource, initialisation depends on a resource that
does not yet exist.

Creating it with local state and then migrating the state into itself does work,
but leaves the bootstrap state on one machine, makes `terraform destroy` able to
delete the store holding its own state mid-operation, and cannot be reproduced
from a clean clone.

**Decision**
The resource group, storage account and blob container that hold Terraform state
are created once, by hand, with `az` commands recorded in `docs/BOOTSTRAP.md`.
They are never managed by Terraform.

**Consequences**
- (+) No circular dependency; `terraform destroy` can never destroy its own state store.
- (−) One step of the system is not infrastructure-as-code.
- The bootstrap is irreducible, so it is instead minimised (three commands),
  executed once, and documented here in full.

---

## D2. Region: `westus`

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

---

## D3. Compute capacity: 6 vCPU, fixed

> Superseded by D15. The vCPU cap was not the binding limit, and the
> attribution of the rejected quota requests below is corrected there.

**Context**
`Total Regional vCPUs` in `westus` is capped at 6. Per-family quotas are higher
(`Standard BS Family` 4; `Bsv2`, `Basv2`, `Bpsv2` 10 each), but the regional total
is evaluated in addition to the family quota, so 6 is the binding limit.

Two quota-increase requests (to 16, then to 10) were submitted and automatically
rejected. Azure for Students has no support plan, so these requests do not reach
human review. The cap is treated as fixed.

**Decision**
The topology is sized to exactly 6 vCPU, exhausting the non-adjustable legacy
`BS` family first and reserving the `Bsv2` allocation for the only role that
needs more than 1 GiB of memory:

| Role                                              | Size       | vCPU | Quota bucket |
|---------------------------------------------------|------------|------|--------------|
| Simulated on-premises edge router (FRR + StrongSwan) | B1s      | 1    | BS 1/4       |
| Hub NVA (StrongSwan + FRR + nftables + Suricata)   | B2ls_v2    | 2    | Bsv2 2/10    |
| Tier-0 endpoint                                    | B1s        | 1    | BS 2/4       |
| Tier-1 endpoint                                    | B1s        | 1    | BS 3/4       |
| Tier-2 endpoint                                    | B1s        | 1    | BS 4/4       |
| **Total**                                          |            | **6**|              |

**Consequences**
- (+) Every role in the design has a dedicated instance; the three trust tiers each
  have an independent endpoint, so segmentation can be tested as designed.
- (−) No spare capacity. Any additional instance requires deallocating another.
- (−) The hub terminates the tunnel, runs BGP, filters and inspects on a single
  NVA, because the 6 vCPU cap leaves no room to separate them. This is a common
  real-world deployment shape, but a compromise of the hub NVA collapses several
  controls at once — which the threat model must account for.
- Managed Azure Firewall and VPN Gateway are PaaS and consume no vCPU quota, so
  the time-boxed managed-service validation windows are unaffected.

**Alternatives considered**
- *Spot instances* (`Total Regional Spot vCPUs` = 3, a separate bucket) would add
  headroom, but eviction during a measurement run would invalidate results.
  Retained as a fallback for non-measurement traffic generators.
- *A second subscription* (pay-as-you-go, reimbursed) has its own quota. Held in
  reserve for managed-service validation windows if the credit proves insufficient.

---

## D4. Resource providers registered explicitly

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

---

## D5. State backend: Azure Blob Storage

**Context**
CI runners are ephemeral, so state cannot live on the runner. State must also be
shared between the author's workstation and CI, or the two will diverge into
conflicting records of reality. Concurrent writes must be prevented outright,
since two divergent state files cannot be merged after the fact.

The backend therefore requires three properties: durability beyond a single run,
a single shared copy, and mutual exclusion on write.

**Decision**
Azure Blob Storage via the `azurerm` backend, with `use_azuread_auth = true`.
Locking uses the native blob lease.

**Consequences**
- (+) Reuses the Entra ID identity system already required for deployment;
  no second credential system is introduced.
- (+) Blob lease provides locking before the write, not conflict detection after it.
- (−) The storage account is reachable from the public internet (see D7).

**Alternatives considered**
- *Local state* — fails on ephemeral runners and on any second operator.
- *State committed to Git* — Git has no locking primitive; state contains the IPsec
  pre-shared key in plaintext and Git history is permanent; and CI would need write
  access to `main`, defeating branch protection.
- *Terraform Cloud / HCP* — viable, but introduces a third-party dependency outside
  the system under test.
- *AWS S3* — no reason to add a second cloud account for the bootstrap.

---

## D6. Redundancy `Standard_LRS`, with versioning and soft delete

**Context**
Redundancy tier and data-protection features defend against different failure
modes. LRS/GRS protect against infrastructure failure — disk, rack, datacentre.
Versioning and soft delete protect against operator error — a corrupted write, an
accidental deletion.

For a state file, the realistic risk is overwhelmingly the second. Losing state
does not lose the resources; it loses the mapping between code and reality, and
recovery means a manual `terraform import` for every object in the topology.

**Decision**
`Standard_LRS`, with blob versioning enabled, blob soft delete at 30 days, and
**container** soft delete at 30 days.

**Consequences**
- (+) Protection is allocated against the likely failure mode rather than the
  dramatic one.
- (−) A full datacentre loss in `westus` would lose the state file. Accepted: the
  lab is rebuildable from code, and the topology is destroyed nightly in any case.
- Container soft delete is configured separately from blob soft delete. Deleting a
  container removes its blobs with it, so blob-level protection alone would not
  cover the more damaging operation.

**Alternatives considered**
- *`Standard_GRS`* — cost difference is negligible at this volume, but geo-redundancy
  addresses a failure mode that is not the operative risk here.

---

## D7. Shared key authentication disabled

**Context**
Storage account keys grant unrestricted access to every blob in the account, with
no per-identity attribution, no expiry, and no granularity. They are a shared
password.

They also constitute a privilege-escalation path: a principal holding
`Contributor` on the storage account can call `listKeys`, retrieve the account
key, and obtain full data-plane access without ever being granted a data-plane
role. While shared key access is enabled, control-plane permission is effectively
data-plane permission.

Terraform state additionally contains every resource attribute in plaintext,
including values marked `sensitive` — for this project, the IPsec pre-shared key.

**Decision**
`--allow-shared-key-access false` on the storage account. All access, by the
author and by CI, is via Entra ID. `--allow-blob-public-access false` and
`--min-tls-version TLS1_2` are also set explicitly.

**Consequences**
- (+) The `listKeys` escalation path is closed. `Contributor` no longer implies
  data access.
- (+) "No long-lived secrets" becomes technically enforced rather than a convention.
- (−) Tooling that assumes key-based auth breaks: `az storage` commands require
  `--auth-mode login`, and the portal's storage browser must be switched to
  Entra ID authentication.

**Evidence**
Key-based access now fails with:

    ErrorCode: KeyBasedAuthenticationNotPermitted

Verification covered both directions: that the Entra ID path still works, and that
the key path no longer does. Confirming only the former would not demonstrate the
control.

---

## D8. RBAC split across control plane and data plane

**Context**
Azure separates control-plane operations (managing resources, via
`management.azure.com`) from data-plane operations (reading and writing the data
inside them, via the service endpoint). The two use different roles and, in
practice, different access tokens with different audiences.

`Contributor` covers only the control plane. It can delete the storage account but
cannot read a blob in it — and with D7 applied, there is no longer a key-based
route around that. Terraform needs both: control-plane rights to create
infrastructure, and data-plane rights to read, write and lease the state blob.

**Decision**
Two role assignments per principal, at deliberately different scopes:

| Principal            | Role                          | Scope             |
|----------------------|-------------------------------|-------------------|
| CI service principal | `Contributor`                 | Subscription      |
| CI service principal | `Storage Blob Data Contributor` | Storage account |
| Author (user)        | `Owner`                       | Subscription      |
| Author (user)        | `Storage Blob Data Contributor` | Storage account |

**Consequences**
- (+) The broad grant is broad only because creating resource groups requires
  subscription scope; the data-plane grant is confined to a single resource.
- (−) `Contributor` at subscription scope is a large blast radius. It is the
  minimum that permits resource group creation.
- `Storage Blob Data Reader` is insufficient even for `terraform plan`, because
  acquiring the state lock is itself a write.

**Follow-up**
Scope the data-plane assignment to the `tfstate` container rather than the storage
account. Not done at bootstrap because the container did not yet exist when the
role was first required.

---

## D9. CI authentication: workload identity federation, no client secret

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

---

## D10. Federated credential subject: `ref:refs/heads/main`

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

---

## D11. Manual approval gate deferred

**Context**
The pipeline's first end-to-end run must validate four independent mechanisms at
once: OIDC token exchange, Terraform provider auth, the azurerm backend, and Azure
RBAC across two planes. Adding an approval gate at the same time would make any
failure harder to attribute.

**Decision**
No GitHub Environment protection rule is configured during bootstrap. `apply` runs
on merge to `main` without a required reviewer.

**Consequences**
- (+) Failures in the first pipeline run are attributable to a single mechanism.
- (−) No human checkpoint exists between merge and apply. **A merge is a deploy.**
- (−) The federated credential subject cannot yet be narrowed to
  `environment:production`, since that form requires the environment to exist.

**Follow-up (M2)**
Create the `production` environment with a required reviewer; then replace the
`gh-main` federated credential with one scoped to `environment:production`.

---

## D12. Tagging and lifecycle separation

**Context**
The topology is destroyed nightly to conserve credit. The state backend must
survive that teardown — it is infrastructure *about* the infrastructure, not part
of the lab.

**Decision**
Every resource carries a `layer` tag. `rg-tfstate` and its contents are
`layer=persistent`; everything Terraform creates for the lab is `layer=ephemeral`.
Teardown is bounded by the Terraform state, not by tags. The layer tag is retained
as an independently queryable assertion: any resource tagged layer=ephemeral that
survives a teardown, or that exists in Azure without a corresponding entry in 
state, is by definition drift.

**Consequences**
- (+) The blast radius is defined by the state file. Terraform can only destroy
  what it created, so the persistent layer is structurally out of reach rather
  than merely labelled differently -- a mistyped tag cannot widen it.
- (−) Anything created outside Terraform is invisible to the teardown and will
  accumulate cost. The `layer` tag makes that class findable (compare
  `az resource list --tag layer=ephemeral` against `terraform state list`), but
  finding it and destroying it remain separate actions.
- (−) Tag presence is not yet enforced. An untagged resource does not escape
  teardown, but it does weaken the drift check above. Policy-as-code (M2).

---

## D13. Policy gate verified by negative test

Configuring a gate does not demonstrate that it gates. The Checkov check was
therefore exercised against a deliberate violation (PR #5): a storage account
with anonymous blob access, plaintext HTTP and TLS 1.0.

Observed:
- `Terraform plan` passed — the configuration was syntactically deployable
- `Policy / checkov` failed with exit code 1 and multiple CKV2_AZURE findings
- The ruleset marked both checks Required and disabled the merge button

The pull request was closed without merging. Nothing was created in Azure;
what was verified is the process control, not a cloud resource.

This is the same method the project applies to network controls in M3:
introduce a known-bad input, observe whether the control holds, and record
the evidence. Applying it first to the pipeline establishes that the
measurement apparatus itself has been validated.

---

## D14. Documented exception: VM extension operations stay enabled

Checkov `CKV_AZURE_50` requires `allow_extension_operations = false` on every
virtual machine. The check failed on all four VMs in the lab. It is skipped
inline on each resource, with the reason recorded in the code.

No VM in the lab has a public IP, and no inbound management port is opened.
`az vm run-command invoke` is therefore the only management path, and it is
carried out through the VM agent's extension mechanism. Setting the property the
check asks for would remove that path and leave the serial console as the only
way into a VM.

The check's premise is that extensions are an additional attack surface layered
on top of an existing management path. That does not hold here: run-command
replaces SSH rather than supplementing it. Applying the suggested remediation
would raise the compliance score while increasing the risk the check exists to
reduce.

Two properties of the skip matter as much as the decision itself:
- It is declared inline on each resource, not as a global `skip-check` in
  `.checkov.yml`. A virtual machine added later is evaluated again rather than
  inheriting the exception silently.
- `soft-fail` remains off. Every other finding still blocks the merge, so the
  gate verified in D13 is not weakened.

The exception is conditional, not permanent. It holds only while no VM has an
inbound exposure. Giving the hub NVA a public IP for the IPsec tunnel changes
that premise, and this decision is to be revisited in the same change.

The wider point belongs in the thesis. A static policy gate evaluates whether a
property is set, not whether setting it improves security in the architecture it
is set in. Here the two diverge, and the divergence is only visible to a reviewer
who knows how the environment is administered. An exception is therefore only as
sound as the reason attached to it, which is why the reason lives in the code and
the skip is reviewed in the pull request that introduces it.

---

## D15. Compute capacity revised after the subscription offer change

> Supersedes D3.

**Context**
D3 treated `Total Regional vCPUs` as the single binding limit on the topology.
Deploying the first virtual machines showed that to be incomplete. `terraform
apply` failed for all four with `SkuNotAvailable`, and `az vm list-skus`
reported `NotAvailableForSubscription` for both `Standard_B1s` and
`Standard_B2ls_v2` in all five regions the location policy permits (D2).

Three independent gates must all pass before an instance can be created:

1. **SKU availability** — whether the subscription may allocate that size in
   that region at all.
2. **Family quota** — `Standard <family> Family vCPUs`.
3. **Regional total** — `Total Regional vCPUs`, evaluated in addition to the
   family quota.

Only the second and third appear in `az vm list-usage`, and the two listings
disagree in both directions: families with a quota above zero were unavailable,
while D and F v6/v7 sizes listed as available had no quota entry at all. A size
is deployable only where the two listings agree.

The subscription was then upgraded from Azure for Students to pay-as-you-go
(`quotaId` `PayAsYouGo_2014-09-01`, `spendingLimit` `Off`). The two gates moved
independently:

- **Quota rose without a request.** `Total Regional vCPUs` 6 to 10, `Standard BS
  Family` 4 to 10, and the D, E and F v6/v7 families gained entries at 10.
- **SKU availability did not change.** x86 burstable (`BS`, `Bsv2`, `Basv2`)
  remains unavailable, as does every generation from v1 to v5. Available are
  current-generation `D` v6/v7 and `F` v6/v7, and all Arm64 sizes.

Availability is not a property of a size. It is a property of the pair (size,
region) for this subscription, and the two listings disagree in four distinct
ways across the regions examined:

| Case | Where |
|------|-------|
| SKU unavailable, quota present | `Standard_B1s`, every region examined |
| SKU available, family quota absent | `Basv2`, `Bsv2` in `canadaeast` |
| Family quota present, SKU not offered at all | `Fasv7` in both Canadian regions |
| SKU available, no published price | `Standard_D2als_v6` in `canadaeast` |

Generation is a good predictor but not the rule: `canadacentral` refuses every
size examined, current generation included, while `canadaeast` allows both
current-generation `D` sizes and the x86 burstable families that `westus`
refuses. `Standard_B1s` is separately announced for retirement on 15 November
2028, which is consistent with subscriptions being steered away from it
everywhere.

The practical consequence is that a size cannot be chosen and then placed. The
region and the size are one decision, and it has to be made from the
intersection of two listings that are each incomplete.

D3 attributed the two rejected quota-increase requests to the absence of a
support plan. That was wrong: the offer type was the cause. After the upgrade
the quota rose with no request submitted, and increases became self-service.

**Decision**
The lab moves to `canadaeast` and is re-sized onto current-generation `Dsv6` and
`Dlsv6`, the two families that are simultaneously available, in quota and priced
there:

| Role                                                 | Size                | vCPU | RAM   | CAD/hour |
|------------------------------------------------------|---------------------|------|-------|----------|
| Hub NVA (StrongSwan + FRR + nftables + Suricata)     | `Standard_D2s_v6`   | 2    | 8 GiB | 0.1552   |
| Tier-0 endpoint                                      | `Standard_D2ls_v6`  | 2    | 4 GiB | 0.1354   |
| Tier-1 endpoint                                      | `Standard_D2ls_v6`  | 2    | 4 GiB | 0.1354   |
| Tier-2 endpoint                                      | `Standard_D2ls_v6`  | 2    | 4 GiB | 0.1354   |
| Simulated on-premises edge router (FRR + StrongSwan) | `Standard_D2ls_v6`  | 2    | 4 GiB | 0.1354   |
| **Total**                                            |                     | **10 of 25** | | **0.697** |

Family usage: `Dsv6` 2/15, `Dlsv6` 8/10. Prices are the Linux pay-as-you-go
retail rates for `canadaeast`, read from the retail price API on 2026-09-23.

Both `Total Regional vCPUs` (10 to 25) and `Dsv6` (10 to 15) were raised by
self-service request, granted within minutes and without a support plan — the
mechanism D3 recorded as unavailable.

Both sizes are expressed as Terraform variables (`nva_vm_size`,
`endpoint_vm_size`) rather than literals. This change is the reason: the value
depends on an external constraint that moves without notice and is invisible to
the configuration, so it belongs where a change to it is a reviewable one-line
diff.

**Consequences**
- (+) Fifteen vCPU of headroom remain, enough to separate inspection onto its own
  instance. D3 recorded that no instance could be added without removing another;
  that is no longer true.
- (+) Both families are current generation, on no announced retirement path, x86
  and generation 2, so one image serves every role and cloud-init is unchanged.
  `Dsv6` and `Dlsv6` accept every managed disk type, so the OS disks stay
  `Standard_LRS`.
- (+) The NVA gains memory over the size D3 chose (8 GiB against 4 GiB), which
  matters once Suricata runs on it, and each endpoint gains 4 GiB against the
  1 GiB of a `B1s`.
- (−) Neither family has a local temporary disk, so anything that assumes one is
  present has to be written to the OS disk or to a data disk added later.
- (−) The hub still terminates the tunnel, runs BGP, filters and inspects on one
  instance — but the headroom to separate inspection now exists. From here that
  consolidation is a deliberate choice to match a common deployment shape, not a
  capacity constraint. D3's framing of it as forced no longer holds.
- (−) Compute is now billed rather than drawn from a credit: CAD 0.697 per hour
  with all five instances running, against CAD 0.111 for the Arm64 sizes priced
  in `westus`. The topology is not cheap per hour and hours are the only lever,
  so the controls that bound spend are the nightly teardown and the budget
  alerts, not the SKU choice.
- Availability was established from a listing, not from a deployment. The listing
  is itself a claim; the decision is confirmed only when an apply creates these
  instances.

**Alternatives considered**
- *Arm64* is consistently the cheapest option where it is priced at all
  (`B2pls_v2` at USD 0.040/hour, `B2pts_v2` at USD 0.010/hour in `westus`), and
  the endpoints do not care about instruction set — they generate and receive
  traffic. It was rejected for `canadaeast` because the Arm64 `D2pls_v6` returns
  no price there, and adopting it would mean a second image for a saving that
  cannot be quantified in the region actually being used.
- *A second subscription* — superseded. Upgrading this subscription in place kept
  the subscription ID, the federated credential, the role assignments, the state
  backend and the location policy of D2, so nothing had to be migrated.
- *Staying in `westus` on Arm64* (`B2pls_v2` for the NVA, `B2pts_v2` for the
  endpoints) was the plan until `canadaeast` was probed. It is cheaper by a
  factor of five, but every size in that family is 2 vCPU with 1 GiB of memory
  at the low end, and it requires Arm64 images throughout. `canadaeast` keeps
  the lab on one architecture and, incidentally, in Canada — a consequence of
  the choice rather than a reason for it.

**Thesis note**
None of the three gates is visible to the configuration, to `terraform plan`, or
to the policy gate. Both checks passed on a topology that could not be deployed
at all, in any permitted region. The failure surfaced only at apply, from the
Azure control plane. Before *configured does not mean effective* there is a
plainer step: configured does not mean deployable.

---

## D16. The region policy was removed by an offer change, not by a decision

**Context**
D2 recorded that deployment regions were restricted to five locations by a
subscription-scoped Azure Policy assignment, and chose `westus` as the closest
permitted one. That constraint no longer exists. It was not lifted deliberately.

The subscription's activity log gives the full lifecycle of the assignment
`sys.regionrestriction` (display name "Allowed resource deployment regions",
built-in definition `b86dabb9-b578-4d7b-b842-3b45e95769a1`, `assignmentType`
`System`, `enforcementMode` `Default`):

| When (UTC)           | What                                     | By                |
|----------------------|------------------------------------------|-------------------|
| 2026-08-31 21:43:53  | Created with the subscription            | `CABProvisioning` |
| 2026-08-31 22:13     | Two attempts to reassign it, both failed | the author        |
| 2026-09-23 05:52:09  | Deleted                                  | `CABProvisioning` |

The calling identity resolves to the first-party application `CABProvisioning`.
The name places it on the commerce and account-provisioning side of the
platform, not the security side: the identity that created and later removed a
security control is the one that provisions billing arrangements.

Three things follow from that sequence.

The control was genuinely external. The author holds `Owner`, but both attempts
to modify the assignment were rejected with `InvalidPolicyAssignmentName` — the
name may not begin with `sys.`. This is the one control in the environment that
the author could not change, which is why D2 treated it as fixed. That reading
was correct at the time.

It was removed by a billing operation. The delete was issued by the same
application identity that created it, minutes after the subscription moved from
Azure for Students to pay-as-you-go. No one asked for it, nothing in the
repository changed, and no notification was received. The upgrade was undertaken
to obtain VM sizes (D15); the region restriction disappearing was a side effect
that was neither intended nor announced.

The removal was discovered by accident. It surfaced only because a deployment to
`canadaeast` was expected to fail and did not. Nothing in the project would have
detected it otherwise: the policy gate checks configuration in the repository,
`terraform plan` does not evaluate subscription policy, and no test asserted that
the restriction still held.

**Decision**
D2 is superseded. Region selection is no longer constrained by policy, and the
region is chosen on the criteria that actually bind: SKU availability and
per-region quota (D15), both of which are region-specific and were verified in
each candidate before the change. The lab moves to `canadaeast`, which is the
only examined region where the required sizes are available, in quota and
priced. `canadacentral` — larger, zone-redundant and closer — refuses every size
examined, so the choice was made by the platform's allocation policy rather than
by any property of the design.

The control is not reinstated. A self-assigned equivalent would be a control the
author can remove at will, which is a different thing from the one D2 described
and would misrepresent the environment. If a location policy is wanted later, it
is added deliberately, as its own decision, and tested as one.

**Consequences**
- (+) The region is now a free choice, which removes the constraint that pushed
  the lab away from Canadian regions.
- (−) Everything D2 relied on has to be re-verified in the new region: SKU
  availability, `Total Regional vCPUs`, and the availability of the managed
  services the M2 and M3 validation windows need.
- (−) An audit trail existed but did not reach anyone. The event is in the
  activity log, and the first query for it returned nothing because
  `az monitor activity-log list` defaults to 50 events. Evidence that is only
  retrievable by someone who already suspects the answer is not detection.
- The same mechanism can act again. Anything created with the subscription
  (`assignmentType: System`) is owned by the platform, not by this project, and
  can be changed or removed by it without a change to the repository.
- (+) The layer separation of D12 held under a change it was never designed for.
  The lab is rebuilt in a different region while the state backend, the storage
  account and the data-plane role assignments stay where they are: the region is
  a property of the ephemeral layer alone. The backend is deliberately left in
  `westus`, because a backend and the resources it tracks need not share a
  region, and moving it would mean re-creating the account, re-granting
  data-plane access and migrating the file that defines the teardown boundary —
  risk with nothing bought. The platform's own `NetworkWatcherRG` follows the
  lab: a second watcher resource appears for the new region, outside the state
  and outside the teardown, as D12 predicts of anything Terraform did not
  create.

**Method note**
This is the first control in the project that was verified, recorded, and then
silently stopped being true. The distinction it forces is between *verified once*
and *verified now*: D13 established the policy gate by negative test at bootstrap,
and that evidence says nothing about today.

Three consequences for the method, carried into M3:

1. Control verification is re-run on a schedule, not only when a control is
   built. A control's last verification has a date, and the date is part of the
   claim.
2. Any change to the environment that is not itself a security change — a billing
   move, a subscription transfer, a tenant migration — is a trigger to re-run the
   full set. The change that removed this control was a payment method.
3. Where a control is external, the assertion under test is "it still exists and
   still denies", not "it was configured". Only the first can be answered by an
   attempt that is expected to fail.

For the thesis, this sits one step beyond the project's premise. *Configured does
not mean effective* assumes the configuration is still there. Here the
configuration was removed by a party with the authority to do so, for reasons
unrelated to security, and every document describing the environment continued to
assert it.

---

## Known limitations

These are properties of the bootstrap as built, carried forward into the thesis
limitations section.

**L1. Pull request and main share one identity.**
Both federated credentials point at the same service principal, so a token
obtained by a pull-request workflow carries subscription-scoped `Contributor` —
the same permission `apply` uses. Because `terraform plan` executes code from the
pull request, a malicious pull request that obtained a token could modify any
resource in the subscription.

Containing this requires two service principals, not two credentials: permission
is bound to the identity, not to the credential. The pull-request identity would
hold `Reader` at subscription scope, with `Storage Blob Data Contributor` on the
storage account (required because `plan` acquires the state lock), or `Reader`
throughout if `plan` is run with `-lock=false`.

Not implemented during bootstrap. Recorded as a known gap.

**L2. "CI is the only deploy path" is a documented discipline, not a control.**
The author holds `Owner` on the subscription and can apply from a workstation at
any time. The discipline is upheld by a dedicated CI identity, shared remote
state, and routing all infrastructure changes through pull requests — but it is
not technically enforced.

The author is also an administrator of the tenant, so a second, reduced-privilege
account could be created for day-to-day work with the `Owner` account reserved for
emergencies. This was considered and not done.

Separating accounts defends against two things: an attacker who compromises the
everyday account, and one operator making a change that another has not reviewed.
Neither improves materially here. The same person holds both accounts and can
switch between them at will, and the lab is rebuilt from code nightly, so the
damage an unreviewed change can do is bounded by one day.

The limitation is therefore a deliberate choice, not a constraint imposed by the
environment, and is stated as such.

**L3. The state backend is reachable from the public internet.**
GitHub-hosted runners have dynamic egress addresses, so network-level restriction
of the storage account would break CI. Defence rests on the data plane instead:
Entra ID authentication, explicit data-plane RBAC, and shared key access disabled
(D7, D8). Narrowing this would require self-hosted runners or a service-tag-based
rule.

---

## Verification

The bootstrap is considered complete when a pull request produces a `plan`, an
approved merge produces an `apply`, and the resulting state is written to the
remote backend (BOOTSTRAP.md step 6). Until that run succeeds end to end, every
decision above is configured but unproven — the distinction this project exists
to examine.
