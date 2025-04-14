provider "null" {}

resource "null_resource" "install_docker_manager" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = var.swarm_manager_ip
  }

  provisioner "remote-exec" {
    inline = [
      "curl -fsSL https://get.docker.com | sudo sh",
      "sudo usermod -aG docker ${var.ssh_user}"
    ]
  }
}

resource "null_resource" "install_docker_worker1" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = var.swarm_worker1_ip
  }

  provisioner "remote-exec" {
    inline = [
      "curl -fsSL https://get.docker.com | sudo sh",
      "sudo usermod -aG docker ${var.ssh_user}"
    ]
  }
}

resource "null_resource" "install_docker_worker2" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = var.swarm_worker2_ip
  }

  provisioner "remote-exec" {
    inline = [
      "curl -fsSL https://get.docker.com | sudo sh",
      "sudo usermod -aG docker ${var.ssh_user}"
    ]
  }
}

resource "null_resource" "init_swarm" {
  depends_on = [null_resource.install_docker_manager]

  connection {
    type     = "ssh"
    user     = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host     = var.swarm_manager_ip
  }

  provisioner "remote-exec" {
    inline = [
      "docker swarm init --advertise-addr ${var.swarm_manager_ip}"
    ]
  }

  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no -i ${var.ssh_private_key_path} ${var.ssh_user}@${var.swarm_manager_ip} 'docker swarm join-token worker -q' > worker_token.txt"
  }

}

resource "null_resource" "join_worker1" {
  depends_on = [null_resource.install_docker_worker1, null_resource.init_swarm]

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = var.swarm_worker1_ip
  }

  provisioner "file" {
    source      = "worker_token.txt"
    destination = "/var/lib/docker/worker_token.txt"
  }

  provisioner "remote-exec" {
    inline = [
      "SWARM_TOKEN=$(cat /var/lib/docker/worker_token.txt)",
      "docker swarm join --token $SWARM_TOKEN ${var.swarm_manager_ip}:2377"
    ]
  }
}

resource "null_resource" "join_worker2" {
  depends_on = [null_resource.install_docker_worker2, null_resource.init_swarm]

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = var.swarm_worker2_ip
  }

  provisioner "file" {
    source      = "worker_token.txt"
    destination = "/var/lib/docker/worker_token.txt"
  }

  provisioner "remote-exec" {
    inline = [
      "SWARM_TOKEN=$(cat /var/lib/docker/worker_token.txt)",
      "docker swarm join --token $SWARM_TOKEN ${var.swarm_manager_ip}:2377"
    ]
  }
}
