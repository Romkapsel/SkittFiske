-- Fangstrapporten: vises når du avslutter, og /skitt rapport viser de siste (bla med pilene)
local addonName, ns = ...
local R = {}
ns.Report = R
local Logic, Game, L = ns.Logic, ns.Game, ns.L

local WIDTH = 330
local f, sub, pageFs, prevBtn, nextBtn
local pool = {}
local page = 1

local function row(i)
  local r = pool[i]
  if r then return r end
  r = {}
  r.icon = f:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(16, 16)
  r.left = ns.Text(f, "GameFontNormalSmall", ns.INK, 12)
  r.left:SetJustifyH("LEFT")
  r.right = ns.Text(f, "GameFontNormalSmall", ns.INK, 12)
  r.right:SetJustifyH("RIGHT")
  pool[i] = r
  return r
end

-- Treplata med pergament (Media/panel.tga) i ni deler, så den kan bli så høy som rapporten trenger
local function panel(frame)
  local C, T = 34, 48 / 256
  local cells = {
    { "TOPLEFT", 0, T, 0, T }, { "TOP", T, 1 - T, 0, T }, { "TOPRIGHT", 1 - T, 1, 0, T },
    { "LEFT", 0, T, T, 1 - T }, { "CENTER", T, 1 - T, T, 1 - T }, { "RIGHT", 1 - T, 1, T, 1 - T },
    { "BOTTOMLEFT", 0, T, 1 - T, 1 }, { "BOTTOM", T, 1 - T, 1 - T, 1 }, { "BOTTOMRIGHT", 1 - T, 1, 1 - T, 1 },
  }
  for _, c in ipairs(cells) do
    local t = frame:CreateTexture(nil, "BACKGROUND")
    t:SetTexture(ns.MEDIA .. "panel.tga")
    t:SetTexCoord(c[2], c[3], c[4], c[5])
    local p = c[1]
    local left, right = p:find("LEFT"), p:find("RIGHT")
    local top, bottom = p:find("TOP"), p:find("BOTTOM")
    if left then t:SetPoint("LEFT", 0, 0) t:SetWidth(C) elseif right then t:SetPoint("RIGHT", 0, 0) t:SetWidth(C)
    else t:SetPoint("LEFT", C, 0) t:SetPoint("RIGHT", -C, 0) end
    if top then t:SetPoint("TOP", 0, 0) t:SetHeight(C) elseif bottom then t:SetPoint("BOTTOM", 0, 0) t:SetHeight(C)
    else t:SetPoint("TOP", 0, -C) t:SetPoint("BOTTOM", 0, C) end
  end
end

local function create()
  f = CreateFrame("Frame", "SkittFiskeReport", UIParent)
  f:Hide()
  f:SetSize(WIDTH, 200)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  panel(f)
  if UISpecialFrames then table.insert(UISpecialFrames, "SkittFiskeReport") end -- Esc lukker

  local title = ns.Text(f, "GameFontNormalLarge", ns.HEAD, 22, ns.FONT_TITLE)
  title:SetPoint("TOP", 0, -26)
  title:SetText(L.REPORT_TITLE)
  sub = ns.Text(f, "GameFontNormalSmall", ns.FADED, 10)
  sub:SetPoint("TOP", title, "BOTTOM", 0, -3)

  local close = ns.IconButton(f, "btn_close", 36, 18, L.REPORT_CLOSE, function() f:Hide() end)
  close:SetPoint("TOPRIGHT", -8, -8)

  local done = ns.IconButton(f, "btn_ok", 52, 26, L.REPORT_CLOSE, function() f:Hide() end)
  done:SetPoint("BOTTOMRIGHT", -30, 26)
  prevBtn = ns.IconButton(f, "btn_prev", 44, 22, L.REPORT_OLDER, function() R.Show(page + 1) end)
  prevBtn:SetPoint("BOTTOMLEFT", 30, 28)
  nextBtn = ns.IconButton(f, "btn_next", 44, 22, L.REPORT_NEWER, function() R.Show(page - 1) end)
  nextBtn:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
  pageFs = ns.Text(f, "GameFontNormalSmall", ns.FADED, 10)
  pageFs:SetPoint("LEFT", nextBtn, "RIGHT", 8, 0)
end

-- Linjene i rapporten: { left, right, icon, color, small }
function R.Lines(r)
  local out = {}
  local function kv(k, v, color) out[#out + 1] = { left = k, right = v, color = color } end
  kv(L.REPORT_TIME, Logic.Duration(r.secs, L))
  kv(L.REPORT_CASTS, tostring(r.casts or 0))
  kv(L.REPORT_CAUGHT, tostring(r.caught or 0))
  if (r.escaped or 0) > 0 then kv(L.REPORT_ESCAPED, tostring(r.escaped), { 0.62, 0.14, 0.07 }) end
  if (r.missed or 0) > 0 then kv(L.REPORT_MISSED, tostring(r.missed)) end
  if r.skillFrom and r.skillTo then
    kv(L.REPORT_SKILL, L.REPORT_SKILL_VALUE:format(r.skillFrom, r.skillTo, r.skillTo - r.skillFrom))
  end
  out[#out + 1] = { gap = true }
  if #r.items == 0 and (r.money or 0) == 0 then
    out[#out + 1] = { left = L.REPORT_NOTHING, small = true }
  end
  for _, it in ipairs(r.items) do
    out[#out + 1] = { icon = Game.ItemIcon(it.id), left = L.CATCH_ROW:format(it.n, it.name or Game.ItemName(it.id) or ("#" .. it.id)),
                      right = it.value and Logic.Coins(it.value) or "" }
  end
  if (r.money or 0) > 0 then kv(L.REPORT_MONEY, Logic.Coins(r.money)) end
  if (r.total or 0) > 0 then
    out[#out + 1] = { gap = true }
    kv(L.REPORT_VALUE, Logic.Coins(r.total), ns.HEAD)
    if r.perHour then kv(L.REPORT_PER_HOUR, Logic.Coins(r.perHour), ns.HEAD) end
  end
  if Logic.TooLowSkill(r) then out[#out + 1] = { left = L.REPORT_ESCAPED_HINT, small = true, color = { 0.62, 0.14, 0.07 } } end
  if (r.total or 0) > 0 then
    out[#out + 1] = { left = r.sparkmack and L.REPORT_SOURCE or L.REPORT_SOURCE_VENDOR, small = true, grey = true }
  end
  return out
end

function R.Show(p)
  local list = ns.db and ns.db.history or {}
  if #list == 0 then ns.Print(L.NO_REPORT) return end
  if not f and not ns.Safe("rapport", create) then
    if f then f:Hide() end
    f = nil
    return
  end
  page = math.max(1, math.min(p or 1, #list))
  local r = list[page]
  local when = date and date("%d.%m %H:%M", r.started) or ""
  sub:SetText(L.REPORT_WHEN:format(when, r.zone or "") .. (r.who and ("  ·  " .. r.who) or ""))
  for _, x in ipairs(pool) do x.icon:Hide() x.left:Hide() x.right:Hide() end
  local y, n = -72, 0
  for _, line in ipairs(R.Lines(r)) do
    if line.gap then
      y = y - 6
    else
      n = n + 1
      local x = row(n)
      x.left:ClearAllPoints()
      x.right:ClearAllPoints()
      if line.icon then
        x.icon:ClearAllPoints()
        x.icon:SetPoint("TOPLEFT", 36, y)
        x.icon:SetTexture(line.icon)
        x.icon:Show()
        x.left:SetPoint("TOPLEFT", 56, y - 2)
      else
        x.left:SetPoint("TOPLEFT", 36, y - 2)
      end
      x.left:SetWidth(line.right and (WIDTH - 170) or (WIDTH - 72))
      x.left:SetText(line.left or "")
      local c = line.color or (line.grey and ns.FADED) or ns.INK
      x.left:SetTextColor(c[1], c[2], c[3])
      x.left:Show()
      if line.right then
        x.right:SetPoint("TOPRIGHT", -36, y - 2)
        x.right:SetText(line.right)
        x.right:SetTextColor(c[1], c[2], c[3])
        x.right:Show()
      end
      local h = (x.left.GetStringHeight and x.left:GetStringHeight()) or 12
      y = y - math.max(18, (h or 12) + 6)
    end
  end
  f:SetHeight(-y + 62)
  pageFs:SetText(#list > 1 and L.REPORT_PAGE:format(page, #list) or "")
  prevBtn:SetShown(page < #list)
  nextBtn:SetShown(page > 1)
  f:Show()
end

function R.Hide() if f then f:Hide() end end
function R.IsShown() return f and f:IsShown() end
