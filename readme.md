# HelloID-Conn-Prov-Source-OrtecWS

> [!IMPORTANT]  
> This repository contains the connector and configuration code only. The implementer is responsible for acquiring the connection details such as username, password, certificate, etc. You may need to sign a contract or agreement with the supplier before using this connector. Coordinate with the client’s application manager to arrange the required access and credentials.

<p align="center">
  <img src="https://raw.githubusercontent.com/Tools4everBV/HelloID-Conn-Prov-Source-OrtecWS/refs/heads/main/Logo.png">
</p>

## Table of contents

- [HelloID-Conn-Prov-Source-OrtecWS](#helloid-conn-prov-source-ortecws)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Requirements](#requirements)
    - [Connection settings](#connection-settings)
  - [Remarks](#remarks)
    - [Logic in-depth](#logic-in-depth)
  - [Development resources](#development-resources)
    - [API endpoints](#api-endpoints)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Source-OrtecWS_ is a _source_ connector. It imports _employees_ and their _shifts_ from Ortec using a SOAP-based web service.

## Getting started

### Requirements

- This connector requires an **on-premise HelloID Agent** to be installed and running.
- The **IP addresses of the HelloID Agent server must be whitelisted by Ortec**. Please contact Ortec support to arrange this.

- **API access must be requested from Ortec**. They are responsible for configuring the SOAP API and providing the following connection details:
  - **Base URL**: The base URL of the OrtecWS SOAP API (e.g., `https://t4e-weu-soapsvc1-p.ortec-hosting.com`)
  - **Server Name**: The name of the server used in the SOAP endpoint path (e.g., `T4E_WEU_OWS_P`)
  - **API Key**: A pre-shared key (PSK) used to authenticate SOAP requests
  - **API Username** and **API Password**: Credentials required to authenticate with the OrtecWS API

- The connector requires two configuration settings to define the import window for shift data:
  - `HistoricalDays`: The number of days in the past from which shifts should be imported.
    - The Ortec API supports a maximum of **2 historical days**. Contact Ortec if you require a larger window.
  - `FutureDays`: The number of days in the future from which shifts should be imported.
    - The Ortec API supports a maximum of **7 future days**. Contact Ortec if you require a larger window.

- **Ensure Aggregation Values Match Between Sources**
  - The OrtecWS source connector is not a full source. Its purpose is to **aggregate to the existing HR source** with employee shift data. This happens through **aggregation based on the `ExternalId`** of the primary source. Make sure the **aggregation value in the primary source matches the aggregation value in OrtecWS**, otherwise shift data won’t link correctly to the person.

- **Verify department codes in OrtecWS correspond to the codes used in the primary HR source** 
  - Often, OrtecWS uses the short code (shortName) instead of the internal ID.
  - For Beaufort, use the shortName in the departments script and mapping, not the ID.
  - Confirm codes match on both sides to avoid breaking business rules or dynamic/sub permissions.


### Connection settings

| Setting        | Description                                                                                                          | Mandatory |
| -------------- | -------------------------------------------------------------------------------------------------------------------- | --------- |
| BaseUrl        | The base URL of the OrtecWS API. <br>_e.g., `https://t4e-weu-soapsvc1-p.ortec-hosting.com`_                          | Yes       |
| ServerName     | The server name used in the SOAP endpoint path. <br>_e.g., `T4E_WEU_OWS_P`_                                          | Yes       |
| ApiKey         | The pre-shared key (PSK) for authenticating SOAP requests.                                                           | Yes       |
| ApiUsername    | The username for authenticating with the API. <br>_e.g., `ORTEC-HOSTING\\T4E_WEU_OWS_WebS01_P`_                      | Yes       |
| ApiPassword    | The password associated with the API username.                                                                       | Yes       |
| HistoricalDays | Number of days in the past to include when fetching employments (e.g. 2 = current date minus 2 days). Max = 2 days.  | Yes       |
| FutureDays     | Number of days in the future to include when fetching employments (e.g. 7 = current date plus 7 days). Max = 7 days. | Yes       |

## Remarks

**Soap XML**  
The connector makes use of an xml soap request to retrieve the data that is necessary for the connector.

**Time Window Restrictions**  
The API enforces a time window of **-2 to +7 days**. Requests outside this range are automatically adjusted. This is the maximum supported range by Ortec. Contact Ortec if you need to widen this.

**Multiple Employments**  
Employees may appear multiple times if they hold multiple _dienstverbanden_ (employments). Each unique employment has a separate `empCon`. The connector merges these into a single record with a comma-separated list of `empCon` values.

**Aggregation Value**  
The connector uses a custom `Aggregation` value to support automatic person linking in HelloID:  
By default, the `Aggregation` value is based on the `ExternalId` from the OrtecWS data.
  - This value is prefixed and suffixed with `'XXXXX'`.  
  This pattern helps avoid accidental matches when `ExternalId` values are partially similar across sources.

**Department Codes in OrtecWS**  
The department code used in OrtecWS is often the short code (shortName) of a department from the primary source system, not the internal ID. The internal ID usually exists only in the primary system.  
For example, when using Beaufort as the primary system, the short code must be used in the departments script and mapping instead of the ID.  
This may differ per primary source system, but the key is that the codes match on both sides to ensure existing business rules and any dynamic/sub permissions keep working without changes. This is usually desired but may vary per client.


### Logic in-depth

When calling the OrtecWS API:

- The connector queries a fixed date range:  
  From _today minus `HistoricalDays`_ to _today plus `FutureDays`_.
- If an employee is assigned to multiple employments, they will appear more than once in the result. The connector consolidates these entries.
- All employments for the same person are stored in a single string, separated by commas.

## Development resources

### API endpoints

The following SOAP endpoint is used:

| Endpoint                                           | Description                          |
| -------------------------------------------------- | ------------------------------------ |
| `/CAIS/ApplicationIntegration/{ServerName}/SOAP12` | Retrieves employees and their shifts |

## Getting help

> [!NOTE]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012557600-Configure-a-custom-PowerShell-source-system) pages_

> [!NOTE]
> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com/forum/helloid-connectors/provisioning/5311-helloid-conn-prov-source-ortecws-persons)

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
