
# HelloID-Conn-Prov-Source-OrtecWS


| :information_source: Information                                                                                                                                                                                                                                                                                                                                                       |
| :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements. |

<p align="center">
  <img src="">
</p>

## Table of contents

- [HelloID-Conn-Prov-Source-OrtecWS](#HelloID-Conn-Prov-Source-OrtecWS)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
    - [Endpoints](#endpoints)
  - [Getting started](#getting-started)
    - [Connection settings](#connection-settings)
    - [Remarks](#remarks)
      - [Logic in-depth](#logic-in-depth)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Source-OrtecWS_ is a _source_ connector. The purpose of this connector is to import _employees_ and their _shifts_.

### Endpoints

Currently the following endpoints are being used..

| Endpoint                                          | Purpose                         |
| ------------------------------------------------- |-------------------------------- |
| /CAIS/ApplicationIntegration/{servername}/SOAP12 | Retrieving Employees and Shifts |


## Getting started

### Connection settings

The following settings are required to connect to the API.

| Setting    | Description                                                                            | Mandatory |
| ---------- | -------------------------------------------------------------------------------------- | --------- |
| ApiKey     | The ApiKey to connect to the API                                                       | Yes       |
| BaseUrl    | The URL to the API                                                                     | Yes       |
| HistoricalDays | - The number of days in the past from which the shifts will be imported.<br> - Will be converted to a `[DateTime]` object containing the _current date_ __minus__ the number of days specified. | Yes       |
| FutureDays | - The number of days in the future from which the shifts will be imported.<br> - Will be converted to a `[DateTime]` object containing the _current date_ __plus__ the number of days specified. | Yes       |

### Remarks

- The connector makes use of an xml soap request to retrieve the data that is necessary for the connector.

- The window for querying is -2 days and +7 days. If a call falls outside this window, the API constrains it to fit within the window. You can change these value's with _HistoricalDays_ and _FutureDays_ in the configuration.

- It is possible for a employee to come back twice with a get call. this happens when a user is assigned to multiple employements (Dienstverband) (The same user exists multiple times in the source system with only a different _empCon_). The connector handles this by creating one person with all the _empCon_ (employements / dienstverband) in a comma separated string.

## Getting help

> [!NOTE]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012557600-Configure-a-custom-PowerShell-source-system) pages_

> [!NOTE]
> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com/forum/helloid-connectors/provisioning/5311-helloid-conn-prov-source-ortecws-persons)

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/

