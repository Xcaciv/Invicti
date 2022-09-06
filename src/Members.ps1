#Requires -Version 3
<#
.SYNOPSIS
  Do things with Invicti members
.DESCRIPTION
  Mass edit members
.PARAMETER action
    <Brief description of parameter input required. Repeat this attribute if required>
.INPUTS
  <Inputs if any, otherwise state None>
.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
.NOTES
  Version:        1.0
  Author:         <Name>
  Creation Date:  <Date>
  Purpose/Change: Initial script development
  
.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>


#--------[Params]---------------
Param(
  [Parameter()]
  [ValidationSet('delete', 
    'deleteinvitation', 
    'get', 
    'getapitoken', 
    'getbyemail', 
    'getinvitation', 
    'gettimezones', 
    'invitationlist', 
    'list', 
    'new', 
    'newinvitation', 
    'sendinvitationemail',
    'update'
    )]
  [string]$Action='list',

  [Parameter()]
  [int]$Id='',

  [Parameter()]
  [string]$Url='https://www.netsparkercloud.com/api/',

  [Parameter()]
  [ValidationSet('1.0')]
  [string]$ApiVersion='1.0',

  [Parameter()]
  [string]$Subject='members'
)

#if (-not($PSBoundParameters.ContainsKey("MyParam"))) {
#   Write-Output "Value from pipeline"
#}

#--------[Script]---------------


Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$scriptDir = Split-Path -LiteralPath $PSCommandPath
$startingLoc = Get-Location
Set-Location $scriptDir
$startingDir = [System.Environment]::CurrentDirectory
[System.Environment]::CurrentDirectory = $scriptDir


try
{
    # >>>>>> Insert script here.
}
finally
{
    Set-Location $startingLoc
    [System.Environment]::CurrentDirectory = $startingDir
    Write-Output "Done. ET: $($stopwatch.Elapsed)"
}