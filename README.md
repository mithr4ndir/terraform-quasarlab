# terraform-quasarlab
Terraform IaC for provisioning VMs, network, and services

# 🛠️ Terraform Proxmox Setup

This repository uses [Terraform](https://www.terraform.io/) to provision virtual machines on a [Proxmox VE](https://www.proxmox.com/en/proxmox-ve) hypervisor. Below are the steps to get your environment ready to run this code securely and efficiently.

---

## 📦 Required Tools

| Tool | Purpose |
|------|---------|
| [Terraform CLI](https://developer.hashicorp.com/terraform/downloads) | Infrastructure as Code engine |
| [Proxmox Terraform Provider (Telmate)](https://github.com/Telmate/terraform-provider-proxmox) | Allows Terraform to control PVE |
---

## 🚀 Installation

### 1. Install Terraform

#### macOS
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

#### Ubuntu / Debian
```bash
sudo apt update && sudo apt install -y gnupg software-properties-common curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

#### Windows (via winget)
```powershell
winget install HashiCorp.Terraform
```
Or download manually from: https://www.terraform.io/downloads

 