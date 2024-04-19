<#
.SYNOPSIS
Imports applications from an XML file, setting users, tags, and AppGroup memberships as defined in the export.

.DESCRIPTION
Requires an XML export from a delivery group, including applications, users, tags, and AppGroup memberships.

.EXAMPLE
.\ImportApplicationsFromAppGroup.ps1
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [String] $IconSource = "$PSScriptRoot\Resources\Icons",

    [Parameter(Mandatory = $False)]
    [Switch] $Cloud
)

$LogPS = "${env:SystemRoot}\Temp\ApplicationImport.log"
$StartDTM = (Get-Date)

Add-PSSnapin citrix*

Write-Verbose "Start Logging" -Verbose
Start-Transcript $LogPS | Out-Null

# Checking icon resources folder
if (Test-Path -Path $IconSource) {
    Write-Verbose "Icon resources located" -Verbose
} else {
    Write-Warning "No icon resources found - please ensure icons exported are located at: $($IconSource)"
    Exit 1
}

# Prompt for XML file if not specified
Write-Verbose "Please Select an XML Import File" -Verbose
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
    InitialDirectory = [Environment]::GetFolderPath('Desktop') 
    Filter = 'XML Files (*.xml)|*.xml'
}
$null = $FileBrowser.ShowDialog()

if ($FileBrowser.FileName) {
    $Apps = Import-Clixml -Path $FileBrowser.FileName
} else {
    Write-Warning "No input file selected. Exiting."
    Exit
}

$Count = ($Apps | Measure-Object).Count
$StartCount = 1

foreach ($App in $Apps) {
    Write-Verbose "Processing Application $StartCount of $Count: $($App.PublishedName)" -Verbose
    $existingApp = Get-BrokerApplication -PublishedName $App.PublishedName -ErrorAction SilentlyContinue

    if ($existingApp) {
        Write-Verbose "Application with Name: $($App.PublishedName) already exists. Ignoring."
        $StartCount++
        continue
    } else {
        $MakeAppCmd = "New-BrokerApplication -ApplicationType HostedOnDesktop"
        $failed = $false

        # Prepare the command by dynamically appending properties if they are not null or empty
        $App.PSObject.Properties | ForEach-Object {
            if ($null -ne $_.Value -and $_.Name -ne 'IconUid' -and $_.Name -ne 'EncodedIconData') {
                $value = $_.Value -replace "'", "''" # Handle single quotes in values by doubling them
                $MakeAppCmd += " -$($_.Name) '$value'"
            }
        }

        if ($null -ne $App.IconUid) {
            $IconPath = "$IconSource\$($App.IconUid).txt"
            if (Test-Path -Path $IconPath) {
                $EncodedIconData = Get-Content -Path $IconPath
                $IconUid = New-BrokerIcon -EncodedIconData $EncodedIconData
                $MakeAppCmd += " -IconUid $IconUid.Uid"
            } else {
                Write-Warning "Icon file missing for application: $($App.PublishedName)"
                $failed = $true
            }
        }

        if (-not $failed) {
            try {
                Invoke-Expression $MakeAppCmd
                Write-Verbose "Successfully created application: $($App.PublishedName)"
            } catch {
                Write-Warning "Failed to create application: $($App.PublishedName). Error: $_"
                $failed = $true
            }
        }

        # Additional setup such as adding users and tags if the application creation was successful and not failed
        if (-not $failed) {
            AddUsersToApp -App $App
            AddTags -App $App
            AddToAdditionalAppGroups -App $App
        }

        $StartCount++
    }
}

Stop-Transcript | Out-Null
Write-Verbose "Import Complete - Logfile located at $LogPS" -Verbose
$EndDTM = (Get-Date)
Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalSeconds) Seconds" -Verbose
