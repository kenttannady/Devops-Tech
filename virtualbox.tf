terraform {
  required_providers {
    virtualbox = {
      source = "terra-farm/virtualbox"
      version = "0.2.2-alpha.1"
    }
  }
}

provider "virtualbox" {
  delay      = 60
  mintimeout = 5
}

resource "virtualbox_vm" "centos_web" {
  name   = "centos-web-server"
  image  = "https://cloud.centos.org/centos/7/vagrant/x86_64/images/CentOS-7-x86_64-Vagrant-2004_01.VirtualBox.box"
  cpus   = 1
  memory = "1024"

  network_adapter {
    type           = "nat"
    host_interface = "vboxnet0"
  }
}

output "ip_address" {
  value = virtualbox_vm.centos_web.network_adapter.0.ipv4_address
}
