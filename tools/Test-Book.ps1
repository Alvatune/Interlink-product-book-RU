$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'Test-MarkdownChecks.ps1')
. (Join-Path $PSScriptRoot 'Markdown-Checks.ps1')
& (Join-Path $PSScriptRoot 'Build-Book.ps1') -Check
$bookRoot = Split-Path $PSScriptRoot -Parent
$wikiRoot = Join-Path $bookRoot 'wiki'
$pages = @(Get-ChildItem -LiteralPath $wikiRoot -File -Filter '*.md')
$pageNames = @{}
foreach ($page in $pages) { $pageNames[$page.BaseName] = $true }
$wikiLinks = 0
$markdownLinks = 0
$tableRows = 0
$renderedTables = 0

foreach ($folder in @('wiki', 'book')) {
    foreach ($page in (Get-ChildItem -LiteralPath (Join-Path $bookRoot $folder) -File -Filter '*.md')) {
        $content = [System.IO.File]::ReadAllText($page.FullName)
        $structure = Test-PageContent -Name "$folder/$($page.Name)" -Content $content
        $tableRows += $structure.Rows
        $renderedTables += $structure.Tables
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
foreach ($page in (Get-ChildItem -LiteralPath $bookRoot -File -Filter '*.md')) {
    $content = [System.IO.File]::ReadAllText($page.FullName)
    $null = Test-PageContent -Name $page.Name -Content $content
    foreach ($link in [regex]::Matches($content, '\[[^\]\r\n]+\]\(([^\s)]+)\)')) {
        $target = $link.Groups[1].Value
        if ($target -match '^(?:https?://|mailto:|#)') { continue }
        $destination = Join-Path $bookRoot ([uri]::UnescapeDataString($target.Split('#', 2)[0]))
        if (-not (Test-Path -LiteralPath $destination)) { throw "Broken root Markdown link in $($page.Name): $target" }
    }
}
Write-Host "Validated $($pages.Count) wiki pages; wiki links=$wikiLinks; Markdown links=$markdownLinks; table rows=$tableRows; rendered tables=$renderedTables"
