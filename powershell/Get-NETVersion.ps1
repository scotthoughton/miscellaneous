#To be Run on client computer

#Set Paths
$path = (Split-Path -Path ((Get-Variable -Name MyInvocation).Value).MyCommand.Path)
$scriptName =  $MyInvocation.MyCommand.Name
if(!(Test-Path "$path\Logs")){ New-Item "$path\Logs" -type directory }
if(!(Test-Path "$path\CSVs")){ New-Item "$path\CSVs" -type directory }
$dateTime = Get-Date -Format  yyyy-MM-dd_HHmm
$Logfile = "$path\Logs\$scriptName" + "-Log"+ $dateTime + ".txt"
$transcriptPath = "$path\Logs\$scriptName" + "Transcript"+ $dateTime + ".txt"

Start-Transcript -Path $transcriptPath
Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -recurse |
Get-ItemProperty -name Version,Release -EA 0 |
Where { $_.PSChildName -match '^(?!S)\p{L}'} |
Select PSChildName, Version, Release, @{
  name="Product"
  expression={
      switch -regex ($_.Release) {
        "378389" { [Version]"4.5" }
        "378675|378758" { [Version]"4.5.1" }
        "379893" { [Version]"4.5.2" }
        "393295|393297" { [Version]"4.6" }
        "394254|394271" { [Version]"4.6.1" }
        "394802|394806" { [Version]"4.6.2" }
        {$_ -gt 394806} { [Version]"Undocumented 4.6.2 or higher, please update script" }
      }
    }
}
Stop-Transcript