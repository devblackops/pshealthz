
# PSHealthZ

## Overview

Basic HTTP listener that executes [Operation Validation Framework](https://github.com/PowerShell/Operation-Validation-Framework) (OVF) tests that are present on the given system and returns results using a simple REST API.
This is an implementation of the [Health Endpoint Monitoring Pattern](https://msdn.microsoft.com/en-us/library/dn589789.aspx) using PowerShell.

## Getting Started

Start the listener on the desired port and path. The command below will expose a REST endpoint at ```http://localhost:1938/health```.

>This command must be run from an elevated session.

```powershell
>.\Start-HealthzListener.ps1 -Port 1938 -Path health -Verbose
```

This will block the current PowerShell session. Open another session and execute the following command:

```powershell
>$r = Invoke-RestMethod -Uri 'http://localhost:1938/health'
>$r | fl
```

Without specifying a specific test to execute, PSHealthZ will return a list of available OVF tests that are present in `$env:PSModulePath`.

```powershell
>$r.availableTests
Services
More services
Storage Capacity
```

To execute a specific test, add `'?test=<testname>'` as a query parameter.

```powershell
>$r = Invoke-RestMethod -Uri 'http://localhost:1938/health?test=services'
```

You can inspect the test results with:

```powershell
>$r.testResults | ft *
```

To terminate the HTTP listener, run:

```powershell
Invoke-RestMethod -Uri 'http://localhost:1938/health?command=exit'
```
