<# 

This script will read an Excel file with columns:
1. Broker Application Name
2. AD Group Name

... and use them to configure a Broker Application (XenApp application) to set UserFilterEnabled as $true, then read the AD Group that can contain nested groups to add the users to the AssociatedUserNames setting of the application to limit visibility.

Download the following before running the script:

Virtual Apps and Desktops Remote PowerShell SDK
https://www.citrix.com/downloads/citrix-cloud/product-software/xenapp-and-xendesktop-service.html

#>

# Add the required Citrix cmdlets and authenticate
Add-PSSnapin Citrix*
asnp Citrix*
Get-XDAuthentication

# Import the required Excel module to read the Excel file
Install-Module -Name ImportExcel -Force
Import-Module ImportExcel

# Read the Citrix Apps to AD Group Mappings in Excel spreadsheet
$excelFilePath = "C:\scripts\"
$excelFileName = "Citrix App to AD Group Mapping.xlsx"
$worksheetName = "Test" # Change this to the actual name of your worksheet
$citrixAppData = Import-Excel -Path $excelFilePath$excelFileName -WorksheetName $worksheetName

# Define Function for retriving users from group

function Get-AllADGroupMembers {
    param (
        [Parameter(Mandatory = $true)]
        $GroupName
    )

    # Place results into an array to catch scenario where there is only one member
    $groupMembers = @(Get-ADGroupMember -Identity $GroupName)

    foreach ($member in $groupMembers) {
        if ($member.objectClass -eq "group") {
            # Use the Get-allADGroupMembers function to recursively get any nested group objects
            $nestedGroupMembers = Get-AllADGroupMembers $member.name
            $groupMembers += $nestedGroupMembers
        }
    }
    # Use Where-Object to only select users and Sort-Object to remove duplicate users
    return ($groupMembers | Where-Object { $_.objectClass -eq "user" } | Sort-Object -Unique)
    <# Write-Host $groupMembers.name
    Write-Host $groupMembers.objectClass
    Write-Host ""#>
}

##### Start looping through Broker Applications from Excel #####

foreach ($eachCitrixApp in $citrixAppData) {
    # Read Excel file rows for each column
    $brokerApplicationName = $eachCitrixApp."Broker Application Name"
    #$brokerApplicationName
    $adGroupName = $eachCitrixApp."AD Group Name"
    #$adGroupName

    # Enable filter for the Broker Application and include trimming any leading and trailing whitespaces in case the Excel content has spaces
    Set-BrokerApplication -Name $brokerApplicationName.Trim() -UserFilterEnabled $true

    # Get groups and users from group and include trimming any leading and trailing whitespaces in case the Excel content has spaces
    $groupUsers = Get-AllADGroupMembers $adGroupName
    
    # Add found users to Broker Application and include trimming any leading and trailing whitespaces in case the Excel content has spaces
    foreach ($user in $groupUsers) {
        Add-BrokerUser -Application $brokerApplicationName.Trim() -Name $user.SamAccountName
        Write-Host "Adding User: "$user.SamAccountName
    }
} 
