<#
.SYNOPSIS
Exports applications from a specified Delivery Group to an XML file including their icons and settings.

.DESCRIPTION
Provides a clean export of existing applications via Clixml from specified Delivery Groups.

.EXAMPLE
.\ExportApplicationsFromDeliveryGroups.ps1

.EXAMPLE
.\ExportApplicationsFromDeliveryGroups.ps1 -OutputLocation "C:\temp"

.EXAMPLE
.\ExportApplicationsFromDeliveryGroups.ps1 -DeliveryGroup "My Delivery Group" -OutputLocation "C:\temp"

.EXAMPLE
.\ExportApplicationsFromDeliveryGroups.ps1 -DeliveryGroup "My Delivery Group" -OutputLocation "C:\temp" -Cloud

.NOTES
To be used in conjunction with the ImportApplicationsFromAppGroups.ps1 Script
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [String] $DeliveryGroup,

    [Parameter(Mandatory = $False)]
    [String] $OutputLocation = "$PSScriptRoot",

    [Parameter(Mandatory = $False)]
    [String] $IconOutput = "$PSScriptRoot\Resources\Icons",

    [Parameter(Mandatory = $False)]
    [Switch] $Cloud
)

$LogPS = "${env:SystemRoot}\Temp\AppsFromDeliveryGroupExport.log"
$StartDTM = Get-Date

function GetApps {
    $Count = $Apps.Count
    $StartCount = 1

    Write-Verbose "There are $Count Applications in Delivery Groups to process" -Verbose

    $Results = @()

    foreach ($app in $Apps) {
        Write-Verbose "Processing Application $StartCount ($($app.PublishedName)) of $Count" -Verbose

        # Handle Icon Export Path
        $iconPath = Join-Path -Path $IconOutput -ChildPath "$($app.IconUid).txt"
        if (-not (Test-Path -Path $iconPath)) {
            $encodedIconData = (Get-BrokerIcon -Uid $app.IconUid).EncodedIconData
            $encodedIconData | Out-File $iconPath
        }

        # Collect application details
        $Properties = @{
            AdminFolderName                 = $app.AdminFolderName
            ApplicationName                 = $app.ApplicationName
            ApplicationType                 = $app.ApplicationType
            CommandLineExecutable           = $app.CommandLineExecutable
            CommandLineArguments            = $app.CommandLineArguments
            WorkingDirectory                = $app.WorkingDirectory
            AssociatedDesktopGroupUUIDs     = $app.AssociatedDesktopGroupUUIDs
            AssociatedDesktopGroupUids      = $app.AssociatedDesktopGroupUids
            IconUid                         = $app.IconUid
            PublishedName                   = $app.PublishedName
            Description                     = $app.Description
            EncodedIconData                 = $encodedIconData
        }

        # Store each Application setting for export
        $Results += New-Object psobject -Property $Properties
        $StartCount++
    }

    # Exporting results
    $exportPath = Join-Path -Path $OutputLocation -ChildPath "ExportedApps_$(Get-Date -Format 'yyyyMMddHHmmss').clixml"
    $Results | Export-Clixml -Path $exportPath
    Write-Verbose "Exported file located at $exportPath" -Verbose
}

Write-Verbose "Start Logging" -Verbose
Start-Transcript -Path $LogPS | Out-Null

# Check if resources folder exists (to store icon)
if (-not (Test-Path -Path $IconOutput)) {
    New-Item -Path $IconOutput -ItemType Directory -Force | Out-Null
}

Add-PSSnapin Citrix.*

# Fetch applications
if ([string]::IsNullOrWhiteSpace($DeliveryGroup)) {
    Write-Verbose "No Delivery Group specified. Processing all Applications in all Delivery Groups" -Verbose
    $Apps = Get-BrokerApplication
} else {
    Write-Verbose "Delivery Group: $DeliveryGroup specified. Processing all Applications in $DeliveryGroup" -Verbose
    $DG = Get-BrokerDesktopGroup -Name $DeliveryGroup
    $Apps = Get-BrokerApplication | Where-Object { $_.AssociatedDesktopGroupUids -contains $DG.Uid }
}

GetApps

if ($Cloud.IsPresent) {
    Write-Verbose "Cloud Switch Specified, Attempting to Authenticate to Citrix Cloud" -Verbose
    try {
        Get-XDAuthentication # Added a Cloud Check - not validated yet
    }
    catch {
        Write-Warning "$_" -Verbose
        Write-Warning "Authentication Failed. Bye"
        Break
    }
}

Write-Verbose "Stop logging" -Verbose
Stop-Transcript | Out-Null
Write-Verbose "Logfile located at $LogPS" -Verbose
$EndDTM = Get-Date
Write-Verbose "Elapsed Time: $(($EndDTM - $StartDTM).TotalSeconds) Seconds" -Verbose
Write-Verbose "Elapsed Time: $(($EndDTM - $StartDTM).TotalMinutes) Minutes" -Verbose
