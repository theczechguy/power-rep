# Retrieve important attributes of all groups in specified domain 
#
# Created by Michal Zezula :: zezulami@gmail.com
#
# - output is PS custom object , it is up to user how to process it
##############################
##############################
#region G000 initial setup
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
#endregion
#region G001 data extraction
try
{
    Write-Verbose "Importing activedirectory module"
    import-module activedirectory -ErrorAction stop #stop the script in case of failure

    #gather data
    $iCounter = 0 # loop counter
    Write-Host "`nProcessing groups : $domain`n"
    
    if(!$UseWaterBalloon)
    {
    
        Get-ADGroup -filter {GroupCategory -eq 'security'} -server $domain -Properties CN,CanonicalName,Description,whenChanged,whenCreated | % {

            $d = $_
            $iCounter++
            if($iCounter -ge 10000)
            {
                Write-Verbose "Processed 10 000 lines !"
                $iCounter = 0
            }   
            $myobj = $null
            $myobj = @{ }

            $myobj.GroupName = $d.CN
            $myobj.GroupDomain_NameSpace = ($d.CanonicalName -split "/")[0]
            $myobj.Description = $d.Description
            $myobj.DateEntryAdded = $d.whenCreated
            $myobj.DateEntryUpdated = $d.whenChanged

            $obj = New-Object PSObject -Property $myobj
            $obj
        }
    }
    else
    {
        $data = Get-ADGroup -filter {GroupCategory -eq 'security'} -server $domain -Properties CN,CanonicalName,Description,whenChanged,whenCreated #waterballoon !

        $data | % {
            $d = $_
            $iCounter++
            if($iCounter -ge 10000)
            {
                Write-Verbose "Processed 10 000 lines !"
                $iCounter = 0
            }   
            $myobj = $null
            $myobj = @{ }

            $myobj.GroupName = $d.CN
            $myobj.GroupDomain_NameSpace = ($d.CanonicalName -split "/")[0]
            $myobj.Description = $d.Description
            $myobj.DateEntryAdded = $d.whenCreated
            $myobj.DateEntryUpdated = $d.whenChanged

            $obj = New-Object PSObject -Property $myobj
            $obj
           }
        
    }
}
catch
{
        $errorMessage = "ERROR at line:$($Error[0].InvocationInfo.Line) line number:$($Error[0].InvocationInfo.ScriptLineNumber), char:$($Error[0].InvocationInfo.OffsetInLine)`r`n message: $($Error[0].Exception.Message)"
        Error-Write -text $errorMessage -SourceScript "groups - $domain"
}
#endregion