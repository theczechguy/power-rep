function Get-LocalGroupMembers
{

<#
.SYNOPSIS
    Get members of all local groups

.DESCRIPTION
    Iterates through all local groups using ADSI.
    Generates one PSObject per user , output can be processed further with format-* cmdlets.
    
    Exported properties
        memberId,memberClass,memberParent,groupId,groupDescription,IsMemberLocal

    
    Displayed into console by default, if $outputPath parameter is used script generates .csv file into specified location
        to modify delimiter use -$csvDelimiter parameter , default value is ","

    Errors are trapped into ./localGroup_error.txt

.PARAMETER $outputPath
    Specify path into which script generates csv file
    mandatory = no

.PARAMETER $csvDelimiter
    Can modify delimiter used in csv file
    Default value is ","
    mandatory = no

.EXAMPLE
    Get-LocalGroupMembers
        Display members of all groups into console.
        
        memberId         : alien
        memberClass      : User
        memberParent     : WinNT://WORKGROUP/MIKY-DESKTOP/alien
        groupId          : Users
        groupDescription : Clen skupiny Users nemuže provádet nechtené ani úmyslné zmeny systému a muže spouštet vetšinu aplikací.
        IsMemberLocal    : True

.EXAMPLE
    Get-LocalGroupMembers -outputPath ./out.csv
        Generate list of members fo all local groups and save it into csv file in specified location.

.EXAMPLE
    Get-LocalGroupMembers -outputPath ./out.csv -delimiter ";"
        Generate csv file and use ";" as delimiter.
#>
    param(
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String]$outputPath,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String]$csvDelimiter = ",",

    [Parameter(Mandatory=$false)]
    [switch]$skipOrphaned
            )

$Computer = $env:COMPUTERNAME
Write-Verbose "Using $Computer as computername"
Write-Verbose "Setting up ADSI connection"

$Computer = [ADSI]"WinNT://$Computer"
Write-Verbose "Scanning local groups"

$Groups = $Computer.psbase.Children | Where {$_.psbase.schemaClassName -eq "group"}
Write-Verbose "Groups loaded"
Write-Verbose "Processing members"
$memberCol = @()
ForEach ($Group In $Groups)
 {
    Write-Verbose "Invoking members of group : $Group"
    
    $Members = @($Group.psbase.Invoke("Members"))
    Write-Verbose "Invoke done"
    Write-Verbose "Processing members"
    ForEach ($Member In $Members)
    {
        Write-Verbose "Member : $Member"
        
        $memberId = $Member."GetType".Invoke().InvokeMember("Name", 'GetProperty', $Null, $Member, $Null)
        if($skipOrphaned -eq $true)
        {
            if($memberid -match "([A-Z])-[0-9]-[0-9]-.*")
            {
                continue;Write-Verbose "Skipping orpahned member."
            } #skip orphaned members if skiOrphaned param is true
        }

        Write-Verbose "Creating new object for user"
        Write-Verbose "Filling up object properties"
        $o = "" | select memberId,memberClass,memberParent,IsMemberLocal,groupId,server,groupDescription
        $o.memberId = $memberId
        $o.memberClass = $Member."GetType".Invoke().InvokeMember("Class", 'GetProperty', $Null, $Member, $Null)
        $o.GroupId = ($Group.Name)[0]
        $o.groupDescription = ($group.Description)[0]

        $parent =($Member."GetType".Invoke().InvokeMember("ADsPath", 'GetProperty', $Null, $Member, $Null) -split "//")[1]
            $isMemberLocal = switch -Wildcard ($parent)
            {
                "*$env:COMPUTERNAME*"{$true}
                "NT AUTHORITY*"{$true}
                "NT SERVICE*"{$true}
                default{$false}
            }
        
            if($isMemberLocal -eq $true)
            {
                $memberParent = $env:COMPUTERNAME
            }
            else
            {
                $memberParent = ($parent -split "/")[0]
            }
        $o.memberParent = $memberParent
        $o.IsMemberLocal = $isMemberLocal
        $o.server = $env:COMPUTERNAME

        $memberCol += $o

    }
 }

 if($PSBoundParameters.ContainsKey("outputPath")){$memberCol | Export-Csv  -Force -NoTypeInformation -Path $outputPath -Delimiter "$csvDelimiter"}
        else{$memberCol}

trap{$_ | out-file ./localGroup_error.txt -Append}
}
