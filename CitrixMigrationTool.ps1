# Load the required Citrix PowerShell SDK module
Import-Module Citrix*

# Create the WPF GUI
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Citrix Applications Query" Height="500" Width="600">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="10">
            <Label Content="Source Controller:" Width="120"/>
            <TextBox x:Name="SourceController" Width="200" Margin="0,0,10,0"/>
            <Label Content="Destination Controller:" Width="150"/>
            <TextBox x:Name="DestinationController" Width="200"/>
        </StackPanel>
        <Button x:Name="QueryButton" Content="Query Applications" Grid.Row="1" Width="150" Margin="10" HorizontalAlignment="Left"/>
        <ListBox x:Name="ApplicationsList" Grid.Row="2" Margin="10" SelectionMode="Multiple"/>
        <StackPanel Grid.Row="3" Orientation="Horizontal" Margin="10">
            <Label Content="Application Groups:" Width="120"/>
            <ListBox x:Name="ApplicationGroupList" Width="200" Height="100" Margin="0,0,10,0"/>
            <Button x:Name="CopyButton" Content="Copy Applications" Width="150"/>
        </StackPanel>
    </Grid>
</Window>
"@

# Parse the XAML
Add-Type -AssemblyName PresentationFramework
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get UI elements
$sourceControllerBox = $window.FindName("SourceController")
$destinationControllerBox = $window.FindName("DestinationController")
$applicationGroupListBox = $window.FindName("ApplicationGroupList")
$queryButton = $window.FindName("QueryButton")
$copyButton = $window.FindName("CopyButton")
$applicationsList = $window.FindName("ApplicationsList")

# Define the event handler for the query button click
$queryButton.Add_Click({
    # Clear the list boxes
    $applicationsList.Items.Clear()
    $applicationGroupListBox.Items.Clear()

    # Get the source and destination controller addresses
    $sourceController = $sourceControllerBox.Text
    $destinationController = $destinationControllerBox.Text

    if ([string]::IsNullOrEmpty($sourceController) -or [string]::IsNullOrEmpty($destinationController)) {
        [System.Windows.MessageBox]::Show("Please enter both source and destination controller addresses.")
        return
    }

    # Query the applications from the source controller
    try {
        $applications = Get-BrokerApplication -AdminAddress $sourceController

        # Populate the list box with application names
        foreach ($app in $applications) {
            $applicationsList.Items.Add($app.Name)
        }
    } catch {
        [System.Windows.MessageBox]::Show("Failed to query applications from the source controller. Please check the address and try again.")
    }

    # Query the application groups from the destination controller
    try {
        $appGroups = Get-BrokerApplicationGroup -AdminAddress $destinationController

        # Populate the list box with application group names
        foreach ($group in $appGroups) {
            $applicationGroupListBox.Items.Add($group.Name)
        }
    } catch {
        [System.Windows.MessageBox]::Show("Failed to query application groups from the destination controller. Please check the address and try again.")
    }
})

# Define the event handler for the copy button click
$copyButton.Add_Click({
    # Get the source and destination controller addresses
    $sourceController = $sourceControllerBox.Text
    $destinationController = $destinationControllerBox.Text

    # Get the selected application group
    $selectedAppGroupName = $applicationGroupListBox.SelectedItem

    if ([string]::IsNullOrEmpty($selectedAppGroupName)) {
        [System.Windows.MessageBox]::Show("Please select an application group.")
        return
    }

    # Retrieve the application group object from the destination controller
    $selectedAppGroup = Get-BrokerApplicationGroup -AdminAddress $destinationController -Name $selectedAppGroupName

    if ($null -eq $selectedAppGroup) {
        [System.Windows.MessageBox]::Show("Selected application group not found on the destination controller.")
        return
    }

    # Get the selected applications
    $selectedApplications = $applicationsList.SelectedItems

    if ($selectedApplications.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Please select at least one application to copy.")
        return
    }

    # Copy the selected applications to the destination controller within the specified application group and folder
    try {
        foreach ($appName in $selectedApplications) {
            try {
                # Query the application details from the source controller
                $app = Get-BrokerApplication -AdminAddress $sourceController -Name $appName

                # Build the parameters dynamically, checking for null values
                $params = @{
                    AdminAddress = $destinationController
                    Name = $app.Name
                    ApplicationType = $app.ApplicationType
                    ApplicationGroup = $selectedAppGroupName
                    CommandLineExecutable = $app.CommandLineExecutable
                    CommandLineArguments = $app.CommandLineArguments
                    Enabled = $app.Enabled
                    PublishedName = $app.PublishedName
                }

                if ($null -ne $app.DesktopGroup) {
                    $params["DesktopGroup"] = $app.DesktopGroup
                }

                if ($null -ne $app.IconUid) {
                    $params["IconUid"] = $app.IconUid
                }

                if ($null -ne $app.Visibility) {
                    $params["Visibility"] = $app.Visibility
                }

                # Log the parameters for debugging
                Write-Host "Copying application with parameters: $($params | Out-String)"

                # Create the application in the destination controller within the specified application group
                $newApp = New-BrokerApplication @params

                # Now, update the application's folder path to match the application group name
                Set-BrokerApplication -Uid $newApp.Uid -FolderPath $selectedAppGroupName

                [System.Windows.MessageBox]::Show("Successfully copied application: $($app.Name)")
            } catch {
                [System.Windows.MessageBox]::Show("Failed to copy application: $($appName). Error: $_")
            }
        }

        [System.Windows.MessageBox]::Show("Applications copied successfully.")
    } catch {
        [System.Windows.MessageBox]::Show("Failed to copy applications to the destination controller. Error: $_")
    }
})

# Show the window
$window.ShowDialog()
