# Retrieve members of all groups in specified domain
# Output tells you from which domain the group and the user is -> namespace properties
#
# Created by Michal Zezula :: zezulami@gmail.com
#
# - output is PS custom object , it is up to user how to process it
#
##############################
##############################
#region M000 initial setup
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$domain,
    [Parameter(Mandatory=$false)]
    [switch]$UseWaterBalloon
        )


$ErrorActionPreference = "stop"
$errorLogPath = "./errors.txt"

function Error-Write([string]$text,[string]$SourceScript)
{
    $result = Test-Path $errorLogPath

    switch($result)
    {
        false {New-Item -ItemType file -Force -Path $errorLogPath}
        default{}
    }

    $modifiedInput = $(get-date -Format "hh:mm:ss MM/dd/yyyy") + " - $SourceScript : " + $text
    Add-Content -Path $errorLogPath -Value $modifiedInput
}
Write-Verbose "Importing activedirectory module"
import-module activedirectory
#endregion

#region M001 data extraction
#gather data
 $iCounter = 0 #loop counter
 Write-Host "`nProcessing group members : $domain`n"
 #region M001.1
 if(!$UseWaterBalloon)
 {
    try
    {
      Get-ADGroup -filter {GroupCategory -eq 'security'} -server $domain -Properties Members,SamAccountName,CanonicalName | % {
 
        $d = $_
        $iCounter++
        if($iCounter -ge 10000)
        {
            Write-Verbose "Processed 10 000 lines !"
            $iCounter = 0
        }

        foreach($member in $d.Members)
        {
            $myobj = $null
            $myobj = @{ }

            $myobj.Groupname = $d.SamAccountName
            $myobj.Groupdomain_NameSpace = ($d.CanonicalName -split "/")[0]
            $myobj.MemberName = (($member -split "," | Select-String -AllMatches "CN=") | select -First 1) -replace "CN=",""
            $myobj.MemberDomain_NameSpace = (($member -split "," | Select-String -AllMatches "DC=") -replace "DC=","") -join "."
            $obj = New-Object PSObject -Property $myobj
            $obj
        }
      }
    }
    catch
    {
        $errorMessage = "ERROR at line:$($Error[0].InvocationInfo.Line) line number:$($Error[0].InvocationInfo.ScriptLineNumber), char:$($Error[0].InvocationInfo.OffsetInLine)`r`n message: $($Error[0].Exception.Message)"
        Error-Write -text $errorMessage -SourceScript "group_members $domain"
    }
 }
 #endregion
 #region M001.2
 else
 {
    try
    {
        Write-Verbose "Building data collection"
        $data =Get-ADGroup -filter {GroupCategory -eq 'security'} -server $domain -Properties Members,SamAccountName,CanonicalName #water baloon !
        Write-Verbose "Data collection ready"
 
         foreach($d in $data)
         {
            $iCounter++
            if($iCounter -ge 10000)
             {
                Write-Verbose "Processed 10 000 lines !"
                $iCounter = 0
             }
            $d.Members | %{
    
            $myobj = $null
            $myobj = @{ }

            $myobj.Groupname = $d.SamAccountName
            $myobj.Groupdomain_NameSpace = ($d.CanonicalName -split "/")[0]
            $myobj.MemberName = (($_ -split "," | Select-String -AllMatches "CN=") | select -First 1) -replace "CN=",""
            $myobj.MemberDomain_NameSpace = (($_ -split "," | Select-String -AllMatches "DC=") -replace "DC=","") -join "."

            $obj = New-Object PSObject -Property $myobj
                $obj
            }
 }
    }
    catch
    {
        $errorMessage = "ERROR at line:$($Error[0].InvocationInfo.Line) line number:$($Error[0].InvocationInfo.ScriptLineNumber), char:$($Error[0].InvocationInfo.OffsetInLine)`r`n message: $($Error[0].Exception.Message)"
        Error-Write -text $errorMessage -SourceScript "group_members - $domain"
    }
 }
 #endregion
 #endregion