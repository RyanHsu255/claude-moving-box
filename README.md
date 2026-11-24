# Claude Moving Box

**English** | [繁體中文](README.zh-TW.md)

Move a project **and its Claude Code conversations** to another PC (Windows / PowerShell).

> Unofficial community tool, not affiliated with Anthropic. Use at your own risk and keep backups.

## Features

- **Moves the project files too**, not just the conversations: one zip carries both (or conversations only, your choice).
- **Interactive wizard**: double-click and answer a few questions. No command-line knowledge needed.
- **English and Traditional Chinese**: every prompt, progress line and message follows the language you pick.
- **Registers conversations in the Claude desktop app** (Code tab) as well as for the CLI, so they show up in the sidebar and in `claude --resume`. The desktop-app part is best-effort, see [Notes](#notes).
- **Progress bar** while packing and restoring, with file count, size, time left and the file being read, so a slow OneDrive file never looks like a freeze.
- **Safe**: restore previews first and writes nothing until you confirm; existing files are never overwritten; the desktop-app index is backed up first.

## Why

Copying a project folder does not bring the Claude conversations along:

- The CLI stores conversations in `%USERPROFILE%\.claude\projects\<encoded-path>\`. The folder name is derived from the project's absolute path, so a different path on the new PC means the old conversations are not found.
- The Claude **desktop app** (Code tab) keeps its own session index and does not scan `.claude\projects`, so copied conversations never appear in its sidebar.

Claude Moving Box handles both: it re-maps the path for the CLI and registers the conversations in the desktop app.

## Files

| File | Purpose |
|---|---|
| `ClaudeMovingBox-Wizard.bat` | **Easiest**: double-click to start the wizard. Bypasses execution policy and never closes by itself. |
| `claudemovingbox-wizard.ps1` | Interactive wizard. The first question is the language, shown in both languages (`1) English  2) 繁體中文`). Pressing Enter picks `2` on a Traditional Chinese system and `1` on any other system. Skip the question with `-Lang en` or `-Lang zh`. |
| `ClaudeMovingBox.ps1` | The engine. The wizard calls it; you can also call it directly. |

Keep the three files in the same folder, and copy the whole folder to the old PC.

## Wizard (recommended)

1. Double-click `ClaudeMovingBox-Wizard.bat`.
2. Choose:
   - `1` old PC: pack project files + conversations
   - `2` old PC: pack **conversations only** (no project files)
   - `3` new PC: restore (if the zip contains project files you are asked whether to restore them too)
3. Paste the paths when asked. Restore shows a preview first and writes nothing until you confirm.

## Command line

### 1. Old PC: pack

```powershell
.\ClaudeMovingBox.ps1 export -Project "D:\path\MyProject" -Out "D:\MyProject.zip"
```

| Option | Meaning |
|---|---|
| `-Project` | Project folder on the old PC (must be the real path; the tool uses it to find the conversations) |
| `-Out` | Zip file to create |
| `-NoProject` | Pack conversations only, not the project files (with `import`: restore conversations only, skip project files in the zip) |
| `-Exclude a,b` | Folder names to skip inside the project (default `node_modules`) |

The zip contains the project files, all conversations (`.jsonl`) and a `manifest.json`.

### 2. New PC: restore

Preview first (writes nothing):

```powershell
.\ClaudeMovingBox.ps1 import -Zip "D:\MyProject.zip" -Target "C:\path\MyProject" -Preview
```

Then run it again without `-Preview`. It will:

1. Restore the project files into `-Target` (existing files are never overwritten).
2. Put the conversations where `claude --resume` finds them.
3. Register them in the Claude desktop app (the app's index folder is backed up first). **Fully quit and reopen the app** afterwards. Use `-NoApp` to skip this step.

## Notes

- Open the desktop app once and start any conversation on the new PC before importing, so the tool can locate the app's index folder.
- The desktop app's index format is undocumented and may change with app updates; the CLI step does not depend on it. Reports from other users suggest sidebar registration is not always accepted, so treat it as best-effort.
- Safe to re-run: existing files and already-registered conversations are skipped.
- Index backups are saved next to the original as `<folder>.bak-<timestamp>`; restore it if something looks wrong.
- If PowerShell blocks the script: `powershell -ExecutionPolicy Bypass -File .\ClaudeMovingBox.ps1 import -Zip ... -Target ...`
- Conversations can contain sensitive data (code, paths, pasted secrets). Treat the zip like the project itself.

## License

MIT, see [LICENSE](LICENSE).
