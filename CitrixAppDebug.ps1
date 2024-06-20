# Load the required Citrix PowerShell SDK module
Import-Module Citrix*

# Create the WPF GUI
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Citrix App Migration Tool" Height="650" Width="800">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <Grid.ColumnDefinitions> 
            <ColumnDefinition Width = "Auto" />
            <ColumnDefinition Width = "400" /> 
        </Grid.ColumnDefinitions> 

        <StackPanel Grid.Column="1" Grid.Row="0" Orientation="Horizontal" Margin="10">
            <Label Content="Source Controller:" Width="120"/>
            <TextBox x:Name="SourceController" Width="200" Margin="0,0,10,0"/>
        </StackPanel>

        <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="10">
            <Label Content="Destination Controller:" Width="150"/>
            <TextBox x:Name="DestinationController" Width="200"/>
        </StackPanel>
        
        <Button x:Name="QueryButton" Content="Query Applications" Grid.Row="1" Grid.ColumnSpan="2" Width="760" Margin="10" HorizontalAlignment="Left"/>
        <DataGrid x:Name="ApplicationsDataGrid" Grid.Column="1" Grid.Row="2" Grid.RowSpan="3" Margin="10" AutoGenerateColumns="False" CanUserAddRows="False" SelectionMode="Extended" SelectionUnit="FullRow" IsReadOnly="True">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Application Name" Binding="{Binding Name}" Width="*"/>
                <DataGridTextColumn Header="Enabled" Binding="{Binding Enabled}" Width="Auto"/>
            </DataGrid.Columns>
        </DataGrid>
        <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="10">
            <Label x:Name="ApplicationGroupLabel" Content="Destination App Groups:" Width="150"/>
            <ListBox x:Name="ApplicationGroupList" Width="200" Margin="0,0,10,0"/>
        </StackPanel>
        <StackPanel Grid.Row="4" Orientation="Horizontal" Margin="10">
            <Label Content="Satellite Zone Name:" Width="150"/>
            <TextBox x:Name="UserFolder" Width="200" Margin="0,0,10,0"/>
        </StackPanel>
        <StackPanel Grid.Row="5" Grid.ColumnSpan="2" Orientation="Horizontal" Margin="10">
            <Button x:Name="CopyButton" Content="Copy Applications" Width="760"/>
        </StackPanel>
        <StackPanel Grid.Row="3" Orientation="Horizontal" Margin="10">
            <Label Content="Admin Folders:" Width="150"/>
            <ListBox x:Name="AdminFoldersList" Width="200" Height="100" Margin="0,0,10,0"/>
        </StackPanel>
        <StackPanel Grid.Row="6" Orientation="Horizontal" Margin="10">
            <Label Content="Status Output:" Width="150"/>
        </StackPanel>
        <StackPanel Grid.Row="7" Orientation="Horizontal" Grid.ColumnSpan="2" Margin="10,0,10,0">
            <TextBox x:Name="StatusTextBox" Height="100" Width="760" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" IsReadOnly="True" TextWrapping="Wrap"/>
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
$applicationGroupLabel = $window.FindName("ApplicationGroupLabel")
$applicationFolderListBox = $window.FindName("AdminFoldersList")
$userFolderBox = $window.FindName("UserFolder")
$queryButton = $window.FindName("QueryButton")
$copyButton = $window.FindName("CopyButton")
$applicationsDataGrid = $window.FindName("ApplicationsDataGrid")
$statusTextBox = $window.FindName("StatusTextBox")

# Define a function to append text to the status TextBox
function Add-Status {
    param (
        [string]$text
    )
    $statusTextBox.AppendText("$text`n")
    $statusTextBox.ScrollToEnd()
}

# Define the event handler for the query button click
$queryButton.Add_Click({
    try {
            # Clear the DataGrid and ListBox
            $applicationsDataGrid.Items.Clear()
            $applicationGroupListBox.Items.Clear()
            $adminFolderListBox.Items.Clear()
            $statusTextBox.Clear()

            # Get the source and destination controller addresses
            $sourceController = $sourceControllerBox.Text
            $destinationController = $destinationControllerBox.Text

            if ([string]::IsNullOrEmpty($sourceController) -or [string]::IsNullOrEmpty($destinationController)) {
                [System.Windows.MessageBox]::Show("Please enter both source and destination controller addresses.")
                return
            }

            $applicationGroupsLabel.Content = "$destinationController Application Groups"

            Add-Status "Querying applications from source controller $sourceController..."

            # Query the applications from the source controller
            try {
                $applications = Get-BrokerApplication -AdminAddress $sourceController

                # Populate the DataGrid with application names and enabled status
                foreach ($app in $applications) {
                    $applicationsDataGrid.Items.Add([PSCustomObject]@{
                        Name = $app.Name
                        Enabled = $app.Enabled
                    })
                }

                Add-Status "Successfully queried applications from source controller."
            } catch {
                [System.Windows.MessageBox]::Show("Failed to query applications from the source controller. Please check the address and try again.")
                Add-Status "Failed to query applications from source controller. Error: $_"
            }

            Add-Status "Querying application groups from destination controller $destinationController..."

            # Query the application groups from the destination controller
            try {
                $appGroups = Get-BrokerApplicationGroup -AdminAddress $destinationController

                # Populate the ListBox with application group names
                foreach ($group in $appGroups) {
                    $applicationGroupListBox.Items.Add($group.Name)
                }

                Add-Status "Successfully queried application groups from destination controller."
            } catch {
                [System.Windows.MessageBox]::Show("Failed to query application groups from the destination controller. Please check the address and try again.")
                Add-Status "Failed to query application groups from destination controller. Error: $_"
            }

            Add-Status "Querying admin folders from destination controller $destinationController..."

            # Query the admin folders from the destination controller
            try {
                $adminFolders = Get-BrokerAdminFolder -AdminAddress $destinationController

                # Populate the ListBox with admin folder names
                foreach ($folder in $adminFolders) {
                    $adminFolderListBox.Items.Add($folder.Name)
                }

                Add-Status "Successfully queried admin folders from destination controller."
            } catch {
                [System.Windows.MessageBox]::Show("Failed to query admin folders from the destination controller. Please check the address and try again.")
                Add-Status "Failed to query admin folders from destination controller. Error: $_"
            }
        } catch {
            [System.Windows.MessageBox]::Show("An error occurred while querying applications: $_")
            Add-Status "An error occurred while querying applications: $_"
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

    Add-Status "Copying applications to destination controller $destinationController in application group $selectedAppGroupName..."

    # Retrieve the application group object from the destination controller
    $selectedAppGroup = Get-BrokerApplicationGroup -AdminAddress $destinationController -Name $selectedAppGroupName

    if ($null -eq $selectedAppGroup) {
        [System.Windows.MessageBox]::Show("Selected application group not found on the destination controller.")
        Add-Status "Selected application group not found on the destination controller."
        return
    }

    # Get the satellite zone name
    $userFolder = $userFolderBox.Text

    # Get the selected applications
    $selectedApplications = $applicationsDataGrid.SelectedItems

    if ($selectedApplications.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Please select at least one application to copy.")
        Add-Status "No applications selected for copying."
        return
    }

    # Copy the selected applications to the destination controller within the specified application group and folder
    try {
        foreach ($selectedApp in $selectedApplications) {
            try {
                # Query the application details from the source controller
                $app = Get-BrokerApplication -AdminAddress $sourceController -Name $selectedApp.Name

                # Separate folder name from published name
                $appNameParts = $app.Name -split "\\"
                $appName = $appNameParts[-1]

                # Fetch the icon from the source controller
                $icon = Get-BrokerIcon -AdminAddress $sourceController -Uid $app.IconUid

                # Add the icon to the destination controller
                $newIcon = New-BrokerIcon -AdminAddress $destinationController -EncodedIconData $icon.EncodedIconData

                # Build the parameters dynamically, checking for null values
                $params = @{
                    AdminAddress = $destinationController
                    Name = $appName
                    ApplicationType = $app.ApplicationType
                    ApplicationGroup = $selectedAppGroupName
                    CommandLineExecutable = $app.CommandLineExecutable
                    CommandLineArguments = $app.CommandLineArguments
                    Enabled = $app.Enabled
                    PublishedName = $app.PublishedName
                    AdminFolder = $selectedAppGroupName
                    IconUid = $newIcon.Uid
                }

                if ($null -ne $app.DesktopGroup) {
                    $params["DesktopGroup"] = $app.DesktopGroup
                }

                if ($null -ne $app.Visibility) {
                    $params["Visibility"] = $app.Visibility
                }

                if ($null -ne $app.Description) {
                    $params["Description"] = $app.Description
                }

                # Log the parameters for debugging
                Add-Status "Copying application: $appName with parameters: $($params | Out-String)"

                # Create the application in the destination controller within the specified application group
                $newApp = New-BrokerApplication @params

                # Set the folder path for users if specified
                if (-not [string]::IsNullOrEmpty($userFolder)) {
                    Set-BrokerApplication -Name $newApp.Name -ClientFolder $userFolder
                }

                Add-Status "Successfully copied application: $appName"
            } catch {
                [System.Windows.MessageBox]::Show("Failed to copy application: $($selectedApp.Name). Error: $_")
                Add-Status "Failed to copy application: $($selectedApp.Name). Error: $_"
            }
        }

        Add-Status "Applications copied successfully."
    } catch {
        [System.Windows.MessageBox]::Show("Failed to copy applications to the destination controller. Error: $_")
        Add-Status "Failed to copy applications to the destination controller. Error: $_"
    }
})

# Show the window
try {
    $window.ShowDialog() | Out-Null
} catch {
    [System.Windows.MessageBox]::Show("An error occurred: $_")
    Add-Status "An error occurred: $_"
}
