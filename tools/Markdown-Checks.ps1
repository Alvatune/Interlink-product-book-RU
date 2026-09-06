function Test-PageContent {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content
    )

    if ($Content.Contains([char]0xFFFD)) { throw "Invalid text encoding: $Name" }
    # This public edition describes its own requirements, not named prototypes.
    if ($Content -match '(?i)\b(?:IPS|ИПС|IMBASE|Aras(?:\s+Innovator)?|Intermech|Интермех)\b') {
        throw "Excluded product reference: $Name"
    }

    $tables = [System.Collections.Generic.List[object]]::new()
    $currentTable = [System.Collections.Generic.List[string]]::new()
    $fenceCharacter = ''
    $fenceLength = 0
    $lineNumber = 0
    foreach ($line in (($Content + "`n") -split '\r?\n')) {
        $lineNumber++
        if ($fenceLength -gt 0) {
            if ($line -match ('^\s*' + [regex]::Escape($fenceCharacter) + '{' + $fenceLength + ',}\s*$')) {
                $fenceLength = 0
            }
            continue
        }
        if ($line -match '^\s*(`{3,}|~{3,})') {
            $fenceCharacter = $Matches[1].Substring(0, 1)
            $fenceLength = $Matches[1].Length
        } elseif ($line -match '^\s*\|') {
            if ($line -notmatch '\|\s*$') { throw "Missing final table separator: ${Name}:$lineNumber" }
            if ($line -match '\[\[') { throw "Wiki syntax inside table: ${Name}:$lineNumber" }
            $currentTable.Add($line)
            continue
        } elseif ($line.Contains('[[') -or $line.Contains(']]')) {
            $withoutLinks = [regex]::Replace($line, '\[\[[^\[\]\r\n]+\]\]', '')
            if ($withoutLinks.Contains('[[') -or $withoutLinks.Contains(']]')) {
                throw "Incomplete or multiline wiki link: ${Name}:$lineNumber"
            }
        }
        if ($currentTable.Count -gt 0) {
            $tables.Add($currentTable.ToArray())
            $currentTable.Clear()
        }
    }
    if ($fenceLength -gt 0) { throw "Unclosed code fence: $Name" }

    $sourceRows = 0
    foreach ($table in $tables) {
        if ($table.Count -lt 2 -or $table[1] -notmatch '^\s*\|(?:\s*:?-{3,}:?\s*\|)+\s*$') {
            throw "Missing table header delimiter: $Name"
        }
        $width = 0
        foreach ($line in $table) {
            # A pipe is escaped only after an odd number of backslashes.
            $rowWidth = [regex]::Matches($line, '(?<!\\)(?:\\\\)*\|').Count - 1
            if ($width -eq 0) { $width = $rowWidth }
            if ($rowWidth -ne $width) { throw "Inconsistent table width: ${Name}: $line" }
            $sourceRows++
        }
    }

    # Source delimiters alone are insufficient: Markdown may render them as prose.
    $html = (ConvertFrom-Markdown -InputObject $Content).Html
    $renderedTables = [regex]::Matches($html, '(?s)<table(?:\s[^>]*)?>.*?</table>')
    if ($renderedTables.Count -ne $tables.Count) { throw "Rendered table count differs: $Name" }
    for ($index = 0; $index -lt $tables.Count; $index++) {
        $source = $tables[$index]
        $expectedWidth = [regex]::Matches($source[0], '(?<!\\)(?:\\\\)*\|').Count - 1
        $renderedRows = [regex]::Matches($renderedTables[$index].Value, '(?s)<tr(?:\s[^>]*)?>.*?</tr>')
        if ($renderedRows.Count -ne $source.Count - 1) { throw "Rendered table rows differ: $Name" }
        foreach ($row in $renderedRows) {
            $cells = [regex]::Matches($row.Value, '(?s)<t[hd](?:\s[^>]*)?>.*?</t[hd]>')
            if ($cells.Count -ne $expectedWidth) { throw "Rendered table cells differ: $Name" }
        }
    }

    return [pscustomobject]@{ Tables = $tables.Count; Rows = $sourceRows }
}
