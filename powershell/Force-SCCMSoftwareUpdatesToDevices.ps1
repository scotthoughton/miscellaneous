#Requires -version 5
param(
    [String[]]$Computers
)
#Set Paths
$path = (Split-Path -Path ((Get-Variable -Name MyInvocation).Value).MyCommand.Path)
$scriptName =  $MyInvocation.MyCommand.Name
if(!(Test-Path "$path\Logs")){ New-Item "$path\Logs" -type directory }
if(!(Test-Path "$path\CSVs")){ New-Item "$path\CSVs" -type directory }
$dateTime = Get-Date -Format  yyyy-MM-dd_HHmm
$Logfile = "$path\Logs\$scriptName" + "-Log"+ $dateTime + ".txt"
$transcriptPath = "$path\Logs\$scriptName" + "Transcript"+ $dateTime + ".txt"

function Show-TextBox{

    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 

$objForm = New-Object System.Windows.Forms.Form 
$objForm.Text = "Computer Entry Form"
$objForm.Size = New-Object System.Drawing.Size(300,300) 
$objForm.StartPosition = "CenterScreen"

$objForm.KeyPreview = $True
$objForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
    {$objForm.Close()}})

$OKButton = New-Object System.Windows.Forms.Button
$OKButton.Location = New-Object System.Drawing.Size(75,225)
$OKButton.Size = New-Object System.Drawing.Size(75,23)
$OKButton.Text = "OK"
$OKButton.Add_Click({$x=$objTextBox.Text;$objForm.Close()})
$objForm.Controls.Add($OKButton)

$CancelButton = New-Object System.Windows.Forms.Button
$CancelButton.Location = New-Object System.Drawing.Size(150,225)
$CancelButton.Size = New-Object System.Drawing.Size(75,23)
$CancelButton.Text = "Cancel"
$CancelButton.Add_Click({$objForm.Close()})
$objForm.Controls.Add($CancelButton)

$objLabel = New-Object System.Windows.Forms.Label
$objLabel.Location = New-Object System.Drawing.Size(10,20) 
$objLabel.Size = New-Object System.Drawing.Size(280,20) 
$objLabel.Text = "Please Computer Names, 1 Per Line:"
$objForm.Controls.Add($objLabel) 

$objTextBox = New-Object System.Windows.Forms.TextBox 
$objTextBox.Multiline = $True
$objTextBox.AcceptsReturn = $True
$objTextBox.Location = New-Object System.Drawing.Size(10,40) 
$objTextBox.Size = New-Object System.Drawing.Size(260,175) 
$objForm.Controls.Add($objTextBox) 

$objForm.Topmost = $True

$objForm.Add_Shown({$objForm.Activate()})
[void] $objForm.ShowDialog()
[String[]]$x
$x = $objTextBox.Text.Split("`r`n")
$x = $x.Trim(" ")
$x = $x.Trim()
$textList = @()
$x | %{if(![string]::IsNullOrEmpty($_) -and $_ -ne "" -and $_ -ne " " -and $_ -ne "`r`n"){ $textList += $_ }}
Return $textList
}

Start-Transcript -Path $transcriptPath

if($Computers -eq $null -or $Computers -eq "" -or $Computers -eq " "){$Computers = Show-TextBox}
foreach($Computer in $Computers){
[string]$server = $Computer
if(![string]::IsNullOrEmpty($server) -and $server -ne "" -and $server -ne " " -and $server -ne "`r`n"){
$jobName = $server + "Job"
Start-Job -name $jobName -ArgumentList $server,$Logfile -ScriptBlock{
    #functions for Job
    $waitingseconds = 120
Function LogWrite
{
   Param ([string]$logstring)

   Add-content $Logfile -value $logstring
   Write-Output "$logstring"
}
function Update-SCCMClientStatus([string]$Computer){
    #Trigger SCCM Update Scan and wait a little
([wmiclass]"\\$Computer\ROOT\ccm:SMS_Client").TriggerSchedule('{00000000-0000-0000-0000-000000000113}') |Out-Null
Start-Sleep -Seconds $(1*$waitingseconds)
}
function Restart-WhenPendingReboot([string]$Computer){
$CMIsRebootPending = (gwmi -ComputerName $Computer -Namespace "root\ccm\clientsdk" -Class 'CCM_ClientUtilities' -list).DetermineIfRebootPending().RebootPending
    If ($CMIsRebootPending) { 
        LogWrite "INFO   `t$Computer has a pending reboot and the server will reboot."            
    }
    else{
        LogWrite "INFO   `t$Computerr is not a pending reboot."
    }
    return $CMIsRebootPending
}
function Install-WindowsUpdates([string]$Computer){
    [System.Management.ManagementObject[]] $CMMissingUpdates = @(get-wmiobject -query "SELECT * FROM CCM_SoftwareUpdate WHERE ComplianceState = '0'" -ComputerName $Computer -Namespace "root\ccm\clientsdk")
If ($CMMissingUpdates.count) {
    LogWrite "INFO   `t$Computer The number of missing updates is $($CMMissingUpdates.count)"
    $CMInstallMissingUpdates = (Get-WmiObject -ComputerName $Computer -Namespace "root\ccm\clientsdk" -Class 'CCM_SoftwareUpdatesManager' -List).InstallUpdates($CMMissingUpdates)
 
    Do {
        Start-Sleep $(2*$waitingseconds)
        [array]$CMInstallPendingUpdates = @(get-wmiobject -query "SELECT * FROM CCM_SoftwareUpdate WHERE EvaluationState = 6 or EvaluationState = 7" -ComputerName $Computer -Namespace "root\ccm\clientsdk")
        LogWrite "INFO   `t The number of pending updates for installation is: $($CMInstallPendingUpdates.count)"
    } While (($CMInstallPendingUpdates.count -ne 0) -and ((New-TimeSpan -Start $StartTime -End $(Get-Date)) -lt "00:45:00"))
    If (Restart-WhenPendingReboot($Computer)) {
        (Get-WmiObject -ComputerName $Computer -Namespace "root\ccm\clientsdk" -Class 'CCM_ClientUtilities' -list).RestartComputer()
        LogWrite "Restarting $server"
        LogWrite "Waiting for $server to come back online"
        Start-Sleep $(2*$waitingseconds)
    }
} ELSE {
    LogWrite "INFO   `tThere are no missing updates."
}
}

    LogWrite "Updating SCCM Client on $server"
    Update-SCCMClientStatus -Computer $server
    LogWrite "Checking for Pending Reboots on $server"
    If (Restart-WhenPendingReboot) {
        (Get-WmiObject -ComputerName $server -Namespace 'ROOT\ccm\ClientSDK' -Class 'CCM_ClientUtilities' -list).RestartComputer()
        LogWrite "Restarting $server"
        LogWrite "Waiting for $server to come back online"
        Start-Sleep $(2*$waitingseconds)
        LogWrite "Updating SCCM Client on $server"
        Update-SCCMClientStatus -Computer $server
    }
    Install-WindowsUpdates -Computer $server
    Update-SCCMClientStatus -Computer $server
    Install-WindowsUpdates -Computer $server
}
}
}
#Wait for all jobs
Get-Job | Wait-Job
 
#Get all job results
Get-Job | Receive-Job | Out-GridView
Stop-Transcript
pause
