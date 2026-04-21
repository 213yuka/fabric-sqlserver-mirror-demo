// SQL Server 2022 Developer on Windows Server 2022 VM (West US 3)
// - VNet has a dedicated subnet delegated to Microsoft.PowerPlatform/vnetaccesslinks
//   for the Fabric VNet Data Gateway.
// - SQL listens on 1433 (private VNet path; Fabric reaches it via the VNet DG).
// - Public IP retained for admin (RDP / az vm run-command).
targetScope = 'resourceGroup'

@description('Resource name prefix')
param namePrefix string = 'sqlmirror'

@description('Azure region')
param location string = resourceGroup().location

@description('VM size')
param vmSize string = 'Standard_D2s_v5'

@description('Local Windows admin username')
param adminUsername string = 'azureuser'

@description('Local Windows admin password')
@secure()
param adminPassword string

@description('SQL Server SQL auth login (used by Fabric)')
param sqlAuthLogin string = 'fabric_login'

@description('Password for sqlAuthLogin')
@secure()
param sqlAuthPassword string

@description('Public IP allowed for inbound RDP. Use your client IP/CIDR. * = any (demo only)')
param allowedSourceCidr string = '*'

@description('SQL TCP port (Fabric reaches SQL via VNet DG over private IP, so 1433 is fine).')
param sqlPort int = 1433

@description('SendGrid API key for email notifications (leave empty to skip)')
@secure()
param sendGridApiKey string = ''

@description('Email address to receive change notifications')
param alertEmailTo string = ''

@description('Sender email address for SendGrid')
param alertEmailFrom string = 'noreply@sqlmirror-demo.example.com'

var vnetName       = '${namePrefix}-vnet'
var subnetVm       = 'sql-subnet'
var subnetGateway  = 'gateway-subnet'
var subnetFunc     = 'func-subnet'
var nsgName        = '${namePrefix}-nsg'
var pipName        = '${namePrefix}-pip'
var nicName        = '${namePrefix}-nic'
var vmName         = '${namePrefix}-vm'
var funcAppName    = '${namePrefix}-func-${uniqueString(resourceGroup().id)}'
var storageName    = toLower('${namePrefix}st${uniqueString(resourceGroup().id)}')
var lawName        = '${namePrefix}-law'
var appInsightsName = '${namePrefix}-ai'
var dnsLabel       = toLower('${namePrefix}-${uniqueString(resourceGroup().id)}')

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowRDP'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: allowedSourceCidr
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
      {
        // Allow SQL from inside the VNet (covers VNet Data Gateway subnet)
        name: 'AllowSQL-FromVNet'
        properties: {
          priority: 1010
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: string(sqlPort)
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: { addressPrefixes: [ '10.30.0.0/16' ] }
    subnets: [
      {
        name: subnetVm
        properties: {
          addressPrefix: '10.30.1.0/24'
          networkSecurityGroup: { id: nsg.id }
        }
      }
      {
        // Subnet for the Fabric VNet Data Gateway. Must be delegated.
        name: subnetGateway
        properties: {
          addressPrefix: '10.30.2.0/24'
          delegations: [
            {
              name: 'pp-delegation'
              properties: {
                serviceName: 'Microsoft.PowerPlatform/vnetaccesslinks'
              }
            }
          ]
        }
      }
      {
        // Subnet for Azure Functions VNet integration
        name: subnetFunc
        properties: {
          addressPrefix: '10.30.3.0/24'
          delegations: [
            {
              name: 'func-delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: pipName
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: { domainNameLabel: dnsLabel }
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: vnet.properties.subnets[0].id }
          publicIPAddress: { id: pip.id }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: 'sqlmirrorvm'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftSQLServer'
        offer: 'sql2022-ws2022'
        sku: 'sqldev-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'Premium_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [ { id: nic.id } ]
    }
  }
}

// SQL VM extension: enables SQL Auth and opens port (PRIVATE connectivity)
resource sqlVm 'Microsoft.SqlVirtualMachine/sqlVirtualMachines@2023-10-01' = {
  name: vmName
  location: location
  properties: {
    virtualMachineResourceId: vm.id
    sqlServerLicenseType: 'PAYG'
    sqlManagement: 'Full'
    sqlImageSku: 'Developer'
    sqlImageOffer: 'SQL2022-WS2022'
    serverConfigurationsManagementSettings: {
      sqlConnectivityUpdateSettings: {
        connectivityType: 'PRIVATE'
        port: sqlPort
        sqlAuthUpdateUserName: sqlAuthLogin
        sqlAuthUpdatePassword: sqlAuthPassword
      }
      additionalFeaturesServerConfigurations: {
        isRServicesEnabled: false
      }
    }
  }
}

// ---- Azure Functions (SQL Trigger) resources ----

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: lawName
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: law.id
  }
}

resource funcPlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: '${namePrefix}-plan'
  location: location
  sku: {
    tier: 'FlexConsumption'
    name: 'FC1'
  }
  kind: 'functionapp'
  properties: {
    reserved: true
  }
}

resource funcApp 'Microsoft.Web/sites@2024-04-01' = {
  name: funcAppName
  location: location
  kind: 'functionapp,linux'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: funcPlan.id
    virtualNetworkSubnetId: vnet.properties.subnets[2].id
    siteConfig: {
      appSettings: [
        { name: 'AzureWebJobsStorage', value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${storage.listKeys().keys[0].value};EndpointSuffix=core.windows.net' }
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'dotnet-isolated' }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsights.properties.ConnectionString }
        { name: 'SqlConnectionString', value: 'Server=${nic.properties.ipConfigurations[0].properties.privateIPAddress},${sqlPort};Database=AdventureWorksLT2022;User Id=${sqlAuthLogin};Password=${sqlAuthPassword};Encrypt=True;TrustServerCertificate=True' }
        { name: 'SendGridApiKey', value: sendGridApiKey }
        { name: 'AlertEmailTo', value: alertEmailTo }
        { name: 'AlertEmailFrom', value: alertEmailFrom }
      ]
      netFrameworkVersion: 'v8.0'
      linuxFxVersion: 'DOTNET-ISOLATED|8.0'
    }
    httpsOnly: true
  }
}

output vmFqdn string             = pip.properties.dnsSettings.fqdn
output vmPublicIp string         = pip.properties.ipAddress
output vmPrivateIp string        = nic.properties.ipConfigurations[0].properties.privateIPAddress
output sqlServerEndpoint string  = '${pip.properties.dnsSettings.fqdn},${sqlPort}'
output sqlPort int               = sqlPort
output sqlAuthLoginName string   = sqlAuthLogin
output vnetId string             = vnet.id
output gatewaySubnetId string    = vnet.properties.subnets[1].id
output gatewaySubnetName string  = subnetGateway
output funcAppName string        = funcApp.name
output funcAppUrl string         = 'https://${funcApp.properties.defaultHostName}'
output appInsightsName string    = appInsights.name
