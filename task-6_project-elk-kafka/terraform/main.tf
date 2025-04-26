provider "local" {}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

module "network" {
  source = "./modules/network"
}

module "swarm" {
  source = "./modules/swarm"
}

module "kafka" {
  source = "./modules/kafka"
}

module "elk" {
  source = "./modules/elk"
}

