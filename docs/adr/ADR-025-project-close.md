# ADR-025: The project closes after four scenarios; the remaining planned work is dropped

**Status:** Accepted
**Date:** 2026-11-15
**Milestone:** M3 (week 10)
**Amends:** ADR-011, ADR-018, ADR-019, ADR-023, ADR-024

Index of all decisions: [README.md](README.md).

---

## Context

The time available for the project has been reduced, and the work still planned
can no longer be completed. The four mandatory scenarios in ADR-023 (#1, #3, #4,
#6) have each been run, and their results and remediations are recorded in the
matrix and the evidence. Several items planned in earlier ADRs have not been
started.

## Decision

- **Technical work stops at the current state of `main`.** No further scenarios,
  detections or infrastructure changes are made.
- **The following planned work is dropped:**

  | Item | Planned in | Status |
  |---|---|---|
  | Optional scenarios #2, #5, #7, #8, #9 | ADR-023 | Not run |
  | Final run of all scenarios on one fresh build | ADR-023 | Not run |
  | Re-run of #3 with the fixed detection (b) deployed (#82) | ADR-023 | Not run. The fixed query was run against the #3 data and returns the bypass flow (EV-M3-06 (e4)) |
  | Validation window #2, managed Azure Firewall | ADR-019 | Not taken |
  | Suricata on the NVA | ADR-019 | Not built |
  | Restricting tier-0 inbound to named sources and ports; narrowing tier-1 and tier-2 egress | ADR-018 | Not done. Tier-0 egress was closed (#60, EV-M3-02) |
  | Detection on `AzureActivity` for network writes by identities other than CI | ADR-024 | Not built |
  | Manual approval gate (protected environment, required reviewer) | ADR-011 | Not added |

- **Close-out:**
  - The scenario #3 test user (ADR-024) has been deleted. It is not created
    again, since the final run does not take place.
  - The lab stays destroyed. The persistent layer (ADR-017) is kept for now;
    after the Sentinel trial ends, its ingestion is billed and capped by the
    daily quota.

## Consequences

- (−) Detection (b) was fixed after #3, and the fixed query was checked against
  the #3 data (EV-M3-06 (e4)). #3 was not run again with the fixed rule
  deployed, so the time to detect after the fix is not measured.
- (−) No single build shows all fixes working together. Each fix was verified
  on its own build.
- (−) The results cover four scenarios. Nothing is claimed for the techniques
  of the dropped scenarios.
- (−) Tier 0 still accepts any flow from tier 1. Its isolation is claimed only as
  tested: tier 2 cannot reach it, and it has no Internet egress.
- (−) The NVA is the only firewall tested; nothing is claimed about the managed
  Azure Firewall.
- (−) A merge to `main` still deploys without review (ADR-011).
- (+) Every result that is claimed has its pre-registration, runbook and
  evidence in the repository.

## Alternatives considered

- *Run the final run before closing* — needs a full lab session and a new
  evidence pass; not possible in the time available.
- *Leave the plans in place without a decision* — the ADRs, the README and the
  matrix would describe work that is not going to happen.

---

## Verification

Each ADR listed under Amends ends with a dated amendment that points to ADR-025.
`az ad user show` for the #3 test user returns not found.
