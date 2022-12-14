#Requires -Version 5
<#
.SYNOPSIS
  Do things with Invicti members, most specifically disable Members
.DESCRIPTION
  Mass edit members
.PARAMETER Action
    <Brief description of parameter input required. Repeat this attribute if required>
.PARAMETER Id
    <Brief description of parameter input required. Repeat this attribute if required>
.PARAMETER Email
    <Brief description of parameter input required. Repeat this attribute if required>
.PARAMETER Member
    <Brief description of parameter input required. Repeat this attribute if required>
.PARAMETER DisableMemberList
    <Brief description of parameter input required. Repeat this attribute if required>
.PARAMETER BaseUrl
    override
.PARAMETER ApiVersion
    Version of API to be used
.PARAMETER Subject
    override 'members' to call other endpoints
.PARAMETER Verb
    OVERRIDE HTTP Verb
.PARAMETER Credential
    PSCredential for authentication to API
.PARAMETER CredentialPrompt
    Toggle force prompt for credentials
.INPUTS
  <Inputs if any, otherwise state None>
.OUTPUTS
  To Screen
.NOTES
  Version:        1.0
  Author:         Alton Crossley
  Creation Date:  2022-09-26
  Purpose/Change: Initial script development

.EXAMPLE
  <Script> -Verbose
  Lists members
#>


#--------[Params]---------------
Param(
  [Parameter()]
  [ValidateSet('delete', 'deleteinvitation', 'get', 'getapitoken', 'getbyemail', 'getinvitation', 'gettimezones', 'invitationlist', 'list', 'new', 'newinvitation', 'sendinvitationemail', 'update', 'disablemember' )]
  [string]$Action = 'list',

  [Parameter()]
  [int]$Id,

  [Parameter()]
  [string]$Email,

  [Parameter()]
  [Object]$Member,

  [Parameter()]
  [string]$DisableMemberList = '',

  [Parameter()]
  [string]
  $BaseUrl = 'https://www.netsparkercloud.com/api/',

  [Parameter()]
  [ValidateSet('1.0')]
  [string]
  $ApiVersion = '1.0',

  [Parameter()]
  [string]
  $Subject = 'members',

  [Parameter()]
  [string]
  [ValidateSet('POST', 'GET')]
  $Verb,

  [Parameter()]
  [System.Management.Automation.PSCredential]
  $Credential = [System.Management.Automation.PSCredential]::Empty,

  [Parameter()]
  [Switch]$CredentialPrompt
)

function CallInvictiAPI
{
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
    [string]$JsonBody = $null,

    [Parameter()]
    [ValidateNotNull()]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]
    $Credential = [System.Management.Automation.PSCredential]::Empty
  )


  Write-Debug "Calling ${Verb} :: ${Uri}"

  $Parameters = @{
    Method = $Verb
    Uri = $Uri
    ContentType = 'application/json'
    # Authentication = "Basic"
    Credential = $Credential
  }

  if ($Verb -eq 'POST')
  {
    $Parameters | Add-Member -MemberType NoteProperty -Name 'Body' -Value $JsonBody
  }

  Invoke-RestMethod @Parameters
}

function Get-InvictiMember
{
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

function Disable-InvictiMember
{
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

  if ($Member.State -eq 'Disabled')
  {
    $Name = $Member.Name
    Write-Verbose "User ${Name} **ALREADY DISABLED**"
    return
  }
  else
  {
    $Member.State = 'Disabled'
    $Member | Add-Member -MemberType NoteProperty -Name 'AutoGeneratePassword' -Value $true
  }

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
  Write-Debug "Checking Cred"

  if (!([boolean](Get-Variable "InvictiCred" -Scope Global -ErrorAction SilentlyContinue)) -or $CredentialPrompt)
  {
    Write-Debug "Prompting credentials"
    $Credential = Get-Credential -Message "Enter your API 'Token' and 'Key' as 'User Name' and 'Password'"
    Set-Variable -Name 'InvictiCred' -Value $Credential -Scope global
  }
  else
  {
    Write-Debug "Loading Global Credentials"
    $Credential = $global:InvictiCred
  }
}

if (($null -ne $Member) -and ($null -eq $Verb))
{
  Write-Debug "Member set, forcing POST"
  $Verb = 'POST'
}
elseif ($null -eq $Verb -or $Verb -eq '')
{
  Write-Debug "No verb, defaulting to GET"
  $Verb = 'GET'
}

try
{

  if ($null -eq $Member)
  {
    $Body = ''
  }
  else
  {
    Write-Debug "Converting Member to JsonBody"
    $Body = $Member | ConvertTo-Json
  }

  if (($null -ne $DisableMemberList) -and ($DisableMemberList -ne ''))
  {
    Write-Verbose "Disabled Member list not empty"
    $emailRegex = '\w+([-+.]\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*';
    if (Test-Path -Path $DisableMemberList)
    {
      Write-Output "Loading Disable Member List"
      foreach ($line in Get-Content -Path $DisableMemberList)
      {
        if ($line -match $emailRegex)
        {
          try
          {
            $Member = Get-InvictiMember $line "${BaseUrl}${ApiVersion}" $Verb $Body $Credential
            $result = Disable-InvictiMember $Member "${BaseUrl}${ApiVersion}/${Subject}" $Credential
            Write-Debug $result
            Write-Verbose "Disabled ${line}"
          }
          catch
          {
            Write-Verbose "Unable to Disable ${line}"
          }
        }
      }
    }
    else {
      Write-Output "Unable to find Disable Member List"
    }
    return

  }

  # load member function
  if (($null -ne $Email -and $Email -ne '') -and ($null -eq $Member))
  {
    Write-Verbose "Loading member"
    $Member = Get-InvictiMember $Email "${BaseUrl}${ApiVersion}" $Verb $Body $Credential
    if ($Action -eq 'getbyemail')
    {
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
  CallInvictiAPI $Uri $Verb $Body $Credential
  return $Member
}
catch
{
  Write-Error ($_.Exception | Format-List -Force | Out-String) -ErrorAction Continue
  Write-Error ($_.InvocationInfo | Format-List -Force | Out-String) -ErrorAction Continue
  throw
}
finally
{
  Set-Location $startingLoc
  [System.Environment]::CurrentDirectory = $startingDir
  Write-Verbose "Done. ET: $($stopwatch.Elapsed)"
}