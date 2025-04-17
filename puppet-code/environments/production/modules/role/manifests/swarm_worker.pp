class role::swarm_worker {
  include base_server
  include puppet_related
  include profile::swarm_worker
}
