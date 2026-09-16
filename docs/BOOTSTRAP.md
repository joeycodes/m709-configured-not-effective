# Bootstrap and CI Preparation (Azure for Students)

Work through these in order. Steps 0 to 6 are one-time setup; only after the pipeline "hello world" in step 6 works do you start building the real network (M1).

The logic: CI is used from day one, but the pipeline needs a remote state store and an identity to exist *before* it can run. Those two things are created manually, once. Everything after that goes through CI.

---

## 0. Respect the student-subscription limits first

| Limit | What to do |
|---|---|
| Resource creation restricted to a few regions | Pick ONE allowed region and use it everywhere. Probe with `az group create -n rg-probe -l <region>` (delete after). Region is only a lab setting, so any allowed region is fine. |
| ~USD 100 credit, no credit card | The subscription pauses when the credit is spent (no overspend, no charge). The core is cheap; do NOT stand up the managed Firewall or VPN Gateway during bootstrap. |
| Low vCPU quota per region | Use B1s VMs; keep the count low. Request a quota bump in the portal if needed (small bumps are usually auto-approved). |
| Managed services may be limited | The self-hosted core does not need them. If a managed validation window ever exceeds the USD 100 credit, run that window on a separate pay-as-you-go subscription and claim it under the CAD 500 department reimbursement (with Director approval first). |

Set your region once and reuse it: `LOCATION=<your-allowed-region>` (example below uses `canadacentral`).

---

## 1. Prerequisites

- Install and log in: Azure CLI (`az login`), Terraform, git.
- Create the GitHub repository (`configured-not-effective`).
- Note your IDs: `az account show --query "{sub:id, tenant:tenantId}" -o json`.

---

## 2. One-time manual bootstrap

### 2a. Remote state backend (persistent base, never destroyed)

```bash
LOCATION=canadacentral
az group create -n rg-tfstate -l $LOCATION
az storage account create -n sttfstate<unique-suffix> -g rg-tfstate \
  -l $LOCATION --sku Standard_LRS --encryption-services blob
az storage container create -n tfstate \
  --account-name sttfstate<unique-suffix> --auth-mode login
```

State locking is automatic with the azurerm backend (blob lease). This resource group is never destroyed by the nightly teardown.

### 2b. CI identity via GitHub OIDC (no long-lived secrets)

```bash
GH=<your-github-username>
az ad app create --display-name "gh-configured-not-effective"     # note the appId
az ad sp create --id <appId>

# federated credential for the main branch
az ad app federated-credential create --id <appId> --parameters '{
  "name":"gh-main",
  "issuer":"https://token.actions.githubusercontent.com",
  "subject":"repo:'"$GH"'/configured-not-effective:ref:refs/heads/main",
  "audiences":["api://AzureADTokenExchange"]
}'
# a second one for pull requests (plan on PR)
az ad app federated-credential create --id <appId> --parameters '{
  "name":"gh-pr",
  "issuer":"https://token.actions.githubusercontent.com",
  "subject":"repo:'"$GH"'/configured-not-effective:pull_request",
  "audiences":["api://AzureADTokenExchange"]
}'

az role assignment create --assignee <appId> --role Contributor \
  --scope /subscriptions/<SUB_ID>
```

Record `client-id (appId)`, `tenant-id`, and `subscription-id` for step 4.

Note: on a single-owner student subscription you cannot truly lock yourself out of `apply`, since you own the subscription. "CI is the only deploy path" is therefore a documented discipline here (a dedicated CI identity, all applies through the pipeline, remote shared state), not a hard technical control. Record the whole bootstrap in `docs/adr/ADR-000-bootstrap.md`.

---

## 3. Repository scaffolding (in Git)

- `infra/envs/lab/backend.tf` and `providers.tf` using OIDC:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstate<unique-suffix>"
    container_name       = "tfstate"
    key                  = "lab.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
  use_oidc = true
}
```

- `infra/envs/lab/main.tf`: for the loop test, just one resource group.
- `infra/policy/`: one starter Rego rule (for example, require standard tags) plus a Checkov/tfsec config.
- `.github/workflows/`: `plan.yml`, `apply.yml`, `nightly-destroy.yml`.

---

## 4. GitHub repository settings

- Store as repository **Variables** (OIDC needs no secret): `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`.
- Workflow permissions in each workflow: `id-token: write`, `contents: read`.
- Create an **Environment** named `production` with a **required reviewer** (this is the manual approval gate before `apply`).
- Enable **branch protection** on `main`: require a pull request and require the `plan` + policy checks to pass before merge.

Azure login step used by the workflows:

```yaml
permissions:
  id-token: write
  contents: read
steps:
  - uses: azure/login@v2
    with:
      client-id: ${{ vars.AZURE_CLIENT_ID }}
      tenant-id: ${{ vars.AZURE_TENANT_ID }}
      subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

---

## 5. Guardrails from day one

- **Budget + alert** at 50% of the monthly budget (belt and suspenders; the USD 100 credit also auto-pauses).
- **Tag convention**: tag every ephemeral resource (for example `layer=ephemeral`) so the nightly teardown can target only the disposable layer.
- **Feature flag** `enable_firewall = false` by default. Do not build the paid managed layer during bootstrap.

---

## 6. Prove the loop before building anything real

Run the minimal `envs/lab` (one resource group) through the full pipeline:

```
open PR  ->  plan  ->  policy check  ->  approve  ->  apply  ->  state written to the remote backend
```

When this succeeds, the whole chain (CI, Terraform, Azure, remote state, OIDC auth) is proven end to end. This is the pipeline's "hello world" and de-risks everything downstream. It is the seed of the M2 minimum-shippable milestone.

---

## 7. Only then start M1

With the loop working, adding the real network (VNets, subnets, UDRs, tiers, self-hosted VPN/BGP, logging) is pure content, no longer blocked by environment, identity, or pipeline problems.
