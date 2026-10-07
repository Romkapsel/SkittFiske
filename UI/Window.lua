-- Fiskevinduet: skill, agn, fangsten så langt. Skjult til du starter å fiske.
-- Agnknappene er sikre knapper, så vinduet kan ikke vises, skjules eller flyttes i kamp (det køes).
local addonName, ns = ...
local W = {}
ns.Window = W
local Data, Logic, Game, L = ns.Data, ns.Logic, ns.Game, ns.L

local WIDTH, ROWS, PICK = 250, 8, 6
local f, skillFs, zoneFs, lureBtn, lureText, glow, pulse, statsFs, hintFs, warnFs, emptyFs
local rows, picks = {}, {}
local lures = {}
local isLure = {} -- item-ID → om det er agn (tooltipen sjekkes én gang per ting)

local BACKDROP = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local function macroFor(id) return ("/use item:%d\n/use %d"):format(id, Data.MAIN_HAND) end

local function lureTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if self.lureId then
    GameTooltip:SetItemByID(self.lureId)
  elseif #lures == 0 then
    GameTooltip:SetText(L.LURE_NONE_IN_BAGS)
  else
    GameTooltip:SetText(L.LURE_PICK)
  end
  GameTooltip:Show()
end

local function hideTip() GameTooltip:Hide() end

local function setPicker(show)
  if Game.InCombat() then return end
  for i, b in ipairs(picks) do b:SetShown(show and lures[i] ~= nil) end
end

local function makeLureButton(parent, size)
  local b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
  b:SetSize(size, size)
  b:RegisterForClicks(Game.ClickMode()) -- bare én av dem, ellers brukes agnet to ganger
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  b.count:SetPoint("BOTTOMRIGHT", -2, 2)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:SetScript("OnEnter", lureTooltip)
  b:SetScript("OnLeave", hideTip)
  return b
end

function W.Create(cdb)
  if f then return f end
  f = CreateFrame("Frame", "SkittFiskeWindow", UIParent, "BackdropTemplate")
  f:SetSize(WIDTH, 120)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  if f.SetBackdrop then
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(0.04, 0.09, 0.13, 0.92)
    f:SetBackdropBorderColor(0.31, 0.7, 0.85, 0.9)
  end
  local p = cdb.window
  if p and p.x then f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p.x, p.y)
  else f:SetPoint("CENTER", UIParent, "CENTER", 300, 0) end
  f:SetScript("OnDragStart", function(self) if not Game.InCombat() then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    if x then cdb.window = { x = x, y = y } end
  end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 12, -10)
  title:SetText(L.TITLE)
  title:SetTextColor(0.31, 0.7, 0.85)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 0, 0)
  close:SetScript("OnClick", function() ns.Stop() end) -- vinduet åpent = du fisker; krysset avslutter som makroen

  skillFs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  skillFs:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  zoneFs = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  zoneFs:SetPoint("TOPLEFT", skillFs, "BOTTOMLEFT", 0, -2)

  -- Agn: én knapp. Ett slags agn i baggen = klikk setter det på. Flere = klikk viser dem.
  lureBtn = makeLureButton(f, 36)
  lureBtn:SetPoint("TOPLEFT", zoneFs, "BOTTOMLEFT", 0, -8)
  lureBtn:HookScript("PostClick", function()
    if #lures > 1 then setPicker(not (picks[1] and picks[1]:IsShown())) end
  end)
  glow = lureBtn:CreateTexture(nil, "OVERLAY")
  glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
  glow:SetBlendMode("ADD")
  glow:SetPoint("TOPLEFT", -6, 6)
  glow:SetPoint("BOTTOMRIGHT", 6, -6)
  glow:Hide()
  pulse = glow:CreateAnimationGroup()
  pulse:SetLooping("BOUNCE")
  local a = pulse:CreateAnimation("Alpha")
  a:SetFromAlpha(1)
  a:SetToAlpha(0.2)
  a:SetDuration(0.6)

  lureText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  lureText:SetPoint("LEFT", lureBtn, "RIGHT", 8, 0)

  for i = 1, PICK do
    local b = makeLureButton(f, 30)
    if i == 1 then b:SetPoint("TOPLEFT", lureBtn, "BOTTOMLEFT", 0, -6)
    else b:SetPoint("LEFT", picks[i - 1], "RIGHT", 4, 0) end
    b:SetAttribute("type", "macro")
    b:HookScript("PostClick", function() setPicker(false) end)
    b:Hide()
    picks[i] = b
  end

  local anchor = CreateFrame("Frame", nil, f)
  anchor:SetSize(1, 1)
  anchor:SetPoint("TOPLEFT", lureBtn, "BOTTOMLEFT", 0, -42)
  emptyFs = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  emptyFs:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
  emptyFs:SetText(L.CATCH_EMPTY)
  for i = 1, ROWS do
    local r = {}
    r.icon = f:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(16, 16)
    r.icon:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -(i - 1) * 18)
    r.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.text:SetWidth(WIDTH - 50)
    r.text:SetJustifyH("LEFT")
    rows[i] = r
  end
  statsFs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  warnFs = f:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
  warnFs:SetText(L.COMBAT_WARN)
  warnFs:Hide()
  hintFs = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hintFs:SetWidth(WIDTH - 24)
  hintFs:SetJustifyH("LEFT")
  hintFs:SetText(L.HINT)
  f.anchor = anchor
  f:Hide()

  f:SetScript("OnUpdate", function(self, el)
    self.tick = (self.tick or 0) + el
    if self.tick >= 1 then self.tick = 0 W.RefreshLure() end
  end)
  return f
end

------------------------------------------------------------------------
-- Oppdatering
------------------------------------------------------------------------

function W.RefreshSkill()
  if not f then return end
  local rank, max, mod = Game.Skill()
  if rank then
    skillFs:SetText(L.SKILL:format(rank, max or rank) .. ((mod or 0) > 0 and L.SKILL_BONUS:format(mod) or ""))
  else
    skillFs:SetText(L.SKILL_UNKNOWN)
  end
  local z, sub = Game.Zone()
  zoneFs:SetText((sub ~= "" and sub ~= z) and (sub .. ", " .. z) or z)
end

-- Agnene i baggen og knappene for dem (bare utenfor kamp: sikre attributter)
function W.RefreshLures()
  if not f or Game.InCombat() then return end
  local bag, extra = {}, {}
  Game.EachBagItem(function(_, _, id, _, count)
    if isLure[id] == nil then isLure[id] = Game.IsLure(id) end
    if isLure[id] then
      bag[id] = (bag[id] or 0) + count
      if not Data.LURES[id] then extra[id] = true end
    end
  end)
  lures = Logic.Lures(bag, Data.LURES, extra)
  local one = #lures == 1 and lures[1] or nil
  if one then
    lureBtn:SetAttribute("type", "macro")
    lureBtn:SetAttribute("macrotext", macroFor(one.id))
  else
    lureBtn:SetAttribute("type", nil)
    lureBtn:SetAttribute("macrotext", nil)
  end
  lureBtn.lureId = one and one.id or nil
  local first = lures[1]
  lureBtn.icon:SetTexture(first and Game.ItemIcon(first.id) or "Interface\\Icons\\Trade_Fishing")
  lureBtn.icon:SetDesaturated(first == nil)
  lureBtn.count:SetText(one and one.count > 1 and one.count or "")
  for i, b in ipairs(picks) do
    local l = lures[i]
    if l then
      b:SetAttribute("macrotext", macroFor(l.id))
      b.lureId = l.id
      b.icon:SetTexture(Game.ItemIcon(l.id))
      b.count:SetText(l.count > 1 and l.count or "")
    else
      b.lureId = nil
      b:Hide()
    end
  end
  if #lures < 2 then setPicker(false) end
  W.Layout()
end

function W.RefreshLure()
  if not f then return end
  local has, ms = Game.LureOnPole()
  local state, secs = Logic.LureState(has, ms, Data.LURE_LOW)
  if state == "none" then
    lureText:SetText(#lures > 0 and L.LURE_NONE or L.LURE_NONE_IN_BAGS)
    lureText:SetTextColor(1, 0.82, 0)
  else
    lureText:SetText(L.LURE_LEFT:format(Logic.Left(secs, L)))
    if state == "low" then lureText:SetTextColor(1, 0.82, 0) else lureText:SetTextColor(0.5, 0.83, 0.5) end
  end
  local light = state ~= "ok" and #lures > 0
  glow:SetShown(light)
  if light and not pulse:IsPlaying() then pulse:Play() elseif not light and pulse:IsPlaying() then pulse:Stop() end
end

function W.RefreshCatch(cdb)
  if not f then return end
  local s = cdb.session
  local n = 0
  if s then
    local list = {}
    for _, id in ipairs(s.order) do list[#list + 1] = id end
    table.sort(list, function(a, b) return s.items[a] > s.items[b] end)
    for i = 1, ROWS do
      local id, r = list[i], rows[i]
      if id then
        n = i
        r.icon:SetTexture(Game.ItemIcon(id))
        r.text:SetText(L.CATCH_ROW:format(s.items[id], s.names[id] or Game.ItemName(id) or ("#" .. id)))
        r.icon:Show() r.text:Show()
      else
        r.icon:Hide() r.text:Hide()
      end
    end
    local st = L.STATS:format(s.casts, s.caught)
    if s.escaped > 0 then st = st .. L.STATS_ESCAPED:format(s.escaped) end
    statsFs:SetText(st)
  else
    for _, r in ipairs(rows) do r.icon:Hide() r.text:Hide() end
    statsFs:SetText("")
  end
  emptyFs:SetShown(n == 0)
  f.rowsShown = math.max(n, 1)
  W.Layout()
end

function W.Layout()
  if not f or Game.InCombat() then return end
  local pickerOpen = picks[1] and picks[1]:IsShown()
  f.anchor:ClearAllPoints()
  f.anchor:SetPoint("TOPLEFT", lureBtn, "BOTTOMLEFT", 0, pickerOpen and -44 or -10)
  local rowsH = (f.rowsShown or 1) * 18
  statsFs:ClearAllPoints()
  statsFs:SetPoint("TOPLEFT", f.anchor, "TOPLEFT", 0, -rowsH - 6)
  warnFs:ClearAllPoints()
  warnFs:SetPoint("TOPLEFT", statsFs, "BOTTOMLEFT", 0, -4)
  hintFs:ClearAllPoints()
  hintFs:SetPoint("TOPLEFT", warnFs:IsShown() and warnFs or statsFs, "BOTTOMLEFT", 0, -8)
  local h = 10 + 18 + 6 + 14 + 2 + 12 + 8 + 36 + (pickerOpen and 44 or 10) + rowsH + 6 + 14 + (warnFs:IsShown() and 16 or 0) + 8 + 28 + 10
  f:SetHeight(h)
end

function W.Refresh(cdb)
  if not f then return end
  W.RefreshSkill()
  W.RefreshLures()
  W.RefreshLure()
  W.RefreshCatch(cdb)
end

function W.CombatWarning(on)
  if not f then return end
  warnFs:SetShown(on)
  W.Layout()
end

------------------------------------------------------------------------
-- Vise og skjule (køes i kamp)
------------------------------------------------------------------------

function W.Show()
  if not f then return end
  if Game.InCombat() then ns.Queue("window", true) return end
  f:Show()
end

function W.Hide()
  if not f then return end
  if Game.InCombat() then ns.Queue("window", false) return end
  setPicker(false)
  f:Hide()
end

function W.IsShown() return f and f:IsShown() end
