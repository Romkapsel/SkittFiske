-- En falsk WoW-klient til testene. T holder tilstanden; testene endrer den og fyrer hendelser med Fire().
T = {
  chat = {}, now = 1000, clock = 1700000000, combat = false, timers = {},
  handlers = {}, bindings = {}, macros = {}, macroLimit = 120,
  cvars = { Sound_EnableAllSound = "1", Sound_EnableSFX = "1", Sound_SFXVolume = "0.4", Sound_MusicVolume = "0.6",
            Sound_AmbienceVolume = "0.5", Sound_MasterVolume = "0.8", Sound_EnableSoundWhenGameIsInBG = "0",
            ActionButtonUseKeyDown = "1" },
  equip = {}, bags = { [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {} }, bagSize = 16, counts = {},
  items = {}, skill = { rank = 120, max = 150, mod = 0 }, zone = "Elwynn Forest", subzone = "Crystal Lake",
  loot = nil, money = 1000, wench = nil, channel = nil, mouseover = false,
  realm = "Classic Beta PvP 2", faction = "Alliance", player = "Testfisker",
}

-- Ting: id → { name, loc, class, sub, tip = { linjer }, sell }
function Item(id, t) t.id = id T.items[id] = t return id end
function Link(id) return id and ("|cffffffff|Hitem:" .. id .. "::::::::60:::::|h[" .. (T.items[id] and T.items[id].name or "?") .. "]|h|r") end
function Put(id, n, bag, slot)
  bag = bag or 0
  if not slot then
    for s = 1, T.bagSize do if not T.bags[bag][s] then slot = s break end end
  end
  T.bags[bag][slot] = id
  T.counts[bag .. ":" .. slot] = n or 1
  return bag, slot
end
function BagCount(id)
  local n = 0
  for b = 0, 4 do for s = 1, T.bagSize do if T.bags[b][s] == id then n = n + (T.counts[b .. ":" .. s] or 1) end end end
  return n
end

-- Hemmelige verdier (som i Forever i kamp)
local function boom() error("attempt to use a secret value", 2) end
SECRET = setmetatable({}, { __tostring = boom, __concat = boom, __lt = boom, __le = boom, __add = boom })
function issecretvalue(v) return v == SECRET end

------------------------------------------------------------------------
-- Rammer
------------------------------------------------------------------------

local function frame(name, kind)
  local f = { scripts = {}, hooks = {}, shown = true, attrs = {}, name = name, kind = kind, points = {} }
  function f:SetScript(k, fn) self.scripts[k] = fn end
  function f:GetScript(k) return self.scripts[k] end
  function f:HookScript(k, fn) self.hooks[k] = self.hooks[k] or {} table.insert(self.hooks[k], fn) end
  function f:RegisterEvent(e) T.handlers[e] = T.handlers[e] or {} table.insert(T.handlers[e], self) end
  function f:RegisterUnitEvent(e) self:RegisterEvent(e) end
  function f:Show()
    if T.combat and self.protected then error("ADDON_ACTION_BLOCKED Show " .. tostring(self.name)) end
    self.shown = true
  end
  function f:Hide()
    if T.combat and self.protected then error("ADDON_ACTION_BLOCKED Hide " .. tostring(self.name)) end
    self.shown = false
  end
  function f:SetShown(v) if v then self:Show() else self:Hide() end end
  function f:IsShown() return self.shown end
  function f:SetAttribute(k, v)
    if T.combat and self.secure then error("ADDON_ACTION_BLOCKED SetAttribute") end
    self.attrs[k] = v
  end
  function f:GetAttribute(k) return self.attrs[k] end
  function f:RegisterForClicks(...) self.clicks = { ... } end
  function f:CreateTexture() return frame(nil, "Texture") end
  function f:CreateFontString(_, _, template)
    if template then error("fontmal i CreateFontString: " .. template) end
    return frame(nil, "FontString")
  end
  function f:SetText(t) self.text = t end
  function f:GetText() return self.text end
  function f:SetTexture(t) self.texture = t end
  function f:SetTextColor(r, g, b) self.color = { r, g, b } end
  function f:GetCenter() return 400, 300 end
  function f:GetStringHeight() return 12 end
  function f:NumLines() return 0 end
  function f:SetPoint(...) table.insert(self.points, { ... }) end
  function f:ClearAllPoints() self.points = {} end
  function f:SetHeight(h) self.height = h end
  function f:SetSize(w, h) self.width, self.height = w, h end
  function f:CreateAnimationGroup()
    if T.failAnim then error("CreateAnimationGroup feilet") end
    local g = frame(nil, "AnimationGroup")
    g.playing = false
    function g:Play() self.playing = true end
    function g:Stop() self.playing = false end
    function g:IsPlaying() return self.playing end
    function g:CreateAnimation() return frame(nil, "Animation") end
    return g
  end
  return setmetatable(f, { __index = function(_, k)
    if type(k) == "string" and k:match("^%u") then return function() end end
  end })
end

local function runScript(f, k, ...)
  if f.scripts[k] then f.scripts[k](f, ...) end
  for _, h in ipairs(f.hooks[k] or {}) do h(f, ...) end
end
RunScript = runScript

-- Et klikk på en knapp: sikre knapper gjør handlingen sin (spell / macro) mellom PreClick og PostClick
function Click(b, mouse)
  runScript(b, "PreClick", mouse or "LeftButton")
  if b.secure then
    local t = b.attrs.type
    if t == "spell" then table.insert(T.casts, b.attrs.spell)
    elseif t == "macro" then table.insert(T.macroRuns, b.attrs.macrotext) end
  end
  runScript(b, "OnClick", mouse or "LeftButton")
  runScript(b, "PostClick", mouse or "LeftButton")
end
T.casts, T.macroRuns = {}, {}

NAMED, ALLFRAMES = {}, {}
-- Bare maler vi vet finnes i Forever (7. okt: vinduet stoppet halvveis med spillets eldre maler)
KNOWN_TEMPLATES = { SecureActionButtonTemplate = true, GameTooltipTemplate = true }
function CreateFrame(kind, name, parent, template)
  if template and not KNOWN_TEMPLATES[template] then error("ukjent mal i Forever: " .. template) end
  local f = frame(name, kind)
  table.insert(ALLFRAMES, f)
  f.template = template
  f.parent = parent
  if template and template:find("SecureActionButtonTemplate") then
    f.secure = true
    f.protected = true
    local p = parent
    while p do p.protected = true p = p.parent end -- som i spillet: en ramme med sikre barn er beskyttet i kamp
  end
  if name then NAMED[name] = f end
  return f
end

UIParent = frame("UIParent")
WorldFrame = frame("WorldFrame")
GameTooltip = frame("GameTooltip")
UISpecialFrames = {}
SlashCmdList = {}
NUM_BAG_SLOTS = 4
ERR_FISH_ESCAPED = "Your fish got away!"
ERR_FISH_NOT_HOOKED = "No fish are hooked."

function Fire(e, ...)
  for _, f in ipairs(T.handlers[e] or {}) do f.scripts.OnEvent(f, e, ...) end
end

function RunTimers(upTo)
  T.now = T.now + (upTo or 5)
  local list = T.timers
  T.timers = {}
  for _, t in ipairs(list) do t.fn() end
  if #T.timers > 0 and (upTo or 5) > 0 then RunTimers(upTo) end
end
C_Timer = { After = function(s, fn) table.insert(T.timers, { at = T.now + s, fn = fn }) end }

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------

function print(s) table.insert(T.chat, s) end
function Chat(p) for _, s in ipairs(T.chat) do if s:find(p, 1, true) then return true end end return false end
function GetTime() return T.now end
function time() return T.clock end
function date(fmt, t) return "07.10 20:15" end
function GetBuildInfo() return "1.60.1", "70205", "Oct 2 2026", 16001 end
function InCombatLockdown() return T.combat end
function UnitAffectingCombat() return T.combat end
function UnitName() return T.player end
function GetRealmName() return T.realm end
function UnitFactionGroup() return T.faction, T.faction end
function UnitExists(u) if u == "mouseover" then return T.mouseover end return true end
function GetRealZoneText() return T.zone end
function GetSubZoneText() return T.subzone end
function GetMoney() return T.money end

C_CVar = {
  GetCVar = function(k) return T.cvars[k] end,
  SetCVar = function(k, v) if T.cvars[k] == nil then error("unknown cvar") end T.cvars[k] = tostring(v) return true end,
}

C_Spell = { GetSpellName = function(id) if id == 7620 or id == 7731 then return "Fishing" end end }
function GetSpellInfo(id) return C_Spell.GetSpellName(id) end

function GetNumSkillLines() return T.skill and 3 or 1 end
function GetSkillLineInfo(i)
  if i == 1 then return "Secondary Skills", true end
  if i == 2 then return "First Aid", false, false, 40, 0, 0, 75 end
  if i == 3 and T.skill then return "Fishing", false, false, T.skill.rank, 0, T.skill.mod, T.skill.max end
end

function UnitChannelInfo(u)
  if T.channel then return T.channel, "", 0, 0, 0, false, false, 7620 end
end

function SetOverrideBindingClick(owner, prio, key, btn)
  if T.combat then error("ADDON_ACTION_BLOCKED SetOverrideBindingClick") end
  T.bindings[key] = btn
end
function ClearOverrideBindings()
  if T.combat then error("ADDON_ACTION_BLOCKED ClearOverrideBindings") end
  T.bindings = {}
end

function GetWeaponEnchantInfo()
  local w = T.wench
  if not w then return false, nil, nil, nil, false end
  return true, w, 0, 0, false
end

-- Ting og baggene
C_Item = {}
function C_Item.GetItemInfoInstant(id)
  local it = T.items[id]
  if not it then return nil end
  return id, "", "", it.loc or "", it.icon or 1000 + id, it.class or 15, it.sub or 0
end
function C_Item.GetItemNameByID(id) return T.items[id] and T.items[id].name end
function C_Item.GetItemIconByID(id) return 1000 + id end
function C_Item.GetItemInfo(id)
  local it = T.items[id]
  if not it then return nil end
  return it.name, Link(id), 1, 1, 1, "", "", 1, it.loc or "", 1000 + id, it.sell or 0
end
function C_Item.GetItemCount(id) return BagCount(id) end

local SLOT_OF = { INVTYPE_HEAD = 1, INVTYPE_FEET = 8, INVTYPE_HAND = 10, INVTYPE_2HWEAPON = 16, INVTYPE_WEAPON = 16,
                  INVTYPE_SHIELD = 17, INVTYPE_FINGER = 11 }
local function findInBags(id)
  for b = 0, 4 do for s = 1, T.bagSize do if T.bags[b][s] == id then return b, s end end end
end
local function freeSlot()
  for b = 0, 4 do for s = 1, T.bagSize do if not T.bags[b][s] then return b, s end end end
end
T.equipCalls = 0
function C_Item.EquipItemByName(item, slot)
  T.equipCalls = T.equipCalls + 1
  local id = type(item) == "number" and item or tonumber(tostring(item):match("item:(%d+)"))
  local it = T.items[id]
  if not it then return end
  slot = slot or SLOT_OF[it.loc]
  local weapon = slot == 16 or slot == 17
  if T.combat and not weapon then return end -- rustning kan ikke byttes i kamp
  local b, s = findInBags(id)
  if not b then return end
  local old = T.equip[slot]
  T.bags[b][s] = old
  T.counts[b .. ":" .. s] = 1
  T.equip[slot] = id
  if slot == 16 and it.loc == "INVTYPE_2HWEAPON" and T.equip[17] then
    local fb, fs = freeSlot()
    T.bags[fb][fs] = T.equip[17]
    T.equip[17] = nil
  end
  if slot == 17 and T.equip[16] and T.items[T.equip[16]].loc == "INVTYPE_2HWEAPON" then
    local fb, fs = freeSlot()
    T.bags[fb][fs] = T.equip[16]
    T.equip[16] = nil
  end
end

function GetInventoryItemID(_, slot) return T.equip[slot] end
function GetInventoryItemLink(_, slot) return Link(T.equip[slot]) end
local cursor
function PickupInventoryItem(slot)
  if T.combat then error("blocked") end
  cursor = T.equip[slot]
  T.equip[slot] = nil
end
function PutItemInBackpack()
  for s = 1, T.bagSize do if not T.bags[0][s] then T.bags[0][s] = cursor cursor = nil return end end
  error("full")
end
function PutItemInBag(inv)
  local bag = inv - 30
  for s = 1, T.bagSize do if not T.bags[bag][s] then T.bags[bag][s] = cursor cursor = nil return end end
  error("full")
end
function ClearCursor() cursor = nil end

C_Container = {
  GetContainerNumSlots = function(b) return T.bags[b] and T.bagSize or 0 end,
  GetContainerItemID = function(b, s) return T.bags[b] and T.bags[b][s] end,
  GetContainerItemLink = function(b, s) return T.bags[b] and Link(T.bags[b][s]) end,
  GetContainerItemInfo = function(b, s)
    local id = T.bags[b] and T.bags[b][s]
    if id then return { itemID = id, stackCount = T.counts[b .. ":" .. s] or 1 } end
  end,
  GetContainerNumFreeSlots = function(b)
    local n = 0
    for s = 1, T.bagSize do if not T.bags[b][s] then n = n + 1 end end
    return n, 0
  end,
  ContainerIDToInventoryID = function(b) return 30 + b end,
}

local function tip(id, extra)
  if not id then return nil end
  local lines = { { leftText = T.items[id].name } }
  for _, l in ipairs(T.items[id].tip or {}) do lines[#lines + 1] = { leftText = l } end
  for _, l in ipairs(extra or {}) do lines[#lines + 1] = { leftText = l } end
  return { lines = lines }
end
T.enchant = {} -- slot → ekstra tooltip-linje (f.eks. «Fishing +2» på hanskene)
C_TooltipInfo = {
  GetBagItem = function(b, s) return tip(T.bags[b][s]) end,
  GetInventoryItem = function(_, slot) return tip(T.equip[slot], T.enchant[slot] and { T.enchant[slot] }) end,
  GetItemByID = function(id) return tip(id) end,
}

-- Loot
function IsFishingLoot() return T.loot and T.loot.fishing end
function GetNumLootItems() return T.loot and #T.loot.items or 0 end
function GetLootSlotLink(i) return Link(T.loot.items[i][1]) end
function GetLootSlotInfo(i) local x = T.loot.items[i] return 1000 + x[1], T.items[x[1]].name, x[2] end

-- Makroer
function GetMacroIndexByName(n) for i, m in ipairs(T.macros) do if m.name == n then return i end end return 0 end
function CreateMacro(name, icon, body, perChar)
  if #T.macros >= T.macroLimit then error("too many macros") end
  table.insert(T.macros, { name = name, icon = icon, body = body, perChar = perChar })
  return #T.macros
end
function PickupMacro(i) T.cursorMacro = i end

------------------------------------------------------------------------
-- Felles oppsett for testene
------------------------------------------------------------------------

POLE = Item(6256, { name = "Fishing Pole", loc = "INVTYPE_2HWEAPON", class = 2, sub = 20, tip = { "Two-Hand", "Fishing Pole" }, sell = 4 })
STRONG = Item(6365, { name = "Strong Fishing Pole", loc = "INVTYPE_2HWEAPON", class = 2, sub = 20,
                      tip = { "Two-Hand", "Equip: Increased Fishing +5." }, sell = 180 })
ARCANITE = Item(19970, { name = "Arcanite Fishing Pole", loc = "INVTYPE_2HWEAPON", class = 2, sub = 20,
                         tip = { "Two-Hand", "Equip: Increased Fishing +35." }, sell = 2000 })
HAT = Item(19972, { name = "Lucky Fishing Hat", loc = "INVTYPE_HEAD", class = 4, sub = 1, tip = { "Head", "Equip: Increased Fishing +5." } })
BOOTS = Item(19969, { name = "Nat Pagle's Extreme Anglin' Boots", loc = "INVTYPE_FEET", class = 4, sub = 1,
                      tip = { "Feet", "Equip: Increased Fishing +5." } })
REQ_HAT = Item(33820, { name = "Weather-Beaten Fishing Hat", loc = "INVTYPE_HEAD", class = 4, sub = 1,
                        tip = { "Head", "Requires Fishing (100)" } })
SWORD = Item(2488, { name = "Gladius", loc = "INVTYPE_WEAPON", class = 2, sub = 7, tip = { "One-Hand" } })
SHIELD = Item(2129, { name = "Large Round Shield", loc = "INVTYPE_SHIELD", class = 4, sub = 6, tip = { "Off Hand" } })
HELM = Item(3890, { name = "Studded Hat", loc = "INVTYPE_HEAD", class = 4, sub = 2, tip = { "Head" } })
OLDBOOTS = Item(2309, { name = "Embossed Leather Boots", loc = "INVTYPE_FEET", class = 4, sub = 2, tip = { "Feet" } })
GLOVES = Item(2470, { name = "Reinforced Leather Gloves", loc = "INVTYPE_HAND", class = 4, sub = 2, tip = { "Hands" } })
BAUBLE = Item(6529, { name = "Shiny Bauble", class = 0, tip = { "Use: When applied to your fishing pole, increases Fishing by 25 for 10 min." } })
CRAWLER = Item(6530, { name = "Nightcrawlers", class = 0, tip = { "Use: When applied to your fishing pole, increases Fishing by 50 for 10 min." } })
NEWLURE = Item(999001, { name = "Forever Spinner", class = 0, tip = { "Use: When applied to your fishing pole, increases Fishing by 60 for 10 min." } })
BREAD = Item(4540, { name = "Tough Hunk of Bread", class = 0, tip = { "Use: Restores 61 health over 18 sec." } })
SMALLFISH = Item(6291, { name = "Raw Brilliant Smallfish", class = 7, sell = 1 })
LONGJAW = Item(6289, { name = "Raw Longjaw Mud Snapper", class = 7, sell = 2 })
OILY = Item(6358, { name = "Oily Blackmouth", class = 7, sell = 4 })

function Login()
  Fire("ADDON_LOADED", "SkittFiske")
  Fire("PLAYER_LOGIN")
end

function Slash(msg) SlashCmdList.SKITTFISKE(msg or "") end

-- To høyreklikk i verden med `gap` sekunder mellom
function DoubleRight(gap)
  local hooks = WorldFrame.hooks.OnMouseDown or {}
  for _, h in ipairs(hooks) do h(WorldFrame, "RightButton") end
  T.now = T.now + (gap or 0.2)
  for _, h in ipairs(hooks) do h(WorldFrame, "RightButton") end
end

HARNESS = { LoadAddon = true, NS = true, RESULTS = true, ALLOWED = true, check = true, HARNESS = true }
function NewGlobals()
  local out = {}
  for k in pairs(_G) do if not BASELINE[k] and not ALLOWED[k] and not HARNESS[k] then out[#out + 1] = k end end
  return out
end
