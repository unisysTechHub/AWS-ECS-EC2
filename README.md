# FundTransfer development environment on ECS EC2

This Terraform root deploys every runnable `deploy-*` component from the
Kubernetes project into the `dev` AWS environment: MySQL, Redis, Kafka,
registry, and the five FundTransfer services. ECS tasks run on an EC2 Auto
Scaling Group, use private ECR repositories, Cloud Map service names under
`dev.local`, and encrypted EFS storage for stateful containers.

The environment is composed from reusable modules in `modules/`: `network`,
`ecr`, `efs`, `discovery`, `ecs-cluster`, and `ecs-service`.

`deploy-cluster-volume.sh` and `deploy-daemonset.sh` are Kind/Docker-specific
and have no ECS equivalent. EFS replaces the Kind host volumes; ECR image
authentication replaces the insecure-registry DaemonSet.

## Deploy

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply -target=module.ecr
```

Push all private images before creating ECS services. Obtain repository URLs
with `terraform output -json ecr_repositories`, authenticate, tag, and push:

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.us-east-1.amazonaws.com
docker tag unisystechhub/userservice:latest ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/fundtransfer-dev/userservice:v1
docker push ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/fundtransfer-dev/userservice:v1
```

Repeat for `accountservice`, `transactionservice`, `coordinatorservice`,
`authservice`, and `registry` using their ECR repository names.

MySQL, Redis, and Kafka are pulled directly from Docker Hub and are configured
with full image URI variables: `mysql_image`, `redis_image`, and `kafka_image`.
Their defaults are `docker.io/library/mysql:8.0`,
`docker.io/library/redis:6.2`, and `docker.io/bitnami/kafka:3.7`.

After every required image is pushed, deploy the infrastructure and services:

```bash
terraform apply
```
