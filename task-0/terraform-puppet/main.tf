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
      "apt update -y",

      "wget https://apt.puppet.com/puppet7-release-focal.deb",
      "dpkg -i puppet7-release-focal.deb",
      "apt update -y",

      "apt install -y puppetserver",

      "sed -i 's/2g/256m/' /etc/default/puppetserver",

      "systemctl enable puppetserver",
      "systemctl start puppetserver"
    ]
  }
}
