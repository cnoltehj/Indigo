targetScope = 'resourceGroup'

@description('Deployment environment.')
@allowed([
  'dev'
  'prod'
])
param environment string

@description('Azure region used for the workload.')
param location string = resourceGroup().location

@description('SQL administrator login. Supplied by pipeline or deployment operator.')
param sqlAdministratorLogin string

@secure()
@description('SQL administrator password. Never commit this value to source control.')
param sqlAdministratorPassword string

@description('App Service Plan SKU.')
param appServiceSku string = 'B1'

@description('Azure SQL Database SKU name.')
param sqlDatabaseSkuName string = 'Basic'

@description('Common governance tags.')
param tags object

var workload = 'claims'
var suffix = uniqueString(resourceGroup().id, environment)

module monitoring './modules/monitoring.bicep' = {
  name: 'monitoring-${environment}'
  params: {
    workload: workload
    environment: environment
    location: location
    tags: tags
  }
}

module keyVault './modules/keyvault.bicep' = {
  name: 'keyvault-${environment}'
  params: {
    environment: environment
    location: location
    suffix: suffix
    tags: tags
  }
}

module database './modules/database.bicep' = {
  name: 'database-${environment}'
  params: {
    workload: workload
    environment: environment
    location: location
    suffix: suffix
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorPassword: sqlAdministratorPassword
    sqlDatabaseSkuName: sqlDatabaseSkuName
    tags: tags
  }
}

module appService './modules/appservice.bicep' = {
  name: 'appservice-${environment}'
  params: {
    workload: workload
    environment: environment
    location: location
    appServiceSku: appServiceSku
    keyVaultName: keyVault.outputs.name
    applicationInsightsConnectionString: monitoring.outputs.applicationInsightsConnectionString
    suffix: suffix
    tags: tags
  }
}

// Assign the App Service managed identity least-privilege read access to Key Vault secrets.
// This is isolated in a module so the runtime-created principalId is a module input.
module keyVaultRole './modules/keyvault-role.bicep' = {
  name: 'keyvault-role-${environment}'
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: appService.outputs.principalId
  }
}

output appServiceName string = appService.outputs.name
output appServiceHostName string = appService.outputs.defaultHostName
output sqlServerName string = database.outputs.sqlServerName
output sqlDatabaseName string = database.outputs.sqlDatabaseName
output keyVaultName string = keyVault.outputs.name
output applicationInsightsName string = monitoring.outputs.applicationInsightsName
