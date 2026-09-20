# Copies this repo into the WoW: Forever beta AddOns folder as "Bartender4".
# Usage: powershell -File tools\install-forever.ps1 [-AddOns "<path to Interface\AddOns>"] [-Probe]
#   -Probe  also (re)installs the ForeverProbe diagnostic addon (it logs harmless Lua errors from its snippet tests)
param(
	[string]$AddOns = "E:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns",
	[switch]$Probe
)
$repo = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path $AddOns)) { throw "AddOns folder not found: $AddOns" }

robocopy $repo (Join-Path $AddOns "Bartender4") /MIR /XD ".git" "tools" ".github" /XF "*.md" ".gitignore" ".pkgmeta" ".luacheckrc" ".editorconfig" /NFL /NDL /NJH /NJS /NP | Out-Null
Write-Host "Installed Bartender4 into $AddOns"
if ($Probe) {
	robocopy (Join-Path $repo "tools\ForeverProbe") (Join-Path $AddOns "ForeverProbe") /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
	Write-Host "Installed ForeverProbe"
}
