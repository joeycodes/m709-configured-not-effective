# Observability layer evidence

Environment: `canadaeast`, resource group `rg-cne-observability`, first applied
by CI on 2026-10-05 (2026-10-06 03:58 UTC). Decision record: ADR D17.
File headers carry the local date; timestamps inside the files are UTC.

## Assertions

| ID | Assertion | Expected | Observed | File |
|----|-----------|----------|----------|------|
| O1 | The workspace is deployed as configured | `PerGB2018`, 90 days, 1 GB cap, local auth disabled, `canadaeast` | all five hold | `O1-workspace-settings.txt` |
| O2 | The subscription Activity Log is exported to the workspace | one diagnostic setting, eight categories | `diag-activity-log`, eight categories, target `log-cne-observability` | `O2-activity-log-diagnostic-setting.txt` |
| O3 | Data is arriving, not merely configured to | rows in `AzureActivity`, none earlier than the apply | 499 rows in three categories; earliest 03:58:21 UTC, the minute the setting was created | `O3-activity-data-arriving.txt` |
| O4 | The evidence account is deployed as configured, and its access controls hold when tried | `Standard_GRS`, shared key off, no public blob access, infrastructure encryption on, versioning and 30-day soft delete; key access refused; blob access refused without a data role | all settings hold; key access refused (`KeyBasedAuthenticationNotPermitted`); blob listing refused for the subscription Owner | `O4-evidence-storage-settings.txt` |
| O5 | The layer survives a teardown of the lab | after the destroy workflow, only `rg-cne-observability` remains | holds; both resources present | `O5-survives-lab-destroy.txt` |

## What the readings show

O3 is the one that matters: O1 and O2 say the export is configured, O3 says it
works. It also confirms the export is not retroactive — nothing before the apply
is present, so the policy deletion recorded in D16 is not in the workspace.

The same table holds an independent record of the M1 drift test (F2–F4). The
network-interface writes show the CI identity creating the NICs at 03:59, a
*user* writing to `nic-cne-hub` at 04:34:25, and the CI identity writing it back
at 04:35:48. That user write is what the first detection rule is meant to catch.

## What was learned for the detection rule

- **Identify CI by its identity, not by "not a user".** `Caller` is an e-mail
  address for a user and an object ID for a service principal. The CI principal
  is object `596978ed-…`, application `8d9d812c-…` (`Claims.appid`).
- **One operation is several records.** Start, Accept and Success, and for the
  NIC creations a further Success ten minutes later. All twelve records for the
  four NICs share one `CorrelationId`, because the provider uses one per run;
  de-duplicate on `CorrelationId` together with `_ResourceId`.
- **Record time is not action time.** The 04:09 records appear seven minutes
  after the apply finished and are not new writes.
- **Resource group names are not case-stable.** `ResourceGroup` reads
  `RG-CNE-LAB`; an exact, case-sensitive match on `rg-cne-lab` returns nothing
  and raises no error.

## Gaps and corrections

- **Two predictions about O4 were wrong.** Listing containers as Owner was
  expected to fail and succeeded. The first explanation offered — a data role
  granted at subscription scope and inherited — was checked and is false: both
  existing assignments are scoped to the state account alone (O4 f). The actual
  reason is that listing, creating and deleting *containers* are control-plane
  Actions, which Owner and Contributor hold; only operations on *blobs* are
  DataActions. The test that distinguishes the two is O4 (e).
- **Consequence.** Owner and Contributor cannot read or write evidence, but they
  can list the container that holds it and, under the same permission, delete
  it — listing is verified here, deletion is not tested. The CI identity is
  Contributor. Container soft delete (30 days) is the only protection at that
  level.
- **A disabled key is still issued.** In O4 (c) the CLI retrieves the account
  key successfully and is then refused when it presents it.
- **O5 used a manual run** of the destroy workflow, not the scheduled one.
- **Not yet tested:** that the daily cap stops ingestion, that a shared-key
  query against the workspace is refused, and that a deleted blob can be
  recovered.
