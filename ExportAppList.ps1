# Load the Citrix PowerShell snap-ins
Add-PSSnapin Citrix*

# Define the Delivery Controller address
$deliveryController = "YourDeliveryControllerFQDN"

# Establish a connection to the Citrix site
Get-BrokerSite -AdminAddress $deliveryController

# Query all the applications
$applications = Get-BrokerApplication -AdminAddress $deliveryController

# Define the export file path
$exportFilePath = "C:\Path\To\Your\Export\ApplicationsList.csv"

# Export the application list to a CSV file
$applications | Select-Object ApplicationName, PublishedName, Enabled, ApplicationType, AssociatedUserFullNames, AssociatedDesktopGroups, DeliveryGroups, InstalledMachines | Export-Csv -Path $exportFilePath -NoTypeInformation

Write-Host "Application list has been exported to $exportFilePath"