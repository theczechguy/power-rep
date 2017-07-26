function Get-SqlQueryResult {
    [Cmdletbinding()]
    param(
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
        [Parameter(Mandatory = $false , ParameterSetName = 'procedure')]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $StoredProcedureParameters,

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

        #endregion

        #region sql connection
            $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
            $sqlConnection.ConnectionString = $sqlConnectionStringBuilder.ConnectionString

            $connectionOpenStart = get-date

            try {
                $sqlConnection.Open()
            }
            catch {
                throw "Failed to open DB connection :: $($_.exception.message)"
            }
            finally {
                $connectionOpenEnd = get-date
                $timeDiff = New-TimeSpan -start $connectionOpenStart -End $connectionOpenEnd
                Write-Debug "Open Connection (Total seconds/Total miliseconds) : $($timeDiff.TotalSeconds)/$($timeDiff.TotalMilliseconds)"
            }
        #endregion
    }
    PROCESS {
        #region var declaration
            $sqlCommand = $null
            $outputHashtable = @{'HasData' = $null ; 'Data' = $null}
        #endregion

        #region prepare for exec
            # if stored procedure is executed
            if ($PSCmdlet.ParameterSetName -eq 'procedure') {
                $sqlCommand = New-Object System.Data.SqlClient.SqlCommand($StoredProcedureName , $sqlConnection)
                $sqlCommand.CommandType = [System.Data.CommandType]::StoredProcedure

                if ($PSBoundParameters.ContainsKey('StoredProcedureParameters')) {
                    foreach ($parameterKey in $StoredProcedureParameters.Keys) {
                        $sqlCommand.Parameters.AddWithValue("@$parameterKey",[string]$StoredProcedureParameters[$parameterKey]).Direction =
                        [System.Data.ParameterDirection]::Input
                    }                
                }
            } else {
                $sqlCommand = New-Object System.Data.SqlClient.SqlCommand($Query , $sqlConnection)
            }
            
            $sqlCommand.CommandTimeout = $QueryTimeout # seconds, input from parameter

            $dataSet = New-Object System.Data.DataSet
            $dataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($sqlCommand)

            $queryExecutionStart = get-date
        #endregion

        #region execute
            try {
                [void]$dataAdapter.Fill($dataSet)            
            }
            catch {
                throw "Failed to retrieve data :: $($_.exception.message)"
            }
            finally {
                if($sqlConnection -ne $null -AND $sqlConnection.State -ne [System.Data.ConnectionState]::Closed) {
                    $sqlConnection.Dispose()
                }

                $queryExecutionStop = get-date
                $timeDiff = New-TimeSpan -Start $queryExecutionStart -End $queryExecutionStop
                Write-Debug "Execute query (Total seconds/Total miliseconds) : $($timeDiff.TotalSeconds)/$($timeDiff.TotalMilliseconds)"
            }
        #endregion

        #region generate output
            if($dataset.Tables.Count -gt 0) {
                if([string]::IsNullOrEmpty($dataSet.Tables[0])) {
                    Write-warning "Sql query returned empty result"
                    $outputHashtable.HasData = $false
                } else {
                    $outputHashtable.HasData = $true
                    $outputHashtable.Data = $dataSet.Tables[0]
                }
            } else {
                Write-Warning "No data received from query"
                $outputHashtable.HasData = $false
            }

            Write-Output $outputHashtable
        #endregion
    }
}
