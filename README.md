
# PSHealthZ

## Overview

Basic HTTP(S) listener that executes [Operation Validation Framework](https://github.com/PowerShell/Operation-Validation-Framework) (OVF) tests that are present on the given system and returns results using a simple REST API.
This is an implementation of the [Health Endpoint Monitoring Pattern](https://msdn.microsoft.com/en-us/library/dn589789.aspx) using PowerShell.

## Getting Started

Start the listener on the desired port and path. The command below will expose a REST endpoint at ```http://localhost:1938/health```.

>This command must be run from an elevated session.

```powershell
>$listener = Start-HealthzListener -PassThru -Verbose
```

This will create a PowerShell job running the listener in the backgound. To see the listener details, run:

```powershell
$listener | Format-List *
```

To test the listener, run the following:

```powershell
>$r = Invoke-RestMethod -Uri 'http://localhost:1938/health'
>$r | Format-List *
```

Without specifying a specific test to execute, PSHealthZ will return a list of available OVF tests that are present in `$env:PSModulePath`.

```powershell
>$r.availableTests
Storage Capacity Memory Capacity OVF.Example1
Services asdf                    OVF.Example2
More services                    OVF.Example2
Logical Disks                    OVF.Windows.Server
Memory                           OVF.Windows.Server
Network Adapters                 OVF.Windows.Server
Operating System                 OVF.Windows.Server
```

To execute a specific test, add `'?test=<testname>'` as a query parameter.

```powershell
>$r = Invoke-RestMethod -Uri 'http://localhost:1938/health?test=services'
```

To execute tests from a specific module, add `'?module=<modulename>'` as a query parameter.

```powershell
>$r = Invoke-RestMethod -Uri 'http://localhost:1938/health?module=ovf.example1'
```

You can inspect the test results with:

```powershell
>$r.testResults | Format-Table *
```

To stop the HTTP listener, run:

```powershell
$listener | Stop-HealthzListener
```
