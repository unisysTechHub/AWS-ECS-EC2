output "ecs_cluster" { value = module.cluster.cluster_name }
output "ecr_repositories" { value = module.ecr.repository_urls }
output "service_discovery_domain" { value = module.discovery.domain }
