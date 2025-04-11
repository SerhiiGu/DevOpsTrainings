provider "null" {}

resource "null_resource" "install_docker_manager" {
  connection {
    type     = "ssh"
    user     = var.manager.user
    private_key = file(var.manager.ssh_key)
    host     = var.manager.ip
  }

  provisioner "remote-exec" {
    inline = [
      "curl -fsSL https://get.docker.com | sudo sh",
      "sudo usermod -aG docker ${var.manager.user}"
    ]
  }
}

resource "null_resource" "install_docker_worker" {
  connection {
    type        = "ssh"
    user        = var.worker.user
    private_key = file(var.manager.ssh_key)
    host        = var.worker.ip
  }

  provisioner "remote-exec" {
    inline = [
      "curl -fsSL https://get.docker.com | sudo sh",
      "sudo usermod -aG docker ${var.worker.user}"
    ]
  }
}

resource "null_resource" "init_swarm" {
  depends_on = [null_resource.install_docker_manager]

  connection {
    type        = "ssh"
    user        = var.manager.user
    private_key = file(var.manager.ssh_key)
    host        = var.manager.ip
  }

  provisioner "remote-exec" {
    inline = [
      "docker swarm init --advertise-addr ${var.manager.ip}"
    ]
  }

  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no -i ${var.manager.ssh_key} ${var.manager.user}@${var.manager.ip} 'docker swarm join-token worker -q' > worker_token.txt"
  }

}

resource "null_resource" "join_worker" {
  depends_on = [null_resource.install_docker_worker, null_resource.init_swarm]

  connection {
    type        = "ssh"
    user        = var.worker.user
    private_key = file(var.manager.ssh_key)
    host        = var.worker.ip
  }

  provisioner "file" {
    source      = "worker_token.txt"
    destination = "/tmp/worker_token.txt"
  }

  provisioner "remote-exec" {
    inline = [
      "SWARM_TOKEN=$(cat /tmp/worker_token.txt)",
      "docker swarm join --token $SWARM_TOKEN ${var.manager.ip}:2377"
    ]
  }
}
