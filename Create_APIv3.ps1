Import-Module BitsTransfer
$prefix=Read-Host ″Enter POC Prefix″
Write-Host '1 = ORB-EMEA-SQL1\SQL2012'
Write-Host '2 = ORB-EMEA-SQL1\SQL2016'
switch(read-host "Select Instance"){
1 {$ServerName = 'ORB-EMEA-SQL1\SQL2012'}
2 {$ServerName = 'ORB-EMEA-SQL1\SQL2016'}
default {$ServerName = 'ORB-EMEA-SQL1\SQL2012'}
}
# IIS/PORTAL
$dirName = "F:\Portal\$prefix.APIv3.0.1"
#$serviceDirName = "F:\Portal\$prefix\Service"
$Binding = "*:80:"+"$Prefix"+"api.orbuscloud.com"
#create Portal Folder
if(-not (test-path $dirName)) {
    md $dirName | out-null
} else {
    write-host "$dirName already exists!"
}

#Path to Portal files Template (F:\Portal\iServer API 3.0.1) and execute copy
$source1='F:\Portal\iServer API 3.0.1\*'
Copy-Item -path $source1 -destination $dirName -recurse

# replace contents of copied Portal files
$current = 'XYZ'
#(get-content "$dirName\API\Web.config").replace("$current", "$prefix") | set-content $dirName\API\Web.config
#(get-content "$dirName\Service\db.config").replace("$current", "$prefix") | set-content $dirName\Service\db.config
$APIwebConfig = "$dirName\API\Web.config"
$doc = (Get-Content $APIwebConfig) -as [Xml]
$dbconnectiondetails = $doc.SelectSingleNode('configuration/connectionStrings/add')
$dbconnectiondetails.setattribute("connectionString","Data Source=$ServerName;Initial Catalog=$prefix-iServerDB;User Id=portaluser;Password=portaluser;")
$doc.save("$dirName\API\Web.config")

Write-Host 'API config files updated'

# create Website in IIS
Import-Module WebAdministration
$iisAppPoolName = "$Prefix.APIv3.0.1"
$iisAppPoolDotNetVersion = "v4.0"
$iisAppName = "$Prefix.APIv3.0.1"
$directoryPath = "$dirName\API"
#$serviceDirName = "$dirName/Service"

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