# Host Updater Powershell script for Windows.  

## Description

Downloads new hosts file from http://winhelp2002.mvps.org/hosts.txt, and checks for any redirects that don't go to 0.0.0.0.  

Appends to your current hosts file.

## Installation

Right-click on the following link and save it to your computer.  Then right-click on the file and select "Run with Powershell":

https://raw.githubusercontent.com/M-D-M/Host_Updater_for_Windows/master/update_hosts_file.ps1

## Problems

If the script is not running on your computer, you may have to allow powershell scripts to run.  To do this:

- Press the Windows key and type "Powershell"
- Right-click on the result and select "Run as administrator"
- Copy and paste the following command and press the Enter key
  - `set-executionpolicy remotesigned -scope localmachine`
- Press "Y" in the message that appears, and press the Enter key

Now you should be all set to run the host updater!
