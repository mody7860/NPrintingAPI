# NPrintingAPI
Repository contains assets which enable schedule actions with the Qlik NPrinting API

# .SYNOPSIS  
    Execute task (by name ) and return status message on success/failure.
     
# .DESCRIPTION  
    This script authnticates with the NPrinting API, then uses session tokens to get tasks lists and finds the matching task to execute.  
    when a task is found then script will then invoke the task and monitor its status.  When complete the script returns the relevant  
    status back to the caller.
# .EXAMPLE    
    ./NPrintingAPITaskMgmt.ps1 -hostname nprintserver:4993 -taskname "Reload Operations Monitor" -interval 15
    Start the named task "Reload Operations Monitor" on nprintserver.airproducts.com. 
    Check the status of the task every 15 seconds.
    
# .EXAMPLE
    ./NPrintingAPITaskMgmt.ps1 -hostname nprintserver.airproducts.com -taskname "Reload Executive Dashboard" -interval 60
    Start the named task "Reload Executive Dashboard" on nprintserver.airproducts.com. Check the status of the task every 60 seconds.
    .PARAMETER hostname
                Hostname (or IP address) of the Nprinting Server 
    .PARAMETER taskname
                Named task to execute.
    .PARAMETER interval
                The amount of time (in seconds) between task status checks for the currently executing task.
                  
    .NOTES  
        File Name  : sensetaskreload.ps1
        Version    : 1.0 
        Author     : Irshad Mody 
        Requires   : PowerShell (tested on v5)
                 
                 Port 4993 exception in firewall on Nprinting server.
