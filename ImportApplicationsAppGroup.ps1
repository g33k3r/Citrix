<#
.SYNOPSIS
Imports published applications into a specified application group.

.DESCRIPTION
Requires a clean export of existing Applications via Clixml.
Use the corresponding ExportApplications.ps1 script for export.

.EXAMPLE
.\ImportApplications.ps1 -ApplicationGroupName "Application Group Name"

.EXAMPLE
.\ImportApplications.ps1 -ApplicationGroupName "Application Group Name" -Cloud

.NOTES
Export required from an existing application group. Use the corresponding export script to achieve an appropriate export.
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $True)]
    [String] $ApplicationGroupName,

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
        $application = Get-BrokerApplication -Name $app.Name
        Set-BrokerApplication -InputObject $application -IconUid $IconUid.Uid
        write-Verbose "Icon changed for application: $($app.Name)" -Verbose
    }
    catch {
        Write-Warning "Setting App Icon Failed for $($app.Name)" -Verbose
        Write-Warning "$_" -Verbose
    }
}

function AddUsersToApp {
    try {
        $users = $app.AssociatedUserNames 
        foreach ($user in $users) {
            Add-BrokerUser -Name "$user" -Application "$app.Name"
            write-Verbose "User: $($user) added for application (Limit Visibility): $($app.Name)" -Verbose
        }
    }
    catch {
        Write-Warning "Error on User: $($user) for application: $($app.Name)" -Verbose
    }
}

function AddTags {
    foreach ($Tag in $app.Tags) {
        if (Get-BrokerTag -Name $Tag -ErrorAction SilentlyContinue) {
            try {
                Get-BrokerTag -Name $Tag | Add-BrokerTag -Application $app.Name
            }
            catch {
                Write-Warning "Failed to assign Tag: $($Tag) to $($app.Name)" -Verbose
            }
        }
        else {
            try {
                New-BrokerTag -Name $Tag
                Get-BrokerTag -Name $Tag | Add-BrokerTag -Application $app.Name
            }
            catch {
                Write-Warning "Failed to create or assign Tag: $($Tag) to $($app.Name)" -Verbose
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

# Attempt to stop any existing transcripts
try {
    Stop-Transcript | Out-Null
} catch {
    # Ignore errors if no transcript is running
}

# Start a new transcript
try {
    Start-Transcript -Path $LogPS -ErrorAction Stop
} catch {
    Write-Warning "Could not start the transcript. Check permissions and path: $LogPS" -Verbose
    Exit
}

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
$ApplicationGroupUid = (Get-BrokerApplicationGroup -Name $ApplicationGroupName).Uid
if ($null -eq $ApplicationGroupUid) {
    Write-Warning "Specified Application Group '$ApplicationGroupName' not found. Exiting script."
    Exit
}

# Processing applications for import
foreach ($app in $Apps) {
    Write-Verbose "Processing Application $StartCount of $Count: $($app.Name)" -Verbose
    $existingApp = Get-BrokerApplication -Name $app.Name -ErrorAction SilentlyContinue
    if ($existingApp) {
        Write-Verbose "Application $($app.Name) already exists. Skipping..." -Verbose
    } else {
        try {
            # Create the application
            $newAppParams = @{
                ApplicationType = 'HostedOnDesktop';
                CommandLineExecutable = $app.CommandLineExecutable;
                CommandLineArguments = $app.CommandLineArguments;
                Name = $app.Name;
                PublishedName = $app.Name;
                Description = $app.Description;
                Enabled = $app.Enabled;
                WorkingDirectory = $app.WorkingDirectory;
                AdminFolderName = $app.AdminFolderName;
                UserFilterEnabled = $app.UserFilterEnabled;
                ApplicationGroupUid = $ApplicationGroupUid
            }
            # Conditionally add ClientFolder if it's not null or empty
            if (![string]::IsNullOrWhiteSpace($app.ClientFolder)) {
                $newAppParams['ClientFolder'] = $app.ClientFolder
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

            Write-Verbose "Successfully imported application: $($app.Name)" -Verbose
        } catch {
            Write-Warning "Failed to import application: $($app.Name). Error: $_" -Verbose
        }
    }
    $StartCount++
}

Write-Verbose "Stop logging" -Verbose
Stop-Transcript
$EndDTM = (Get-Date)
Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalSeconds) Seconds" -Verbose
Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalMinutes) Minutes" -Verbose
