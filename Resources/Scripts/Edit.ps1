# Prevent Undo and Commit if ReadWrite is off
$rows.GUI.ReadWrite.Add_Click({$rows.UpdateGrid($false, $false)})

# Enter edit mode
$rows.GUI.Grid.Add_BeginningEdit({$rows.GUI.Status.Text = 'Editing'})

# Commit changes
$rows.GUI.Grid.Add_CellEditEnding({
    # Bail out if cell is unchanged
    if (
        $Args[1].EditingElement.Text -eq
        $Args[1].Row.Item.($Args[1].Column.Header)
    ) {
        return
    }

    $rows.Csv.UndoStack.Push(@{
        Action = 'Change'
        OldRow = $Args[1].Row.Item.PSObject.Copy()
        At     = $rows.Csv.Body.IndexOf($Args[1].Row.Item)
    })
    
    $rows.Csv.RedoStack.Clear()
    $rows.UpdateGrid($false, $true)
})

# Cell-level commitment
$rows.GUI.Grid.Add_CurrentCellChanged({
    $rows.GUI.Grid.CommitEdit()
})

# Each function below corresponds to a button in the GUI
$rows.GUI.Undo.Add_Click({$Rows.Undo()})
$rows.GUI.Redo.Add_Click({$Rows.Redo()})

$rows.GUI.InsertTop.Add_Click({$rows.Insert(0)})

$rows.GUI.InsertLast.Add_Click({$rows.Insert($rows.Csv.Body.Count)})

$rows.GUI.InsertAbove.Add_Click({
    $At = $rows.Csv.Body.IndexOf($rows.GUI.Grid.SelectedItem)
    $rows.Insert($At)
})

$rows.GUI.InsertBelow.Add_Click({
    $At = $rows.Csv.Body.IndexOf($rows.GUI.Grid.SelectedItem)
    $Offset = $rows.GUI.Grid.SelectedItems.Count
    $rows.Insert($At + $Offset)
})

$rows.GUI.Remove.Add_Click({$rows.Remove($rows.GUI.Grid.SelectedItems)})

$rows.GUI.Commit.Add_Click({$rows.Export()})
