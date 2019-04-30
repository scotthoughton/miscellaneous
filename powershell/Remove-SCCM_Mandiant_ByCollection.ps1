#Set Paths
$path = (Split-Path -Path ((Get-Variable -Name MyInvocation).Value).MyCommand.Path)
$scriptName =  $MyInvocation.MyCommand.Name
if(!(Test-Path "$path\Logs")){ New-Item "$path\Logs" -type directory }
if(!(Test-Path "$path\CSVs")){ New-Item "$path\CSVs" -type directory }
$dateTime = Get-Date -Format  yyyy-MM-dd_HHmm
$Logfile = "$path\Logs\$scriptName" + "-Log"+ $dateTime + ".txt"
$transcriptPath = "$path\Logs\$scriptName" + "Transcript"+ $dateTime + ".txt"

Start-Transcript -Path $transcriptPath
#Module Requires SCCM Client To Be Installed - Solves for 32bit OS
if([Environment]::Is64BitOperatingSystem){
    if((Test-Path "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\")){
        import-module "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
    }
    else{
        Write-Output "SCCM Module Not Installed"
        Pause
        Exit
    }
}
else{
    if((Test-Path "C:\Program Files\Microsoft Configuration Manager\AdminConsole\bin\")){
        import-module "C:\Program Files\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
    }
    else{
        Write-Output "SCCM Module Not Installed"
        Pause
        Exit
    }
}
cd CAS:
Function Start-Deploy([string]$ApplicationName,[string]$CollectionName){
Start-CMApplicationDeployment -CollectionName "$CollectionName" -Name "$ApplicationName" `
-DeployAction "Uninstall" -DeployPurpose "Require" -UserNotification "DisplaySoftwareCenterOnly" `
-PreDeploy $True -RebootOutsideServiceWindow $false -SendWakeUpPacket $false -UseMeteredNetwork $false
}
#All MW
$collections = Get-CMDeviceCollection -Name "MW:*" | Select Name
$app = "MANDIANT Intelligent Response Agent (Uninstall Only)"
foreach($collection in $collections){
    Start-Deploy -ApplicationName $app -CollectionName $collection.Name
}
Stop-Transcript