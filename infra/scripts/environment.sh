#!/bin/bash
set -euo pipefail

function usage {
  echo "USAGE"
  echo "  $0 OPTIONS COMMAND"
  echo
  echo "OPTIONS"
  echo "  --tenant-id          Azure tenant ID"
  echo "  --subscription-id    Azure subscription ID"
  echo "  --subscription-name  Azure subscription name"
  echo "  --location           Azure location"
  echo "  --organization-url   Azure DevOps organization URL"
  echo "  --project-name       Azure DevOps project name"
  echo "  --prefix             Short prefix for all the resource names"
  echo "  --env                Environment identifier"
  echo "  --help, -h           Display help"
  echo
  echo "COMMANDS"
  echo "  up    Create an environment"
  echo "  down  Remove an environment"
  echo
  echo "EXAMPLE"
  echo "  $ $0 --tenant-id xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx --subscription-id xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx --subscription-name \"Example Sub\" --location westeurope --organization-url https://dev.azure.com/ExampleOrg --project-name ExampleApp --env dev --prefix exampleapp up"
  echo
  echo "PRE-REQUISITES"
  echo "  Azure CLI, Azure CLI devops extension, jq"
  exit 0
}

function up {
  echo "Login to Azure..."
  az login --tenant "$tenant_id"
  echo

  echo "Setting active subscription..."
  az account set --subscription "$subscription_id"
  echo

  echo "Creating a resource group for pipeline resources..."
  pipeline_rg=${prefix}-${env}-pl-rg
  r=$(az group create -n "$pipeline_rg" -l "$location")
  pipeline_rg_id=$(echo $r | jq '.id' | sed 's/"//g')
  echo "Done. ID: $pipeline_rg_id"
  echo

  echo "Creating a key vault for pipeline secrets..."
  pipeline_kv=${prefix}-${env}-pl-kv
  r=$(az keyvault create -n "$pipeline_kv" -g "$pipeline_rg" -l "$location")
  pipeline_kv_id=$(echo $r | jq '.id' | sed 's/"//g')
  echo "Done. ID: $pipeline_kv_id"
  echo

  echo "Creating a resource group for Terraform resources..."
  terraform_rg=${prefix}-${env}-tf-rg
  r=$(az group create -n "$terraform_rg" -l "$location")
  terraform_rg_id=$(echo $r | jq '.id' | sed 's/"//g')
  echo "Done. ID: $terraform_rg_id"
  echo

  echo "Creating a storage account for Terraform files..."
  terraform_sa=${prefix}${env}tfsa
  r=$(az storage account create --resource-group "$terraform_rg" --name "$terraform_sa" --sku "Standard_LRS" --encryption-services "blob")
  terraform_sa_id=$(echo $r | jq '.id' | sed 's/"//g')
  terraform_sa_account_key=$(az storage account keys list --resource-group "$terraform_rg" --account-name "$terraform_sa" --query "[0].value" -o "tsv")
  echo "Done. ID: $terraform_sa_id"
  echo

  echo "Creating a storage container for Terraform files..."
  r=$(az storage container create --name "terraform-state" --account-name "$terraform_sa" --account-key "$terraform_sa_account_key")
  echo "Done."
  echo

  echo "Adding the storage account key to the key vault..."
  r=$(az keyvault secret set --vault-name "$pipeline_kv" --name "SA-ACCOUNT-KEY" --value "$terraform_sa_account_key")
  echo "Done."
  echo

  echo "Creating a resource groups for provisioned resources..."
  main_rg=${prefix}-${env}-main-rg
  r=$(az group create -n "$main_rg" -l "$location")
  main_rg_id=$(echo $r | jq '.id' | sed 's/"//g')
  func_rg=${prefix}-${env}-func-rg
  r=$(az group create -n "$func_rg" -l "$location")
  func_rg_id=$(echo $r | jq '.id' | sed 's/"//g')
  echo "Done. IDs: $main_rg_id $func_rg_id"
  echo

  echo "Creating a service principal for Terraform..."
  terraform_sp=http://${prefix}-${env}-tf-sp
  r=$(az ad sp create-for-rbac -n $terraform_sp --role "contributor" --scopes "$terraform_sa_id" "$main_rg_id" "$func_rg_id")
  terraform_sp_name=$(echo $r | jq '.name' | sed 's/"//g')
  terraform_sp_app_id=$(echo $r | jq '.appId' | sed 's/"//g')
  terraform_sp_password=$(echo $r | jq '.password' | sed 's/"//g')
  terraform_sp_id=$(az ad sp list --spn "$terraform_sp_name" --query "[0].objectId" -o "tsv")
  echo "Done. ID: $terraform_sp_id"
  echo

  echo "Adding the service principal details to the key vault..."
  r=$(az keyvault secret set --vault-name "$pipeline_kv" --name "SP-ID" --value "$terraform_sp_app_id")
  r=$(az keyvault secret set --vault-name "$pipeline_kv" --name "SP-PASSWORD" --value "$terraform_sp_password")
  r=$(az keyvault secret set --vault-name "$pipeline_kv" --name "TENANT-ID" --value "$tenant_id")
  r=$(az keyvault secret set --vault-name "$pipeline_kv" --name "SUBSCRIPTION-ID" --value "$subscription_id")
  echo "Done."
  echo

  echo "Creating a service principal for Azure DevOps..."
  azdo_sp=http://${prefix}-${env}-azdo-sp
  r=$(az ad sp create-for-rbac -n "$azdo_sp" --skip-assignment)
  azdo_sp_name=$(echo $r | jq '.name' | sed 's/"//g')
  azdo_sp_app_id=$(echo $r | jq '.appId' | sed 's/"//g')
  azdo_sp_password=$(echo $r | jq '.password' | sed 's/"//g')
  azdo_sp_id=$(az ad sp list --spn "$azdo_sp_name" --query "[0].objectId" -o "tsv")
  echo "Done. ID: $azdo_sp_id"
  echo

  echo "Wait for a minute..."
  sleep 60
  echo "Done."
  echo

  echo "Creating role assignment for Azure DevOps service principal..."
  r=$(az role assignment create --assignee "$azdo_sp_app_id" --scope "$pipeline_kv_id" --role "reader")
  azdo_ra_id=$(echo $r | jq '.id' | sed 's/"//g')
  azdo_ra_name=$(echo $r | jq '.name' | sed 's/"//g')
  echo "Done. ID: $azdo_ra_id"
  echo

  echo "Setting key vault policy..."
  r=$(az keyvault set-policy --name $pipeline_kv --spn "$azdo_sp_app_id" --subscription "$subscription_id" --secret-permissions "get")
  echo "Done."
  echo

  echo "Creating Azure DevOps service connection..."
  echo "When you are prompted for principal key, use: $azdo_sp_password"
  azdo_sc=${prefix}-${env}-azdo-sc
  r=$(az devops service-endpoint azurerm create --azure-rm-service-principal-id "$azdo_sp_app_id" --azure-rm-tenant-id "$tenant_id" --azure-rm-subscription-id "$subscription_id" --azure-rm-subscription-name "$subscription_name" --name "$azdo_sc" --organization "$organization_url" --project "$project_name")
  azdo_sc_id=$(echo $r | jq '.id' | sed 's/"//g')
  echo "Done. ID: $azdo_sc_id"
  echo

  echo "Created the following resources:"
  echo "  $pipeline_rg ($pipeline_rg_id)"
  echo "  $pipeline_kv ($pipeline_kv_id)"
  echo "  $terraform_rg ($terraform_rg_id)"
  echo "  $terraform_sa ($terraform_sa_id)"
  echo "  $main_rg ($main_rg_id)"
  echo "  $func_rg ($func_rg_id)"
  echo "  $terraform_sp ($terraform_sp_id)"
  echo "  $azdo_sp ($azdo_sp_id)"
  echo "  $azdo_ra_name ($azdo_ra_id)"
  echo "  $azdo_sc ($azdo_sc_id)"

  echo
  echo "All Done."
  echo "Rember to verify the Azure DevOps service connection at $organization_url/$project_name/_settings/adminservices?resourceId=$azdo_sc_id"
  echo

  exit 0
}

function down {
  echo "Login to Azure..."
  az login --tenant "$tenant_id"
  echo

  echo "Setting active subscription..."
  az account set --subscription "$subscription_id"
  echo

  echo "Deleting the resource group for pipeline resources..."
  pipeline_rg=${prefix}-${env}-pl-rg
  az group delete -n "$pipeline_rg" -y
  echo "Done."
  echo

  echo "Deleting the resource group for Terraform resources ..."
  terraform_rg=${prefix}-${env}-tf-rg
  az group delete -n "$terraform_rg" -y
  echo "Done."
  echo

  echo "Deleting the resource group for provisioned resources..."
  main_rg=${prefix}-${env}-main-rg
  az group delete -n "$main_rg" -y
  func_rg=${prefix}-${env}-func-rg
  az group delete -n "$func_rg" -y
  echo "Done."
  echo

  echo "Deleting the service principal for Terraform..."
  terraform_sp=http://${prefix}-${env}-tf-sp
  terraform_sp_id=$(az ad sp list --spn "$terraform_sp" --query "[0].objectId" -o "tsv")
  az ad sp delete --id "$terraform_sp_id"
  echo "Done."
  echo

  echo "Deleting the service principal for Azure DevOps..."
  azdo_sp=http://${prefix}-${env}-azdo-sp
  azdo_sp_id=$(az ad sp list --spn "$azdo_sp" --query "[0].objectId" -o "tsv")
  az ad sp delete --id "$azdo_sp_id"
  echo "Done."
  echo

  echo "Deleting Azure DevOps service connection..."
  azdo_sc=${prefix}-${env}-azdo-sc
  r=$(az devops service-endpoint list --organization "$organization_url" --project "$project_name")
  azdo_sc_id=$(echo $r | jq ".[] | select(.name == \"$azdo_sc\") | .id" | sed 's/"//g')
  az devops service-endpoint delete --organization "$organization_url" --project "$project_name" --id "$azdo_sc_id" -y
  echo "Done."
  echo

  echo "Deleted the following resources:"
  echo "  $pipeline_rg"
  echo "  $terraform_rg"
  echo "  $main_rg"
  echo "  $func_rg"
  echo "  $terraform_sp ($terraform_sp_id)"
  echo "  $azdo_sp ($azdo_sp_id)"
  echo "  $azdo_sc ($azdo_sc_id)"

  echo
  echo "All Done."
  echo

  exit 0
}

# Bound variables
tenant_id=
subscription_id=
subscription_name=
location=
organization_url=
project_name=
prefix=
env=
command=

# Process arguments
while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
    --tenant-id)
    tenant_id="$2"
    shift # past argument
    shift # past value
    ;;
    --subscription-id)
    subscription_id="$2"
    shift # past argument
    shift # past value
    ;;
    --subscription-name)
    subscription_name="$2"
    shift # past argument
    shift # past value
    ;;
    --organization-url)
    organization_url="$2"
    shift # past argument
    shift # past value
    ;;
    --project-name)
    project_name="$2"
    shift # past argument
    shift # past value
    ;;
    --prefix)
    prefix="$2"
    shift # past argument
    shift # past value
    ;;
    --env)
    env="$2"
    shift # past argument
    shift # past value
    ;;
    --location)
    location="$2"
    shift # past argument
    shift # past value
    ;;
    up)
    command="up"
    shift # past argument
    ;;
    down)
    command="down"
    shift # past argument
    ;;
    -h|--help|*)
    command="usage"
    shift # past argument
    ;;
  esac
done

# Validate arguments
if [[ -z $tenant_id || -z $subscription_id || -z $subscription_name || -z $location || -z $organization_url || -z $project_name || -z $prefix || -z $env ]]; then
  echo 'ERROR: One or more required options are missing'
  exit 1
fi

# Execute command
case $command in
  up)
  up
  ;;
  down)
  down
  ;;
  *)
  usage
  ;;
esac
