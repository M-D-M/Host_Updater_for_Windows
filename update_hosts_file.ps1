#!/usr/bin/powershell

$remote_hosts_file="http://winhelp2002.mvps.org/hosts.txt"
$hosts_file_loc="C:\Windows\System32\drivers\etc\hosts"
# $hosts_file_loc="hosts"

function main ($vals) {
    if ($vals.length -lt 1)
    {
        usageMessage
    }
    else
    {
        switch ($vals[0])
        {
            "install" {
                installUpdateAgent
            }
            "uninstall" {
                uninstallUpdateAgent
            }
            "run" {
                replaceHosts
            }
            default {
                usageMessage
            }
        }
    }
}

function usageMessage {
    write-host "`nUsage: <script name> [install|uninstall|run]"
}

function replaceHosts {
    # Hide progress output for commands
    $progressPreference = 'silentlyContinue'

    outputHostsSize
    
    write-output "Downloading new hosts information from $remote_hosts_file..."
    Invoke-WebRequest -Uri $remote_hosts_file -OutFile $hosts_file_loc".download"

    write-output "Removing any line that doesn't begin with 0.0.0.0"
    Get-Content $hosts_file_loc".download" | Where-Object {$_ -match '^0.0.0.0'} | Set-Content $hosts_file_loc".tmp"

    if (!(test-path $hosts_file_loc".initial")) {
            write-host "`nFirst time running this script; copying existing hosts file to hosts.initial..."
            cp $hosts_file_loc $hosts_file_loc".initial"
    }

    mv $hosts_file_loc $hosts_file_loc".old" -force

    Get-Content $hosts_file_loc".initial" | Add-Content $hosts_file_loc
    get-content $hosts_file_loc".tmp" | add-content $hosts_file_loc

    outputHostsSize

    rm $hosts_file_loc".tmp", $hosts_file_loc".download"
}

function installUpdateAgent {
    write-host "`nInstall feature under construction."

    exit

    $action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -command "& {get-eventlog -logname Application -After ((get-date).AddDays(-1)) | Export-Csv -Path c:\fso\applog.csv -Force -NoTypeInformation}"'

    $trigger =  New-ScheduledTaskTrigger -Daily -At 9am

    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "AppLog" -Description "Daily dump of Applog"
}

function uninstallUpdateAgent {
    write-host "`nRemoving update agent..."
    
    write-host "`nCopying old hosts file back to ${hosts_file_loc}..."
    mv $hosts_file_loc".initial" $hosts_file_loc -force
}

function outputHostsSize {
    $hostsSize=$(Get-Content $hosts_file_loc | Measure-Object -Line).Lines
    write-host "`nSize of hosts file: $hostsSize"
}

main $args