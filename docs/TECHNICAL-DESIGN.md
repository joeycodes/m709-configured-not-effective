# Technical Design

**configured-not-effective** · hybrid cloud internetwork, adversarially validated
Companion to `PROJECT.md`. This document covers the how: architecture, network design, IaC, CI/CD, detection engineering, attack scenarios, and validation.

---

## 1. Goals of this design

1. Build a hybrid internetwork whose security rests on network-layer controls (segmentation, routing-enforced inspection, egress control).
2. Express everything as code, and block non-compliant configuration before it deploys.
3. Attack the controls under an assume-breach model and measure, with evidence, which hold and which fail silently.
4. For failures that go undetected, engineer detections as code and re-test until they fire.
5. Keep it reproducible and cheap (free-tier core, paid services only in short windows).

Non-goal: a novel detection algorithm or a generalizable study. This is an MSc-level design, implementation, and evaluation.

---

## 2. Architecture overview

Two domains joined over an IPsec tunnel running eBGP:

- **On-premises (simulated):** a single edge router (FRRouting + StrongSwan on a free-tier VM) advertising the on-prem prefix via BGP, standing in for a customer edge device.
- **Azure:** a hub-and-spoke of four virtual networks. The hub carries the tunnel endpoint and the firewall; three spokes are the trust tiers. Routing forces all inter-spoke and outbound traffic up through the hub firewall, which is the only path to the internet.

A full topology diagram lives in `docs/diagrams/` (exported from the source `.drawio`). Textual summary:

```
                internet
                   |
             [ hub: firewall + tunnel endpoint ]
              /        |          \
        Tier-0      Tier-1       Tier-2
      restricted  application   low-trust
                   |  (IPsec + eBGP)
             [ simulated on-premises ]
```

**Connectivity choice.** The tunnel is terminated primarily by self-hosted FRR + StrongSwan on free-tier micro VMs (cheap, rebuilds in minutes, full BGP timer control). The managed Azure VPN Gateway is exercised only in short, time-boxed validation windows to confirm the design works on the native product, then destroyed. Same for the managed Azure Firewall: a self-hosted inspection host (nftables/Suricata) is used for routine testing, with the managed firewall raised only in validation windows.

---

## 3. Network design

### 3.1 Address plan

Non-overlapping, hierarchical, with room reserved for a future second cloud.

| Domain | Supernet | Segment | Prefix | Purpose |
|---|---|---|---|---|
| On-premises | 10.0.0.0/16 | core | 10.0.0.0/24 | legacy core, edge router |
| Azure | 10.100.0.0/14 | hub VNet | 10.100.0.0/16 | firewall, tunnel endpoint, DNS |
| | | Tier-0 (restricted) | 10.101.0.0/16 | sensitive assets, default-deny egress |
| | | Tier-1 (application) | 10.102.0.0/16 | business workloads |
| | | Tier-2 (low-trust) | 10.103.0.0/16 | dev and test |
| Reserved | 10.200.0.0/14 | (future AWS) | — | cross-provider extension only |

Within each VNet, subnets are carved as /24s (for example the hub uses 10.100.0.0/24 for the firewall subnet, 10.100.1.0/24 for the gateway/router subnet).

### 3.2 Routing and enforcement

- Spokes peer to the hub; there is no direct spoke-to-spoke peering.
- User-defined routes (UDRs) on each spoke send `0.0.0.0/0` and inter-spoke traffic to the firewall's private IP as next hop.
- eBGP runs between the on-prem edge router and the Azure tunnel endpoint; the on-prem prefix is learned dynamically.
- The restricted tier (Tier-0) denies egress by default; any outbound destination is explicitly allow-listed.

The security posture therefore depends on three network-layer controls: **segmentation** (NSG/ASG), **routing-enforced inspection** (UDR forcing traffic through the firewall), and **egress control** (default-deny plus allow-list). These three are the objects under test.

### 3.3 DNS

Hub-based resolution (Azure DNS Private Resolver, or the firewall acting as DNS proxy). DNS query logging is enabled because it is the detection signal source for the DNS-tunnelling exfiltration scenario.

---

## 4. Infrastructure as code

### 4.1 Repository layout

```
configured-not-effective/
  README.md
  PROJECT.md
  docs/
    TECHNICAL-DESIGN.md
    adr/                     architecture decision records
    diagrams/                topology (exported from .drawio)
  infra/
    modules/
      network/               vnet, subnets, peering, UDR
      connectivity/          FRR + StrongSwan VM (or managed VPN GW)
      firewall/              Azure Firewall, feature-flagged (on-demand)
      tiers/                 tier-0/1/2 spokes, NSG/ASG rules
      logging/               Log Analytics, flow logs, diagnostic settings
    envs/
      lab/                   the single lab environment
        main.tf  variables.tf  backend.tf
    policy/                  Rego policies, Checkov/tfsec config
    detections/             KQL analytics rules, reachability assertions
  .github/workflows/
    plan.yml  apply.yml  nightly-destroy.yml
  attack/
    scenarios/              scenario definitions and runbooks
    tooling/                CALDERA / Atomic / stratus configs
  results/
    control-effectiveness-matrix.md
```

### 4.2 State, identity, and bootstrap

- **Remote state:** an Azure Storage backend, part of the persistent base (never destroyed). State locking via blob lease.
- **Authentication:** GitHub Actions authenticates to Azure via OIDC federation. No long-lived credentials in CI. The CI identity is the only principal granted deploy permissions; human accounts are read/plan only, so a local `terraform apply` cannot bypass the pipeline.
- **Bootstrap (one-time, manual):** create the state backend and the OIDC trust. Everything else flows through CI. Recorded in an ADR.

---

## 5. CI/CD pipeline

CI is used from day one; it is the enforcement point for the "prevent" stage, not an afterthought.

**`plan.yml` (on pull request):**
1. checkout; `setup-terraform`
2. OIDC login to Azure
3. `terraform init` (remote state); `fmt`, `validate`
4. `terraform plan -out`
5. **policy gate:** OPA/Rego via `conftest` against the plan; Checkov and tfsec as secondary scanners. Non-compliant plan fails the check.
6. **reachability assertion:** deterministic check that Tier-2 cannot reach Tier-0 (see 6.3). Fails the check if reachable.
7. post results to the PR.

**`apply.yml` (on merge to `main`, environment-gated):**
1. re-plan and re-check policy
2. manual approval (GitHub environment protection)
3. `terraform apply`

**`nightly-destroy.yml` (cron, 23:00):**
- Destroy the paid layer only, via a feature flag: `terraform apply -var="enable_firewall=false"` (and the managed gateway if it was raised). The free-tier core and the persistent base remain. This closes the largest cost risk (a forgotten paid resource) without relying on memory.

Policy-as-code lives in `infra/policy/`. Example guardrails: deny any subnet without an associated NSG; deny a public IP on a Tier-0 resource; require a route table whose default next hop is the firewall on every spoke; require standard tags.

---

## 6. Detection engineering

The platform emits raw telemetry; the contribution is the detection logic on top and the proof it fires. No third-party SIEM.

### 6.1 Telemetry sources

- NSG flow logs → Log Analytics
- Azure Activity Log (control-plane changes)
- Azure Firewall logs (traffic and DNS proxy)
- DNS query logs (for the exfiltration scenario)

### 6.2 Detection-as-code (runtime, declarative)

Detections are authored as Microsoft Sentinel analytics rules (KQL), version-controlled in `infra/detections/`, and deployed through the same CI pipeline as infrastructure. The rule encodes the intended policy, so a violation is a proven ineffective control rather than an anomaly guess. Example concept (lateral movement into Tier-0):

```kusto
// A flow that segmentation should have denied
AzureNetworkAnalytics_CL
| where SrcIP_s startswith "10.103."     // Tier-2 (low-trust)
    and DestIP_s startswith "10.101."    // Tier-0 (restricted)
    and FlowStatus_s == "A"              // ACCEPTED
| summarize hits = count() by SrcIP_s, DestIP_s, DestPort_d
```

Any result means the segmentation control was ineffective. A second, cross-log rule flags traffic that reached Tier-0 but has no corresponding entry in the firewall log (it bypassed inspection).

### 6.3 Deterministic assertions (pre-deploy, in CI)

Configuration-class failures are caught before any traffic flows: a CI step runs `az network watcher test-ip-flow` (and effective-routes checks) asserting Tier-2 → Tier-0 = Deny and that the spoke default route's next hop is the firewall. If the assertion fails, the pipeline fails. This is the strongest form of the test.

### 6.4 Where the judgment is made

| Layer | Where | What it decides |
|---|---|---|
| Pre-deploy | CI reachability assertion + policy-as-code | catches config-class failure before deploy (strongest) |
| Runtime, declarative | Sentinel KQL rule / Config-style checks | encodes intended policy; fires on violation (main workload) |
| Runtime, imperative | Azure Function (glue only) | cross-log correlation and orchestration a single query cannot express |

Principle: keep the judgment in declarative, version-controlled rules; use a Function only for what a query cannot express. No large imperative "brain".

---

## 7. Attack scenarios

**Model: assume-breach.** There is no production application to exploit; the attacker is taken to already hold a foothold in the low-trust tier (Tier-2). The test measures the containment provided by the network controls, not an application vulnerability. Rigour comes from exhaustive, evasion-aware coverage and from the genuinely adversarial scenarios below.

| # | Scenario | MITRE ATT&CK | Control under test | Expected signal | Mandatory |
|---|---|---|---|---|---|
| 1 | Lateral movement Tier-2 → Tier-0 | T1021 (Remote Services) | segmentation (NSG/ASG) | flow-log ACCEPT that should be REJECT | ✅ |
| 2 | Overly permissive NSG service tag allows traffic | T1021 | segmentation | flow-log ACCEPT | |
| 3 | Routing misconfig lets traffic bypass the firewall | T1562 (Impair Defenses) | routing-enforced inspection | flow present at Tier-0, absent in firewall log | |
| 4 | DNS tunnelling exfiltration via allowed egress | T1071.004 / T1048 | egress control | DNS query-log anomalies (entropy, length, rate) | ✅ |
| 5 | Exfiltration over legitimate HTTPS 443/CDN | T1567 (Exfil over Web Service) | egress control | outbound volume anomaly from Tier-0 | |
| 6 | Cloud credential abuse: SSRF → instance metadata → steal role → move via cloud APIs | T1552.005 (Cloud Instance Metadata API) | identity, not network | Activity Log / control-plane anomalies | (recommended) |
| 7 | Attack from the on-prem side of the VPN (over-trusted tunnel) | T1199 (Trusted Relationship) | segmentation across the tunnel | flow-log at hub / Tier boundaries | |
| 8 | Detection evasion: low-and-slow via allowed channels | TA0005 (Defense Evasion) | the detections themselves | (measures what produces no signal) | |

Tooling: CALDERA, Atomic Red Team, and cloud-specific tooling such as stratus-red-team, supplemented by manual technique. Scenario definitions and runbooks live in `attack/scenarios/`. Under schedule pressure, the mandatory set is #1 and #4; scenario #6 is recommended because it is a control-plane attack that network segmentation cannot stop, which makes it a strong demonstration of the "configured but ineffective" thesis.

---

## 8. Validation and results

For each scenario, record the outcome before and after remediation. Schema of `results/control-effectiveness-matrix.md`:

| Scenario | ATT&CK | Expected control | Prevented? (initial) | Detected? (initial) | MTTD | Remediation | Prevented? (post) | Detected? (post) | Evidence |
|---|---|---|---|---|---|---|---|---|---|

Where a failure went undetected, a new detection is authored (6.2), committed, and the scenario re-run to confirm it fires. Every row cites log evidence (a query result, an alert, or a screenshot).

**Honest boundary (a result in itself).** Configuration-class failures (for example lateral movement enabled by a routing or segmentation error) can be detected deterministically and pre-emptively, approaching full reliability. Behavioural failures (for example exfiltration through a legitimately permitted channel) can only be monitored probabilistically and narrowed, never eliminated, and a patient attacker can evade them. The report states this asymmetry plainly rather than claiming everything is detectable.

---

## 9. Security and ethics of the offensive work

- All testing is confined to candidate-owned accounts; no third-party systems and no real data.
- The environment is disposable by design and rebuilt from code.
- Adversary tooling is run only against the lab environment.

---

## 10. Future extensions (out of baseline scope)

- **Second cloud (AWS):** mirror the design (Transit Gateway, Network Firewall) and run the same scenario suite for a cross-provider comparison.
- **Kubernetes tier (AKS):** add a workload spoke with pod-level network policy to widen the attack surface.

Neither is required for the core result; both are natural next steps if the schedule allows.
