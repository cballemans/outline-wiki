
#!/usr/bin/env bash
set -euo pipefail

# Usage: ./create-remote-backend.sh <resource_group> <location> <storage_account> <container>
RG_NAME=${1:-rg-tf-backend}
LOCATION=${2:-westeurope}
STORAGE=${3:-sttf$(openssl rand -hex 3)}
CONTAINER=${4:-tfstate}

# Requires Azure CLI logged in
az group create --name "$RG_NAME" --location "$LOCATION" >/dev/null
az storage account create   --name "$STORAGE"   --resource-group "$RG_NAME"   --location "$LOCATION"   --sku Standard_LRS   --kind StorageV2   --allow-blob-public-access false >/dev/null

ACCOUNT_KEY=$(az storage account keys list -g "$RG_NAME" -n "$STORAGE" --query "[0].value" -o tsv)
az storage container create   --name "$CONTAINER"   --account-name "$STORAGE"   --account-key "$ACCOUNT_KEY" >/dev/null

echo "Created backend:"
echo "resource_group_name=$RG_NAME"
echo "storage_account_name=$STORAGE"
echo "container_name=$CONTAINER"
echo "key=outline.tfstate"
