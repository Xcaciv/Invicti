#Requires -Version 4
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
  [ValidateSet('delete', 'deleteinvitation', 'get', 'getapitoken', 'getbyemail', 'getinvitation', 'gettimezones', 'invitationlist', 'list', 'new', 'newinvitation', 'sendinvitationemail', 'update', 'disablemember' )]
  [string]$Action='list',

  [Parameter()]
  [int]$Id,

  [Parameter()]
  [string]$Email,

  [Parameter()]
  [Object]$Member,

  [Parameter()]
  [string]$DisableMemberList,

  [Parameter()]
  [string]
  $BaseUrl='https://www.netsparkercloud.com/api/',

  [Parameter()]
  [ValidateSet('1.0')]
  [string]
  $ApiVersion='1.0',

  [Parameter()]
  [string]
  $Subject='members',

  [Parameter()]
  [string]
  [ValidateSet('POST','GET')]
  $Verb,

  [Parameter()]
  [System.Management.Automation.PSCredential]
  $Credential = [System.Management.Automation.PSCredential]::Empty
)

function CallInvictiAPI {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory)]
    [string]
    $Uri,

    [Parameter()]
    [string]
    [ValidateSet('POST', 'GET')]
    $Verb,

    [Parameter()]
    [string]$JsonBody,

    [Parameter()]
    [ValidateNotNull()]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]
    $Credential = [System.Management.Automation.PSCredential]::Empty
  )

  
  Write-Debug "calling ${Verb} :: ${Uri}"

  $Parameters = @{
    Method = $Verb
    Uri = $Uri
    Body = $JsonBody
    ContentType = 'application/json'
    Authentication = "Basic"
    Credential = $Credential
  }

  Invoke-RestMethod @Parameters
}

function Get-InvictiMember {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory)]
    [string]
    $Email,

    [Parameter(Mandatory)]
    [string]
    $Uri,

    [Parameter()]
    [string]
    [ValidateSet('POST', 'GET')]
    $Verb,

    [Parameter()]
    [string]$Body,

    [Parameter()]
    [ValidateNotNull()]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]
    $Credential = [System.Management.Automation.PSCredential]::Empty
  )

  $Uri += "/members/getbyemail?email=" + [System.Web.HttpUtility]::UrlEncode($Email)
  CallInvictiAPI $Uri $Verb $Body $Credential
}

function Disable-InvictiMember {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory)]
    [PSObject]
    $Member,

    [Parameter(Mandatory)]
    [string]
    $Uri,

    [Parameter()]
    [ValidateNotNull()]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]
    $Credential = [System.Management.Automation.PSCredential]::Empty
  )

    $Member.State = 'Disabled'
    $Member | Add-Member -MemberType NoteProperty -Name 'AutoGeneratePassword' -Value $true

    $Body = ConvertTo-Json -Depth 10 -InputObject $Member
    $Verb = 'POST'
    $Action = 'update'

    Write-Debug "BODY: ${Body}" 

    $Uri = "${Uri}/${Action}"
    return CallInvictiAPI $Uri $Verb $Body $Credential
}

#--------[Script]---------------


Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$scriptDir = Split-Path -LiteralPath $PSCommandPath
$startingLoc = Get-Location
Set-Location $scriptDir
$startingDir = [System.Environment]::CurrentDirectory
[System.Environment]::CurrentDirectory = $scriptDir

# Handle basic credentials - user = token and password = key
if ($Credential -eq [System.Management.Automation.PSCredential]::Empty)
{
  if (($null -eq $global:InvictiCred) -or ([System.Management.Automation.PSCredential]::Empty -eq $global:InvictiCred))
  {
    $Credential = Get-Credential -Message "Enter your API 'Token' and 'Key' as 'User Name' and 'Password'"
    Set-Variable -Name 'InvictiCred' -Value $Credential -Scope global
  }
  else
  {
    $Credential = $global:InvictiCred
  }
}

if (($null -ne $Member) -and ($null -eq $Verb))
{
  $Verb = 'POST'
}
elseif ($null -eq $Verb -or $Verb -eq '')
{
  $Verb = 'GET'
}

try
{
  
  if ($null -eq $Member)
  {
    $Body = ''
  }
  else {
    $Body = $Member | ConvertTo-Json
  }

  if ($null -eq $DisableMemberList)
  {
    $emailRegex = '\w+([-+.]\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*';
    foreach($line in Get-Content -Path $DisableMemberList)
    {
      if($line -match $emailRegex)
      {
        $Member = Get-InvictiMember $line "${BaseUrl}${ApiVersion}" $Verb $Body $Credential
        $result = Disable-InvictiMember $Member "${BaseUrl}${ApiVersion}/${Subject}" $Credential
        Write-Debug $result
        Write-Verbose "Disabled ${line}"
      }
    }
    return
  }
  
  if ($null -ne $Email -and $null -eq $Member) {
    $Member = Get-InvictiMember $Email "${BaseUrl}${ApiVersion}" $Verb $Body $Credential
    if ($Action -eq 'getbyemail') { 
      return $Member 
    }
  }

  # special functions
  if ($Action -eq 'disablemember')
  {
    return Disable-InvictiMember $Member "${BaseUrl}${ApiVersion}/${Subject}" $Credential
  }
  
  # normal function
  $Uri = "${BaseUrl}${ApiVersion}/${Subject}/${Action}"
  return CallInvictiAPI $Uri $Verb $Body $Credential 
}
finally
{
    Set-Location $startingLoc
    [System.Environment]::CurrentDirectory = $startingDir
    Write-Verbose "Done. ET: $($stopwatch.Elapsed)"
}