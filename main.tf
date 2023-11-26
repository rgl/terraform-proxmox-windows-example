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

variable "username" {
  default = "vagrant"
}

variable "password" {
  sensitive = true
  # NB the password will be reset by the cloudbase-init SetUserPasswordPlugin plugin.
  # NB this value must meet the Windows password policy requirements.
  #    see https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/password-must-meet-complexity-requirements
  default = "HeyH0Password"
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

# the virtual machine cloudbase-init cloud-config.
# NB the parts are executed by their declared order.
# see https://github.com/cloudbase/cloudbase-init
# see https://cloudbase-init.readthedocs.io/en/1.1.2/userdata.html#cloud-config
# see https://cloudbase-init.readthedocs.io/en/1.1.2/userdata.html#userdata
# see https://www.terraform.io/docs/providers/template/d/cloudinit_config.html
# see https://www.terraform.io/docs/configuration/expressions.html#string-literals
data "template_cloudinit_config" "example" {
  gzip          = false
  base64_encode = false
  part {
    content_type = "text/cloud-config"
    content      = <<-EOF
      #cloud-config
      hostname: example
      timezone: Europe/Lisbon
      users:
        - name: ${jsonencode(var.username)}
          passwd: ${jsonencode(var.password)}
          primary_group: Administrators
          ssh_authorized_keys:
            - ${jsonencode(trimspace(file("~/.ssh/id_rsa.pub")))}
      # these runcmd commands are concatenated together in a single batch script and then executed by cmd.exe.
      # NB this script will be executed as the cloudbase-init user (which is in the Administrators group).
      # NB this script will be executed by the cloudbase-init service once, but to be safe, make sure its idempotent.
      # NB the output of this script appears on the cloudbase-init.log file when the
      #    debug mode is enabled, otherwise, you will only have the exit code.
      runcmd:
        - "echo # Script path"
        - "echo %~f0"
        - "echo # Sessions"
        - "query session"
        - "echo # whoami"
        - "whoami /all"
        - "echo # Windows version"
        - "ver"
        - "echo # Environment variables"
        - "set"
      EOF
  }
  part {
    filename     = "example.ps1"
    content_type = "text/x-shellscript"
    content      = <<-EOF
      #ps1_sysnative
      # this is a PowerShell script.
      # NB this script will be executed as the cloudbase-init user (which is in the Administrators group).
      # NB this script will be executed by the cloudbase-init service once, but to be safe, make sure its idempotent.
      # NB the output of this script appears on the cloudbase-init.log file when the
      #    debug mode is enabled, otherwise, you will only have the exit code.
      Start-Transcript -Append "C:\cloudinit-config-example.ps1.log"
      function Write-Title($title) {
        Write-Output "`n#`n# $title`n#"
      }
      Write-Title "Script path"
      Write-Output $PSCommandPath
      Write-Title "Sessions"
      query session | Out-String
      Write-Title "whoami"
      whoami /all | Out-String
      Write-Title "Windows version"
      cmd /c ver | Out-String
      Write-Title "Environment Variables"
      dir env:
      Write-Title "TimeZone"
      Get-TimeZone
      EOF
  }
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.38.1/docs/resources/virtual_environment_file
resource "proxmox_virtual_environment_file" "example_ci_user_data" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_pve_node_name
  source_raw {
    file_name = "${var.prefix}-ci-user-data.txt"
    data      = data.template_cloudinit_config.example.rendered
  }
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
  # NB we use a custom user data because this terraform provider initialization
  #    block is not entirely compatible with cloudbase-init (the cloud-init
  #    implementation that is used in the windows base image).
  # see https://pve.proxmox.com/wiki/Cloud-Init_Support
  # see https://cloudbase-init.readthedocs.io/en/latest/services.html#openstack-configuration-drive
  # see https://registry.terraform.io/providers/bpg/proxmox/0.38.1/docs/resources/virtual_environment_vm#initialization
  initialization {
    user_data_file_id = proxmox_virtual_environment_file.example_ci_user_data.id
  }
  # NB this can only connect after about 3m15s (because the ssh service in the
  #    windows base image is configured as "delayed start").
  provisioner "remote-exec" {
    connection {
      target_platform = "windows"
      type            = "ssh"
      host            = self.ipv4_addresses[index(self.network_interface_names, "Ethernet")][0]
      user            = var.username
      password        = var.password
    }
    # NB this is executed as a batch script by cmd.exe.
    inline = [
      <<-EOF
      whoami.exe /all
      EOF
    ]
  }
}

output "ip" {
  value = proxmox_virtual_environment_vm.example.ipv4_addresses[index(proxmox_virtual_environment_vm.example.network_interface_names, "Ethernet")][0]
}
