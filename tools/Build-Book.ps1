param([switch]$Check)

$ErrorActionPreference = 'Stop'
$bookRoot = Split-Path $PSScriptRoot -Parent
$wikiRoot = Join-Path $bookRoot 'wiki'
$renderedRoot = Join-Path $bookRoot 'book'
$pages = @(Get-ChildItem -LiteralPath $wikiRoot -File -Filter '*.md')
$pageNames = @{}
foreach ($page in $pages) { $pageNames[$page.BaseName] = $true }
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Convert-PageTarget([string]$Target) {
    $parts = $Target.Split('#', 2)
    $name = [uri]::UnescapeDataString($parts[0])
    if ($name.EndsWith('.md')) { $name = $name.Substring(0, $name.Length - 3) }
    if (-not $pageNames.ContainsKey($name)) { throw "Unknown wiki page: $Target" }
    $result = $name + '.md'
    if ($parts.Length -eq 2) { $result += '#' + $parts[1] }
    return $result
}

if (-not $Check) { [void][System.IO.Directory]::CreateDirectory($renderedRoot) }
foreach ($page in $pages) {
    $content = [System.IO.File]::ReadAllText($page.FullName).Replace("`r`n", "`n")
    $content = [regex]::Replace($content, '\[\[([^\]\r\n]+)\]\]', {
        param($match)
        $parts = $match.Groups[1].Value.Split('|', 2)
        $label = $parts[0]
        $target = if ($parts.Length -eq 2) { $parts[1] } else { $parts[0] }
        return '[' + $label + '](' + (Convert-PageTarget $target) + ')'
    })
    $content = [regex]::Replace($content, '(\[[^\]\r\n]+\]\()([^\s)]+)(\))', {
        param($match)
        $target = $match.Groups[2].Value
        $wikiPrefix = 'https://github.com/Alvatune/Interlink-product-book-RU/wiki/'
        if ($target.StartsWith($wikiPrefix)) {
            $target = Convert-PageTarget $target.Substring($wikiPrefix.Length)
        } elseif ($target -notmatch '^(?:[a-z]+:|#|/|\.\./)') {
            $candidate = [uri]::UnescapeDataString($target.Split('#', 2)[0]) -replace '\.md$', ''
            if ($pageNames.ContainsKey($candidate)) { $target = Convert-PageTarget $target }
        }
        return $match.Groups[1].Value + $target + $match.Groups[3].Value
    })
    $content = "<!-- Generated from wiki/$($page.Name). Edit the source, then run tools/Build-Book.ps1. -->`n`n" + $content.TrimEnd() + "`n"
    $destination = Join-Path $renderedRoot $page.Name
    if ($Check) {
        if (-not (Test-Path -LiteralPath $destination)) { throw "Missing generated page: $destination" }
        if ([System.IO.File]::ReadAllText($destination).Replace("`r`n", "`n") -cne $content) {
            throw "Stale generated page: $destination"
        }
    } else {
        [System.IO.File]::WriteAllText($destination, $content, $utf8)
    }
}
if ($Check) {
    foreach ($extra in (Get-ChildItem -LiteralPath $renderedRoot -File -Filter '*.md')) {
        if (-not $pageNames.ContainsKey($extra.BaseName)) { throw "Unexpected generated page: $($extra.Name)" }
    }
}
Write-Host "Book pages: $($pages.Count); check=$Check"
