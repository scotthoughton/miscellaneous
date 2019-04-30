# Get Event by EventID and Source
[CmdletBinding()]
Param(
	[Parameter(Position=1)]
	[string[]]$Computers,
	[Parameter(Position=2)]
	[int]$EventID,
	[Parameter(Position=3)]
	[string]$EventSource,
	[Parameter(Position=4)]
	[int]$EventRecords
)
#Set Paths
$path = (Split-Path -Path ((Get-Variable -Name MyInvocation).Value).MyCommand.Path)
$scriptName =  $MyInvocation.MyCommand.Name
if(!(Test-Path "$path\Logs")){ New-Item "$path\Logs" -type directory }
if(!(Test-Path "$path\CSVs")){ New-Item "$path\CSVs" -type directory }
$dateTime = Get-Date -Format  yyyy-MM-dd_HHmm
$Logfile = "$path\Logs\$scriptName" + "-Log"+ $dateTime + ".txt"
$CSVfile = "$path\CSVs\$scriptName" + "-Servers"+ $dateTime + ".csv"
$transcriptPath = "$path\Logs\$scriptName" + "Transcript"+ $dateTime + ".txt"
Function LogWrite
{
   Param ([string]$logstring)

   Add-content $Logfile -value $logstring
   Write-Output "$logstring"
}
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
Function Get-WmiObjectCustom{            
[cmdletbinding()]            
param(            
 [string]$ComputerName = $env:ComputerName,            
 [string]$NameSpace = "root\cimv2",            
 [int]$TimeoutInseconds = 10,            
 [string]$Class            
)            

try {            
 $ConnectionOptions = new-object System.Management.ConnectionOptions            
 $EnumerationOptions = new-object System.Management.EnumerationOptions            
 $timeoutseconds = new-timespan -seconds $timeoutInSeconds            
 $EnumerationOptions.set_timeout($timeoutseconds)            
 $assembledpath = "\\{0}\{1}" -f $ComputerName, $NameSpace            
 $Scope = new-object System.Management.ManagementScope $assembledpath, $ConnectionOptions            
 $Scope.Connect()            
 $querystring = "SELECT * FROM {0}" -f $class            
 $query = new-object System.Management.ObjectQuery $querystring            
 $searcher = new-object System.Management.ManagementObjectSearcher            
 $searcher.set_options($EnumerationOptions)            
 $searcher.Query = $querystring            
 $searcher.Scope = $Scope            
 $result = $searcher.get()            
} catch {            
 Throw $_            
}            
return $result            
}

if($Computers -eq $null -or $Computers -eq "" -or $Computers -eq " "){$Computers = Show-TextBox -formText "Enter Computer Names" -labelText "Computers" -multiLineText $true}
if($EventID -eq $null -or $EventID  -eq "" -or $EventID  -eq " "){$EventID  = Show-TextBox -formText "Enter EventID" -labelText "EventID " -multiLineText $false}
if($EventSource -eq $null -or $EventSource  -eq "" -or $EventSource  -eq " "){$EventSource  = Show-TextBox -formText "Enter Event Source" -labelText "Event Source " -multiLineText $false}
if($EventRecords -eq $null -or $EventRecords  -eq "" -or $EventRecords  -eq " "){$EventRecords  = Show-TextBox -formText "Enter Number of Event Records to Retrieve" -labelText "Event Records Number" -multiLineText $false}
foreach($Computer in $Computers){
    [string]$server = $Computer
    [int]$records = $EventRecords
    LogWrite "$server - Start"
    [int]$records = $EventRecords
    Try{
        $os = Get-WmiObjectCustom -Class "win32_operatingsystem" -computername $server
        $OperatingSystem = ($os.caption).replace(",","-")
        $OSArchitecture = ($os.OSArchitecture).replace(",","-")
        
        LogWrite "$server - $OperatingSystem"
        LogWrite "$server - $OSArchitecture"
    }
    Catch{
    LogWrite "server - Failed to OS and OS Architecture"
    }
    Try{
        if($records -eq 0 -or $records -eq $null -or $records -eq ""){
            $Events = Get-EventLog -LogName "System" -ComputerName $server | Where-Object {$_.EventId -eq $EventID -and $_.Source -eq $EventSource}
        }
        else{
            $Events = Get-EventLog -LogName "System" -ComputerName $server | Where-Object {$_.EventId -eq $EventID -and $_.Source -eq $EventSource} |  Select-Object -First $records
        }
        
        $EventCount = ($Events | measure).count
        if($EventCount -ge 1){
            foreach($event in $events){
                $message = "Time: " + ($event.TimeGenerated) + " - Type: " + ($event.EntryType) + " - Message: " + ($event.Message)
                LogWrite "$message"
			}

            }
        else{
            LogWrite "$server - No Events Matching Critera Found"
        }
    }
    Catch{
        LogWrite "$server - Failed to Get Event Log"
    }
    LogWrite "$server - End"
}