# see https://github.com/hashicorp/terraform
terraform {
  required_version = "1.6.4"
  required_providers {
    # see https://registry.terraform.io/providers/hashicorp/random
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
    # see https://registry.terraform.io/providers/hashicorp/template
    template = {
      source  = "hashicorp/template"
      version = "2.2.0"
    }
    # see https://registry.terraform.io/providers/bpg/proxmox
    # see https://github.com/bpg/terraform-provider-proxmox
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.38.1"
    }
  }
}

provider "proxmox" {
  ssh {
    node {
      name    = var.proxmox_pve_node_name
      address = var.proxmox_pve_node_address
    }
  }
}

variable "proxmox_pve_node_name" {
  type    = string
  default = "pve"
}

variable "proxmox_pve_node_address" {
  type = string
}

variable "prefix" {
  type    = string
  default = "terraform-windows-example"
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.38.1/docs/data-sources/virtual_environment_vms
data "proxmox_virtual_environment_vms" "windows_templates" {
  tags = ["windows-2022-uefi", "template"]
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.38.1/docs/data-sources/virtual_environment_vm
data "proxmox_virtual_environment_vm" "windows_template" {
  node_name = data.proxmox_virtual_environment_vms.windows_templates.vms[0].node_name
  vm_id     = data.proxmox_virtual_environment_vms.windows_templates.vms[0].vm_id
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.38.1/docs/resources/virtual_environment_vm
resource "proxmox_virtual_environment_vm" "example" {
  name      = var.prefix
  node_name = var.proxmox_pve_node_name
  tags      = ["windows-2022-uefi", "example", "terraform"]
  clone {
    vm_id = data.proxmox_virtual_environment_vm.windows_template.vm_id
    full  = false
  }
  cpu {
    type  = "host"
    cores = 4
  }
  memory {
    dedicated = 4 * 1024
  }
  network_device {
    bridge = "vmbr0"
  }
  disk {
    interface   = "scsi0"
    file_format = "raw"
    iothread    = true
    ssd         = true
    discard     = "on"
    size        = 64
  }
  agent {
    enabled = true
  }
}
