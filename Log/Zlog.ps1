function New-ZlogConfiguration
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    Param (
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $LogName,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $LiteralLogFolderPath,

        
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $LogNameExtension = 'log',

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
        $LogRotationDays = 0,

        [Parameter(Mandatory = $false)]
        [int]
        $LogRotationHours = 0,

        [Parameter(Mandatory = $false)]
        [int]
        $LogRotationMinutes = 0,

        # allow logging of debug level messages
        [Parameter(Mandatory = $false)]
        [switch]
        $EnableDebugMessages,

        # do not send output hashtable to pipeline in the end
        [Parameter(Mandatory = $false)]
        [switch]
        $SupressPipelineOutput,

        # enable indetation
        [Parameter(Mandatory = $false)]
        [switch]
        $EnableIndent
    )
    Process
    {
        $ErrorActionPreference = 'stop'

        #region variable declaration
            $logRotationEnabled = $false
            $useTimeInLogname = $null # true/false
            $currentTime = $null
            $fullLiteralPath = $null # full path of the logfile
        #endregion

        #region logfolder
            if ($PSBoundParameters.Keys.Contains('LiteralLogFolderPath')) {
                if ($PSBoundParameters.Keys.Contains('LogName')) {
                    if(!(Test-Path -LiteralPath $LiteralLogFolderPath -ErrorAction SilentlyContinue)){                    
                        Write-Verbose -Message "Some part of provided path does not exist : $LiteralLogFolderPath"
    
                        try {
                            $LiteralLogFolderPath = New-Item -ItemType Directory -Path $LiteralLogFolderPath
                        }
                        catch {
                            Update-Exception -Exception $_ -ErrorDetailMessage "Failed to create log folder : $LiteralLogFolderPath" -Throw
                        }
                    }
                } else {
                    Write-Error -Message 'Missing LogName parameter' -RecommendedAction 'Use LogName and LiteralLogFolderPath parameters together.'
                }
            }
        #endregion

        #region logfile
            if ($PSBoundParameters.Keys.Contains('LogName')) {
                #region timezone
                    switch ($Timezone) {
                        'UTCTIME' { 
                            $currentTime = (get-date).ToUniversalTime()
                            break
                        }
                        'LOCALTIME' {
                            $currentTime = get-date
                        }
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

                #region log rotation
                    if ($PSBoundParameters.Keys.Contains('LogRotationDays')) {
                        $logRotationEnabled = $true
                    }

                    if ($PSBoundParameters.Keys.Contains('LogRotationHours')) {
                        $logRotationEnabled = $true
                    }
                    
                    if ($PSBoundParameters.Keys.Contains('LogRotationMinutes')) {
                        $logRotationEnabled = $true
                    }
                #endregion

                #region log name definition

                    $customizedLogname = New-Object System.Text.StringBuilder
                    [void]$customizedLogname.Append($LogName) # just log name without anything

                    if ($useTimeInLogname -eq $true) {
                        [void]$customizedLogname.AppendFormat("_{0}", $logNameTime) # append time 
                    }

                    if ($logRotationEnabled -eq $true) {
                        $logNameBeforeRotation = $customizedLogname.ToString()
                        [void]$customizedLogname.Append('-0')
                    }

                    [void]$customizedLogname.AppendFormat('.{0}', $LogNameExtension) # append file extension

                #endregion

                #region build full file path
                    try {
                        $fullLiteralPath = Join-Path -Path $LiteralLogFolderPath -ChildPath $customizedLogname.ToString()
                    }
                    catch {
                        Update-Exception -Exception $_ -ErrorDetailMessage 'Unable to combine logname with logpath' -Throw
                    }
                #endregion

                #region create file
                    if (!(Test-Path -LiteralPath $fullLiteralPath -ErrorAction SilentlyContinue)) {
                        try {
                            $logFile = New-Item -ItemType File -Path $fullLiteralPath
                        }
                        catch {
                            Update-Exception -Exception $_ -ErrorDetailMessage "Failed to create logfile : $fullLiteralPath" -Throw
                        }
                    } else {
                        Write-Warning -Message "Logfile : $fullLiteralPath already exists !"    # should this fail with error ?
                                                                                                # maybe another parameter to specify is it 
                                                                                                # should fail in this case or not
                        try {
                            $logFile = Get-Item -LiteralPath $fullLiteralPath   
                        }
                        catch {
                            Update-Exception -Exception $_ -ErrorDetailMessage "Failed to get logfile : $fullLiteralPath" -Throw
                        }
                    }
                #endregion
            }
        #endregion

        #region output

            $configHashTable = New-ZlogConfigTable
            $configHashTable.'EnableIndent' = $EnableIndent.IsPresent
            $configHashTable.'Indent' = 0
            $configHashTable.'LogLiterallPath' = $fullLiteralPath
            $configHashTable.'LogFolder' = $LiteralLogFolderPath
            $configHashTable.'LogNameNoRotation' = $logNameBeforeRotation
            $configHashTable.'LogFileCreatedUTC' = $logFile.CreationTimeUtc
            $configHashTable.'LogFileExtension' = $LogNameExtension
            $configHashTable.'LogTimezone' = $Timezone
            $configHashTable.'LogRotationEnabled' = $logRotationEnabled
            $configHashTable.'LogRotationDays' = $LogRotationDays
            $configHashTable.'LogRotationHours' = $LogRotationHours
            $configHashTable.'LogRotationMinutes' = $LogRotationMinutes
            $configHashTable.'LogRotationIdentifier' = 0
            $configHashTable.'DebugMessagesEnabled' = $true

            $Global:ZLogConfig = $configHashTable

            if (!$SupressPipelineOutput.IsPresent) {
                Write-Output $configHashTable   
            }
        #endregion
    }
}

function Rotate-Zlog {
    [CmdletBinding()]
    param()
    PROCESS{
        if (-not (Get-Variable -Name ZLogConfig -Scope Global -ErrorAction SilentlyContinue)) {
            Write-Error -Message 'ZLog configuration has not been set yet, rotation is not possible'`
                        -RecommendedAction 'Run first New-ZlogConfiguration'`
        } else {
            #region should rotate ?
                if ($Global:ZLogConfig.LogRotationEnabled -eq $true) {
                    Write-Verbose -Message "Logrotation is enabled"

                    [datetime]$fileCreatedUTC = $Global:ZLogConfig.LogFileCreatedUTC
                    $logRotationDays = $Global:ZLogConfig.LogRotationDays
                    $logRotationHours = $Global:ZLogConfig.LogRotationHours
                    $logRotationMinutes = $Global:ZLogConfig.LogRotationMinutes
                    $logRotationIdentifier = $Global:ZLogConfig.LogRotationIdentifier
                    [string]$logFullPath = $Global:ZLogConfig.LogLiterallPath
                    $logFileExtension = $Global:ZLogConfig.LogFileExtension
                    $logNameNoRotation = $Global:ZLogConfig.LogNameNoRotation
                    $logFolder = $Global:ZLogConfig.LogFolder

                    $limit = (get-date).ToUniversalTime().AddMinutes(-$logRotationMinutes).AddHours(-$logRotationHours).AddDays(-$logRotationDays)

                    if ($fileCreatedUTC -lt $limit) {
                        # file is older , rotate
                        Write-Verbose -Message 'Log rotation is initiated'

                        $rotateMessage = New-Object System.Text.StringBuilder
                        [void]$rotateMessage.AppendLine(('=' * 50))
                        [void]$rotateMessage.AppendLine('LOG ROTATION INITIATED')
                        [void]$rotateMessage.AppendLine("CURRENT LOG FILE : $($Global:ZLogConfig.LogLiterallPath)")
                        
                    } else {
                        # file is newer , do not rotate
                        Write-Verbose -Message 'Logfile is not ready for log rotation'
                        return
                    }
                } else {
                    return
                }
            #endregion
            #region rotate
                    $Global:ZLogConfig.LogRotationIdentifier++
                    $newLogName = "{0}-{1}.{2}" -f $logNameNoRotation,$Global:ZLogConfig.LogRotationIdentifier,$logFileExtension
                    [void]$rotateMessage.AppendLine("NEW LOG FILE : $newLogName")

                    # write to old log
                    Write-ZLog -Message $rotateMessage.ToString() -Level WARNING

                    #update global config
                    $newLogLiterallPath = Join-Path -Path $logFolder -ChildPath $newLogName
                    $Global:ZLogConfig.LogLiterallPath = $newLogLiterallPath

                    #create new file
                    try {
                        $newLogFile = New-Item -ItemType File -Path $newLogLiterallPath
                    }
                    catch {
                        Update-Exception -Exception $_ -ErrorDetailMessage "Failed to create file : $newLogLiterallPath" -Throw
                    }

                    $Global:ZLogConfig.LogFileCreatedUTC = $newLogFile.CreationTimeUtc
                    
                    $rotateMessage.Clear() # clear previous messages
                    $rotateMessage.AppendLine('LOG ROTATION')
                    $rotateMessage.AppendLine("PREVIOUS LOG : $logFullPath")

                    #write to new log file
                    Write-ZLog -Message $rotateMessage.ToString() -Level WARNING
            #endregion
        }
    }
}

<#
    .SYNOPSIS
    Function for advanced logging.

    .PARAMETER Message
    Message to be logged

    .PARAMETER LogFunction
    Used to log function start and end.
    Accepts two possible inputs - Start / End

    .PARAMETER DebugOptions
    Offers easy logging of usefull informations about evnrionments. 
    For example dump of all global variables , etc.

    .PARAMETER Level
    Level of message - INFO, WARNING , etc.

    .PARAMETER LiterallPath
    Literall path to the log file

    .PARAMETER Indent
    Allows to create 'tree' structure inside of your logs by indenting to the right side and back.

    .PARAMETER SupressConsoleOutput
    Do not display log message in the host console.

    .PARAMETER SupressFileOutput
    Do not write log message to the file.

    .PARAMETER Timezone
    Specifies if time should be local or UTC

    .PARAMETER PassThrough
    If used, function in the end sends the log message to the pipeline.
#>
function Write-ZLog
{
    [CmdletBinding(DefaultParameterSetName = 'message')]
    [OutputType([string])]
    Param (
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

        # debug options
        [Parameter(Mandatory = $true,
                    Position = 0,
                    ParameterSetName = 'debugoptions')]
        [ValidateSet('DumpVariablesScopeGlobal','DumpVariablesScopeLocal')]
        [string]
        $DebugOptions,

        [Parameter(Mandatory = $false)]
        [Parameter(ParameterSetName = 'message')]
        [Parameter(ParameterSetName = 'function')]
        [ValidateSet('INFO','WARNING','ERROR','DEBUG')]
        $Level = 'INFO',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Increase','Decrease','IncreaseDelayed','DecreaseDelayed','Reset')]
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
        $Timezone = 'UTCTIME',

        # send output message to pipeline
        [Parameter(Mandatory = $false)]
        [switch]
        $PassThrough,

        # allow log rotation , if rotation is enabled
        [Parameter(Mandatory = $false)]
        [switch]
        $AllowLogRotationAfterThisMessage
    )
    Begin {

        #region internal functions
            function Set-ZIndentLevel
            {
                [CmdletBinding()]
                [OutputType([int])]
                Param
                (
                    # Param1 help description
                    [Parameter(Mandatory=$true,
                            ValueFromPipeline = $true,
                            Position=0)]
                    [ValidateSet('Increase','IncreaseDelayed','Decrease','DecreaseDelayed','Reset')]
                    [String]
                    $Indent
                )
                Process {
                    switch ($Indent) {
                            'Increase'{
                                $localIndent = ++$Global:ZLogConfig.Indent
                                break
                            }
                            'IncreaseDelayed'{
                                $localIndent = $Global:ZLogConfig.Indent++
                                break
                            }
                            'Decrease'{
                                if($Global:ZLogConfig.Indent -ne 0) {
                                    $localIndent = --$Global:ZLogConfig.Indent
                                } else {
                                    Write-Verbose 'Indent is already 0'
                                }
                                break           
                            }
                            'DecreaseDelayed'{
                                if($Global:ZLogConfig.Indent -ne 0) {
                                    $localIndent = $Global:ZLogConfig.Indent--
                                } else {
                                    Write-Verbose 'Indent is already 0'
                                }
                                break
                            }
                            'Reset'{
                                $Global:ZLogConfig.Indent = 0
                                $localIndent = $Global:ZLogConfig.Indent
                                break
                            }
                    }
                    Write-Output $localIndent
                }
            }
        #endregion

        #region global configuration

            #region test config variable
                $testConfigVariable = Get-Variable -Name 'ZLogConfig' -Scope Global -ErrorAction SilentlyContinue
                if (-not $testConfigVariable) { # if config variable does not exist yet, create a new one with default configuration
                    $Global:ZLogConfig = New-ZlogConfigTable
                }
            #endregion

            #region read configuration
                #region indent
                    $indentString = [string]::Empty
                    $localIndent = 0
                    if ($Global:ZLogConfig.EnableIndent -eq $true) {
                        if ([string]::IsNullOrEmpty($Indent)) {
                            $localIndent = $Global:ZLogConfig.Indent
                        } else {
                            $localIndent = Set-ZIndentLevel -Indent $Indent
                        }

                        if ($localIndent -gt 0) {
                            $indentString = "{0}>> " -f (" " * $localIndent)
                        } else {
                            $indentString = [string]::Empty
                        }
                    }
                #endregion

                #endregion log file
                    if ($Global:ZLogConfig.LogLiterallPath) {
                        $literallPath = $Global:ZLogConfig.LogLiterallPath
                    } else {
                        $literallPath = $null
                    }
                #region 
            #endregion

        #endregion

        #region log target
            
            # log to file ?
            if($SupressFileOutput.IsPresent) {
                Write-Verbose -Message "Logfile output is supressed !"
            } elseif([string]::IsNullOrEmpty($LiterallPath)) {
                Write-Verbose -Message "Logfile is not defined"
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

            # send log message to pipeline ?
            if ($PassThrough.IsPresent) {
                Write-Verbose -Message 'Message will be sent to pipeline'
                $logToPipeline = $true
            } else {
                $logToPipeline = $false
            }

        #endregion
    }
    Process{
            #region variable declaration
                $lowestCountOfSpaces = [System.Int32]::MaxValue # lowest count of spaces from left side
                $countOfSpacesFromStart = $null
                
                $splitMessage = $null
                $actuallMessage = $null
                $finalMessage = $null
                $currentTime = $null

                if ($PSBoundParameters.Keys.Contains('Timezone')) {
                    $timeDecision = $Timezone
                } else {
                    $timeDecision = $Global:ZLogConfig.LogTimezone
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
                    
                    Write-debug "Datatype of current message : $($Message.GetType())"
                    Write-debug "Converting to string"

                    switch ($Message) {
                        {($_ -is [int] -or $_ -is [string])} {
                            $actuallMessage = $Message
                            break
                        }

                        {$_ -is [hashtable]} {
                            $actuallMessage = $Message | Format-Table -AutoSize | Out-String -Width 4096
                            break
                        }

                        {$_ -is [System.Management.Automation.PSCustomObject]} {
                            $actuallMessage = $Message | Format-Table -AutoSize | Out-String -Width 4096
                            break
                        }

                        Default {
                            $actuallMessage = $Message | Format-List | Out-String -Width 4096
                        }
                    }
                }
            #endregion

            #region parameterset function
                if ($PSCmdlet.ParameterSetName -eq 'function') {
                    $Level = 'DEBUG'

                    $callStack = Get-PSCallStack
                    Write-Debug -Message "Callstack count : $($callStack.count)"
                    if ($callStack.count -ge 1) {
                        $callStack = $callStack[1]
                    }

                    switch ($LogFunction) {
                        'Start' {
                            $Indent = 'IncreaseDelayed'
                            break
                          }
                        'End' {
                            $Indent = 'Decrease'
                            break
                        }
                    }

                    $localIndent = Set-ZIndentLevel -Indent $Indent

                    if($localIndent -gt 0) {
                        $indentString = "{0}>> " -f (" " * $localIndent)
                    }
                    else {
                        $indentString = [string]::Empty
                    }

                    $actuallMessage = " <~~~~> {0} function : {1} ({2})" -f $LogFunction , $callStack.Command, $localIndent
                    $actuallMessage = $actuallMessage.Trim()
                }
            #endregion

            #region parameterset debugoptions
                if ($PSCmdlet.ParameterSetName -eq 'debugoptions') {
                    $Level = 'DEBUG'

                    switch ($DebugOptions) {
                        'DumpVariablesScopeGlobal' {
                            Write-Verbose 'Dumping global variables'
                            $actuallMessage = Get-Variable -Scope 'Global' -ErrorAction Continue | Format-List | Out-String
                        }

                        'DumpVariablesScopeLocal' {
                            Write-Verbose -Message 'Dumping local variables'
                            $actuallMessage =  Get-Variable -Scope 'Local' -ErrorAction Continue | Format-List | Out-String
                        }
                    }
                }
            #endregion

            #region process message

                $debugEnabled = $Global:ZLogConfig.DebugMessagesEnabled -eq $false -AND $Level -eq 'DEBUG'

                if ($debugEnabled) {
                    Write-Verbose 'DEBUG level messages are disabled'
                    return
                }

                #region make sure that all level strings have the same lenght
                    $paddingDesiredLength = ('INFO','WARNING','ERROR','DEBUG' | Measure-Object -Maximum -Property Length).Maximum
                    if ($paddingDesiredLength -gt 0) {
                        $paddedLevel = Pad-Both -InputObject $Level -DesiredLength $paddingDesiredLength
                    } else {
                        $paddedLevel = $Level
                    }
                #endregion

                $splitMessage = $actuallMessage -split([environment]::NewLine) # split message by lines
                $finalMessage = New-Object System.Text.StringBuilder

                if($splitMessage.Count -gt 1 -AND !([string]::IsNullOrEmpty($splitMessage))) {

                    Write-Verbose "Received multiline input"

                    #region identify the line with lowest count of empty spaces from left side
                        foreach($line in $splitMessage) {
                            Write-Debug "LINE - >$line<"

                            if(!([string]::IsNullOrEmpty($line)) -AND !([string]::IsNullOrWhiteSpace($line))) {
                                $countOfSpacesFromStart = $null
                                $countOfSpacesFromStart = $line.Length - $line.TrimStart(' ').Length
                    
                                Write-Debug "Count of Spaces from Start : $countOfSpacesFromStart"

                                if($lowestCountOfSpaces -gt $countOfSpacesFromStart){
                                    $lowestCountOfSpaces = $countOfSpacesFromStart
                                }
                                Write-Debug "Lowest Count of spaces : $lowestCountOfSpaces"
                            }
                        }
                        Write-Debug "Final lowest count of spaces : $lowestCountOfSpaces"
                    #endregion

                    #region remove empty spaces from left side , count is determined by the previous step
                        $firstLineString = ("{0} <:> {1} <:> {2}" -f $currentTime, $paddedLevel , $indentString)
                        $firstLineProcessed = $false
                        $lineLength = $firstLineString.Length

                        foreach($line in $splitMessage) {
                            if(!([string]::IsNullOrEmpty($line)) -AND !([string]::IsNullOrWhiteSpace($line))) { # if the line is not empty/ just spaces
                                
                                $line = $line.Substring($lowestCountOfSpaces)

                                if ($firstLineProcessed -eq $false) {
                                    $firstLineProcessed = $true
                                    $line = $line.TrimEnd([environment]::NewLine)

                                    [void]$finalMessage.AppendLine(("{0}{1}" -f $firstLineString,$line)) # add extra empty spaces to match the lengt of the message line
                                } else {
                                    $line = ("{0}{1}" -f (' ' * $lineLength ) , $line)
                                    $line = $line.TrimEnd([environment]::NewLine)

                                    [void]$finalMessage.AppendLine($line) # add extra empty spaces to match the lengt of the message line
                                }
                            }
                            else {
                                if ($firstLineProcessed -eq $false) {
                                    $firstLineProcessed = $true
                                    [void]$finalMessage.AppendLine(("{0}{1}" -f $firstLineString,$line)) # add extra empty spaces to match the lengt of the message line             
                                } else {
                                    [void]$finalMessage.AppendLine($line)   
                                }
                            }
                        }
                    #endregion
                } else {
                    [void]$finalMessage.Append(("{0} <:> {1} <:> {2}{3}" -f $currentTime, $paddedLevel , $indentString , $actuallMessage)) # one line input, so just build message
                }
            #endregion

        #region output
            #region console
                if($logToConsole -eq $true) {
                    switch ($Level)
                    {
                        'WARNING' {
                            Write-Host -Object $finalMessage.ToString() -ForegroundColor Yellow
                            break
                        }

                        'ERROR' {
                            Write-Host -Object $finalMessage.ToString() -ForegroundColor Red
                            break
                        }

                        'DEBUG' {
                            Write-Host -Object $finalMessage.ToString() -ForegroundColor Magenta
                            break
                        }

                        DEFAULT {
                            Write-Host -Object $finalMessage.ToString()
                        }
                    }
                }
            #endregion

            #region file
                if($logToFile -eq $true) {
                    try {
                        $finalMessage.ToString() | Out-File -LiteralPath $LiterallPath -Append -force # out-file does not block file for reading
                    }
                    catch {
                        Update-Exception -Exception $_ -ErrorDetailMessage 'Failed to write log message to file' -Throw
                    }
                }
            #endregion

            #region pipeline
                if ($logToPipeline -eq $true) {
                    Write-Output -InputObject $finalMessage.ToString()
                }
            #endregion
        #endregion
    }
    End {
        #region log rotation
            if ($AllowLogRotationAfterThisMessage.IsPresent) {
                Rotate-Zlog   
            }
        #endregion
    }
}

<#
    .Synopsis
    Update exception object
    .DESCRIPTION
    Set's ErrorDetails exception property to desired message
    .PARAMETER Exception
        Exception object that will be modified
    .PARAMETER ErrorDetailMessage
        Custom message that will be assigned to errordetails property of Exception object
    .PARAMETER Throw
        Specifies if function should in the end throw the exception.
        If not used ,function writes modified exception object to pipeline.
    .EXAMPLE
        try {
            get-childitem HKLM:/ -ErrorAction stop
        }
        catch {
            $ex = Update-Exception -Exception $_ -ErrorDetailMessage 'Failed to list HKLM:\'
            throw $ex
        }

        writeErrorStream      : True
        PSMessageDetails      : 
        Exception             : System.Security.SecurityException: Požadovaný přístup k registru není povolen.
                                v System.ThrowHelper.ThrowSecurityException(ExceptionResource resource)
                                v Microsoft.Win32.RegistryKey.OpenSubKey(String name, Boolean writable)
                                v Microsoft.PowerShell.Commands.RegistryWrapper.OpenSubKey(String name, Boolean writable)
                                v Microsoft.PowerShell.Commands.RegistryProvider.GetRegkeyForPath(String path, Boolean writeAccess)
                                v Microsoft.PowerShell.Commands.RegistryProvider.GetChildItems(String path, Boolean recurse, UInt32 depth)
                                Zóna sestavení, u něhož došlo k chybě:
                                MyComputer
        TargetObject          : HKEY_LOCAL_MACHINE\BCD00000000
        CategoryInfo          : PermissionDenied: (HKEY_LOCAL_MACHINE\BCD00000000:String) [Get-ChildItem], SecurityException
        FullyQualifiedErrorId : System.Security.SecurityException,Microsoft.PowerShell.Commands.GetChildItemCommand
        ErrorDetails          : Failed to list HKLM:\
        InvocationInfo        : System.Management.Automation.InvocationInfo
        ScriptStackTrace      : at <ScriptBlock>, C:\temp\testickky.ps1: line 38
        PipelineIterationInfo : {}

        In this example function modifies Exception with custom message  'Failed to list HKLM:\' while preserving original exception as can be seen
        in the output dump.
#>
function Update-Exception
{
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    Param
    (
        # Exception object
        [Parameter(Mandatory=$true,
                   ValueFromPipeline = $true,
                   Position=0)]
        [System.Management.Automation.ErrorRecord]
        $Exception,

        # error detail message
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ErrorDetailMessage,

        # do not return exception but throw it instead
        [Parameter(Mandatory = $false)]
        [switch]
        $Throw
    )
    BEGIN{
        Write-ZLog -LogFunction Start -Level DEBUG
    }
    Process {
        $Exception.errordetails = $ErrorDetailMessage

        if ($Throw.IsPresent) {
            Write-Verbose -Message 'Throwing exception'
            throw $Exception
        } else {
            Write-Verbose -Message 'Writing exception to pipeline'
            Write-Output $Exception
        }
    }
    END{
        Write-ZLog -LogFunction End -Level DEBUG
    }
}

<#
    .SYNOPSIS
    Log exception properties using write-zlog

    .DESCRIPTION
    Function accepts already existing Exception object as an input and logs , using write-zlog function , all important properties.

    .PARAMETER Exception
    Exception object

    .PARAMETER CustomMessage
    Custom message can be added to the log using this parameter.

    .PARAMETER Throw
    Specifies if function should in the end throw the exception.
    If not used there is no output to pipeline, the only output is the output from write-zlog

    .EXAMPLE
        In this example exception is first updated with custom message by using Update-Exception function and modified exception is then passed
        via pipeline to Log-Exception function which will log all important properties if the exception.
        Parameter -Throw is specified therefore after the exception is logged the function will throw the exception.

            try {
                get-childitem HKLM:/ -ErrorAction stop
            }
            catch {
                Update-Exception -Exception $_ -ErrorDetailMessage 'Failed to list HKLM:\' | Log-Exception -Throw
            }
#>
function Log-Exception {
    param(
        # exception object
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.ErrorRecord]
        $Exception,

        # additional custom message
        [Parameter(Mandatory = $false)]
        [string]
        $CustomMessage,

        # After logging the exception throw exception
        [Parameter(Mandatory = $false)]
        [switch]
        $Throw
    )
    BEGIN{
        Write-ZLog -LogFunction Start -Level DEBUG -Indent IncreaseDelayed

        Write-ZLog -Message "!!!!!!!!-EXCEPTION-!!!!!!!!" -Level ERROR
        Write-ZLog -Message "!!!!!!!!!!!!!!!!!!!!!!!!!!!" -Level ERROR
    }
    PROCESS{       
        if ($PSBoundParameters.Keys.Contains('CustomMessage')) {
            Write-ZLog -Message "Custom message : $CustomMessage" -Level ERROR
        }

        Write-ZLog -Message "MESSAGE : $($Exception.Exception.Message)" -Level ERROR
        Write-ZLog -Message "ERROR DETAILS : $($Exception.ErrorDetails)" -Level ERROR
        Write-ZLog -Message "POSITION MESSAGE : $($Exception.InvocationInfo.PositionMessage)" -Level ERROR
        Write-ZLog -Message "SCRIPT STACK TRACE : $($Exception.ScriptStackTrace)" -Level ERROR
        Write-ZLog -Message "CATEGORY INFO : $($Exception.CategoryInfo.ToString())" -Level ERROR
        Write-ZLog -Message "TARGET OBJECT : $($Exception.TargetObject)" -Level ERROR
        Write-ZLog -Message "HRESULT : $($Exception.Exception.HResult)" -Level ERROR

        $ExceptionObject = $Exception.Exception
        $originalIndent = $Global:ZLogIndent # store original indent level so it can be set back after iterating through inner exceptions 
        if ($ExceptionObject.InnerException -ne $null) {
            Write-ZLog -Message "INNER EXCEPTION" -Level ERROR

            while ($ExceptionObject.InnerException -ne $null) {
                Write-ZLog -Message "TARGET SITE : $($ExceptionObject.InnerException.TargetSite)" -Level ERROR -Indent Increase
                Write-ZLog -Message "MESSAGE : $($ExceptionObject.InnerException.Message)" -Level ERROR
                $ExceptionObject = $ExceptionObject.InnerException
            }
        }
        $Global:ZLogIndent = $originalIndent
    }
    END{
        Write-ZLog -Message "!!!!!!!!!!!!!!!!!!!!!!!!!!!" -Level ERROR -Indent Decrease
        Write-ZLog -Message "!!!!!!!!-EXCEPTION-!!!!!!!!" -Level ERROR

        Write-ZLog -LogFunction End -Level DEBUG -Indent Decrease

        if ($Throw.IsPresent) {
            throw $Exception
        }
    }
}

# Select from database
function Invoke-SqlQuery {
	[Cmdletbinding()]
	[outputtype([hashtable])]
    param(

        # sql query to be executed
        [Parameter(Mandatory = $true ,ParameterSetName = 'query')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Query,

        # sql query to be executed
        [Parameter(Mandatory = $true, ParameterSetName = 'procedure')]
        [ValidateNotNullOrEmpty()]
        [string]
        $StoredProcedureName,

        # parameters for stored procedure if any required
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $Parameters,

        # sql server instance
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ServerInstance,

        # failover partner ,if any
        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [string]
        $FailoverInstance,

        # DB name / initial catalog
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Database,

        # query execution timeout
        [Parameter(Mandatory = $false)]
        [ValidateScript({($_ -gt 0 -AND $_ -lt 65535)})]
        [int]
        $QueryTimeout = 60,

        # how long to wait for connection to be established
        [Parameter(Mandatory = $false)]
        [ValidateScript({$_ -gt 0 -AND $_ -lt 120})]
        [int]
        $ConnectionTimeout = 10
    )
    BEGIN {

        Write-ZLog -LogFunction Start -Level DEBUG -Indent IncreaseDelayed
        Log-BoundParameters -Parameters $PSBoundParameters

        #region initialization
            $ErrorActionPreference = 'stop'
        #endregion

        #region connection string
            $sqlConnectionStringBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder

            $sqlConnectionStringBuilder.'Integrated Security' = $true
            $sqlConnectionStringBuilder.'Data Source' = $ServerInstance
            $sqlConnectionStringBuilder.'Initial Catalog' = $Database
            $sqlConnectionStringBuilder.'Connect Timeout' = $ConnectionTimeout

            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('FailoverInstance')) {
                $sqlConnectionStringBuilder.'Failover Partner' = $FailoverInstance
            }

            Write-ZLog -Message "Connection string :  $($sqlConnectionStringBuilder.ConnectionString)" -Level DEBUG

        #endregion

        #region sql connection
            $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
            $sqlConnection.ConnectionString = $sqlConnectionStringBuilder.ConnectionString

			if ($DebugPreference -ne 'silentlycontinue') {
				$connectionOpenStart = get-date	
			}

            Write-ZLog -Message 'Opening connection to DB' -Level DEBUG

            try {
                $sqlConnection.Open()
            }
            catch {
                Update-Exception -Exception $_ -ErrorDetailMessage 'Failed to open connection to DB' | Log-Exception -Throw
            }
            finally {
                Write-ZLog -Message 'Connection to DB opened' -Level DEBUG
            }
        #endregion
    }
    PROCESS {
        #region var declaration
            $sqlCommand = $null
            $outputHashtable = @{'HasData' = $null ; 'Data' = $null ; 'RecordsCount' = $null}
        #endregion

        #region prepare for exec
            # if stored procedure is executed
            if ($PSCmdlet.ParameterSetName -eq 'procedure') {
                Write-ZLog -Message "Stored Procedure : $StoredProcedureName" -Level DEBUG
                $sqlCommand = New-Object System.Data.SqlClient.SqlCommand($StoredProcedureName , $sqlConnection)
                $sqlCommand.CommandType = [System.Data.CommandType]::StoredProcedure

            } else {
                Write-ZLog -Message "Query : $Query" -Level DEBUG
                $sqlCommand = New-Object System.Data.SqlClient.SqlCommand($Query , $sqlConnection)
			}
			
			if ($PSBoundParameters.ContainsKey('Parameters')) {
				foreach ($parameterKey in $Parameters.Keys) {
                    $parameterKey = $parameterKey.TrimStart('@')

                    Write-ZLog -Message "Parameter Name  : $parameterKey" -Level DEBUG
                    Write-ZLog -Message "Parameter Value : $($Parameters[$parameterKey])" -Level DEBUG

					$sqlCommand.Parameters.AddWithValue("@$parameterKey",[string]$Parameters[$parameterKey]).Direction =
					[System.Data.ParameterDirection]::Input
				}                
			}
            
            $sqlCommand.CommandTimeout = $QueryTimeout # seconds, input from parameter

            $dataSet = New-Object System.Data.DataSet
            $dataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($sqlCommand)
        #endregion

        #region execute
            Write-ZLog -Message 'Executing query' -Level DEBUG
            try {
                [void]$dataAdapter.Fill($dataSet)        
            }
            catch {
                Update-Exception -Exception $_ -ErrorDetailMessage 'Failed to retrieve data' | Log-Exception -Throw
            }
            finally {
                if($sqlConnection -ne $null -AND $sqlConnection.State -ne [System.Data.ConnectionState]::Closed) {
                    Write-ZLog -Message 'DB connection is opened , closing' -Level DEBUG
                    $sqlConnection.Dispose()
                }
            }
            Write-ZLog -Message 'Execution completed' -Level DEBUG
        #endregion

        #region generate output
            if($dataset.Tables.Count -gt 0) {
                if([string]::IsNullOrEmpty($dataSet.Tables[0])) {
                    Write-ZLog -Message "Sql query returned empty result" -Level DEBUG
                    $outputHashtable.HasData = $false
                } else {
                    $outputHashtable.HasData = $true
                    $outputHashtable.Data = $dataSet.Tables[0]
                    $outputHashtable.RecordsCount = $dataSet.Tables[0].Rows.Count
                }
            } else {
                Write-ZLog -Message "No data received from query" -Level DEBUG
                $outputHashtable.HasData = $false
            }

            Write-Output $outputHashtable
        #endregion
    }
    END{
        Write-ZLog -LogFunction End -Indent Decrease -Level DEBUG
    }
}

function Invoke-SqlUpdate {
	[Cmdletbinding()]
	[Outputtype([bool])]
    param(
        # sql query to be executed
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Query,

        # parameters for stored procedure if any required
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $Parameters,

        # sql server instance
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ServerInstance,

        # failover partner ,if any
        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [string]
        $FailoverInstance,

        # DB name / initial catalog
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Database,

        # query execution timeout
        [Parameter(Mandatory = $false)]
        [ValidateScript({($_ -gt 0 -AND $_ -lt 65535)})]
        [int]
        $QueryTimeout = 60,

        # how long to wait for connection to be established
        [Parameter(Mandatory = $false)]
        [ValidateScript({$_ -gt 0 -AND $_ -lt 120})]
        [int]
        $ConnectionTimeout = 10,

        # force execution without transaction
        [Parameter(Mandatory = $false)]
        [switch]
        $NoTransaction

    )
    BEGIN {

        #region initialization
            $ErrorActionPreference = 'stop'
            Set-StrictMode -Version latest
        #endregion

        #region connection string
            $sqlConnectionStringBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder

            $sqlConnectionStringBuilder.'Integrated Security' = $true
            $sqlConnectionStringBuilder.'Data Source' = $ServerInstance
            $sqlConnectionStringBuilder.'Initial Catalog' = $Database
            $sqlConnectionStringBuilder.'Connect Timeout' = $ConnectionTimeout

            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('FailoverInstance')) {
                $sqlConnectionStringBuilder.'Failover Partner' = $FailoverInstance
            }

            Write-ZLog -Message "Connection string :  $($sqlConnectionStringBuilder.ConnectionString)" -Level DEBUG

        #endregion

        #region sql connection
            $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
            $sqlConnection.ConnectionString = $sqlConnectionStringBuilder.ConnectionString

			if ($DebugPreference -ne 'silentlycontinue') {
				$connectionOpenStart = get-date	
            }
            Write-ZLog -Message 'Opening connection to DB' -Level DEBUG
            try {
                $sqlConnection.Open()
            }
            catch {
                Update-Exception -Exception $_ -ErrorDetailMessage 'Failed to open connection to DB' | Log-Exception -Throw
            }
            finally {
				Write-ZLog -Message 'Connection to DB opened' -Level DEBUG
            }
        #endregion
    }
    PROCESS {
        #region var declaration
            $sqlCommand = $null
            $result = $false
        #endregion

        #region prepare for exec

            Write-ZLog -Message "Command : $Query" -Level DEBUG

            if(!$NoTransaction.IsPresent){
                Write-ZLog -Message 'Transaction created' -Level DEBUG
                $sqlTransaction = $sqlConnection.BeginTransaction()
            }
            
            $sqlCommand = New-Object System.Data.SqlClient.SqlCommand($Query , $sqlConnection)
            $sqlCommand.CommandTimeout = $QueryTimeout # seconds, input from parameter

            if(!$NoTransaction.IsPresent){
                $sqlCommand.Transaction = $sqlTransaction
            }

            # parameters
            if($PSBoundParameters.ContainsKey('Parameters')) {
                foreach ($parameterKey in $Parameters.Keys) {
                            $parameterKey = $parameterKey.TrimStart('@')
                            Write-ZLog -Message "Parameter Name  : $parameterKey" -Level DEBUG
                            Write-ZLog -Message "Parameter Value : $($Parameters[$parameterKey])" -Level DEBUG
                            $sqlCommand.Parameters.AddWithValue("@$parameterKey",[string]$Parameters[$parameterKey]).Direction =
                            [System.Data.ParameterDirection]::Input
                        }
            }
        #endregion

        #region execute
            Write-ZLog -Message 'Executing command' -Level DEBUG
            try {
                $rowsAffected = $sqlCommand.ExecuteNonQuery()
                Write-ZLog -Message "Number of affected rows : $rowsAffected" -Level DEBUG
                $result = $true
                
                if (!$NoTransaction.IsPresent) {
                    Write-ZLog -Message 'Commiting transaction' -Level DEBUG
                    $sqlTransaction.Commit() # if execution was ok , commit transaction   
                }
            }
            catch {
                if (!$NoTransaction.IsPresent) {
                    Write-ZLog -Message 'Rolling back transaction' -Level DEBUG
                    $sqlTransaction.Rollback()

                    Update-Exception -Exception $_ -ErrorDetailMessage 'Failed to execute command' | Log-Exception -Throw
                }
            }
            finally {
                if($sqlConnection -ne $null -AND $sqlConnection.State -ne [System.Data.ConnectionState]::Closed) {
                    Write-ZLog -Message 'Closing DB connection' -Level DEBUG
                    $sqlConnection.Dispose()
                }
            }
        #endregion

        #region generate output
            Write-Output $result
        #endregion
    }
}

function Log-BoundParameters {
    [CmdletBinding()]
    param(
        # psboundparameters
        [Parameter(Mandatory = $true)]
        $Parameters
    )
    BEGIN{
        Write-ZLog -LogFunction Start -Indent IncreaseDelayed -Level DEBUG
        Write-ZLog -Message 'Parameters:' -Level DEBUG
    }
    PROCESS{
        $Parameters | Format-Table -AutoSize | Out-String | Write-ZLog -Level DEBUG
    }
    END{
        Write-ZLog -LogFunction End -Level DEBUG -Indent Decrease
    }
}

function Pad-Both
{
     param(
        [Parameter(Mandatory = $true,
                   ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $InputObject,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int]
        $DesiredLength
     )
     PROCESS {
        try {
            $SpacesToAdd = $DesiredLength - $InputObject.Length
            $PadLeft = $SpacesToAdd/2 + $InputObject.Length
            $OutputObject = ($InputObject.PadLeft($PadLeft).PadRight($DesiredLength))    
            Write-Output $OutputObject
        }
        catch {
            throw
        }
     }
}

function New-ZlogConfigTable {
    PROCESS{
        $outputHashtable = [ordered]@{
            'EnableIndent' = $false
            'Indent' = 0
            'LogLiterallPath' = $null
            'LogFolder' = $null
            'LogNameNoRotation' = $null
            'LogFileCreatedUTC' = $null
            'LogFileExtension' = 'log'
            'LogTimezone' = 'UTCTIME'
            'LogRotationEnabled' = $false
            'LogRotationDays' = 0
            'LogRotationHours' = 0
            'LogRotationMinutes' = 0
            'LogRotationIdentifier' = 0
            'DebugMessagesEnabled' = $false
        }
        Write-Output $outputHashtable
    }
}
