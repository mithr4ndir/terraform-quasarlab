# terraform-quasarlab — QuasarLab Infrastructure

Terraform configurations for provisioning VMs on a 2-node Proxmox cluster. Uses a reusable VM module and 1Password for credential management.

## VMs Managed

| VM | Module Path | IP | Cores | RAM | Storage | Host |
|----|------------|-----|-------|-----|---------|------|
| k8cluster1 | `proxmox/kubernetes/` | 192.168.1.90 | 8 | 16 GB | truenas-iscsi | pve |
| k8cluster2 | `proxmox/kubernetes/` | 192.168.1.89 | 8 | 16 GB | truenas-iscsi | pve2 |
| k8cluster3 | `proxmox/kubernetes/` | 192.168.1.91 | 8 | 16 GB | truenas-iscsi | pve |
| nginx1 | `proxmox/nginx/` | 192.168.1.92 | 2 | 4 GB | truenas-iscsi | pve |
| nginx2 | `proxmox/nginx/` | 192.168.1.93 | 2 | 4 GB | truenas-iscsi | pve |
| jellyfin | `proxmox/jellyfin/` | 192.168.1.170 | 6 | 12 GB | truenas-iscsi | pve2 |
| wazuh | `proxmox/wazuh/` | 192.168.1.171 | 4 | 16 GB | truenas-iscsi | pve |
| command-center1 | `proxmox/command-center/` | 192.168.1.88 | 4 | 8 GB | truenas-iscsi | pve2 |
| fleetdm | `proxmox/fleetdm/` | — | 4 | 8 GB | truenas-iscsi | — |

## Directory Layout

```
terraform-quasarlab/
├── modules/proxmox/vm/       # Reusable VM module (generic Proxmox VM)
├── proxmox/
│   ├── kubernetes/           # 3-node K8s cluster
│   ├── nginx/                # HA load balancer pair
│   ├── jellyfin/             # Media server (GPU passthrough host)
│   ├── wazuh/                # SIEM (1Password provider for credentials)
│   ├── command-center/       # Management VM
│   └── fleetdm/              # Fleet device management
```

## Credentials

The `wazuh` module uses the **1Password Terraform provider** — credentials are fetched at runtime from the `Infrastructure` vault via `OP_SERVICE_ACCOUNT_TOKEN` env var.

Older modules use `terraform.tfvars` (gitignored) with:
```hcl
pm_api_url  = "https://<pve-host>:8006/api2/json"
pm_user     = "root@pam"
pm_password = "..."
```

## State

Terraform state is stored on NFS at `/mnt/terraform-state/state/<module>/terraform.tfstate` (not in git).

## Usage

```bash
cd proxmox/wazuh
export OP_SERVICE_ACCOUNT_TOKEN="..."
terraform init
terraform plan
terraform apply
```

## Related Repos

| Repository | Purpose |
|------------|---------|
| [ansible-quasarlab](https://github.com/mithr4ndir/ansible-quasarlab) | Post-provisioning configuration for all VMs |
| [k8s-argocd](https://github.com/mithr4ndir/k8s-argocd) | Kubernetes workloads deployed via ArgoCD |
| [observability-quasarlab](https://github.com/mithr4ndir/observability-quasarlab) | Grafana dashboards and monitoring config |
