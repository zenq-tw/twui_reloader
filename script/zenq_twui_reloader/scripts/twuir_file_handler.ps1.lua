return [[

$LivenessMarkerFilePath_self = "{{WORKER_MARKER_FILE}}"
New-Item -ItemType File -Path $LivenessMarkerFilePath_self -Force

Write-Host "Start: $((Get-Date).ToString('HH:mm:ss.fff'))"


$pipeName = "{{BACKEND_PIPE_NAME}}"
$waiting_time_ms = [int]( ([float]"{{WAITING_FOR_SIBLING_PROCESS_TIME__SECODNS}}" ) * 1000)



Register-EngineEvent -SourceIdentifier PowerShell.Exiting -SupportEvent -Action {
    Write-Host "Ending..."
    
    # Check if the file exists
    if (Test-Path -Path $LivenessMarkerFilePath_self -PathType Leaf) {
        # Remove the file
        Remove-Item -Path $LivenessMarkerFilePath_self -Force
        Write-Host "Marker file removed: '$LivenessMarkerFilePath_self'"
    } else {
        Write-Host "Marker file does not exist: '$LivenessMarkerFilePath_self'`nHow this can be?"
    }

    Cleanup

    Write-Host @"
Timestamp: $((Get-Date).ToString('HH:mm:ss.fff'))
  Script ended gracefully
"@
}




$pipeDirectionServer  = [System.IO.Pipes.PipeDirection]::Out
$pipeTransmissionMode = [System.IO.Pipes.PipeTransmissionMode]::Message
$pipeOptions          = [System.IO.Pipes.PipeOptions]::Asynchronous

$pipe = New-Object System.IO.Pipes.NamedPipeServerStream($pipeName, $pipeDirectionServer, 1, $pipeTransmissionMode, $pipeOptions)


$RequestsStream = [System.IO.StreamReader]::new([System.Console]::OpenStandardInput())
$ResultsStream = new-object System.IO.StreamWriter $pipe


function WriteToPipe {
    param (
        [string]$Data
    )

    try {
        $ResultsStream.WriteLine($Data)
    }
    catch {
        Write-Error @"
Timestamp: $((Get-Date).ToString('HH:mm:ss.fff'))
  An error occurred while writing to the pipe $($pipeName):
  $($_.Exception.Message)
"@
    }
}


function Cleanup {
    try {
        $RequestsStream.Dispose()
        $ResultsStream.Dispose()
        $pipe.Dispose()

        Write-Host "Pipe and streams closed"
    } catch {
        Write-Error "Error occured while cleanup: '$($_.Exception.Message)'"
    }
}




$ClientWaiter = $pipe.BeginWaitForConnection($null, $null)

if ($ClientWaiter.AsyncWaitHandle.WaitOne($waiting_time_ms)) {
    Write-Host "Timestamp: $((Get-Date).ToString('HH:mm:ss.fff'))`n  Client connected"
    
    $pipe.EndWaitForConnection($ClientWaiter)    
    $ResultsStream.AutoFlush = $true

    while ($null -ne ($line = $RequestsStream.ReadLine())) {
        if (-not ($pipe.IsConnected)) {
            Write-Host "Timestamp: $((Get-Date).ToString('HH:mm:ss.fff'))`n  Client disconnected"
            break
        }

        try {
            Write-Host "Received input: '$line'"
            $file = $line.Trim()

            if (Test-Path -Path $file -PathType Leaf) {
                $LastWriteTime = (Get-Item -Path $file).LastWriteTime
                Write-Host "File last write time is: $LastWriteTime"

                $result = $LastWriteTime.ToString("ddMMyy_HHmmss")

            } else {
                Write-Host "The specified file does not exist."
                $result = "Not found"
            }

            WriteToPipe -Data $result
    
            Write-Host "Data written successfully: '$result'`n"
        } catch {

            Write-Host @"
Timestamp: $((Get-Date).ToString('HH:mm:ss.fff'))
An error occurred:
  $($_.Exception.Message)
"@

            break
        }
    }


    Write-Host @"
Timestamp: $((Get-Date).ToString('HH:mm:ss.fff'))
  Pipe communication ended
"@

} else {
    $sec  = $waiting_time_ms / 1000

    Write-Host @"
Timestamp: $((Get-Date).ToString('HH:mm:ss.fff'))
  Client didn't connected to the pipe for $sec seconds
  Transmitter is not alive? -> Exit
"@

}


]]