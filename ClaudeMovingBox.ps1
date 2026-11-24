<#
.SYNOPSIS
  Claude Moving Box - move a project and its Claude Code conversations between PCs.

  OLD PC :  .\ClaudeMovingBox.ps1 export -Project "D:\path\MyProject" -Out "D:\MyProject.zip"
  NEW PC :  .\ClaudeMovingBox.ps1 import -Zip "D:\MyProject.zip" -Target "C:\Users\me\Documents\MyProject"

  export  Packs the project folder (optional) + all its conversations into one zip.
  import  Restores the project folder, puts the conversations where the Claude CLI
          expects them, and registers them in the Claude desktop app (Code tab).

.PARAMETER Mode     export | import
.PARAMETER Project  (export) project folder on the old PC
.PARAMETER Out      (export) zip file to create
.PARAMETER NoProject (export) pack conversations only, not the project files
                     (import) restore conversations only, skip project files in the zip
.PARAMETER Exclude  (export) folder names to skip in the project (default: node_modules)
.PARAMETER Zip      (import) zip made by export
.PARAMETER Target   (import) project folder on this PC (created if missing)
.PARAMETER Preview  (import) show what would happen, write nothing
.PARAMETER NoApp    (import) skip desktop-app registration (CLI only)
.PARAMETER Lang     en | zh - language of the progress bar text (default en)

  export writes straight into the zip (no temporary copy of the project) and shows a progress bar
  with file count, size, estimated time and the file currently being read. A slow file usually means
  OneDrive is downloading it (Files On-Demand).
#>
param(
  [Parameter(Mandatory, Position = 0)][ValidateSet('export', 'import')][string]$Mode,
  [string]$Project, [string]$Out, [switch]$NoProject, [string[]]$Exclude = @('node_modules'),
  [string]$Zip, [string]$Target, [switch]$Preview, [switch]$NoApp,
  [ValidateSet('en', 'zh')][string]$Lang = 'en'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$utf8 = New-Object System.Text.UTF8Encoding($false)
$projectsRoot = Join-Path $HOME '.claude\projects'

function Get-EncodedName([string]$p) { ($p.TrimEnd('\')) -replace '[^A-Za-z0-9]', '-' }
function ToMs([string]$iso) { [DateTimeOffset]::Parse($iso).ToUnixTimeMilliseconds() }
function Copy-Tree([string]$from, [string]$to, [string[]]$skipDirs = @()) {
  # copies only files that do not already exist at the destination
  $a = @($from, $to, '/E', '/XC', '/XN', '/XO', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/R:1', '/W:1')
  if ($skipDirs.Count) { $a += '/XD'; $a += $skipDirs }
  & robocopy @a | Out-Null
  $rc = $LASTEXITCODE; $global:LASTEXITCODE = 0   # robocopy 1-7 means success
  if ($rc -ge 8) { throw ($L.robo -f $rc, $from, $to) }
}

# ---------- progress helpers ----------
# every message the engine prints lives here, so the wizard's language choice applies to all of it
$L = @{
  en = @{
    scan = 'Claude Moving Box: scanning'; scanSt = '{0} file(s) found'; pack = 'Claude Moving Box: packing'
    unpack = 'Claude Moving Box: extracting'; st = '{0}/{1} files    {2} / {3}'
    total = 'To pack       : {0} file(s), {1}'; skipped = '{0} file(s) skipped (locked or unreadable)'
    robo = 'robocopy failed ({0}): {1} -> {2}'; cantdir = 'Cannot read folder: {0}'
    unsafe = 'Unsafe path in zip: {0}'
    needexp = 'export needs -Project and -Out'; noproj = 'Project not found: {0}'
    nosess = 'No conversations found at {0}'
    folders = 'Folders that exist (pick the one for your project, rerun with the real project path):'
    nothing = 'Nothing to export.'; outdir = 'Output is a folder, using: {0}'
    lconv = 'Conversations : {0}'; lproj = 'Project files  : {0} (skipping: {1})'
    skipf = 'Skipped (cannot read): {0}'
    done = 'Done: {0} conversation(s){1} -> {2} ({3} MB, {4} s)'; plusproj = ' + project folder'
    needimp = 'import needs -Zip and -Target'; nozip = 'Zip not found: {0}'
    modeprev = 'Mode           : PREVIEW (nothing written)'; modeimp = 'Mode           : IMPORT'
    from = 'From           : {0}  ({1} conversations)'; ptarget = 'Project target : {0}'
    clis = 'CLI sessions   : {0}'
    pfilesP = 'Project files  : {0} file(s) would be restored (existing files are never overwritten)'
    pfilesR = 'Project files  : {0} file(s) restored (existing files are never overwritten)'
    newP = 'CLI sessions   : {0} new conversation(s) would be added'
    newR = 'CLI sessions   : {0} new conversation(s) added'
    noidx = 'Desktop app index not found (open the app once and start any session, then rerun). CLI side is done.'
    appP = 'Desktop app    : {0} conversation(s) would be registered'
    appR = 'Desktop app    : {0} conversation(s) registered'
    bak = 'Index backup   : {0}'
    finish = 'Done. Fully quit and reopen the Claude desktop app to see the conversations.'
  }
  zh = @{
    scan = 'Claude Moving Box：掃描中'; scanSt = '已找到 {0} 個檔案'; pack = 'Claude Moving Box：打包中'
    unpack = 'Claude Moving Box：解壓縮中'; st = '{0}/{1} 個檔案    {2} / {3}'
    total = '要打包：{0} 個檔案，{1}'; skipped = '{0} 個檔案被略過 (被鎖定或無法讀取)'
    robo = 'robocopy 失敗 ({0})：{1} -> {2}'; cantdir = '無法讀取資料夾：{0}'
    unsafe = 'zip 內有不安全的路徑：{0}'
    needexp = 'export 需要 -Project 與 -Out'; noproj = '找不到專案：{0}'
    nosess = '在 {0} 找不到對話'
    folders = '現有的對話資料夾 (找出對應你專案的那個，再用正確的專案路徑重跑)：'
    nothing = '沒有東西可以匯出。'; outdir = '輸出位置是資料夾，改存為：{0}'
    lconv = '對話：{0}'; lproj = '專案檔案：{0} (略過：{1})'
    skipf = '已略過 (無法讀取)：{0}'
    done = '完成：{0} 個對話{1} -> {2} ({3} MB，{4} 秒)'; plusproj = ' + 專案資料夾'
    needimp = 'import 需要 -Zip 與 -Target'; nozip = '找不到 zip：{0}'
    modeprev = '模式：預覽 (不會寫入任何東西)'; modeimp = '模式：還原'
    from = '來源：{0}  ({1} 個對話)'; ptarget = '專案放到：{0}'
    clis = 'CLI 對話放到：{0}'
    pfilesP = '專案檔案：將還原 {0} 個檔案 (已存在的檔案不會被覆蓋)'
    pfilesR = '專案檔案：已還原 {0} 個檔案 (已存在的檔案不會被覆蓋)'
    newP = 'CLI 對話：將新增 {0} 個對話'
    newR = 'CLI 對話：已新增 {0} 個對話'
    noidx = '找不到桌面版 App 的索引 (請先開一次 App 並建立任一對話，再重跑)。CLI 這邊已完成。'
    appP = '桌面版 App：將登記 {0} 個對話'
    appR = '桌面版 App：已登記 {0} 個對話'
    bak = '索引備份：{0}'
    finish = '完成。請完全結束 Claude 桌面版再重開，就會看到這些對話。'
  }
}[$Lang]

function Format-Size([double]$b) {
  if ($b -ge 1GB) { '{0:N2} GB' -f ($b / 1GB) } elseif ($b -ge 1MB) { '{0:N1} MB' -f ($b / 1MB) } else { '{0:N0} KB' -f ($b / 1KB) }
}
function New-ProgressState { @{ Total = [double]0; TotalFiles = 0; Bytes = [double]0; Files = 0; Skipped = 0
                                Sw = [Diagnostics.Stopwatch]::StartNew(); LastMs = [long]-1000; Skip = @() } }
function Show-Work($st, [string]$activity, [string]$current, [switch]$Force) {
  $ms = $st.Sw.ElapsedMilliseconds
  if (-not $Force -and ($ms - $st.LastMs) -lt 200) { return }   # redraw at most 5x per second
  $st.LastMs = $ms
  $pct = if ($st.Total -gt 0) { [int][math]::Min(100, 100 * $st.Bytes / $st.Total) }
         elseif ($st.TotalFiles -gt 0) { [int][math]::Min(100, 100 * $st.Files / $st.TotalFiles) } else { 100 }
  $eta = if ($st.Bytes -gt 0 -and $st.Total -gt $st.Bytes) { [int]($ms / 1000 * ($st.Total - $st.Bytes) / $st.Bytes) } else { -1 }
  if ($current.Length -gt 70) { $current = '...' + $current.Substring($current.Length - 67) }
  Write-Progress -Activity $activity -PercentComplete $pct -SecondsRemaining $eta -CurrentOperation $current `
    -Status ($L.st -f $st.Files, $st.TotalFiles, (Format-Size $st.Bytes), (Format-Size $st.Total))
}
function Add-TreeFiles([string]$root, [string]$prefix, [string[]]$skipDirs, $list, $st) {
  # walks the tree without following junctions and without entering excluded folder names
  $stack = New-Object 'System.Collections.Generic.Stack[string]'
  $stack.Push($root)
  while ($stack.Count) {
    $dir = $stack.Pop()
    try { $infos = (New-Object IO.DirectoryInfo $dir).GetFileSystemInfos() }
    catch { Write-Warning ($L.cantdir -f $dir); $st.Skipped++; continue }
    foreach ($i in $infos) {
      if ($i -is [IO.DirectoryInfo]) {
        if ($skipDirs -contains $i.Name) { continue }
        if ($i.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
        $stack.Push($i.FullName)
      }
      else {
        if ($st.Skip -contains $i.FullName) { continue }   # never pack the zip being written
        $rel = $i.FullName.Substring($root.Length).TrimStart('\') -replace '\\', '/'
        $list.Add([pscustomobject]@{ Full = $i.FullName; Entry = "$prefix/$rel"; Len = [double]$i.Length; Time = $i.LastWriteTime })
        $st.Total += $i.Length; $st.TotalFiles++
      }
    }
    if (($st.Sw.ElapsedMilliseconds - $st.LastMs) -ge 200) {
      $st.LastMs = $st.Sw.ElapsedMilliseconds
      Write-Progress -Activity $L.scan -Status ($L.scanSt -f $st.TotalFiles) -CurrentOperation $dir
    }
  }
}
function Expand-ZipWithProgress([string]$zipPath, [string]$dest) {
  $st = New-ProgressState
  $za = [IO.Compression.ZipFile]::OpenRead($zipPath)
  try {
    foreach ($e in $za.Entries) { if (-not $e.FullName.EndsWith('/')) { $st.Total += $e.Length; $st.TotalFiles++ } }
    $buf = New-Object byte[] (1MB)
    foreach ($e in $za.Entries) {
      $target = [IO.Path]::GetFullPath((Join-Path $dest ($e.FullName -replace '/', '\')))
      if ($target -ne $dest -and -not $target.StartsWith($dest + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw ($L.unsafe -f $e.FullName)
      }
      if ($e.FullName.EndsWith('/')) { New-Item -ItemType Directory -Force -Path $target | Out-Null; continue }
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
      $in = $e.Open()
      try {
        $o = New-Object IO.FileStream($target, [IO.FileMode]::Create, [IO.FileAccess]::Write)
        try {
          while (($r = $in.Read($buf, 0, $buf.Length)) -gt 0) { $o.Write($buf, 0, $r); $st.Bytes += $r; Show-Work $st $L.unpack $e.FullName }
        } finally { $o.Dispose() }
      } finally { $in.Dispose() }
      try { [IO.File]::SetLastWriteTime($target, $e.LastWriteTime.LocalDateTime) } catch {}
      $st.Files++
    }
    Show-Work $st $L.unpack '' -Force
  }
  finally { $za.Dispose(); Write-Progress -Activity $L.unpack -Completed }
}

# ============================== EXPORT ====================================
if ($Mode -eq 'export') {
  if (-not $Project -or -not $Out) { throw $L.needexp }
  if (-not (Test-Path -LiteralPath $Project)) { throw ($L.noproj -f $Project) }
  $Project = (Resolve-Path -LiteralPath $Project).Path.TrimEnd('\')
  $enc = Get-EncodedName $Project
  $sess = Join-Path $projectsRoot $enc
  if (-not (Test-Path -LiteralPath $sess)) {
    Write-Warning ($L.nosess -f $sess)
    Write-Warning $L.folders
    Get-ChildItem $projectsRoot -Directory | ForEach-Object { "  " + $_.Name }
    throw $L.nothing
  }

  # -Out may be a folder or lack ".zip" (e.g. "Desktop\output"): turn it into a real zip file name
  if (Test-Path -LiteralPath $Out -PathType Container) {
    $Out = Join-Path $Out ((Split-Path $Project -Leaf) + '-movingbox.zip')
    Write-Host ($L.outdir -f $Out)
  }
  elseif (-not [IO.Path]::GetExtension($Out)) { $Out += '.zip' }
  $Out = [IO.Path]::GetFullPath($Out)
  $outDir = Split-Path -Parent $Out
  if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
  $tmp = "$Out.partial"   # written here first, renamed when complete

  try {
    Write-Host ($L.lconv -f $sess)
    if (-not $NoProject) { Write-Host ($L.lproj -f $Project, ($Exclude -join ', ')) }

    # 1. scan: know the file count and total size up front so the bar can show a percentage
    $st = New-ProgressState
    $st.Skip = @($Out, $tmp)
    $items = New-Object 'System.Collections.Generic.List[object]'
    Add-TreeFiles $sess 'sessions' @() $items $st
    if (-not $NoProject) { Add-TreeFiles $Project 'project' $Exclude $items $st }
    Write-Progress -Activity $L.scan -Completed
    Write-Host ($L.total -f $st.TotalFiles, (Format-Size $st.Total))
    $n = @(Get-ChildItem -LiteralPath $sess -Filter *.jsonl -File).Count

    # 2. pack straight into the zip (no temporary copy of the project)
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
    $st.Sw.Restart(); $st.LastMs = -1000
    $za = [IO.Compression.ZipFile]::Open($tmp, [IO.Compression.ZipArchiveMode]::Create)
    try {
      $manifest = [ordered]@{
        tool = 'ClaudeMovingBox'; version = 1; exportedAt = (Get-Date).ToString('o')
        originalProject = $Project; sessionCount = $n; includesProject = (-not $NoProject)
      }
      $me = $za.CreateEntry('manifest.json', [IO.Compression.CompressionLevel]::Optimal)
      $ms = $me.Open()
      try { $b = $utf8.GetBytes(($manifest | ConvertTo-Json)); $ms.Write($b, 0, $b.Length) } finally { $ms.Dispose() }

      $buf = New-Object byte[] (1MB)
      foreach ($it in $items) {
        Show-Work $st $L.pack $it.Entry -Force   # show the name BEFORE reading: a slow OneDrive file stays visible
        try { $in = New-Object IO.FileStream($it.Full, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]'ReadWrite,Delete') }
        catch {
          Write-Warning ($L.skipf -f $it.Full)
          $st.Skipped++; $st.Bytes += $it.Len; $st.Files++; continue
        }
        try {
          $entry = $za.CreateEntry($it.Entry, [IO.Compression.CompressionLevel]::Optimal)
          $t = $it.Time; if ($t.Year -lt 1980 -or $t.Year -gt 2107) { $t = [datetime]'1980-01-01' }
          $entry.LastWriteTime = $t
          $o = $entry.Open()
          try {
            while (($r = $in.Read($buf, 0, $buf.Length)) -gt 0) {
              $o.Write($buf, 0, $r); $st.Bytes += $r
              Show-Work $st $L.pack $it.Entry
            }
          } finally { $o.Dispose() }
        } finally { $in.Dispose() }
        $st.Files++
      }
      Show-Work $st $L.pack '' -Force
    }
    finally { $za.Dispose(); Write-Progress -Activity $L.pack -Completed }

    if (Test-Path -LiteralPath $Out) { Remove-Item -LiteralPath $Out -Force }
    Move-Item -LiteralPath $tmp -Destination $Out
    $mb = [math]::Round((Get-Item -LiteralPath $Out).Length / 1MB, 1)
    Write-Host ($L.done -f $n, $(if (-not $NoProject) { $L.plusproj } else { '' }), $Out, $mb, [int]$st.Sw.Elapsed.TotalSeconds)
    if ($st.Skipped) { Write-Warning ($L.skipped -f $st.Skipped) }
  }
  finally {
    Write-Progress -Activity $L.scan -Completed
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }   # leftover of a failed or cancelled run
  }
  return
}

# ============================== IMPORT ====================================
if (-not $Zip -or -not $Target) { throw $L.needimp }
if (-not (Test-Path -LiteralPath $Zip)) { throw ($L.nozip -f $Zip) }
$Target = [IO.Path]::GetFullPath($Target).TrimEnd('\')
$enc = Get-EncodedName $Target
$destSess = Join-Path $projectsRoot $enc
$stage = Join-Path ([IO.Path]::GetTempPath()) ('movingbox-' + [guid]::NewGuid().ToString('N'))
Write-Host $(if ($Preview) { $L.modeprev } else { $L.modeimp })
try {
  New-Item -ItemType Directory -Force -Path $stage | Out-Null
  Expand-ZipWithProgress (Resolve-Path -LiteralPath $Zip).Path $stage
  $m = Get-Content "$stage\manifest.json" -Raw -Encoding UTF8 | ConvertFrom-Json
  Write-Host ($L.from -f $m.originalProject, $m.sessionCount)
  Write-Host ($L.ptarget -f $Target)
  Write-Host ($L.clis -f $destSess)

  # 1. project files
  if ($m.includesProject -and -not $NoProject) {
    $cnt = (Get-ChildItem "$stage\project" -Recurse -File -Force).Count
    Write-Host ($(if ($Preview) { $L.pfilesP } else { $L.pfilesR }) -f $cnt)
    if (-not $Preview) {
      New-Item -ItemType Directory -Force -Path $Target | Out-Null
      Copy-Tree "$stage\project" $Target
    }
  }
  elseif (-not (Test-Path -LiteralPath $Target) -and -not $Preview) {
    New-Item -ItemType Directory -Force -Path $Target | Out-Null
  }

  # 2. CLI conversations
  $new = (Get-ChildItem "$stage\sessions" -Filter *.jsonl |
    Where-Object { -not (Test-Path -LiteralPath (Join-Path $destSess $_.Name)) }).Count
  Write-Host ($(if ($Preview) { $L.newP } else { $L.newR }) -f $new)
  if (-not $Preview) {
    New-Item -ItemType Directory -Force -Path $destSess | Out-Null
    Copy-Tree "$stage\sessions" $destSess
  }

  # 3. desktop app index
  if ($NoApp) { return }
  $idxRoot = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Claude-Data') -Directory -Filter 'claude_*' -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName 'claude-code-sessions' } | Where-Object { Test-Path $_ } | Select-Object -First 1
  $idxDir = $null
  if ($idxRoot) {
    $idxDir = Get-ChildItem $idxRoot -Recurse -Filter 'local_*.json' | Sort-Object LastWriteTime -Descending |
      Select-Object -First 1 | ForEach-Object { $_.DirectoryName }
  }
  if (-not $idxDir) {
    Write-Warning $L.noidx
    return
  }
  $known = @{}
  Get-ChildItem $idxDir -Filter 'local_*.json' | ForEach-Object {
    try { $known[(Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json).cliSessionId] = $true } catch {}
  }
  $entries = @()
  foreach ($f in Get-ChildItem "$stage\sessions" -Filter *.jsonl) {
    $cli = $f.BaseName
    if ($known.ContainsKey($cli)) { continue }
    $title = $null; $created = $null; $model = $null
    foreach ($line in (Get-Content -LiteralPath $f.FullName -TotalCount 80 -Encoding UTF8)) {
      try { $o = $line | ConvertFrom-Json } catch { continue }
      if (-not $created -and $o.timestamp) { $created = ToMs $o.timestamp }
      if (-not $model -and $o.attachment.identity.modelId) { $model = $o.attachment.identity.modelId }
      if (-not $title -and $o.type -eq 'user' -and $o.message.content -is [string] -and
          $o.message.content.Trim() -and -not $o.message.content.TrimStart().StartsWith('<')) {
        $title = ($o.message.content.Trim() -replace '\s+', ' ')
      }
      if ($title -and $created -and $model) { break }
    }
    if (-not $title) { $title = $cli.Substring(0, 8) }
    if ($title.Length -gt 50) { $title = $title.Substring(0, 50) }
    $last = [DateTimeOffset]::new($f.LastWriteTimeUtc).ToUnixTimeMilliseconds()
    if (-not $created) { $created = $last }
    if (-not $model) { $model = 'claude-opus-5-5' }
    $entries += [ordered]@{
      sessionId = 'local_' + [guid]::NewGuid().ToString(); cliSessionId = $cli
      cwd = $Target; originCwd = $Target; gitAnchorsFolderRealpath = $Target
      folderPlace = [ordered]@{ cwd = $Target; realPath = $Target }
      lastFocusedAt = $last; createdAt = $created; lastActivityAt = $last; lastTurnEdgeAt = $last
      model = $model; effort = 'medium'; isArchived = $false; title = $title; titleSource = 'auto'
      permissionMode = 'auto'; completedTurns = 1
    }
    Write-Host ("  + {0}  {1}" -f $cli.Substring(0, 8), $title)
  }
  Write-Host ($(if ($Preview) { $L.appP } else { $L.appR }) -f $entries.Count)
  if (-not $Preview -and $entries.Count) {
    $bak = "$idxDir.bak-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
    Copy-Item -LiteralPath $idxDir -Destination $bak -Recurse
    foreach ($e in $entries) {
      [IO.File]::WriteAllText((Join-Path $idxDir "$($e.sessionId).json"), ($e | ConvertTo-Json -Depth 5), $utf8)
    }
    Write-Host ($L.bak -f $bak)
    Write-Host $L.finish
  }
}
finally { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
