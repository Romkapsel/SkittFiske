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

-- Daniels røde knapper (art/knapper.png → Media/btn_*.tga, art/skilt.png → Media/lbl_*.tga). tex = filnavnet uten .tga
function ns.IconButton(parent, tex, w, h, tip, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, h)
  b.iconName = tex
  b.tex = b:CreateTexture(nil, "ARTWORK")
  b.tex:SetAllPoints()
  b.tex:SetTexture(M .. tex .. ".tga")
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetTexture(M .. tex .. ".tga")
  hl:SetBlendMode("ADD")
  hl:SetAlpha(0.3)
  b:RegisterForClicks("LeftButtonUp")
  b:SetScript("OnClick", onClick)
  b:SetScript("OnMouseDown", function(self) self.tex:SetVertexColor(0.75, 0.75, 0.75) end)
  b:SetScript("OnMouseUp", function(self) self.tex:SetVertexColor(1, 1, 1) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(tip, 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

------------------------------------------------------------------------
-- Mål (Daniel 7. okt: vannrett – skill øverst, Stang og Agn under, så et felt med fangst og inntjening)
------------------------------------------------------------------------

local LAYOUT = {
  crop = { 168, 856 },
  title = 104, zone = 144,
  bar = { 358, 166, 300, 28 },           -- x, y, bredde, høyde (der streken var)
  summary = 208, value = 226, rows = 250, rowStep = 19,
  list = { 364, 288 },                   -- fangstlinjene: x, bredde
  line2 = 334, lineX = 528,              -- Stang, Agn og ringene: y, midten av linja
  pole = 92, lure = 124,                -- bredden på Stang- og Agn-plassen
  rings = { 323, 44, 48 },               -- y, størrelse, avstand
  warn = 386,
  report = { 712, 430, 54, 27 },          -- midt på den glatte delen av treplata (x 660–800, y 428–458)
  close = { 738, 94, 44, 22 },
  drop = 380,                            -- bredden på nedtrekket fra området
}
local S = 0.8 -- enheter per piksel i frame.tga
local CROP_W = LAYOUT.crop[2] - LAYOUT.crop[1]
local WIN_W, WIN_H = CROP_W * S, 512 * S
local RINGS, ROWS, DROP_ROWS = 3, 3, 10
local CENTER_X = 508 -- alt midtstilt under tittelen, litt til venstre for midten av pergamentet (Daniel)

local function px(v) return v * S end
local function X(v) return (v - LAYOUT.crop[1]) * S end
local function at(region, x, y, point)
  region:ClearAllPoints()
  region:SetPoint(point or "TOPLEFT", region:GetParent(), "TOPLEFT", X(x), -px(y))
end

local f, drop, zoneFs, warnFs, summaryFs, valueFs, emptyFs, barFill, barText, noLureFs
local checks, rings, rows, dropRows = {}, {}, {}, {}
local lures = {}
local isLure = {} -- item-ID → om det er agn (tooltipen sjekkes én gang per ting)
local pulses = {}

local function macroFor(id) return ("/use item:%d\n/use %d"):format(id, Data.MAIN_HAND) end
local function hideTip() GameTooltip:Hide() end

------------------------------------------------------------------------
-- Bygging
------------------------------------------------------------------------

local function makeRing(i)
  local r = LAYOUT.rings
  local size = px(r[2])
  local b = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
  b:SetSize(size, size)
  at(b, LAYOUT.lineX, r[1]) -- plassen settes av W.LayoutLine
  b:RegisterForClicks(Game.ClickMode()) -- bare én av dem, ellers brukes agnet to ganger
  b:SetAttribute("type", "macro")
  b.glow = b:CreateTexture(nil, "BACKGROUND")
  b.glow:SetPoint("TOPLEFT", -px(5), px(5))
  b.glow:SetPoint("BOTTOMRIGHT", px(5), -px(5))
  b.glow:SetTexture(M .. "mask_circle.tga")
  b.glow:SetVertexColor(1, 0.75, 0.2)
  b.glow:Hide()
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", px(5), -px(5))
  b.icon:SetPoint("BOTTOMRIGHT", -px(5), px(5))
  ns.Safe("ringmaske", function()
    local mask = b:CreateMaskTexture()
    mask:SetAllPoints(b.icon)
    mask:SetTexture(M .. "mask_circle.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    b.icon:AddMaskTexture(mask)
  end)
  b.ring = b:CreateTexture(nil, "OVERLAY")
  b.ring:SetAllPoints()
  b.ring:SetTexture(M .. "ring.tga")
  b.count = ns.Text(b, "GameFontNormalSmall", { 1, 1, 1 }, 10, nil, true)
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

local function makeCheck(label)
  local c = {}
  c.box = f:CreateTexture(nil, "ARTWORK")
  c.box:SetSize(px(23), px(23))
  c.box:SetTexture(M .. "box.tga")
  c.mark = f:CreateTexture(nil, "OVERLAY")
  c.mark:SetSize(px(23), px(23))
  c.text = ns.Text(f, "GameFontNormalSmall", INK, 14)
  c.text:SetText(label)
  return c
end

local function placeCheck(c, x)
  local y = LAYOUT.line2
  at(c.box, x, y)
  at(c.mark, x, y)
  at(c.text, x + 29, y + 4)
end

-- Stang, Agn og ringene sentrert på én linje; flyttes bare utenfor kamp (ringene er sikre knapper)
function W.LayoutLine(n)
  local L2 = LAYOUT
  local total = L2.pole + L2.lure + math.max(n, 0) * L2.rings[3]
  local x = L2.lineX - total / 2
  placeCheck(checks.pole, x)
  placeCheck(checks.lure, x + L2.pole)
  local rx = x + L2.pole + L2.lure
  for i, b in ipairs(rings) do at(b, rx + (i - 1) * L2.rings[3], L2.rings[1]) end
  at(noLureFs, rx, L2.line2 + 5)
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
  title:SetPoint("TOP", f, "TOPLEFT", X(CENTER_X), -px(LAYOUT.title))
  title:SetText(L.TITLE)
  zoneFs = ns.Text(f, "GameFontNormalSmall", FADED, 10)
  zoneFs:SetPoint("TOP", f, "TOPLEFT", X(CENTER_X), -px(LAYOUT.zone))
  -- Nedtrekk fra området: klikk på navnet (eller pila) for fisken som er fanget her
  local zoneHit = CreateFrame("Button", nil, f)
  zoneHit:SetPoint("TOPLEFT", zoneFs, "TOPLEFT", -px(6), px(3))
  zoneHit:SetPoint("BOTTOMRIGHT", zoneFs, "BOTTOMRIGHT", px(22), -px(3))
  zoneHit:RegisterForClicks("LeftButtonUp")
  zoneHit:SetScript("OnClick", function() W.ToggleDrop() end)
  zoneHit:SetScript("OnEnter", function(self)
    zoneFs:SetTextColor(HEAD[1], HEAD[2], HEAD[3])
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L.DROP_TIP, 1, 1, 1)
    GameTooltip:Show()
  end)
  zoneHit:SetScript("OnLeave", function() zoneFs:SetTextColor(FADED[1], FADED[2], FADED[3]) hideTip() end)
  local arrow = f:CreateTexture(nil, "OVERLAY")
  arrow:SetSize(px(14), px(14))
  arrow:SetPoint("LEFT", zoneFs, "RIGHT", px(4), 0)
  arrow:SetTexture(M .. "arrow_down.tga")

  local c = LAYOUT.close
  at(ns.IconButton(f, "btn_close", px(c[3]), px(c[4]), L.BTN_DONE, function() ns.Stop() end), c[1], c[2]) -- vinduet åpent = du fisker

  -- 1) Fiskeskill øverst, bred stolpe
  local bx, by, bw, bh = unpack(LAYOUT.bar)
  local barBg = f:CreateTexture(nil, "ARTWORK")
  barBg:SetPoint("TOPLEFT", f, "TOPLEFT", X(bx + 4), -px(by + 4))
  barBg:SetSize(px(bw - 8), px(bh - 8))
  barBg:SetColorTexture(0.24, 0.17, 0.12, 0.95)
  barFill = f:CreateTexture(nil, "ARTWORK", nil, 1)
  barFill:SetPoint("TOPLEFT", barBg, "TOPLEFT")
  barFill:SetHeight(px(bh - 8))
  barFill:SetColorTexture(0.34, 0.55, 0.24, 1)
  barFill.full = px(bw - 8)
  local barFrame = f:CreateTexture(nil, "OVERLAY")
  barFrame:SetPoint("TOPLEFT", f, "TOPLEFT", X(bx), -px(by))
  barFrame:SetSize(px(bw), px(bh))
  barFrame:SetTexture(M .. "bar_frame.tga")
  barText = ns.Text(f, "GameFontNormalSmall", { 1, 0.98, 0.92 }, 12, nil, true)
  barText:SetPoint("CENTER", barBg, "CENTER", 0, 0)

  -- 2) Stang og Agn, og agn-ringene på samme linje
  checks.pole = makeCheck(L.CHECK_POLE)
  checks.lure = makeCheck(L.CHECK_LURE)
  for i = 1, RINGS do rings[i] = makeRing(i) end
  noLureFs = ns.Text(f, "GameFontNormalSmall", FADED, 11)
  noLureFs:SetText(L.LURE_NONE_IN_BAGS)
  W.LayoutLine(0)

  -- 3) Feltet: fanget, kast, verdi og fangsten med verdi per fisk – oppdateres mens du fisker
  summaryFs = ns.Text(f, "GameFontNormalSmall", FADED, 11)
  summaryFs:SetPoint("TOP", f, "TOPLEFT", X(CENTER_X), -px(LAYOUT.summary))
  valueFs = ns.Text(f, "GameFontNormal", HEAD, 13)
  valueFs:SetPoint("TOP", f, "TOPLEFT", X(CENTER_X), -px(LAYOUT.value))
  emptyFs = ns.Text(f, "GameFontNormalSmall", FADED, 11)
  emptyFs:SetPoint("TOP", f, "TOPLEFT", X(CENTER_X), -px(LAYOUT.rows + 4))
  emptyFs:SetText(L.CATCH_EMPTY)
  local x0, w = unpack(LAYOUT.list)
  for i = 1, ROWS do
    local r = {}
    local y = LAYOUT.rows + (i - 1) * LAYOUT.rowStep
    r.icon = f:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(px(16), px(16))
    at(r.icon, x0 + 10, y)
    r.text = ns.Text(f, "GameFontNormalSmall", INK, 11)
    at(r.text, x0 + 32, y + 2)
    r.text:SetWidth(px(w - 120))
    r.text:SetJustifyH("LEFT")
    if r.text.SetWordWrap then r.text:SetWordWrap(false) end
    r.value = ns.Text(f, "GameFontNormalSmall", HEAD, 11)
    r.value:SetPoint("TOPRIGHT", f, "TOPLEFT", X(x0 + w - 10), -px(y + 2))
    r.value:SetJustifyH("RIGHT")
    rows[i] = r
  end

  -- Nederst: kampvarsel (ellers tomt). På treplata: Rapport.
  warnFs = ns.Text(f, "GameFontNormalSmall", { 0.7, 0.12, 0.08 }, 11)
  warnFs:SetPoint("TOP", f, "TOPLEFT", X(CENTER_X), -px(LAYOUT.warn))
  local rp = LAYOUT.report
  at(ns.IconButton(f, "lbl_rapport", px(rp[3]), px(rp[4]), L.BTN_REPORT, function() ns.Report.Show(1) end), rp[1], rp[2])

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

  ns.Safe("nedtrekk", W.CreateDrop)

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
  W.RefreshDrop()
  -- Stang på?
  local id = Game.Equipped(Data.MAIN_HAND)
  local class, subClass
  if id then
    local _
    _, class, subClass = Game.ItemInstant(id)
  end
  setCheck(checks.pole, class == Data.POLE_CLASS and subClass == Data.POLE_SUBCLASS)
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
  -- Uten agn i baggen tar teksten plassen til omtrent tre ringer
  W.LayoutLine(#lures == 0 and 3 or math.min(#lures, RINGS))
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

-- Feltet: regnes som rapporten (samme priser), så tallene her og i rapporten er like
function W.RefreshCatch(cdb)
  if not f or not f.ready then return end
  W.RefreshDrop()
  local s = cdb.session
  local r = s and Logic.Report(s, Game.Clock(), ns.Session.Price) or nil
  local items = r and r.items or {}
  local st = L.SUMMARY:format(r and r.caught or 0, r and r.casts or 0)
  if r and r.escaped > 0 then st = st .. L.STATS_ESCAPED:format(r.escaped) end
  summaryFs:SetText(st)
  if r and r.total > 0 then
    valueFs:SetText(L.VALUE_LINE:format(Logic.Coins(r.total)) .. (r.perHour and L.PER_HOUR:format(Logic.Coins(r.perHour)) or ""))
  else
    valueFs:SetText(L.VALUE_NONE)
  end
  emptyFs:SetShown(#items == 0)
  for i, row in ipairs(rows) do
    local it = items[i]
    if i == ROWS and #items > ROWS then
      local rest = 0
      for k = ROWS, #items do rest = rest + (items[k].value or 0) end
      row.icon:Hide()
      row.text:SetText(L.MORE:format(#items - ROWS + 1))
      row.text:SetTextColor(FADED[1], FADED[2], FADED[3])
      row.value:SetText(rest > 0 and Logic.Coins(rest) or "")
      row.text:Show() row.value:Show()
    elseif it then
      row.icon:SetTexture(Game.ItemIcon(it.id))
      row.icon:Show()
      row.text:SetText(L.CATCH_ROW:format(it.n, it.name or Game.ItemName(it.id) or ("#" .. it.id)))
      row.text:SetTextColor(INK[1], INK[2], INK[3])
      row.value:SetText(it.value and Logic.Coins(it.value) or "")
      row.text:Show() row.value:Show()
    else
      row.icon:Hide() row.text:Hide() row.value:Hide()
    end
  end
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
  warnFs:SetText(on and L.COMBAT_WARN or "")
end

------------------------------------------------------------------------
-- Nedtrekket: fisken som er fanget i området du står i (fra SkittFiskeDB.zones – alle dine karakterer)
------------------------------------------------------------------------

-- Nesten svart med gul tekst og litt større skrift (Daniel 7. okt)
local DROP_GOLD = { 1, 0.82, 0 }
local DROP_LIGHT = { 1, 0.95, 0.75 }
local DROP_DIM = { 0.62, 0.6, 0.55 }
local DROP_ROW = 24
local DROP_TOP = 82 -- første fiskelinje under overskrift, skill og sjanse

function W.CreateDrop()
  local w = LAYOUT.drop
  drop = CreateFrame("Frame", nil, f)
  drop:SetFrameLevel((f:GetFrameLevel() or 1) + 20)
  drop:SetSize(px(w), 40)
  drop:SetPoint("TOP", zoneFs, "BOTTOM", 0, -px(6))
  drop:EnableMouse(true)
  local edge = drop:CreateTexture(nil, "BORDER")
  edge:SetAllPoints()
  edge:SetColorTexture(0.55, 0.42, 0.18, 1)
  local bg = drop:CreateTexture(nil, "BACKGROUND", nil, 1)
  bg:SetPoint("TOPLEFT", 1, -1)
  bg:SetPoint("BOTTOMRIGHT", -1, 1)
  bg:SetColorTexture(0.05, 0.04, 0.03, 0.96)
  edge:SetDrawLayer("BACKGROUND", 0)
  drop.head = ns.Text(drop, "GameFontNormal", DROP_GOLD, 14, nil, true)
  drop.head:SetPoint("TOP", 0, -px(10))
  drop.empty = ns.Text(drop, "GameFontNormalSmall", DROP_DIM, 13)
  -- Skill: hva området krever, og din sjanse nå (med utstyr og agn)
  drop.skill = ns.Text(drop, "GameFontNormalSmall", DROP_LIGHT, 12, nil, true)
  drop.skill:SetPoint("TOP", drop.head, "BOTTOM", 0, -px(5))
  drop.chance = ns.Text(drop, "GameFontNormalSmall", DROP_LIGHT, 12, nil, true)
  drop.chance:SetPoint("TOP", drop.skill, "BOTTOM", 0, -px(3))
  drop.empty:SetPoint("TOP", drop.chance, "BOTTOM", 0, -px(8))
  drop.empty:SetWidth(px(w - 28))
  drop.empty:SetText(L.DROP_EMPTY)
  for i = 1, DROP_ROWS do
    local r = {}
    local y = -px(DROP_TOP + (i - 1) * DROP_ROW)
    r.icon = drop:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(px(20), px(20))
    r.icon:SetPoint("TOPLEFT", px(12), y)
    r.text = ns.Text(drop, "GameFontNormal", DROP_GOLD, 13, nil, true)
    r.text:SetPoint("TOPLEFT", px(40), y - px(3))
    r.text:SetWidth(px(w - 40 - 100))
    r.text:SetJustifyH("LEFT")
    if r.text.SetWordWrap then r.text:SetWordWrap(false) end
    r.mark = drop:CreateTexture(nil, "OVERLAY")
    r.mark:SetSize(px(18), px(18))
    r.mark:SetPoint("TOPLEFT", px(w - 92), y - px(1))
    r.mark:SetTexture(M .. "check.tga")
    r.pct = ns.Text(drop, "GameFontNormal", DROP_LIGHT, 13, nil, true)
    r.pct:SetPoint("TOPRIGHT", -px(12), y - px(3))
    dropRows[i] = r
  end
  drop:Hide()
end

function W.RefreshDrop()
  if not drop or not drop:IsShown() and not drop.opening then return end
  local z, sub = Game.Zone()
  local data = ns.FishData
  local list = Logic.AreaFish(data and data.zones, ns.db and ns.db.zones or {}, z, sub)
  drop.head:SetText(L.DROP_HERE:format((sub ~= "" and sub) or z))
  local base = Logic.ZoneSkill(data and data.skill, z, sub)
  local need = Logic.SkillNeeds(base)
  if need then
    drop.skill:SetText(L.DROP_SKILL:format(need.min, need.full))
    local rank, _, mod = Game.Skill()
    local chance = Logic.CatchChance(rank and (rank + (mod or 0)), base)
    if chance == nil then
      drop.chance:SetText("")
    elseif chance == 0 then
      drop.chance:SetText(L.DROP_CHANCE_NONE)
      drop.chance:SetTextColor(1, 0.35, 0.3)
    else
      drop.chance:SetText(L.DROP_CHANCE:format(Logic.Pct(chance)))
      if chance >= 1 then drop.chance:SetTextColor(0.45, 0.9, 0.45)
      elseif chance >= 0.75 then drop.chance:SetTextColor(1, 0.82, 0)
      else drop.chance:SetTextColor(1, 0.5, 0.3) end
    end
  else
    drop.skill:SetText("")
    drop.chance:SetText("")
  end
  drop.empty:SetShown(#list == 0)
  for i, r in ipairs(dropRows) do
    local it = list[i]
    if it then
      r.icon:SetTexture(Game.ItemIcon(it.id))
      r.text:SetText(Game.ItemName(it.id) or (data and data.names[it.id]) or ("#" .. it.id))
      r.pct:SetText(Logic.Pct(it.pct))
      local c = it.own and DROP_DIM or DROP_LIGHT
      r.pct:SetTextColor(c[1], c[2], c[3])
      r.mark:SetShown(it.caught ~= nil)
      r.icon:Show() r.text:Show() r.pct:Show()
    else
      r.icon:Hide() r.text:Hide() r.pct:Hide() r.mark:Hide()
    end
  end
  local n = math.min(#list, DROP_ROWS)
  drop:SetHeight(px(n > 0 and (DROP_TOP + 8 + n * DROP_ROW) or (DROP_TOP + 30)))
end

function W.ToggleDrop()
  if not drop then return end
  if drop:IsShown() then drop:Hide() return end
  drop.opening = true
  W.RefreshDrop()
  drop.opening = nil
  drop:Show()
end

function W.DropShown() return drop and drop:IsShown() end

-- Til testene
function W.Rings() return rings end
function W.Rows() return rows end
function W.Texts() return { summary = summaryFs, value = valueFs } end

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
  if drop then drop:Hide() end
  f:Hide()
end

function W.IsShown() return f and f:IsShown() end
