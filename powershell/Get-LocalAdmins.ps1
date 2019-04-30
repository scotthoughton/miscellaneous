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

Start-Transcript -Path $transcriptPath
Import-Module ActiveDirectory
$usernames = Get-ADGroupMember "Windows Server Admins" | Select -Property SamAccountName
function Show-TextBox{
#Version 2.1
    param(
        [string]$formText = "Data Entry Form",
        [string]$labelText = "Please enter the information in the space below:",
        [bool]$multiLineText = $true
    )
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 

$objForm = New-Object System.Windows.Forms.Form 
$objForm.Text = $formText
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
$objLabel.Text = $labelText
$objForm.Controls.Add($objLabel) 

$objTextBox = New-Object System.Windows.Forms.TextBox 
$objTextBox.Multiline = $multiLineText
$objTextBox.AcceptsReturn = $True
$objTextBox.Location = New-Object System.Drawing.Size(10,40) 
$objTextBox.Size = New-Object System.Drawing.Size(260,175) 
$objForm.Controls.Add($objTextBox) 

$objForm.Topmost = $True

$objForm.Add_Shown({$objForm.Activate()})
[void] $objForm.ShowDialog()
if($multiLineText){
[String[]]$x = ""
$x = $objTextBox.Text.Split("`r`n")
$x = $x.Trim(" ")
$x = $x.Trim()
$textList = @()
$x | %{if(![string]::IsNullOrEmpty($_) -and $_ -ne "" -and $_ -ne " " -and $_ -ne "`r`n"){ $textList += $_ }}
Return $textList
}
else{
    Return $objTextBox.Text
}
}
function get-localadmin($serverName){
 $localAdminRoot = @()
    $admins = Gwmi win32_groupuser -computer $serverName  
    $admins = $admins |? {$_.groupcomponent -like '*"Administrators"'}  
  
    $admins |% {  
    $_.partcomponent -match ".+Domain\=(.+)\,Name\=(.+)$" > $nul
    $adminList =  $matches[1].trim('"') + "\" + $matches[2].trim('"')
    ForEach($localAdmin in $adminList){
        $localAdminResults = New-Object System.Object
            ForEach($admin in $usernames){
                $adminCheck = "CORP\" + $admin
                if($adminCheck -like $localAdmin){
                    $currentUser = "WindowsAdmin"
                    break
                }
            }
            $localAdminsADGroup = "CORP\" + "$serverName" + " " + "Admins"
            if($currentUser -ne "WindowsAdmin" -and $localAdmin -ne "CORP\Domain Admins" -and $localAdmin -ne "CORP\Windows Server Admins" -and $localAdmin -ne $localAdminsADGroup){
            $localAdminResults | Add-Member -MemberType NoteProperty -Name Computer -Value $serverName
            $localAdminResults | Add-Member -MemberType NoteProperty -Name Level -Value "Local Computer Admin"
            $localAdminResults | Add-Member -MemberType NoteProperty -Name UserName -Value $localAdmin
            $localAdminRoot += $localAdminResults
            }
          }
    }  
Return $localAdminRoot
}
function get-localAdminAD($serverName){
$localAdminsADGroup = "$serverName" + " " + "Admins"
$localAdminsAD = Get-ADGroupMember -Identity "$localAdminsADGroup"
$localAdminRoot = @()
foreach($localAdmin in $localAdminsAD){
    $localAdminResults = New-Object System.Object
    if($currentUser -ne "WindowsAdmin" -and $localAdmin -ne "CORP\Domain Admins" -and $localAdmin -ne "CORP\Windows Server Admins" -and $localAdmin -ne $localAdminsADGroup){
    $localAdminResults | Add-Member -MemberType NoteProperty -Name Computer -Value $serverName
    $localAdminResults | Add-Member -MemberType NoteProperty -Name Level -Value "AD Computer Admin"
    $userName = "CORP\" + $localAdmin.SAMAccountName
    $localAdminResults | Add-Member -MemberType NoteProperty -Name UserName -Value $userName
    $localAdminRoot += $localAdminResults
    }
}
Return $localAdminRoot
}
function Get-Admins($serverName){
get-localadmin -serverName $serverName
get-localAdminAD -serverName $serverName
}
if($Computers -eq $null -or $Computers -eq "" -or $Computers -eq " "){$Computers = Show-TextBox}
foreach($Computer in $Computers){
[string]$server = $Computer
if(![string]::IsNullOrEmpty($server) -and $server -ne "" -and $server -ne " " -and $server -ne "`r`n"){
Get-Admins -serverName $Computer
}
}
Stop-Transcript
Show-TextBox -inputText (Get-Content $transcriptPath)
Pause