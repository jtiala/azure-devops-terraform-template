# Azure DevOps Terraform Template

This template is a monorepo containing a starter setup for **Microsoft Azure** infrastructure managed with **Terraform** configuration, **Azure DevOps** pipelines for automation, handy script for managing environments, as well as some example Azure resources to get you started.

The environment script is heavily inspired by [Maninderjit Bindra](https://twitter.com/maniSbindra)'s article on [Medium](https://medium.com/@maninder.bindra/creating-a-single-azure-devops-yaml-pipeline-to-provision-multiple-environments-using-terraform-e6d05343cae2).

## Environments

### Creating an environment

1. Run `infra/scripts/environment.sh up`. For help, run the script with `-h` flag.

   This will create the needed service principals, an Azure DevOps service connection and the following resource groups and resources:

   - **[PREFIX]-[ENV]-pl-rg**
     - _[PREFIX]-[ENV]-pl-kv_: Key vault for pipeline secrets
   - **[PREFIX]-[ENV]-tf-rg**
     - _[PREFIX][env]tfsa_: Storage account for Terraform
       - _terraform-state_: Blob container for Terraform state
   - **[PREFIX]-[ENV]-main-rg**
     - Most of the Terraform provisioned Azure resources
   - **[PREFIX]-[ENV]-func-rg** - Terraform provisioned Azure Functions related resources. This is needed, because based on a [current limitation](https://docs.microsoft.com/en-us/azure/app-service/containers/app-service-linux-intro#limitations) on Azure, both Linux and Functions apps cannot live in the same resource group.

2. In Azure DevOps, go to `Project settings Service connections` (or click the link from the script output), select your new connection, click `Edit` and `Verify connection`. Click OK.

3. Create a `tfvars` file for the new environment at `infra/tf-vars/[ENV].tfvars`. Use the same environment identifier that you used with the script.

### Removing an environment

To remove an environment created, run `infra/scripts/environment.sh down` (use `-h` flag for help). This removes all the resources, service principals and service connections created for the environment as well as all the resources Terraform has provisioned for the environment. You'll have to remove the pipelines manually.

## Pipelines

### Creating a pipeline

1. In Azure DevOps, create a new pipeline using existing YAML file. Available pipeline templates are described below.
2. Add an environment variables `PREFIX` and `ENV` with the same values that you used with the environment script.
3. Run the pipeline.
4. Rename your pipeline with environment specific name so they are easier to recognize.
5. You may want to add a manual approval check before deploying to some environments. Approval checks can be created in Azure DevOps at `Pipelines > Environments > [PREFIX]-[ENV]-infra > Approvals and checks`.

### Infra pipeline templates

#### Continuous Delivery (`pipelines/infra/cd.yml`)

Runs Terraform plan against your environment and after successful plan, the changes will be applied and the updated infrastructure will be deployed. The pipeline will be triggered when new infra-related commits are pushed to the master branch (i.e. after merged pull request).

#### Continuous Integration (`pipelines/infra/ci.yml`)

Runs Terraform plan against your environment, but will not apply the changes. The pipeline will be triggered for infra-related pull requests on GitHub or BitBucket. For Azure DevOps repos, you need to setup a build validation from the repo settings.

### API pipeline templates

#### Continuous Delivery (`pipelines/api/cd.yml`)

Builds a Docker image from the API source code, pushes it to the container registry and triggers deployment for the app using `az webapp create` command. The pipeline will be triggered when new API-related commits are pushed to the master branch (i.e. after merged pull request).

#### Continuous Integration (`pipelines/api/ci.yml`)

Builds a Docker image from the API source code. The pipeline will be triggered for API-related pull requests on GitHub or BitBucket. For Azure DevOps repos, you need to setup a build validation from the repo settings.

### Functions pipeline templates

#### Continuous Delivery (`pipelines/functions/cd.yml`)

Builds a zip archive from the functions source code and deploys a new version of the functions app using `az functionapp deployment` command. The pipeline will be triggered when new functions-related commits are pushed to the master branch (i.e. after merged pull request).

#### Continuous Integration (`pipelines/functions/ci.yml`)

Builds a Docker image from the API source code. The pipeline will be triggered for API-related pull requests on GitHub or BitBucket. For Azure DevOps repos, you need to setup a build validation from the repo settings.

## Example Azure resources

The included Terraform configuration creates the following Azure resources:

- **storage.tf**
  - Storage account
  - Storage container for logs
  - SAS token
- **db.tf**
  - CosmosDB account
  - MongoDB database
- **api.tf**
  - Container registry
  - Linux app service plan
  - Dockerized Node.js app with database connection
- **functions.tf**
  - Linux functions app service plan
  - Application insights
  - Python functions app with database connection
