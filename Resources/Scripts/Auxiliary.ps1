function Write-Log ($Message) {
    $LogTime = (Get-Date).ToString('HH:mm:ss.ff')
    Write-Output "[$LogTime] $Message" | Out-Host
}

function New-Dialog ($Message, $Option, $Icon) {
    return [Windows.MessageBox]::Show($Message, 'Rows', $Option, $Icon)
}

trap {
    New-Dialog "Fatal error: $_`n`nClick OK to exit" 'OK' 'Error'
    throw $_
    exit
}

function Expand-Path ($Path) {
    return $ExecutionContext.InvokeCommand.ExpandString($Path)
}