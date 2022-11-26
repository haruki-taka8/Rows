# Start Filter
$rows.GUI.Filterbar.Add_TextChanged({
    # Filter on ENTER pressed
    if ($rows.GUI.Filterbar.Text -match "\r\n") {
        $PrevCursor = $rows.GUI.Filterbar.SelectionStart - 2
        $rows.GUI.Filterbar.Text = $rows.GUI.Filterbar.Text.Replace("`r`n","")
        $rows.GUI.Filterbar.SelectionStart = $PrevCursor
 
        $rows.DoFilter()
    }
})

# Filter on Aliases/Filter clicked
$rows.GUI.InputAlias.Add_Click({$rows.DoFilter()})
$rows.GUI.OutputAlias.Add_Click({$rows.DoFilter()})
$rows.GUI.Filter.Add_Click({$rows.DoFilter()})

# Expand <ColumnName> notation
function Expand-ColumnNotation ($String, $ActiveRow) {
    $Match = $String | Select-String '(?<=<)(.+?)(?=>)' -AllMatches
    $Match.Matches.Value.ForEach({
        $String = $String.Replace("<$_>", $ActiveRow.$_)
    })
    return $String
}

# Set preview on row change
$rows.GUI.Grid.Add_SelectionChanged({
    $Path = Expand-Path $rows.Config.PreviewPath
    $Path = Expand-ColumnNotation $Path $rows.GUI.Grid.SelectedItem
    
    $Preview = $null
    if (Test-Path $Path) {
        # Don't permanently lock the file
        $Preview = [Windows.Media.Imaging.BitmapImage]::New()
        $Preview.BeginInit()
        $Preview.UriSource = $Path
        $Preview.CacheOption = 'OnLoad'
        $Preview.EndInit()
    }

    $rows.GUI.Preview.Source = $Preview
})

# Copy
$rows.GUI.CopyRow.Add_Click({
    $Copy = $rows.Config.CopyRowFormat
    $Copy = Expand-ColumnNotation $Copy $rows.GUI.Grid.SelectedItem
    Set-Clipboard $Copy

    Write-Log "Copy row: $Copy"
})

$rows.GUI.CopyImage.Add_Click({
    [Windows.Clipboard]::SetImage($rows.GUI.Preview.Source)

    Write-Log "Copy image: $($rows.GUI.Preview.Source)"
})
