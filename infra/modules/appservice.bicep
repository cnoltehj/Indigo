param workload string
param environment string
param location string
param appServiceSku string
param keyVaultName string
param applicationInsightsConnectionString string
param suffix string
param tags object

var planName = 'indigo-${workload}-plan-${environment}'
var appName = 'indigo-${workload}-api-${environment}-${take(suffix, 8)}'

resource plan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: planName
  location: location
  tags: tags
  sku: {
    name: appServiceSku
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource app 'Microsoft.Web/sites@2024-11-01' = {
  name: appName
  location: location
  tags: tags
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|10.0'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      alwaysOn: environment == 'prod'
      healthCheckPath: '/health'
      appSettings: [
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: environment == 'prod' ? 'Production' : 'Development'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsightsConnectionString
        }
        {
          name: 'ConnectionStrings__ClaimsDatabase'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=claims-sql-connection-string)'
        }
      ]
    }
  }
}

output name string = app.name
output defaultHostName string = app.properties.defaultHostName
output principalId string = app.identity.principalId
