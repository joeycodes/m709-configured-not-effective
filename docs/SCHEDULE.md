# Execution Schedule

**configured-not-effective** · MINT 709 Capstone · Jian Chen (1878285)
Companion to `PROJECT.md` (§5 Milestones). Window: 1 Sep – 31 Dec 2026. Contingency: 1 Mar 2027.

Each month closes on a **gate**: a checkable condition, not a feeling of progress. If a gate is not met, the following month's optional work is dropped rather than the gate being deferred.

---

## Standing rhythm

| Cadence | Item |
|---|---|
| Monday | 30 min re-plan against this file; check the Azure budget alert |
| Friday | Commit the week's evidence (logs, screenshots, plan output) + a one-paragraph log entry in `docs/journal.md` |
| Fortnightly | Short written status to Leonard Rogers — keeps the supervisor loop warm and creates a paper trail |
| Before any paid resource | Confirm `nightly-destroy.yml` is live and the budget alert is armed |

---

## M1 · September — Build the internetwork as code

Goal: an environment that provisions from empty and is destroyed and rebuilt in one pipeline run.

### Week 1 (Sep 1–6) — Admin and bootstrap
- Confirm registration and supervisor sign-off; obtain **Director approval for the ~CAD 300 spend before any expense is incurred** (this is a hard blocker on every paid validation window later).
- Azure subscription created; free-tier eligibility and quota confirmed.
- One-time manual bootstrap (§4.2): persistent resource group, Storage backend for Terraform state with blob-lease locking, Entra app registration + GitHub OIDC federated credential, RBAC split — CI identity is the only principal with deploy rights, human account is read/plan only.
- Repo scaffolded to the layout in TECHNICAL-DESIGN §4.1.
- ADR-0001 state and identity bootstrap; ADR-0002 self-hosted tunnel/firewall as the routine path, managed products exercised only in time-boxed validation windows.
- **Exit:** a GitHub Actions job authenticates via OIDC, runs `terraform init` against remote state, and produces a green empty plan.

### Week 2 (Sep 7–13) — Address plan and hub
- Freeze the address plan (§3.1) in one place: a Terraform `locals` map that the docs table is generated from, so the two cannot drift.
- `modules/network`: hub VNet 10.100.0.0/16, subnets carved as /24s (firewall 10.100.0.0/24, gateway/router 10.100.1.0/24, DNS, management).
- `modules/logging` built **now, not later**: Log Analytics workspace, diagnostic settings, Activity Log export. Telemetry must exist from the first deployed resource so November has history to work with.
- **Exit:** hub deployed through CI apply; workspace receiving Activity Log.

### Week 3 (Sep 14–20) — Spokes and routing enforcement
- `modules/tiers`: Tier-0 (10.101/16, restricted), Tier-1 (10.102/16, application), Tier-2 (10.103/16, low-trust). NSG/ASG baseline. Hub peering only — no spoke-to-spoke peering.
- UDRs sending `0.0.0.0/0` and inter-spoke traffic to the inspection next hop.
- Self-hosted inspection host (nftables/Suricata) stood up as the routine next hop; managed Azure Firewall stays behind the `enable_firewall` flag.
- One small test VM per tier, deallocated when idle.
- **Exit:** effective-routes output and a traceroute both show Tier-1 → internet traversing the inspection host; Tier-2 → Tier-0 is denied.

### Week 4 (Sep 21–30) — On-premises, eBGP, and M1 close
- FRR + StrongSwan edge VM as the simulated on-prem site (10.0.0.0/24); IPsec to the Azure-side endpoint; eBGP session with the on-prem prefix learned dynamically in both directions.
- `nightly-destroy.yml` written and proven **before** the first paid window.
- **Validation window #1 (time-boxed, ~48 h):** raise the managed Azure VPN Gateway, confirm the design holds on the native product, capture evidence, destroy. Log the actual cost.
- **M1 GATE:** on-prem → Tier-1 reachable over the tunnel; BGP-learned routes visible in effective routes; the entire environment destroys and rebuilds from `main` in a single pipeline run, with the rebuild time recorded.

---

## M2 · October — Prevent and detect

Goal: the pipeline becomes the enforcement point, and the telemetry layer can prove what happened.

### Week 5 (Oct 1–7) — Policy-as-code
- Rego policies in `infra/policy/`, run by `conftest` against `terraform plan -json`. Starter set: subnet without an associated NSG → deny; public IP on a Tier-0 resource → deny; spoke route table whose default next hop is not the firewall → deny; required tags.
- Checkov and tfsec wired in as secondary scanners; results posted to the PR.
- **Exit:** a deliberately non-compliant PR fails the check. **Record this run** — it satisfies a success criterion and is demo footage.

### Week 6 (Oct 8–14) — Deterministic assertions and gated apply
- CI reachability step (§6.3): `az network watcher test-ip-flow` plus effective-route checks asserting Tier-2 → Tier-0 = Deny and spoke default next hop = firewall.
- `apply.yml` behind GitHub environment protection with manual approval.
- Credential audit: confirm no long-lived secret exists in the repo, in Actions, or on the workstation.
- **Exit:** the assertion catches a deliberately broken UDR — a second recorded negative test.

### Week 7 (Oct 15–21) — Telemetry layer
- Flow logs → workspace, firewall traffic and DNS-proxy logs, DNS query logging, Activity Log. Sentinel onboarded.
- Verify each source with a query per source rather than assuming enablement equals arrival.
- **Verify before building on it:** NSG flow logs are on a retirement path in favour of VNet flow logs, and `AzureNetworkAnalytics_CL` is the legacy Traffic Analytics schema. Confirm which schema your subscription actually writes and pin the detections to that — this is cheap now and expensive in November.
- **Exit:** a one-page telemetry inventory — source → table → retention → what it can prove.

### Week 8 (Oct 22–31) — Detection-as-code v1 and M2 close
- First rules in `infra/detections/`, deployed by the same pipeline (code, never portal clicks): (a) accepted flow Tier-2 → Tier-0; (b) flow observed at Tier-0 with no corresponding firewall-log entry (inspection bypassed); (c) DNS query entropy / length / rate baseline.
- Each rule gets a synthetic trigger proving it fires.
- **Start the report now.** Create the GPS-format skeleton and back-fill Chapter 3 (design) and Chapter 4 (implementation) from `TECHNICAL-DESIGN.md` and the ADRs. This single decision is the strongest protection the schedule has.
- **M2 GATE:** minimum shippable core — a third party can clone, bootstrap, and obtain the environment, the gates, and firing detections from documentation alone.

---

## M3 · November — Attack and detection engineering

Goal: the control-effectiveness matrix, populated with evidence.

### Week 9 (Nov 1–8) — Harness and pre-registration
- CALDERA, Atomic Red Team, stratus-red-team configured in `attack/tooling/`; assume-breach foothold established on the Tier-2 host.
- **Pre-register** the expected control and expected signal for every scenario, committed with a timestamp *before* the first run. This is the stated mitigation for the known-answer risk (§9 of PROJECT.md) and only counts if it is timestamped ahead of the results.
- Runbooks in `attack/scenarios/`; matrix skeleton committed.
- **Exit:** scenario #1 executes end to end as a dry run.

### Week 10 (Nov 9–15) — Mandatory scenarios
- **#1** Lateral movement Tier-2 → Tier-0 (T1021) and **#4** DNS-tunnelling exfiltration (T1071.004 / T1048).
- Record initial prevented? / detected? / MTTD with log evidence for each.
- **Exit:** the two mandatory rows are complete. The irreducible floor is met; everything after this is upside.

### Week 11 (Nov 16–23) — Extended scenarios
- **#3** routing bypass, **#7** attack from the on-prem side of the tunnel, **#2** overly permissive service tag, **#6** SSRF → instance metadata → role theft.
- Prioritise **#6** if time is short: it is a control-plane attack that network segmentation cannot stop, which is the sharpest demonstration of the thesis.
- **Validation window #2 (time-boxed):** raise the managed Azure Firewall and re-run the key scenarios so the results also hold on the native product.

### Week 12 (Nov 24–30) — Close the gaps and M3 close
- For every failure that went undetected: author the detection, commit it, re-run the scenario, confirm it fires, fill the post-remediation columns.
- Attempt **#8** (low-and-slow evasion) against your own new detections. A successful evasion is a finding, not a failure — it is the evidence for the honest-boundary argument.
- **M3 GATE:** every attempted scenario has both halves of the matrix filled and cites log evidence.

---

## M4 · December — Regression, measurement, report

### Week 13 (Dec 1–7) — Full regression from zero
- Destroy everything except the persistent base; rebuild from `main`; re-run the whole scenario suite against the fresh build. This is what backs the reproducibility claim — record build time and any drift.
- If a peer is available, a short independent reproduction attempt (the second known-answer mitigation).

### Week 14 (Dec 8–15) — Measurement and results
- Compute MTTD, detection coverage per ATT&CK technique, prevented/detected counts, and actual cost against the CAD 300 estimate.
- Write Chapter 5 (results) and Chapter 6 (the honest boundary: configuration-class failures are deterministically catchable, behavioural failures only probabilistically narrowed).
- Freeze the diagrams.

### Week 15 (Dec 16–22) — Draft and demo
- **Full draft to the supervisor by Dec 18** — leaving a real review round rather than a formality.
- Record the demonstration: routing forcing spoke traffic through the hub firewall, a non-compliant deployment rejected in CI, an attack detected.
- Repo tidy: README reproducible from documentation alone, ADR set complete.

### Week 16 (Dec 23–31) — Revision and submission
- Incorporate supervisor comments; final GPS formatting; final teardown to the persistent base only, confirmed with a cost report showing no paid resources remaining.
- Submit.

---

## Scope discipline

**Hard floor (must ship):** environment as code · CI policy gate + reachability assertion · scenarios #1 and #4 · the before/after matrix · the report.

**Decision points**

| Date | If | Then |
|---|---|---|
| Oct 31 | M2 gate not met | Drop scenarios #2, #5, #7, #8 from the plan now; do not carry them into November |
| Nov 15 | The two mandatory rows are not complete | Stop adding scenarios; spend the rest of November on detection engineering and the matrix |
| Nov 23 | M3 complete and ahead | Only then consider the optional AWS or AKS extension — and prefer deepening the evidence instead |
| Dec 18 | No full draft with the supervisor | Invoke the extension to 1 Mar 2027 deliberately, rather than discovering it in late December |

---

## Open items to resolve in Week 1

1. ~~README contradicts the approved scope.~~ **Resolved.** `README.md` is now Azure-only and states the one-cloud baseline explicitly. `PROJECT.md` and `TECHNICAL-DESIGN.md` already matched; the reserved `10.200.0.0/14` supernet stays as documented foresight.
2. **Sentinel and log-ingestion cost** is not itemised in the CAD 300 estimate. Flow-log volume is the usual surprise. Set a daily ingestion cap on the workspace in Week 2, before the volume exists.
3. **`docs/adr/` does not exist yet** although both other documents reference it. Create it in Week 1 with ADR-0001.
4. **Diagrams still show the three-domain / AWS topology** and must be redrawn before anything is submitted. All four are `.drawio.png` with the editable `mxfile` source embedded, so they reopen in draw.io directly — no rebuild from scratch.
   - `02-1 Three-domain topology` — delete the AWS node; the diagram then reduces to two boxes and its stated point (three tunnels live at once, direct vs via-on-prem backup, BGP failover) no longer exists. Either drop this diagram or replace it with the substitute in the note below.
   - `02-New Complete Topology` — delete the AWS half; keep internet → hub → three tiers.
   - `02-2 Azure segmentation` and `02-4 Detection pipeline` — likely unaffected; confirm.
   - **Router label is wrong throughout.** The diagrams say "VyOS router" (and one says "FRR router" for the AWS side); the design specifies FRRouting + StrongSwan. Unify on FRR + StrongSwan.
   - **Prefix mismatch.** `02-1` shows on-premises as `10.0.0.0/14`; the address plan in TECHNICAL-DESIGN §3.1 says `10.0.0.0/16`. Fix one.

---

## Note · what the single-cloud decision costs, and how to buy it back

Dropping AWS removes the three-domain triangle, and with it the only routing-resilience story in the design: three tunnels live at once, a direct path and a via-on-prem backup, with BGP failover as the object of test. That was genuine internetworking depth in a project whose centre of gravity is otherwise security, and a MINT examiner is likely to look for it.

It can be recovered inside one cloud, cheaply: run **two IPsec tunnels between the on-premises edge and the Azure hub** (active/standby, distinguished by AS-path prepend or local preference), then test failover by tearing the primary down and measuring convergence. It costs one extra tunnel on the same free-tier VMs, preserves the eBGP path-selection demonstration, and adds an attack scenario worth having — does the security posture hold on the backup path, or does failover route around the firewall? Consider slotting it into Week 4 alongside the eBGP work, and as an extra row in the November matrix.
