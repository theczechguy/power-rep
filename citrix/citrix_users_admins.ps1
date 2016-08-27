# Gather users and administrators from Citrix farm
# Created by Michal Zezula :: zezulami@gmail.com
##################################################
# check if citrix snapin is loaded, if not load it
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

# check if activedirectory module is loaded, if not load it
if(!(Get-Module ActiveDirectory))
{
    try
    {
        Import-Module activedirectory
    }
    catch
    {
        Write-Error "Failed to load activedirectory module : $($_.exception.message)"
        return
    }
}

function Get-CTXApplications
{
[string]$outputCol= $null

    foreach($app in $appCol)#foreach application
    {
    if($adminObj.Group -ne "N/A")#if the Group properties contains real group name
        {
            $grupen =$adminObj.Group #group record from the account list
            foreach($a in $app.Accounts) # foreach account in application list
            {
                $accounten = ($a -split "\\")[1] # split the account into two parts, delimited by \ , pick the second one - ID
                switch($accounten -eq $grupen) # if there is match betwen account from app list and the one from account list result is true
                {
                true {$outputCol += ($app.DisplayName + ",")# match found - add applicatoin into applications list
                        break
                      }
                false {} # match not found , do nothing, continue in the loop
                }
            }
        }
        else
        {
            $grupen =($adminObj.User -split "\\")[1]
            foreach($a in $app.Accounts)
            {
                $accounten = ($a -split "\\")[1]
                switch($accounten -eq $grupen)
                {
                true {$outputCol += ($app.DisplayName + ",")
                        break
                      }
                false {}
                }
            }
        }

    }
    return $outputCol.TrimEnd(",")
}


#get name of the farm
$farmName = Get-XAFarm | select -ExpandProperty FarmName

#get list of accounts assigned to published resources
$appCol = Get-XAApplication | Get-XAApplicationReport | select Accounts,DisplayName
$objCol = @() #collection to store the results

# gather users
# generates the list of users with access to published apps , then removes duplicates
Get-XAApplication | select -ExpandProperty Browsername |%{ Get-XAAccount -BrowserName $_} | select -ExpandProperty AccountDisplayName | sort | Get-Unique | % {

    $accountSplit =($_ -split "\\") # split the domain name and user ID
    $accountDomain = $accountSplit[0] # store the domain
    $accountID = $accountSplit[1] # store the user ID

# first test if the account is group if yes, fill the required properties and create a new record for each member in $objCol collection
# if not, account is user, in this case fill the required properties directly and create a new record in $objCol
    try
    {
         $gm =Get-ADGroupMember $accountID -ErrorAction Continue -Server $accountDomain
            foreach($m in $gm)
            {
            $adminObj = "" | Select-Object Role , AdministratorType , FarmPriviliges , FolderPriviliges , User , Farm , Group , Applications
            $adminObj.Role = "User"
            $adminObj.User = "$accountDomain\$($m.name)"
            $adminObj.Farm = $farmName
            $adminObj.Group = $accountID
            $adminObj.Applications = Get-CTXApplications
            $adminObj
        }
    }
    catch
    {
        $adminObj = "" | Select-Object Role , AdministratorType , FarmPriviliges , FolderPriviliges , User , Farm , Group , Applications
        $adminObj.Role = "User"
        $adminObj.User = "$accountDomain\$accountID"
        $adminObj.Farm = $farmName
        $adminObj.Group = "N/A"
        $adminObj.Applications = Get-CTXApplications
        $adminObj
    }
}



# gather admins
# generate list of farm administrators
Get-XAAdministrator | % {

    $accountSplit =($_.AdministratorName -split "\\") # split into two parts domain \ id
    $accountDomain = $accountSplit[0] # account domain
    $accountID = $accountSplit[1] # account id
    $AdministratorType = $_.AdministratorType # priviliges
    $FarmPrivileges = ($_.FarmPrivileges | % {$_}) -join "," # filled in case of custom priviliges -> gets detailed permissions
    $FolderPrivileges = ($_.FolderPrivileges | % {$_}) -join "," # filled in case of custom priviliges -> gets detailed permissions


    #same procedure as it is for the farm users
    try
    {
         $gm =Get-ADGroupMember $accountID -ErrorAction Continue -Server $accountDomain
            foreach($m in $gm)
            {
            $adminObj = "" | Select-Object Role , AdministratorType , FarmPriviliges , FolderPriviliges , User , Farm , Group, Applications
            $adminObj.Role = "Administrator"
            $adminObj.AdministratorType = $AdministratorType
            $adminObj.FarmPriviliges = $FarmPrivileges
            $adminObj.FolderPriviliges = $FolderPrivileges
            $adminObj.User = "$accountDomain\$($m.name)"
            $adminObj.Farm = $farmName
            $adminObj.Group = $accountID
            $adminObj

            
        }
    }
    catch
    {
        $adminObj = "" | Select-Object Role , AdministratorType , FarmPriviliges , FolderPriviliges , User , Farm , Group , Applications
        $adminObj.Role = "Administrator"
        $adminObj.AdministratorType = $AdministratorType
        $adminObj.FarmPriviliges = $FarmPrivileges
        $adminObj.FolderPriviliges = $FolderPrivileges
        $adminObj.User = "$accountDomain\$accountID"
        $adminObj.Farm = $farmName
        $adminObj.Group = "N/A"
        $adminObj
    }
}