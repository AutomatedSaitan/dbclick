# DBClick app

DBClick is a web application that provides a simple API interface to interact with a MySQL database. It allows storing and retrieving timestamped entries with random strings.

## Features
- RESTful API endpoints for data interaction
- Database connection test with retry mechanism

## Technical Stack
- Node.js with Express.js backend
- MySQL database (Azure MySQL Flexible Server)
- Docker containerization
- Azure Web App hosting

## Infrastructure
- Deployed on Azure using Infrastructure as Code (Terraform) with state and plan stored in a storage account blob
- CI/CD with GitHub Actions
- Private networking with VNet integration
- Connectivity achieved via private link (Azure Private DNS Zone)
- Azure Container Registry for image storage
- Container hosted on Azure App Service with CI integration on ACR push event via webhook

## Deployment
The application is automatically deployed to Azure Web Apps through GitHub Actions workflows. The infrastructure is managed through Terraform, with state stored in Azure Storage.

## API Endpoints
- GET / - API documentation
- GET /last-entry - Retrieve most recent database entry
- GET /add-entry - triggers a creation of a new timestamped entry

## Local deployment
Provided Dockerfile allows for building a container with this app. MySQL database has to be provided separately.

## Environmental Variables

Through the use of environmental variables in CI/CD, this application can be redeployed to any subscription with minimal effort. Some further hard-coded variables can be substituted, if more configuration flexibility is required (mainly region to be deployed to, resources' SKUs, database parameters, etc.)

## Azure deployment requirements

Infrastructure and container deployment process assumes that federated credentials with GitHub Actions have been established in the Azure Tenant with high permission level (resource deployment adds roles to multiple resources during run) and a storage account has been already provisioned in order to store Terraform plan and state files. One-shot resource deployment strategy has proven inadequate for infrastructure this complex with frequent changes occuring during development.

## Known issues

During Terraform deployment multiple inconsistent behaviours of Azure Resource Manager have been observed, causing the necessity to retry multiple times with a large loss of time. This has been mitigated by using low value for deployment parallelism.

Multiple App Service Plans' deployment cause Azure to automatically throttle creation of a new plan for the next 48h- move to another region or contact with support is required in such case.

Web App sometimes ignored webhook trigger to redeploy new container version- manual restart of the application helps in such cases.

Some resources support availability zones (MySQL instance), which differ between region and this setting has to be manually adjusted before deployment to fit target region.