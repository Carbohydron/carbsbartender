# Porting Bartender4 to WoW: Forever — Context Notes

Status: research only, nothing ported yet. Compiled 2026-09-20 from community sources on the
Forever beta (entered beta 2026-09-17, launch announced 2026-11-04). Findings are third-party
and NOT yet verified by us on a live client. Verify each in-game before relying on it.

## What Forever is (per community findings)
- Runs on **Retail/Mainline's UI + API architecture** (12.1.5-era API set), not Classic's.
- **Interface number 16001** (build 1.60.1.x, `WowB.exe`). TOC should list `16001` first.
- `WOW_PROJECT_ID` presumably behaves like Mainline, but `select(4, GetBuildInfo())` returns
  16001, so any `>= 100000`-style version checks take the wrong branch (verify).
- Includes Midnight "addon disarmament": secret values, combat-log restrictions, protected
  functions. Has Edit Mode and Cooldown Manager. Classic globals like `GetItemInfo`,
  `GetSpellInfo`, `UnitAura` reportedly absent (use `C_*` namespaces).
- Talents use `C_Traits`; `GetSpecialization` reportedly missing.

## Biggest risk (project-defining)
Reported: **secure snippets fail** — the client lacks `loadstring_untainted`, so `WrapScript`,
state drivers (`RegisterStateDriver`) and `RunAttribute` crash. Bartender4 depends on these
for paging, stance/form swaps, vehicle/override bar, pet battle, and self/focus/target
cast modifiers. "Conventional action-bar addons cannot work" per that source; bars that
re-anchor Blizzard's own buttons keep drag/drop.
First task: confirm this on a live client with a minimal test addon. Everything else hinges on it.

## Bartender4 code touching the risk
- [Bartender4.lua](Bartender4.lua): `_onstate-petbattle` (l.156), `_onstate-vehicle` (l.189), `RegisterStateDriver` (l.174, 215)
- [StateBar.lua](StateBar.lua): `_onstate-page` (l.226), target-help/harm/all drivers (l.253-311)
- [ActionBar.lua](ActionBar.lua), [Bar.lua](Bar.lua): also use secure attributes/handlers
- [HideBlizzard.lua](HideBlizzard.lua) (108 lines): hides Blizzard bars; must be checked against Forever's frame names
- Flavor gating via `WOW_PROJECT_ID` in ~51 places (StateBar.lua, Bartender4.lua, HideBlizzard.lua, ...)
- Current TOC: `## Interface: 120007,120100,11509,50504,20506`; add `16001`
- Libs are `.pkgmeta` externals (not vendored): notably **LibActionButton-1.0** holds most
  button/secure logic and will need the same audit. Also LibKeyBound, LibDualSpec (spec API!), LibButtonGlow.

## Other known hazards
- Reported bug: SavedVariables written on exit but not read back on launch (breaks Bartender4DB
  persistence until fixed by Blizzard; check).
- Unknown events throw on registration; wrap in `pcall`.
- `SetBinding` / `SetOverrideBindingClick` / `UseAction` are protected.
- Spec-based profiles (LibDualSpec) will break if `GetSpecialization` is truly absent.

## Suggested plan
1. Get a Forever beta client; build a tiny test addon: secure header + `RegisterStateDriver`, `WrapScript`, SecureActionButton with `action` attribute; log results.
2. Dump `_G` frame names for action bars (`MainMenuBar`, `MainActionBar`, `MultiBar*`, `OverrideActionBar`, `StanceBar`, `PetActionBar`) and `C_ActionBar`.
3. Add 16001 to a fork-local TOC; load with `/console scriptErrors 1`; triage errors module by module.
4. Add a `WoWForever` flavor detector; branch state-driver code (fallback: restricted mode re-anchoring Blizzard buttons if snippets stay broken).
5. Audit LibActionButton-1.0, LibDualSpec, StatusTracking/MicroMenu/BagBar (Retail-only Blizzard frames).

## Sources
- https://github.com/imperial64/forever-addon-dev (API reference + restriction measurements, lint tool)
- https://github.com/Thunderz96/forever-addon-kit (API baseline, porting tools, secure snippet findings)
- https://pixelnitro.com/will-classic-addons-work-with-wow-forever-beta-client-full-compatibility-guide/
- https://github.com/tobarisu1/wow_forever_addons

## Measured on live Forever beta (1.60.1 build 69913, 2026-09-20, ForeverProbe)
- `loadstring_untainted` is nil -> restricted snippets (`SecureHandlerExecute`, `RunAttribute`, `_onstate-*` bodies,
  `WrapScript` bodies) throw "attempt to call a nil value" at RestrictedExecution.lua:79. Snippets are DEAD.
- `RegisterStateDriver` works (sets `state-<name>` attr, including in combat).
- `RegisterAttributeDriver(btn, "action"|"unit", "[cond]v;...")` WORKS in combat: `action` attr is set as a number,
  and clicking the SecureActionButton runs the paged action in combat. This is the snippet-free replacement path.
- WOW_PROJECT_ID == WOW_PROJECT_MAINLINE (1). toc=16001.
- Missing globals: GetSpecialization, GetSpecializationInfo, GetActiveSpecGroup, GetSpellInfo, GetItemInfo, UnitAura, LibStub,
  ActionButton_UpdateHotkeys. Present: C_ActionBar (73 fns), C_EditMode (12), C_SpecializationInfo, C_Spell, C_Item, C_UnitAuras.
- Frames: MainMenuBar/MainMenuBarArtFrame/MainMenuBarManager MISSING. Present: MainActionBar, MultiBarBottomLeft/BottomRight/Right/Left,
  MultiBar5-7, StanceBar, PetActionBar, PossessActionBar, OverrideActionBar, MicroMenu(+Container), BagsBar,
  StatusTrackingBarManager, ExtraActionBarFrame, ZoneAbilityFrame, MainMenuBarVehicleLeaveButton, MultiCastActionBarFrame.
- ActionButton1: `action` attribute nil but `.action` property = 73 (warrior stance page).
- Bar-state fns work: GetBonusBarOffset/Index, GetOverrideBarIndex(33), GetVehicleBarIndex(31), Has*ActionBar, GetNumShapeshiftForms.
- Probe: `tools/ForeverProbe` (copy into `_classic_beta_/Interface/AddOns`).
