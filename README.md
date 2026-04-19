# Project 01 — Controlled Cross-Spoke Data Access with Private DNS Resolution

> **Series:** Azure Platform Engineering — Real-World Projects  
> **Pillar Focus:** Networking (primary) · Storage ·
> **Status:** Deployed and validated in Azure, documented in this repo.

---

## Overview

This project implements controlled, private data access between two Azure spoke VNets routed through a centralised hub. An application workload in one spoke securely reads from a storage account in a second spoke without public internet exposure, without stored credentials, and with all traffic routing through the hub for governance.

The core challenge is not the individual components. It is wiring them together correctly: routing that forces cross-spoke traffic through the hub, DNS resolution that returns private IPs across all VNets, and identity-based authentication that requires no secrets.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  rg-platform-connectivity                                       │
│                                                                 │
│  vnet-hub (10.0.0.0/16)                                         │
│  ┌─────────────────────────────────────────────┐                │
│  │  snet-shared-services (10.0.1.0/24)         │                │
│  │  snet-appgw (10.0.2.0/24)                   │                │
│  └─────────────────────────────────────────────┘                │
│                                                                 │
│  Private DNS Zone: privatelink.blob.core.windows.net            │
│  Linked to: vnet-hub · vnet-app-dev · vnet-data-access          │
└───────────────────┬─────────────────────────┬───────────────────┘
                    │ peering                  │ peering
       ┌────────────▼──────────┐  ┌────────────▼──────────────┐
       │  rg-app-dev           │  │  rg-data-access            │
       │                       │  │                            │
       │  vnet-app-dev         │  │  vnet-data-access          │
       │  (10.1.0.0/16)        │  │  (10.2.0.0/16)             │
       │                       │  │                            │
       │  Application          │  │  snet-data-access          │
       │  workloads            │  │  (10.2.1.0/24)             │
       │                       │  │                            │
       │                       │  │  Storage Account           │
       │                       │  │  Private Endpoint          │
       │                       │  │  NIC: 10.2.1.x             │
       └───────────────────────┘  └────────────────────────────┘
```

### Component Map

| Component                              | Pillar               | Purpose                                 |
| -------------------------------------- | -------------------- | --------------------------------------- |
| `vnet-data-access`                     | Networking           | Isolated spoke for data workloads       |
| VNet peering (hub ↔ data-access)       | Networking           | Layer-3 adjacency to hub                |
| Private DNS Zone (blob)                | Networking           | Resolves storage FQDN to private IP     |
| VNet links (hub, app-dev, data-access) | Networking           | Enables private DNS resolution per VNet |
| `st-data-access` (Storage Account)     | Storage              | Data plane — public access disabled     |
| Private Endpoint on blob               | Storage + Networking | Injects private NIC into subnet         |
| System-assigned Managed Identity       | Identity             | VM authenticates without credentials    |
| RBAC: Storage Blob Data Reader         | Identity             | Authorises identity at data plane       |

---

## Repository Structure

```
terraform/
├── modules/                    # Stateless reusable logic — no backend blocks
│   ├── networking/
│   │   ├── main.tf             # VNet, subnet, bidirectional peering
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── private-dns/
│   │   ├── main.tf             # DNS zone + for_each VNet links
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── storage/
│       ├── main.tf             # Storage account + private endpoint
│       ├── variables.tf
│       └── outputs.tf
└── stacks/                     # Root configurations — own state, call modules
    ├── networking/
    │   ├── versions.tf         # Provider + backend
    │   ├── data.tf             # Reads platform-connectivity remote state
    │   ├── main.tf             # Calls networking module
    │   └── outputs.tf          # Exposes VNet/subnet IDs for downstream stacks
    └── storage/
        ├── versions.tf
        ├── data.tf             # Reads networking + connectivity remote state
        └── main.tf             # Calls storage module
```

---

## Key Design Decisions

### Modules vs Stacks

Terraform modules are stateless, reusable logic with no backend. Stacks are root configurations that own state and call modules. Conflating the two placing backend blocks inside module directories produces non-callable, non-reusable code. This project enforces the separation explicitly.

### DNS Zone Ownership

Private DNS zones live in `platform/connectivity`, owned by the connectivity stack. Workload stacks are consumers. They reference the zone ID via remote state output, they do not create their own zones. This prevents duplicate zones across stacks and ensures a single authoritative owner.

Adding a new spoke requires one change: add its VNet ID to `spoke_vnet_ids` in the connectivity stack's (repo: Azure-landing-zone) `private-dns.tf`. The `for_each` on VNet link resources handles the rest automatically.

### Cross-Spoke Routing

VNet peering in Azure is non-transitive. Spoke A peered to hub and Spoke B peered to hub cannot reach each other without explicit routing. User Defined Routes (UDRs) in each spoke force default traffic toward the hub's forwarding IP. IP forwarding must be enabled both on the NVA's Azure NIC and at the OS level.

### Identity Without Secrets

The application VM authenticates to the storage account using a system-assigned Managed Identity. Token acquisition happens via the Instance Metadata Service at `169.254.169.254` — a link-local address reachable only from within the VM. No connection strings, no SAS tokens, no rotation required.

---

## DNS Resolution Flow

When an application queries `stdataaccess.blob.core.windows.net`:

```
1. VM sends query to 168.63.129.16 (Azure platform DNS)
2. Azure DNS checks for Private DNS Zones linked to this VNet
3. Finds: privatelink.blob.core.windows.net → linked to vnet-data-access
4. CNAME: stdataaccess.blob.core.windows.net
       → stdataaccess.privatelink.blob.core.windows.net
5. A record lookup in Private DNS Zone → 10.2.1.x
6. Returns private IP to caller
```

Without the VNet link, step 3 finds nothing. Azure DNS falls through to public resolution and returns the storage account's public IP. If public access is disabled (as it is here), the connection fails. If it is not disabled, traffic goes over the public internet — defeating the entire purpose of the Private Endpoint.

---

## Terraform State Architecture

```
sttfstate7tcl (rg-tfstate)
├── platform-connectivity.tfstate     → hub VNet, DNS zones, VNet links
├── spoke-data-access-networking.tfstate  → vnet-data-access, subnet, peering
└── spoke-data-access-storage.tfstate    → storage account, private endpoint
```

Each stack reads upstream outputs via `terraform_remote_state`. No hardcoded resource IDs. A failed storage deployment cannot corrupt networking state.

---

## Deployment

### Prerequisites

- Azure CLI authenticated (`az login`)
- Terraform >= 1.12.0
- Platform connectivity stack already applied
- `platform-connectivity.tfstate` present in the state storage account

### Deployment Order

```bash
# 1. Deploy networking spoke
cd terraform/stacks/networking
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 2. Link new spoke VNet to blob DNS zone (connectivity stack)
cd platform/connectivity
terraform plan -out=tfplan
# Verify: 4 VNet links to add, 0 to destroy
terraform apply tfplan

# 3. Deploy storage
cd terraform/stacks/storage
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Validation

```bash
# Confirm Private Endpoint is provisioned
az network private-endpoint show \
  --name pe-stdataaccessa0j8qg-blob \
  --resource-group rg-data-access \
  --query "{state:provisioningState, ip:customDnsConfigs[0].ipAddresses[0]}" \
  -o table

# Confirm A record was auto-registered
az network private-dns record-set a list \
  --resource-group rg-platform-connectivity \
  --zone-name "privatelink.blob.core.windows.net" \
  -o table

# Confirm VNet links are active
az network private-dns link vnet list \
  --resource-group rg-platform-connectivity \
  --zone-name "privatelink.blob.core.windows.net" \
  --query "[].{name:name, state:virtualNetworkLinkState}" \
  -o table
```

Expected results:

- Private Endpoint state: `Succeeded`
- A record present with IP in `10.2.1.x` range
- VNet links: `Completed` for hub, app_dev, data_access

---

## Cost Profile

| Resource         | Monthly Cost  | Notes                   |
| ---------------- | ------------- | ----------------------- |
| Storage Account  | ~$0.02/GB     | Negligible at dev scale |
| Private Endpoint | ~$5.50        | Per endpoint            |
| VNet Peering     | ~$1           | Per GB data transfer    |
| Private DNS Zone | ~$0.50        | Per zone                |
| **Total**        | **~$7/month** | No compute running      |

Destroy when not in use. Storage account and DNS zone can remain; Private Endpoint is the meaningful cost.

---

## Failure Scenarios

See [`docs/troubleshooting.md`](docs/troubleshooting.md) for documented failure cases, diagnosis steps, and resolutions encountered during this build.

---
