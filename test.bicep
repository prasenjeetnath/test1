targetScope = 'resourceGroup'

@description('Virtual Network Name')
param vnetName string = 'abccopilot-vnet'

@description('Key Vault Name')
param keyVaultName string = 'testvault11'

@description('Storage Account Name')
param storageAccountName string = 'abccopilotdb'

@description('Azure AI Search Service Name')
param searchServiceName string = 'abccopilotuserdb'

@description('App Service Plan Name')
param appServicePlanName string = 'abccopilot-prod-ui'

@description('App Service Name')
param appServiceName string = 'abccopilot-prod-ui'

@description('Location for all resources')
param location string = resourceGroup().location


resource searchService 'Microsoft.Search/searchServices@2020-08-01' = {
  name: searchServiceName
  location: location
  properties: {
    hostingMode: 'default'
    networkRuleSet: {
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: defaultSubnet.id
        }
      ]
    }
  }
  sku: {
    name: 'standard'
  }
  dependsOn: [
    keyVault
  ]
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    networkAcls: {
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: defaultSubnet.id
        }
      ]
    }
  }
  dependsOn: [
    keyVault
  ]
}

resource attachmentsTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2021-04-01' = {
  parent: storageAccount
  name: 'Attachments'
  properties: {}
}

resource usersTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2021-04-01' = {
  parent: storageAccount
  name: 'Users'
  properties: {}
}

resource userRequestsTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2021-04-01' = {
  parent: storageAccount
  name: 'UserRequests'
  properties: {}
}

resource usageMonitoringTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2021-04-01' = {
  parent: storageAccount
  name: 'UsageMonitoring'
  properties: {}
}

resource abcCopilotContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  parent: storageAccount
  name: 'abccopilot-userdata'
  properties: {}
}

resource appServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'P0V3'
    tier: 'PremiumV3'
  }
}

resource appService 'Microsoft.Web/sites@2021-02-01' = {
  name: appServiceName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      appSettings: [
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
    }
  }
  kind: 'app,linux'
  dependsOn: [
    appServicePlan
  ]
}

resource appInsights 'Microsoft.Insights/components@2021-05-01' = {
  name: '${appServiceName}-ai'
  location: location
  properties: {
    Application_Type: 'web'
  }
  dependsOn: [
    appService
  ]
}

resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'appServiceDiagnostics'
  scope: appService
  properties: {
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
    storageAccountId: storageAccount.id
  }
  dependsOn: [
    appService
    storageAccount
  ]
}

resource autoScaleSetting 'Microsoft.Insights/autoscaleSettings@2021-05-01' = {
  name: '${appServiceName}-autoscale'
  location: location
  properties: {
    profiles: [
      {
        name: 'AutoScaleProfile'
        capacity: {
          minimum: '1'
          maximum: '2'
          default: '1'
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricNamespace: 'Microsoft.Web/sites'
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT1M'
            }
          }
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricNamespace: 'Microsoft.Web/sites'
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 30
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT1M'
            }
          }
        ]
      }
    ]
    enabled: true
    targetResourceUri: appService.id
  }
  dependsOn: [
    appService
  ]
}
