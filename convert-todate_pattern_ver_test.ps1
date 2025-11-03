function Convert-ToDate {
    param(
        [Parameter(Mandatory = $true)][string]$InputDate,
        [switch]$ShowDebug,
        [switch]$ReturnAllCandidates
    )

    $s = $InputDate.ToString().Trim()
    if ($s -eq '') { throw "Unsupported date format: $InputDate" }
    if ($s -notmatch '^\d+$') { throw "Unsupported date format: $InputDate" }

    $now = Get-Date
    $currentYear  = $now.Year
    $currentMonth = $now.Month

    function TryCreateDate([int]$y, [int]$m, [int]$d) {
        try { return [datetime]::new($y, $m, $d) }
        catch { return $null }
    }

    $patterns = @(
        @{ Name='D';        Len=1; Parts=@(@{K='D'; S=0; L=1}); Priority=1 },
        @{ Name='DD';       Len=2; Parts=@(@{K='D'; S=0; L=2}); Priority=1 },
        @{ Name='MD';       Len=2; Parts=@(@{K='M'; S=0; L=1}, @{K='D'; S=1; L=1}); Priority=1 },
        @{ Name='MDD';      Len=3; Parts=@(@{K='M'; S=0; L=1}, @{K='D'; S=1; L=2}); Priority=1 },
        @{ Name='MMDD';     Len=4; Parts=@(@{K='M'; S=0; L=2}, @{K='D'; S=2; L=2}); Priority=1 },
        @{ Name='YYMD';     Len=4; Parts=@(@{K='Y2'; S=0; L=2}, @{K='M'; S=2; L=1}, @{K='D'; S=3; L=1}); Priority=2 },
        @{ Name='YYMDD';    Len=5; Parts=@(@{K='Y2'; S=0; L=2}, @{K='M'; S=2; L=1}, @{K='D'; S=3; L=2}); Priority=1 },
        @{ Name='YYMMD';    Len=5; Parts=@(@{K='Y2'; S=0; L=2}, @{K='M'; S=2; L=2}, @{K='D'; S=4; L=1}); Priority=1 },
        @{ Name='YYMMDD';   Len=6; Parts=@(@{K='Y2'; S=0; L=2}, @{K='M'; S=2; L=2}, @{K='D'; S=4; L=2}); Priority=1 },
        @{ Name='YYYYMMDD'; Len=8; Parts=@(@{K='Y4'; S=0; L=4}, @{K='M'; S=4; L=2}, @{K='D'; S=6; L=2}); Priority=1 }
    )

    $rawCandidates = @()
    foreach ($pat in $patterns) {
        if ($s.Length -ne $pat.Len) { continue }

        $y = $null; $m = $null; $d = $null
        foreach ($p in $pat.Parts) {
            $substr = $s.Substring($p.S, $p.L)
            $val = [int]$substr
            switch ($p.K) {
                'Y2' { $y = 2000 + $val }
                'Y4' { $y = $val }
                'M'  { $m = $val }
                'D'  { $d = $val }
            }
        }
        if (-not $y) { $y = $currentYear }
        if (-not $m) { $m = $currentMonth }

        $rawCandidates += [PSCustomObject]@{
            Year=$y; Month=$m; Day=$d; Pattern=$pat.Name; Priority=$pat.Priority
        }
    }

    if ($rawCandidates.Count -eq 0) { throw "Unsupported date format: $InputDate" }

    $valids = @()
    foreach ($c in $rawCandidates) {
        $dt = TryCreateDate $c.Year $c.Month $c.Day
        if ($dt) { $valids += [PSCustomObject]@{ Date=$dt.Date; Pattern=$c.Pattern; Priority=$c.Priority } }
    }

    if ($valids.Count -eq 0) { throw "Invalid date: $InputDate" }

    $minPri = ($valids | Measure-Object Priority -Minimum).Minimum
    $filtered = $valids | Where-Object { $_.Priority -eq $minPri }

    $unique = @($filtered | Group-Object Date | ForEach-Object { $_.Group[0] })

    # ===== 常に配列で返す =====
    if ($unique.Count -eq 1) {
        return @($unique[0].Date)  # 単一でも配列
    } elseif ($unique.Count -gt 1) {
        if ($ReturnAllCandidates) {
            return $unique | ForEach-Object { $_.Date }
        } else {
            $list = ($unique | ForEach-Object { $_.Date.ToString('yyyy-MM-dd') + "(pattern=" + $_.Pattern + ")" }) -join ", "
            throw "Multiple candidate dates for input: $InputDate -> [$list]"
        }
    }
}

<#
# ==== テストスイート ====
$tests = @(
    '7','45','91','105','1225',
    '240105','20240105','24927','2492','2412','24130','24123','230230'
)

Write-Host "Running tests..."
foreach ($t in $tests) {
    try {
        $resArray = Convert-ToDate -InputDate $t
        if ($resArray -is [array]) {
            Write-Host ("{0,-8} => [ {1} ]" -f $t, ($resArray | ForEach-Object { $_.ToString('yyyy-MM-dd') } -join ', '))
        } else {
            Write-Host ("{0,-8} => {1}" -f $t, $resArray.ToString('yyyy-MM-dd'))
        }
    } catch {
        Write-Host ("{0,-8} => ERROR: {1}" -f $t, $_.Exception.Message)
    }
}

<#
# 曖昧候補を返す動作確認
Write-Host "`nTest ReturnAllCandidates with 24123:"
$all = Convert-ToDate 24123 -ReturnAllCandidates
foreach ($d in $all) { Write-Host $d.ToString('yyyy-MM-dd') }
#>

Measure-Command{
1..1000|%{
Convert-ToDate 7        # 当月7日
Convert-ToDate 45       # 4月5日
Convert-ToDate 91       # 9月1日
Convert-ToDate 105      # 1月5日
Convert-ToDate 1225     # 12月25日
Convert-ToDate 240105   # 2024年1月5日
Convert-ToDate 20240105 # 2024年1月5日
convert-todate 24927    # 2024年9月27日
convert-todate 2492     # 2024年9月2日
convert-todate 2412     # 2024年1月2日
convert-todate 24130    # 2024年1月30日
convert-todate 2498     # 2024年9月8日
convert-todate 24098    # 2024年9月8日
}
}
