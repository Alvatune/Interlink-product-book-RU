$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Markdown-Checks.ps1')

$cases = @(
    @{ Name = 'plain table'; Valid = $true; Content = "| Name | Meaning |`n|---|---|`n| Value | Meaning |" }
    @{ Name = 'Markdown table link'; Valid = $true; Content = "| Page | Meaning |`n|---|---|`n| [Table](Tabular-data) | Data |" }
    @{ Name = 'escaped pipe'; Valid = $true; Content = "| Value | Meaning |`n|---|---|`n| A\|B | Alternatives |" }
    @{ Name = 'empty body'; Valid = $true; Content = "| Name | Meaning |`n|---|---|" }
    @{ Name = 'wiki link outside table'; Valid = $true; Content = '[[Tables|Tabular-data]]' }
    @{ Name = 'code is not a table'; Valid = $true; Content = '```text' + "`n| raw |`n" + '```' }
    @{ Name = 'longer fence'; Valid = $true; Content = '````text' + "`n" + '```' + "`n| raw |`n" + '````' }
    @{ Name = 'wiki alias inside table'; Valid = $false; Content = "| Page |`n|---|`n| [[Label|Page]] |" }
    @{ Name = 'wiki link inside table'; Valid = $false; Content = "| Page |`n|---|`n| [[Page]] |" }
    @{ Name = 'missing header delimiter'; Valid = $false; Content = "| Name | Meaning |`n| Value | Meaning |" }
    @{ Name = 'extra cell'; Valid = $false; Content = "| Name | Meaning |`n|---|---|`n| A | B | C |" }
    @{ Name = 'missing final pipe'; Valid = $false; Content = "| Name | Meaning |`n|---|---|`n| A | B" }
    @{ Name = 'multiline wiki link'; Valid = $false; Content = "[[Label`nPage]]" }
    @{ Name = 'unclosed fence'; Valid = $false; Content = '```mermaid' + "`nflowchart TD" }
    @{ Name = 'excluded reference'; Valid = $false; Content = 'Based on Aras Innovator' }
    @{ Name = 'excluded reference case'; Valid = $false; Content = 'imbase' }
    @{ Name = 'replacement character'; Valid = $false; Content = 'Broken ' + [char]0xFFFD }
)
foreach ($case in $cases) {
    $valid = $true
    try { $null = Test-PageContent -Name $case.Name -Content $case.Content }
    catch { $valid = $false }
    if ($valid -ne $case.Valid) { throw "Unexpected validation result: $($case.Name)" }
}
Write-Host "Markdown validation regression cases: $($cases.Count) passed"
