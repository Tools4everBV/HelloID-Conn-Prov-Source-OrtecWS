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

- You must request API access from **Ortec**. They are responsible for:
  - Enabling the API for your environment.
  - Supplying the **Base URL**, **Server Name**, **API Key**, **API Username**, and **API Password**.


- The connector expects two additional settings:
  - `HistoricalDays`: Number of days in the past from which shift data will be imported.
    - Max allowed by Ortec is 2 days. If you need a wider window, you’ll have to request it from them.
  - `FutureDays`: Number of days in the future from which shift data will be imported.
    - Max allowed by Ortec is 7 days. You can also request a change via Ortec.

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

- The connector uses a SOAP 1.2 request to retrieve employee and shift data.
- The API enforces a time window of **-2 to +7 days**. Requests outside this range are automatically adjusted. This is the maximum supported range by Ortec. Contact Ortec if you need to widen this.
- Employees may appear multiple times if they hold multiple _dienstverbanden_ (employments). Each unique employment has a separate `empCon`. The connector merges these into a single record with a comma-separated list of `empCon` values.

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
