# Claude Moving Box Wizard - interactive front end for ClaudeMovingBox.ps1 (English / 繁體中文)
# Run:  double-click ClaudeMovingBox-Wizard.bat,  or  .\claudemovingbox-wizard.ps1 [-Lang en|zh]
param([ValidateSet('en', 'zh')][string]$Lang)
$ErrorActionPreference = 'Stop'

$M = @{
  en = @{
    title = '=== Claude Moving Box Wizard: move a project and its Claude Code conversations ==='
    m1 = '  1) OLD PC: pack project + conversations -> zip'
    m1b = '  2) OLD PC: pack conversations ONLY (no project files) -> zip'
    m2 = '  3) NEW PC: restore (zip -> conversations [+ project], register in the desktop app)'
    qrestproj = 'The zip contains project files. Restore them too? (n = conversations only)'
    mq = '  Q) Quit'
    choose = 'Choose'
    err = 'Error'
    enter = 'Press Enter to exit'
    noengine = 'ClaudeMovingBox.ps1 not found next to this script:'
    qproj = 'Full path of the project folder (paste it)'
    nofolder = 'Folder not found:'
    qout = 'Where to save the zip'
    qwith = 'Include the project files too? (n = conversations only)'
    lproj = 'Project'; lout = 'Output'; lwith = 'Include project files'
    qgo = 'Start packing?'
    cancel = 'Cancelled.'
    done1 = 'Done! Copy the zip (and this whole folder) to the new PC, run the wizard and choose 3.'
    qzip = 'Full path of the zip file (paste it)'
    nofile = 'File not found:'
    qtarget = 'Folder on THIS PC for the project (created if missing)'
    needtarget = 'A project folder is required'
    qapp = 'Register in the Claude desktop app? (open the app once and start any conversation first)'
    prev = '--- Preview (nothing written yet) ---'
    qrest = 'Looks fine - restore for real?'
    cancel2 = 'Cancelled, nothing was written.'
    done2 = 'Done! FULLY quit the Claude desktop app (tray icon > Quit) and reopen it.'
    resume = 'To continue in a terminal: cd "{0}" then claude --resume'
    bye = 'Bye.'
  }
  zh = @{
    title = '=== Claude Moving Box 精靈：搬移專案與 Claude 對話 ==='
    m1 = '  1) 舊電腦：打包 專案 + 對話 -> zip'
    m1b = '  2) 舊電腦：只打包對話 (不含專案檔案) -> zip'
    m2 = '  3) 新電腦：還原 (zip -> 對話 [+ 專案]，並登記到桌面版 App)'
    qrestproj = 'zip 內含專案檔案，要一併還原嗎？(選 n 則只還原對話)'
    mq = '  Q) 離開'
    choose = '請選擇'
    err = '發生錯誤'
    enter = '按 Enter 結束'
    noengine = '找不到 ClaudeMovingBox.ps1 (請和精靈放在同一個資料夾)：'
    qproj = '專案資料夾完整路徑 (可直接貼上)'
    nofolder = '找不到資料夾:'
    qout = 'zip 要存到哪裡'
    qwith = '要連專案檔案一起打包嗎？(選 n 則只打包對話)'
    lproj = '專案'; lout = '輸出'; lwith = '含專案檔案'
    qgo = '開始打包？'
    cancel = '已取消。'
    done1 = '完成！把 zip 連同整個 Claude Moving Box 資料夾帶到新電腦，執行精靈選 3。'
    qzip = 'zip 檔完整路徑 (可直接貼上)'
    nofile = '找不到檔案:'
    qtarget = '專案要放在這台電腦的哪個資料夾 (不存在會自動建立)'
    needtarget = '必須指定專案資料夾'
    qapp = '要登記到 Claude 桌面版 App 嗎？(需先開過一次 App 並建立過任一對話)'
    prev = '--- 預覽 (尚未寫入任何東西) ---'
    qrest = '以上沒問題，正式還原？'
    cancel2 = '已取消，沒有寫入任何東西。'
    done2 = '完成！請「完全結束」Claude 桌面版 (系統匣選 Quit) 後再重開。'
    resume = '終端機接續對話：cd "{0}" 然後 claude --resume'
    bye = '已離開。'
  }
}

# First question: language. Asked in Traditional Chinese only when the system is
# Traditional Chinese (zh-TW / zh-HK / zh-MO / zh-Hant*); everything else is English.
if (-not $Lang) {
  $cul = (Get-UICulture).Name
  $sysZh = ($cul -in @('zh-TW', 'zh-HK', 'zh-MO')) -or ($cul -like 'zh-Hant*')
  # Fixed order: 1) English  2) 繁體中文.  Enter alone = 2 on a Traditional Chinese system, else 1.
  $def = if ($sysZh) { '2' } else { '1' }
  $head = if ($sysZh) { '請選擇語言 / Select language' } else { 'Select language / 請選擇語言' }
  $ask  = if ($sysZh) { '輸入 1 或 2 / Enter 1 or 2' } else { 'Enter 1 or 2 / 輸入 1 或 2' }
  Write-Host $head; Write-Host '  1) English'; Write-Host '  2) 繁體中文'
  $a = (Read-Host "$ask [$def]").Trim()
  if (-not $a) { $a = $def }
  $Lang = if ($a -eq '2') { 'zh' } else { 'en' }
}
$T = $M[$Lang]

# never close the window on an unexpected error
trap {
  Write-Host ''
  Write-Host "$($T.err): $($_.Exception.Message)" -ForegroundColor Red
  Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
  Read-Host $T.enter
  break
}

$engine = Join-Path $PSScriptRoot 'ClaudeMovingBox.ps1'
if (-not (Test-Path -LiteralPath $engine)) { Write-Host "$($T.noengine) $engine" -ForegroundColor Red; Read-Host $T.enter; return }

function Ask([string]$q, [string]$default = '') {
  $hint = if ($default) { " [$default]" } else { '' }
  $a = (Read-Host "$q$hint").Trim().Trim('"').Trim("'")
  if (-not $a) { $a = $default }
  return $a
}
function AskYesNo([string]$q, [bool]$default = $true) {
  $d = if ($default) { 'Y/n' } else { 'y/N' }
  $a = (Read-Host "$q ($d)").Trim().ToLower()
  if (-not $a) { return $default }
  return ($a -eq 'y' -or $a -eq 'yes')
}

Write-Host ''
Write-Host $T.title -ForegroundColor Cyan
Write-Host $T.m1; Write-Host $T.m1b; Write-Host $T.m2; Write-Host $T.mq
$choice = (Read-Host $T.choose).Trim().ToLower()

try {
  switch ($choice) {
    { $_ -in '1', '2' } {
      $proj = Ask $T.qproj
      if (-not $proj -or -not (Test-Path -LiteralPath $proj)) { throw "$($T.nofolder) $proj" }
      $name = Split-Path $proj.TrimEnd('\') -Leaf
      $out = Ask $T.qout (Join-Path ([Environment]::GetFolderPath('Desktop')) "$name-movingbox.zip")
      $withProj = ($choice -eq '1')
      Write-Host ''
      Write-Host "$($T.lproj): $proj"; Write-Host "$($T.lout): $out"; Write-Host "$($T.lwith): $withProj"
      if (-not (AskYesNo $T.qgo $true)) { Write-Host $T.cancel; break }
      $p = @{ Project = $proj; Out = $out; Lang = $Lang }
      if (-not $withProj) { $p.NoProject = $true }
      & $engine export @p
      Write-Host ''
      Write-Host $T.done1 -ForegroundColor Green
    }
    '3' {
      $zip = Ask $T.qzip
      if (-not $zip -or -not (Test-Path -LiteralPath $zip)) { throw "$($T.nofile) $zip" }
      $target = Ask $T.qtarget
      if (-not $target) { throw $T.needtarget }
      # does the zip carry project files? (peek at manifest.json)
      $hasProj = $false
      Add-Type -AssemblyName System.IO.Compression.FileSystem
      $za = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $zip).Path)
      try {
        $en = $za.Entries | Where-Object { $_.FullName -eq 'manifest.json' } | Select-Object -First 1
        if ($en) {
          $sr = New-Object IO.StreamReader($en.Open(), [Text.Encoding]::UTF8)
          try { $hasProj = [bool]((ConvertFrom-Json $sr.ReadToEnd()).includesProject) } finally { $sr.Dispose() }
        }
      } finally { $za.Dispose() }
      $restoreProj = if ($hasProj) { AskYesNo $T.qrestproj $true } else { $false }
      $app = AskYesNo $T.qapp $true
      $p = @{ Zip = $zip; Target = $target; Lang = $Lang }
      if ($hasProj -and -not $restoreProj) { $p.NoProject = $true }
      if (-not $app) { $p.NoApp = $true }
      Write-Host ''; Write-Host $T.prev -ForegroundColor Yellow
      & $engine import @p -Preview
      Write-Host ''
      if (-not (AskYesNo $T.qrest $true)) { Write-Host $T.cancel2; break }
      & $engine import @p
      Write-Host ''
      Write-Host $T.done2 -ForegroundColor Green
      Write-Host ($T.resume -f $target)
    }
    default { Write-Host $T.bye }
  }
}
catch { Write-Host "$($T.err): $($_.Exception.Message)" -ForegroundColor Red }
Write-Host ''
Read-Host $T.enter
