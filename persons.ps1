########################################################################
# HelloID-Conn-Prov-Source-OrtecWS-Persons
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

    # Extract employees from the response
    $actionMessage = "extracting employees from employee data"

    $employees = $response.XML.employees.employee | ForEach-Object {
        [PSCustomObject]@{
            RseId        = $_.rse_id
            EmpNum       = $_.empNum
            EmpCon       = $_.empCon
            EmpSurname   = $_.empSurname
            EmpFirstname = $_.empFirstname
            EmpEmail     = $_.empEmail
            PosEmp       = $_.empPositions.empPosition.posEmp
            PosEmpId     = $_.empPositions.empPosition.posEmpId
        }
    }

    Write-Information "Retrieved [$($employees.Count)] persons"

    $groupedEmployees = $employees | Group-Object -Property EmpNum

    # Extract shifts from the response
    $actionMessage = "extracting shifts from shift data"

    $shifts = $response.XML.shifts.shift | ForEach-Object {
        [PSCustomObject]@{
            RseId       = $_.rse_id
            DptId       = $_.dptId
            DptCode     = $_.dptCode
            DptCcr      = $_.dptCcr
            ShtId       = $_.shtId
            ShtName     = $_.shtName
            ShtFrom     = $_.shtFrom
            ShtUntil    = $_.shtUntil
            SklShift    = $_.sklShift
            SklShiftId  = $_.sklShiftId
            SklLvlShift = $_.sklLvlShift
        }
    }

    Write-Information "Retrieved [$($shifts.Count)] shifts"

    # Enhance and export person object to HelloID
    $actionMessage = "enhancing and exporting person object to HelloID"

    # Set counter to keep track of actual exported person objects
    $exportedPersons = 0

    foreach ($employee in $groupedEmployees) {
        # Get the shifts for the current employee
        $actionMessage = "retrieving shifts for employee $($employee.Group.EmpNum) with RSE ID: $($employee.Group.RseId)"

        $employeeShifts = $shifts | Where-Object { $_.RseId -eq $employee.Group.RseId }

        $contracts = [System.Collections.Generic.List[object]]::new()
        # Create a contract for each shift
        foreach ($shift in $employeeShifts) {
            $ShiftContract = @{
                externalId  = "$($shift.ShtId)_$($shift.SklShiftId)"
                dptCode     = $shift.DptCode
                dptCcr      = $shift.DptCcr
                dptId       = $shift.DptId
                shtId       = $shift.ShtId
                shtName     = $shift.ShtName
                sklShift    = $shift.SklShift
                sklShiftId  = $shift.SklShiftId
                sklLvlShift = $shift.SklLvlShift
                employment  = $employee.Group.EmpCon
                function    = $employee.Group.PosEmp
                functionId  = $employee.Group.PosEmpId
                # Add the same fields as for shift. Otherwise, the HelloID mapping will fail
                # The value of both the 'startAt' and 'endAt' cannot be null. If empty, HelloID is unable
                # to determine the start/end date, resulting in the contract marked as 'active'
                startAt     = $shift.ShtFrom
                endAt       = $shift.ShtUntil
            }
            $contracts.Add($ShiftContract)
        }

        # Only output the person object if there are contracts
        if ($contracts.Count -gt 0) {
            $personObj = [PSCustomObject]@{
                ExternalId  = $employee.Group.EmpNum
                DisplayName = "$($employee.Group.EmpFirstname) $($employee.Group.EmpSurname) ($($employee.Group.EmpNum))".Trim()
                FirstName   = $employee.Group.EmpFirstname
                LastName    = $employee.Group.EmpSurname
                Email       = $employee.Group.EmpEmail
                function    = $employee.Group.PosEmp
                functionId  = $employee.Group.PosEmpId
                Employment  = $employee.Group.EmpCon -join ','
                Contracts   = $contracts
            }

            Write-Output ($personObj | ConvertTo-Json -Depth 20)

            # Updated counter to keep track of actual exported person objects
            $exportedPersons++
        }
    }

    Write-Information "Exported [$exportedPersons] unique persons"
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