# terraform-quasarlab 🌐

A minimal Terraform repo to provision a 3‑node all‑in‑one Kubernetes cluster on Proxmox (each VM runs both control‑plane + worker), plus an external HAProxy VM for API/bootstrap load balancing.

---

## What You Need to Run This

- **Terraform 1.4+** (install via HashiCorp installer or your package manager)  
- **Proxmox API credentials** (`pm_api_url`, `pm_user`, `pm_password`)  
- **SSH key** in `~/.ssh/id_rsa.pub` for cloud-init access  
- **Proxmox template** (e.g. `ubuntu-24-04-cloud-init-template`) present on your node  
- **A `terraform.tfvars`** file (or environment variables) with your Proxmox details and VM defaults

---

## Directory Layout

```plaintext
terraform-quasarlab/
├── modules/
│   └── proxmox/
│       └── vm/               # module skeleton: generic VM logic for any service
├── proxmox/
│   └── command-center/       # example per-service directory using the proxmox/vm module
        ├── locals.tf                 # Local variables (e.g., VM definitions)
        ├── main.tf                   # Core resource declarations
        ├── variables.tf              # Input variable declarations
        └── outputs.tf                # Outputs (VM IDs & IPs)
        └── terraform.tfvars          # Not included and should not be put into git, var assigned described below     
```

---

## Quickstart
1. **Clone** the repo:
   ```bash
   git clone git@…/terraform-quasarlab.git
   cd terraform-quasarlab
   ```
2. **Create** a `terraform.tfvars` with:
   ```hcl
   pm_api_url      = "https://proxmox.local:8006/api2/json"
   pm_user         = "root@pam"
   pm_password     = "YOUR_PASS"
   pm_node         = "pve"

   # VM defaults
   storage_pool    = "truenas-iscsi"
   network_bridge  = "vmbr0"
   memory          = 16384
   cores           = 8
   sockets         = 1
   template        = "ubuntu-24-04-cloud-init-template"
   ```
3. **Initialize** Terraform:
   ```bash
   terraform init
   ```
4. **Plan** your changes:
   ```bash
   terraform plan
   ```
5. **Apply** and watch your VMs spin up:
   ```bash
   terraform apply -auto-approve

---

## Tips & Tricks
- **Parallelism:** use -parallelism=N to throttle Proxmox API calls (or set pm_parallel in the provider).

- **Split clone & provision:** disable define_connection_info in the module to clone VMs fast, then provision via Ansible or null_resource.

- **Module reuse:** parameterize for_each = var.vms to create any number of nodes with one block.

- **State locking:** consider a remote backend (S3, Consul) if multiple engineers will run Terraform concurrently.

- **Secrets:** never commit terraform.tfvars with credentials—gitignore it!

© 2025 terraform-quasarlab