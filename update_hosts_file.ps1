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
    write-host "`nUsage: <script name> [install|run]"
}

function replaceHosts {
    # Hide progress output for commands
    $progressPreference = 'silentlyContinue'

    write-output "Downloading file..."
    Invoke-WebRequest -Uri $remote_hosts_file -OutFile $hosts_file_loc".download"

    write-output "Removing any line that doesn't begin with 0.0.0.0"
    Get-Content $hosts_file_loc".download" | Where-Object {$_ -match '^0.0.0.0'} | Set-Content $hosts_file_loc".tmp"

    if (!(test-path $hosts_file_loc".initial")) {
            cp $hosts_file_loc $hosts_file_loc".initial"
    }

    mv $hosts_file_loc $hosts_file_loc".old" -force

    Get-Content $hosts_file_loc".initial" | Add-Content $hosts_file_loc
    get-content $hosts_file_loc".tmp" | add-content $hosts_file_loc

    rm $hosts_file_loc".tmp", $hosts_file_loc".download"
}

function installUpdateAgent {
    write-host "`nInstall feature under construction."
}

main $args
