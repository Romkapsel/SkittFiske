-- Fiskevinduet: Daniels fiskeramme av treverk med pergament i midten (art/fiskeramme.png → Media/frame.tga).
-- Skjult til du starter å fiske. Agn-ringene er sikre knapper, så vinduet kan ikke vises, skjules, skaleres eller
-- flyttes i kamp (det køes). Plasseringene i LAYOUT er piksler i frame.tga og står likt i tools/render_media.py.
local addonName, ns = ...
local W = {}
ns.Window = W
local Data, Logic, Game, L = ns.Data, ns.Logic, ns.Game, ns.L

ns.MEDIA = "Interface\\AddOns\\SkittFiske\\Media\\"
local M = ns.MEDIA
ns.FONT_TITLE, ns.FONT_TEXT = "Fonts\\MORPHEUS.TTF", "Fonts\\FRIZQT__.TTF"
ns.INK = { 0.27, 0.17, 0.09 }     -- tekst på pergamentet
ns.HEAD = { 0.43, 0.18, 0.07 }    -- overskrifter
ns.FADED = { 0.47, 0.38, 0.27 }   -- dempet tekst
ns.PLATE = { 0.93, 0.86, 0.71 }   -- tekst på treverket
local INK, HEAD, FADED, PLATE = ns.INK, ns.HEAD, ns.FADED, ns.PLATE

------------------------------------------------------------------------
-- Byggeklosser uten spillets maler (BackdropTemplate, UIPanelCloseButton … stoppet vinduet i Forever 7. okt).
-- Pynt som kan feile, går gjennom ns.Safe og skrives i debug i stedet for å stoppe resten.
------------------------------------------------------------------------

function ns.Safe(label, fn)
  local ok, err = pcall(fn)
  if not ok then ns.Debug.Ui(label, err) end
  return ok
end

-- Tekst med egen font (Friz/Morpheus); faller tilbake til spillets fontobjekt hvis fonten ikke kan settes
function ns.Text(parent, font, color, size, path, shadow)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  local ok = size and fs:SetFont(path or ns.FONT_TEXT, size, "")
  if not ok then fs:SetFontObject(_G[font] or GameFontNormal) end
  if shadow and fs.SetShadowOffset then fs:SetShadowOffset(1, -1) end
  if color then fs:SetTextColor(color[1], color[2], color[3]) end
  return fs
end

-- Knapp som bare er tekst (på treplata i rammen), med lys når musa er over
function ns.PlateButton(parent, text, w, h, onClick, size)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, h)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 0.9, 0.6, 0.15)
  b.label = ns.Text(b, "GameFontNormal", PLATE, size or 12, nil, true)
  b.label:SetPoint("CENTER", 0, 0)
  b.label:SetText(text)
  b:RegisterForClicks("LeftButtonUp")
  b:SetScript("OnClick", onClick)
  return b
end

-- Knapp av mørkt tre (rapporten)
function ns.WoodButton(parent, text, w, h, onClick)
  local b = ns.PlateButton(parent, text, w, h, onClick, 11)
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.24, 0.16, 0.1, 1)
  local edge = b:CreateTexture(nil, "BORDER")
  edge:SetPoint("TOPLEFT", -1, 1)
  edge:SetPoint("BOTTOMRIGHT", 1, -1)
  edge:SetColorTexture(0.12, 0.08, 0.05, 1)
  return b
end

------------------------------------------------------------------------
-- Mål
------------------------------------------------------------------------

local LAYOUT = {
  crop = { 168, 856 },
  title = 104, zone = 146, divider = 168,
  left = 362, right = 552, colw = 172,
  head1 = 174, head2 = 284,
  checks = 204, checkStep = 25,
  rings = 312, ring = 44, ringStep = 52,
  caught = 204, bar = 228, barw = 168, stats = 258,
  rows = 312, rowStep = 23,
  hint = 388,
  buttons = { 650, 726 }, buttonY = 436, buttonW = 74, buttonH = 24,
  close = { 771, 85, 22 },
}
local S = 0.8 -- enheter per piksel i frame.tga
local CROP_W = LAYOUT.crop[2] - LAYOUT.crop[1]
local WIN_W, WIN_H = CROP_W * S, 512 * S
local RINGS, ROWS = 3, 3
local CENTER_X = 536
local TITLE_X = 508 -- tittelen og sonen litt til venstre for midten (Daniel)

local function px(v) return v * S end
local function X(v) return (v - LAYOUT.crop[1]) * S end
local function at(region, x, y, point)
  region:ClearAllPoints()
  region:SetPoint(point or "TOPLEFT", region:GetParent(), "TOPLEFT", X(x), -px(y))
end

local f, zoneFs, hintFs, caughtFs, statsFs, barFill, barText, noLureFs
local checks, rings, rows = {}, {}, {}
local lures = {}
local isLure = {} -- item-ID → om det er agn (tooltipen sjekkes én gang per ting)
local pulses = {}

local function macroFor(id) return ("/use item:%d\n/use %d"):format(id, Data.MAIN_HAND) end
local function hideTip() GameTooltip:Hide() end

------------------------------------------------------------------------
-- Bygging
------------------------------------------------------------------------

local function heading(text, x, y)
  local fs = ns.Text(f, "GameFontNormalLarge", HEAD, 19, ns.FONT_TITLE)
  fs:SetPoint("TOP", f, "TOPLEFT", X(x), -px(y))
  fs:SetText(text)
  return fs
end

local function makeRing(i)
  local size = px(LAYOUT.ring)
  local b = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
  b:SetSize(size, size)
  at(b, LAYOUT.left + 8 + (i - 1) * LAYOUT.ringStep, LAYOUT.rings)
  b:RegisterForClicks(Game.ClickMode()) -- bare én av dem, ellers brukes agnet to ganger
  b:SetAttribute("type", "macro")
  b.glow = b:CreateTexture(nil, "BACKGROUND")
  b.glow:SetPoint("TOPLEFT", -px(6), px(6))
  b.glow:SetPoint("BOTTOMRIGHT", px(6), -px(6))
  b.glow:SetTexture(M .. "mask_circle.tga")
  b.glow:SetVertexColor(1, 0.75, 0.2)
  b.glow:Hide()
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", px(6), -px(6))
  b.icon:SetPoint("BOTTOMRIGHT", -px(6), px(6))
  ns.Safe("ringmaske", function()
    local mask = b:CreateMaskTexture()
    mask:SetAllPoints(b.icon)
    mask:SetTexture(M .. "mask_circle.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    b.icon:AddMaskTexture(mask)
  end)
  b.ring = b:CreateTexture(nil, "OVERLAY")
  b.ring:SetAllPoints()
  b.ring:SetTexture(M .. "ring.tga")
  b.count = ns.Text(b, "GameFontNormalSmall", { 1, 1, 1 }, 11, nil, true)
  b.count:SetPoint("BOTTOMRIGHT", -px(1), px(2))
  b:SetScript("OnEnter", function(self)
    self.ring:SetVertexColor(1.3, 1.2, 0.9)
    if self.lureId then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetItemByID(self.lureId)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function(self) self.ring:SetVertexColor(1, 1, 1) hideTip() end)
  b:Hide()
  return b
end

local function makeCheck(i, label)
  local y = LAYOUT.checks + 6 + (i - 1) * LAYOUT.checkStep
  local c = {}
  c.box = f:CreateTexture(nil, "ARTWORK")
  c.box:SetSize(px(21), px(21))
  at(c.box, LAYOUT.left + 4, y)
  c.box:SetTexture(M .. "box.tga")
  c.mark = f:CreateTexture(nil, "OVERLAY")
  c.mark:SetSize(px(21), px(21))
  at(c.mark, LAYOUT.left + 4, y)
  c.text = ns.Text(f, "GameFontNormalSmall", INK, 14)
  at(c.text, LAYOUT.left + 33, y + 2)
  c.text:SetText(label)
  return c
end

function W.Create(cdb)
  if f then return f end
  f = CreateFrame("Frame", "SkittFiskeWindow", UIParent)
  f:Hide() -- skjult til den er ferdig bygget (et halvt vindu skal aldri vises)
  f:SetSize(WIN_W, WIN_H)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScale(cdb.scale or 0.9)
  local p = cdb.window
  if p and p.x then f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p.x, p.y)
  else f:SetPoint("CENTER", UIParent, "CENTER", 250, -40) end
  f:SetScript("OnDragStart", function(self) if not Game.InCombat() then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    if x then cdb.window = { x = x, y = y } end
  end)
  -- Shift + rull: større eller mindre (ikke i kamp)
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function(self, delta)
    if not IsShiftKeyDown() or Game.InCombat() then return end
    local s = math.max(0.5, math.min(1.4, (cdb.scale or 0.9) + delta * 0.05))
    cdb.scale = s
    self:SetScale(s)
  end)

  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture(M .. "frame.tga")
  bg:SetTexCoord(LAYOUT.crop[1] / 1024, LAYOUT.crop[2] / 1024, 0, 1)

  local title = ns.Text(f, "GameFontNormalLarge", HEAD, 27, ns.FONT_TITLE)
  title:SetPoint("TOP", f, "TOPLEFT", X(TITLE_X), -px(LAYOUT.title))
  title:SetText(L.TITLE)
  zoneFs = ns.Text(f, "GameFontNormalSmall", FADED, 10)
  zoneFs:SetPoint("TOP", f, "TOPLEFT", X(TITLE_X), -px(LAYOUT.zone))
  local line = f:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(0.59, 0.47, 0.31, 0.7)
  line:SetSize(px(252), 1)
  line:SetPoint("TOP", f, "TOPLEFT", X(TITLE_X), -px(LAYOUT.divider))

  local c = LAYOUT.close
  at(ns.PlateButton(f, "X", px(c[3]), px(c[3]), function() ns.Stop() end, 12), c[1], c[2]) -- vinduet åpent = du fisker

  -- Venstre: Klar og Agn
  local midL = LAYOUT.left + LAYOUT.colw / 2
  heading(L.PLAQUE_READY, midL, LAYOUT.head1)
  checks.pole = makeCheck(1, L.CHECK_POLE)
  checks.lure = makeCheck(2, L.CHECK_LURE)
  checks.sound = makeCheck(3, L.CHECK_SOUND)
  heading(L.PLAQUE_LURE, midL, LAYOUT.head2)
  for i = 1, RINGS do rings[i] = makeRing(i) end
  noLureFs = ns.Text(f, "GameFontNormalSmall", FADED, 11)
  at(noLureFs, LAYOUT.left + 8, LAYOUT.rings + 14)
  noLureFs:SetText(L.LURE_NONE_IN_BAGS)

  -- Høyre: Fiske og Fangst
  local R = LAYOUT.right
  heading(L.PLAQUE_SKILL, R + LAYOUT.colw / 2, LAYOUT.head1)
  local lbl = ns.Text(f, "GameFontNormalSmall", INK, 14)
  at(lbl, R + 4, LAYOUT.caught + 4)
  lbl:SetText(L.CAUGHT)
  caughtFs = ns.Text(f, "GameFontNormal", HEAD, 15)
  caughtFs:SetPoint("TOPRIGHT", f, "TOPLEFT", X(R + LAYOUT.barw - 4), -px(LAYOUT.caught + 3))

  local barBg = f:CreateTexture(nil, "ARTWORK")
  barBg:SetPoint("TOPLEFT", f, "TOPLEFT", X(R + 3), -px(LAYOUT.bar + 5))
  barBg:SetSize(px(LAYOUT.barw - 6), px(19))
  barBg:SetColorTexture(0.24, 0.17, 0.12, 0.95)
  barFill = f:CreateTexture(nil, "ARTWORK", nil, 1)
  barFill:SetPoint("TOPLEFT", barBg, "TOPLEFT")
  barFill:SetHeight(px(19))
  barFill:SetColorTexture(0.34, 0.55, 0.24, 1)
  barFill.full = px(LAYOUT.barw - 6)
  local barFrame = f:CreateTexture(nil, "OVERLAY")
  barFrame:SetPoint("TOPLEFT", f, "TOPLEFT", X(R), -px(LAYOUT.bar + 2))
  barFrame:SetSize(px(LAYOUT.barw), px(25))
  barFrame:SetTexture(M .. "bar_frame.tga")
  barText = ns.Text(f, "GameFontNormalSmall", { 1, 0.98, 0.92 }, 12, nil, true)
  barText:SetPoint("CENTER", barBg, "CENTER", 0, 0)

  statsFs = ns.Text(f, "GameFontNormalSmall", FADED, 12)
  at(statsFs, R + 4, LAYOUT.stats)

  heading(L.PLAQUE_CATCH, R + LAYOUT.colw / 2, LAYOUT.head2)
  for i = 1, ROWS do
    local r = {}
    local y = LAYOUT.rows + (i - 1) * LAYOUT.rowStep
    r.icon = f:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(px(19), px(19))
    at(r.icon, R + 4, y + 1)
    r.text = ns.Text(f, "GameFontNormalSmall", INK, 12)
    at(r.text, R + 28, y + 3)
    r.text:SetWidth(px(LAYOUT.colw - 36))
    r.text:SetJustifyH("LEFT")
    if r.text.SetWordWrap then r.text:SetWordWrap(false) end
    rows[i] = r
  end

  -- Nederst i pergamentet: hjelp (eller kampvarsel). På treplata: knappene.
  hintFs = ns.Text(f, "GameFontNormalSmall", FADED, 10)
  hintFs:SetPoint("TOP", f, "TOPLEFT", X(CENTER_X), -px(LAYOUT.hint))
  hintFs:SetText(L.HINT)
  local hintHit = CreateFrame("Frame", nil, f)
  hintHit:SetAllPoints(hintFs)
  hintHit:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L.HINT_TIP, 1, 1, 1, 1, true)
    GameTooltip:AddLine(L.SIZE_TIP, 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  hintHit:SetScript("OnLeave", hideTip)
  local bw, bh = px(LAYOUT.buttonW), px(LAYOUT.buttonH)
  at(ns.PlateButton(f, L.BTN_REPORT, bw, bh, function() ns.Report.Show(1) end), LAYOUT.buttons[1], LAYOUT.buttonY)
  at(ns.PlateButton(f, L.BTN_DONE, bw, bh, function() ns.Stop() end), LAYOUT.buttons[2], LAYOUT.buttonY)

  -- Lys som pulserer når noe mangler (agn-ringene og krysset ved Agn)
  ns.Safe("glow", function()
    local regions = { checks.lure.mark }
    for _, b in ipairs(rings) do regions[#regions + 1] = b.glow end
    for _, region in ipairs(regions) do
      local g = region:CreateAnimationGroup()
      g:SetLooping("BOUNCE")
      local a = g:CreateAnimation("Alpha")
      a:SetFromAlpha(1)
      a:SetToAlpha(0.25)
      a:SetDuration(0.6)
      pulses[region] = g
    end
  end)

  f:SetScript("OnUpdate", function(self, el)
    self.tick = (self.tick or 0) + el
    if self.tick >= 1 then self.tick = 0 W.RefreshLure() end
  end)
  f.ready = true
  return f
end

local function pulse(region, on)
  local g = pulses[region]
  if not g then return end
  if on and not g:IsPlaying() then g:Play() elseif not on and g:IsPlaying() then g:Stop() region:SetAlpha(1) end
end

local function setCheck(c, ok)
  c.mark:SetTexture(M .. (ok and "check.tga" or "cross.tga"))
end

------------------------------------------------------------------------
-- Oppdatering
------------------------------------------------------------------------

function W.RefreshSkill()
  if not f or not f.ready then return end
  local rank, max, mod = Game.Skill()
  if rank then
    barText:SetText(L.BAR:format(rank, max or rank) .. (((mod or 0) > 0) and ("  +" .. mod) or ""))
    local ratio = (max and max > 0) and math.min(1, rank / max) or 1
    barFill:SetWidth(math.max(1, barFill.full * ratio))
  else
    barText:SetText(L.SKILL_UNKNOWN)
    barFill:SetWidth(1)
  end
  local z, sub = Game.Zone()
  zoneFs:SetText((sub ~= "" and sub ~= z) and (sub .. ", " .. z) or z)
  -- Stang på?
  local id = Game.Equipped(Data.MAIN_HAND)
  local class, subClass
  if id then
    local _
    _, class, subClass = Game.ItemInstant(id)
  end
  setCheck(checks.pole, class == Data.POLE_CLASS and subClass == Data.POLE_SUBCLASS)
  setCheck(checks.sound, ns.active)
end

-- Agnene i baggen på ringene (bare utenfor kamp: sikre attributter)
function W.RefreshLures()
  if not f or not f.ready or Game.InCombat() then return end
  local bag, extra = {}, {}
  Game.EachBagItem(function(_, _, id, _, count)
    if isLure[id] == nil then isLure[id] = Game.IsLure(id) end
    if isLure[id] then
      bag[id] = (bag[id] or 0) + count
      if not Data.LURES[id] then extra[id] = true end
    end
  end)
  lures = Logic.Lures(bag, Data.LURES, extra)
  for i, b in ipairs(rings) do
    local l = lures[i]
    if l then
      b:SetAttribute("macrotext", macroFor(l.id))
      b.lureId = l.id
      b.icon:SetTexture(Game.ItemIcon(l.id))
      b.count:SetText(l.count > 1 and l.count or "")
      b:Show()
    else
      b.lureId = nil
      b:SetAttribute("macrotext", nil)
      b:Hide()
    end
  end
  noLureFs:SetShown(#lures == 0)
end

function W.RefreshLure()
  if not f or not f.ready then return end
  local has, ms = Game.LureOnPole()
  local state, secs = Logic.LureState(has, ms, Data.LURE_LOW)
  if state == "none" then
    checks.lure.text:SetText(L.CHECK_LURE)
  else
    checks.lure.text:SetText(L.CHECK_LURE_LEFT:format(Logic.Left(secs, L)))
  end
  setCheck(checks.lure, state ~= "none")
  local light = state ~= "ok" and #lures > 0
  pulse(checks.lure.mark, state ~= "ok")
  for _, b in ipairs(rings) do
    b.glow:SetShown(light)
    pulse(b.glow, light)
  end
end

function W.RefreshCatch(cdb)
  if not f or not f.ready then return end
  local s = cdb.session
  local list = {}
  if s then
    for _, id in ipairs(s.order) do list[#list + 1] = id end
    table.sort(list, function(a, b) return s.items[a] > s.items[b] end)
  end
  for i, r in ipairs(rows) do
    local id = list[i]
    if i == ROWS and #list > ROWS then
      r.icon:Hide()
      r.text:SetText(L.MORE:format(#list - ROWS + 1))
      r.text:SetTextColor(FADED[1], FADED[2], FADED[3])
      r.text:Show()
    elseif id then
      r.icon:SetTexture(Game.ItemIcon(id))
      r.icon:Show()
      r.text:SetText(L.CATCH_ROW:format(s.items[id], s.names[id] or Game.ItemName(id) or ("#" .. id)))
      r.text:SetTextColor(INK[1], INK[2], INK[3])
      r.text:Show()
    elseif i == 1 then
      r.icon:Hide()
      r.text:SetText(L.CATCH_EMPTY)
      r.text:SetTextColor(FADED[1], FADED[2], FADED[3])
      r.text:Show()
    else
      r.icon:Hide()
      r.text:Hide()
    end
  end
  caughtFs:SetText(s and s.caught or 0)
  local st = L.CASTS:format(s and s.casts or 0)
  if s and s.escaped > 0 then st = st .. L.STATS_ESCAPED:format(s.escaped) end
  statsFs:SetText(st)
end

function W.Refresh(cdb)
  if not f or not f.ready then return end
  W.RefreshSkill()
  W.RefreshLures()
  W.RefreshLure()
  W.RefreshCatch(cdb)
end

function W.CombatWarning(on)
  if not f or not f.ready then return end
  hintFs:SetText(on and L.COMBAT_WARN or L.HINT)
  if on then hintFs:SetTextColor(0.7, 0.12, 0.08) else hintFs:SetTextColor(FADED[1], FADED[2], FADED[3]) end
end

-- Ringene til testene
function W.Rings() return rings end

------------------------------------------------------------------------
-- Vise og skjule (køes i kamp)
------------------------------------------------------------------------

function W.Show()
  if not f or not f.ready then return end
  if Game.InCombat() then ns.Queue("window", true) return end
  f:Show()
end

function W.Hide()
  if not f then return end
  if Game.InCombat() then ns.Queue("window", false) return end
  f:Hide()
end

function W.IsShown() return f and f:IsShown() end
