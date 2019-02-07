$bacpacfilepath = "C:\Users\stefano\OneDrive\BACPAC\d365bconprem190207.bacpac";
$bacpacname = "d365bconprem190207.bacpac";
$resourcegroup = "d365bc190207rg"
$location = "West Europe"
$servername = "d365bc190207srv"
$serverversion = "12.0"
$databasename = "d365bc190207";
$firewallrulename = "d365bc190207fwrule";
$localIP = 'Your local machine IP address';
$subscription = "Your Azure Subscription Name"
$storageaccountname = "d365bc190207st"
$storagecontainer = "dbcontainer";

#Login to Azure account
Add-AzureRmAccount -Subscription $subscription


#Create a resource group
New-AzureRmResourceGroup -Name $resourcegroup -Location $location

#Create Azure SQL database server
#Stores the Azure SQL credentials (specify your Azure SQL Server Login and Password)
$credential = Get-Credential
New-AzureRmSqlServer -ResourceGroupName $resourcegroup -Location $location -ServerName $servername -ServerVersion $serverversion -SqlAdministratorCredentials $credential

#Firewall rules settings
New-AzureRmSqlServerFirewallRule -ResourceGroupName $resourcegroup -ServerName $servername -FirewallRuleName $firewallrulename -StartIpAddress $localIP -EndIpAddress $localIP

#Create Storage Account
Select-AzureSubscription -SubscriptionName $subscription
New-AzureStorageAccount -StorageAccountName $storageaccountname -Location $location

#Create a container in the Storage Account. Permissions off means that only the owner of the container has access to it.
Set-AzureSubscription -CurrentStorageAccountName $storageaccountname -SubscriptionName $subscription
New-AzureStorageContainer -Name $storagecontainer -Permission Off

#Upload the bacpac file to the container
Set-AzureStorageBlobContent -Container $storagecontainer -File $bacpacfilepath

#Import the bacpac to create a Database in Azure SQL Server:
# 1) Retrieves the Azure Storage Key
$primarykey=(Get-AzureStorageKey -StorageAccountName $storageaccountname).Primary
#2) Retrieves the URI of the blob file
$StorageUri=(Get-AzureStorageBlob -blob $bacpacname -Container $storagecontainer).ICloudBlob.uri.AbsoluteUri
#3) Import the bacpac file on Azure SQL (we connect using a StorageAccessKey)
$importRequest = New-AzureRmSqlDatabaseImport –ResourceGroupName $resourcegroup –ServerName $servername –DatabaseName $databasename –StorageKeytype "StorageAccessKey" –StorageKey $primarykey -StorageUri $StorageUri –AdministratorLogin $credential.UserName –AdministratorLoginPassword $credential.Password –Edition Standard –ServiceObjectiveName S0 -DatabaseMaxSizeBytes 50000

#Check the import status
$importStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
[Console]::Write("Importing")
while ($importStatus.Status -eq "InProgress")
{
    $importStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
    [Console]::Write(".")
    Start-Sleep -s 10
}
[Console]::WriteLine("")
$importStatus
