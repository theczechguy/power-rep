# Citrix XenApp 6.5 Farm HTML Report
# Created by Michal Zezula - zezulami@gmail.com
# 
# output and error paths are specified in $outputFile and $errorLogFile variables
# requirements : PS v2
#              : .net 4 installed on server from which is this script executed
#              : .net 3.5 also possible but additional download is neccessary  https://www.microsoft.com/en-us/download/details.aspx?id=14422&tduid=(955134d146f497cdb6a07dc939e1731d)(256380)(2459594)(TnL5HPStwNw-aWJyfTTLIfG_fXlzVOsUoQ)()
#              : WMI functional on target servers
#              : sufficient permissions on target server to read performance data using WMI
#              : Used account must have view permissions in Citrix Farm
#####################################################################
#####################################################################
#####################################################################
#region initial setup
$ErrorActionPreference = "silentlycontinue"

# load snapin , in case of failure stop the script
Add-PSSnapin Citrix.XenApp.Commands -ErrorAction Stop

#variable declaration
$datum = Get-Date -Format g
$farmName = (Get-XAFarm -ErrorAction Stop).FarmName

$webServers = "web1","web2"
$SQLServers = "sql1"

$outputFile = "./out.html"
$dataWriterPath = $outputFile

$errorLogFile = "./errs.txt"
#endregion
#region HTML
$htmlTitle = "Citrix XenApp report"

$htmlHeader = @"

<!DOCTYPE html>
<html>
<head>
<title>$htmlTitle</title>
<style>
button.accordion {
    background-color: #eee;
    color: #444;
    cursor: pointer;
    padding: 20px;
    width: 100%;
    border: none;
    text-align: left;
    outline: none;
    font-size: 15px;
    transition: 0.1s;
	border-radius: 25px; 	
}

.datagrid table { border-collapse: collapse; text-align: Center; width: 100%; } .datagrid {font: normal 12px/150% Arial, Helvetica, sans-serif; background: #fff; overflow: hidden; border: 1px solid #006699; -webkit-border-radius: 20px; -moz-border-radius: 20px; border-radius: 20px; }.datagrid table td, .datagrid table th { padding: 3px 10px; }.datagrid table thead th {background:-webkit-gradient( linear, left top, left bottom, color-stop(0.05, #006699), color-stop(1, #00557F) );background:-moz-linear-gradient( center top, #006699 5%, #00557F 100% );filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#006699', endColorstr='#00557F');background-color:#006699; color:#FFFFFF; font-size: 15px; font-weight: bold; border-left: 1px solid #0070A8; } .datagrid table thead th:first-child { border: none; }.datagrid table tbody td { color: #00496B; border-left: 1px solid #E1EEF4;font-size: 12px;border-bottom: 2px solid #E1EEF4;font-weight: normal; }.datagrid table tbody .alt td { background: #E1EEF4; color: #00496B; }.datagrid table tbody td:first-child { border-left: none; }.datagrid table tbody tr:last-child td { border-bottom: none; }


button.accordion.active, button.accordion:hover {
    background-color: #ddd;
}

button.accordion:after {
    content: '\02795';
    font-size: 13px;
    color: #777;
    float: right;
    margin-left: 5px;
}

button.accordion.active:after {
    content: "\2796";
}

div.panel {
    padding: 0 18px;
    background-color: white;
    max-height: 0;
    overflow: hidden;
    transition: 0.6s ease-in-out;
    opacity: 0;
}

div.panel.show {
    opacity: 1;
    max-height: 100%;  
}
</style>
</head>


"@

$htmlBody = @"

<body>
<h2>Citrix Farm report</h2>
"@

$htmlAccordionXenAppHealthBeg = @" 
<button class="accordion">Server Health</button>
<div class="panel">
<div class="datagrid"><table>
<thead><tr><th>Server</th><th>Folder</th><th>WGs</th><th>Zone</th><th>Ping</th><th>WMI</th><th>XML</th><th>IMA</th><th>Booted</th></tr></thead>
<tbody>
"@

$htmlAccordionXenAppHealthEnd = @"
</tbody>
</table></div>
</div>
"@

$htmlAccordionWebHealthBeg = @"
<button class="accordion">Web Servers</button>
<div class="panel">
<div class="datagrid"><table width='800'>
<thead><tr><th>Server</th><th>Ping</th><th>MSSQLSERVER</th><th>SQLSERVERAGENT</th></tr></thead>
<tbody>
"@

$htmlAccordionWebHealthEnd = @"
</tbody>
</table></div>
</div>
"@

$htmlAccordionSQLHealthBeg = @"
<button class="accordion">SQL Servers</button>
<div class="panel">
<div class="datagrid"><table>
<thead><tr><th>Server</th><th>Ping</th><th>WAS</th><th>W3SVC</th></tr></thead>
<tbody>
"@

$htmlAccordionSQLHealthEnd = @"
</tbody>
</table></div>
</div>
"@

$htmlAccordionFarmLoadBeg = @"
<button class="accordion">Farm Load</button>
<div class="panel">
<IMG
SRC="data:image/gif;base64,
"@

$htmlAccordionFarmLoadEnd = @"
"
ALT="Farm Load">
</div>
"@

$htmlAccordionAppReportBeg = @"
<button class="accordion">Application Report</button>
<div class="panel">
<div class="datagrid"><table>
<thead><tr><th>AppName</th><th>Type</th><th>Enabled</th><th>Access</th><th>Servers</th><th>WGs</th><th>Folder</th><th>Executable</th></tr></thead>
<tbody>
"@

$htmlAccordionAppReportEnd = @"
</tbody>
</table></div>
</tr>
</table>
</div>
"@

$htmlScript = @"
<script>
var acc = document.getElementsByClassName("accordion");
var i;
for (i = 0; i < acc.length; i++) {
    acc[i].onclick = function(){
        this.classList.toggle("active");
        this.nextElementSibling.classList.toggle("show");
  }
}
</script>
"@

$htmlFinish = @"
</body>
</html>
"@

#endregion
#region function declaration
function New-ColumnChart
{
<#
.SYNOPSIS
    Create a new ColumnChart

.Description
    Creates a new ColumnChart using Microsoft .Net chart controls

.PARAMETER Title
    Set the chart Title, can be multiline -> `n
    Mandatory = yes

.PARAMETER xLabel
    Sets the label for the X axis - this name must match name of property of input data       
    Mandatory = yes

.PARAMETER yLabel
    Sets the label for the Y axis - this name must match name of property of input data
    Mandatory = yes

.PARAMETER width
    Sets the width of the chart
    Mandatory = no
    default = 500

.PARAMETER height
    Sets the height of the chart
    Mandatory = no
    default = 400

.PARAMETER data
    Sets the input data
    Mandatory = yes

.PARAMETER outPath
    sets the output path
    use only path , name is set automaticaly to chart.png

.PARAMETER background
    set chart background colour
    default is white


.EXAMPLE
    $input = Get-Process | select ProcessName,WS -First 5
    New-ColumnChart -Title "Services`nby StartMode" -xLabel "ProcessName" -yLabel "WS" -data $input
    
#>

# created by Michal Zezula

[cmdletbinding()]
Param(
    
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [String]$Title,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$xLabel,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$yLabel,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]$width = 600,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]$height = 400,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [psobject]$data,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$outPath
        )

[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")


# create chart object 
$Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart 
$Chart.Width = $width
$Chart.Height = $height
$Chart.Left = 40 
$Chart.Top = 30

# create a chartarea to draw on and add to chart , set background color to transparent
$ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
$Chart.ChartAreas.Add($ChartArea)
$Chart.BackColor = [System.Drawing.Color]::white


# add data to chart 
[void]$Chart.Series.Add("Data") 
#$Chart.Series["Data"].Points.DataBindXY($data.Keys, $data.Values)
#$Chart.Series["Data"].Points.AddXY($data.Keys, $data.Values)
write-host $data
$data | foreach {$Chart.Series["Data"].Points.AddXY($_.$xLabel , $_.$yLabel)} | Out-Null

$Chart.Series["Data"]["DrawingStyle"] = "lighttodark"

# add title and axes labels 
[void]$Chart.Titles.Add($Title) 
$ChartArea.AxisX.Title = $xLabel 
$ChartArea.AxisY.Title = $yLabel

$Chart.Series["Data"].IsValueShownAsLabel = $true
$Chart.Series["Data"]["LabelStyle"] = "Bottom"

# Find point with max/min values and change their colour 
#$maxValuePoint = $Chart.Series["Data"].Points.FindMaxByValue() 
#$maxValuePoint.Color = [System.Drawing.Color]::Crimson

$minValuePoint = $Chart.Series["Data"].Points.FindMinByValue() 
$minValuePoint.Color = [System.Drawing.Color]::GreenYellow

#############################

$chart.SaveImage("$outPath\chart.png","png")
<#
# display the chart on a form 
$Chart.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right -bor 
                [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left 
$Form = New-Object Windows.Forms.Form 
$Form.Text = "PowerShell Chart" 
$Form.Width = $width + 100
$Form.Height = $height + 100
$Form.controls.add($Chart) 
$Form.Add_Shown({$Form.Activate()}) 
$Form.ShowDialog()
#>
}

function PingIt([string]$target,[int]$timeout = 1500, [int]$retry =2)
{

    $result = $true
    $ping = New-Object System.Net.NetworkInformation.Ping
    $i = 0
        do{
            
            $I++
            try
            {$result = $ping.Send($target, $timeout).Status.ToString()}
            catch
            {continue}
            if($result -eq "success"){return $true}
          }
          until($i -eq $retry)
          return $false
    
}

function dataWriter
{
    param ($data)
    $tbEntry = "<tr>"
    $data | %{

    $tbEntry += switch($_)
    {
        #ok part
        "OK"{"<td bgcolor='#387C44' align=center><font color='#FFFFFF'>$_</font></td>"}
        "running"{"<td bgcolor='#387C44' align=center><font color='#FFFFFF'>$_</font></td>"}
        #error part
        "Error"{"<td bgcolor='#FF0000' align=center><font color='#FFFFFF'>$_</font></td>"}
        "stopped"{"<td bgcolor='#FF0000' align=center><font color='#FFFFFF'>$_</font></td>"}

        #empty string
        ""{"<td>-</td>"}

        default{"<td>$_</td>"}
        }
    }
    $tbEntry += "</tr>"
    $tbEntry | out-file $dataWriterPath -Append
}

function dataWriterAlter
{
    param($data)
    $alter = $false

    $tbEntry = '<tr class="alt">'
    $data | % {
      $tbEntry += "<td>$_</td>"
    }
    $tbEntry += "</tr>"
    $tbEntry | Out-File $dataWriterPath -Append
}

function Convert-ToBase64
{
    param([string]$path)
    [convert]::ToBase64String((Get-Content $path -Encoding Byte))
}
#endregion

#region XenApp server health
$XenAppserverColl = @()
$xenAppLoad = @()
Get-XAServer -erroraction stop | % {
    $results = "" | Select-Object Server, Folder, WGs, Zone, Ping, WMI, XML, IMA, Booted
    $server = $_.ServerName
    $resultLoad = "" | Select-Object Server,Load
    $resultLoad.Server = $server
    $resultLoad.Load = Get-XAServerLoad -ServerName $_.ServerName | select -ExpandProperty Load

    $results.Server = $_.ServerName
    $results.Folder = $_.FolderPath
    $results.WGs = ((Get-XAWorkerGroup -ServerName $_.ServerName) | % {$_.WorkerGroupName}) -join ","
    $results.Zone = $_.ZoneName
    
    $resultPing = PingIt($_.ServerName)
    if($resultPing -ne $true){$results.Ping = "ERROR"}
    else{$results.Ping = "OK" # if ping works continue with other checks .
            
            #wmi part
            $wmi = Get-WmiObject -Class win32_operatingsystem -ComputerName $_.ServerName
            if($wmi -ne $null)
            {
                $results.WMI = "OK"
                 $datum = $wmi.ConvertToDateTime($wmi.LastBootUpTime)
                  $results.Booted=$datum.tostring() #server uptime
            }
            else{$results.WMI = "ERROR";$results.Booted = "ERROR"}

            #IMA check
            if((Get-Service -ComputerName $server -Name "IMAService").Status -match "Running"){$results.IMA = "OK"}
             else{$results.IMA = "ERROR"}

            #XML check
            if($_.ElectionPreference -ne "WorkerMode")
             {
               if((Get-Service -ComputerName $server -Name "ctxhttp").Status -match "Running"){$results.XML = "OK"}
                else{$results.XML="ERROR"}
                 }
                 else{$results.XML="N/A"}


    
        }#end results else block


    $XenAppserverColl += $results #combine results from all servers into one collection
    $xenAppLoad += $resultLoad
    }
#endregion
#region WebServer check
$WebServerColl = @()
$webServers | % {

    $resultsIIS = "" | Select-Object Server, Ping, WAS, W3SVC
    $resultsIIS.Server = "$_"
    
        $resultPing = PingIt($_)
        if($resultPing -ne $true){$resultsIIS.Ping = "ERROR"}
        else{$resultsIIS.Ping = "OK"}

        $resultWAS = Get-Service -ComputerName $_ -Name "WAS"
        if($resultWAS.Status -ne "Running"){$resultsIIS.WAS = "ERROR"}
        else{$resultsIIS.WAS = "OK"}

        $resultW3SVC = Get-Service -ComputerName $_ -Name "W3SVC"
        if($resultW3SVC.Status -ne "Running"){$resultsIIS.W3SVC = "ERROR"}
        else{$resultsIIS.W3SVC = "OK"}

        $WebServerColl += $resultsIIS
}
#endregion
#region SQL server check
$SQLCol = @()
$SQLServers | %{

    $resultsSQL = "" | Select-Object Server, Ping, MSSQLSERVER, SQLSERVERAGENT
    $resultsSQL.Server = "$_"

    $resultPing = PingIt("$_")
    if($resultPing -ne $true){$resultsSQL.Ping = "ERROR"}
    else{$resultsSQL.Ping = "OK"}

    $resultServer = Get-Service -ComputerName "$_" -Name "MSSQLSERVER"
    if($resultServer.Status -ne "Running"){$resultsSQL.MSSQLSERVER = "ERROR"}
    else{$resultsSQL.MSSQLSERVER = "OK"}

    $resultAgent = Get-Service -ComputerName "$_" -Name "SQLSERVERAGENT"
    if($resultAgent.Status -ne "Running"){$resultsSQL.SQLSERVERAGENT = "ERROR"}
    else{$resultsSQL.SQLSERVERAGENT = "OK"}

    $SQLCol += $resultsSQL
                }
#endregion


#region Application report
$appReport = Get-XAApplication | % {Get-XAApplicationReport -BrowserName $_.BrowserName} | select BrowserName,
applicationtype,
enabled,
@{n='accounts'; e={($_.accounts) -join ";"}},
@{n='servers'; e={$_.servernames}},
@{n='WGs'; e={($_.workergroupnames) -join ";"}},
folderpath,
CommandLineExecutable
#endregion

#region HTML report
##########################

New-ColumnChart -Title "XenApp server load" -xLabel "Server" -yLabel "Load" -data ($xenAppLoad | sort -Property Load) -outPath "C:\temp\"

$convertedChart = Convert-ToBase64 -path "C:\temp\chart.png"

#create new file
$htmlHeader + $htmlBody + $htmlAccordionXenAppHealthBeg | Out-File $outputFile

$XenAppserverColl | % {
    dataWriter -data $_.Server, $_.Folder, $_.WGs , $_.Zone , $_.Ping , $_.WMI , $_.XML , $_.IMA , $_.Booted
}

$htmlAccordionXenAppHealthEnd + $htmlAccordionWebHealthBeg | Out-File $outputFile -Append

$WebServerColl | % {
    dataWriter -data $_.Server , $_.Ping , $_.WAS , $_.W3SVC
}

$htmlAccordionWebHealthEnd + $htmlAccordionSQLHealthBeg | Out-File $outputFile -Append
$SQLCol | % {
    dataWriter -data $_.Server , $_.Ping , $_.MSSQLSERVER , $_.SQLSERVERAGENT
}

$htmlAccordionSQLHealthEnd + $htmlAccordionFarmLoadBeg | Out-File $outputFile -Append

$convertedChart + $htmlAccordionFarmLoadEnd + $htmlAccordionAppReportBeg | out-file $outputFile -Append

$appReport | % {
    dataWriter -data $_.BrowserName, $_.applicationtype, $_.enabled , $_.accounts , $_.servers , $_.WGs, $_.folderpath, $_.CommandLineExecutable
}

$htmlAccordionAppReportEnd + $htmlScript + $htmlFinish | Out-File $outputFile -Append

    trap{$_ | Out-File $errorLogFile -Append}
#endregion