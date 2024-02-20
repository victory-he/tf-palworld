## Getting started

## Prerequisites
Terraform

### Set required variables in tfvars
- If you are bringing an existing save to the server, you have to set the variable `DEDICATED_SERVER_NAME`.
- This can be found as the variable `DedicatedServerName` in `Pal/Saved/Config/LinuxServer/GameUserSettings.ini`.


```
# Docker envs
MAX_PLAYERS           = "16"
SERVER_NAME           = ""
SERVER_DESCRIPTION    = ""
SERVER_PASSWORD       = ""
ADMIN_PASSWORD        = ""

# Palworld server name
DEDICATED_SERVER_NAME = ""

# AWS envs
S3_URI                = ""
S3_REGION             = ""
key_name              = ""
instance_profile_arn  = ""
```

## Usage

1. Configure S3 backend by setting the following environment variables in your bash session
```
TFSTATE_BUCKET=
TFSTATE_KEY=
TFSTATE_REGION=
```

2. Initialize Terraform
```
terraform init \
-backend-config="bucket=${TFSTATE_BUCKET}" \
-backend-config="key=${TFSTATE_KEY}" \
-backend-config="region=${TFSTATE_REGION}" 
```

3. Terraform plan
```
terraform plan
```

4. Terraform apply
```
terraform apply
```

## Using RCON
```
docker-compose run --rm rcon ShowPlayers
docker-compose run --rm rcon save
```
