Import-Module BitsTransfer
$prefix=Read-Host ″Enter POC Prefix″
Write-Host '1 = ORB-US-SQL1\SQL2012'
Write-Host '2 = ORB-US-SQL1\SQLSERVER2016'
switch(read-host "Select Instance where iServerDB is hosted"){
1 {$ServerName = 'ORB-US-SQL1\SQL2012'}
2 {$ServerName = 'ORB-US-SQL1\SQLSERVER2016'}
default {$ServerName = 'ORB-US-SQL1\SQL2012'}
}
# IIS/API
$dirName = "E:\Portal\$prefix.APIv3.0.2"
$Binding = "*:80:"+"$Prefix"+"api.orbuscloud.com"
#create API Folder
if(-not (test-path $dirName)) {
    md $dirName | out-null
} else {
    write-host "$dirName already exists!"
}

#Path to API files Template (E:\Portal\iServer API 3.0.2) and execute copy
$source1='E:\Portal\iServer API 3.0.2\*'
Copy-Item -path $source1 -destination $dirName -recurse

# replace contents of copied API files
$current = 'XYZ'
$APIwebConfig = "$dirName\Web.config"
$doc = (Get-Content $APIwebConfig) -as [Xml]
$dbconnectiondetails = $doc.SelectSingleNode('configuration/connectionStrings/add')
$dbconnectiondetails.setattribute("connectionString","Data Source=$ServerName;Initial Catalog=$prefix-iServerDB;User Id=portaluser;Password=portaluser;")
$doc.save("$dirName\Web.config")

Write-Host 'API config files updated'

# create Website in IIS
Import-Module WebAdministration
$iisAppPoolName = "$Prefix.APIv3.0.2"
$iisAppPoolDotNetVersion = "v4.0"
$iisAppName = "$Prefix.APIv3.0.2"
$directoryPath = "$dirName"

#navigate to the app pools root
cd IIS:\AppPools\

#check if the app pool exists
if (!(Test-Path $iisAppPoolName -pathType container))
{
    #create the app pool
    $appPool = New-Item $iisAppPoolName
    $appPool | Set-ItemProperty -Name "managedRuntimeVersion" -Value $iisAppPoolDotNetVersion
}

#navigate to the sites root
cd IIS:\Sites\

#check if the site exists
if (Test-Path $iisAppName -pathType container)
{
    return
}

#create the Website
$iisApp = New-Item $iisAppName -bindings @{protocol="http";bindingInformation=$Binding} -physicalPath $directoryPath
$iisApp | Set-ItemProperty -Name "applicationPool" -Value $iisAppPoolName
#ConvertTo-WebApplication -ApplicationPool "$iisAppPoolName" -PSPath "IIS:\Sites\$Prefix.Portal\Service"

#Set-WebConfigurationProperty -filter "/system.webServer/security/authentication/windowsAuthentication" -Name Enabled -Value True -PSPath "IIS:\" -location $iisAppName
Set-WebConfigurationProperty -Filter "/system.webServer/security/authentication/anonymousAuthentication" -Name Enabled -Value True -PSPath "IIS:\" -location $iisAppName

#Set-WebConfigurationProperty -filter "/system.webServer/security/authentication/windowsAuthentication" -Name Enabled -Value False -PSPath "IIS:\" -location $iisAppName/Service
#Set-WebConfigurationProperty -Filter "/system.webServer/security/authentication/anonymousAuthentication" -Name Enabled -Value True -PSPath "IIS:\" -location $iisAppName/Service

Write-Host 'API Done' -foregroundColor Green
