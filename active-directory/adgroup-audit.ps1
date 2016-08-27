# Group audit
# Author : Michal Zezula , zezulami@gmail.com
########################

param(
[Parameter(Mandatory=$true)]
[string]$groupName,
[Parameter(Mandatory=$true)]
[string]$domain
)

if(!(Get-ADGroup -Identity $groupName -Server $domain))
{
    Write-Warning "Cannot find group : $groupName !"
    return
}

$outObj = @()

Write-Verbose "Starting time $(Get-Date) "

Get-ADGroupMember -Identity $groupName -Server $domain | % {
    $member = $_
    $out = "" | select parentGroup,id,fullname,mail,enabled,lastlogondate,isGroup

    if($member.objectClass -eq "user")
    {
        $memberDomain =  (($member.distinguishedName.Split(',') | Select-String -AllMatches "DC=") | % {$_.ToString().Substring(3)}) -join "."
        $memberIdentity = $member.SID.Value

        $memberDetails = Get-ADUser -Identity $memberIdentity -Server $memberDomain -Properties name,displayname,mail,enabled,lastlogondate | select name,displayname,mail,enabled,lastlogondate

        $out.parentGroup = $groupName
        $out.id = $memberDetails.name
        $out.fullname = $memberDetails.displayname
        $out.mail = $memberDetails.mail
        $out.enabled = $memberDetails.enabled
        $out.lastlogondate = $memberDetails.lastlogondate
        $out.isGroup = "n"
        $outObj+=$Out
    }
    else
    {
        $out.parentGroup = $groupName
        $out.id = $member.name
        $out.isGroup = "y"
        $outObj+=$Out
    }   
}

$outObj

Write-Verbose "End time $(Get-Date) "