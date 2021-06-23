
# Define variables for networking part
$ResourceGroup  = "Test-RG"
$Location       = "westeurope"
$vNetName       = "test-vnet"
$AddressSpace   = "10.10.0.0/16" # Format 10.10.0.0/16
$SubnetIPRange  = "10.10.1.0/24" # Format 10.10.1.0/24
$SubnetName     = "test-subnet"
$nsgName        = "test-nsg"
$StorageAccount = "testdiagnsticxwast"

New-AzResourceGroup -Name $ResourceGroup -Location $Location
New-AzStorageAccount -Name $StorageAccount -ResourceGroupName $ResourceGroup -Location $Location -SkuName Standard_LRS

# Create Virtual Network and Subnet
$vNetwork = New-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $vNetName -AddressPrefix $AddressSpace -Location $location
Add-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $vNetwork -AddressPrefix $SubnetIPRange
Set-AzVirtualNetwork -VirtualNetwork $vNetwork

# Create Network Security Group
$nsgRuleVMAccess = New-AzNetworkSecurityRuleConfig -Name 'allow-vm-access' -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22,3389 -Access Allow
New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroup -Location $location -Name $nsgName -SecurityRules $nsgRuleVMAccess



$vNet       = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $vNetName
$Subnet     = Get-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $vNet
$nsg        = Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroup -Name $NsgName
$vmName 	= "DC-1"
$pubName	= "MicrosoftWindowsServer"
$offerName	= "WindowsServer"
$skuName	= "2019-Datacenter"
$vmSize 	= "Standard_B2s"
$nicName    = "$vmName-nic"
$osDiskName = "$vmName-OsDisk"
$osDiskSize = "60"
$osDiskType = "Premium_LRS"

$adminUsername = Read-Host 'username'
$adminPassword = Read-Host -AsSecureString 'password'
$adminCreds    = New-Object PSCredential $adminUsername, $adminPassword
$IpConfigName1 = "IPConfig-1"

$nic = New-AzNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroup -Location $location -SubnetId $Subnet.Id -NetworkSecurityGroupId $nsg.Id

#create av set
$avsetname = "DCsAvSet"

New-AzAvailabilitySet -Location $Location -Name $avsetname -ResourceGroupName $ResourceGroup -Sku aligned -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 2

$AvailabilitySet = Get-AzAvailabilitySet -ResourceGroupName $ResourceGroup -Name $avsetname

$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize -AvailabilitySetID $AvailabilitySet.Id
Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

# Set VM operating system parameters
Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $vmName -Credential $adminCreds

Set-AzVMBootDiagnostic -Enable -ResourceGroupName $ResourceGroup -VM $vmConfig -StorageAccountName $StorageAccount

# Set virtual machine source image
Set-AzVMSourceImage -VM $vmConfig -PublisherName $pubName -Offer $offerName -Skus $skuName -Version 'latest'

# Set OsDisk configuration
Set-AzVMOSDisk -VM $vmConfig -Name $osDiskName -StorageAccountType $osDiskType -CreateOption fromImage

# Create the VM
New-AzVM -ResourceGroupName $ResourceGroup -Location $location -VM $vmConfig
