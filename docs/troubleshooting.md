# Troubleshooting — Cross-Spoke Data Access

Real failures encountered during this build, documented with root cause, diagnosis steps, and resolution. Every entry reflects an actual error from this deployment session.

---

## 1. `local.*` References in Refactored Module

**Error:**

```
Error: Reference to undeclared local value
  on ../../modules/networking/main.tf line 26
  local.hub_resource_group_name has not been declared
```

**Root cause:** The networking module was refactored from a root configuration (which had a `data.tf` defining `locals {}`) into a reusable module. The `locals` block was removed but the references inside `main.tf` were not updated to use `var.*` instead.

**Why it happens:** When code is moved from a root configuration to a module, `locals` populated from `terraform_remote_state` data sources move to the calling stack. The module receives values as input variables, not local values. The references inside the module must be updated to match.

**Fix:**

```hcl
# Before (broken — references locals that no longer exist)
resource_group_name = local.hub_resource_group_name
virtual_network_name = local.hub_vnet_name
remote_virtual_network_id = local.hub_vnet_id

# After (correct — references input variables)
resource_group_name = var.hub_resource_group_name
virtual_network_name = var.hub_vnet_name
remote_virtual_network_id = var.hub_vnet_id
```

**Diagnosis:** `terraform validate` catches this immediately. The error message names the exact file and line number.

---

## 2. Remote State Output Name Mismatch

**Error:**

```
Error: Unsupported attribute
  data.terraform_remote_state.connectivity.outputs.resource_group_name
  is null
```

**Root cause:** The connectivity stack exported `resource_group_name` but the value returned was not what the networking stack expected. Additionally, a duplicate output was accidentally added to the wrong stack's `outputs.tf`.

**Why it happens:** Remote state reads are not validated at write time. You can reference any output name and Terraform will not complain until plan time when it attempts to read the actual value. If the output doesn't exist in the upstream state, it returns null silently.

**Diagnosis:**

```bash
# Download and inspect the upstream state directly
az storage blob download \
  --account-name sttfstate7tcl \
  --container-name tfstate \
  --name platform-connectivity.tfstate \
  --file /tmp/connectivity.tfstate

cat /tmp/connectivity.tfstate | python3 -c "
import json, sys
state = json.load(sys.stdin)
for k, v in state.get('outputs', {}).items():
    print(f'{k}: {v[\"value\"]}')
"
```

**Fix:** Match the reference in the consuming stack to the exact output name in the producing stack. Never guess — always inspect the state file.

---

## 3. Duplicate `data` Block in private-dns Stack

**Error:**

```
Error: Duplicate data source configuration
  A data source named "networking" was already declared at main.tf:1
```

**Root cause:** Two `data "terraform_remote_state" "networking"` blocks in `private-dns/main.tf` — one reading `platform-connectivity.tfstate` and one reading `spoke-data-access-networking.tfstate`. Both had the same local name `networking`.

**Fix:** Give each block a distinct local name:

```hcl
data "terraform_remote_state" "connectivity" {
  config = { key = "platform-connectivity.tfstate" }
}

data "terraform_remote_state" "data_spoke" {
  config = { key = "spoke-data-access-networking.tfstate" }
}
```

---

## 4. Connectivity Plan Showing DNS Outputs Going to Null

**Symptom:**

```
Changes to Outputs:
  - private_dns_zone_blob_id = "..." -> null
  - private_dns_zone_acr_id  = "..." -> null
```

**Root cause:** The DNS zones had been destroyed and removed from Terraform state. The outputs in `platform/connectivity/outputs.tf` still referenced `azurerm_private_dns_zone.blob.id` — a resource that no longer existed in state. Terraform resolves this to null.

**Why it is dangerous:** Downstream stacks reading these outputs via `terraform_remote_state` receive null instead of a real resource ID. This causes silent failures — the private endpoint gets created with a null DNS zone ID, which either errors or creates a misconfigured endpoint.

**Fix:** Either restore the managed resources (correct long term) or remove outputs that reference non-existent resources. Do not leave null-producing outputs in a state file that downstream stacks depend on.

---

## 5. DNS Zone Conflict — Duplicate Zone Across Stacks

**Symptom:**

```
Error: A resource with the ID already exists
  privatelink.blob.core.windows.net in rg-platform-connectivity
```

**Root cause:** Two separate Terraform stacks (`platform/connectivity` and `terraform/stacks/private-dns`) both attempted to create `azurerm_private_dns_zone` with the name `privatelink.blob.core.windows.net` in the same resource group. Azure does not allow duplicate zone names in the same resource group.

**Why it happens:** Copy-paste architecture. The private-dns stack was scaffolded from the project design without checking whether the connectivity stack already owned the zone.

**Fix:** Delete the redundant private-dns stack entirely. The connectivity stack is the authoritative owner. Workload stacks consume the zone ID via remote state or data source lookup, they never create their own zones.

**Rule:** One resource, one owner, one state file.

---

## 6. VNet Links Not Appearing in Plan

**Symptom:** After adding `data_access` to `spoke_vnet_ids` in the connectivity stack, `terraform plan` showed no new VNet link resources.

**Root cause:** The VNet link resources used `private_dns_zone_name = azurerm_private_dns_zone.blob.name` a managed resource reference. The DNS zones had been destroyed and were no longer in state. Terraform evaluated the resource reference, found nothing, and silently dropped the dependent resources from the plan.

**Why it is insidious:** No error is produced. The resources simply do not appear in the plan. Without understanding the dependency chain, this looks like the code is correct and working. When in fact nothing will be created.

**Diagnosis:** Check whether the referenced resource exists in state:

```bash
terraform state list | grep private_dns_zone
# If empty — the zone is not in state, dependent resources will be dropped
```

**Fix:** Replace managed resource references with data source lookups when the resource is ephemeral or managed by another stack:

```hcl
# Replace
private_dns_zone_name = azurerm_private_dns_zone.blob.name

# With
private_dns_zone_name = data.azurerm_private_dns_zone.blob.name
```

---

## 7. ACI Subnet Delegation Conflict

**Error:**

```
SubnetDelegationsCannotChangeWhenSubnetUsedByResource
Delegations of subnet snet-data-access cannot be changed from []
to [Microsoft.ContainerInstance/containerGroups]
because it is being used by resource pe-stdataaccessa0j8qg-blob.nic...
```

**Root cause:** The validation step attempted to deploy an Azure Container Instance into `snet-data-access` to test DNS resolution. That subnet already contained the Private Endpoint NIC. Azure cannot add the ACI delegation (`Microsoft.ContainerInstance/containerGroups`) to a subnet that is already in use by a non-delegated resource.

**Why it happens:** Private Endpoints require a subnet with no delegation. ACI requires a subnet with ACI delegation. They are mutually exclusive in the same subnet.

**Fix:** Use CLI-based validation instead of deploying a test container:

```bash
# Validate Private Endpoint provisioning state
az network private-endpoint show \
  --name pe-<storage-name>-blob \
  --resource-group rg-data-access \
  --query "{state:provisioningState, ip:customDnsConfigs[0].ipAddresses[0]}" \
  -o table

# Validate A record registration
az network private-dns record-set a list \
  --resource-group rg-platform-connectivity \
  --zone-name "privatelink.blob.core.windows.net" \
  -o table

# Validate VNet links
az network private-dns link vnet list \
  --resource-group rg-platform-connectivity \
  --zone-name "privatelink.blob.core.windows.net" \
  --query "[].{name:name, state:virtualNetworkLinkState}" \
  -o table
```

If all three return expected values, DNS resolution is working correctly without needing a container.

---

## 8. Provider Version Inconsistency Across Stacks

**Observation:** The existing landing zone stacks (`landing-zones/app-dev/*`) use `azurerm ~> 3.80`. The new project stacks (`terraform/stacks/*`) use `azurerm ~> 4.0`. Both work independently but share the same state storage account.

**Risk:** If a future refactor attempts to combine these stacks or share modules between them, provider version constraints may conflict. The `~>` constraint allows patch updates but not major version changes.

**Current status:** Not a blocking issue — each stack initialises its own provider independently. Document it for awareness.

**Recommendation:** Standardise on `~> 4.0` for all new stacks. Migrate existing stacks to 4.x during a dedicated upgrade session. Do not mix major versions within the same module call chain.

---

## Validation Checklist

Use this after every deployment to confirm the system is working correctly end to end.

```bash
STORAGE_NAME="<your-storage-account-name>"
RG="rg-data-access"
DNS_RG="rg-platform-connectivity"
ZONE="privatelink.blob.core.windows.net"

echo "=== Private Endpoint ==="
az network private-endpoint show \
  --name "pe-${STORAGE_NAME}-blob" \
  --resource-group $RG \
  --query "{state:provisioningState, ip:customDnsConfigs[0].ipAddresses[0]}" \
  -o table

echo "=== DNS A Record ==="
az network private-dns record-set a list \
  --resource-group $DNS_RG \
  --zone-name $ZONE \
  -o table

echo "=== VNet Links ==="
az network private-dns link vnet list \
  --resource-group $DNS_RG \
  --zone-name $ZONE \
  --query "[].{name:name, state:virtualNetworkLinkState}" \
  -o table

echo "=== Public Access Status ==="
az storage account show \
  --name $STORAGE_NAME \
  --resource-group $RG \
  --query "publicNetworkAccess" \
  -o tsv
```

Expected output:

- Private Endpoint: `Succeeded`
- A record present with IP in `10.2.1.x`
- All VNet links: `Completed`
- Public access: `Disabled`
