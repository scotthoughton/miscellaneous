param(
    [String[]]$Computers
)
#Set Paths
$path = (Split-Path -Path ((Get-Variable -Name MyInvocation).Value).MyCommand.Path)
$scriptName = $MyInvocation.MyCommand.Name
if (!(Test-Path "$path\Logs")) { New-Item "$path\Logs" -type directory }
if (!(Test-Path "$path\CSVs")) { New-Item "$path\CSVs" -type directory }
$dateTime = Get-Date -Format  yyyy-MM-dd_HHmm
$Logfile = "$path\Logs\$scriptName" + "-Log" + $dateTime + ".txt"
$transcriptPath = "$path\Logs\$scriptName" + "Transcript" + $dateTime + ".txt"
Function LogWrite {
    Param ([string]$logstring)

    Add-content $Logfile -value $logstring
    Write-Output "$logstring"
}
function Show-TextBox {
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
    $objForm.Size = New-Object System.Drawing.Size(300, 300) 
    $objForm.StartPosition = "CenterScreen"

    $objForm.KeyPreview = $True
    $objForm.Add_KeyDown( {if ($_.KeyCode -eq "Escape") 
            {$objForm.Close()}})

    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Size(75, 225)
    $OKButton.Size = New-Object System.Drawing.Size(75, 23)
    $OKButton.Text = "OK"
    $OKButton.Add_Click( {$x = $objTextBox.Text; $objForm.Close()})
    $objForm.Controls.Add($OKButton)

    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Size(150, 225)
    $CancelButton.Size = New-Object System.Drawing.Size(75, 23)
    $CancelButton.Text = "Cancel"
    $CancelButton.Add_Click( {$objForm.Close()})
    $objForm.Controls.Add($CancelButton)

    $objLabel = New-Object System.Windows.Forms.Label
    $objLabel.Location = New-Object System.Drawing.Size(10, 20) 
    $objLabel.Size = New-Object System.Drawing.Size(280, 20) 
    $objLabel.Text = $labelText
    $objForm.Controls.Add($objLabel) 

    $objTextBox = New-Object System.Windows.Forms.TextBox 
    $objTextBox.Multiline = $multiLineText
    $objTextBox.AcceptsReturn = $True
    $objTextBox.Location = New-Object System.Drawing.Size(10, 40) 
    $objTextBox.Size = New-Object System.Drawing.Size(260, 175) 
    $objForm.Controls.Add($objTextBox) 

    $objForm.Topmost = $True

    $objForm.Add_Shown( {$objForm.Activate()})
    [void] $objForm.ShowDialog()
    if ($multiLineText) {
        [String[]]$x = ""
        $x = $objTextBox.Text.Split("`r`n")
        $x = $x.Trim(" ")
        $x = $x.Trim()
        $textList = @()
        $x | % {if (![string]::IsNullOrEmpty($_) -and $_ -ne "" -and $_ -ne " " -and $_ -ne "`r`n") { $textList += $_ }}
        Return $textList
    }
    else {
        Return $objTextBox.Text
    }
}

Start-Transcript -Path $transcriptPath
if ($Computers -eq $null -or $Computers -eq "" -or $Computers -eq " ") {$Computers = Show-TextBox -formText "Computer Entry" -labelText "Enter One Computer Name Per Line"}
foreach ($Computer in $Computers) {
    [string]$server = $Computer
    if (![string]::IsNullOrEmpty($server) -and $server -ne "" -and $server -ne " " -and $server -ne "`r`n") {
        Try {
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $server) 
            $regKey = $reg.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system", $true) 
            $regKey.SetValue("EnableLUA", "0", [Microsoft.Win32.RegistryValueKind]::DWord)

            #Check
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $server) 
            $regKey = $reg.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system", $true) 
            $uacsetting = $regKey.GetValue("EnableLUA")
            if ($uacsetting -eq 0) {
                LogWrite "$server - UAC Disabled"
            }
            else {
                LogWrite "$server - UAC Failed to Disable"
            }
        }
        Catch {
            LogWrite "$server - UAC Failed to Disable"
        }
    }
}
Stop-Transcript