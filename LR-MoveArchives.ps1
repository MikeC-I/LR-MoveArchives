<#
.NAME 
    LR-MoveArchives
.SYNOPSIS
    Script for moveing inactive archive files.
.DESCRIPTION
    A simple script to reliably move inactive archive files from one folder to another based on age (given in the directory/filename)
.PARAMETER SourceFolder
    [REQUIRED] [STRING] The source folder for archives
.PARAMETER DestinationFolder
    [REQUIRED] [STRING] Path where the archives will be moved to
.PARAMETER DaysOld
    [REQUIRED] [INT] Age of archives to be moved in days (default is 7)
.EXAMPLE
    LR-OutputSystemMonitors.ps1 -ServerName MyLRServer -EntityID 1 -OutPath C:\Reports\CSVs -Prefix CMPNY -Email me@company.com
.NOTES
    Make sure to run as a user that has the correct permissions to the source and destination folders
    Argument for scheduled task: -Noninteractive -ExecutionPolicy Bypass -Command "C:\LogRhythm\Scripts\LR-MoveArchives\LR-MoveArchives -SourceFolder "D:\LogRhythmArchives\Inactive" -DestinationFolder "D:\LRTest\" -DaysOld 7
    
    Change Log:
        2021/01/04 - Initial Commit of complete script for use in customer environments
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$SourceFolder,
    [Parameter(Mandatory = $true)] [string]$DestinationFolder,
    [Parameter(Mandatory = $true)] [int32]$DaysOld = 7
)

$logfile = "C:\LogRhythm\Scripts\LR-MoveArchives\LR-MoveArchives.log"
$globalloglevel = 1

Function Write-Log {  

    # This function provides logging functionality.  It writes to a log file provided by the $logfile variable, prepending the date and hostname to each line
    # Currently implemented 4 logging levels.  1 = DEBUG / VERBOSE, 2 = INFO, 3 = ERROR / WARNING, 4 = CRITICAL
    # Must use the variable $globalloglevel to define what logs will be written.  1 = All logs, 2 = Info and above, 3 = Warning and above, 4 = Only critical.  If no $globalloglevel is defined, defaults to 2
    # Must use the variable $logfile to define the filename (full path or relative path) of the log file to be written to
               
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string]$logdetail,
        [Parameter(Mandatory = $false)] [int32]$loglevel = 2
    )
    if (($globalloglevel -ne 1) -and ($globalloglevel -ne 2) -and ($globalloglevel -ne 3) -and ($globalloglevel -ne 4)) {
        $globalloglevel = 2
    }

    if ($loglevel -ge $globalloglevel) {
        try {
            $logfile_exists = Test-Path -Path $logfile
            if ($logfile_exists -eq 1) {
                if ((Get-Item $logfile).length/1MB -ge 10) {
                    $logfilename = [io.path]::GetFileNameWithoutExtension($logfile)
                    $newfilename = "$($logfilename)"+ (Get-Date -Format "yyyyMMddhhmmss").ToString() + ".log"
                    Rename-Item -Path $logfile -NewName $newfilename
                    New-Item $logfile -ItemType File
                    $this_Date = Get-Date -Format "MM\/dd\/yyyy hh:mm:ss tt"
                    Add-Content -Path $logfile -Value "$this_Date [$env:COMPUTERNAME] $logdetail"
                }
                else {
                    $this_Date = Get-Date -Format "MM\/dd\/yyyy hh:mm:ss tt"
                    Add-Content -Path $logfile -Value "$this_Date [$env:COMPUTERNAME] $logdetail"
                }
            }
            else {
                New-Item $logfile -ItemType File
                $this_Date = Get-Date -Format "MM\/dd\/yyyy hh:mm:ss tt"
                Add-Content -Path $logfile -Value "$this_Date [$env:COMPUTERNAME] $logdetail"
            }
        }
        catch {
            Write-Error "***ERROR*** An error occured writing to the log file: $_"
        }
    }
}

Function Move-Archives {
    Write-Log -loglevel 2 -logdetail "Beginning archive move.."
    Write-Log -loglevel 1 -logdetail "Source folder: $($SourceFolder)"
    Write-Log -loglevel 1 -logdetail "Destination folder: $($DestinationFolder)"
    Write-Log -loglevel 1 -logdetail "Checking source folder $($SourceFolder)..."
    $sourcexists = Test-Path -Path $SourceFolder
    if ($sourcexists -ne $true) {
        Write-log -loglevel 4 "***CRITICAL*** Source folder does not exist, exiting."
        Exit
    }
    else {
        Write-Log -loglevel 1 -logdetail "Source path exists, continuing..."
    }
    $then = (get-date).AddDays(-$DaysOld).ToString("yyyyMMdd")      
    Write-Log -loglevel 1 -logdetail "Moving archives older than $($then)."
    $timespent = Measure-Command {
        Get-ChildItem $SourceFolder | ForEach {
            $thisobject = $_
            if ($thisobject.name.split("_")[0] -lt $then) {            
                Try {
                    Write-Log -loglevel 1 -logdetail "Moving object $($thisobject.name)..."
                    $timespentobject = Measure-Command {
                        Move-Item -Path $thisobject.FullName -Destination $DestinationFolder
                    }
                    $timespentobject_f = "{0:hh\:mm\:ss\.fff}" -f ([TimeSpan] $timespentobject)
                    Write-log -loglevel 1 -logdetail "Moved $($thisobject.name) in $($timespentobject_f)"
                }
                Catch {
                    Write-Log -loglevel 3 -logdetail "***ERROR*** Could not move $($thisobject.name): $_"
                }
            }
        }
    }
    $timespent_f = "{0:hh\:mm\:ss\.fff}" -f ([TimeSpan] $timespent)
    Write-Log -loglevel 2 -logdetail "Total time: $($timespent_f)"
}

Move-Archives
