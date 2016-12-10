#!/usr/bin/powershell

$remote_hosts_file="http://winhelp2002.mvps.org/hosts.txt"
$hosts_file_loc="C:\Windows\System32\drivers\etc\hosts"
$scriptName="$(Split-Path -Path $MyInvocation.MyCommand.Path)\$($MyInvocation.MyCommand)"
$scriptDesc="Update hosts file with $scriptName"
$taskName="UpdateHosts"
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
            "status" {
                checkStatus
            }
            default {
                usageMessage
            }
        }
    }
}

function usageMessage {
    write-host "`nUsage: <script name> [install|uninstall|run|status]"
}

function replaceHosts {
    # Hide progress output for commands
    $progressPreference = 'silentlyContinue'

    outputHostsSize
    
    write-output "Downloading new hosts information from $remote_hosts_file..."
    Invoke-WebRequest -Uri $remote_hosts_file -OutFile $hosts_file_loc".download"

    write-output "Removing any line that doesn't begin with 0.0.0.0"
    Get-Content $hosts_file_loc".download" | Where-Object {$_ -match '^0.0.0.0'} | Set-Content $hosts_file_loc".tmp"

    if (!(isHostsFileModified)) {
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
    if (doesAgentExist) {
        write-host "`nHost updater task already exists! No need to create again."
    }
    else
    {
        write-host "`nCreating windows task to update hosts file weekly..."

        $arguments="-NoProfile -WindowStyle Hidden -command ""${scriptName} run"""
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "$arguments"

        $trigger = New-ScheduledTaskTrigger -Daily -At 9pm

        Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "${taskName}" -Description "${scriptDesc}" -User "System"
    }

    replaceHosts

    write-host "Done! Press any key to continue..."
    Read-Host 
}

function uninstallUpdateAgent {
    if (doesAgentExist) {
        write-host "`nRemoving scheduled tasks to update hosts file..."

        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
    else {
        write-host "`nScheduled task to update hosts file does not exist."
    }

    if (!(isHostsFileModified)) {
        write-host "`nHosts file has not been modified. Exiting."
    }
    else {
        write-host "`nCopying old hosts file back to ${hosts_file_loc}..."
        mv $hosts_file_loc".initial" $hosts_file_loc -force
    }
   
}

function outputHostsSize {
    $hostsSize=$(Get-Content $hosts_file_loc | Measure-Object -Line).Lines
    write-host "`nSize of hosts file: $hostsSize"
}

function checkStatus {
    if (!(isHostsFileModified)) {
        write-host "`nHosts file has not been modified."
    }
    else {
        outputHostsSize
    }

    if (doesAgentExist) {
        write-host "Host updater task exists! Next run time: $((Get-ScheduledTaskInfo $taskName).NextRunTime)"
    }
    else {
        write-host "`nTask to update hosts file does not exist."
    }
}

function doesAgentExist {
    return (Get-ScheduledTask | Select -ExpandProperty TaskName | Where-Object {$_ -match $taskName})
}

function isHostsFileModified {
    $returnVal = $true

    if (test-path $hosts_file_loc".initial") {
        $returnVal = $true
    }
    else {
        $returnVal = $false
    }

    return $returnVal
}

main $args