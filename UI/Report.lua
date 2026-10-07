-- Fangstrapporten: vises når du avslutter, og /skitt rapport viser de siste (bla med pilene)
local addonName, ns = ...
local R = {}
ns.Report = R
local Logic, Game, L = ns.Logic, ns.Game, ns.L

local WIDTH = 300
local f, sub, pageFs, prevBtn, nextBtn
local pool = {}
local page = 1

local function row(i)
  local r = pool[i]
  if r then return r end
  r = {}
  r.icon = f:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(16, 16)
  r.left = ns.Text(f, "GameFontNormalSmall", 1, 1, 1)
  r.left:SetJustifyH("LEFT")
  r.right = ns.Text(f, "GameFontNormalSmall", 1, 1, 1)
  r.right:SetJustifyH("RIGHT")
  pool[i] = r
  return r
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
  ns.Background(f, 0.95)
  if UISpecialFrames then table.insert(UISpecialFrames, "SkittFiskeReport") end -- Esc lukker

  local title = ns.Text(f, "GameFontNormalLarge", 0.31, 0.7, 0.85)
  title:SetPoint("TOPLEFT", 12, -10)
  title:SetText(L.REPORT_TITLE)
  sub = ns.Text(f, "GameFontNormalSmall", 0.55, 0.55, 0.55)
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)

  ns.CloseButton(f, function() f:Hide() end)

  local done = ns.TextButton(f, L.REPORT_CLOSE, 80, function() f:Hide() end)
  done:SetPoint("BOTTOMRIGHT", -10, 10)
  prevBtn = ns.TextButton(f, "<", 26, function() R.Show(page + 1) end)
  prevBtn:SetPoint("BOTTOMLEFT", 10, 10)
  nextBtn = ns.TextButton(f, ">", 26, function() R.Show(page - 1) end)
  nextBtn:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
  pageFs = ns.Text(f, "GameFontNormalSmall", 0.55, 0.55, 0.55)
  pageFs:SetPoint("LEFT", nextBtn, "RIGHT", 8, 0)
end

-- Linjene i rapporten: { left, right, icon, color, small }
function R.Lines(r)
  local out = {}
  local function kv(k, v, color) out[#out + 1] = { left = k, right = v, color = color } end
  kv(L.REPORT_TIME, Logic.Duration(r.secs, L))
  kv(L.REPORT_CASTS, tostring(r.casts or 0))
  kv(L.REPORT_CAUGHT, tostring(r.caught or 0))
  if (r.escaped or 0) > 0 then kv(L.REPORT_ESCAPED, tostring(r.escaped), { 1, 0.5, 0.4 }) end
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
    kv(L.REPORT_VALUE, Logic.Coins(r.total), { 1, 0.82, 0 })
    if r.perHour then kv(L.REPORT_PER_HOUR, Logic.Coins(r.perHour), { 1, 0.82, 0 }) end
  end
  if Logic.TooLowSkill(r) then out[#out + 1] = { left = L.REPORT_ESCAPED_HINT, small = true, color = { 1, 0.5, 0.4 } } end
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
  local y, n = -48, 0
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
        x.icon:SetPoint("TOPLEFT", 12, y)
        x.icon:SetTexture(line.icon)
        x.icon:Show()
        x.left:SetPoint("TOPLEFT", 32, y - 2)
      else
        x.left:SetPoint("TOPLEFT", 12, y - 2)
      end
      x.left:SetWidth(line.right and (WIDTH - 130) or (WIDTH - 24))
      x.left:SetText(line.left or "")
      local c = line.color or (line.grey and { 0.5, 0.5, 0.5 }) or { 0.9, 0.9, 0.9 }
      x.left:SetTextColor(c[1], c[2], c[3])
      x.left:Show()
      if line.right then
        x.right:SetPoint("TOPRIGHT", -12, y - 2)
        x.right:SetText(line.right)
        x.right:SetTextColor(c[1], c[2], c[3])
        x.right:Show()
      end
      local h = (x.left.GetStringHeight and x.left:GetStringHeight()) or 12
      y = y - math.max(18, (h or 12) + 6)
    end
  end
  f:SetHeight(-y + 44)
  pageFs:SetText(#list > 1 and L.REPORT_PAGE:format(page, #list) or "")
  prevBtn:SetShown(page < #list)
  nextBtn:SetShown(page > 1)
  f:Show()
end

function R.Hide() if f then f:Hide() end end
function R.IsShown() return f and f:IsShown() end
