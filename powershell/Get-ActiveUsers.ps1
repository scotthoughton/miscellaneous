#Requires -version 5
param(
    [String[]]$Computers
)

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
if($Computers -eq $null -or $Computers -eq "" -or $Computers -eq " "){$Computers = Show-TextBox}
foreach($Computer in $Computers){
[string]$server = $Computer
if(![string]::IsNullOrEmpty($server) -and $server -ne "" -and $server -ne " " -and $server -ne "`r`n"){
    $queryResults = (qwinsta /server:$server | foreach { (($_.trim() -replace "\s+",","))} | ConvertFrom-Csv)  
     
    # Pull the session information from each instance 
    $userCount = 0
    ForEach ($queryResult in $queryResults) { 
        $RDPUser = $queryResult.USERNAME 
        $sessionType = $queryResult.SESSIONNAME 
         
        # We only want to display where a "person" is logged in. Otherwise unused sessions show up as USERNAME as a number 
        If (($RDPUser -match "[a-z]") -and ($RDPUser -ne $NULL) -and ($RDPUser -ne "shoughto") -and ($RDPUser -ne "biadmin")) {  
            # When running interactively, uncomment the Write-Host line below to show the output to screen 
            $userCount ++
             #Write-Output "$server logged in by $RDPUser on $sessionType "
            #$SessionList = $SessionList + "`n`n" + $ServerName + " logged in by " + $RDPUser + " on " + $sessionType 
        } 
    } 
    Write-Output "$server has $userCount Users"
} 
}

