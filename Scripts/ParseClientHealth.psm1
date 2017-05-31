function Get-ClientHealthLogs {
    <#


    #>
[CmdLetBinding()]
Param(
    [Parameter(Mandatory=$True)]$Path
)

    $Logs = Get-ChildItem -Path $Path -Recurse -Filter *.log
    Write-Verbose "$($Logs.Count) logs found"
    ForEach ($Log in $Logs) {
        Write-Verbose "Reading $Log"
        $LogContent = Get-Content -Path $Log.FullName
        $LogObject = New-Object -TypeName psobject
        $LogContent | ForEach-Object {
            $_ -match '^(?<key>\w{1,}):\s(?<value>.*$)' | Out-Null
            If ($Matches) {
                Write-Verbose "Found match on $($Matches['key'])"
                $LogObject | Add-Member `
                    -MemberType NoteProperty `
                    -Name $Matches['key'] `
                    -Value $Matches['value'] -Force
                If ($Matches['key'] -eq 'Timestamp') {
                    $LogObject 
                    $LogObject = New-Object -TypeName psobject
                    $Matches = $null
                }   
            }

        }
    }
}
