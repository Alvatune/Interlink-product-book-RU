$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'Build-Book.ps1') -Check
$bookRoot = Split-Path $PSScriptRoot -Parent
$wikiRoot = Join-Path $bookRoot 'wiki'
$pages = @(Get-ChildItem -LiteralPath $wikiRoot -File -Filter '*.md')
$pageNames = @{}
foreach ($page in $pages) { $pageNames[$page.BaseName] = $true }
$wikiLinks = 0
$markdownLinks = 0
$tableRows = 0

foreach ($folder in @('wiki', 'book')) {
    foreach ($page in (Get-ChildItem -LiteralPath (Join-Path $bookRoot $folder) -File -Filter '*.md')) {
        $content = [System.IO.File]::ReadAllText($page.FullName)
        if ($content.Contains([char]0xFFFD)) { throw "Invalid text encoding: $($page.Name)" }
        $inFence = $false
        $tableWidth = 0
        foreach ($line in ($content -split '\r?\n')) {
            if ($line -match '^\s*```') { $inFence = -not $inFence; $tableWidth = 0; continue }
            if ($inFence) { continue }
            if ($line -match '^\s*\|') {
                if ($line -match '\[\[[^\]]*\|[^\]]*\]\]') { throw "Wiki alias breaks table: $($page.Name): $line" }
                $width = [regex]::Matches($line, '(?<!\\)\|').Count - 1
                if ($tableWidth -eq 0) { $tableWidth = $width }
                if ($width -ne $tableWidth) { throw "Inconsistent table width: $($page.Name): $line" }
                $tableRows++
            } else { $tableWidth = 0 }
        }
        if ($inFence) { throw "Unclosed code fence: $($page.Name)" }
        foreach ($link in [regex]::Matches($content, '\[\[([^\]\r\n]+)\]\]')) {
            $parts = $link.Groups[1].Value.Split('|', 2)
            $target = $parts[$parts.Length - 1].Split('#', 2)[0]
            if (-not $pageNames.ContainsKey($target)) { throw "Broken wiki link in $($page.Name): $target" }
            $wikiLinks++
        }
        foreach ($link in [regex]::Matches($content, '\[[^\]\r\n]+\]\(([^\s)]+)\)')) {
            $target = $link.Groups[1].Value
            if ($target -match '^(?:https?://|mailto:|#)') { continue }
            $name = [uri]::UnescapeDataString($target.Split('#', 2)[0])
            if (-not $name.EndsWith('.md') -and $folder -eq 'wiki') { $name += '.md' }
            $destination = Join-Path $page.DirectoryName $name
            if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) { throw "Broken Markdown link in $folder/$($page.Name): $target" }
            $markdownLinks++
        }
    }
}
Write-Host "Validated $($pages.Count) wiki pages; wiki links=$wikiLinks; Markdown links=$markdownLinks; table rows=$tableRows"
