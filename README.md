# Three-environment AWS service stack

This Terraform root creates exactly three EC2 instances named `dev`, `test`,
and `production`. Each instance runs the same complete application catalog so
the environments remain comparable.

## Service inventory

Each EC2 instance runs:

- The original 30 Docker services: language runtimes, frameworks, databases,
  web servers, Open WebUI, Jupyter, Ganache/Remix, EMQX, WebXR, PocketBase,
  Portainer, and n8n.
- Six added Docker services: AR, VR, TensorFlow Serving, Kong Gateway, Apache
  NiFi, and MediaMTX.

AWS Lambda supplies the shared Function-as-a-Service endpoint. Therefore the
project contains 37 logical service types. Across all three environments it
starts 108 Docker containers (36 per EC2 instance) plus one shared Lambda
function.

Existing functional equivalents were retained instead of duplicated:
Ganache/Remix for blockchain, EMQX for IoT, Open WebUI for chatbot, WebXR for
metaverse, n8n for RPA, and PocketBase for BaaS.

## AWS layout

```text
dev EC2 (m7i.2xlarge, encrypted 150-GB gp3)
  +-- 30 original services + 6 added services

test EC2 (m7i.2xlarge, encrypted 150-GB gp3)
  +-- 30 original services + 6 added services

production EC2 (m7i.4xlarge, encrypted 300-GB gp3)
  +-- 30 original services + 6 added services

Shared AWS Lambda
  +-- FaaS HTTP endpoint used by Kong in every environment
```

Terraform also creates one explicit VPC, an internet gateway, and separate
public subnets for `dev`, `test`, and `production`; deployment therefore does
not depend on an AWS account still having its default VPC.

The instance types are deliberately larger than the earlier `t3.medium`
because every host now runs databases, JVM services, NiFi, TensorFlow, Spark,
and the other containers together. Override `environment_instances` only after
measuring actual CPU, memory, and disk usage.

The combined cloud-init payload is gzip-compressed before being submitted to
EC2. This keeps the full bootstrap within the EC2 user-data API limit. Host-port
collisions are resolved as follows:

| Service | Host port |
|---|---:|
| PocketBase | 8091 |
| AR | 8092 |
| VR | 8093 |
| Jupyter | 8888 |
| MediaMTX WebRTC | 8889 |
| MediaMTX SRT/UDP | 8890 |
| MediaMTX HLS | 8891 |

All instances require IMDSv2, use encrypted root volumes, and receive the SSM
Session Manager instance profile. NiFi and Kong administration are not exposed
by the platform security group.

## Validate without AWS charges

These commands format, validate, and run the repository's mocked plan test.
They do not deploy AWS infrastructure:

```powershell
terraform init
terraform fmt -check
terraform validate
terraform test
```

With valid AWS credentials, `terraform plan` previews the real account changes
without applying them:

```powershell
terraform plan
```

Stop after the plan if zero AWS charges are required. Do not run
`terraform apply` or `terraform apply -auto-approve` because three large EC2
instances, their EBS volumes, public IPv4 addresses, Lambda, and related AWS
resources can be billable.

## Deploy only after approval

Review `platform_allowed_cidrs` and every security-group rule before a real
deployment. The demonstration default for platform service endpoints is
`["0.0.0.0/0"]`; production access should be narrowed to trusted networks.

An existing singleton `aws_instance.runtime` state address is migrated to the
new `production` address. Nevertheless, the new compressed user data, disk
encryption, sizing, and replacement policy can still replace that EC2 instance.
Back up all Docker volumes and databases before any apply.

After an explicitly approved deployment:

```powershell
terraform output environment_instance_ids
terraform output environment_public_ips
terraform output environment_service_urls
terraform output environment_ssm_commands
terraform output -json environment_nifi_ssm_tunnels
```

Run the appropriate NiFi SSM tunnel and browse to
`https://localhost:8443/nifi`. NiFi uses a generated self-signed certificate,
so a browser warning is expected for this demonstration.

## Smoke tests

Replace `ENVIRONMENT_IP` with the relevant value from
`environment_public_ips`:

```powershell
curl.exe http://ENVIRONMENT_IP:8092/healthz
curl.exe http://ENVIRONMENT_IP:8093/healthz
curl.exe http://ENVIRONMENT_IP:8000/ar/healthz
curl.exe -H "Content-Type: application/json" -d '{"instances":[1.0,2.0,5.0]}' http://ENVIRONMENT_IP:8501/v1/models/half_plus_two:predict
```

Through SSM, inspect `/var/log/devcloud-userdata.log`,
`/var/log/platform-userdata.log`, `/opt/platform/bootstrap-success`, and both
Docker Compose projects.

## Sensitive local files

Terraform state, variable files, generated PEM keys, and generated Lambda ZIPs
are ignored by `.gitignore`. Existing copies are not deleted automatically.
Both uploaded projects contained credential-bearing state or variable
artifacts; rotate any credentials shared outside the trusted environment.
