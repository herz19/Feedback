# Electrical engineering toolkit for Claude Code - Windows installer
# Installs: Git + Python (if missing), the Claude skills (global), the Python engineering libraries,
# and Claude Code itself (if missing). Safe to run again: it updates what is already there.

$ErrorActionPreference = "Stop"
$RepoUrl   = "https://github.com/herz19/Feedback.git"
$Branch    = "master"
$RepoDir   = Join-Path $env:USERPROFILE "Feedback"
$SkillsDir = Join-Path $env:USERPROFILE ".claude\skills"

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "    OK  $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "    !!  $msg" -ForegroundColor Yellow }
function Have($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
}

# 1. Git and Python ---------------------------------------------------------
Step "Checking Git and Python"
if (-not (Have "git")) {
    if (Have "winget") { winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements; Refresh-Path }
    else { throw "Git is missing and winget is not available. Install Git from https://git-scm.com then run this again." }
}
Ok "Git: $(git --version)"

$py = $null
foreach ($c in @("py","python")) { if (Have $c) { try { & $c --version *> $null; if ($LASTEXITCODE -eq 0) { $py = $c; break } } catch {} } }
if (-not $py) {
    if (Have "winget") { winget install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements; Refresh-Path; $py = "py" }
    else { throw "Python is missing and winget is not available. Install Python 3.12 from https://python.org (tick 'Add to PATH') then run this again." }
}
Ok "Python: $(& $py --version)"

# 2. Download or update the skills repository -------------------------------
Step "Downloading the skills to $RepoDir"
if (Test-Path (Join-Path $RepoDir ".git")) {
    git -C $RepoDir fetch origin
    git -C $RepoDir checkout $Branch
    git -C $RepoDir pull --ff-only origin $Branch
} else {
    git clone --branch $Branch $RepoUrl $RepoDir
}
Ok "Repository ready"

# 3. Copy skills to the global Claude folder (works in every project) -------
Step "Installing skills to $SkillsDir"
New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null
Get-ChildItem (Join-Path $RepoDir ".claude\skills") | ForEach-Object {
    Copy-Item $_.FullName -Destination $SkillsDir -Recurse -Force
    Ok $_.Name
}
$GlobalClaudeMd = Join-Path $env:USERPROFILE ".claude\CLAUDE.md"
if (-not (Test-Path $GlobalClaudeMd)) {
    Copy-Item (Join-Path $RepoDir "CLAUDE.md") $GlobalClaudeMd
    Ok "Global CLAUDE.md created"
} else {
    Warn "You already have $GlobalClaudeMd - left it unchanged. Project rules are in $RepoDir\CLAUDE.md"
}

# 4. Python engineering libraries -------------------------------------------
Step "Installing Python libraries (pandapower, python-control, OpenDSS, ezdxf, Excel, PDF)"
& $py -m pip install --upgrade pip
& $py -m pip install "pandapower>=3.0,<3.5" control ezdxf openpyxl pandas scipy matplotlib opendssdirect.py pdfplumber
& $py -c "import pandapower, control, ezdxf, openpyxl, opendssdirect, pdfplumber; print('    OK  all Python libraries import')"

# 5. ngspice (circuit simulation) -------------------------------------------
Step "Checking ngspice"
if (Have "ngspice") { Ok "ngspice found" }
else {
    Warn "ngspice is not installed. Download the Windows build from https://ngspice.sourceforge.io/download.html"
    Warn "Extract it (for example to C:\Spice64) and add C:\Spice64\bin to PATH."
}

# 6. Claude Code -------------------------------------------------------------
Step "Checking Claude Code"
if (Have "claude") { Ok "Claude Code found: $(claude --version)" }
else {
    Warn "Claude Code not found. Installing with the official installer..."
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
    Refresh-Path
}

Write-Host "`nDone. Open a NEW terminal and run:  claude" -ForegroundColor Green
Write-Host "Inside Claude Code, type /skills to see the installed skills, and /plugin for plugins." -ForegroundColor Green
Write-Host "Optional (needs software on this PC): MATLAB MCP Server, PowerMCP (PSS/E, PowerWorld), cad-mcp (AutoCAD)." -ForegroundColor Green
