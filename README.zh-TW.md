# Claude Moving Box

[English](README.md) | **繁體中文**

把專案**連同 Claude Code 對話紀錄**搬到另一台電腦（Windows / PowerShell）。

> 非官方社群工具，與 Anthropic 無關。使用風險自負，請先備份。

## 特色

- **連專案檔案一起搬**，不只是對話：一個 zip 兩者都帶走（也可以只搬對話，自己選）。
- **互動式精靈**：雙擊就能用，回答幾個問題即可，不需要會下指令。
- **中英文雙語**：所有提示、進度和訊息都跟著你選的語言走。
- **登記到 Claude 桌面版**（Code 分頁），也支援 CLI：對話會出現在側邊欄，也能用 `claude --resume` 接續。桌面版這部分是盡力而為，見[注意事項](#注意事項)。
- **進度條**：打包和還原時顯示檔案數、大小、剩餘時間和目前讀取的檔案，OneDrive 檔案慢也不會看起來像當機。
- **安全**：還原前先預覽，確認後才寫入；已存在的檔案不會被覆蓋；桌面版索引登記前先備份。

## 為什麼需要它

只複製專案資料夾，Claude 的對話不會跟著過去：

- CLI 把對話存在 `%USERPROFILE%\.claude\projects\<編碼後路徑>\`，資料夾名稱由專案的絕對路徑換算而來。新電腦的路徑不同，舊對話就找不到。
- Claude **桌面版**（Code 分頁）有自己的對話索引，不會掃描 `.claude\projects`，所以複製過去的對話不會出現在側邊欄。

Claude Moving Box 兩個都處理：替 CLI 對應新路徑，並把對話登記到桌面版。

## 檔案

| 檔案 | 用途 |
|---|---|
| `ClaudeMovingBox-Wizard.bat` | **最簡單**：雙擊啟動精靈，繞過執行原則限制，不會自己關閉 |
| `claudemovingbox-wizard.ps1` | 互動式精靈。第一個問題是選語言，中英並列（`1) English  2) 繁體中文`）。直接按 Enter：繁體中文系統預設選 `2`，其他系統預設選 `1`。可用 `-Lang en` 或 `-Lang zh` 跳過這題 |
| `ClaudeMovingBox.ps1` | 主程式。精靈就是呼叫它，也可直接用指令操作 |

三個檔案請放同一個資料夾，搬到舊電腦時整個資料夾一起複製。

## 精靈用法（建議）

1. 雙擊 `ClaudeMovingBox-Wizard.bat`。
2. 選擇：
   - `1` 舊電腦：打包專案檔案 + 對話
   - `2` 舊電腦：**只打包對話**（不含專案檔案）
   - `3` 新電腦：還原（zip 內含專案檔案時，會問你要不要一併還原）
3. 依提示貼上路徑。還原時會先顯示預覽，確認後才會寫入。

## 指令用法

### 1. 舊電腦：打包

```powershell
.\ClaudeMovingBox.ps1 export -Project "D:\path\MyProject" -Out "D:\MyProject.zip"
```

| 參數 | 說明 |
|---|---|
| `-Project` | 舊電腦上的專案資料夾（要打真實路徑，工具靠它找對話） |
| `-Out` | 要產生的 zip 檔 |
| `-NoProject` | 只打包對話，不含專案檔案（用在 `import` 時：只還原對話，略過 zip 內的專案檔案） |
| `-Exclude a,b` | 專案中要略過的資料夾名稱，預設 `node_modules` |

zip 裡有：專案檔案、全部對話（`.jsonl`）、`manifest.json`。

### 2. 新電腦：還原

先預覽，不會寫入任何東西：

```powershell
.\ClaudeMovingBox.ps1 import -Zip "D:\MyProject.zip" -Target "C:\path\MyProject" -Preview
```

確認沒問題，拿掉 `-Preview` 再執行。它會依序：

1. 把專案檔案還原到 `-Target`（已存在的檔案不會被覆蓋）。
2. 把對話放到 `claude --resume` 找得到的位置。
3. 把對話登記到桌面版 App（登記前先備份索引）。完成後**完全結束 App 再重開**。不想動桌面版，加 `-NoApp`。

## 注意事項

- 新電腦要先開過一次桌面版 App 並建立過任一對話，工具才找得到索引位置。
- 桌面版索引格式沒有公開文件，App 更新後可能失效；CLI 那一步不受影響。其他使用者也回報過側邊欄登記不一定被接受，請當作盡力而為。
- 重複執行是安全的：已存在的檔案和已登記的對話都會略過。
- 索引備份在原資料夾旁，名稱為 `<資料夾>.bak-時間`，出問題把它還原即可。
- 被 PowerShell 擋住時：`powershell -ExecutionPolicy Bypass -File .\ClaudeMovingBox.ps1 import -Zip ... -Target ...`
- 對話可能含敏感資料（程式碼、路徑、貼上的金鑰），zip 請當作專案本身一樣保管。

## 授權

MIT，見 [LICENSE](LICENSE)。
