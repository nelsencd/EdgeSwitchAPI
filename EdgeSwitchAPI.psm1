####
# Name:     EdgeSwitchAPI.psm1
# Purpose:  EdgeSwitch API
# Author:   Cody Nelsen
# Revision: 2017-02-15 - initial version
####

####
# Source(s):
# http://blogs.lockstepgroup.com/2013/02/automatic-network-device-monitoring-with-prtg.html
# https://github.com/malle-pietje/UniFi-API-browser
####

######ignore invalid SSL Certs##########
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

###############################################################################
## API Functions
###############################################################################

function Connect-EdgeSwitch {
	<#
	.SYNOPSIS
		Establishes initial connection to the EdgeSwitch.
		
	.DESCRIPTION
		The Connect-EdgeSwitch cmdlet establishes and validates connection parameters to allow further communications to the EdgeSwitch. The cmdlet needs at least three parameters:
		 - IP or hostname of the switch
		 - An authenticated username
		 - A password
		
		The cmdlet returns an object that contains the websession, IP or hostname, protocal, and port that is needed to provide to further calls to the API
        and the result of the web request.
	
	.EXAMPLE
		Connect-EdgeSwitch "192.168.1.253" "admin" "password"
		
		Connects to EdgeSwitch using the default port (443) over SSL (HTTPS) using the username "admin" and the password password.
		
	.EXAMPLE
		Connect-EdgeSwitch "192.168.1.253" "jsmith" "1234567890" -HttpOnly
		
		Connects to EdgeSwitch using the default port (80) over HTTP using the username "jsmith" and the password 1234567890.
		
	.EXAMPLE
		Connect-EdgeSwitch -Switch "192.168.1.253" -UserName "admin" -Password "1234567890" -Port 8080 -HttpOnly
		
		Connects to EdgeSwitch using port 8080 over HTTP using the username "admin" and the password 1234567890.
		
	.PARAMETER Switch
		IP address or host name of the switch. Don't include the protocol part ("https://" or "http://").
		
	.PARAMETER UserName
		Switch username to use for authentication.
		
	.PARAMETER Password
		Passwrd for the switch username. Needs to be cleartext.
	
	.PARAMETER Port
		The port that the EdgeSwith is accessible on. This defaults to port 443 over HTTPS, and port 80 over HTTP.
	
	.PARAMETER HttpOnly
		When specified, configures the connection to run over HTTP rather than the default HTTPS.
	#>
    
    Param (
		[Parameter(Mandatory=$True,Position=0)]
		[ValidatePattern("\d+\.\d+\.\d+\.\d+|(\w\.)+\w")]
		[string]$Switch,

		[Parameter(Mandatory=$True,Position=1)]
		[string]$UserName,

		[Parameter(Mandatory=$True,Position=2)]
		[string]$Password,

		[Parameter(Mandatory=$False,Position=3)]
		[int]$Port = $null,

		[Parameter(Mandatory=$False)]
		[alias('http')]
		[switch]$HttpOnly
	)

    BEGIN {
		if ($HttpOnly) {
			$Protocol = "http"
			if (!$Port) { $Port = 80 }
		} else {
			$Protocol = "https"
			if (!$Port) { $Port = 443 }
		}
    }

    PROCESS {

        
        #Create the initial URL
        $Url = $Protocol + "://" + $Switch + ":" + $Port + "/htdocs/pages/main/main.lsp"
        
        #Make the innitial conneciton to the switch
        $Result = Invoke-WebRequest $Url -SessionVariable Session

        $FormFields = @{username=$UserName;password=$Password;accept_eula=0;require_eula=0}

        #Create the URL to log in to the switch
        $Url = $Protocol + "`://" + $Switch + "`:" + $Port + "/htdocs/login/login.lua"

        #Log in to the switch
        $Result = Invoke-WebRequest -uri $Url -WebSession $Session -Body $FormFields -Method Post

        #Return the websession, switch IP/hostname, protocol used, port used, and result for use with other cmdlets
        $Return = "" | Select-Object WebSession,Switch,Protocol,Port,Result
        $Return.WebSession = $Session
        $Return.Switch     = $Switch
        $Return.Protocol   = $Protocol
        $Return.Port       = $Port
        $Return.Result     = $Result

        return $Return

    }


}

function Disconnect-EdgeSwitch {
    <#
    .SYNOPSIS
        Logs out from connection to EdgeSwitch

    .DESCRIPTION
        The Disconnect-EdgeSwitch cmdlet logs out from an established connection to an EdgeSwicth. The cmdlet needs one parameter:
        - WebSession

        This cmdlet does not return anything.

    .EXAMPLE
        Disconnect-EdgeSwitch -WebSession $es

        Logs out from the from the given web session to the EdgeSwitch.

    .PARAMETER
        WebSession stored when the Get-EdgeSwitch cmdlet is run.

    #>

    param(
        [Parameter(Mandatory=$True,Position=0)]
        $WebSession

    )

    PROCESS {
        
        #Create the URL to logout from the switch
        $Url = $WebSession.Protocol + "://" + $WebSession.Switch + ":" + $WebSession.Port + "/htdocs/pages/main/logout.lsp"

        #Logout from the switch
        $Result = Invoke-WebRequest -uri $Url -WebSession $WebSession.WebSession -Method Get

    }
}

function Backup-EdgeSwitchStartupConfiguration {
	<#
	.SYNOPSIS
		Downloads the startup configuration from the switch.
		
	.DESCRIPTION
		The Backup-EdgeSwitchStartupConfiguration cmdlet uses http to download the startup configuration from the switch to a specified path using a previously created web session. 
        The cmdlet needs two parameters:
		 - WebSession
		 - Path
		
		This cmdlet returns the result of the web request.
	
	.EXAMPLE
		Backup-EdgeSwitchStartupConfiguration -WebSession $es -DestinationPath "C:\Users\admin\Downloads\"
		
		Connects to EdgeSwitch using the stored WebSession $es generated from the Get-EdgeSwtich cmdlet and saves the config to C:\Users\admin\Downloads
		
	.PARAMETER WebSession
		WebSession stored when the Get-EdgeSwtich cmdlet is run.
		
	.PARAMETER DestinationPath
		Path where you would like to download the file. Do not include the file name. It can include the trailing slash.
	#>
    
    Param (
		[Parameter(Mandatory=$True,Position=0)]
		$WebSession,

		[Parameter(Mandatory=$True,Position=1)]
		[string]$DestinationPath
	)

    PROCESS {

        #Create the URL that create the temp TempConfigScript.scr that we will download
        $Url = $WebSession.Protocol + "://" + $WebSession.Switch + ":" + $WebSession.Port + "/htdocs/lua/ajax/file_upload_ajax.lua?protocol=6"
        
        $FormFields = @{"file_type_sel[]"="config"}
        
        #Tell the switch to create the TempConfigScript.scr file
        $Result = Invoke-WebRequest -Uri $url -WebSession $WebSession.WebSession -Method Post -Body $FormFields `
            -ContentType "application/x-www-form-urlencoded"
        
        $Date = Get-Date -Format yyyyMMdd_HHmmss
        
        #Create the URL to download the file
        $Url = $WebSession.Protocol + "://" + $WebSession.Switch + ":" + $WebSession.Port + "/htdocs/pages/base/http_download_file.lua?filepath=/mnt/download/TempConfigScript.scr"
        
        #Check the $DestinationPath parameter to see if it has a trailing \ or not and add it if needed and the file name in the format of yyyyMMdd_HHmmss_switch.scr
        $LastCharacter = $DestinationPath.Substring($DestinationPath.Length - 1)
        if($LastCharacter -ne "\") {
            
            $FullPath = $DestinationPath + "\" + $Date + "_" + $WebSession.Switch + ".scr"

        } else {

            
            $FullPath = $DestinationPath + $Date + "_" + $WebSession.Switch + ".scr"

        }
        
        #Download the file
        $Result = Invoke-WebRequest -Uri $Url -WebSession $WebSession.WebSession -Method Get -ContentType "application/force-download" -OutFile $FullPath

        return $Result

    }

}

function Add-EdgeSwitchSNMPCommunityGroup {
	<#
	.SYNOPSIS
		Adds an SNMP community string for the EdgeSwitch
		
	.DESCRIPTION
		The Add-EdgeSwitchSNMPCommunityGroup cmdlet sets the SNMP community group for the EdgeSwitch. 
        The cmdlet needs at least three parameters:
		 - WebSession
		 - CommunityName
         - GroupName
         - IPAddress
		
		This cmdlet does not return anything.
	
	.EXAMPLE
		Add-EdgeSwitchSNMPCommunityGroup -WebSession $es -CommunityName "public" -GroupName "DefaultRead" -IPAddress "192.168.1.2"
		
		Connects to EdgeSwitch using the stored WebSession $es generated from the Get-EdgeSwtich cmdlet and adds a read only SNMP community string for the server at 192.168.1.2
		
	.PARAMETER WebSession
		WebSession stored when the Get-EdgeSwtich cmdlet is run.
		
	.PARAMETER CommunityName
		The SNMP community string
    
    .PARAMETER GroupName
        The permissions given to the community string

    .PARAMETER IPAdress
        The IP Address of the server that will receive the SNMP information
	#>
    
    Param (
		[Parameter(Mandatory=$True,Position=0)]
		$WebSession,

		[Parameter(Mandatory=$True,Position=1)]
		[string]$CommunityName,

        [Parameter(Mandatory=$True,Position=2)]
        [ValidateSet("DefaultRead","DefaultSuper","DefaultSuper")]
		[string]$GroupName = "DefaultRead",

        [Parameter(Mandatory=$false,Position=3)]
		[string]$IPAddress = "0.0.0.0"
	)

    PROCESS {
        
        #Create the URL
        $Url = $WebSession.Protocol + "://" + $WebSession.Switch + ":" + $WebSession.Port + "/htdocs/pages/base/snmp_community_group_modal.lsp"

        $FormFields = @{community_name=$CommunityName;group_name_sel=$GroupName;ip_address=$IPAddress;community_index="4294967295";b_modal1_clicked="b_modal1_submit"}

        #Set the SNMP string
        $Result = Invoke-WebRequest -uri $Url -WebSession $WebSession.WebSession -Body $FormFields -Method Post

    }

}

function Save-EdgeSwitchConfiguration {
	<#
	.SYNOPSIS
		Saves the configuration of the EdgeSwitch
		
	.DESCRIPTION
		The Save-EdgeSwitchConfiguration cmdlet saves the configuration of the EdgeSwitch.
        The cmdlet needs one parameter:
		 - WebSession
		
		This cmdlet does not return anything.
	
	.EXAMPLE
		Save-EdgeSwitchConfiguration -WebSession $es
		
		Connects to EdgeSwitch using the stored WebSession $es generated from the Get-EdgeSwtich cmdlet and saves the configuration
    
    .PARAMETER WebSession
		WebSession stored when the Get-EdgeSwtich cmdlet is run.	
	#>

    Param (
		[Parameter(Mandatory=$True,Position=0)]
		$WebSession
    )

    PROCESS {
        
        #Create the URl 
        $Url = $WebSession.Protocol + "://" + $WebSession.Switch + ":" + $WebSession.Port + "/htdocs/lua/ajax/save_cfg.lua?save=1"

        #Save the configuration
        $Result = Invoke-WebRequest -uri $Url -WebSession $WebSession.WebSession -Method Post

    }

}

###############################################################################
## PowerShell Module Functions
###############################################################################

Export-ModuleMember *-*
