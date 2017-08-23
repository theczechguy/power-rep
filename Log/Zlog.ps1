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
                    Update-Exception -Exception $_ -ErrorDetailMessage "Failed to create log folder : $LiteralLogFolderPath" -Throw
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

            try {
                $fullLiteralPath = Join-Path -Path $LiteralLogFolderPath -ChildPath $customizedLogname    
            }
            catch {
                Update-Exception -Exception $_ -ErrorDetailMessage 'Unable to combine logname with logpath' -Throw
            }
        #endregion

        #region create file

            if ($DoNotCreateFile.IsPresent) {
                Write-Verbose -Message 'File will not be created !'
            } else {

                if (!(Test-Path -LiteralPath $fullLiteralPath -ErrorAction SilentlyContinue)) {
                    try {
                        $null = New-Item -ItemType File -Path $fullLiteralPath
                    }
                    catch {
                        Update-Exception -Exception $_ -ErrorDetailMessage "Failed to create logfile : $fullLiteralPath" -Throw
                    }
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
    [CmdletBinding(DefaultParameterSetName = 'message')]
    [OutputType([string])]
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
        [string]
        $LiterallPath = $Global:ZLogLogFullPath,

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
        $PassThrough
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
                    
                    Write-debug "Datatype of current message : $($Message.GetType())"
                    Write-debug "Converting to string"

                    switch ($Message) {
                        {($_ -is [int] -or $_ -is [string])} {
                            $actuallMessage = $Message
                            break
                        }

                        {$_ -is [hashtable]} {
                            $actuallMessage = $Message | Format-Table -Wrap | Out-String -Width 4096
                            break
                        }

                        {$_ -is [System.Management.Automation.PSCustomObject]} {
                            $actuallMessage = $Message | Format-Table -Wrap | Out-String -Width 4096
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
                    
                    $callStack = Get-PSCallStack
                    Write-Debug -Message "Callstack count : $($callStack.count)"
                    if ($callStack.count -ge 1) {
                        $callStack = $callStack[1]
                    }

                    $actuallMessage = " <~~~~> {0} function : {1} <~~~~>" -f $LogFunction , $callStack.Command
                    $actuallMessage = $actuallMessage.Trim()
                    #$finalMessage = "{0} <:> {1} <:> {2}{3}" -f $currentTime, $Level , $indentString, $mesage
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
                        [void]$finalMessage.AppendLine(("{0} <:> {1} <:> {2}" -f $currentTime, $Level , $indentString))# first line empty
                        $lineLength = $finalMessage.Length

                        foreach($line in $splitMessage) {
                            if(!([string]::IsNullOrEmpty($line)) -AND !([string]::IsNullOrWhiteSpace($line))) { # if the line is not empty/ just spaces        
                                
                                $line = $line.Substring($lowestCountOfSpaces)
                                $line = ("{0}{1}" -f (' ' * $lineLength ) , $line)
                                $line = $line.TrimEnd([environment]::NewLine)
                        
                                [void]$finalMessage.AppendLine($line) # add extra empty spaces to match the lengt of the message line
                            }
                            else {
                                [void]$finalMessage.AppendLine($line) # add extra empty spaces to match the lengt of the message line
                            }
                        }
                    #endregion
                } else {
                    [void]$finalMessage.Append(("{0} <:> {1} <:> {2}{3}" -f $currentTime, $Level , $indentString , $actuallMessage)) # one line input, so just build message
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
                            Write-Host -Object $finalMessage.ToString() -ForegroundColor Magenta -BackgroundColor Black
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
}