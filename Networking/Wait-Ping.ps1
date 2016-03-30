﻿function Wait-Ping
{
	<#
	.SYNOPSIS
		Wait-Ping holds execution control until a computer computer responds to ping. By default, it will wait for up to 5 minutes
		(600 seconds) and give up. If the computer becomes available to ping within that time, Wait-Ping will release control and
		allow code execution to continue.
		
	.EXAMPLE
		PS> Wait-Ping -ComputerName MYSERVER
	
		This example will ping MYSERVER. If MYSERVER responds, Wait-Ping will immediately return control. If MYSERVER does not respond,
		Wait-Ping will attempt to ping MYSERVER ever 10 seconds up to a maximum duration of 5 minutes. If MYSERVER comes back online
		during that time, Wait-Ping will release control. If 5 minutes is passed, Wait-Ping will release control with a warning
		stating the timeout was exceeded.
		
	.PARAMETER ComputerName
		The Netbios, DNS FQDN or IP address of the computer you'd like to ping. This is mandatory.
	
	.PARAMETER Timeout
		The maximum amount of seconds that you'd like to wait for ComputerName to become available. By default, this is set to
		600 seconds (5 minutes).
	
	.PARAMETER CheckEvery
		The interval at which ComputerName is pinged during the timeout period to check to see if ComputerName has become available
		to ping yet.
	#>
	[CmdletBinding()]
	[OutputType($null)]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[int]$Timeout = 600,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[int]$CheckEvery = 10
		
	)
	try {
		$timer = [Diagnostics.Stopwatch]::StartNew()
		while (-not (Test-Connection -ComputerName $ComputerName -Quiet -Count 1))
		{
			Write-Verbose -Message "Waiting for [$($ComputerName)] to become pingable..."
			if ($timer.Elapsed.TotalSeconds -ge $Timeout)
			{
				throw "Timeout exceeded. Giving up on ping availability to [$ComputerName]"
			}
			Start-Sleep -Seconds $CheckEvery
		}
	}
	catch 
	{
		Write-Error -Message $_.Exception.Message
	}
	finally
	{
		if (Test-Path -Path Variable:\timer)
		{
			$timer.Stop()
		}
	}
}