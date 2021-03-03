#!/bin/bash
set -e

AZ_RESOURCE_GROUP=djangorg
AZ_LOCATION=eastus
AZ_ACR=djangoappacr
ACR_LOGIN_SERVER=ACR_LOGIN_SERVER
AZ_ACR_PASSWORD=password
DOCKER_IMAGE_TAG=django-app
AZ_AKS=djangoakscluster
AZ_DNS_PREFIX=djangokubernetes
AKS_POD=djangopod
AKS_POSTGRES=djangopostgres
AKS_POSTGRES_USERNAME=djangoadmin
AKS_POSTGRES_PASSWORD=djangoadmin

# Create a resource group.
az group create \
    --name $AZ_RESOURCE_GROUP \
    --location $AZ_LOCATION \
    | jq

# Create a registry
az acr create --resource-group $AZ_RESOURCE_GROUP \
  --location $AZ_LOCATION \
  --name $AZ_ACR \
  --sku Basic \
  --admin-enabled true

ACR_LOGIN_SERVER=$(az acr list \
  --resource-group $AZ_RESOURCE_GROUP \
  | jq -r '.[0].loginServer')

# login to registry
AZ_ACR_PASSWORD=$(az acr credential show \
  --resource-group $AZ_RESOURCE_GROUP \
  --name $AZ_ACR | jq -r '.passwords[0].value')

# build docker image
docker build --tag $DOCKER_IMAGE_TAG .
docker tag $DOCKER_IMAGE_TAG $ACR_LOGIN_SERVER/$DOCKER_IMAGE_TAG:latest

# push image to ACR
echo $AZ_ACR_PASSWORD | docker login $ACR_LOGIN_SERVER \
  --username $AZ_ACR \
  --password-stdin

docker push $ACR_LOGIN_SERVER/$DOCKER_IMAGE_TAG:latest


# create AKS cluster
az aks create \
  --resource-group=$AZ_RESOURCE_GROUP \
  --name=$AZ_AKS \
  --vm-set-type VirtualMachineScaleSets \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 5 \
  --dns-name-prefix=$AZ_DNS_PREFIX \
  --generate-ssh-keys \
  --load-balancer-sku standard

# connect to AKS cluster
az aks get-credentials \
  --resource-group=$AZ_RESOURCE_GROUP \
  --name=$AZ_AKS \
  --overwrite-existing

# create Postgres flexible server
# az postgres flexible-server create \
#   --public-access <YOUR-IP-ADDRESS>

az postgres flexible-server create \
  --location $AZ_LOCATION \
  --resource-group=$AZ_RESOURCE_GROUP \
  --name $AKS_POSTGRES \
  --admin-user $AKS_POSTGRES_USERNAME \
  --admin-password $AKS_POSTGRES_PASSWORD

az postgres flexible-server show \
  --resource-group $AZ_RESOURCE_GROUP \
  --name $AKS_POSTGRES

kubectl apply -f deployment.yaml