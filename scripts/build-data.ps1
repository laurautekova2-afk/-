# Собирает portal/data.js из CSV-файлов папки data/.
# Запуск:  powershell -ExecutionPolicy Bypass -File scripts\build-data.ps1
# CSV — единственный источник данных; data.js не редактировать вручную.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dataDir = Join-Path $root 'data'
$inv = [Globalization.CultureInfo]::InvariantCulture

function ConvertTo-Num($v) {
    if ($null -eq $v -or "$v".Trim() -eq '') { return $null }
    return [double]::Parse("$v".Trim(), $inv)
}

function Read-Csv($name) {
    $path = Join-Path $dataDir $name
    return Get-Content -Path $path -Encoding UTF8 | ConvertFrom-Csv
}

$companies = Read-Csv 'companies.csv'
$results   = Read-Csv 'results_9m.csv'
$solvency  = Read-Csv 'solvency.csv'
$ratings   = Read-Csv 'ratings.csv'

$nmpDates  = @('2026-01-01','2026-04-01','2026-07-01','2026-10-01','2026-11-01')
$ndvaDates = @('2026-10-01','2026-11-01')

$out = @()
foreach ($c in $companies) {
    $r = $results  | Where-Object { $_.id -eq $c.id }
    $s = $solvency | Where-Object { $_.id -eq $c.id }
    $g = $ratings  | Where-Object { $_.id -eq $c.id }
    if (-not $r -or -not $s -or -not $g) { throw "Нет полных данных для компании '$($c.id)'" }

    $nmp = [ordered]@{}
    foreach ($d in $nmpDates)  { $nmp[$d]  = ConvertTo-Num $s."nmp_$d" }
    $ndva = [ordered]@{}
    foreach ($d in $ndvaDates) { $ndva[$d] = ConvertTo-Num $s."ndva_$d" }

    $out += [ordered]@{
        id = $c.id; name = $c.name; note = $c.note
        assets0101 = ConvertTo-Num $c.assets_0101; assets1001 = ConvertTo-Num $c.assets_1001
        capital0101 = ConvertTo-Num $c.capital_0101; capital1001 = ConvertTo-Num $c.capital_1001
        reserves1001 = ConvertTo-Num $c.reserves_1001; reservesDeltaPct = ConvertTo-Num $c.reserves_delta_pct
        premiums = ConvertTo-Num $r.premiums_9m26; premiumsDeltaPct = ConvertTo-Num $r.premiums_delta_pct
        claims = ConvertTo-Num $r.claims_9m26; claimsRatioPct = ConvertTo-Num $r.claims_ratio_pct
        cededSharePct = ConvertTo-Num $r.ceded_share_pct
        profit = ConvertTo-Num $r.profit_9m26; profitPrev = ConvertTo-Num $r.profit_9m25
        nmp = $nmp; ndva = $ndva
        rating = $g.rating; ratingStatus = $g.rating_status
        riskReported = $g.risk_reported; riskBasis = $g.basis
    }
}

$payload = [ordered]@{
    meta = [ordered]@{
        title = 'Отчет по перестрахованию: КСЖ Республики Казахстан'
        period = '01.01.2026 – 01.10.2026 (9 месяцев)'
        prudentialAsOf = '01.11.2026'
        preparedAt = '27.11.2026'
        units = 'млрд тенге, регуляторные показатели (не МСФО)'
        nmpDates = $nmpDates; ndvaDates = $ndvaDates
        builtAt = (Get-Date -Format 'yyyy-MM-dd HH:mm')
    }
    companies = $out
}

$json = $payload | ConvertTo-Json -Depth 6
$js = "// Сгенерировано scripts/build-data.ps1 — не редактировать вручную.`nwindow.KSJ_DATA = $json;`n"
$target = Join-Path $root 'portal\data.js'
[IO.File]::WriteAllText($target, $js, (New-Object Text.UTF8Encoding($false)))
Write-Host "Готово: $target ($($out.Count) компаний)"
