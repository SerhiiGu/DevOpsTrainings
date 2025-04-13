provider "null" {}

resource "null_resource" "install_puppet_server" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = var.puppet_server_ip
  }

  provisioner "remote-exec" {
    inline = [
      "hostnamectl set-hostname puppet-master"
      "echo ${var.puppet_server_ip} puppet-master >> /etc/hosts",
      "apt update -y",

      # Puppet 7 для Debian 12 (bookworm)
      "wget https://apt.puppet.com/puppet7-release-bookworm.deb",
      "dpkg -i puppet7-release-bookworm.deb",
      "apt update -y",

      "apt install -y puppetserver",

      "sed -i 's/2g/1g/' /etc/default/puppetserver",

      "systemctl enable puppetserver",
      "systemctl start puppetserver"
    ]
  }
}
