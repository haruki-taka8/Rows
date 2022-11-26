using module .\Csv.psm1

class Rows {
    [Hashtable] $GUI
    [Csv] $Csv
    [PSCustomObject] $Config
    [PSCustomObject] $Style

    Rows () {
        Write-Log 'Create GUI'
        [Xml] $Xaml = Get-Content '.\GUI.xaml'
        $Form = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::New($Xaml))

        # Populate $Hash with elements
        $This.GUI = [Hashtable]::Synchronized(@{})
        $Xaml.SelectNodes('//*[@Name]').Name.ForEach({
            $This.GUI[$_] = $Form.FindName($_)
        })

        # DataContext
        Write-Log 'Bind DataContext'
        $This.Config = $This.GUI.Rows.DataContext =
            Get-Content '.\Configurations\Configuration.json' | ConvertFrom-JSON
    }

    [Void] InitializeGUI () {
        Write-Log 'Import styling'
        if (Test-Path '.\Configurations\Style.json') {
            $This.Style = Get-Content '.\Configurations\Style.json' | ConvertFrom-JSON
        } else {
            Write-Log 'No valid style found, continuing'
        }

        try {
            $This.Csv = [Csv]::New($This.Config.CsvPath, $This.Config.HasHeader)

        } catch {
            Write-Log 'No valid CSV found, starting creation wizard'
            $This.GUI.NewFileScreen.Visibility = 'Visible'
            return
        }

        $This.GUI.NewFileScreen.Visibility = 'Collapsed'

        # Conditional formatting
        Write-Log 'Create datagrid columns'
        $This.Csv.Header.ForEach({
            Write-Log "  - $_"
            $Column = [Windows.Controls.DataGridTextColumn]::New()
            $Column.Binding = [Windows.Data.Binding]::New($_)
            $Column.Header  = $_

            # Multiline
            $EditStyle = [Windows.Style]::New([Windows.Controls.TextBox])
            $EditStyle.Setters.Add([Windows.Setter]::New(
                [Windows.Controls.Primitives.TextBoxBase]::AcceptsReturnProperty,
                $true
            ))
            $EditStyle.Setters.Add([Windows.Setter]::New(
                [Windows.Controls.Primitives.TextBoxBase]::BorderThicknessProperty,
                [Windows.Thickness]::New(0)
            ))
            $Column.EditingElementStyle = $EditStyle

            # Column width
            if ($This.Style.Width.$_ -match '^\d+$') {
                $Column.Width = $This.Style.Width.$_
            }

            # Conditional formatting
            $Column.CellStyle = [Windows.Style]::New()
            foreach ($Item in $This.Style.Color.$_.PSObject.Properties) {
                $Trigger = [Windows.DataTrigger]::New()
                $Trigger.Binding = $Column.Binding
                $Trigger.Value   = $Item.Name
                $Trigger.Setters.Add([Windows.Setter]::New(
                    [Windows.Controls.DataGridCell]::BackgroundProperty,
                    [Windows.Media.BrushConverter]::New().ConvertFrom($Item.Value)
                ))
                $Column.CellStyle.Triggers.Add($Trigger)
            }
            $This.GUI.Grid.Columns.Add($Column)
        })

        # Finalize UI
        $This.DoFilter()
        $This.GUI.Splashscreen.Visibility = 'Collapsed'
        Write-Log 'Okay, it''s happening! Everybody stay calm!'
    }

    [Void] Export () {
        if (!$This.GUI.Commit.IsEnabled) {return}
        if (!$This.GUI.ReadWrite.IsEnabled) {return}

        $This.Csv.Export($This.Config.CsvPath, $This.Config.HasHeader)
        $This.GUI.Rows.Title = 'Rows'
    }

    [Void] UpdateGrid ($UpdateGrid, $UpdateTitle) {
        if ($UpdateGrid) {
            $This.GUI.Grid.CancelEdit()
            $This.GUI.Grid.ItemsSource = $This.Csv.Body
            $This.GUI.Grid.Items.Refresh()
        }

        if ($UpdateTitle) {
            $This.GUI.Rows.Title = '*Rows'
        }

        $This.GUI.Undo.IsEnabled = $This.Csv.UndoStack.Count -and $This.GUI.ReadWrite.IsChecked
        $This.GUI.Redo.IsEnabled = $This.Csv.RedoStack.Count -and $This.GUI.ReadWrite.IsChecked
    }

    [Void] DoFilter () {
        if ($This.GUI.Status.Text -eq 'Filtering') {return}
        $This.GUI.Status.Text      = 'Filtering'
        $This.GUI.Preview.Source   = $null
        $This.GUI.Grid.ItemsSource = $null
        $This.Csv.DoFilter($This.GUI, $This.GUI.Filterbar.Text, $This.Config.InputAlias, $This.Config.OutputAlias, $This.Style.Alias)
        $This.UpdateGrid($false, $false)
    }

    [Void] Insert ($At) {
        $Count = $This.Config.InsertCount
        if ($This.Config.InsertSelectedCount) {$Count = $This.GUI.Grid.SelectedItems.Count}

        $This.Csv.Insert($At, $Count, $This.Config.IsTemplate, $This.Style.Template)
        $This.UpdateGrid($true, $true)
        $This.GUI.Insert.IsChecked = $false
        $This.GUI.Grid.ScrollIntoView($This.GUI.Grid.Items[$At], $This.GUI.Grid.Columns[0])
    }

    [Void] Remove ($Items) {
        $This.Csv.Remove($Items)
        $This.UpdateGrid($true, $true)
    }

    [Void] Undo () {
        $This.Csv.Undo()
        $This.UpdateGrid($true, $true)
    }

    [Void] Redo () {
        $This.Csv.Redo()
        $This.UpdateGrid($true, $true)
    }
}

function New-Rows {[Rows]::New()}
Export-ModuleMember -Function New-Rows