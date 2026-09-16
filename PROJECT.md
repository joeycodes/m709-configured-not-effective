# configured-not-effective — Project Document

**Validating the security posture of a hybrid cloud internetwork by attacking it, not by inspecting it.**

MINT 709 Capstone · Jian Chen (1878285) · Supervisor: Leonard Rogers · Sep–Dec 2026

---

## 1. Overview

Cloud security controls are usually verified by reviewing their configuration. A control can be present in the configuration yet ineffective in practice, either through misconfiguration (a route that skips the firewall, a security group that opens every port) or through the abuse of a permitted service (DNS used as a covert exfiltration channel). Common practice treats a control as effective simply because it is configured, and that gap is where breaches happen.

This project builds a hybrid cloud internetwork (an on-premises site joined to Microsoft Azure), then proves whether its network-layer security controls actually hold by attacking them and measuring what is caught. The guiding idea: **configured does not mean effective.**

## 2. Objective

Produce a reproducible, adversarially validated hybrid internetwork, together with evidence of which security controls hold, which fail silently, and whether their failure is detectable. The central question:

> Can the security posture of a hybrid cloud internetwork be validated by attacking it rather than by inspecting it, and can the controls that fail silently be made detectable?

## 3. Scope

**In scope**
- One cloud (Azure) plus a simulated on-premises site, joined over IPsec with eBGP.
- Hub-and-spoke topology; routing that forces traffic through a hub firewall; three trust tiers with a default-deny restricted tier.
- Infrastructure-as-code (Terraform) with policy-as-code gating in CI.
- Detection built on Azure-native telemetry (detection-as-code).
- Adversarial validation under an assume-breach model, and a before/after control-effectiveness matrix.

**Out of scope**
- Application-layer penetration testing (there is no production application; this is an assume-breach test of network controls).
- A second cloud and cross-provider comparison (optional extension only).
- Formal compliance certification (the work maps to CIS/Zero-Trust baselines; it does not seek assessment).

**Optional extension (only if ahead of schedule)**
- Add AWS for a cross-provider comparison.
- Add a Kubernetes (AKS) tier with pod-level network policy.

## 4. Approach

Three connected stages:

1. **Build** — stand up the internetwork as code; policy-as-code blocks non-compliant configuration before it deploys.
2. **Attack** — under an assume-breach model, run a focused catalogue of scenarios mapped to MITRE ATT&CK, recording whether each control held and whether its failure produced a signal.
3. **Verify** — for undetected failures, engineer a detection as code and re-run to confirm it fires; deterministic reachability assertions catch configuration-class failures before any traffic flows.

Detail is in `docs/TECHNICAL-DESIGN.md`.

## 5. Milestones

| # | Month | Milestone |
|---|---|---|
| M1 | September | Requirements and address plan; on-premises site and Azure landing zone built as code, eBGP established |
| M2 | October | Policy-as-code gating in CI; CI/CD pipeline, identity, and secrets complete; native detection layer in place |
| M3 | November | Attack execution and detection engineering; control-effectiveness matrix populated |
| M4 | December | Regression and measurement; final report in the GPS thesis format |

Completion targeted by December 31, 2026, with the automatic extension to March 1, 2027 as a contingency only.

## 6. Deliverables

1. Final report in the GPS thesis format (design, method, results).
2. Public infrastructure-as-code repository (Terraform, policy-as-code, CI, detections), reproducible from documentation alone.
3. Network design package: topology, address plan, and architecture decision records.
4. Control-effectiveness matrix (before and after), backed by log evidence, with a supporting compendium of test data.
5. Demonstration recording: routing forcing spoke traffic through the hub firewall, a non-compliant deployment rejected in CI, and an attack detected.

## 7. Resources and cost

- **Software:** Terraform, Open Policy Agent (Checkov, tfsec), GitHub Actions, FRRouting with StrongSwan/WireGuard, adversary-emulation tooling (CALDERA, Atomic Red Team, stratus-red-team), Azure-native detection (Microsoft Sentinel, Azure Monitor, Network Watcher). All open-source or free.
- **Cloud:** one Azure subscription on the free tier for the core; managed Azure Firewall and VPN Gateway raised only in short validation windows.
- **Hardware:** a personal workstation only.
- **Cost:** approximately CAD 300, within the CAD 500 department limit. Director approval will be obtained before any expense is incurred.

## 8. Success criteria

- The environment provisions from empty accounts and is reproducible by a third party from the repository alone.
- Policy-as-code blocks deliberately non-compliant changes in CI.
- Every attack scenario has a recorded initial and post-remediation outcome, backed by log evidence.
- The report states honestly which failures can be caught deterministically and which can only be reduced.

## 9. Risks

| Risk | Mitigation |
|---|---|
| Scope creep in a four-month window | M2 is a minimum shippable core; the attack phase has an irreducible floor (the two mandatory scenarios plus the matrix) |
| Learning curve (Terraform, OPA, detection engineering) | Start CI and IaC on day one; keep the cloud count at one |
| Cloud cost | Free-tier core; paid firewall/gateway only in short windows; nightly automated teardown; budget alerts at 50% |
| Attacking a self-designed environment (known-answer) | Pre-register expected control and signal per scenario; optional short independent test |

## 10. Roles

- **Candidate:** Jian Chen — design, implementation, evaluation, reporting.
- **Mentor / supervisor:** Leonard Rogers — supervision and evaluation.

## 11. Status

Proposal submitted for approval; awaiting registration. Repository scaffolding in progress.
