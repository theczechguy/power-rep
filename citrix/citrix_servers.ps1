#Get list of XenApp farm servers
# Created by Michal Zezula :: zezulami@gmail.com
################################################
function Get-ServerFQDN([string]$servername)
{
    #get server FQDN
    ([System.Net.Dns]::GetHostByName($servername) | select -ExpandProperty HostName).tolower()
}

if(!(Get-PSSnapin Citrix.Xenapp.Commands))
{
    try
    {
        Add-PSSnapin Citrix.Xenapp.commands
    }
    catch
    {
        Write-Error "An error occured during snapin load : $($_.exception.message)"
        return
    }
}

$farmName = Get-XAFarm | select -ExpandProperty FarmName
$serverCol = Get-XAServer | select -ExpandProperty ServerName | % {Get-ServerFQDN -servername $_ }

$serverCol | % {
    $outObj = "" | select ServerName,FarmName
    $outObj.ServerName = $_
    $outObj.FarmName = $farmName

    $outObj
}