# Usage (from a Ubuntu 22.04 host)

[![Lint](https://github.com/rgl/terraform-proxmox-windows-example/actions/workflows/lint.yml/badge.svg)](https://github.com/rgl/terraform-proxmox-windows-example/actions/workflows/lint.yml)

Create and install the [base Windows 2022 UEFI template](https://github.com/rgl/windows-vagrant).

Install Terraform:

```bash
# see https://github.com/hashicorp/terraform/releases
# renovate: datasource=github-releases depName=hashicorp/terraform
terraform_version='1.9.2'
wget "https://releases.hashicorp.com/terraform/$terraform_version/terraform_${$terraform_version}_linux_amd64.zip"
unzip "terraform_${$terraform_version}_linux_amd64.zip"
sudo install terraform /usr/local/bin
rm terraform terraform_*_linux_amd64.zip
```

Set your proxmox details:

```bash
# see https://registry.terraform.io/providers/bpg/proxmox/latest/docs#argument-reference
# see https://github.com/bpg/terraform-provider-proxmox/blob/v0.61.1/proxmoxtf/provider/provider.go#L49-L56
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

List this repository dependencies (and which have newer versions):

```bash
export GITHUB_COM_TOKEN='YOUR_GITHUB_PERSONAL_TOKEN'
./renovate.sh
```
