Param( 
    [switch] $installOnly,
    [string] $appArtifactPath = "",
    [string] $platformArtifactPath = "",
    [string] $databasePath = "",
    [string] $licenseFilePath = "",
    [switch] $multitenant,
    [switch] $includeTestToolkit,
    [switch] $includeTestLibrariesOnly,
    [switch] $includeTestFrameworkOnly,
    [switch] $includePerformanceToolkit
)

Write-Host "Installing Business Central"
$startTime = [DateTime]::Now

$runPath = "c:\Run"
$myPath = Join-Path $runPath "my"
$navDvdPath = "C:\NAVDVD"

function Get-MyFilePath([string]$FileName)
{
    if ((Test-Path $myPath -PathType Container) -and (Test-Path (Join-Path $myPath $FileName) -PathType Leaf)) {
        (Join-Path $myPath $FileName)
    } else {
        (Join-Path $runPath $FileName)
    }
}

. (Get-MyFilePath "ServiceSettings.ps1")
. (Get-MyFilePath "HelperFunctions.ps1")

$installFromArtifacts = ($appArtifactPath -ne "" -and $platformArtifactPath -ne "")
if ($installFromArtifacts) {
    Write-Host "Installing from artifacts"
    $navDvdPath = $platformArtifactPath
}
else {
    Write-Host "Installing from DVD"
}

if (!(Test-Path $navDvdPath -PathType Container)) {
    Write-Error "DVD folder not found
You must map a folder on the host with the DVD content to $navDvdPath"
    exit 1
}

# start the SQL Server
Write-Host "Starting Local SQL Server"
Start-Service -Name $SqlBrowserServiceName -ErrorAction Ignore
Start-Service -Name $SqlWriterServiceName -ErrorAction Ignore
Start-Service -Name $SqlServiceName -ErrorAction Ignore

# start IIS services
Write-Host "Starting Internet Information Server"
Start-Service -name $IisServiceName

Write-Host "Copying Service Tier Files"
RoboCopy "$NavDvdPath\ServiceTier\Program Files" "C:\Program Files" /e /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
RoboCopy "$NavDvdPath\ServiceTier\System64Folder" "C:\Windows\System32" "NavSip.dll" /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null

Write-Host "Copying PowerShell Scripts"
RoboCopy "$navDvdPath\WindowsPowerShellScripts\Cloud\NAVAdministration" "$runPath\NAVAdministration" /e /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
if (Test-Path "$navDvdPath\WindowsPowerShellScripts\WebSearch") {
    RoboCopy "$navDvdPath\WindowsPowerShellScripts\WebSearch" "$runPath\WebSearch" /e /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
}

Start-Job -ScriptBlock { Param($NavDvdPath, $runPath, $appArtifactPath)

    function Get-ExistingDirectory([string]$pri1, [string]$pri2, [string]$folder)
    {
        if ($pri1 -and (Test-Path (Join-Path $pri1 $folder))) {
            (Get-Item (Join-Path $pri1 $folder)).FullName
        }
        elseif ($pri2 -and (Test-Path (Join-Path $pri2 $folder))) {
            (Get-Item (Join-Path $pri2 $folder)).FullName
        }
        else {
            ""
        }
    }

    Write-Host "Copying Web Client Files"
    RoboCopy "$NavDvdPath\WebClient\Microsoft Dynamics NAV" "C:\Program Files\Microsoft Dynamics NAV" /e /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
    
    if (Test-Path "$navDvdPath\RoleTailoredClient\program files\Microsoft Dynamics NAV\*\RoleTailored Client" -PathType Container) {
        Write-Host "Copying Client Files"
        RoboCopy "$navDvdPath\RoleTailoredClient\program files\Microsoft Dynamics NAV" "C:\Program Files (x86)\Microsoft Dynamics NAV" "*.dll" /e /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
        RoboCopy "$navDvdPath\RoleTailoredClient\program files\Microsoft Dynamics NAV" "C:\Program Files (x86)\Microsoft Dynamics NAV" "*.exe" /e /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
        RoboCopy "$navDvdPath\RoleTailoredClient\systemFolder" "C:\Windows\SysWow64" "NavSip.dll" /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
    }

    if (Test-Path "$navDvdPath\LegacyDlls\program files\Microsoft Dynamics NAV\*\RoleTailored Client" -PathType Container) {
        Write-Host "Copying Client Files"
        RoboCopy "$navDvdPath\LegacyDlls\program files\Microsoft Dynamics NAV" "C:\Program Files (x86)\Microsoft Dynamics NAV" "*.dll" /e /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
        RoboCopy "$navDvdPath\LegacyDlls\program files\Microsoft Dynamics NAV" "C:\Program Files (x86)\Microsoft Dynamics NAV" "*.exe" /e /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
        RoboCopy "$navDvdPath\LegacyDlls\systemFolder" "C:\Windows\SysWow64" "NavSip.dll" /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
    }
    
    Write-Host "Copying ModernDev Files"
    RoboCopy "$navDvdPath" "$runPath" "*.vsix" /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
    if (Test-Path "$navDvdPath\ModernDev\program files\Microsoft Dynamics NAV") {
        RoboCopy "$navDvdPath\ModernDev\program files\Microsoft Dynamics NAV" "C:\Program Files\Microsoft Dynamics NAV" /e /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
    }
    if ((Test-Path "$navDvdPath\ModernDev\program files\Microsoft Dynamics NAV\*\*\*.vsix") -and !(Test-Path (Join-Path $runPath "*.vsix"))) {
        Copy-Item -Path "$navDvdPath\ModernDev\program files\Microsoft Dynamics NAV\*\*\*.vsix" -Destination $runPath -Force
    }
    
    Write-Host "Copying additional files"
    "ConfigurationPackages","Test Assemblies","TestToolKit","UpgradeToolKit","Extensions","Applications","Applications.*" | % {
        $dir = Get-ExistingDirectory -pri1 $appArtifactPath -pri2 $navDvdPath -folder $_
        if ($dir)
        {
            $name = [System.IO.Path]::GetFileName($dir)
            Write-Host "Copying $name"
            RoboCopy "$dir" "C:\$name" /e /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
        }
    }

    $mockAssembliesPath = "C:\Test Assemblies\Mock Assemblies"
    if (Test-Path $mockAssembliesPath) {
        $serviceTierAddInsFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service\Add-ins").FullName
        if (!(Test-Path (Join-Path $serviceTierAddInsFolder "Mock Assemblies"))) {
            new-item -itemtype symboliclink -path $serviceTierAddInsFolder -name "Mock Assemblies" -value $mockAssembliesPath | Out-Null
        }
    }

    $installersFolder = Get-ExistingDirectory -pri1 $appArtifactPath -pri2 $navDvdPath -folder "Intallers"
    if ($installersFolder) {
        Get-ChildItem $installersFolder -Recurse | Where-Object { $_.PSIsContainer } | % {
            Get-ChildItem $_.FullName | Where-Object { $_.PSIsContainer } | % {
                $dir = $_.FullName
                Get-ChildItem (Join-Path $dir "*.msi") | % {
                    $filepath = $_.FullName
                    if ($filepath.Contains('\WebHelp\')) {
                        Write-Host "Skipping $filepath"
                    } else {
                        Write-Host "Installing $filepath"
                        Start-Process -FilePath $filepath -WorkingDirectory $dir -ArgumentList "/qn /norestart" -Wait
                    }
                }
            }
        }
    }

} -ArgumentList $navDvdPath, $runPath, $appArtifactPath | Out-Null

Write-Host "Copying dependencies"
$serviceTierFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName
# Due to dependencies from finsql.exe, we have to copy hlink.dll and ReportBuilder in place inside the container
Copy-Item -Path (Join-Path $runPath 'Install\hlink.dll') -Destination (Join-Path $serviceTierFolder 'hlink.dll')
Copy-Item -Path (Join-Path $runPath 'Install\t2embed.dll') -Destination "c:\windows\system32\t2embed.dll"
Copy-Item -Path (Join-Path $runPath 'Install\Microsoft.IdentityModel.dll') -Destination (Join-Path $serviceTierFolder 'Microsoft.IdentityModel.dll')

Write-Host "Copying ReportBuilder"
Start-Job -ScriptBlock { Param($runPath)
    $reportBuilderPath = "C:\Program Files (x86)\ReportBuilder"
    $reportBuilderSrc = Join-Path $runPath 'Install\ReportBuilder2016'
    Move-Item -Path $reportBuilderSrc -Destination $reportBuilderPath -Force
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction Ignore | Out-null
    New-Item "HKCR:\MSReportBuilder_ReportFile_32" -itemtype Directory -ErrorAction Ignore | Out-null
    New-Item "HKCR:\MSReportBuilder_ReportFile_32\shell" -itemtype Directory -ErrorAction Ignore | Out-null
    New-Item "HKCR:\MSReportBuilder_ReportFile_32\shell\Open" -itemtype Directory -ErrorAction Ignore | Out-null
    New-Item "HKCR:\MSReportBuilder_ReportFile_32\shell\Open\command" -itemtype Directory -ErrorAction Ignore | Out-null
    Set-Item "HKCR:\MSReportBuilder_ReportFile_32\shell\Open\command" -value "$reportBuilderPath\MSReportBuilder.exe ""%1"""
} -ArgumentList $runPath | Out-Null

Write-Host "Importing PowerShell Modules"
Import-Module "$serviceTierFolder\Microsoft.Dynamics.Nav.Management.psm1"

$databaseServer = "localhost"
$databaseInstance = "SQLEXPRESS"
if ($multitenant) {
    $databaseName = "tenant"
}
else {
    $databaseName = "CRONUS"
}
$skipDb = $false

# Restore CRONUS Demo database to databases folder
if ($databasePath) {

    # Restore database
    $databaseFolder = "c:\databases"
    New-Item -Path $databaseFolder -itemtype Directory -ErrorAction Ignore | Out-Null

    Write-Host "Determining Database Collation from $databasePath"
    $collation = (Invoke-Sqlcmd -ServerInstance localhost\SQLEXPRESS -ConnectionTimeout 300 -QueryTimeOut 300 "RESTORE HEADERONLY FROM DISK = '$databasePath'").Collation

    SetDatabaseServerCollation -collation $collation

    Write-Host "Restoring CRONUS Demo Database"
    New-NAVDatabase -DatabaseServer $databaseServer `
                    -DatabaseInstance $databaseInstance `
                    -DatabaseName "$databaseName" `
                    -FilePath "$databasePath" `
                    -DestinationPath "$databaseFolder" `
                    -Timeout 300 | Out-Null
}
elseif (Test-Path "$navDvdPath\SQLDemoDatabase" -PathType Container) {
    $bak = (Get-ChildItem -Path "$navDvdPath\SQLDemoDatabase\CommonAppData\Microsoft\Microsoft Dynamics NAV\*\Database\*.bak")[0]
    
    # Restore database
    $databaseFolder = "c:\databases"
    New-Item -Path $databaseFolder -itemtype Directory -ErrorAction Ignore | Out-Null
    $databaseFile = $bak.FullName

    Write-Host "Determining Database Collation"
    $collation = (Invoke-Sqlcmd -ServerInstance localhost\SQLEXPRESS -ConnectionTimeout 300 -QueryTimeOut 300 "RESTORE HEADERONLY FROM DISK = '$databaseFile'").Collation

    SetDatabaseServerCollation -collation $collation

    Write-Host "Restoring CRONUS Demo Database"
    New-NAVDatabase -DatabaseServer $databaseServer `
                    -DatabaseInstance $databaseInstance `
                    -DatabaseName "$databaseName" `
                    -FilePath "$databaseFile" `
                    -DestinationPath "$databaseFolder" `
                    -Timeout 300 | Out-Null
}
elseif (Test-Path "$navDvdPath\databases") {

    $multitenant = $false
    $databaseName = "CRONUS"

    $collation = Get-Content -Path "$navDvdPath\databases\Collation.txt" -ErrorAction SilentlyContinue
    if ($collation) {
        SetDatabaseServerCollation -collation $collation
    }

    Write-Host "Copying Cronus database"
    RoboCopy "$navDvdPath\databases" "c:\databases" /e /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
    $mdf = (Get-Item "C:\databases\*.mdf").FullName
    $ldf = (Get-Item "C:\databases\*.ldf").FullName
    $attachcmd = @"
USE [master]
GO
CREATE DATABASE [$databaseName] ON (FILENAME = '$mdf'),(FILENAME = '$ldf') FOR ATTACH
GO
"@
    Invoke-Sqlcmd -ServerInstance localhost\SQLEXPRESS -QueryTimeOut 0 -ea Stop -Query $attachcmd
}
else {
    $skipDb = $true
    Write-Host "Skipping restore of Cronus database"
}

$databaseName = "CRONUS"

if ($multitenant -and !$SkipDb) {
    Write-Host "Exporting Application to $DatabaseName"
    Invoke-sqlcmd -serverinstance "$DatabaseServer\$DatabaseInstance" -Database tenant -query 'CREATE USER "NT AUTHORITY\SYSTEM" FOR LOGIN "NT AUTHORITY\SYSTEM";'
    Export-NAVApplication -DatabaseServer $DatabaseServer -DatabaseInstance $DatabaseInstance -DatabaseName "tenant" -DestinationDatabaseName $databaseName -Force -ServiceAccount 'NT AUTHORITY\SYSTEM' | Out-Null
    Write-Host "Removing Application from tenant"
    Remove-NAVApplication -DatabaseServer $DatabaseServer -DatabaseInstance $DatabaseInstance -DatabaseName "tenant" -Force | Out-Null
}

Write-Host "Modifying Business Central Service Tier Config File for Docker"
$CustomConfigFile =  Join-Path $serviceTierFolder "CustomSettings.config"
$CustomConfig = [xml](Get-Content $CustomConfigFile)
$customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value = $databaseServer
$customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value = $databaseInstance
$customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value = "$databaseName"
$customConfig.SelectSingleNode("//appSettings/add[@key='ServerInstance']").Value = "$serverInstance"
$customConfig.SelectSingleNode("//appSettings/add[@key='ManagementServicesPort']").Value = "7045"
$customConfig.SelectSingleNode("//appSettings/add[@key='ClientServicesPort']").Value = "7046"
$customConfig.SelectSingleNode("//appSettings/add[@key='SOAPServicesPort']").Value = "7047"
$customConfig.SelectSingleNode("//appSettings/add[@key='ODataServicesPort']").Value = "7048"
$customConfig.SelectSingleNode("//appSettings/add[@key='DeveloperServicesPort']").Value = "7049"
$customConfig.SelectSingleNode("//appSettings/add[@key='DefaultClient']").Value = "Web"
$customConfig.SelectSingleNode("//appSettings/add[@key='Multitenant']").Value = "$multitenant"
$taskSchedulerKeyExists = ($customConfig.SelectSingleNode("//appSettings/add[@key='EnableTaskScheduler']") -ne $null)
if ($taskSchedulerKeyExists) {
    $customConfig.SelectSingleNode("//appSettings/add[@key='EnableTaskScheduler']").Value = "false"
}
$CustomConfig.Save($CustomConfigFile)

# Creating Business Central Service
Write-Host "Creating Business Central Service Tier"
$serviceCredentials = New-Object System.Management.Automation.PSCredential ("NT AUTHORITY\SYSTEM", (new-object System.Security.SecureString))
$serverFile = "$serviceTierFolder\Microsoft.Dynamics.Nav.Server.exe"
$configFile = "$serviceTierFolder\Microsoft.Dynamics.Nav.Server.exe.config"
New-Service -Name $NavServiceName -BinaryPathName """$serverFile"" `$$ServerInstance /config ""$configFile""" -DisplayName "Dynamics 365 Business Central Server [$ServerInstance]" -Description "$serverInstance" -StartupType manual -Credential $serviceCredentials -DependsOn @("HTTP") | Out-Null

$serverVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($serverFile)
$versionFolder = ("{0}{1}" -f $serverVersion.FileMajorPart,$serverVersion.FileMinorPart)
$registryPath = "HKLM:\SOFTWARE\Microsoft\Microsoft Dynamics NAV\$versionFolder\Service"
New-Item -Path $registryPath -Force | Out-Null
New-ItemProperty -Path $registryPath -Name 'Path' -Value "$serviceTierFolder\" -Force | Out-Null
New-ItemProperty -Path $registryPath -Name 'Installed' -Value 1 -Force | Out-Null

Install-NAVSipCryptoProvider

Get-Job | Wait-Job | Receive-Job | Out-Host

$installApps = @()
if ($includeTestToolkit) {
    $installApps += GetTestToolkitApps -includeTestLibrariesOnly:$includeTestLibrariesOnly -includeTestFrameworkOnly:$includeTestFrameworkOnly -includePerformanceToolkit:$includePerformanceToolkit
}

if (!$skipDb -and ($multitenant -or $installOnly -or $licenseFilePath -ne "" -or ($installApps) -or (Test-Path "$navDvdPath\SQLDemoDatabase\CommonAppData\Microsoft\Microsoft Dynamics NAV\*\Database\cronus.flf"))) {
    Write-Host "Starting Business Central Service Tier"
    Start-Service -Name $NavServiceName -WarningAction Ignore

    if ($licenseFilePath -ne "") {
        Write-Host "Importing license file"
        Import-NAVServerLicense -LicenseFile $licenseFilePath -ServerInstance $ServerInstance -Database NavDatabase -WarningAction SilentlyContinue
    }
    elseif (Test-Path "$navDvdPath\SQLDemoDatabase\CommonAppData\Microsoft\Microsoft Dynamics NAV\*\Database\cronus.flf") {
        Write-Host "Importing CRONUS license file"
        $licensefile = (Get-Item -Path "$navDvdPath\SQLDemoDatabase\CommonAppData\Microsoft\Microsoft Dynamics NAV\*\Database\cronus.flf").FullName
        Import-NAVServerLicense -LicenseFile $licensefile -ServerInstance $ServerInstance -Database NavDatabase -WarningAction SilentlyContinue
    }

    if ($multitenant) {
        Copy-NavDatabase -SourceDatabaseName "tenant" -DestinationDatabaseName "default"
        Write-Host "Mounting tenant database"
        Mount-NavDatabase -ServerInstance $ServerInstance -TenantId "default" -DatabaseName "default"
        $mtstartTime = [DateTime]::Now
        while ([DateTime]::Now.Subtract($mtstartTime).TotalSeconds -le 60) {
            $tenantInfo = Get-NAVTenant -ServerInstance $ServerInstance -Tenant "default"
            if ($tenantInfo.State -eq "Operational") { break }
            Start-Sleep -Seconds 1
        }
        Write-Host "Tenant is $($TenantInfo.State)"
    }

    if ($installApps) {
        $serviceTierFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName
        if (Test-Path "$serviceTierFolder\Microsoft.Dynamics.Nav.Apps.Management.psd1") {
            Import-Module "$serviceTierFolder\Microsoft.Dynamics.Nav.Apps.Management.psd1"
            $installApps | % {
                $appFile = $_
                Write-Host "Publishing $appFile"
                Publish-NavApp -ServerInstance $ServerInstance -Path $appFile -SkipVerification
    
                $navAppInfo = Get-NAVAppInfo -Path $appFile
                $appPublisher = $navAppInfo.Publisher
                $appName = $navAppInfo.Name
                $appVersion = $navAppInfo.Version
    
                Write-Host "Synchronizing $appName"
                Sync-NavTenant -ServerInstance $ServerInstance -Tenant default -Force
                Sync-NavApp -ServerInstance $ServerInstance -Publisher $appPublisher -Name $appName -Version $appVersion -Tenant default -Mode ForceSync -force -WarningAction Ignore

                Write-Host "Installing $appName"
                Install-NavApp -ServerInstance $ServerInstance -Publisher $appPublisher -Name $appName -Version $appVersion -Tenant default
            }
        }
    }
    
    Write-Host "Stopping Business Central Service Tier"
    Stop-Service -Name $NavServiceName -WarningAction Ignore
}

$timespend = [Math]::Round([DateTime]::Now.Subtract($startTime).Totalseconds)
Write-Host "Installation took $timespend seconds"
Write-Host "Installation complete"
