-- Lyden mens du fisker: effekter opp, musikk og omgivelser ned, og lyd også når spillet ikke er i fokus.
-- Det gamle lagres i SkittFiskeDB.sound (lydinnstillingene gjelder hele kontoen) og settes tilbake etterpå.
local addonName, ns = ...
local Sound = {}
ns.Sound = Sound
local Logic, Game = ns.Logic, ns.Game

function Sound.Apply(db)
  if db.sound then return end
  local cur = {}
  for _, k in ipairs(Logic.SOUND_KEYS) do cur[k] = Game.GetCVar(k) end
  local plan = Logic.SoundPlan(cur)
  local saved = {}
  for k, v in pairs(plan) do
    if Game.SetCVar(k, v) then saved[k] = cur[k] end
  end
  db.sound = saved
end

function Sound.Restore(db)
  if not db.sound then return end
  for k, v in pairs(db.sound) do Game.SetCVar(k, v) end
  db.sound = nil
end
