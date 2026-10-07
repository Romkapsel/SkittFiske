-- Dobbelt høyreklikk kaster. Ved det andre trykket bindes høyre musknapp et øyeblikk til en sikker
-- Fishing-knapp, så slippet av knappen kaster (spillet krever et ekte klikk; vi kaster aldri selv).
-- Høyreklikk på duppen er spillets eget: det fanger. Mens duppen er ute, gjør dobbeltklikk ingenting.
local addonName, ns = ...
local Cast = {}
ns.Cast = Cast
local Data, Logic, Game = ns.Data, ns.Logic, ns.Game

local btn, owner, last
local armed = false

function Cast.Init()
  if btn then return end
  owner = CreateFrame("Frame")
  btn = CreateFrame("Button", "SkittFiskeCastButton", UIParent, "SecureActionButtonTemplate")
  btn:SetSize(1, 1)
  btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -50, 50)
  btn:SetAlpha(0)
  btn:EnableMouse(false)
  btn:RegisterForClicks("AnyUp", "AnyDown")
  btn:SetAttribute("type", "spell")
  btn:SetAttribute("spell", Game.FishingName())
  btn:HookScript("PreClick", function() ns.Debug.Count("castClick") end)
  btn:HookScript("PostClick", function() Cast.Disarm() end)
  if WorldFrame and WorldFrame.HookScript then
    WorldFrame:HookScript("OnMouseDown", function(_, button) Cast.OnMouseDown(button) end)
  end
end

function Cast.OnMouseDown(button)
  if button ~= "RightButton" or not ns.active then return end
  ns.Debug.Count("rightDown")
  local now = Game.Now()
  if not Logic.IsDoubleClick(last, now, Data.DOUBLE_CLICK) then last = now return end
  last = nil
  if Game.InCombat() or Game.IsFishing() then return end
  if Game.try(UnitExists, "mouseover") then return end
  if pcall(SetOverrideBindingClick, owner, true, "BUTTON2", "SkittFiskeCastButton") then
    armed = true
    ns.Debug.Count("armed")
    if C_Timer then C_Timer.After(1, Cast.Disarm) end
  end
end

function Cast.Disarm()
  if armed and not Game.InCombat() then
    pcall(ClearOverrideBindings, owner)
    armed = false
  end
end

function Cast.IsArmed() return armed end
