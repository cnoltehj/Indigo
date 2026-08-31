# Indigo Claims Intake - Technical Governance Vetting

This repository demonstrates the three capabilities requested in the brief:

1. a secure, maintainable Azure target shape for Claims Intake;
2. a minimal Azure cloud baseline codified in Bicep; and
3. an Azure DevOps YAML release flow with controlled promotion from non-production to production.

The implementation is intentionally small. The .NET API is an **in-memory demonstration stub** only; the focus is architecture, infrastructure-as-code and release governance.

## Target architecture

```text
Customer / Agent
      |
      | HTTPS + OAuth2/OIDC
      v
Microsoft Entra ID
      |
      v
Azure App Service - .NET Claims Intake API
      |
      +--> Azure SQL Database
      |      relational production store
      |
      +--> Azure Key Vault
      |      runtime secrets/configuration
      |
      +--> Application Insights + Log Analytics
             logs, metrics, traces, diagnostics
```

**Load balancing:** no separate Azure Load Balancer is required for this baseline. Azure App Service provides platform-managed traffic distribution when the App Service Plan is scaled to multiple instances. A global routing layer such as Azure Front Door or Traffic Manager would be considered only if future multi-region, WAF, edge-routing or global failover requirements justify it.

## Repository layout

```text
.
|-- README.md
|-- SOLUTION.md
|-- IMPLEMENTATION-GUIDE.md
|-- docker-compose.yml
|-- src/
|   `-- Indigo.Claims.Api/
|       |-- Indigo.Claims.Api.csproj
|       |-- Program.cs
|       |-- appsettings.json
|       `-- Dockerfile
|-- infra/
|   |-- main.bicep
|   |-- modules/
|   |   |-- appservice.bicep
|   |   |-- database.bicep
|   |   |-- keyvault.bicep
|   |   |-- monitoring.bicep
|   |   `-- secrets.bicep
|   `-- parameters/
|       |-- dev.bicepparam
|       `-- prod.bicepparam.example
`-- pipelines/
    `-- azure-pipelines.yml
```

## Local prerequisites

Recommended environment: **VS Code/ Visual Studio on Windows**, PowerShell terminal, .NET 10 SDK and optionally Docker Desktop using Linux containers.

Check the tools:

```powershell
dotnet --latest version
git -- latest version
docker -- latest version
az --latest version
az bicep latest version
```

## Run the API directly in VS Code

From the repository root:

```powershell
dotnet restore .\src\Indigo.Claims.Api\Indigo.Claims.Api.csproj
dotnet build .\src\Indigo.Claims.Api\Indigo.Claims.Api.csproj -c Release
dotnet run --project .\src\Indigo.Claims.Api\Indigo.Claims.Api.csproj
```

Use the URL printed by .NET and open `/openapi/v1.json` if you want to inspect the OpenAPI document.

Health check:

```powershell
Invoke-RestMethod -Uri "http://localhost:<PORT>/health"
```

## Run as a Linux container

```powershell
docker compose up --build
```

The container listens on:

```text
http://localhost:8080
```

Health check:

```powershell
Invoke-RestMethod -Uri "http://localhost:8080/health"
```

## Demonstrate the business requirements

Claim operations use a local demonstration API key. Production authentication is expected to use Microsoft Entra ID/OAuth2.

```powershell
$headers = @{ "X-API-Key" = "local-dev-key" }
$body = @{
  externalReference = "clm-00231"
  policyNumber = "P-12345"
  type = "Auto"
  incidentDate = "2026-05-01T10:30:00Z"
  description = "Rear-end collision"
} | ConvertTo-Json

Invoke-RestMethod `
  -Uri "http://localhost:8080/claims" `
  -Method Post `
  -Headers $headers `
  -ContentType "application/json" `
  -Body $body
```

Send the same request again. The same `externalReference` returns the existing claim instead of creating a duplicate.

A status lookup can use the external reference:

```powershell
Invoke-RestMethod `
  -Uri "http://localhost:8080/claims/status?externalReference=clm-00231" `
  -Headers $headers
```

The stub masks the policy number in its response and deliberately does not return the description. This demonstrates the principle of limiting exposure of sensitive claims data without turning the assignment into a full application implementation.

## Validate the Bicep baseline

```powershell
az bicep lint --file .\infra\main.bicep
az bicep build --file .\infra\main.bicep
```

Before deployment, use Azure validation and What-If:

```powershell
az deployment group validate `
  --resource-group indigo-claims-rg-dev-uks `
  --template-file .\infra\main.bicep `
  --parameters .\infra\parameters\dev.bicepparam `
  --parameters sqlAdminPassword="$env:SQL_ADMIN_PASSWORD"

az deployment group what-if `
  --resource-group indigo-claims-rg-dev-uks `
  --template-file .\infra\main.bicep `
  --parameters .\infra\parameters\dev.bicepparam `
  --parameters sqlAdminPassword="$env:SQL_ADMIN_PASSWORD"
```

The DEV environment is the single deployable non-production baseline required by the assignment. `prod.bicepparam.example` illustrates how the same template is promoted with production values.

## Azure DevOps governance

The pipeline is in `pipelines/azure-pipelines.yml`:

```text
Pull Request
    |
    v
Build / validation / quality gates
    |
    v
DEV deployment
    |
    v
DEV verification
    |
    v
claims-prod Environment approval/checks
    |
    v
PRODUCTION promotion
```

Configure production approvals in **Azure DevOps > Pipelines > Environments > claims-prod > Approvals and checks**. The approval is intentionally owned outside vendor-editable YAML.

## Security baseline

- Microsoft Entra ID/OAuth2 is the production authentication expectation.
- No anonymous modification of claims is permitted.
- Secrets are not committed to Git or embedded in application code.
- App Service uses Managed Identity and Key Vault references for runtime secret retrieval.
- TLS 1.2+ is enforced at the hosting/database baseline.
- Logs should use claim/correlation identifiers and must not contain claim descriptions, policy details or personal data.
- The SQL administrator secret is passed as a secure deployment variable for the assessment; a mature production implementation should prefer Entra-based database authentication.

## Required deliverables

- `README.md` - local execution and repository instructions.
- `SOLUTION.md` - concise architecture/governance blueprint and trade-offs.
- `IMPLEMENTATION-GUIDE.md` - practical implementation/deployment guide.
- `src/`, `infra/`, `pipelines/` - assignment source code.

See `SOLUTION.md` for the rationale and governance model.
