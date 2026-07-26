provider "aws" { region = var.aws_region }

locals {
  name = "${var.project_name}-${var.environment}"
  tags = { Project = var.project_name, Environment = var.environment, ManagedBy = "Terraform" }
  stateful = toset(["mysql", "redis", "kafka", "registry"])
  services = {
    mysql = { port = 3306, cpu = 512, memory = 1024, environment = { MYSQL_DATABASE = "db_example", MYSQL_USER = "springuser" } }
    redis = { port = 6379, cpu = 256, memory = 512, command = ["redis-server", "--appendonly", "yes", "--bind", "0.0.0.0", "--protected-mode", "no"], environment = {} }
    kafka = { port = 9092, cpu = 512, memory = 1024, environment = { KAFKA_CFG_NODE_ID = "0", KAFKA_CFG_PROCESS_ROLES = "broker,controller", KAFKA_CFG_CONTROLLER_QUORUM_VOTERS = "0@kafka.dev.local:9093", KAFKA_CFG_LISTENERS = "PLAINTEXT://:9092,CONTROLLER://:9093", KAFKA_CFG_ADVERTISED_LISTENERS = "PLAINTEXT://kafka.dev.local:9092", KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP = "PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT", KAFKA_CFG_CONTROLLER_LISTENER_NAMES = "CONTROLLER", KAFKA_CFG_INTER_BROKER_LISTENER_NAME = "PLAINTEXT", ALLOW_PLAINTEXT_LISTENER = "yes" } }
    registry = { port = 5000, cpu = 256, memory = 512, environment = { REGISTRY_STORAGE_DELETE_ENABLED = "true" } }
    userservice = { port = 8082, cpu = 256, memory = 512, environment = { SERVER_PORT = "8082", SPRING_APPLICATION_NAME = "userservice", SPRING_DATASOURCE_URL = "jdbc:mysql://mysql.dev.local:3306/db_example", SPRING_DATA_REDIS_HOST = "redis.dev.local", SPRING_KAFKA_BOOTSTRAP_SERVERS = "kafka.dev.local:9092", COORDINATOR_SERVICE = "http://coordinatorservice.dev.local:8089", JWT_TOKEN_EXPIRATION_IN_SECONDS = "500000", JWT_HTTP_REQUEST_HEADER = "Authorization", JWT_ALGORITHM = "HS512" } }
    accountservice = { port = 8083, cpu = 256, memory = 512, environment = { SERVER_PORT = "8083", SPRING_APPLICATION_NAME = "accountservice", SPRING_DATASOURCE_URL = "jdbc:mysql://mysql.dev.local:3306/db_example", SPRING_JPA_HIBERNATE_DDL_AUTO = "update" } }
    transactionservice = { port = 8086, cpu = 256, memory = 512, environment = { SERVER_PORT = "8086", SPRING_APPLICATION_NAME = "transactionservice", SPRING_DATASOURCE_URL = "jdbc:mysql://mysql.dev.local:3306/db_example", SPRING_DATA_REDIS_HOST = "redis.dev.local", SPRING_KAFKA_BOOTSTRAP_SERVERS = "kafka.dev.local:9092" } }
    coordinatorservice = { port = 8089, cpu = 256, memory = 512, environment = { SERVER_PORT = "8089", SPRING_APPLICATION_NAME = "CoordinatorService", TRANSACTION_SERVICE = "http://transactionservice.dev.local:8086", ACCOUNT_SERVICE = "http://accountservice.dev.local:8083" } }
    authservice = { port = 8090, cpu = 256, memory = 512, environment = { SERVER_PORT = "8090", SPRING_APPLICATION_NAME = "AuthorizationService", SPRING_DATASOURCE_URL = "jdbc:mysql://mysql.dev.local:3306/db_example" } }
  }
}

module "network" { source = "./modules/network" name = local.name ssh_allowed_cidr = "49.207.6.33/32" tags = local.tags }
module "ecr" { source = "./modules/ecr" name = local.name repositories = ["registry", "userservice", "accountservice", "transactionservice", "coordinatorservice", "authservice"] tags = local.tags }
module "storage" { source = "./modules/efs" name = local.name stateful_services = local.stateful subnet_ids = module.network.private_subnet_ids efs_security_group_id = module.network.efs_security_group_id tags = local.tags }
module "discovery" { source = "./modules/discovery" domain = "${var.environment}.local" vpc_id = module.network.vpc_id services = keys(local.services) tags = local.tags }
module "cluster" { source = "./modules/ecs-cluster" name = local.name instance_type = var.ecs_instance_type private_subnet_ids = module.network.private_subnet_ids security_group_id = module.network.ecs_security_group_id tags = local.tags }

module "services" {
  source = "./modules/ecs-service"
  for_each = local.services
  name = each.key cluster_id = module.cluster.cluster_id image = each.key == "mysql" ? var.mysql_image : each.key == "redis" ? var.redis_image : each.key == "kafka" ? var.kafka_image : "${module.ecr.repository_urls[each.key]}:${var.image_tag}"
  cpu = each.value.cpu memory = each.value.memory container_port = each.value.port command = try(each.value.command, null)
  environment = merge(each.value.environment, each.key == "mysql" ? { MYSQL_ROOT_PASSWORD = var.mysql_root_password, MYSQL_PASSWORD = var.mysql_password } : contains(["accountservice", "authservice", "transactionservice", "userservice"], each.key) ? { SPRING_DATASOURCE_USERNAME = "springuser", SPRING_DATASOURCE_PASSWORD = var.mysql_password, JWT_SIGNING_KEY_SECRET = var.jwt_signing_key } : {})
  private_subnet_ids = module.network.private_subnet_ids security_group_id = module.network.ecs_security_group_id execution_role_arn = module.cluster.execution_role_arn service_registry_arn = module.discovery.service_arns[each.key]
  efs_file_system_id = contains(local.stateful, each.key) ? module.storage.file_system_id : null
  efs_access_point_id = contains(local.stateful, each.key) ? module.storage.access_point_ids[each.key] : null
  mount_path = each.key == "mysql" ? "/var/lib/mysql" : each.key == "redis" ? "/data" : each.key == "kafka" ? "/bitnami/kafka" : each.key == "registry" ? "/var/lib/registry" : null
  additional_ports = each.key == "kafka" ? [9093] : []
  aws_region = var.aws_region tags = local.tags
  depends_on = [module.cluster, module.storage]
}
