function New-ZlogConfiguration
{
    [CmdletBinding()]
    [OutputType([string])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $LogName,


        [Parameter(Mandatory=$true,
                   Position=1)]
        [ValidateNotNullOrEmpty()]
        [string]
        $LiteralLogFolderPath,

        
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $LogNameExtension = 'log',

        # Param2 help description
        [Parameter(Mandatory=$false)]
        [ValidateSet('NOTIME','FILETIME','STANDARD')]
        [string]
        $TimeInLogname = 'FILETIME',

        [Parameter(Mandatory = $false)]
        [ValidateSet('UTCTIME','LOCALTIME')]
        [string]
        $Timezone = 'UTCTIME',

        [Parameter(Mandatory = $false)]
        [int]
        $LogRotationDays = 1,

        [Parameter(Mandatory = $false)]
        [int]
        $LogRotationHours = 0,

        # do not send log file path to pipeline
        [Parameter(Mandatory = $false)]
        [switch]
        $SupressOutput,

        [Parameter(Mandatory = $false)]
        [switch]
        $DoNotCreateFile,

        # allow logging of debug level messages
        [Parameter(Mandatory = $false)]
        [switch]
        $EnableDebug
        
    )
    Process
    {
        Set-StrictMode -Version latest
        $ErrorActionPreference = 'stop'

        #region variable declaration
            $logRotationEnabled = $false
        #endregion


        #region test folder path
            if(!(Test-Path -LiteralPath $LiteralLogFolderPath -ErrorAction SilentlyContinue)){
                
                Write-Verbose -Message "Some part of provided path does not exist : $LiteralLogFolderPath"

                try {
                    $LiteralLogFolderPath = New-Item -ItemType Directory -Path $LiteralLogFolderPath
                }
                catch {
                    throw $_
                }
            }
        #endregion

        #region analyze parameters
            # loop through all used parameter names
            $MyInvocation.BoundParameters.Keys | Where-Object {$_ -notin('LogName','LiteralLogFolderPath')} | ForEach-Object -Process {

                $currentParameter = $_
                Write-Debug "PARAMETER ANALYSIS : found parameter -> $currentParameter"

                switch ($currentParameter) {
                    'TimeInLogname' {
                        Write-Debug "PARAMETER ANALYSIS : TimeInLogname -> $TimeInLogname"
                        break
                    }

                    'Timezone' {
                        Write-Debug "PARAMETER ANALYSIS : Timezone -> $Timezone"
                        $Global:ZLogTimeZone = $Timezone
                        break
                    }

                    'LogRotationDays' {
                        Write-Debug "PARAMETER ANALYSIS : LogRotationDays -> $LogRotationDays"
                        Write-Verbose -Message "Log rotation enabled"
                        $logRotationEnabled = $true
                        $Global:ZLogRotationNDays = $LogRotationDays
                        break
                    }   
                    
                    'LogRotationHours' {
                        write-debug "PARAMETER ANALYSIS : LogRotationHours -> $LogRotationHours"
                        Write-Verbose -Message "Log rotation enabled"
                        $logRotationEnabled = $true
                        $Global:ZLogRotationNHours = $LogRotationHours
                        break
                    }

                    'EnableDebug' {
                        write-debug "PARAMETER ANALYSIS : EnableDebug -> True"
                        Write-Verbose -Message 'Debug level messages enabled'
                        $global:ZLogEnableDebugMessages = $true
                    }

                    DEFAULT {
                        write-debug "PARAMETER ANALYSIS : Unknown parameter : $currentParameter"
                        break
                    }
                    
                }
            }
        #endregion

        #region build logfile name

            #region timezone
                switch ($Timezone) {
                    'UTCTIME' { 
                        $currentTime = (get-date).ToUniversalTime()
                        break
                    }
                    'LOCALTIME' {
                        $currentTime = get-date
                    }

                    Default {}
                }
            #endregion

            #region time in log name
                switch ($TimeInLogname) {
                    'FILETIME' {
                        $logNameTime = $currentTime.ToFileTime()
                        $useTimeInLogname = $true
                    }
                    'STANDARD' {
                        $logNameTime = $currentTime.ToString('yyyyMMdd_HH_mm_ss')
                        $useTimeInLogname = $true
                    }
                    Default {
                        Write-Verbose "Time will not be appended to log file name"
                        $useTimeInLogname = $false
                    }
                }
            #endregion

            #region log name

                if ($useTimeInLogname -eq $true) {
                    if ($logRotationEnabled -eq $true) {

                        # logname_time-rotationIdentifier <-- first log is starts with 0
                        $customizedLogname = "{0}_{1}-0.{2}" -f $LogName, $logNameTime , $LogNameExtension
                    } else {
                        $customizedLogname = "{0}_{1}.{2}" -f $LogName , $logNameTime , $LogNameExtension
                    }
                } else {
                    if ($logRotationEnabled -eq $true) {
                        $customizedLogname = "{0}-0.{1}" -f $LogName , $LogNameExtension
                    } else {
                        $customizedLogname = "{0}.{1}" -f $LogName , $LogNameExtension
                    }
                }

            #endregion

            $fullLiteralPath = Join-Path -Path $LiteralLogFolderPath -ChildPath $customizedLogname

        #endregion

        #region create file

            if ($DoNotCreateFile.IsPresent) {
                Write-Verbose -Message 'File will not be created !'
            } else {

                if (!(Test-Path -LiteralPath $fullLiteralPath -ErrorAction SilentlyContinue)) {
                    $null = New-Item -ItemType File -Path $fullLiteralPath -ErrorAction Continue   
                } else {
                    Write-Verbose -Message "Logfile already exists !"
                }
            }

        #endregion
        
        #region output
            $Global:ZLogLogFullPath = $fullLiteralPath
            if (!($SupressOutput.IsPresent)) {
                    Write-Output $Global:ZLogLogFullPath
            }
        #endregion
    }
}

function Write-ZLog
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                    ValueFromPipeline = $true,
                   Position=0,
                   ParameterSetName = 'message')]
        [PSObject]
        $Message,

        # log message indicating function start
        [Parameter(Mandatory = $true,
                    Position = 0,
                    ParameterSetName = 'function')]
        [ValidateSet('Start','End')]
        [string]
        $LogFunction = 'Start',

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO','WARNING','ERROR','DEBUG')]
        $Level = 'INFO',
        
        [Parameter(Mandatory = $false)]
        [string]
        $LiterallPath = $Global:ZLogLogFullPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Increase','Decrease','IncreaseDelayed','DecreaseDelayed','Reset')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Indent,

        [Parameter(
            Mandatory = $false
        )]
        [switch]
        $SupressConsoleOutput,

        [Parameter(
            Mandatory = $false
        )]
        [switch]
        $SupressFileOutput,

        [Parameter(Mandatory = $false)]
        [ValidateSet('UTCTIME','LOCALTIME')]
        [string]
        $Timezone = 'UTCTIME'
    )
    Begin{

        #region Message indent
            $localIndent = 0

            if($Global:ZLogIndent -eq $null) {
                $Global:ZLogIndent = 0
            }

            switch ($Indent) {
                'Increase'{
                    $localIndent = ++$Global:ZLogIndent
                    break
                }
                'IncreaseDelayed'{
                    $localIndent = $Global:ZLogIndent++
                    break
                }
                'Decrease'{
                    if($Global:ZLogIndent -ne 0) {
                        $localIndent = --$Global:ZLogIndent
                    } else {
                        Write-Verbose 'Indent is already 0'
                    }
                    break           
                }
                'DecreaseDelayed'{
                    if($Global:ZLogIndent -ne 0) {
                        $localIndent = $Global:ZLogIndent--
                    } else {
                        Write-Verbose 'Indent is already 0'
                    }
                    break
                }
                'Reset'{
                    $Global:ZLogIndent = 0
                    $localIndent = $Global:ZLogIndent
                    break
                }

                Default {
                    $localIndent = $Global:ZLogIndent
                }
            }

            if($localIndent -gt 0) {
                $indentString = ">> " * $localIndent
            }
            else{
                $indentString = [string]::Empty
            }
        #endregion

        #region log target
            
            # log to file ?

            if($SupressFileOutput.IsPresent) {
                Write-Verbose -Message "Logfile output is supressed !"
            } elseif([string]::IsNullOrEmpty($LiterallPath)) {
                Write-Verbose -Message "ZLogPath variable is not defined or empty. Logfile will not be created !"
                $logToFile = $false
            } else {
                Write-Verbose -Message "Logging to file : $LiterallPath"
                $logToFile = $true
            }

            # log to console ?
            if($SupressConsoleOutput.IsPresent) {
                Write-Verbose -Message "Console output is supressed !"
                $logToConsole = $false
            } else {
                $logToConsole = $true
            }

        #endregion
    }
    Process{

            #region variable declaration
                $lowestCountOfSpaces = 0 # lowest count of spaces from left side
                $countOfSpacesFromStart = $null
                
                $splitMessage = $null
                $currentLine = $null
                $finalMessage = $null
                $currentTime = $null


                if ($PSBoundParameters.Keys.Contains('Timezone')) {
                    $timeDecision = $Timezone
                } else {
                    $timeDecision = $Global:ZLogTimeZone
                }
                switch ($timeDecision) {
                    'UTCTIME'{
                        $currentTime = (get-date).ToUniversalTime()
                    }
                    'LOCALTIME'{
                        $currentTime = get-date
                    }
                    Default {
                        # utc time by default
                        $currentTime = (get-date).ToUniversalTime()
                    }
                }

            #endregion

            #region parameterset message
                if ($PSCmdlet.ParameterSetName -eq 'message') {

                    if ($Global:ZLogEnableDebugMessages -eq $false -and $Level -eq 'DEBUG') {
                        Write-Verbose 'DEBUG level messages are disabled'
                        continue
                    }

                    
                    if($Message -isnot [string] -AND $Message -isnot [int]) {
                        Write-debug "Datatype of current message : $($Message.GetType())"
                        Write-debug "Converting to string"
                        $Message = $Message | Format-List | Out-String
                    }

                    $splitMessage = $Message -split([environment]::NewLine) # split message by lines

                    if($splitMessage.Count -gt 1 -AND !([string]::IsNullOrEmpty($splitMessage))) {

                        Write-Verbose "Received multiline input"

                        #region identify the line with lowest count of empty spaces from left side
                            $splitMessage | ForEach-Object -process {
                                $currentLine = $_ 
                            
                                Write-Debug "LINE - >$currentLine<"

                                if(!([string]::IsNullOrEmpty($currentLine)) -AND !([string]::IsNullOrWhiteSpace($currentLine))) {
                                    $countOfSpacesFromStart = $null
                                    $countOfSpacesFromStart = $currentLine.Length - $currentLine.TrimStart(' ').Length
                        
                                    Write-Debug "Count of Spaces from Start : $countOfSpacesFromStart"

                                    if($lowestCountOfSpaces -eq 0) {
                                        $lowestCountOfSpaces = $countOfSpacesFromStart
                                    } elseif($lowestCountOfSpaces -gt $countOfSpacesFromStart -AND $countOfSpacesFromStart -gt 0) {
                                        $lowestCountOfSpaces = $countOfSpacesFromStart
                                    }
                                    #>

                                    Write-Debug "Lowest Count of spaces : $lowestCountOfSpaces"
                                }
                        
                            }
                            Write-Debug "Final lowest count of spaces : $lowestCountOfSpaces"
                        #endregion

                        #region remove empty spaces from left side , count is determined by the previous step
                            $finalMessage += "{0} <:> {1} <:> {2}" -f $currentTime, $Level , $indentString # first line empty
                            $lineLength = $finalMessage.Length # length of the first line, without any message

                            $splitMessage| ForEach-Object -process {
            
                                $currentLine = $_
                                $messageFirstStage = $null

                                if(!([string]::IsNullOrEmpty($currentLine)) -AND !([string]::IsNullOrWhiteSpace($currentLine))) {
                                    $messageFirstStage+= ($currentLine.Substring($lowestCountOfSpaces)).TrimEnd([environment]::NewLine)
                                }
                                else {
                                    $messageFirstStage += $currentLine
                                }

                                $messageSecondStage = "{0}{1}" -f (' ' * $lineLength) , $messageFirstStage
                                $finalMessage += "{0}{1}" -f [environment]::NewLine , $messageSecondStage
                            }
                        #endregion
                    } else {
                        $finalMessage = "{0} <:> {1} <:> {2}{3}" -f $currentTime, $Level , $indentString , $Message
                    }
                }
            #endregion

            #region parameterset function

                if ($PSCmdlet.ParameterSetName -eq 'function') {
                    
                    $callStack = Get-PSCallStack
                    if ($callStack.count -gt 1) {
                        $callStack = $callStack[($callStack.count -1)]
                    }

                    $mesage = " <~~~~> {0} function : {1} <~~~~>" -f $LogFunction , $callStack.Command
                    $mesage = $mesage.Trim()
                    $finalMessage = "{0} <:> {1} <:> {2}{3}" -f $currentTime, $Level , $indentString, $mesage
                }
            #endregion


        #region output
            #region console

                if($logToConsole -eq $true) {
                    switch ($Level)
                    {
                        'WARNING' {
                            Write-Host -Object $finalMessage -ForegroundColor Yellow
                            break
                        }

                        'ERROR' {
                            Write-Host -Object $finalMessage -ForegroundColor Red
                            break
                        }

                        'DEBUG' {
                            Write-Host -Object $finalMessage -ForegroundColor Cyan
                            break
                        }

                        DEFAULT {
                            Write-Host -Object $finalMessage
                        }
                    }
                }

            #endregion

            #region file
                if($logToFile -eq $true) {
                    $finalMessage | Out-File -LiteralPath $LiterallPath -Append -force # out-file does not block file for reading
                }
            #endregion
        #endregion
    }
}

<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Handle-Exception
{
    [CmdletBinding()]
    [OutputType([void])]
    Param
    (
        # Exception object
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [System.Exception]
        $Exception
    )

    Begin {

    }
    Process {

    }
    End {

    }
}