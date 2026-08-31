# Implementation Guide - Indigo Claims Intake Baseline

This guide describes the shortest path to run, validate and deploying using VS Code.

## 1. Recommended workstation

Use:

- Windows 11
- VS Code
- PowerShell terminal
- .NET 10 SDK
- Git
- Azure CLI + Bicep
- Docker Desktop in Linux-container mode (optional for local container test)

Recommended VS Code extensions: C# Dev Kit, Bicep, Azure Resources and YAML.

## 2. Open the repository

```powershell
cd C:\path\to\indigo-final-brief
code .
```

Validate tools:

```powershell
dotnet --version
git --version
az --version
az bicep version
docker --version
```

## 3. Run the minimal API locally

```powershell
dotnet restore .\src\Indigo.Claims.Api\Indigo.Claims.Api.csproj
dotnet build .\src\Indigo.Claims.Api\Indigo.Claims.Api.csproj -c Release
dotnet run --project .\src\Indigo.Claims.Api\Indigo.Claims.Api.csproj
```

Note the HTTP URL displayed in the terminal.

Test health:

```powershell
Invoke-RestMethod -Uri "http://localhost:<PORT>/health"
```

## 4. Test authorisation and idempotency

Claim routes require the local demonstration header:

```powershell
$headers = @{ "X-API-Key" = "local-dev-key" }
```

First confirm that a call without the header returns `401 Unauthorized`.

Create a claim:

```powershell
$body = @{
  externalReference = "clm-00231"
  policyNumber = "P-12345"
  type = "Auto"
  incidentDate = "2026-05-01T10:30:00Z"
  description = "Rear-end collision"
} | ConvertTo-Json

Invoke-RestMethod `
  -Uri "http://localhost:<PORT>/claims" `
  -Method Post `
  -Headers $headers `
  -ContentType "application/json" `
  -Body $body
```

Run the same command again. The returned `claimId` should be the same. This proves the in-memory idempotency behaviour around `externalReference`.

Status lookup:

```powershell
Invoke-RestMethod `
  -Uri "http://localhost:<PORT>/claims/status?externalReference=clm-00231" `
  -Headers $headers
```

The policy number is masked in the response.

## 5. Optional Linux-container test

Start Docker Desktop and confirm Linux containers are enabled:

```powershell
docker compose up --build
```

Then use:

```text
http://localhost:8080/health
```

This containerisation is only for portable local/runtime packaging; it does not change the target hosting decision, which remains Azure App Service.

## 6. Validate Bicep locally

```powershell
az bicep lint --file .\infra\main.bicep
az bicep build --file .\infra\main.bicep
```

Review `infra/main.bicep` and the modules:

- `appservice.bicep` - Linux App Service, Managed Identity, TLS and runtime settings.
- `database.bicep` - minimal Azure SQL server/database resource.
- `keyvault.bicep` - RBAC-enabled Key Vault.
- `secrets.bicep` - secure SQL connection secret.
- `monitoring.bicep` - Log Analytics and Application Insights.

## 7. Prepare Azure DEV

Login and select the subscription:

```powershell
az login
az account show --output table
az account set --subscription "<subscription-id-or-name>"
```

Create the DEV resource group if Indigo has not pre-provisioned it:

```powershell
az group create --name indigo-claims-rg-dev-uks --location uksouth
```

Set a temporary deployment secret in the current PowerShell session:

```powershell
$env:SQL_ADMIN_PASSWORD = "<strong-dev-password>"
```

Do not store this value in Git.

## 8. Validate and preview the DEV deployment

```powershell
az deployment group validate `
  --resource-group indigo-claims-rg-dev-uks `
  --template-file .\infra\main.bicep `
  --parameters .\infra\parameters\dev.bicepparam `
  --parameters sqlAdminPassword="$env:SQL_ADMIN_PASSWORD"
```

Then run What-If:

```powershell
az deployment group what-if `
  --resource-group indigo-claims-rg-dev-uks `
  --template-file .\infra\main.bicep `
  --parameters .\infra\parameters\dev.bicepparam `
  --parameters sqlAdminPassword="$env:SQL_ADMIN_PASSWORD"
```

Only deploy after reviewing the intended changes.

## 9. Deploy DEV

```powershell
az deployment group create `
  --name claims-dev-baseline `
  --resource-group indigo-claims-rg-dev-uks `
  --template-file .\infra\main.bicep `
  --parameters .\infra\parameters\dev.bicepparam `
  --parameters sqlAdminPassword="$env:SQL_ADMIN_PASSWORD"
```

Confirm the resources in Azure Portal or:

```powershell
az resource list --resource-group indigo-claims-rg-dev-uks --output table
```

Expected baseline resources are App Service/plan, Azure SQL/database, Key Vault, Application Insights and Log Analytics.

## 10. Configure Azure DevOps

Create two Azure DevOps Environments:

```text
claims-dev
claims-prod
```

Create service connections with least privilege:

```text
indigo-claims-dev-sc
indigo-claims-prod-sc
```

Add the secret pipeline variable `sqlAdminPassword` through a secured variable group/secret store; never commit it.

For `claims-prod`, configure **Approvals and checks** in the Azure DevOps UI and assign the Indigo approver. This approval must remain outside YAML.

## 11. Run the pipeline

The pipeline performs:

```text
Build + quality placeholders + Bicep validation
                 |
                 v
             Deploy DEV
                 |
                 v
      claims-prod approval/checks
                 |
                 v
          Promote Production
```

A failed mandatory build/security/IaC check must stop promotion.

## 12. Production notes

The production parameter example demonstrates the same template with stronger capacity and Key Vault purge protection. Before a real production release, complete the organisation-specific controls that are intentionally outside this four-hour baseline, such as Entra application registration, private connectivity if mandated, alert thresholds, final RBAC, database identity configuration and change-management checks.


