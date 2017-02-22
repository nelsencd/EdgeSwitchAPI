## EdgeSwitch API
This PowerShell module can be used to script with the EdgeSwitch using PowerShell cmdlets.
- Not all commands can be used (yet))
- There is still work to be done so please use the Github issues to share your ideas.
- Please read the security notice below before using the module.

## Features
The EdgeSwitch API can be used to do the following:
- Connect and disconnect from the EdgeSwitch
- Download a copy of the startup configuration to your computer
- Set an SNMP community string
- Save the switch configuration

## Using the API
- Connect to the switch and store the session in a variable:
$es = Connect-EdgeSwitch -Switch $SwitchIP -UserName $UserName -Password $Password -HttpOnly

- Download the configuration to your computer:
Backup-EdgeSwitchStartupConfiguration -WebSession $es -DestinationPath "C:\Backups"

- Disconnect (logout) from the switch:
Disconnect-EdgeSwitch -WebSession $es