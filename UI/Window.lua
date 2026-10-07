-- Fiskevinduet: en fisk av treverk med vann i midten (Daniels forbilde 7. okt). Skjult til du starter å fiske.
-- Agn-ringene er sikre knapper, så vinduet kan ikke vises, skjules, skaleres eller flyttes i kamp (det køes).
-- Bildene tegnes av tools/render_media.py; plasseringene i LAYOUT er piksler i Media/frame.tga (1024 × 512).
local addonName, ns = ...
local W = {}
ns.Window = W
local Data, Logic, Game, L = ns.Data, ns.Logic, ns.Game, ns.L

ns.MEDIA = "Interface\\AddOns\\SkittFiske\\Media\\"
local M = ns.MEDIA
local FONT_TITLE, FONT_TEXT = "Fonts\\MORPHEUS.TTF", "Fonts\\FRIZQT__.TTF"
local GOLD = { 0.93, 0.77, 0.36 }
local PLAQUE_TEXT = { 0.94, 0.85, 0.55 }
local LIGHT = { 0.96, 0.94, 0.88 }
local DIM = { 0.75, 0.84, 0.84 }

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
function ns.Text(parent, font, r, g, b, size, path)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  local ok = size and fs:SetFont(path or FONT_TEXT, size, "")
  if not ok then fs:SetFontObject(_G[font] or GameFontNormal) end
  if fs.SetShadowOffset then fs:SetShadowOffset(1, -1) end
  if r then fs:SetTextColor(r, g, b) end
  return fs
end

-- Knapp med det røde bildet (Media/button.tga)
function ns.RedButton(parent, text, w, h, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, h)
  local bg = b:CreateTexture(nil, "ARTWORK")
  bg:SetAllPoints()
  bg:SetTexture(M .. "button.tga")
  bg:SetTexCoord(0, 0.75, 0, 0.75) -- 192 × 48 av 256 × 64
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetTexture(M .. "button.tga")
  hl:SetTexCoord(0, 0.75, 0, 0.75)
  hl:SetBlendMode("ADD")
  hl:SetAlpha(0.35)
  b.label = ns.Text(b, "GameFontNormalSmall", PLAQUE_TEXT[1], PLAQUE_TEXT[2], PLAQUE_TEXT[3], math.max(9, math.floor(h * 0.5)))
  b.label:SetPoint("CENTER", 0, 1)
  b.label:SetText(text)
  b:RegisterForClicks("LeftButtonUp")
  b:SetScript("OnClick", onClick)
  return b
end
ns.TextButton = function(parent, text, w, onClick) return ns.RedButton(parent, text, w, 22, onClick) end

function ns.CloseButton(parent, onClick, size)
  local b = ns.RedButton(parent, "X", size or 20, size or 20, onClick)
  b:SetPoint("TOPRIGHT", -6, -6)
  return b
end

-- Grønt skilt med gullkant og tekst (Media/plaque.tga)
function ns.Plaque(parent, text, w, h)
  local p = CreateFrame("Frame", nil, parent)
  p:SetSize(w, h)
  local t = p:CreateTexture(nil, "ARTWORK")
  t:SetAllPoints()
  t:SetTexture(M .. "plaque.tga")
  t:SetTexCoord(0, 1, 0, 0.75) -- 256 × 48 av 256 × 64
  p.label = ns.Text(p, "GameFontNormalSmall", PLAQUE_TEXT[1], PLAQUE_TEXT[2], PLAQUE_TEXT[3], math.max(10, math.floor(h * 0.42)))
  p.label:SetPoint("CENTER", 0, 1)
  p.label:SetText(text)
  return p
end

------------------------------------------------------------------------
-- Mål
------------------------------------------------------------------------

local TEX_W, TEX_H = 1024, 512
local WIN_W = 720
local S = WIN_W / TEX_W
local WIN_H = TEX_H * S
local LAYOUT = {
  title = 104, zone = 146, left = 290, right = 545, col = 220,
  plaque1 = 172, plaque2 = 284, checks = 212, checkStep = 24,
  rings = 322, ringStep = 62, ring = 56, caught = 212, bar = 236, stats = 268,
  rows = 322, rowStep = 19, hint = 432, buttons = 600, buttonStep = 108, buttonY = 426, close = { 772, 74 },
}
local RINGS, ROWS = 4, 4

local function px(v) return v * S end
local function at(region, x, y, point)
  region:ClearAllPoints()
  region:SetPoint(point or "TOPLEFT", region.anchorTo or region:GetParent(), "TOPLEFT", px(x), -px(y))
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

local function makeRing(i)
  local size = px(LAYOUT.ring)
  local b = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
  b:SetSize(size, size)
  at(b, LAYOUT.left + 10 + (i - 1) * LAYOUT.ringStep, LAYOUT.rings)
  b:RegisterForClicks(Game.ClickMode()) -- bare én av dem, ellers brukes agnet to ganger
  b:SetAttribute("type", "macro")
  b.glow = b:CreateTexture(nil, "BACKGROUND")
  b.glow:SetPoint("TOPLEFT", -px(6), px(6))
  b.glow:SetPoint("BOTTOMRIGHT", px(6), -px(6))
  b.glow:SetTexture(M .. "mask_circle.tga")
  b.glow:SetVertexColor(1, 0.8, 0.2)
  b.glow:Hide()
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", px(8), -px(8))
  b.icon:SetPoint("BOTTOMRIGHT", -px(8), px(8))
  ns.Safe("ringmaske", function()
    local mask = b:CreateMaskTexture()
    mask:SetAllPoints(b.icon)
    mask:SetTexture(M .. "mask_circle.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    b.icon:AddMaskTexture(mask)
  end)
  b.ring = b:CreateTexture(nil, "OVERLAY")
  b.ring:SetAllPoints()
  b.ring:SetTexture(M .. "ring.tga")
  b.count = ns.Text(b, "GameFontNormalSmall", 1, 1, 1, 12)
  b.count:SetPoint("BOTTOMRIGHT", -px(2), px(4))
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
  local y = LAYOUT.checks + (i - 1) * LAYOUT.checkStep
  local c = {}
  c.box = f:CreateTexture(nil, "ARTWORK")
  c.box:SetSize(px(22), px(22))
  at(c.box, LAYOUT.left + 6, y)
  c.box:SetTexture(M .. "box.tga")
  c.mark = f:CreateTexture(nil, "OVERLAY")
  c.mark:SetSize(px(22), px(22))
  at(c.mark, LAYOUT.left + 6, y)
  c.text = ns.Text(f, "GameFontNormalSmall", LIGHT[1], LIGHT[2], LIGHT[3], 12)
  at(c.text, LAYOUT.left + 36, y + 3)
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
  f:SetScale(cdb.scale or 0.85)
  local p = cdb.window
  if p and p.x then f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p.x, p.y)
  else f:SetPoint("CENTER", UIParent, "CENTER", 200, -60) end
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
    local s = math.max(0.5, math.min(1.3, (cdb.scale or 0.85) + delta * 0.05))
    cdb.scale = s
    self:SetScale(s)
  end)

  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture(M .. "frame.tga")

  local title = ns.Text(f, "GameFontNormalLarge", GOLD[1], GOLD[2], GOLD[3], 24, FONT_TITLE)
  title:SetPoint("TOP", f, "TOPLEFT", px(535), -px(LAYOUT.title))
  title:SetText(L.TITLE)
  zoneFs = ns.Text(f, "GameFontNormalSmall", DIM[1], DIM[2], DIM[3], 11)
  zoneFs:SetPoint("TOP", f, "TOPLEFT", px(535), -px(LAYOUT.zone))

  local close = ns.RedButton(f, "X", px(24), px(24), function() ns.Stop() end) -- vinduet åpent = du fisker
  at(close, LAYOUT.close[1], LAYOUT.close[2])

  -- Venstre: Klar og Agn
  local pw, ph = px(LAYOUT.col), px(34)
  at(ns.Plaque(f, L.PLAQUE_READY, pw, ph), LAYOUT.left, LAYOUT.plaque1)
  checks.pole = makeCheck(1, L.CHECK_POLE)
  checks.lure = makeCheck(2, L.CHECK_LURE)
  checks.sound = makeCheck(3, L.CHECK_SOUND)
  at(ns.Plaque(f, L.PLAQUE_LURE, pw, ph), LAYOUT.left, LAYOUT.plaque2)
  for i = 1, RINGS do rings[i] = makeRing(i) end
  noLureFs = ns.Text(f, "GameFontNormalSmall", DIM[1], DIM[2], DIM[3], 11)
  at(noLureFs, LAYOUT.left + 10, LAYOUT.rings + 18)
  noLureFs:SetText(L.LURE_NONE_IN_BAGS)

  -- Høyre: Fiske og Fangst
  local R = LAYOUT.right
  at(ns.Plaque(f, L.PLAQUE_SKILL, pw, ph), R, LAYOUT.plaque1)
  local lbl = ns.Text(f, "GameFontNormalSmall", LIGHT[1], LIGHT[2], LIGHT[3], 12)
  at(lbl, R + 11, LAYOUT.caught)
  lbl:SetText(L.CAUGHT)
  caughtFs = ns.Text(f, "GameFontNormal", GOLD[1], GOLD[2], GOLD[3], 13)
  caughtFs:SetPoint("TOPRIGHT", f, "TOPLEFT", px(R + LAYOUT.col - 14), -px(LAYOUT.caught - 1))

  local barBg = f:CreateTexture(nil, "ARTWORK")
  barBg:SetPoint("TOPLEFT", f, "TOPLEFT", px(R + 4), -px(LAYOUT.bar + 4))
  barBg:SetSize(px(LAYOUT.col - 8), px(18))
  barBg:SetColorTexture(0.08, 0.12, 0.12, 0.9)
  barFill = f:CreateTexture(nil, "ARTWORK", nil, 1)
  barFill:SetPoint("TOPLEFT", barBg, "TOPLEFT")
  barFill:SetHeight(px(18))
  barFill:SetColorTexture(0.31, 0.63, 0.27, 1)
  barFill.full = px(LAYOUT.col - 8)
  local barFrame = f:CreateTexture(nil, "OVERLAY")
  barFrame:SetPoint("TOPLEFT", f, "TOPLEFT", px(R), -px(LAYOUT.bar))
  barFrame:SetSize(pw, px(26))
  barFrame:SetTexture(M .. "bar_frame.tga")
  barText = ns.Text(f, "GameFontNormalSmall", 1, 1, 1, 11)
  barText:SetPoint("CENTER", barBg, "CENTER", 0, 0)

  statsFs = ns.Text(f, "GameFontNormalSmall", DIM[1], DIM[2], DIM[3], 11)
  at(statsFs, R + 11, LAYOUT.stats)

  at(ns.Plaque(f, L.PLAQUE_CATCH, pw, ph), R, LAYOUT.plaque2)
  for i = 1, ROWS do
    local r = {}
    local y = LAYOUT.rows + (i - 1) * LAYOUT.rowStep
    r.icon = f:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(px(16), px(16))
    at(r.icon, R + 11, y + 1)
    r.text = ns.Text(f, "GameFontNormalSmall", LIGHT[1], LIGHT[2], LIGHT[3], 11)
    at(r.text, R + 33, y + 2)
    r.text:SetWidth(px(LAYOUT.col - 50))
    r.text:SetJustifyH("LEFT")
    if r.text.SetWordWrap then r.text:SetWordWrap(false) end
    rows[i] = r
  end

  -- Bunnen: hjelp (eller kampvarsel) og knappene
  hintFs = ns.Text(f, "GameFontNormalSmall", 0.92, 0.84, 0.67, 11)
  at(hintFs, LAYOUT.left + 10, LAYOUT.hint)
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
  local bw, bh = px(110), px(30)
  at(ns.RedButton(f, L.BTN_REPORT, bw, bh, function() ns.Report.Show(1) end), LAYOUT.buttons, LAYOUT.buttonY)
  at(ns.RedButton(f, L.BTN_DONE, bw, bh, function() ns.Stop() end), LAYOUT.buttons + LAYOUT.buttonStep, LAYOUT.buttonY)

  -- Lys som pulserer når noe mangler (agn-ringene og krysset ved Agn)
  ns.Safe("glow", function()
    for _, region in ipairs({ checks.lure.mark, rings[1].glow, rings[2].glow, rings[3].glow, rings[4].glow }) do
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
    local text = L.BAR:format(rank, max or rank) .. (((mod or 0) > 0) and ("  +" .. mod) or "")
    barText:SetText(text)
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
  local _, class, subClass = nil, nil, nil
  if id then _, class, subClass = Game.ItemInstant(id) end
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
      r.text:SetTextColor(DIM[1], DIM[2], DIM[3])
      r.text:Show()
    elseif id then
      r.icon:SetTexture(Game.ItemIcon(id))
      r.icon:Show()
      r.text:SetText(L.CATCH_ROW:format(s.items[id], s.names[id] or Game.ItemName(id) or ("#" .. id)))
      r.text:SetTextColor(LIGHT[1], LIGHT[2], LIGHT[3])
      r.text:Show()
    elseif i == 1 then
      r.icon:Hide()
      r.text:SetText(L.CATCH_EMPTY)
      r.text:SetTextColor(DIM[1], DIM[2], DIM[3])
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
  if on then hintFs:SetTextColor(1, 0.35, 0.3) else hintFs:SetTextColor(0.92, 0.84, 0.67) end
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
