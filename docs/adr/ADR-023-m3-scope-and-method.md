# ADR-023: M3 scope and method: four mandatory scenarios, pre-registered, Atomic Red Team first

**Status:** Accepted; amended 2026-11-09 (tooling) and 2026-11-10 (runbooks, #9), see Amendments
**Date:** 2026-11-06
**Milestone:** M3 (week 9)

Decision D23. Index of all decisions: [README.md](README.md).

---

**Context**
The proposal names four attack scenarios: #1 lateral movement tier 2 → tier 0,
#3 routing misconfiguration, #4 DNS tunnelling, and #6 credential abuse through
the instance metadata service. TECHNICAL-DESIGN §7 lists eight; the other four
(#2, #5, #7, #8) are optional. §7 names CALDERA, Atomic Red Team and
stratus-red-team as tooling.

M3 ends on November 30. `infra/` is frozen on November 27 for the final run,
and the Sentinel trial ends the same day. Week 9 added DNS logging (#59, EV-M3-01)
and closed tier 0's internet egress, a gap found in M2 (R5 (e); #60, EV-M3-02).

**Decision**

*What is tested*
- **The four scenarios in the proposal are mandatory.**

  | # | Scenario | ATT&CK | Class (TECHNICAL-DESIGN §8) |
  |---|---|---|---|
  | 1 | Lateral movement, tier 2 → tier 0 | T1021.004 | configuration |
  | 3 | Routing misconfiguration bypasses the NVA | T1562 | configuration |
  | 4 | DNS tunnelling exfiltration | T1071.004, T1048 | behavioural |
  | 6 | Credential abuse through the instance metadata service | T1552.005 | identity, not network |

  The four cover all three classes.

*How it is tested*
- **Each scenario is pre-registered before its first run.** The entry states
  the expected control, the expected signal, and what "prevented" and
  "detected" mean, in `attack/scenarios/PREREGISTRATION.md`. It is not edited
  after the run; corrections are appended with a date.
- **Baseline gaps are fixed before the run.** A gap that would make a result
  meaningless is fixed first and recorded as its own evidence, and the
  pre-registration lists the fix as a precondition. Example: tier 0 could
  reach the internet over HTTPS, so #4 would have tested nothing; fixed in
  #60 (EV-M3-02).
- **Footholds depend on the scenario.** #1 and #3 start from tier 2. #4 starts
  from tier 0: the data is there, and after EV-M3-02 Azure DNS is its only way out.
  #6 starts from a VM with a managed identity.
- **#4 tests detection only.** The queries go to a domain the lab does not
  own. The test checks whether detection (c) fires.
- **Atomic Red Team first.** Use an atomic test if one runs on Ubuntu for the
  technique; otherwise run the commands by hand through run-command. Every
  step goes into the scenario's runbook in `attack/scenarios/`, with
  its time.

*How results are counted*
- **Prevented, detected and MTTD follow the pre-registration.** MTTD runs from
  the first attempt to incident creation. Results go into the matrix
  (TECHNICAL-DESIGN §8).
- **Each detection is tested with a synthetic trigger first** (S2, S3, EV-M3-03).
- **A final run** in week 12 runs every scenario once on a fresh build from
  `main` after the freeze. Its results go into the report.

**Consequences**
- (−) #4 does not show that data can leave. That would need a name server the
  lab controls.
- (−) Results describe the baseline after its fixes. The state before each fix
  is in that fix's evidence (EV-M3-02).
- (−) It is not yet checked which atomic tests run on Ubuntu; many are
  Windows-only. Manual steps are harder to repeat than atomic tests.
- (−) After the trial ends, ingestion is billed. The cost is small and capped
  by the daily quota.

**Alternatives considered**
- *All eight scenarios mandatory* — not enough time.
- *Expectations written after the run* — results could be explained after the
  fact.
- *Running against the baseline as built* — data would leave tier 0 over HTTPS,
  and #4 would not test DNS.
- *The foothold for #4 in tier 2* — tier 2 can reach the internet through the
  NVA, so data would leave over HTTPS.
- *A working DNS channel* (a bought domain and an own name server) — costs
  money and needs approval; not needed to test detection (c).
- *CALDERA or stratus-red-team* — not needed for four single-step scenarios.
  CALDERA's agents would also need internet egress from tier 0, which EV-M3-02
  removed. May be reconsidered if time is left.
- *A separate regression run* — the final run is already a fresh build after
  the last change.

**Verification**
`PREREGISTRATION.md` has an entry for each scenario, committed before that
scenario's first run (git log). The matrix has both halves filled for each of
the four, citing evidence.

**Amendment (2026-11-09): all four scenarios run manually**
- The Atomic Red Team tests for each technique were checked:
  - [T1021.004](https://github.com/redcanaryco/atomic-red-team/blob/master/atomics/T1021.004/T1021.004.md) (#1): Windows only.
  - [T1071.004](https://github.com/redcanaryco/atomic-red-team/blob/master/atomics/T1071.004/T1071.004.md) (#4): Windows only.
  - [T1552.005](https://github.com/redcanaryco/atomic-red-team/blob/master/atomics/T1552.005/T1552.005.md) (#6): azure-ad only.
  - T1562 (#3): no tests of its own; its subtechniques do not cover a routing
    bypass.
- No test runs on the lab's Ubuntu VMs, so all four scenarios run manually
  through run-command, as the Decision allows. Each runbook's Tooling field
  records this.
- stratus-red-team was also considered for #6. Its Azure coverage is small,
  and it builds its own resources outside this repository's Terraform. Not
  used.

**Amendment (2026-11-10): runbooks and evidence; scenario #9**
- Each scenario's runbook in `attack/scenarios/` holds its steps, commands
  and queries. The results of each run are recorded separately under
  `docs/evidence/m3/`.
- #9 is added as optional: internal scanning from the tier-2 (assume-breach)
  host (T1046). Nothing today reliably monitors or alerts on it. The plan is
  to write a detection for this behaviour that raises a Sentinel alert once
  a threshold is reached.
