<#
.SYNOPSIS

.DESCRIPTION
Provides a clean export of existing Applications via Clixml (See notes)

.EXAMPLE
The following example will export all apps from all Delivery Groups and output the XML files to the current location:
.\ExportApplicationsFromDeliveryGroups.ps1

.EXAMPLE
The following example will export all apps from all Delivery Groups and output the XML files to C:\Temp:
.\ExportApplicationsFromDeliveryGroups.ps1 -OutputLocation "C:\temp"

.EXAMPLE
The following example will export all apps from a single specified Delivery Group and output the XML files to C:\Temp:
.\ExportApplicationsFromDeliveryGroups.ps1 -DeliveryGroup "My Delivery Group" -OutputLocation "C:\temp"

.EXAMPLE
Specifies Citrix Cloud as the export location, calling Citrix Cloud based PS Modules:
.\ExportApplicationsFromDeliveryGroups.ps1 -DeliveryGroup "My Delivery Group" -OutputLocation "C:\temp" -Cloud

.NOTES
To be used in conjunction with the ImportApplicationsFromAppGroups.ps1 Script

#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [String] $DeliveryGroup = $null,

    [Parameter(Mandatory = $False)]
    [String] $OutputLocation = $null,

    [Parameter(Mandatory = $False)]
    [String] $IconOutput = "$PSScriptRoot\Resources\Icons",

    [Parameter(Mandatory = $False)]
    [Switch] $Cloud
)

$LogPS = "${env:SystemRoot}\Temp\AppsFromDeliveryGroupExport.log"
$StartDTM = (Get-Date)

function GetApps {
    try {

        $Count = ($Apps | Measure-Object).Count
        $StartCount = 1

        Write-Verbose "There are $Count Applications in Delivery Groups to process" -Verbose

        $Results = @()

        foreach ($app in $apps) {
            Write-Verbose "Processing Application $StartCount ($($App.PublishedName)) of $Count" -Verbose

            #Handle Icon Export Path
            if (-not(Test-Path -Path "$IconOutput/$($app.IconUid).txt")) {
                (Get-Brokericon -Uid $app.IconUid).EncodedIconData | Out-File "$IconOutput/$($app.IconUid).txt"
            }

            $DeliveryGroupMembership = $app.AssociatedDesktopGroupUids
            foreach ($DGMembership in $DeliveryGroupMembership) {
                try {
                    $DG = Get-BrokerDesktopGroup -Uid $DGMembership
                    Write-Verbose "$($App.PublishedName) is a member of $($DG.Name)" -Verbose
                }
                catch {
                    Write-Warning "$_" -Verbose
                }
            }
            # Builds Properties for each application ready for export
            $Properties = @{
                AdminFolderName                  = $app.AdminFolderName
                AdminFolderUid                   = $app.AdminFolderUid
                ApplicationName                  = $app.ApplicationName
                ApplicationType                  = $app.ApplicationType
                AssociatedDesktopGroupPriorities = $app.AssociatedDesktopGroupPriorities
                AssociatedDesktopGroupUUIDs      = $app.AssociatedDesktopGroupUUIDs
                AssociatedDesktopGroupUids       = $app.AssociatedDesktopGroupUids
                AssociatedUserFullNames          = $app.AssociatedUserFullNames
                AssociatedUserNames              = $app.AssociatedUserNames
                AssociatedUserUPNs               = $app.AssociatedUserUPNs
                BrowserName                      = $app.BrowserName
                ClientFolder                     = $app.ClientFolder
                CommandLineArguments             = $app.CommandLineArguments
                CommandLineExecutable            = $app.CommandLineExecutable
                CpuPriorityLevel                 = $app.CpuPriorityLevel
                Description                      = $app.Description
                IgnoreUserHomeZone               = $app.IgnoreUserHomeZone
                Enabled                          = $app.Enabled
                IconFromClient                   = $app.IconFromClient
                EncodedIconData                  = (Get-Brokericon -Uid $app.IconUid).EncodedIconData # Grabs Icon Image
                IconUid                          = $app.IconUid                       
                MetadataKeys                     = $app.MetadataKeys
                MetadataMap                      = $app.MetadataMap
                MaxPerUserInstances              = $app.MaxPerUserInstances
                MaxTotalInstances                = $app.MaxTotalInstances
                Name                             = $app.Name
                PublishedName                    = $app.PublishedName
                SecureCmdLineArgumentsEnabled    = $app.SecureCmdLineArgumentsEnabled
                ShortcutAddedToDesktop           = $app.ShortcutAddedToDesktop
                ShortcutAddedToStartMenu         = $app.ShortcutAddedToStartMenu
                StartMenuFolder                  = $app.StartMenuFolder
                UUID                             = $app.UUID
                Uid                              = $app.Uid
                HomeZoneName                     = $app.HomeZoneName
                HomeZoneOnly                     = $app.HomeZoneOnly
                HomeZoneUid                      = $app.HomeZoneUid
                UserFilterEnabled                = $app.UserFilterEnabled
                Visible                          = $app.Visible
                WaitForPrinterCreation           = $app.WaitForPrinterCreation
                WorkingDirectory                 = $app.WorkingDirectory
                Tags                             = $app.Tags
            }

            # Stores each Application setting for export
            $Results += New-Object psobject -Property $properties
            $StartCount += 1
        }
        # Exporting results
        $Results | Export-Clixml $ExportLocation
        Write-Verbose "Exported file located at $ExportLocation" -Verbose                 
    }
    catch {
        Write-Warning "$_" -Verbose
    }           
}

Write-Verbose "Start Logging" -Verbose
Start-Transcript $LogPS | Out-Null

# Check if resources folder exists (to store icon)
Write-Verbose "Icon output path is $($IconOutput)" -Verbose
if (-not(Test-Path -Path $IconOutput)) {
    New-Item -Path $IconOutput -ItemType Directory -Force | Out-Null
}

Add-PSSnapin citrix*

# Setting File name
$Date = Get-Date
$FileName = $Date.ToShortDateString() + $Date.ToLongTimeString()
$FileName = (($FileName -replace ":", "") -replace " ", "") -replace "/", ""
$FileName = "Apps_" + $FileName + ".xml"
$FileName = ($FileName -replace " ", "_")

if (!$OutputLocation) {
    $ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
    $ExportLocation = $ScriptDir + "\" + $FileName
}
else {
    $ExportLocation = $OutputLocation + "\" + $FileName
}

if (!$DeliveryGroup) {
    Write-Verbose "No Delivery Group specified. Processing all Applications in all Delivery Groups" -Verbose
    $Apps = Get-BrokerApplication
    GetApps
}
else {
    Write-Verbose "Delivery Group: $($DeliveryGroup) specified. Processing all Applications in $($DeliveryGroup)" -Verbose
    $DG = Get-BrokerDesktopGroup -Name $DeliveryGroup
    $Apps = Get-BrokerApplication | Where-Object { $_.AssociatedDesktopGroupUids -contains $DG.Uid }
    GetApps
}

if ($Cloud.IsPresent) {
    Write-Verbose "Cloud Switch Specified, Attempting to Authenticate to Citrix Cloud" -Verbose
    try {
        Get-XDAuthentication
    }
    catch {
        Write-Warning "$_" -Verbose
        Write-Warning "Authentication Failed. Bye"
        Break
    }
}

Write-Verbose "Stop logging" -Verbose
Write-Verbose "Logfile located at $LogPS" -Verbose
$EndDTM = (Get-Date)
Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalSeconds) Seconds" -Verbose
Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalMinutes) Minutes" -Verbose
Stop-Transcript | Out-Null
