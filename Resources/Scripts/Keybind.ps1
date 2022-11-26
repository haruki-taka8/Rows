$rows.GUI.Rows.Add_KeyUp({
    # Control
    if ($_.KeyboardDevice.Modifiers -eq 'Control') {
        switch ($_.Key) {
            's' {$rows.Export()}

            'z' {if ($rows.GUI.Status.Text -eq 'Editing') {$rows.Undo()}}
            'y' {if ($rows.GUI.Status.Text -eq 'Editing') {$rows.Redo()}}

            'f' {$rows.GUI.Filterbar.Focus()}
        }
        return
    }

    # Alt
    if ($_.KeyboardDevice.Modifiers -eq 'Alt') {
        if ($rows.GUI.Preview.Visibility -eq 'Visible') {
            $rows.GUI.Preview.Visibility = 'Hidden'
        } else {
            $rows.GUI.Preview.Visibility = 'Visible'
        }
        return
    }
})