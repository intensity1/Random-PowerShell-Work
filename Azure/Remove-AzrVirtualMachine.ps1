﻿#Requires -Module AzureRM.Compute
#Requires -Version 4

function Remove-AzrVirtualMachine
{
	<#
	.SYNOPSIS
		This function is used to remove any Azure VMs as well as any attached disks. By default, this function creates a job
		due to the time it takes to remove an Azure VM.
		
	.EXAMPLE
		PS> Login-AzureRmAccount -Credential (Get-KeyStoreCredential -Name 'svcOrchestrator')
		PS> Get-AzureRmVm -Name 'BAPP07GEN22' | Remove-AzrVirtualMachine
	
		This example removes the Azure VM BAPP07GEN22 as well as any disks attached to it.
		
	.PARAMETER VMName
		The name of an Azure VM. This has an alias of Name which can be used as pipeline input from the Get-AzureRmVM cmdlet.
	
	.PARAMETER ResourceGroupName
		The name of the resource group the Azure VM is a part of.
	
	.PARAMETER Wait
		If you'd rather wait for the Azure VM to be removed before returning control to the console, use this switch parameter.
		If not, it will create a job and return a PSJob back.
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[Alias('Name')]
		[string]$VMName,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$ResourceGroupName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$Wait
		
	)
	process
	{
		try
		{
			$scriptBlock = {
				param ($VMName,
					
					$ResourceGroupName)
				$commonParams = @{
					'Name' = $VMName;
					'ResourceGroupName' = $ResourceGroupName
				}
				$vm = Get-AzureRmVm @commonParams
				
				#region Get the VM ID
				$azResourceParams = @{
					'ResourceName' = $VMName
					'ResourceType' = 'Microsoft.Compute/virtualMachines'
					'ResourceGroupName' = $ResourceGroupName
				}
				$vmResource = Get-AzureRmResource @azResourceParams
				$vmId = $vmResource.Properties.VmId
				#endregion
				
				#region Remove the boot diagnostics disk
				if ($vm.DiagnosticsProfile.bootDiagnostics)
				{
					Write-Verbose -Message 'Removing boot diagnostics storage container...'
					$diagSa = [regex]::match($vm.DiagnosticsProfile.bootDiagnostics.storageUri, '^http://(.+?)\.').groups[1].value
					$diagContainerName = ('bootdiagnostics-{0}-{1}' -f $vm.Name.ToLower().Substring(0, 9), $vmId)
					$diagSaRg = (Get-AzureRmStorageAccount | where { $_.StorageAccountName -eq $diagSa }).ResourceGroupName
					Get-AzureRmStorageAccount -ResourceGroupName $diagsarg -Name $diagsa | Remove-AzureStorageContainer -Name $diagContainerName -Force
				}
				#endregion
				
				Write-Verbose -Message 'Removing the Azure VM...'
				$null = $vm | Remove-AzureRmVM -Force
				Write-Verbose -Message 'Removing the Azure network interface...'
				$nulll = $vm | Remove-AzureRmNetworkInterface -Force
				
				## Remove the OS disk
				Write-Verbose -Message 'Removing OS disk...'
				$osDiskUri = $vm.StorageProfile.OSDisk.Vhd.Uri
				$osDiskContainerName = $osDiskUri.Split('/')[-2]
				$osDiskStorageAcct = Get-AzureRmStorageAccount -Name $osDiskUri.Split('/')[2].Split('.')[0]
				$osDiskStorageAcct | Remove-AzureStorageBlob -Container $osDiskContainerName -Blob $osDiskUri.Split('/')[-1] -ea Ignore
				
				#region Remove the status blob
				##TODO: Figure out how to get the ID in this blob
				#$osDiskStorageAcct | Remove-AzureStorageBlob -Container $osDiskContainerName -Blob $statusBlobName
				#endregion
				
				## Remove any other attached disks
				if ($vm.DataDiskNames.Count -gt 0)
				{
					Write-Verbose -Message 'Removing data disks...'
					foreach ($uri in $vm.StorageProfile.DataDisks.Vhd.Uri)
					{
						$dataDiskStorageAcct = Get-AzureRmStorageAccount -Name $uri.Split('/')[2].Split('.')[0]
						$dataDiskStorageAcct | Remove-AzureStorageBlob -Container $uri.Split('/')[-2] -Blob $uri.Split('/')[-1] -ea Ignore
					}
				}
			}
			
			if ($Wait.IsPresent)
			{
				& $scriptBlock -VMName $VMName -ResourceGroupName $ResourceGroupName
			}
			else
			{
				$initScript = {
					$null = Login-AzureRmAccount -Credential (Get-KeyStoreCredential -Name 'Azure svcOrchestrator')
				}
				Start-Job -ScriptBlock $scriptBlock -InitializationScript $initScript -ArgumentList @($VMName, $ResourceGroupName)
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}