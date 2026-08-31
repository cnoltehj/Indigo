using '../main.bicep'

param environment = 'dev'
param location = 'uksouth'
param sqlAdministratorLogin = 'indigoclaimsadmin'
param appServiceSku = 'B1'
param sqlDatabaseSkuName = 'Basic'

param tags = {
  environment: 'dev'
  application: 'claims-intake'
  owner: 'claims-platform'
  managedBy: 'bicep'
  dataClass: 'confidential'
  costCentre: 'insurance-claims'
}

// sqlAdministratorPassword is intentionally NOT stored here.
// Supply it securely at deployment time from Azure DevOps secret variables/Key Vault.
