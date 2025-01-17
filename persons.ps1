##################################################
# HelloID-Conn-Prov-Source-OrtecWS-Persons
#
# Version: 1.0.0
##################################################
# Initialize default value's
$config = $configuration | ConvertFrom-Json

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
        $Body
    )

    process {
        try {
            $splatParams = @{
                Uri         = $Uri
                Method      = $Method
                ContentType = $ContentType
                Body        = $Body
            }

            $responseXml = Invoke-WebRequest @splatParams -Verbose:$false -UseBasicParsing
            $response = [xml]$responseXml.content

            if ($response.Envelope.Body.SendMessageResponse.SendMessageResult -like '*<employees><employee>*') {
                Write-Output $response.Envelope.Body.SendMessageResponse.SendMessageResult
            } elseif ($response.Envelope.Body.SendMessageResponse.SendMessageResult -eq '<?xml version="1.0"?><PSK>The PSK is not correct</PSK>') {
                throw 'The PSK is not correct.'
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

try {
    $xmlRequest = "<?xml version=`"1.0`" encoding=`"utf-8`"?>
    <soap:Envelope xmlns:soap=`"http://www.w3.org/2003/05/soap-envelope`"
        xmlns:cais=`"http://www.ortec.com/CAIS`"
        xmlns:wsa=`"http://schemas.xmlsoap.org/ws/2004/08/addressing`">
        <soap:Header xmlns:wsa=`"http://www.w3.org/2005/08/addressing`">
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
    </soap:Envelope>"

    $splatGetUsersAndShifts = @{
        Uri         = "$($config.BaseUrl)/CAIS/ApplicationIntegration/$($config.ServerName)/SOAP12"
        Method      = 'POST'
        Body        = $xmlRequest
        ContentType = 'application/soap+xml; charset=utf-8'
    }
    [XML]$response = Invoke-OrtecWSRestMethod @splatGetUsersAndShifts

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

    Write-Information "Retrieved $($employees.count) persons from the source system."

    $groupedEmployees = $employees | Group-Object -Property EmpNum

    foreach ($employee in $groupedEmployees) {
        $employeeShifts = $shifts | Where-Object { $_.RseId -eq $employee.Group.RseId }

        $contracts = [System.Collections.Generic.List[object]]::new()
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
                employment  = $employee.group.EmpCon
                function    = $employee.group.PosEmp
                functionId  = $employee.group.PosEmpId
                # Add the same fields as for shift. Otherwise, the HelloID mapping will fail
                # The value of both the 'startAt' and 'endAt' cannot be null. If empty, HelloID is unable
                # to determine the start/end date, resulting in the contract marked as 'active'
                startAt     = $shift.ShtFrom
                endAt       = $shift.ShtUntil
            }
            $contracts.Add($ShiftContract)
        }

        if ($contracts.Count -gt 0) {
            $personObj = [PSCustomObject]@{
                ExternalId  = $employee.group.EmpNum
                DisplayName = "$($employee.group.EmpFirstname) $($employee.group.EmpSurname)".Trim(' ')
                FirstName   = $employee.group.EmpFirstname
                LastName    = $employee.group.EmpSurname
                Email       = $employee.group.EmpEmail
                function    = $employee.group.PosEmp
                functionId  = $employee.group.PosEmpId
                Employment  = $employee.Group.empCon -join ','
                Contracts   = $contracts
            }
            Write-Output $personObj | ConvertTo-Json -Depth 20
        }
    }
} catch {
    $ex = $PSItem
    Write-Information "Could not import OrtecWS persons. Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    Write-Error "Could not import OrtecWS persons. Error: $($ex.Exception.Message)"
}