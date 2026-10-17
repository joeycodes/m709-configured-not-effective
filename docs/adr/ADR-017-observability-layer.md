# ADR-017: A persistent observability layer, in its own state

Decision D17. Written during bootstrap and M1 as a section of
[ADR-000-bootstrap.md](ADR-000-bootstrap.md), which keeps the shared context
(constraints and the staged-hardening principle) and the known limitations
L1 to L3. Index: [README.md](README.md).

---

**Context**
The project's claims rest on evidence: what a control did, recorded at the time
it did it. Until now that evidence had nowhere durable to go. SCHEDULE.md (week 2)
called for a logging layer to be built "now, not later"; it was not built.

D16 showed what that cost. The subscription's Activity Log was the only record of
the region policy being deleted, and in its default form it is retained for 90
days, can only be read by querying it directly, and returned nothing on the first
query because `az monitor activity-log list` stops at 50 events. An export to a
workspace is not retroactive, so every day it is postponed is a day of history
that will not exist when M2 and M3 need it.

The evidence produced by the lab itself has the same problem in a sharper form.
The lab is destroyed nightly (D12), and anything stored inside it goes with it.

**Decision**
A new Terraform root, `infra/envs/observability`, holds a persistent layer:

- **Its own state.** Same backend as the lab, with the key
  `observability.tfstate`. The key is the blob name, not an encryption key: the
  two state files sit side by side in one container. What separates them is that
  each root has its own state and its own workflow, so the nightly teardown,
  which runs against `lab.tfstate`, has no record of these resources and cannot
  reach them.
- **Log Analytics workspace** `log-cne-observability`. Retention 90 days, a
  rolling window: a record is removed 90 days after it is written, so data from
  early October is still present at the December deadline. Daily ingestion cap
  1 GB (the variable allows up to 5 GB as a guard against typing errors). Local
  authentication is disabled, so the workspace's shared key cannot be used to
  ingest or query; every read and write must authenticate through Entra ID and
  is therefore subject to RBAC and recorded.
- **Subscription Activity Log exported to the workspace**, all eight categories.
  The export is not charged and the volume is small, and a category left out
  is found missing only when it is needed.
- **Evidence storage account** `sacneevidence`, in `canadaeast` because VNet flow
  logs require the storage account and the VNet to share a region. Replicated
  `GRS`: unlike the state file (D6), evidence cannot be rebuilt from code, and
  `canadaeast` has no availability zones, so `ZRS` is not an option. Shared key,
  local users and public blob access are disabled; blob versioning and 30-day
  soft delete for blobs and containers are enabled; infrastructure encryption is
  on, which cannot be changed after creation.
- **CI.** `plan.yml` gains a `plan-observability` job beside the existing `plan`
  job, which is unchanged because the ruleset requires it by name. A separate
  `apply-observability.yml` applies this root on merge. The lab's `apply.yml` is
  narrowed from `infra/**` to `infra/envs/lab/**`; without that, merging this
  change would also have rebuilt the entire lab.

**Consequences**
- (+) The layer is out of reach of the teardown structurally, by being in a
  different state, not by a filter that could be mistyped.
- (+) The Activity Log is retained, queryable and available to alert rules from
  the first apply onward.
- (−) Not retroactive. Nothing before the apply date is in the workspace; the D16
  events survive only in the sanitised export committed under `docs/adr/assets/`.
- (−) The daily cap bounds a runaway at roughly a few US dollars a day, but past
  the cap the rest of that day's logs are dropped without error. An attacker who
  can generate volume can use the cap to blind the workspace. An alert on the
  cap being reached is deferred to M2.
- (−) Both the workspace and the storage account accept traffic on their public
  endpoints. Access is Entra-only, so what is exposed is an endpoint, not data.
  Recorded as a known gap, not scheduled (see Alternatives).
- (−) Disabling a key does not remove it. The workspace shared keys and the
  storage access keys still exist and are written to the Terraform state, where
  they would become usable again if the corresponding setting were re-enabled.
  Access control on the state backend therefore still matters.
- (−) Both state files share one container, and the CI identity can write
  either. A fault in the lab workflow could in principle overwrite this layer's
  state.
- (−) The CI identity holds `Contributor`, which cannot create role assignments.
  Granting the NVA or the author data-plane access to the evidence container
  will be a manual step, recorded when it is taken.
- (−) `Owner` and `Contributor` cannot read or write blobs, but container
  operations are control-plane Actions, so both can list the evidence container
  (verified, O4) and, under the same permission, delete it (not tested). The CI
  identity is `Contributor`. Container soft delete is the only protection at
  that level.
- Five Checkov findings are accepted as inline exceptions, each with its reason
  in the resource block, following D14: public network access (`CKV_AZURE_59`)
  and no private endpoint (`CKV2_AZURE_33`), both the known gap above;
  Microsoft-managed rather than customer-managed keys (`CKV2_AZURE_1`), since the
  threat a customer-managed key addresses is outside this project's model and
  infrastructure encryption is already on; queue logging (`CKV_AZURE_33`), for a
  queue service this account does not use; and blob read logging
  (`CKV2_AZURE_21`), which is deferred to the resource-log sources connected in
  M2 week 7. That last one is the only one with real value: it would record who
  read or wrote the evidence, which is the evidence's chain of custody.
- `plan-observability` was added to the ruleset as a required check; that it
  blocks a failing change has not yet been tested.

**Alternatives considered**
- *The same resources inside the lab root, protected by `prevent_destroy`* — the
  lifecycle flag does not exempt a resource from `terraform destroy`; it makes the
  whole destroy fail, which would break the nightly teardown.
- *Teardown with `-target`, listing everything except this layer* — every new lab
  resource would have to be added to the list, and one omission would leave it
  running. Terraform itself discourages `-target` for routine use.
- *Reusing the state storage account for evidence* — the NVA's identity will be
  granted write access to the evidence container, and that grant should not sit
  one misconfiguration away from the file that defines the teardown boundary. The
  state account is also in `westus`, which VNet flow logs cannot use for a VNet
  in `canadaeast`.
- *No daily cap* — leaves the budget alert, which lags by hours, as the only
  protection against a logging runaway.
- *Private Link from the start* — costs more rather than less, since ingestion is
  billed per GB whichever path it takes, and private endpoints and DNS zones are
  billed on top. The clients that matter now, GitHub-hosted runners and the
  author's workstation, have no private path to a VNet, so public access would
  have to stay enabled regardless. A private endpoint must live in a VNet, and the
  lab VNets are destroyed nightly; a persistent VNet peered to the lab hub would
  make this layer depend on the ephemeral one. Revisit when the Azure Monitor
  Agent is introduced in M2, if a persistent VNet exists by then.

**Verification**
Applied by CI on 2026-10-05 (2026-10-06 03:58 UTC). Evidence and method are in
`docs/evidence/observability/`.

| ID | Assertion | Result |
|----|-----------|--------|
| O1 | Workspace deployed as configured | `PerGB2018`, 90 days, 1 GB cap, local auth disabled |
| O2 | Activity Log exported, eight categories | holds |
| O3 | Data is arriving in `AzureActivity` | 499 rows within the first 70 minutes; none earlier than the apply |
| O4 | Evidence account deployed as configured; access controls hold | settings hold; key access refused; blob access refused for the subscription Owner |
| O5 | Layer survives a lab teardown | holds (manual run of the destroy workflow) |

Merging this change also ran the lab's `apply.yml` once, because the change
edited that workflow file and the file is in its own path filter. It rebuilt the
lab. Later changes confined to this root do not trigger it.
