########################################################################
# HelloID-Conn-Prov-Source-OrtecWS-Departments
#
# Version: 1.0.1
########################################################################

# Initialize default values
$config = $configuration | ConvertFrom-Json

#region functions
function Resolve-OrtecWSError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }
        if (-not [string]::IsNullOrEmpty($ErrorObject.ErrorDetails.Message)) {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        }
        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            if ($null -ne $ErrorObject.Exception.Response) {
                $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
                if (-not [string]::IsNullOrEmpty($streamReaderResponse)) {
                    $httpErrorObj.ErrorDetails = $streamReaderResponse
                }
            }
        }
        try {
            # Make sure to inspect the error result object and add only the error message as a FriendlyMessage.
            # $errorDetailsObject = ($httpErrorObj.ErrorDetails | ConvertFrom-Json)
            # $httpErrorObj.FriendlyMessage = $errorDetailsObject.message
            $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails # Temporarily assignment
        }
        catch {
            $httpErrorObj.FriendlyMessage = "Error: [$($httpErrorObj.ErrorDetails)] [$($_.Exception.Message)]"
        }
        Write-Output $httpErrorObj
    }
}

function Invoke-OrtecWSRestMethod {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Method,

        [Parameter()]
        [string]
        $Uri,

        [Parameter()]
        [string]
        $ContentType,

        [Parameter()]
        [object]
        $Body,

        [Parameter()]
        [object]
        $Headers
    )

    process {
        try {
            $splatParams = @{
                Uri         = $Uri
                Method      = $Method
                ContentType = $ContentType
                Headers     = $Headers
                Body        = $Body
            }

            $responseXml = Invoke-WebRequest @splatParams -Verbose:$false -UseBasicParsing
            $response = [xml]$responseXml.content

            if ($response.Envelope.Body.SendMessageResponse.SendMessageResult -like '*<employees><employee>*') {
                Write-Output $response.Envelope.Body.SendMessageResponse.SendMessageResult
            }
            elseif ($response.Envelope.Body.SendMessageResponse.SendMessageResult -eq '<?xml version="1.0"?><PSK>The PSK is not correct</PSK>') {
                throw 'The PSK is not correct.'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
#endregion

try {
    # Build the SOAP request
    $actionMessage = "building SOAP request for HelloIDShiftExport"

    $xmlRequest = @"
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope"
               xmlns:cais="http://www.ortec.com/CAIS"
               xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/08/addressing">
    <soap:Header xmlns:wsa="http://www.w3.org/2005/08/addressing">
        <wsa:Action>http://www.ortec.com/CAIS/IApplicationIntegrationService/SendMessage</wsa:Action>
        <wsa:ReplyTo>
            <wsa:Address>http://www.w3.org/2005/08/addressing/anonymous</wsa:Address>
        </wsa:ReplyTo>
    </soap:Header>
    <soap:Body>
        <cais:SendMessage>
            <cais:message>
                <![CDATA[
<XML>
    <parameters>
        <beginDate>$((Get-Date).AddDays(-$config.HistoricalDays).ToString("yyyy-MM-ddTHH:mm:ss"))</beginDate>
        <endDate>$((Get-Date).AddDays($config.FutureDays).ToString("yyyy-MM-ddTHH:mm:ss"))</endDate>
    </parameters>
    <psk>$($config.Apikey)</psk>
</XML>
                ]]>
            </cais:message>
            <cais:commandName>HelloIDShiftExport</cais:commandName>
        </cais:SendMessage>
    </soap:Body>
</soap:Envelope>
"@

    # Set authentication headers
    $actionMessage = "setting authentication headers"

    $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
    $headers.Add("Authorization", "Basic $([System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($config.ApiUsername):$($config.ApiPassword)")))")

    # Invoke the SOAP request
    $actionMessage = "retrieving employee shift data"

    $splatParams = @{
        Uri         = "$($config.BaseUrl)/CAIS/ApplicationIntegration/$($config.ServerName)/SOAP12"
        Method      = 'POST'
        Body        = $xmlRequest
        Headers     = $headers
        ContentType = 'application/soap+xml; charset=utf-8'
    }

    [xml]$response = Invoke-OrtecWSRestMethod @splatParams

    # Extract departments from the response
    $actionMessage = "extracting departments from shift data"

    $departments = $response.XML.shifts.shift | ForEach-Object {
        [PSCustomObject]@{
            DptId   = $_.dptId
            DptCode = $_.dptCode
            DptCcr  = $_.dptCcr
        }
    }

    Write-Information "Retrieved [$($departments.Count)] departments"

    # Remove duplicates based on DptId
    $uniqueDepartments = $departments | Sort-Object DptId -Unique

    # Export unique departments to HelloID
    $actionMessage = "exporting unique departments to HelloID"
    $exportedDepartments = 0

    foreach ($dept in $uniqueDepartments) {
        $department = [PSCustomObject]@{
            ExternalId        = $dept.DptCode
            DisplayName       = $dept.DptCode
            ManagerExternalId = ""  # Not available in OrtecWS response
            ParentExternalId  = ""  # Not available in OrtecWS response
        }

        $department = $department | ConvertTo-Json -Depth 10
        $department = $department.Replace("._", "__")

        Write-Output $department
        $exportedDepartments++
    }

    Write-Information "Exported [$exportedDepartments] unique departments"
}
catch {
    $ex = $PSItem

    if ( $($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-OrtecWSError -ErrorObject $ex

        $auditMessage = "Error $($actionMessage). Error: $($errorObj.FriendlyMessage)"
        $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
        $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }

    Write-Warning $warningMessage

    throw $auditMessage
}