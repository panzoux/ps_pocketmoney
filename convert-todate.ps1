function Convert-ToDate {
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputDate
    )

    $now = Get-Date
    $currentYear = $now.Year
    $currentMonth = $now.Month
    $inputStr = $InputDate.ToString()
    $len = $inputStr.Length

    function Validate-Date($year, $month, $day) {
        try {
            $date = Get-Date -Year $year -Month $month -Day $day
            if ($date.Year -ne $year -or $date.Month -ne $month -or $date.Day -ne $day) {
                return $null
            }
            return $date
        } catch {
            return $null
        }
    }

    $candidates = @()

    switch ($len) {
        {$_ -in (1..2)} {
            $day = [int]$inputStr
            $month = $currentMonth
            $date = Validate-Date $currentYear $month $day
            if ($date) { $candidates += $date }
            # 2桁で再解釈
            if ($len -eq 2 -and $day -gt 12) {
                $month = [int]$inputStr.Substring(0,1)
                $day = [int]$inputStr.Substring(1,1)
                $date = Validate-Date $currentYear $month $day
                if ($date) { $candidates += $date }
            }
        }
        3 {
            $month = [int]$inputStr.Substring(0,1)
            $day = [int]$inputStr.Substring(1,2)
            $date = Validate-Date $currentYear $month $day
            if ($date) { $candidates += $date }
        }
        4 {
            $monthCandidate = [int]$inputStr.Substring(0,2)
            if ($monthCandidate -ge 1 -and $monthCandidate -le 12) {
                $month = $monthCandidate
                $day = [int]$inputStr.Substring(2,2)
                $date = Validate-Date $currentYear $month $day
                if ($date) { $candidates += $date } 
            } else {
                # 先頭2桁がMMとして解釈できない場合、YYMD 形式を候補として追加
                $year = 2000 + [int]$inputStr.Substring(0,2)
                $month = [int]$inputStr.Substring(2,1)
                $day = [int]$inputStr.Substring(3,1)
                $date = Validate-Date $year $month $day
                if ($date) { $candidates += $date }
            }
        }
        5 {
            # YYMDD
            $year = 2000 + [int]$inputStr.Substring(0,2)
            $month = [int]$inputStr.Substring(2,1)
            $day = [int]$inputStr.Substring(3,2)
            $date = Validate-Date $year $month $day
            if ($date) { $candidates += $date }
            # YYMMDD 形式も候補として追加
            $year = 2000 + [int]$inputStr.Substring(0,2)
            $month = [int]$inputStr.Substring(2,2)
            $day = [int]$inputStr.Substring(4,1)
            $date = Validate-Date $year $month $day
            if ($date) { $candidates += $date }
        }
        6 {
            $year = 2000 + [int]$inputStr.Substring(0,2)
            $month = [int]$inputStr.Substring(2,2)
            $day = [int]$inputStr.Substring(4,2)
            $date = Validate-Date $year $month $day
            if ($date) { $candidates += $date }
        }
        8 {
            $year = [int]$inputStr.Substring(0,4)
            $month = [int]$inputStr.Substring(4,2)
            $day = [int]$inputStr.Substring(6,2)
            $date = Validate-Date $year $month $day
            if ($date) { $candidates += $date }
        }
        default {
            throw "Unsupported date format: $InputDate"
        }
    }

    # 結果判定
    $candidates = $candidates | Select-Object -Unique
    if ($candidates.Count -eq 0) {
        throw "Invalid date: $InputDate"
    } elseif ($candidates.Count -gt 1) {
        throw "Multiple candidate dates for input: $InputDate"
    } else {
        return $candidates[0]
    }
}

if ($MyInvocation.InvocationName -eq 'Convert-ToDate') {
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputDate
    )
    try {
        $resultDate = Convert-ToDate -InputDate $InputDate
        Write-Output $resultDate.ToString("yyyy/MM/dd")
    } catch {
        Write-Error $_.Exception.Message
        exit 1
    }
}
elseif ($MyInvocation.PSCommandPath -eq $PSCommandPath) {
    param(
        [switch]$Benchmark
    )

    Write-Host "This script defines the Convert-ToDate function. To use it, call Convert-ToDate with a date string parameter."

    if ($Benchmark) {
        # Benchmark mode
        Measure-Command{
            1..1000|ForEach-Object{
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
        exit 0
    } else {
        # Test cases
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
        convert-todate 24123    # 2024年12月3日 2024.1.23

        Convert-ToDate 230230   # 存在しない日 → エラー

        exit 1
    }
}
