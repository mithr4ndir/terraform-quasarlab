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
│   ├── wazuh/                # SIEM (credentials via scripts/tf-cached-secrets.sh)
│   ├── authentik/            # Authentik IdP (credentials via scripts/tf-cached-secrets.sh)
│   ├── command-center/       # Management VM
│   └── fleetdm/              # Fleet device management
```

## Credentials

The `wazuh` and `authentik` modules take Proxmox API and cloud-init credentials as `sensitive` input variables. Run them through `scripts/tf-cached-secrets.sh`, which exports `TF_VAR_*` values from the ansible-quasarlab 1Password file cache (`/var/lib/ansible-quasarlab/secrets`, 7 day TTL) and honors its rate-limit kill switch. A plan costs zero 1Password reads while the cache is fresh; `fmt`, `validate` and `init` never load credentials. The source item is `op://Infrastructure/Proxmox API` (override with `PVE_OP_ITEM`). Cache slugs are scoped per item as `tf_<name>.<16 hex chars of sha256 over the item reference>`, so an override never reuses another item's cached credentials; delete the matching `tf_*` files to force a refresh. Do not keep `plan -out` files: they contain variable values.

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
terraform init
../../scripts/tf-cached-secrets.sh plan
../../scripts/tf-cached-secrets.sh apply
```

Tests for the wrapper: `scripts/tests/test-tf-cached-secrets.sh` (stubs op and terraform, never reads a secret).

## Related Repos

| Repository | Purpose |
|------------|---------|
| [ansible-quasarlab](https://github.com/mithr4ndir/ansible-quasarlab) | Post-provisioning configuration for all VMs |
| [k8s-argocd](https://github.com/mithr4ndir/k8s-argocd) | Kubernetes workloads deployed via ArgoCD |
| [observability-quasarlab](https://github.com/mithr4ndir/observability-quasarlab) | Grafana dashboards and monitoring config |
