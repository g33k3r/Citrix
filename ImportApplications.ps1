<#
.SYNOPSIS
Imports published applications into a new delivery group and assigns them to a specified application group.

.DESCRIPTION
Requires a clean export of existing Applications via Clixml.
Use the corresponding ExportApplications.ps1 script for export.

.EXAMPLE
.\ImportApplications.ps1 -DeliveryGroup "Delivery Group Name" -ApplicationGroupName "Application Group Name"

.EXAMPLE
.\ImportApplications.ps1 -DeliveryGroup "Delivery Group Name" -ApplicationGroupName "Application Group Name" -Cloud

.NOTES
Export required from an existing delivery group. Use the corresponding export script to achieve an appropriate export.
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [String] $DeliveryGroup = $null,

    [Parameter(Mandatory = $False)]
    [String] $ApplicationGroupName = $null,

    [Parameter(Mandatory = $False)]
    [String] $IconSource = "$PSScriptRoot\Resources\Icons",

    [Parameter(Mandatory = $False)]
    [Switch] $Cloud
)

$LogPS = "${env:SystemRoot}\Temp\ApplicationImport.log"
$StartDTM = (Get-Date)

# Load Assemblies
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 

Add-PSSnapin citrix*

function ImportandSetIcon {
    $IconUid = New-BrokerIcon -EncodedIconData $app.EncodedIconData
    try {
        $application = Get-BrokerApplication -BrowserName $app.PublishedName
        Set-BrokerApplication -InputObject $application -IconUid $IconUid.Uid
        write-Verbose "Icon changed for application: $($app.PublishedName)" -Verbose
    }
    catch {
        Write-Warning "Setting App Icon Failed for $($app.PublishedName)" -Verbose
        Write-Warning "$_" -Verbose
    }
}

function AddUsersToApp {
    try {
        $users = $app.AssociatedUserNames 
        foreach ($user in $users) {
            $FullAppPath = $app.AdminFolderName + $app.PublishedName
            Add-BrokerUser -Name "$user" -Application "$FullAppPath"
            write-Verbose "User: $($user) added for application (Limit Visibility): $($app.PublishedName)" -Verbose
        }
    }
    catch {
        Write-Warning "Error on User: $($user) for application: $($app.PublishedName)" -Verbose
    }
}

function AddTags {
    foreach ($Tag in $app.Tags) {
        if (Get-BrokerTag -Name $Tag -ErrorAction SilentlyContinue) {
            try {
                Get-BrokerTag -Name $Tag | Add-BrokerTag -Application $app.PublishedName
            }
            catch {
                Write-Warning "Failed to assign Tag: $($Tag) to $($app.PublishedName)" -Verbose
            }
        }
        else {
            try {
                New-BrokerTag -Name $Tag
                Get-BrokerTag -Name $Tag | Add-BrokerTag -Application $app.PublishedName
            }
            catch {
                Write-Warning "Failed to create or assign Tag: $($Tag) to $($app.PublishedName)" -Verbose
            }
        }
    }
}

# Cloud authentication
if ($Cloud.IsPresent) {
    Write-Verbose "Cloud Switch Specified, Attempting to Authenticate to Citrix Cloud" -Verbose
    try {
        Get-XDAuthentication
    }
    catch {
        Write-Warning "$_" -Verbose
        Write-Warning "Authentication Failed. Exiting script." -Verbose
        Break
    }
}

Write-Verbose "Start Logging" -Verbose
Start-Transcript $LogPS | Out-Null

# Check if resources folder exists (to import icons)
if (-not (Test-Path -Path $IconSource)) {
    Write-Warning "No icon resources found at: $($IconSource). Please ensure icons exported are located there."
    Exit
}

# Load application data from XML
$Apps = Import-Clixml -Path "C:\path\to\your\exported\Applications.xml"
$Count = ($Apps | Measure-Object).Count
$StartCount = 1

# Validate or prompt for the Application Group
if ([string]::IsNullOrWhiteSpace($ApplicationGroupName)) {
    Write-Host "No Application Group specified. Available groups:"
    $AvailableGroups = Get-BrokerApplicationGroup | Select-Object Name, Uid
    Write-Host $AvailableGroups | Format-Table -AutoSize
    $ApplicationGroupUid = Read-Host -Prompt 'Enter the UID of the Application Group to use'
} else {
    $ApplicationGroupUid = (Get-BrokerApplicationGroup -Name $ApplicationGroupName).Uid
    if ($null -eq $ApplicationGroupUid) {
        Write-Warning "Specified Application Group '$ApplicationGroupName' not found. Exiting script."
        Exit
    }
}

# Processing applications for import
foreach ($app in $Apps) {
    Write-Verbose "Processing Application $StartCount of $Count: $($app.PublishedName)" -Verbose
    $existingApp = Get-BrokerApplication -PublishedName $app.PublishedName -ErrorAction SilentlyContinue
    if ($existingApp) {
        Write-Verbose "Application $($app.PublishedName) already exists. Skipping..." -Verbose
    } else {
        try {
            # Create the application
            $newAppParams = @{
                ApplicationType = 'HostedOnDesktop';
                CommandLineExecutable = $app.CommandLineExecutable;
                CommandLineArguments = $app.CommandLineArguments;
                Name = $app.PublishedName;
                PublishedName = $app.PublishedName;
                Description = $app.Description;
                ClientFolder = $app.ClientFolder;
                Enabled = $app.Enabled;
                WorkingDirectory = $app.WorkingDirectory;
                AdminFolderName = $app.AdminFolderName;
                UserFilterEnabled = $app.UserFilterEnabled;
                DesktopGroupUid = $DelGroup.Uid;
                ApplicationGroupUid = $ApplicationGroupUid
            }
            $newApp = New-BrokerApplication @newAppParams

            # Handle icon import
            if ($app.IconUid) {
                $iconPath = "$IconSource\$($app.IconUid).txt"
                if (Test-Path $iconPath) {
                    $encodedIconData = Get-Content $iconPath -Encoding Byte
                    $iconUid = New-BrokerIcon -EncodedIconData $encodedIconData
                    Set-BrokerApplication -InputObject $newApp -IconUid $iconUid.Uid
                }
            }

            # Adding Users and Groups to application associations
            AddUsersToApp

            # Adding Tags to Applications
            AddTags

            Write-Verbose "Successfully imported application: $($app.PublishedName)" -Verbose
        } catch {
            Write-Warning "Failed to import application: $($app.PublishedName). Error: $_" -Verbose
        }
    }
    $StartCount++
}

Write-Verbose "Stop logging" -Verbose
Stop-Transcript
$EndDTM = (Get-Date)
Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalSeconds) Seconds" -Verbose
Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalMinutes) Minutes" -Verbose
