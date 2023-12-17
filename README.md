# Usage (from a Ubuntu 22.04 host)

[![Lint](https://github.com/rgl/terraform-proxmox-windows-example/actions/workflows/lint.yml/badge.svg)](https://github.com/rgl/terraform-proxmox-windows-example/actions/workflows/lint.yml)

Create and install the [base Windows 2022 UEFI template](https://github.com/rgl/windows-vagrant).

Install Terraform:

```bash
wget https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip
unzip terraform_1.6.6_linux_amd64.zip
sudo install terraform /usr/local/bin
rm terraform terraform_*_linux_amd64.zip
```

Set your proxmox details:

```bash
# see https://registry.terraform.io/providers/bpg/proxmox/latest/docs#argument-reference
# see https://github.com/bpg/terraform-provider-proxmox/blob/v0.40.0/proxmoxtf/provider/provider.go#L47-L53
cat >secrets-proxmox.sh <<'EOF'
unset HTTPS_PROXY
#export HTTPS_PROXY='http://localhost:8080'
export TF_VAR_proxmox_pve_node_address='192.168.1.21'
export PROXMOX_VE_INSECURE='1'
export PROXMOX_VE_ENDPOINT="https://$TF_VAR_proxmox_pve_node_address:8006"
export PROXMOX_VE_USERNAME='root@pam'
export PROXMOX_VE_PASSWORD='vagrant'
EOF
source secrets-proxmox.sh
```

Create the infrastructure:

```bash
export CHECKPOINT_DISABLE='1'
export TF_LOG='DEBUG' # TRACE, DEBUG, INFO, WARN or ERROR.
export TF_LOG_PATH='terraform.log'
terraform init
terraform plan -out=tfplan
time terraform apply tfplan
```

Login into the machine:

```bash
ssh-keygen -f ~/.ssh/known_hosts -R "$(terraform output --raw ip)"
ssh "vagrant@$(terraform output --raw ip)"
```

Destroy the infrastructure:

```bash
time terraform destroy -auto-approve
```
