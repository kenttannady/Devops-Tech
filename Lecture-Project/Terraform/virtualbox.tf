# Public VM (NGINX)
resource "virtualbox_vm" "nginx_vm" {
  count      = var.environment == "local" ? 1 : 0
  name       = "${local.app_name}-public-vm"
  url        = "https://app.vagrantup.com/ubuntu/boxes/jammy64/versions/20230302.0.0/providers/virtualbox.box"
  cpus       = 2
  memory     = "2048 mib"
  
  network_adapter {
    type           = "nat"
    host_interface = "vboxnet0"
  }
  
  provisioner "local-exec" {
    command = "sleep 30" # Wait for VM to boot
  }
}

# Private VM (Internal service)
resource "virtualbox_vm" "private_vm" {
  count      = var.environment == "local" ? 1 : 0
  name       = "${local.app_name}-private-vm"
  url        = "https://app.vagrantup.com/ubuntu/boxes/jammy64/versions/20230302.0.0/providers/virtualbox.box"
  cpus       = 1
  memory     = "1024 mib"
  
  network_adapter {
    type           = "hostonly"
    host_interface = "vboxnet1"
    device         = "IntelPro1000MTDesktop"
  }
  
  provisioner "local-exec" {
    command = "sleep 30"
  }
}

# VPN Server VM
resource "virtualbox_vm" "vpn_vm" {
  count      = var.environment == "local" ? 1 : 0
  name       = "${local.app_name}-vpn-vm"
  url        = "https://app.vagrantup.com/ubuntu/boxes/jammy64/versions/20230302.0.0/providers/virtualbox.box"
  cpus       = 1
  memory     = "1024 mib"
  
  network_adapter {
    type           = "nat"
    host_interface = "vboxnet0"
  }
  
  network_adapter {
    type           = "hostonly"
    host_interface = "vboxnet1"
    device         = "IntelPro1000MTDesktop"
  }
  
  provisioner "file" {
    source      = "vpn-setup.sh"
    destination = "/tmp/vpn-setup.sh"
  }
  
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/vpn-setup.sh",
      "/tmp/vpn-setup.sh"
    ]
  }
}

resource "local_file" "ansible_inventory_local" {
  count    = var.environment == "local" ? 1 : 0
  content  = <<-EOT
    [public]
    ${virtualbox_vm.nginx_vm[0].name} ansible_host=127.0.0.1 ansible_port=2222 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
    
    [private]
    ${virtualbox_vm.private_vm[0].name} ansible_host=192.168.56.10 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
    
    [vpn]
    ${virtualbox_vm.vpn_vm[0].name} ansible_host=127.0.0.1 ansible_port=2224 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
    
    [monitoring]
    ${virtualbox_vm.nginx_vm[0].name}
    
    [all:vars]
    private_network_cidr=192.168.56.0/24
  EOT
  filename = "inventory_local.ini"
}