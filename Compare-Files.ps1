function Compare-Files {
    <#
    .SYNOPSIS
    This function will find duplicate files in a specified directory and will output to the results to a log file, including the hash for each file for analysis.
    .DESCRIPTION
    This function will find duplicate files in a specified directory and will output the results to a log file that includes the hash for each file for analysis.
    It will output how many files it has processed and the ammount of resources the computer is using during the task.
    .PARAMETER File_Extension
    Specify the file extensions you want to look for, defaults to "*" (comma separated)
    .PARAMETER Search_Location
    Specify the path for target
    .PARAMETER Search_Depth
    Specify how deep you want to go in the recurse, defaults to "*"
    .PARAMETER Log_Location
    Specify the path for the log output
    .PARAMETER Monitoring_Frequency
    Define in seconds the interval to show the monitoring output
    .NOTES
    Examples:
    Compare-Files -Search_Location c:\temp -Log_Location C:\test\logs.txt -Monitoring_Frequency 5 -File_Extension *.log,*.info
    #>
    [cmdletbinding()]
    Param ( 
        [parameter(Mandatory = $false, HelpMessage = "Type the file extensions to search for (comma separated) ")]
        [string[]]$File_Extension = "*",
        
        [parameter(Mandatory = $true, HelpMessage = "Target location for the search ex: C:\test ")]
        [string[]]$Search_Location,
        
        [parameter(Mandatory = $false, HelpMessage = "Numeric value that defines how many sub directories deep the search should include")]
        [ValidateNotNullorEmpty()]
        [int]$Search_Depth = '',

        [parameter(Mandatory = $true, HelpMessage = "File path for script output")]
        [ValidateNotNullorEmpty()]
        [string]$Log_Location,

        [parameter(Mandatory = $false, HelpMessage = "Number of seconds between monitoring update outputs")]
        [ValidateNotNullorEmpty()]
        [int]$Monitoring_Frequency = '10'

    )

    #Deletes and create destination for logs
    Clear-Host
    if (Get-ChildItem $Log_Location -ErrorAction SilentlyContinue) {
        Remove-item $Log_Location -Force -ErrorAction SilentlyContinue
    }
    Write-Host 'Creating Log repository'
    New-Item $Log_Location -Force 

    #Remove any jobs that might exist
    Get-job | Stop-Job -PassThru | Remove-Job
    #Creates a temp file for logs
    $tempfile = New-TemporaryFile 
    
    #Creates a job to look for duplicate files
    $job1 = Start-job -ScriptBlock {
        #Gets a list of files that are in the log path
        $Files_A = Get-ChildItem -Path $using:Search_Location -recurse -depth $using:Search_Depth -Include $using:File_Extension
        #Looks for duplicates
        $Files_B = $Files_A | Group-Object Name | Where-Object { $_.count -gt 1 } | Sort-Object name, group
        
        [System.Collections.ArrayList]$hasharray = @()
        foreach ( $duplicate_file in $Files_B.group) {
            $duplicate_file.FullName | out-file $using:tempfile.FullName -Append
            $hash = Get-FileHash -path $duplicate_file 
            $hasharray += $hash
        } 
        $hasharray | Select-Object Path, Hash | Out-File -FilePath $using:Log_Location
    }

    do {
        Get-Counter -Counter '\Processor(_total)\% Processor Time'
        Get-Counter -Counter "\LogicalDisk(_Total)\% Free Space" 
        Get-Counter '\memory\% committed bytes in use' 
        $count_log = Get-Content -Path $tempfile.FullName | Measure-Object -Line
        "{0} {1}" -f ($count_log.Lines), 'files processed'
        $job_status = $job1 | Get-Job
        Start-Sleep $Monitoring_Frequency
    }
    until ( $job_status.State -eq 'Completed'

    )
    Remove-Item $tempfile.FullName
    Write-output "You will find your log in $log_location"
}