# --------------------------------------------
# 小遣い帳 PowerShell スクリプト（項目対応）
# CSV形式: 日付,連番,金額,項目
# ファイル名: kodukai.csv（スクリプト同フォルダ）
# 日付変換は外部 convert-todate.ps1 の Convert-ToDate を使用
# --------------------------------------------

$csvFile = "$PSScriptRoot\kodukai.csv"
$data = New-Object System.Collections.ArrayList

# 外部 Convert-ToDate 読み込み
. "$PSScriptRoot\convert-todate.ps1"

# CSV 読み込み
if (Test-Path $csvFile) {
    $imported = Import-Csv $csvFile -Encoding UTF8
    if ($imported -isnot [System.Array]) { $imported = @($imported) }
    $null = $data.AddRange($imported)
    "読み込みました ({0}件)" -f $data.Count
}

# 項目リスト
$items = @(
    "食費","カフェ","外食","日用雑貨","交通","交際費","娯楽","美容・衣服",
    "医療・保険","水道・光熱・通信","住まい","教育・教養","その他","手入力"
)

# 直前入力管理
$lastDate = $null
$lastSeq = $null
$unsaved = $false

function ReNumber {
    param([string]$targetDate)
    $itemsByDate = $data | Where-Object {$_.日付 -eq $targetDate} | Sort-Object {[int]$_.連番}
    $counter = 1
    foreach ($item in $itemsByDate) { $item.連番 = $counter; $counter++ }
}

function Show-List {
    $data | Sort-Object {[datetime]$_.日付}, {[int]$_.連番} | Format-Table 日付,連番,金額,項目
}

function Show-Balance {
    $total = ($data | Measure-Object -Property 金額 -Sum).Sum
    Write-Host "残高: $total"
}

function Show-MonthTotal {
    $monthGroups = $data | Group-Object {([datetime]$_.日付).ToString("yyyy-MM")}
    foreach ($g in $monthGroups) {
        $sum = ($g.Group | Measure-Object -Property 金額 -Sum).Sum
        Write-Host "$($g.Name): 合計 $sum"
    }
}

function Show-Help {
    Write-Host @"
小遣い帳コマンド一覧:
日付 金額         : 入力例 '7 500' または '0105,500'
d -日付-連番       : 指定データ削除確認
d -               : 直前データ削除確認
u .日付-連番       : 指定データ更新
u .                : 直前データ更新
l *               : 一覧表示
r =               : 残高表示
s 0               : 月毎合計表示
w +               : 追記保存
q                 : 保存確認後終了
h ?               : ヘルプ
区切り文字: 空白, , .
項目選択後「手入力」を選択した場合は次に項目手入力
"@
}

function Save-Data {
    param([switch]$force)
    if ($script:unsaved -or $force) {
        $data | Sort-Object {[datetime]$_.日付}, {[int]$_.連番} | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
        $script:unsaved = $false
        Write-Host "保存しました"
    }
}

# メインループ
$running = $true
while ($running) {
    if ($unsaved -eq $true){$prompt = "入力(未保存あり)>"} else {$prompt = "入力>"}
    $input = Read-Host $prompt
    if ([string]::IsNullOrWhiteSpace($input)) { continue }
    $parts = $input -split '[ ,.]'

    switch ($parts[0]) {
        {$_ -in 'h','?'} { Show-Help; continue }
        {$_ -in 'l','*'} { Show-List; continue }
        {$_ -in 'r','='} { Show-Balance; continue }
        {$_ -in 's','0'} { Show-MonthTotal; continue }
        {$_ -in 'w','+'} { Save-Data; continue }
        {$_ -eq 'q'} { 
            if ($unsaved) {
                $yn = Read-Host "保存しますか？(1:yes 0:cancel)"
                if ($yn -eq '1') { Save-Data -force }
            }
            $running = $false
            continue 
        }
        {$_ -in 'd','-'} {
            if ($parts.Length -eq 3) {
                try {
                    $targetDateObj = Convert-ToDate $parts[1]
                    $targetDate = $targetDateObj.ToString("yyyy/MM/dd")
                } catch { Write-Host "日付形式エラー"; continue }
                $targetSeq = $parts[2]
            } else {
                $targetDate = $lastDate
                $targetSeq = $lastSeq
            }
            $del = $data | Where-Object {$_.日付 -eq $targetDate -and $_.連番 -eq $targetSeq}
            if ($del) {
                write-host $del
                $yn = Read-Host "削除しますか？(1:yes 0:cancel)"
                if ($yn -eq '1') {
                    foreach ($d in $del) { $data.Remove($d) | Out-Null }
                    ReNumber $targetDate
                    Write-Host "削除しました"
                    $unsaved = $true
                }
            }
            continue
        }
        {$_ -in 'u','.'} {
            if ($parts.Length -eq 3) {
                try {
                    $targetDateObj = Convert-ToDate $parts[1]
                    $targetDate = $targetDateObj.ToString("yyyy/MM/dd")
                } catch { Write-Host "日付形式エラー"; continue }
                $targetSeq = $parts[2]
            } else {
                $targetDate = $lastDate
                $targetSeq = $lastSeq
            }
            $upd = $data | Where-Object {$_.日付 -eq $targetDate -and $_.連番 -eq $targetSeq}
            if ($upd) {
                $upd
                $newAmount = Read-Host "[${targetDate}.${targetSeq}] 金額入力"
                $upd[0].金額 = $newAmount
                ReNumber $targetDate
                Write-Host "更新しました"
                $unsaved = $true
            }
            continue
        }
        default {
            # 通常入力: 日付 金額
            try {
                $dateObj = Convert-ToDate $parts[0]
            } catch { Write-Host "日付形式エラー"; continue }

            $amount = $parts[1]
            if (($amount -eq $null) -or ($amount -eq "")){
                Write-Host "金額が空です。"
                continue
            }

            $dateStr = $dateObj.ToString("yyyy/MM/dd")
            $seq = @($data | Where-Object {$_.日付 -eq $dateStr}).Count + 1

            # 項目表示
            Write-Host "[$dateStr.$seq $amount]項目一覧:"
            for ($i=0; $i -lt $items.Count; $i++) {
                Write-Host "$($i+1):$($items[$i])"
            }
            $itemChoice = Read-Host ">番号>"
            # 入力なしの場合は追加を破棄して次の入力へ
            if ([string]::IsNullOrWhiteSpace($itemChoice)) {
                Write-Host "追加をキャンセルしました。"
                continue
            }
            # 項目選択
            if ($itemChoice -eq $items.Count) {
                $itemName = Read-Host ">>項目手入力"
            } else {
                $itemName = $items[[int]$itemChoice - 1]
            }

            # データ追加
            $entry = [PSCustomObject]@{日付=$dateStr; 連番=$seq; 金額=$amount; 項目=$itemName}
            $data.Add($entry) | Out-Null
            $lastDate = $dateStr
            $lastSeq = $seq
            $unsaved = $true
            Write-Host "追加: $dateStr.$seq $amount [$itemName]"
        }
    }
}
