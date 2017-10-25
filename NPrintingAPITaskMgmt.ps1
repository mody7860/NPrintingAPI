<#  
.SYNOPSIS  
    Execute task reloads (by name ) and return status message on success/failure.
     
.DESCRIPTION  
    This script authnticates with the NPrinting API, then uses session tokens to get tasks lists and finds the matching task to execute.  
    when a task is found then script will then invoke the task and monitor its status.  When complete the script returns the relevant status back
    to the caller.

.EXAMPLE    
    ./NPrinting.ps1 -hostname nprintserver:4993 -taskname "Reload Operations Monitor" -interval 15

    Start the named task "Reload Operations Monitor" on nprintserver.airproducts.com. 
    Check the status of the task every 15 seconds.
    
.EXAMPLE
    ./NPrinting.ps1 -hostname nprintserver.airproducts.com -taskname "Reload Executive Dashboard" -interval 60

    Start the named task "Reload Executive Dashboard" on nprintserver.airproducts.com. Check the status of the task every 60 seconds.


.PARAMETER hostname
            Hostname (or IP address) of the Nprinting Server 
.PARAMETER taskname
            Named reload task to execute.

.PARAMETER interval
            The amount of time (in seconds) between task status checks for the currently executing task.
                  
.NOTES  
    File Name  : sensetaskreload.ps1
    Version    : 1.0 
    Author     : Irshad Mody 
    Requires   : PowerShell (tested on v5)
                 
                 Port 4993 exception in firewall on Nprinting server.
#>

# Accept command line parameters
[CmdletBinding()]
     Param (
     [Parameter(Position=0,mandatory=$true,ParameterSetName="byname")]
	 #[Parameter(Position=0,mandatory=$true,ParameterSetName="byid")]
     [string]$hostname, 
     [Parameter(Position=1,mandatory=$true,ParameterSetName="byname")]
     [string]$taskname,
	 #[Parameter(Position=1,mandatory=$true,ParameterSetName="byid")]
     #[string]$taskid,
     #[Parameter(Position=2,mandatory=$false,ParameterSetName="byname")] 
	 #[Parameter(Position=2,mandatory=$false,ParameterSetName="byid")]
     #[string]$trustedcert = "QlikClient", 
     [Parameter(Position=2,mandatory=$false,ParameterSetName="byname")]
	 #[Parameter(Position=2,mandatory=$false,ParameterSetName="byid")]
     [int]$interval = 10
     )

# Set debugging
If ($PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent) 
{
    $global:dbug = $true
} else {
    $global:dbug = $false
}

# Function to perform REST calls to the NPRINTING API.
 function QRSConnect
 { 
    param ( 
        [Parameter(Position=0,Mandatory=$true)] 
        [string] $command = $null, 
        [Parameter(Position=1,Mandatory=$false)] 
        [System.Collections.Generic.Dictionary[System.String,System.String]] $header = $null, 
        [Parameter(Position=2,Mandatory=$true)] 
        [string] $method = $null,
        [Parameter(Position=3,Mandatory=$false)][ref]$cookieReturn,
        #[string] $cookieReturn = $null,  
        [Parameter(Position=4,Mandatory=$false)] 
        [System.Object] $body = $null
        ) 

    $response = $null
    $contenttype = "application/json" 
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    
    foreach($coo in $global:responsecookies){
      $cook = New-Object System.Net.Cookie 
    
      $cook.Name = $coo.Name
      $cook.Value = $coo.value
      $cook.Domain = $coo.domain
      $cook.Path = "/"

      $session.Cookies.Add($cook);
    }
    
    if($method -eq "POST") 
    { 
        try{
        $response = Invoke-RestMethod $command -ContentType $contenttype -Headers $header -Method $method -Body $body -WebSession $session #-Certificate $cert -Body $body
        }
    catch{
        Write-Host "A failure has occurred when attempting to reload the task. Does the task name exist?"
        Write-host "Error description: " $_
        exit 97
        } 
    } 
    else 
    { 
        try{
            if ( -not $global:responsecookies ){
                $response = Invoke-RestMethod $command -Headers $header -Method $method  -UseDefaultCredentials -SessionVariable websession  #-Certificate $cert 
                }
            else{
                $response = Invoke-RestMethod $command -Headers $header -Method $method  -UseDefaultCredentials -WebSession $session #-Certificate $cert 
                #$response1 = ConvertTo-Json $response 
                }
        
            if ( -not $global:responsecookies ) { 
                $global:responsecookies = $websession.Cookies.GetCookies($command) 
                $global:setCook = $responsecookies["NPWEBCONSOLE_SESSION"]
                foreach ($cookie in $responsecookies) { 
                     # You can get cookie specifics, or just use $cookie
                     if ( $cookie.name -eq "NPWEBCONSOLE_XSRF-TOKEN" )
                     {
                        $cookieReturn.Value = $cookie.value
                     }
                }
            }
        }
        catch{
            Write-Host "Task failed! An error was encountered reloading the task."
            Write-host "Error description: " $_
            exit 97
        }
    } 
 
    #return ConvertTo-Json $response 
    return $response
} 

#set any global vars for this script
$global:xrfkey = ""
$global:setCook = ""
$global:responsecookies=$null


# Create headers for the request.
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]" 


If($dbug){Write-Host "Hostname: " $hostname}

#setup root path
$rootpath = "http://" + $hostname + "/api/v1"


#authenticate first
$path = "/login/ntlm"
$theCommand = $rootpath + $path 

$mycookie=$null

#authenticate and get cookie
$authresult = QRSConnect -command $theCommand -header $headers -method "GET" -cookieReturn ([ref]$mycookie)

#add cookie to header
$headers.Add("X-XSRF-TOKEN",$mycookie) 
#$headers.Add("User-Agent", "Windows")

Write-Host "Authenticated"

$path = "/tasks"
$theCommand = $rootpath + $path

if ( $dbug ){
    Write-Host "Command to get publish tasks:" $theCommand
}

#get all the tasks 
$tasks = QRSConnect -command $theCommand -header $headers -method "GET" 
Write-Host "Total Task count = " $tasks.data.items.count
$runTaskId = ""

#find the target task id
foreach( $dataitem in $tasks.data.items)
{
    if ( $dataitem.name -eq $taskname )
    {
        $runTaskId = $dataitem.id
    }
}

if ( $runTaskId -eq "" )
{
    Write-Host "No Tasks Found with name " $taskname
    exit 100
}

#$path = "/ondemand/requests"
$path="/tasks/$runTaskId/executions"


$theCommand = $rootpath + $path


If($dbug){ 
    Write-Host "Command for reload tasks:" $theCommand 
}

$taskResult = QRSConnect -command $theCommand -header $headers -method "POST"

#finally setup the poll to check when the task finishes.
$path="/tasks/" + $runTaskId + "/executions/" + $taskResult.data.id
$theCommand = $rootpath + $path
do{   
    If($dbug){ Write-Host "Checking on task status:" $theCommand }
    $taskstatus = QRSConnect $theCommand $headers "GET"
    #$x = ConvertFrom-Json $tasks
    Write-host "Checking status - "$taskstatus.data.status
    Start-Sleep -s $interval
} while(($taskstatus.data.status -eq "Enqueued" ) -or ($taskstatus.data.status -eq "Assigned" ) -or ( $taskstatus.data.status -eq "Running" ))


if ( $taskstatus.data.status -ne "Completed" ){
    write-host "Task: $taskname failed"
    exit 99
}
else
{
    write-host "Task: $taskname completed successfully"
}

