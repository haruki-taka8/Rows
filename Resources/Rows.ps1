#Requires -Version 5

# Defaults
$baseDir = $PSScriptRoot
Push-Location $baseDir
Unblock-File .\Scripts\Auxiliary.ps1
Import-Module .\Scripts\Auxiliary.ps1 -Force
Write-Log 'Rows 22.12'
Write-Log
Write-Log 'Define defaults'
Add-Type -AssemblyName PresentationFramework

# XAML & GUI
Unblock-File .\Classes\Csv.psm1, .\Classes\Rows.psm1
Import-Module .\Classes\Csv.psm1, .\Classes\Rows.psm1 -Force
$rows = New-Rows

# Modules
Write-Log 'Import modules'
(Get-ChildItem .\Scripts\*.ps1).ForEach({
    Unblock-File $_
    Write-Log "  - $($_.Name)"
    Import-Module $_ -Force
})

# Lifecycle
Write-Log 'Define lifecycle'
$rows.GUI.Rows.Add_ContentRendered({$rows.InitializeGUI()})

$rows.GUI.NewFile.Add_Click({
    $Columns = $rows.GUI.Column.Text
    if ($Columns -match '^,*$') {return}

    $Columns,'Edit me!' | Set-Content (Expand-Path $rows.Config.CsvPath)
    $rows.InitializeGUI()
})

$rows.GUI.Rows.Add_Closing({
    Write-Log 'Cleanup'
    # Don't check for $rows.GUI.Commit.IsEnabled
    # The property is FALSE when ReadWrite is disabled
    if ($Args[0].Title -eq '*Rows') {
        Write-Log 'Changes unsaved, asking for confirmation'
        $Dialog = New-Dialog 'Save changes before exiting?' 'YesNoCancel' 'Question'
    }

    if ($Dialog -eq 'Cancel') {
        $_.Cancel = $true
        return

    } elseif ($Dialog -eq 'Yes') {
        # Skip ReadWrite check
        $rows.Csv.Export($rows.Config.CsvPath, $rows.Config.HasHeader)
    }

    Remove-Variable baseDir,rows -Scope Script -Force
    Remove-Module Edit,Filter,Keybind,Csv,Auxiliary,Rows -Force
    Pop-Location
})

# Minimize console & display GUI
$rows.GUI.Splashscreen.Visibility = 'Visible'
if ($Host.Name -eq 'ConsoleHost') {
    powershell.exe -Window Minimized '#'
}

Write-Log 'Show splashscreen'
[Void] $rows.GUI.Rows.ShowDialog()
