Function Update-LogicMonitorCollectorVersion {
    <#
        .DESCRIPTION
            Accepts a collector ID or description, a version number, and a start time, then schedules the installation of a new version of the collector.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 30 August 2018
                - Initial release.
            V1.0.0.1 date: 7 September 2018
                - Updated in-line documents.
                - Removed $StartTime. We still support the idea, just with different syntax. See examples.
            V1.0.0.2 date: 23 August 2019
            V1.0.0.3 date: 26 August 2019
            V1.0.0.4 date: 18 October 2019
            V1.0.0.5 date: 4 December 2019
            V1.0.0.6 date: 10 December 2019
            V1.0.0.7 date: 23 July 2020
            V1.0.0.8 date: 21 September 2021
        .LINK
            https://github.com/wetling23/logicmonitor-posh-module
        .PARAMETER AccessId
            Represents the access ID used to connected to LogicMonitor's REST API.
        .PARAMETER AccessKey
            Represents the access key used to connected to LogicMonitor's REST API.
        .PARAMETER AccountName
            Represents the subdomain of the LogicMonitor customer.
        .PARAMETER CollectorId
            Represents the collector's ID.
        .PARAMETER Description
            Represents the collectors description.
        .PARAMETER MajorVersion
            Represents the major version of the collector to install (e.g. 27)
        .PARAMETER MinorVersion
            Represents the minor version of the collector to install (e.g. 2). Valid values are 0-999.
        .PARAMETER StartDate
            Represents the upgrade start date and time. If no value is provided, the current date and time are.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> Update-LogicMonitorCollectorVersion -AccessId <accessId> -AccessKey <accessKey> -AccountName <accountName> -CollectorId 6 -MajorVersion 27 -MinorVersion 2 -Verbose

            In this example, the cmdlet will upgrade the collector to 27.002. The installation will be scheduled to run immediately. Verbose output is sent to the host.
        .EXAMPLE
            PS C:\> Update-LogicMonitorCollectorVersion -AccessId <accessId> -AccessKey <accessKey> -AccountName <accountName> -CollectorId 6 -MajorVersion 27 -MinorVersion 2 -StartDate "08/30/2018 14:00"

            In this example, the cmdlet will upgrade the collector to 27.002. The installation will run at 14:00 on 30 August 2018.
        .EXAMPLE
            PS C:\> Update-LogicMonitorCollectorVersion -AccessId <accessId> -AccessKey <accessKey> -AccountName <accountName> -CollectorId 6 -MajorVersion 27 -MinorVersion 2 -StartDate "08/30/2018 2:00 PM"

            In this example, the cmdlet will upgrade the collector to 27.002. The installation will run at 2:00 PM on 30 August 2018.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param (
        [Parameter(Mandatory)]
        [string]$AccessId,

        [Parameter(Mandatory)]
        [securestring]$AccessKey,

        [Parameter(Mandatory)]
        [string]$AccountName,

        [Parameter(Mandatory, ParameterSetName = "Default", ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [int]$Id,

        [Parameter(Mandatory, ParameterSetName = "Name", ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [string]$Description,

        [int]$MajorVersion,

        [ValidateRange(0, 999)]
        [int]$MinorVersion,

        [datetime]$StartDate,

        [boolean]$BlockStdErr = $false,

        [string]$EventLogSource,

        [string]$LogPath
    )

    Begin {
        # Initialize variables.
        [hashtable]$upgradeProperties = @{ }
        [hashtable]$propertyData = @{ }
        [string]$data = ""
        [string]$httpVerb = "PATCH"
        [string]$queryParams = ""
        [string]$resourcePath = "/setting/collector/collectors"
        [System.Net.SecurityProtocolType]$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'
        [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols

        # Setup parameters for calling Get-LogicMonitor* cmdlet(s).
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') {
            If ($EventLogSource -and (-NOT $LogPath)) {
                $commandParams = @{
                    Verbose        = $true
                    EventLogSource = $EventLogSource
                }
            }
            ElseIf ($LogPath -and (-NOT $EventLogSource)) {
                $commandParams = @{
                    Verbose = $true
                    LogPath = $LogPath
                }
            }
            Else {
                $commandParams = @{
                    Verbose = $true
                }
            }
        }
        Else {
            If ($EventLogSource -and (-NOT $LogPath)) {
                $commandParams = @{
                    Verbose        = $false
                    EventLogSource = $EventLogSource
                }
            }
            ElseIf ($LogPath -and (-NOT $EventLogSource)) {
                $commandParams = @{
                    Verbose = $false
                    LogPath = $LogPath
                }
            }
            Else {
                $commandParams = @{
                    Verbose = $false
                }
            }
        }
    }
    Process {
        $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $message = ("{0}: Validating start time/date." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        If ($StartDate -eq $null) {
            # Neither start date is not provided.
            $StartDate = (Get-Date)
        }

        $startEpoch = [Math]::Round((New-TimeSpan -Start (Get-Date -Date "1/1/1970") -End ($StartDate).ToUniversalTime()).TotalSeconds)

        # Update $resourcePath to filter for a specific collector, when a collector ID or Description is provided by the user.
        Switch ($PsCmdlet.ParameterSetName) {
            Default {
                $resourcePath += "/$Id"
            }
            "Name" {
                $message = ("{0}: Attempting to retrieve the collector ID of {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Description)
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                $collector = Get-LogicMonitorCollectors -AccessId $AccessId -AccessKey $AccessKey -AccountName $AccountName -CollectorDescriptionName $Description @commandParams

                $resourcePath += "/$($collector.id)"

                $message = ("{0}: The value of `$resourcePath is {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $resourcePath)
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
            }
        }

        $message = ("{0}: Finished updating `$resourcePath. The value is:`r`n {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $resourcePath)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        # Sleeping because we get an error about scheduling, if we don't wait.
        Start-Sleep -Seconds 5

        $upgradeProperties = @{
            "majorVersion" = $MajorVersion
            "minorVersion" = $MinorVersion
            "startEpoch"   = $startEpoch
            "description"  = "Collector upgrade initiated by LogicMonitor PowerShell module ($env:USERNAME on $env:COMPUTERNAME)."
        }

        $propertyData.Add("onetimeUpgradeInfo", $upgradeProperties)

        # I am assigning $propertyData to $data, so that I can use the same $requestVars concatination and Invoke-RestMethod as other cmdlets in the module.
        $data = ($propertyData | ConvertTo-Json -Depth 5)
        $enc = [System.Text.Encoding]::UTF8
        $encdata = $enc.GetBytes($data)

        $message = ("{0}: Finished updating `$data. The value update is {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $data)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        # Construct the query URL.
        $url = "https://$AccountName.logicmonitor.com/santaba/rest$resourcePath$queryParams"

        # Get current time in milliseconds
        $epoch = [Math]::Round((New-TimeSpan -start (Get-Date -Date "1/1/1970") -end (Get-Date).ToUniversalTime()).TotalMilliseconds)

        # Concatenate Request Details
        $requestVars = $httpVerb + $epoch + $data + $resourcePath

        # Construct Signature
        $hmac = New-Object System.Security.Cryptography.HMACSHA256
        $hmac.Key = [Text.Encoding]::UTF8.GetBytes([System.Runtime.InteropServices.Marshal]::PtrToStringAuto(([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccessKey))))
        $signatureBytes = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($requestVars))
        $signatureHex = [System.BitConverter]::ToString($signatureBytes) -replace '-'
        $signature = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($signatureHex.ToLower()))

        # Construct Headers
        $headers = @{
            "Authorization" = "LMv1 $accessId`:$signature`:$epoch"
            "Content-Type"  = "application/json"
            "X-Version"     = 2
        }

        # Make Request
        $message = ("{0}: Executing the REST query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Try {
            $response = Invoke-RestMethod -Uri $url -Method $httpVerb -Header $headers -Body $encdata -ErrorAction Stop
        }
        Catch {
            If ($_.Exception.Message -match '429') {
                $message = ("{0}: Rate limit exceeded, retrying in 60 seconds." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                Start-Sleep -Seconds 60
            }
            Else {
                $message = ("{0}: Unexpected error updating LogicMonitor collector version. To prevent errors, {1} will exit. If present, the following details were returned:`r`n
                Error message: {2}`r
                Error code: {3}`r
                Invoke-Request: {4}`r
                Headers: {5}`r
                Body: {6}" -f
                    ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, ($_ | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errorMessage),
                    ($_ | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errorCode), $_.Exception.Message, ($headers | Out-String), ($data | Out-String)
                )
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                Return "Error", $response
            }
        }

        If ($response.status -ne "1") {
            $message = ("{0}: LogicMonitor reported an error (status {1})." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $response.status)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }
        }

        Return $response
    }
} #1.0.0.8