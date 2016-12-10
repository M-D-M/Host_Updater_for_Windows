#!/usr/bin/powershell

$version="1.10.0"

$remote_hosts_file="http://winhelp2002.mvps.org/hosts.txt"
# $hosts_file_loc="hosts"

$hosts_file_loc="C:\Windows\System32\drivers\etc\hosts"
$scriptName="$(Split-Path -Path $MyInvocation.MyCommand.Path)\$($MyInvocation.MyCommand)"
$scriptDesc="Update hosts file with $scriptName"
$taskName="UpdateHosts"

function main ($vals) {
    escalatePriv
    
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
    $title = "Host Updater for Windows v${version}"
    $message = "Welcome to the Host Updater for Windows.  Please choose an option below:"

    $choice1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Install", `
        "Installs host updater task and updates host file."

    $choice2 = New-Object System.Management.Automation.Host.ChoiceDescription "&Uninstall", `
        "Uninstalls host updater task and reverts host file to original."

    $choice3 = New-Object System.Management.Automation.Host.ChoiceDescription "&Run", `
        "Updates host file without installing host updater task."

    $choice4 = New-Object System.Management.Automation.Host.ChoiceDescription "&Status", `
        "Reports status of host file and host updater task."

    $choice5 = New-Object System.Management.Automation.Host.ChoiceDescription "&Exit", `
        "Exits this script."

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($choice1, $choice2, $choice3, $choice4, $choice5)

    $result = $host.ui.PromptForChoice($title, $message, $options, 4) 

    switch ($result)
    {
        0 { installUpdateAgent }
        1 { uninstallUpdateAgent }
        2 { replaceHosts }
        3 { checkStatus }
        4 {}
    }

    # write-host "`nUsage: $scriptName [install|uninstall|run|status]"

    waitForUser
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

    # Add exclusion path for Windows Defender so it won't undo changes to hosts file
    Add-MpPreference -ExclusionPath "$hosts_file_loc"
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

    Remove-MpPreference -ExclusionPath "$hosts_file_loc"
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

function escalatePriv {
    # Get the ID and security principal of the current user account
    $myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
    $myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
 
    # Get the security principal for the Administrator role
    $adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
 
    # Check to see if we are currently running "as Administrator"
    if ($myWindowsPrincipal.IsInRole($adminRole))
    {
        # We are running "as Administrator" - so change the title and background color to indicate this
        $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)"
        $Host.UI.RawUI.BackgroundColor = "DarkRed"
        clear-host
    }
    else
    {
       # We are not running "as Administrator" - so relaunch as administrator
   
       # Create a new process object that starts PowerShell
       $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
   
       # Specify the current script path and name as a parameter
       $newProcess.Arguments = "& '" + $script:MyInvocation.MyCommand.Path + "'"
   
       # Indicate that the process should be elevated
       $newProcess.Verb = "runas";
   
       # Start the new process
       [System.Diagnostics.Process]::Start($newProcess);
   
       # Exit from the current, unelevated, process
       exit
    }
}

function outputHostsSize {
    $hostsSize=$(Get-Content $hosts_file_loc | Measure-Object -Line).Lines
    write-host "`nSize of hosts file: $hostsSize"
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

function waitForUser {
    write-host "`nDone! Press any key to continue..."
    Read-Host 
}

main $args