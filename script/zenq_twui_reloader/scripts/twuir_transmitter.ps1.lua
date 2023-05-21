return [[

$LivenessMarkerFilePath_self = "{{TRANSMITTER_MARKER_FILE}}"
New-Item -ItemType File -Path $LivenessMarkerFilePath_self -Force


$pipeName           = "{{BACKEND_PIPE_NAME}}"
$readyMarkerString  = "{{READY_MARKER_STRING}}"
$waiting_time_ms    = [int]( ([float]"{{WAITING_FOR_SIBLING_PROCESS_TIME__SECODNS}}" ) * 1000)




function RemoveMarkerFile {
    Remove-Item -Path $LivenessMarkerFilePath_self -Force
}



# Ensure at least one argument is passed
if ($args.Length -eq 0) {
    Write-Error  "`nNo command-line argument specified. Exit"
    RemoveMarkerFile
    Exit 1
}

# Check if the argument represents a valid file path string and parent directory in that path is exist or is curent directory (ex.: path='some_file.txt' -> parent directory is current one)
$LogfilePath = $args[0]
if (-not ((Test-Path -IsValid $LogfilePath) -and ([string]::IsNullOrWhiteSpace((Split-Path $LogfilePath -Parent)) -or (Test-Path (Split-Path $LogfilePath -Parent)))))
{
    Write-Error "`nThe specified argument is not a valid file path: '$LogfilePath'. Exit"
    RemoveMarkerFile
    Exit 1
}

$log_writer = New-Object System.IO.StreamWriter $LogfilePath
$log_writer.AutoFlush = $true

function Log {
    param (
        [string]$Msg
    )
    $log_writer.Write("$Msg`n")
}



Log "Start: $((Get-Date).ToString('HH:mm:ss.fff'))"




function SendToParentProcess {
    param (
        [string]$Result
    )
    Write-Host "$Result"
}

function Cleanup {
    try {
        $ResultsStream.Dispose()
        $pipe.Dispose()
    
        Log "Pipe and stream closed"
    } catch {
        Write-Error "Error occured while cleanup: '$($_.Exception.Message)'"
    }
}

function CleanupLogWriter {
    try {
        $log_writer.Dispose()
    } catch {
        Write-Error "Error occured while LogWriter cleanup: '$($_.Exception.Message)'"
    }

}



Register-EngineEvent -SourceIdentifier PowerShell.Exiting -SupportEvent -Action {
    Log "Ending..."

    Cleanup

    # Check if the file exists
    if (Test-Path -Path $LivenessMarkerFilePath_self -PathType Leaf) {
        # Remove the file
        RemoveMarkerFile
        Log "Marker file removed: '$LivenessMarkerFilePath_self'"
    } else {
        Log "Marker file does not exist: '$LivenessMarkerFilePath_self'`nHow this can be?"
    }

    Log "Timestamp: $((Get-Date).ToString('HH:mm:ss.fff'))`n  Script ended gracefully"

    CleanupLogWriter
}


$pipeServerName       = '.'  # means local computer server
$pipeDirectionClient  = [System.IO.Pipes.PipeDirection]::In
$pipeOptions          = [System.IO.Pipes.PipeOptions]::Asynchronous

$pipe = new-object System.IO.Pipes.NamedPipeClientStream($pipeServerName, $pipeName, $pipeDirectionClient, $pipeOptions)

$ResultsStream   = new-object System.IO.StreamReader $pipe



try {
    $pipe.Connect($waiting_time_ms)
}
catch [System.TimeoutException] {

    Write-Error @"
Timestamp: $((Get-Date).ToString("HH:mm:ss.fff"))
  Error (Establish Connection timed out): $($_)
  Worker is not alive? -> Exit
"@
    Exit 1
} 

catch {
    # Handle any other exception types
    Write-Error @"
Timestamp: $((Get-Date).ToString("HH:mm:ss.fff"))
  An unexpected error occurred while trying to connect to server: 
  $($_)
"@
    Exit 1
}


Log @"
Timespamp: $((Get-Date).ToString('HH:mm:ss.fff'))
  Connected
"@


# put a special mark into pipe so lua script can skip all bullshit produced by Register-EngineEvent that we cannot mute
SendToParentProcess $readyMarkerString

while (
    $null -ne ($result = $ResultsStream.ReadLine())
) {
    Log "Data from Worker: '$result'"
    SendToParentProcess -Result $result
}


Log @"
Timestamp: $((Get-Date).ToString('HH:mm:ss.fff'))
  Pipe communication ended


"@

]]