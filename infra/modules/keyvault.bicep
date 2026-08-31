param environment string
param location string
param suffix string
param tags object

var vaultName = 'indigokv${environment}${take(suffix, 8)}'

resource vault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: vaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 30
    enablePurgeProtection: environment == 'prod'
    publicNetworkAccess: 'Enabled'
  }
}

output name string = vault.name
output id string = vault.id
