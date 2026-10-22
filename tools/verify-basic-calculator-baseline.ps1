$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $repoRoot 'opencalc\entry\src\main\ets'

$checks = @(
    @{
        Name = 'CalculatorPage has no scientific-mode UI or state'
        Path = Join-Path $sourceRoot 'pages\CalculatorPage.ets'
        Forbidden = '@State scientific|radianMode|BtnFunc|BtnConst|getFuncBg|科学|弧度模式|''sin''|''cos''|''tan''|''ln''|''log''|''arcsi''|''arcco''|''arcta''|''π'''
    },
    @{
        Name = 'Calculator engine only contains basic arithmetic'
        Path = Join-Path $sourceRoot 'calculator\Calculator.ets'
        Forbidden = 'Math\.(sin|cos|tan|asin|acos|atan|sqrt|log|log2|log10|pow)|fn ===|factorial|powx|private fact|private gl|this\.deg|取模'
    },
    @{
        Name = 'Expression preprocessor has no advanced operators'
        Path = Join-Path $sourceRoot 'calculator\Expression.ets'
        Forbidden = '√|%|factorial|functionsList|arcsi|arcco|arcta|logtwo|logten|''xp'''
    },
    @{
        Name = 'Models have no scientific-mode preference'
        Path = Join-Path $sourceRoot 'model\Models.ets'
        Forbidden = 'ScientificMode|scientificMode|radiansDefault'
    },
    @{
        Name = 'Preferences have no scientific-mode settings'
        Path = Join-Path $sourceRoot 'preferences\PreferencesStore.ets'
        Forbidden = 'ScientificMode|scientificMode|RadiansDefault|radiansDefault'
    }
)

$failures = @()
foreach ($check in $checks) {
    $content = Get-Content -Raw -LiteralPath $check.Path
    if ($content -match $check.Forbidden) {
        $failures += $check.Name
    }
}

$page = Get-Content -Raw -LiteralPath (Join-Path $sourceRoot 'pages\CalculatorPage.ets')
$requiredRows = @(
    "Row() { this.BtnAct('AC'); this.BtnOp('('); this.BtnOp(')'); this.BtnOp('÷') }",
    "Row() { this.BtnDig('7'); this.BtnDig('8'); this.BtnDig('9'); this.BtnOp('×') }",
    "Row() { this.BtnDig('4'); this.BtnDig('5'); this.BtnDig('6'); this.BtnOp('-') }",
    "Row() { this.BtnDig('1'); this.BtnDig('2'); this.BtnDig('3'); this.BtnOp('+') }",
    "Row() { this.BtnDig('0'); this.BtnOp('.'); this.BtnAct('⌫'); this.BtnEq() }"
)
foreach ($row in $requiredRows) {
    if (-not $page.Contains($row)) {
        $failures += "Missing basic keypad row: $row"
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'PASS: baseline contains only the basic four-operation calculator surface and engine.'
