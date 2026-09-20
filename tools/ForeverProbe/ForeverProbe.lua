-- ForeverProbe: measures what an action bar addon needs on WoW: Forever.
-- Results are kept in a table, shown in a copyable window (/fprobe), and written to
-- ForeverProbeDB (SavedVariables, written on logout/reload).
local out = {}
local function log(fmt, ...)
	local ok, s = pcall(string.format, fmt, ...)
	out[#out + 1] = ok and s or tostring(fmt)
end
local function try(name, fn)
	local ok, r = pcall(function() return tostring(fn()) end)
	log("%-38s %s %s", name, ok and "OK  ->" or "FAIL ->", tostring(r))
	return ok
end

local function env()
	log("== ENVIRONMENT ==")
	local v, b, d, toc = GetBuildInfo()
	log("GetBuildInfo: version=%s build=%s date=%s toc=%s", tostring(v), tostring(b), tostring(d), tostring(toc))
	log("WOW_PROJECT_ID=%s MAINLINE=%s CLASSIC=%s", tostring(WOW_PROJECT_ID), tostring(WOW_PROJECT_MAINLINE), tostring(WOW_PROJECT_CLASSIC))
	log("class=%s level=%s", tostring(select(2, UnitClass("player"))), tostring(UnitLevel("player")))
	log("-- global types --")
	local names = { "loadstring_untainted", "loadstring", "RegisterStateDriver", "UnregisterStateDriver",
		"RegisterAttributeDriver", "SecureHandlerWrapScript", "SecureHandlerExecute", "SecureHandlerSetFrameRef",
		"SecureCmdOptionParse", "GetSpecialization", "GetSpecializationInfo", "GetActiveSpecGroup",
		"C_SpecializationInfo", "C_ActionBar", "C_EditMode", "C_PetBattles", "C_Spell", "C_SpellBook", "C_Item",
		"C_UnitAuras", "C_Traits", "GetSpellInfo", "GetItemInfo", "UnitAura", "GetActionInfo", "GetActionTexture",
		"GetActionCooldown", "GetBonusBarOffset", "GetBonusBarIndex", "GetOverrideBarIndex", "GetVehicleBarIndex",
		"HasBonusActionBar", "HasOverrideActionBar", "HasVehicleActionBar", "HasExtraActionBar", "GetExtraBarIndex",
		"GetNumShapeshiftForms", "GetShapeshiftFormInfo", "InCombatLockdown", "SetOverrideBindingClick", "SetBinding",
		"ClearOverrideBindings", "LibStub", "ActionButton_UpdateHotkeys", "ActionBarController_UpdateAll",
		"MultiCastActionBarFrame", "Masque" }
	for _, n in ipairs(names) do
		log("%-30s %s", n, type(_G[n]))
	end
	local function listns(nsname)
		local ns = _G[nsname]
		if type(ns) ~= "table" then return end
		local t = {}
		for k in pairs(ns) do t[#t + 1] = tostring(k) end
		table.sort(t)
		log("%s members (%d): %s", nsname, #t, table.concat(t, ", "))
	end
	pcall(listns, "C_ActionBar")
	pcall(listns, "C_EditMode")
end

local function frames()
	log("== BLIZZARD FRAMES (exists / shown / protected) ==")
	local names = { "MainMenuBar", "MainActionBar", "MainMenuBarArtFrame", "MultiBarBottomLeft", "MultiBarBottomRight",
		"MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar",
		"PossessActionBar", "OverrideActionBar", "MicroMenu", "MicroMenuContainer", "BagsBar", "MainMenuBarBackpackButton",
		"StatusTrackingBarManager", "MainStatusTrackingBarContainer", "ExtraActionBarFrame", "ZoneAbilityFrame",
		"MainMenuBarVehicleLeaveButton", "EditModeManagerFrame", "ActionButton1", "ActionButton12",
		"MultiBarBottomLeftButton1", "PetActionButton1", "StanceButton1", "MainMenuBarManager", "ActionBarController",
		"MicroButtonAndBagsBar", "MultiCastActionBarFrame", "VehicleSeatIndicator", "TalkingHeadFrame" }
	for _, n in ipairs(names) do
		local f = _G[n]
		if type(f) == "table" and f.IsShown then
			local ok, s = pcall(function()
				return ("shown=%s protected=%s"):format(tostring(f:IsShown()), tostring(f.IsProtected and f:IsProtected()))
			end)
			log("%-32s yes  %s", n, ok and s or "?")
		else
			log("%-32s %s", n, type(f) == "nil" and "MISSING" or type(f))
		end
	end
	local ab = _G.ActionButton1
	if ab then
		pcall(function()
			log("ActionButton1 action attr=%s .action=%s type=%s", tostring(ab:GetAttribute("action")),
				tostring(ab.action), tostring(ab:GetAttribute("type")))
		end)
	end
end

local function apis()
	log("== BAR STATE APIs ==")
	try("GetBonusBarOffset()", GetBonusBarOffset)
	try("GetBonusBarIndex()", GetBonusBarIndex)
	try("GetOverrideBarIndex()", GetOverrideBarIndex)
	try("GetVehicleBarIndex()", GetVehicleBarIndex)
	try("HasBonusActionBar()", HasBonusActionBar)
	try("HasOverrideActionBar()", HasOverrideActionBar)
	try("HasVehicleActionBar()", HasVehicleActionBar)
	try("GetNumShapeshiftForms()", GetNumShapeshiftForms)
	try("GetActionInfo(1)", function() return table.concat({ tostring(GetActionInfo(1)) }, ",") end)
	try("GetActionTexture(1)", function() return GetActionTexture(1) end)
	try("GetSpecialization()", GetSpecialization)
	try("GetActiveSpecGroup()", GetActiveSpecGroup)
	try("SecureCmdOptionParse('[mod:shift]a;b')", function() return SecureCmdOptionParse("[mod:shift]a;b") end)
	log("-- events (RegisterEvent pcall; only failures listed) --")
	local f = CreateFrame("Frame")
	for _, e in ipairs({ "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
		"UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS",
		"UNIT_ENTERED_VEHICLE", "PET_BATTLE_OPENING_START", "PLAYER_SPECIALIZATION_CHANGED",
		"ACTIVE_TALENT_GROUP_CHANGED", "SPELL_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_STATE", "UPDATE_BINDINGS",
		"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
		local ok, err = pcall(f.RegisterEvent, f, e)
		if not ok then log("event %-32s FAIL %s", e, tostring(err)) end
	end
end

-- Secure-handler tests. Results resolve after ~2s (state drivers update on next frame).
local header, sbtn
local changes = 0
local function secure()
	log("== SECURE / RESTRICTED-ENV TESTS ==")
	local ok, err = pcall(function()
		header = CreateFrame("Frame", "FProbeHeader", UIParent, "SecureHandlerStateTemplate")
		sbtn = CreateFrame("Button", "FProbeBtn", UIParent, "SecureActionButtonTemplate")
	end)
	log("create secure header + button: %s %s", ok and "OK" or "FAIL", ok and "" or tostring(err))
	if not ok then return end

	header:SetScript("OnAttributeChanged", function(_, n, v)
		if (n == "state-page" or n == "probestate") and changes < 25 then
			changes = changes + 1
			log("  attr change %-12s -> %s (combat=%s)", n, tostring(v), tostring(InCombatLockdown()))
		end
	end)
	try("SetAttribute _onstate-page snippet", function()
		header:SetAttribute("_onstate-page", [[ self:SetAttribute("probestate", newstate) ]])
		return "set"
	end)
	try("RegisterStateDriver [combat]1;[mod:shift]2;0", function()
		RegisterStateDriver(header, "page", "[combat]1;[mod:shift]2;0")
		return "registered"
	end)
	try("SecureHandlerExecute set attr", function()
		SecureHandlerExecute(header, [[ self:SetAttribute("execok", "yes") ]])
		return "called"
	end)
	try("RunAttribute via Execute", function()
		header:SetAttribute("runme", [[ self:SetAttribute("runok", "yes") ]])
		SecureHandlerExecute(header, [[ self:RunAttribute("runme") ]])
		return "called"
	end)
	try("header:WrapScript(btn, OnClick)", function()
		header:WrapScript(sbtn, "OnClick", [[ self:SetAttribute("wrapok", "pre") return nil ]],
			[[ self:SetAttribute("wrapok2", "post") ]])
		return "wrapped"
	end)
	try("SecureHandlerWrapScript (global)", function()
		SecureHandlerWrapScript(sbtn, "OnEnter", header, [[ self:SetAttribute("wrap2ok", "yes") ]])
		return "wrapped"
	end)
	try("SecureActionButton type=action action=1", function()
		sbtn:SetAttribute("type", "action")
		sbtn:SetAttribute("action", 1)
		return "set"
	end)
	try("SetOverrideBindingClick (out of combat)", function()
		SetOverrideBindingClick(header, false, "CTRL-SHIFT-F12", "FProbeBtn")
		ClearOverrideBindings(header)
		return "ok"
	end)

	C_Timer.After(2, function()
		log("-- secure results after 2s --")
		log("execok (Execute ran snippet)   = %s", tostring(header:GetAttribute("execok")))
		log("runok (RunAttribute)           = %s", tostring(header:GetAttribute("runok")))
		log("state-page (driver updated)    = %s", tostring(header:GetAttribute("state-page")))
		log("probestate (_onstate snippet)  = %s", tostring(header:GetAttribute("probestate")))
		log("frame is protected             = %s", tostring(header:IsProtected()))
		log("-> hold SHIFT now / enter combat; further changes are logged above (/fprobe to refresh)")
	end)
end

-- Snippet-free paging: attribute drivers set attributes directly from macro conditionals in
-- secure C code, so they should not need loadstring_untainted. A visible test button is created.
local changes2 = 0
local function secure2()
	log("== NO-SNIPPET PAGING TESTS (RegisterAttributeDriver on a secure button) ==")
	local ok, err = pcall(function()
		local b = CreateFrame("Button", "FProbeBtn2", UIParent, "SecureActionButtonTemplate")
		b:SetSize(48, 48); b:SetPoint("CENTER", 0, -200)
		b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints()
		b.txt = b:CreateFontString(nil, "OVERLAY", "GameFontNormal"); b.txt:SetPoint("TOP", b, "BOTTOM", 0, -2)
		b:RegisterForClicks("AnyUp", "AnyDown")
		b:SetAttribute("type", "action")
		b:SetAttribute("action", 1)
		b:SetScript("OnAttributeChanged", function(self, n, v)
			if n == "action" or n == "unit" then
				if n == "action" then
					self.icon:SetTexture(GetActionTexture(tonumber(v) or 1))
					self.txt:SetText(("action=%s (%s)"):format(tostring(v), type(v)))
				end
				if changes2 < 25 then
					changes2 = changes2 + 1
					log("  btn2 %-6s -> %s (%s) combat=%s", n, tostring(v), type(v), tostring(InCombatLockdown()))
				end
			end
		end)
		b:SetScript("PostClick", function(_, mb, down)
			log("  btn2 click %s down=%s combat=%s", tostring(mb), tostring(down), tostring(InCombatLockdown()))
		end)
		RegisterAttributeDriver(b, "action", "[mod:shift]2;[combat]3;[bonusbar:1]73;1")
		RegisterAttributeDriver(b, "unit", "[@target,harm]target;player")
	end)
	log("attribute drivers on FProbeBtn2: %s %s", ok and "OK" or "FAIL", ok and "" or tostring(err))
	C_Timer.After(2, function()
		local b = _G.FProbeBtn2
		if not b then return end
		log("btn2 after 2s: action=%s (%s) unit=%s type=%s", tostring(b:GetAttribute("action")),
			type(b:GetAttribute("action")), tostring(b:GetAttribute("unit")), tostring(b:GetAttribute("type")))
		log("-> hold SHIFT, enter combat, target an enemy; then CLICK the button below the screen centre in and out of combat")
	end)
end

-- Open questions for the Bartender4 port: how does an attribute driver treat the value "nil", do
-- Unregister* exist, and which action slots do the vehicle/override/possess bars use.
local function secure3()
	log("== PORT QUESTIONS ==")
	log("UnregisterAttributeDriver: %s / UnregisterStateDriver: %s", type(UnregisterAttributeDriver), type(UnregisterStateDriver))
	try("GetTempShapeshiftBarIndex", C_ActionBar.GetTempShapeshiftBarIndex)
	try("C_ActionBar.GetActionBarPage", C_ActionBar.GetActionBarPage)
	for _, n in ipairs({ "OverrideActionBarButton1", "PossessButton1", "MultiBarBottomLeftButton1", "MultiBarRightButton1",
		"ExtraActionButton1", "PetActionButton1" }) do
		local f = _G[n]
		if f then
			log("%-28s .action=%s attr action=%s attr actionpage=%s", n, tostring(f.action), tostring(f:GetAttribute("action")),
				tostring(f:GetAttribute("actionpage")))
		else
			log("%-28s MISSING", n)
		end
	end
	for _, n in ipairs({ "MainActionBar", "OverrideActionBar", "MultiBarBottomLeft" }) do
		local f = _G[n]
		if f then
			log("%-28s attr actionpage=%s statehidden=%s", n, tostring(f:GetAttribute("actionpage")), tostring(f:GetAttribute("statehidden")))
		end
	end
	local ok, err = pcall(function()
		local b = CreateFrame("Button", "FProbeBtn3", UIParent, "SecureActionButtonTemplate")
		RegisterAttributeDriver(b, "unit", "[mod:shift]player;nil")
		RegisterAttributeDriver(b, "fade", "[mod:shift]true;false")
		RegisterStateDriver(b, "visibility", "[mod:shift]hide;show")
	end)
	log("nil-value attribute driver setup: %s %s", ok and "OK" or "FAIL", ok and "" or tostring(err))
	C_Timer.After(2, function()
		local b = _G.FProbeBtn3
		if not b then return end
		local u, f = b:GetAttribute("unit"), b:GetAttribute("fade")
		log("nil-driver result (no shift held): unit=%s (%s)  fade=%s (%s)  visibility shown=%s", tostring(u), type(u), tostring(f), type(f), tostring(b:IsShown()))
	end)
end

local function report()
	ForeverProbeDB = { when = date(), results = out }
end

local function run()
	wipe(out)
	changes = 0
	changes2 = 0
	log("ForeverProbe run %s", date())
	env(); frames(); apis(); secure(); secure2(); secure3()
	C_Timer.After(2.5, report)
end

local win
local function show()
	if not win then
		win = CreateFrame("Frame", "ForeverProbeWindow", UIParent, "BasicFrameTemplateWithInset")
		win:SetSize(760, 520); win:SetPoint("CENTER"); win:SetFrameStrata("DIALOG")
		win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag("LeftButton")
		win:SetScript("OnDragStart", win.StartMoving); win:SetScript("OnDragStop", win.StopMovingOrSizing)
		local sf = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
		sf:SetPoint("TOPLEFT", 10, -30); sf:SetPoint("BOTTOMRIGHT", -30, 10)
		local eb = CreateFrame("EditBox", nil, sf)
		eb:SetMultiLine(true); eb:SetFontObject(ChatFontNormal); eb:SetWidth(700); eb:SetAutoFocus(false)
		eb:SetScript("OnEscapePressed", function() win:Hide() end)
		sf:SetScrollChild(eb)
		win.eb = eb
	end
	win.eb:SetText(table.concat(out, "\n"))
	win:Show()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	local ok, err = pcall(run)
	if not ok then log("PROBE CRASHED: %s", tostring(err)) end
	print("|cff33ff99ForeverProbe|r ran. Type /fprobe to view results (Ctrl+A, Ctrl+C to copy). /reload afterwards to flush the saved file.")
end)

SLASH_FPROBE1 = "/fprobe"
SlashCmdList.FPROBE = function(msg)
	if msg == "run" then pcall(run) end
	show()
end
