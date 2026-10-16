#!/usr/bin/env bash

failures=0

die () {
  echo ERROR: "$*" >&2
  exit 1
}

# Read NVA private IP address from lab.rego
expected_nva=$(sed -n 's/^nva_ip := "\(.*\)"$/\1/p' infra/policy/lab.rego)
[[ -n "$expected_nva" ]] || die "cannot read nva_ip from infra/policy/lab.rego"

[[ "$expected_nva" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "nva_ip in lab.rego is not an IPv4 address: $expected_nva"

# Retrieve the resource group name. Fail if it is empty or cannot be retrieved.
rg=$(terraform -chdir=infra/envs/lab output -raw resource_group_name) || die "Failed to retrieve resource group name from Terraform output."
[[ -n "$rg" ]] || die "Resource group name is empty."

# Retrieve the spoke VM names. Fail if they are empty or cannot be retrieved.
spoke_vms=$(terraform -chdir=infra/envs/lab output -json spoke_vm_names) || die "Failed to retrieve spoke VM names from Terraform output."
[[ -n "$spoke_vms" ]] || die "Spoke VM names are empty."

for tier in tier0 tier1 tier2; do
  # 1. VM name for this tier          -> vm
  tier_vm=$(jq -er ".${tier}" <<< "$spoke_vms") || die "Failed to retrieve spoke VM name for $tier from Terraform output."
  [[ -n "$tier_vm" ]] || die "Spoke VM name for $tier is empty."
  # 2. NIC count must be 1, then NIC id -> nic_id
  tier_nic_count=$(az vm show -g "$rg" -n "$tier_vm" --query 'length(networkProfile.networkInterfaces)' -o tsv) || die "Failed to retrieve NIC count for $tier_vm"
  [[ "$tier_nic_count" -eq 1 ]] || die "Expected 1 NIC for $tier_vm, but found $tier_nic_count."
  # 3. effective routes                -> routes
  tier_nic_id=$(az vm show -g "$rg" -n "$tier_vm" --query 'networkProfile.networkInterfaces[0].id' -o tsv) || die "Failed to retrieve NIC ID for $tier_vm"
  [[ -n "$tier_nic_id" ]] || die "NIC id for $tier_vm is empty."
  # 4. checks on $routes, each printing PASS/FAIL and counting failures
  tier_routes=$(az network nic show-effective-route-table --ids "$tier_nic_id") || die "Failed to retrieve effective route table for $tier_vm"
  
  for prefix in "0.0.0.0/0" "10.100.0.0/14"; do 
    matches=$(jq --arg prefix "$prefix" --arg nva "$expected_nva" '
      [ .value[]
        | select(.addressPrefix == [$prefix])
        | select(.source == "User")
        | select(.nextHopType == "VirtualAppliance")
        | select(.nextHopIpAddress == [$nva])
        | select(.state == "Active")
      ] | length
    ' <<< "$tier_routes") \
      || die "Failed to count matching routes for $tier_vm and prefix $prefix"

    if [[ "$matches" -eq 1 ]]; then
      echo "PASS: $tier_vm has a single active user route for $prefix via the NVA"
    else
      echo "FAIL: $tier_vm does not have the expected route for $prefix via the NVA, found $matches."
      failures=$((failures + 1))
    fi
  done

  default_matches=$(jq '
      [ .value[]
        | select(.addressPrefix == ["0.0.0.0/0"])
        | select(.source == "Default")
        | select(.nextHopType == "Internet")
        | select(.state == "Invalid")
      ] | length
  ' <<< "$tier_routes") \
    || die "Failed to count the default system route for $tier_vm"
  
  if [[ "$default_matches" -eq 1 ]]; then
    echo "PASS: illegal Azure implemented default route is invalid for $tier_vm."
  else
    echo "FAIL: found illegal Azure implemented default route for $tier_vm: $default_matches."
    failures=$((failures + 1))
  fi
done

# Exit code based on the number of failures. 0 = all passed, 1 = at least one failed.
exit $((failures > 0))
