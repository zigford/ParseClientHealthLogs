function Convert-ClientHealthLogsToObjects {
<#
    .SYNOPSIS
    Convert log files produced by the Config Manager Client Health Script into PowerShell Objects

    .DESCRIPTION
    Traverses a log directory for .log files. Read and parse the log files into PS Custom Objects

    .PARAMETER Path
    Specify the root path to the log file store

    .PARAMETER Latest
    Client Health script will store a configurable amount of logs for a PC each time it is run. Specify this parameter if you want only the latest data returned.

    .NOTES
    Author: Jesse Harris
    Version: 1.0
    Release: 01/06/2017
#>
[CmdLetBinding()]
Param(
    [Parameter(Mandatory=$True)]$Path,
    [Switch]$Latest
)

    $Logs = Get-ChildItem -Path $Path -Recurse -Filter *.log
    Write-Verbose "$($Logs.Count) logs found"
    ForEach ($Log in $Logs) {
        Write-Verbose "Reading $Log"
        $LogContent = Get-Content -Path $Log.FullName
        $LogObject = New-Object -TypeName psobject
        $AllPCLog = @()         #This object will temporarily hold back all the logs for a PC to get only the latest one.
        $LogContent | ForEach-Object {
            $_ -match '^(?<key>\w{1,}):\s(?<value>.*$)' | Out-Null
            If ($Matches) {
                Write-Verbose "Found match on $($Matches['key'])" 
                If ('Timestamp','LastBootTime','OSUpdates','InstallDate','RefreshComplianceState','HWInventory' -contains $Matches['key']) {
                    $Value = Convert-Timestamp -Timestamp $Matches['value']
                } Else {
                    $Value = $Matches['value']
                }
                Try {
                    $LogObject | Add-Member `
                        -MemberType NoteProperty `
                        -Name $Matches['key'] `
                        -Value $Value -Force
                } catch {
                    # no match on key
                }
                If ($Matches['key'] -eq 'Version') {
                    # Different Client Health script log files end with different
                    # Key's at the end. This will setup the correct one depernding
                    # on the version indicated in the log
                    $EndKey = Switch ($Value) {
                        0.7.6 {'ClientInstalledReason'}
                        Default {'Timestamp'}
                    }
                }
                If ($EndKey -and $Matches['key'] -eq $EndKey ) {
                    Write-Verbose "End record in log reached at $EndKey"
                    $AllPCLog+=$LogObject 
                    $LogObject = New-Object -TypeName psobject
                    $Matches = $null
                }   
            }
        }
        If ($Latest) {
            $CurrentTimestamp = (Get-Date).AddDays(-1000) 
            $AllPCLog | ForEach-Object {
                If ($_.Timestamp -gt $CurrentTimestamp) {
                    $NewestLog = $_
                    $CurrentTimestamp = $_.Timestamp
                }
            }
            $NewestLog
        } Else {
            $AllPCLog
        }
    }
}

function Get-RepairedMachines {
<#
    .SYNOPSIS
    List a summary of hosts which have been repaired from the Config Manager Client health script

    .DESCRIPTION
    Simply returns Config Manager Client health logs converted to objects based on repair status of some components.

    .PARAMETER Path
    Specify the root path to the log file store

    .PARAMETER Latest
    Client Health script will store a configurable amount of logs for a PC each time it is run. Specify this parameter if you want only the latest data returned.

    .NOTES
    Author: Jesse Harris
    Version: 1.0
    Release: 01/06/2017
#>
    [CmdletBinding()]
    Param([switch]$Latest,$Path)
    #Unhealth workstations are those which need to be or have been repaired:
        Convert-ClientHealthLogsToObjects -Path $Path -Latest:$Latest | Where-Object {
            $_.WMI -ne 'OK' -or
            $_.WUAHandler -ne 'OK' -or
            $_.StateMessages -ne 'OK' -or
            $_.AdminShare -ne 'OK' -or
            $_.ProvisioningMode -ne 'OK' -or
            $_.Certificate -ne 'OK'
        } | Format-Table Hostname,WMI,WUAHandler,StateMessages,AdminShare,ProvisioningMode,Certificate,OSUpdates


}

function Convert-Timestamp {
    <#Convert Timestamp#>
    Param($Timestamp)
    Write-Verbose "Parsing timestamp $Timestamp" 
    Try {
        $Cts = [DateTime]::ParseExact($Timestamp,'yyyy-MM-dd HH:mm:ss',[System.Globalization.CultureInfo]::InvariantCulture)
    } Catch {
        $Cts = $null
    }
    return $Cts
}