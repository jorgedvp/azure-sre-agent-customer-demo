// =============================================================================
// Azure SRE Agent + Arc Customer Demo — Core infrastructure
// Deploys: VNet/Subnet/NSG, 2 VMs (Linux SQL + Windows IIS), Log Analytics,
//          Data Collection Rules, Data Collection Endpoint.
// Arc onboarding, SQL/IIS install, SRE Agent creation, RBAC, Defender and
// GitHub repo connection are handled by the scripts/ automation (not Bicep),
// since those require CLI steps and/or portal interaction that cannot be
// expressed declaratively.
// =============================================================================

@description('Location for all resources')
param location string = 'eastus2'

@description('Base name used to derive resource names')
param baseName string = 'sredemo'

@description('Admin username for both VMs')
param adminUsername string = 'azureadmin'

@description('Admin password for both VMs (Linux SSH + Windows local admin)')
@secure()
param adminPassword string

@description('SSH public key for the Linux VM')
param sshPublicKey string

@description('Your public IP address (CIDR), allowed for initial SSH/RDP setup only')
param allowedSetupIpCidr string

var vnetName = 'vnet-${baseName}'
var subnetName = 'subnet-onprem'
var nsgName = 'nsg-${baseName}'
var lawName = 'law-${baseName}'
var dceName = 'dce-${baseName}'
var dcrName = 'dcr-${baseName}'
var vmLinuxName = 'vm-onprem-sql'
var vmWindowsName = 'vm-onprem-iis'

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-Setup'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: allowedSetupIpCidr
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'Allow-RDP-Setup'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: allowedSetupIpCidr
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
      {
        name: 'Allow-HTTP-Setup'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: allowedSetupIpCidr
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.60.0.0/16']
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.60.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource pipLinux 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-${vmLinuxName}'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource pipWindows 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-${vmWindowsName}'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource nicLinux 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-${vmLinuxName}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: '${vnet.id}/subnets/${subnetName}' }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: { id: pipLinux.id }
        }
      }
    ]
  }
}

resource nicWindows 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-${vmWindowsName}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: '${vnet.id}/subnets/${subnetName}' }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: { id: pipWindows.id }
        }
      }
    ]
  }
}

resource vmLinux 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmLinuxName
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_D2ads_v6' }
    osProfile: {
      computerName: vmLinuxName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'StandardSSD_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [ { id: nicLinux.id } ]
    }
  }
}

resource vmWindows 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmWindowsName
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_D2as_v6' }
    osProfile: {
      computerName: vmWindowsName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-g2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'StandardSSD_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [ { id: nicWindows.id } ]
    }
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

resource dce 'Microsoft.Insights/dataCollectionEndpoints@2023-03-11' = {
  name: dceName
  location: location
  properties: {
    networkAcls: { publicNetworkAccess: 'Enabled' }
  }
}

resource dcr 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: dcrName
  location: location
  properties: {
    dataCollectionEndpointId: dce.id
    dataSources: {
      performanceCounters: [
        {
          name: 'perfCounters'
          streams: ['Microsoft-Perf']
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
            '\\Processor(_Total)\\% Processor Time'
            '\\Memory\\% Committed Bytes In Use'
            '\\LogicalDisk(_Total)\\% Free Space'
            '\\LogicalDisk(_Total)\\Free Megabytes'
          ]
        }
      ]
      syslog: [
        {
          name: 'syslogSource'
          streams: ['Microsoft-Syslog']
          facilityNames: ['auth', 'authpriv', 'daemon', 'syslog', 'user']
          logLevels: ['Warning', 'Error', 'Critical', 'Alert', 'Emergency']
        }
      ]
      windowsEventLogs: [
        {
          name: 'windowsEventSource'
          streams: ['Microsoft-Event']
          xPathQueries: [
            'System!*[System[(Level=1 or Level=2 or Level=3)]]'
            'Application!*[System[(Level=1 or Level=2 or Level=3)]]'
          ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: 'lawDestination'
          workspaceResourceId: law.id
        }
      ]
    }
    dataFlows: [
      { streams: ['Microsoft-Perf'], destinations: ['lawDestination'] }
      { streams: ['Microsoft-Syslog'], destinations: ['lawDestination'] }
      { streams: ['Microsoft-Event'], destinations: ['lawDestination'] }
    ]
  }
}

output lawName string = law.name
output lawId string = law.id
output dcrName string = dcr.name
output dcrId string = dcr.id
output vmLinuxName string = vmLinux.name
output vmWindowsName string = vmWindows.name
output pipLinuxAddress string = pipLinux.properties.ipAddress
output pipWindowsAddress string = pipWindows.properties.ipAddress
