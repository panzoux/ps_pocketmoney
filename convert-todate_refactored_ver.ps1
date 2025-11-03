function Convert-ToDate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputDate
    )

    $now = Get-Date
    $currentYear  = $now.Year
    $currentMonth = $now.Month
    $inputStr     = $InputDate.ToString()
    $len          = $inputStr.Length

    function Try-ParseDate($y, $m, $d) {
        #try { Get-Date -Year $y -Month $m -Day $d -ErrorAction Stop }
        try {
            $date = Get-Date -Year $y -Month $m -Day $d
            if ($date.Year -ne $y -or $date.Month -ne $m -or $date.Day -ne $d) {
                return $null
            }
            return $date
        }
        catch { $null }
    }

    $rawCandidates = @()

    switch ($len) {
        { $_ -in 1..2 } {
            # 日
            $rawCandidates += ,@($currentYear, $currentMonth, [int]$inputStr)

            # 2桁は MMDD 的にも解釈
            if ($len -eq 2) {
                $month = [int]$inputStr.Substring(0,1)
                $day   = [int]$inputStr.Substring(1,1)
                $rawCandidates += ,@($currentYear, $month, $day)
            }
        }
        3 {
            # MDD
            $month = [int]$inputStr.Substring(0,1)
            $day   = [int]$inputStr.Substring(1,2)
            $rawCandidates += ,@($currentYear, $month, $day)
        }
        4 {
            $mm = [int]$inputStr.Substring(0,2)
            if ($mm -ge 1 -and $mm -le 12) {
                # MMDD
                $month = $mm
                $day   = [int]$inputStr.Substring(2,2)
                $rawCandidates += ,@($currentYear, $month, $day)
            } else {
                # YYMD
                $year  = 2000 + [int]$inputStr.Substring(0,2)
                $month = [int]$inputStr.Substring(2,1)
                $day   = [int]$inputStr.Substring(3,1)
                $rawCandidates += ,@($year, $month, $day)
            }
        }
        5 {
            # YYMDD
            $year  = 2000 + [int]$inputStr.Substring(0,2)
            $month = [int]$inputStr.Substring(2,1)
            $day   = [int]$inputStr.Substring(3,2)
            $rawCandidates += ,@($year, $month, $day)

            # YYMMd
            $month = [int]$inputStr.Substring(2,2)
            $day   = [int]$inputStr.Substring(4,1)
            $rawCandidates += ,@($year, $month, $day)
        }
        6 {
            # YYMMDD
            $year  = 2000 + [int]$inputStr.Substring(0,2)
            $month = [int]$inputStr.Substring(2,2)
            $day   = [int]$inputStr.Substring(4,2)
            $rawCandidates += ,@($year, $month, $day)
        }
        8 {
            # YYYYMMDD
            $year  = [int]$inputStr.Substring(0,4)
            $month = [int]$inputStr.Substring(4,2)
            $day   = [int]$inputStr.Substring(6,2)
            $rawCandidates += ,@($year, $month, $day)
        }
        default {
            throw "Unsupported date format: $InputDate"
        }
    }

    # ここでまとめて検証
    $candidates = $rawCandidates | ForEach-Object {
        Try-ParseDate $_[0] $_[1] $_[2]
    #} | Where-Object { $_ } | Select-Object -Unique
    } | Select-Object -Unique

    switch ($candidates.Count) {
        0 { throw "Invalid date: $InputDate" }
        1 { return $candidates[0] }
        default { throw "Multiple candidate dates for input: $InputDate" }
    }
}


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
convert-todate 24123    # 2024年12月3日 2024.1.23

Convert-ToDate 230230   # 存在しない日 → エラー

<#
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
#>