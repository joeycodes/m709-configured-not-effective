# ADR-016: The region policy was removed by an offer change, not by a decision

Decision D16. Written during bootstrap and M1 as a section of
[ADR-000-bootstrap.md](ADR-000-bootstrap.md), which keeps the shared context
(constraints and the staged-hardening principle) and the known limitations
L1 to L3. Index: [README.md](README.md).

---

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
