class Csv {
    [Collections.ArrayList] $Body = @()
    [Array] $Header = @()
    [Collections.Generic.Stack[Hashtable]] $UndoStack = @()
    [Collections.Generic.Stack[Hashtable]] $RedoStack = @()

    Csv ($Path, $HasHeader) {
        Write-Log 'Import CSV'
        $Path = Expand-Path $Path

        $Reader = [IO.StreamReader]::New($Path)
        $This.Header = $Reader.Readline().Replace('"','').Split(',')

        if ($HasHeader) {
            $This.Body = @(Import-CSV $Path)
            return
        }

        $This.Header = 1 .. $This.Header.Count
        $This.Body = @(Import-CSV $Path -Header $This.Header)
    }

    [Void] Export ($ExportTo, $HasHeader) {
        Write-Log 'Export CSV'
        $Data = $This.Body | ConvertTo-Csv -NoTypeInformation
        if (!$HasHeader) {$Data = $Data | Select-Object -Skip 1}

        $Data | Out-File (Expand-Path $ExportTo)
    }

    [Void] Insert ($At, $Count, $IsTemplate, $Template) {
        Write-Log "Insert CSV (@$At x$Count, Template: $IsTemplate)"

        # Prepare blank row template, expanding static <[DdTt]> fields first
        $Now = Get-Date
        $Row = [PSCustomObject] @{}
        $This.Header.ForEach({$Row | Add-Member $_ ''})

        if ($IsTemplate) {
            $Template.PSObject.Properties.ForEach({
                $Row.($_.Name) = $_.Value.
                    Replace('<D>', $Now.ToString('yyyyMMdd')).
                    Replace('<d>', $Now.ToString('yyyy-MM-dd')).
                    Replace('<T>', $Now.ToString('HHmmss')).
                    Replace('<t>', $Now.ToString('HH:mm:ss'))
            })
        }

        # Insert rows
        for ($i = 0; $i -lt $Count; $i++) {
            $ThisRow = $Row.PSObject.Copy()
            $ThisRow.PSObject.Properties.Foreach({
                $_.Value = $_.Value.
                    Replace('<#>', $i).
                    Replace('<!#>', ($Count-$i-1))
            })

            $This.Body.Insert($At+$i, $ThisRow)
            $This.UndoStack.Push(@{
                Action = 'Insert'
                At     = $At
                OldRow = $ThisRow
            })
        }
        $This.RedoStack.Clear()
    }

    [Void] Remove ($RemoveList) {
        Write-Log "Remove CSV (x$($RemoveList.Count))"
        $RemoveList.ForEach({
            $This.UndoStack.Push(@{
                Action = 'Remove'
                OldRow = $_
                At     = $This.Body.IndexOf($_)
            })
            $This.Body.Remove($_)
        })
        $This.RedoStack.Clear()
    }

    [Void] Undo () {
        if ($This.UndoStack.Count -eq 0) {return}
        
        Write-Log 'Undo CSV'
        $Last = $This.UndoStack.Pop()
        $This.RedoStack.Push(@{
            Action = $Last.Action
            OldRow = $This.Body[$Last.At]
            At     = $Last.At
        })

        switch ($Last.Action) {
            'Change' {$This.Body[$Last.At] = $Last.OldRow; return}
            'Remove' {$This.Body.Insert($Last.At, $Last.OldRow); return}
            'Insert' {$This.Body.RemoveAt($Last.At)}
        }
    }

    [Void] Redo () {
        if ($This.RedoStack.Count -eq 0) {return}

        Write-Log 'Redo CSV'
        $Last = $This.RedoStack.Pop()
        $This.UndoStack.Push(@{
            Action = $Last.Action
            OldRow = $This.Body[$Last.At]
            At     = $Last.At
        })

        switch ($Last.Action) {
            'Change' {$This.Body[$Last.At] = $Last.OldRow; return}
            'Insert' {$This.Body.Insert($Last.At, $Last.OldRow); return}
            'Remove' {$This.Body.RemoveAt($Last.At)}
        }
    }

    # DoFilter since Filter is reserved
    [Void] DoFilter ($GUI, $FilterText, $InputAlias, $OutputAlias, $Alias) {
        Write-Log "Filter CSV ($FilterText, IOAlias: $InputAlias, $OutputAlias) "
        # Parse $FilterText into [Collections.ArrayList] $Criteria
        # $Criteria = [{Header = 'A'; Value ='B'}, {Header = 'C'; Value = ''},...]
        $Criteria = [Collections.ArrayList] @()
        $FilterText = $FilterText -split ' (?=(?:"[^"]*"|[^"])*$)'

        foreach ($Entry in $FilterText) {
            $Key, $Value = $Entry -split (':(?=(?:"[^"]*"|[^"])*$)', 2)
            $Key = $Key.Trim('"')

            if ($Value) {
                $Value = $Value.Trim('"')

                # Apply input alias
                if ($InputAlias) {
                    foreach ($Item in $Alias.$Key.PSObject.Properties) {
                        # JSON: $Item.Name: $Item.Value
                        $Value = $Value.Replace($Item.Value, $Item.Name)
                    }
                }
            }

            $Criteria.Add([PSCustomObject] @{
                Key   = $Key
                Value = $Value
            })
        }

        # Filter with new Powershell instance
        $Ps = [PowerShell]::Create().AddScript{
            function Invoke-GUI ([Action] $Action) {
                $GUI.Rows.Dispatcher.Invoke($Action, 'ApplicationIdle')
            }

            [Collections.ArrayList] $Filter = @()
            :row foreach ($Row in $This.Body) {
                :rule foreach ($Rule in $Criteria) {
                    if ($Rule.Value) {
                        if ($Row.($Rule.Key) -notmatch $Rule.Value) {continue row}
                        continue rule
                    }
                    if ($Row -join ',' -notmatch $Rule.Key) {continue row}
                }

                # Add entry; apply alias if OutputAlias is on
                if ($OutputAlias) {
                    $AliasedRow = $Row.PSObject.Copy()
                    $AliasedRow.PSObject.Properties.ForEach({
                        foreach ($Item in $Alias.($_.Name).PSObject.Properties) {
                            # JSON: $Item.Name: $Item.Value
                            $_.Value = $_.Value.Replace($Item.Name, $Item.Value)
                        }
                    })
                    $Filter.Add($AliasedRow)
                    continue row
                }
                $Filter.Add($Row)
            }
            # Show full results
            Invoke-GUI {$GUI.Grid.ItemsSource = $Filter}
            Invoke-GUI {$GUI.Status.Text      = 'Ready'}
        }

        # Assign runspace to instance
        $Ps.Runspace = [RunspaceFactory]::CreateRunspace().Open()
        (Get-Variable GUI,This,Criteria,OutputAlias,Alias).ForEach({
            $Ps.Runspace.SessionStateProxy.SetVariable($_.Name, $_.Value)
        })
        $Ps.BeginInvoke()
    }
}