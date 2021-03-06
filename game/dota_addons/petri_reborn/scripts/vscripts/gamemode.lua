BAREBONES_DEBUG_SPEW = false

if GameMode == nil then
    DebugPrint( '[BAREBONES] creating barebones game mode' )
    _G.GameMode = class({})
end

GameMode.DISABLED_HINTS_PLAYERS = {}

GameMode.PETRI_GAME_HAS_STARTED = false
GameMode.PETRI_GAME_HAS_ENDED = false

GameMode.PETRI_NO_END = false

GameMode.PETRI_NAME_LIST = {}
GameMode.PETRI_LANG_LIST = {}

GameMode.KVN_BONUS_ITEM = {}
for i=0,DOTA_MAX_PLAYERS do
  GameMode.KVN_BONUS_ITEM[i] = {}
  table.insert(GameMode.KVN_BONUS_ITEM[i], {item = "item_petri_kvn_bag_1", count = 1})
  table.insert(GameMode.KVN_BONUS_ITEM[i], {item = "item_petri_kvn_bag_2", count = 1})
  table.insert(GameMode.KVN_BONUS_ITEM[i], {item = "item_petri_kvn_bag_3", count = 1})
  table.insert(GameMode.KVN_BONUS_ITEM[i], {item = "item_petri_kvn_bag_4", count = 1})
end

GameMode.EXIT_COUNT = 0

GameMode.PETRI_ADDITIONAL_EXIT_GOLD_GIVEN = false
GameMode.PETRI_ADDITIONAL_EXIT_GOLD_TIME = 300
GameMode.PETRI_ADDITIONAL_EXIT_GOLD = 10000

GameMode.villians = {}
GameMode.kvns = {}

FUCKSCALEFORM = false

GameRules.Winner = GameRules.Winner or DOTA_TEAM_BADGUYS

check1 = (function(name) 
            for i=1,7 do
              if GameRules.PETRI_LOCK_ITEMS[i] == name then
                return true
              end
            end
            return false
          end)

check2 = (function(purchaser) 
            for i=0,5 do
              if purchaser:GetItemInSlot(i) and check1(purchaser:GetItemInSlot(i):GetName()) then
                return true
              end
            end
            return false
          end)

require('libraries/physics')
require('libraries/projectiles')
require('libraries/notifications')
require('libraries/attachments')
require('libraries/animations')
require('libraries/GameSetup')
require('libraries/KickSystem')
require('libraries/CustomBuildings')
require('libraries/StatUploaderFunctions')

require('libraries/buildinghelper')
require('libraries/dependencies')

require('units/kvn_fan')

require('buildings/bh_abilities')

require('balance')

require('settings')
require('internal/events')
require('events')

require('lottery')
require('scores')
require('autogold')
require('shop')

require('filters')
require('commands')
require('internal/gamemode')

require('easytimers')

require('internal/modifier_model_change')
require('internal/modifier_bonus_life')
require('internal/modifier_tribune')

function GameMode:PostLoadPrecache()
  DebugPrint("[BAREBONES] Performing Post-Load precache")
end

function GameMode:OnFirstPlayerLoaded()
  DebugPrint("[BAREBONES] First Player has loaded")
end

function GameMode:OnAllPlayersLoaded()
  DebugPrint("[BAREBONES] All Players have loaded into the game")
end

function GameMode:AddItems( newHero )
  for steamid,t in pairs(GameMode.StartItemsKVs) do
    if tonumber(steamid) == PlayerResource:GetSteamAccountID(newHero:GetPlayerOwnerID()) then
      for k,v in pairs(t) do
        if k == newHero:GetUnitName() then
          for k1,v1 in pairs(v) do
            newHero:AddItemByName(v1)
          end
          break
        end
      end
    end
  end
end

function GameMode:CreateHero(pID, callback)
  GameMode.assignedPlayerHeroes = GameMode.assignedPlayerHeroes or {}
  
  local player = PlayerResource:GetPlayer(pID)
  if not player then
    callback()
    return
  end
  local team = player:GetTeam()
  local wisp = player:GetAssignedHero()
  if not IsValidEntity(wisp) then
    print("asadasd")
    callback()
    return
  end

  local newHero

  InitAbilities(wisp)
  print(wisp:GetAbilityByIndex(0):GetName())

   -- Init kvn fan
  if team == 2 then
    -- UTIL_Remove(hero) 
    PrecacheUnitByNameAsync("npc_dota_hero_rattletrap",
      function() 
        player = PlayerResource:GetPlayer(pID)
        if not player then
          callback()
        end
        -- self.playerQueue()
        Notifications:Top(pID, {text="#start_game", duration=5, style={color="white", ["font-size"]="45px"}})

        newHero = PlayerResource:ReplaceHeroWith(pID,"npc_dota_hero_rattletrap",0,0)
        -- UTIL_Remove(wisp)

        InitAbilities(newHero)

        -- newHero:SetAbilityPoints(0)
        -- local item = CreateItem("item_petri_hp_fix",newHero,newHero)
        -- item:ApplyDataDrivenModifier(newHero,newHero,"modifier_hp_hack",{})

        -- PrintTable(GameMode.KVN_BONUS_ITEM[pID])

        if GameMode.KVN_BONUS_ITEM[pID] then
          for k,v in pairs(GameMode.KVN_BONUS_ITEM[pID]) do
            for i=1,tonumber(v["count"]) do
              newHero:AddItemByName(v["item"])
            end  
          end
        end

        newHero.spawnPosition = newHero:GetAbsOrigin()
        
        InitHeroValues(newHero, pID)
        newHero.lumber = GameRules.START_KVN_LUMBER

        newHero.uniqueUnitList = {}

        SetupUI(pID)
        SetupUpgrades(pID)
        SetupDependencies(pID)

        GameMode.assignedPlayerHeroes[pID] = newHero

        SetCustomGold( pID, GameRules.START_KVN_GOLD )

        newHero.kvnScore = 0

        Timers:CreateTimer(function (  )
          newHero.key = "kvn"
          GameMode:SetupCustomSkin(newHero, PlayerResource:GetSteamAccountID(pID), newHero.key)
          GameMode:SetupVIPItems(newHero, PlayerResource:GetSteamAccountID(pID))
        end)

        if newHero then
          EasyTimers:CreateTimer(function()
            local abilities = newHero:GetAbilityCount() - 1
            for i = 0, abilities do
              if newHero:GetAbilityByIndex(i) then
                if string.find(newHero:GetAbilityByIndex(i):GetAbilityName(), "special") then
                    newHero:GetAbilityByIndex(i):SetAbilityIndex(14+i)
                    newHero:RemoveAbility(newHero:GetAbilityByIndex(i):GetAbilityName())
                end
              end
            end
          end, DoUniqueString('fixHotKey'), 2)
        end

        table.insert(GameMode.kvns, newHero)

        GameMode:AddItems( newHero )

        callback()
        CustomGameEventManager:Send_ServerToPlayer( player, "petri_close_spawning", { state = false } )
      end, 
    pID)

    return
  end

  local petrosyanHeroName = "npc_dota_hero_brewmaster"
  if pID == PlayerResource:GetNthPlayerIDOnTeam(DOTA_TEAM_BADGUYS, 2) then
    petrosyanHeroName = "npc_dota_hero_death_prophet"
  end

   -- Init petrosyan
  if team == 3 then
    -- UTIL_Remove(hero) 
    PrecacheUnitByNameAsync(petrosyanHeroName,
     function() 
        player = PlayerResource:GetPlayer(pID)
        if not player then
          callback()
        end
        -- self.playerQueue()
        newHero = PlayerResource:ReplaceHeroWith(pID,petrosyanHeroName,0,0)
        -- UTIL_Remove(wisp)

        -- It's dangerous to go alone, take this
        newHero:SetAbilityPoints(4)
        newHero:UpgradeAbility(newHero:FindAbilityByName("petri_petrosyan_return"))
        newHero:UpgradeAbility(newHero:FindAbilityByName("petri_petrosyan_passive"))
        newHero:UpgradeAbility(newHero:FindAbilityByName("petri_exploration_tower_explore_world"))
        newHero:UpgradeAbility(newHero:FindAbilityByName("petri_petrosyan_flat_joke"))

        newHero:FindAbilityByName("petri_petrosyan_passive"):ApplyDataDrivenModifier(newHero, newHero, "dummy_sleep_modifier", {})

        newHero.spawnPosition = newHero:GetAbsOrigin()

        InitHeroValues(newHero, pID)

        SetupUI(pID)

        GameMode.assignedPlayerHeroes[pID] = newHero

        Timers:CreateTimer(function (  )
          GameMode:SetupVIPItems(newHero, PlayerResource:GetSteamAccountID(pID))
        end)

        SetCustomGold( pID, GameRules.START_PETROSYANS_GOLD )

        newHero.petrosyanScore = 0

        GameMode.villians[petrosyanHeroName] = newHero

        Timers:CreateTimer(function (  )
          if petrosyanHeroName ~= "npc_dota_hero_death_prophet" then
            newHero.key = "petrosyan"
            GameMode:SetupCustomSkin(newHero, PlayerResource:GetSteamAccountID(pID), newHero.key)
          else
            newHero.key = "elena"
            GameMode:SetupCustomSkin(newHero, PlayerResource:GetSteamAccountID(pID), newHero.key)
          end
        end)

        if GameRules.explorationTowerCreated == nil then
          GameRules.explorationTowerCreated = true
          Timers:CreateTimer(0.2,
          function()
            GameMode.explorationTower = CreateUnitByName( "npc_petri_exploration_tower" , Entities:FindAllByName("exploration_tower_position")[1]:GetAbsOrigin() , true, newHero, nil, DOTA_TEAM_BADGUYS )
            end)
        end

        if newHero then
          EasyTimers:CreateTimer(function()
            local abilities = newHero:GetAbilityCount() - 1
            for i = 0, abilities do
              if newHero:GetAbilityByIndex(i) then
                if string.find(newHero:GetAbilityByIndex(i):GetAbilityName(), "special") then
                    newHero:GetAbilityByIndex(i):SetAbilityIndex(14+i)
                    newHero:RemoveAbility(newHero:GetAbilityByIndex(i):GetAbilityName())
                end
              end
            end
          end, DoUniqueString('fixHotKey'), 2)
        end

        GameMode:AddItems( newHero )

        callback()
        CustomGameEventManager:Send_ServerToPlayer( player, "petri_close_spawning", { state = false } )
     end, pID)
    return
  end
end

function InitHeroValues(hero, pID)
  hero.lumber = 0
  hero.bonusLumber = 0
  hero.food = 0
  hero.maxFood = 10
  hero.allEarnedGold = 0
  hero.allGatheredLumber = 0
  hero.numberOfUnits = 0
  hero.numberOfMegaWorkers = 0
  hero.buildingCount = 0

  GameMode.SELECTED_UNITS[pID] = {}
  GameMode.SELECTED_UNITS[pID]["0"] = hero:entindex()
end

function SetupDependencies(pID)
  CustomNetTables:SetTableValue( "players_dependencies", tostring(pID), {} );
end

function SetupUpgrades(pID)
  local upgradeAbilities = {}

  for ability_name,ability_info in pairs(GameMode.AbilityKVs) do
    if type(ability_info) == "table" then
      if string.match(ability_name, "petri_upgrade") then 
         upgradeAbilities[ability_name] = 0
      end  
    end
  end

  CustomNetTables:SetTableValue( "players_upgrades", tostring(pID), upgradeAbilities );

  --PrintTable(CustomNetTables:GetTableValue("players_upgrades", tostring(pID)))
end

function SetupUI(pID)
  local player = PlayerResource:GetPlayer(pID)
  if not player then return end

  --Send lumber and food info to users
  CustomGameEventManager:Send_ServerToPlayer( player, "petri_set_items", GameMode.ItemKVs )

  --Send lumber and food info to users
  CustomGameEventManager:Send_ServerToPlayer( player, "petri_set_ability_layouts", GameMode.abilityLayouts )

  --Send gold costs
  CustomGameEventManager:Send_ServerToPlayer( player, "petri_set_gold_costs", GameMode.abilityGoldCosts )

  --Send xp table
  CustomGameEventManager:Send_ServerToPlayer( player, "petri_set_xp_table", XP_PER_LEVEL_TABLE )

  --Send dependencies
  CustomGameEventManager:Send_ServerToPlayer( player, "petri_set_dependencies_table", GameMode.DependenciesKVs )

  --Send special values
  CustomGameEventManager:Send_ServerToPlayer( player, "petri_set_special_values_table", GameMode.specialValues )

  --Send lumber and food info to users
  CustomGameEventManager:Send_ServerToPlayer( player, "petri_set_builds", GameMode.ItemBuilds )

  --Send lumber and food info to users
  CustomGameEventManager:Send_ServerToPlayer( player, "petri_set_shops", GameMode.shopsKVs )
end

function GameMode:OnGameInProgress()
  DebugPrint("[BAREBONES] The game has officially begun")

  Timers:CreateTimer(30.0,
    function()
      for k,v in pairs(GameMode.villians) do
        v:RemoveModifierByName("dummy_sleep_modifier")
      end
    end)

  Shop:Init()
  
  GameMode.PETRI_GAME_HAS_STARTED = true

  -- PauseGame(true)

  GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_BADGUYS, DOTA_MAX_PLAYERS)

  GameMode:TimingScores( )
  GameMode:RegisterAutoGold( )

  local creepID = 1
  Timers:CreateTimer(6 * 60,
    function()
      if creepID == 8 then
        return
      end

      local ents = Entities:FindAllByName("npc_dota_creature")

      for k,v in pairs(ents) do
        if v.GetUnitName and v:GetUnitName() == "npc_petri_creep_special"..tostring(creepID) then
          local pos = v:GetAbsOrigin()

          UTIL_Remove(v)

          local unit = CreateUnitByName("npc_petri_creep_special"..tostring(creepID  + 1),pos,true,nil,nil,DOTA_TEAM_NEUTRALS)
        end
      end

      creepID = creepID + 1

      return 8.0 * 60
    end)

    local creepID = 1
  Timers:CreateTimer(6 * 60,
    function()
      if creepID == 8 then
        return
      end

      local ents = Entities:FindAllByName("npc_dota_creature")

      for k,v in pairs(ents) do
        if v.GetUnitName and v:GetUnitName() == "npc_petri_creep_special_arena_helper"..tostring(creepID) then
          local pos = v:GetAbsOrigin()

          UTIL_Remove(v)

          local unit = CreateUnitByName("npc_petri_creep_special_arena_helper"..tostring(creepID  + 1),pos,true,nil,nil,DOTA_TEAM_BADGUYS)
        end
      end

      creepID = creepID + 1

      return 8.0 * 60
    end)

  Timers:CreateTimer(1.0,
    function()
      GameMode.PETRI_TRUE_TIME = GameMode.PETRI_TRUE_TIME + 1
      return 1.0
    end)

  Timers:CreateTimer((PETRI_FIRST_LOTTERY_TIME * 60),
    function()
      InitLottery()

      Timers:CreateTimer((PETRI_LOTTERY_TIME * 60),
      function()
        InitLottery()

        return (PETRI_LOTTERY_TIME * 60)
      end)
    end)
  
  Timers:CreateTimer((GameRules.PETRI_EXIT_MARK * 60),
    function()
      GameRules.PETRI_EXIT_ALLOWED = true
      Notifications:TopToTeam(DOTA_TEAM_GOODGUYS, {text="#exit_notification", duration=4, style={color="white", ["font-size"]="45px"}})
    end)

  Timers:CreateTimer((GameRules.PETRI_EXIT_WARNING * 60),
    function()
      Notifications:TopToTeam(DOTA_TEAM_GOODGUYS, {text="#exit_warning", duration=4, style={color="red", ["font-size"]="45px"}})
    end)

    Timers:CreateTimer((GameRules.PETRI_MIRACLE1_MARK * 60),
    function()
      GameRules.PETRI_MIRACLE1_ALLOWED = true
      Notifications:TopToTeam(DOTA_TEAM_GOODGUYS, {text="#miracle1_notification", duration=4, style={color="white", ["font-size"]="45px"}})
    end)

  Timers:CreateTimer((GameRules.PETRI_MIRACLE1_WARNING * 60),
    function()
      Notifications:TopToTeam(DOTA_TEAM_GOODGUYS, {text="#miracle1_warning", duration=4, style={color="red", ["font-size"]="45px"}})
    end)

      Timers:CreateTimer((GameRules.PETRI_MIRACLE2_MARK * 60),
    function()
      GameRules.PETRI_MIRACLE2_ALLOWED = true
      Notifications:TopToTeam(DOTA_TEAM_GOODGUYS, {text="#miracle2_notification", duration=4, style={color="white", ["font-size"]="45px"}})
    end)

  Timers:CreateTimer((GameRules.PETRI_MIRACLE2_WARNING * 60),
    function()
      Notifications:TopToTeam(DOTA_TEAM_GOODGUYS, {text="#miracle2_warning", duration=4, style={color="red", ["font-size"]="45px"}})
    end)

      Timers:CreateTimer((GameRules.PETRI_MIRACLE3_MARK * 60),
    function()
      GameRules.PETRI_MIRACLE3_ALLOWED = true
      Notifications:TopToTeam(DOTA_TEAM_GOODGUYS, {text="#miracle3_notification", duration=4, style={color="white", ["font-size"]="45px"}})
    end)

  Timers:CreateTimer((GameRules.PETRI_MIRACLE3_WARNING * 60),
    function()
      Notifications:TopToTeam(DOTA_TEAM_GOODGUYS, {text="#miracle3_warning", duration=4, style={color="red", ["font-size"]="45px"}})
    end)

  Timers:CreateTimer((GameRules.PETRI_TIME_LIMIT * 60),
    function()
      PetrosyanWin()
    end)

  -- Tips
  Timers:CreateTimer(((PETRI_FIRST_LOTTERY_TIME - 2) * 60),
    function()
      Notifications:TopToTeam(DOTA_TEAM_GOODGUYS, {text="#lottery_notification", duration=4, style={color="white", ["font-size"]="45px"}})
    end)

  -- Petrosyan tutorial
  tutorial_time = 0
  Timers:CreateTimer(
    function()
      Notifications:TopToTeam(DOTA_TEAM_BADGUYS, {disabled_players = GameMode.DISABLED_HINTS_PLAYERS, loc_check = true, text="#petrosyans_tip_"..tostring(tutorial_time), duration=10, style={color="white", ["font-size"]="45px"}})

      tutorial_time = tutorial_time + 5
      return 5
    end)
end

function GameMode:InitGameMode()
  GameMode = self

  GameMode:_InitGameMode()

  GameMode.DependenciesKVs = LoadKeyValues("scripts/kv/dependencies.kv")

  GameMode.BuildingMenusKVs = LoadKeyValues("scripts/kv/building_menus.kv")

  GameMode.WallsKVs = LoadKeyValues("scripts/kv/walls.kv")

  GameMode.CustomSkinsKVs = LoadKeyValues("scripts/kv/custom_skins.kv")
  GameMode.CustomBuildingsKVs = LoadKeyValues("scripts/kv/custom_buildings.kv")
  GameMode.VIPItemsKVs = LoadKeyValues("scripts/kv/vip_items.kv")

  GameMode.ShopKVs = LoadKeyValues("scripts/shops/petri_1_radiant_shops.txt")

  GameMode.UnitKVs = LoadKeyValues("scripts/npc/npc_units_custom.txt")
  GameMode.HeroKVs = LoadKeyValues("scripts/npc/npc_heroes_custom.txt")
  GameMode.AbilityKVs = LoadKeyValues("scripts/npc/npc_abilities_custom.txt")
  GameMode.ItemKVs = LoadKeyValues("scripts/npc/npc_items_custom.txt")

  GameMode.StartItemsKVs = LoadKeyValues("scripts/kv/start_items.kv")

  GameMode.shopsKVs = LoadKeyValues("scripts/shops/petri_1_radiant_shops.txt")

  GameMode.ItemBuilds = {}
  GameMode.ItemBuilds["npc_dota_hero_brewmaster"] = LoadKeyValues("itembuilds/default_brewmaster.txt")
  GameMode.ItemBuilds["npc_dota_hero_death_prophet"] = LoadKeyValues("itembuilds/default_death_prophet.txt")
  GameMode.ItemBuilds["npc_dota_hero_rattletrap"] = LoadKeyValues("itembuilds/default_rattletrap.txt")

  GameMode.abilityLayouts = {}
  GameMode.abilityGoldCosts = {}
  GameMode.specialValues = {}
  GameMode.buildingMenus = {}

  GameMode.SELECTED_UNITS = {}

  -- KVN Building menus
  for k,menu in pairs(GameMode.BuildingMenusKVs) do
    if type(menu) == "table" then
      GameMode.buildingMenus[k] = {}
      local i = 1
      for k1,v1 in pairs(menu) do
        GameMode.buildingMenus[k][i] = menu[tostring(i)]
        i = i + 1
      end
    end
  end

  -- Ability layouts
  for i=1,2 do
    local t = GameMode.UnitKVs
    if i == 2 then
      t = GameMode.HeroKVs
    end
    for unit_name,unit_info in pairs(t) do
      if type(unit_info) == "table" then
        if i == 2 then
          GameMode.abilityLayouts[unit_info["override_hero"]] = unit_info["AbilityLayout"]
        else
          GameMode.abilityLayouts[unit_name] = unit_info["AbilityLayout"]
        end
      end
    end
  end

  -- Gold costs
  for ability_name,ability_info in pairs(GameMode.AbilityKVs) do
    if type(ability_info) == "table" then
      if ability_info["AbilityGoldCost"] ~= nil then
        GameMode.abilityGoldCosts[ability_name] = Split(ability_info["AbilityGoldCost"], " ")
      end  
    end
  end

  -- Special values
  for ability_name,ability_info in pairs(GameMode.AbilityKVs) do
    if type(ability_info) == "table" then
      if ability_info["AbilitySpecial"] ~= nil then
        GameMode.specialValues[ability_name] = {}
        for k,v in pairs(ability_info["AbilitySpecial"]) do
          for k1,v1 in pairs(v) do
            if k1 ~= "var_type" and k1 ~= "lumber_cost" and k1 ~= "food_cost" then
              table.insert(GameMode.specialValues[ability_name], {name = k1, value = v1})
            end
          end
        end
      end  
    end
  end

  -- Filter orders
  GameRules:GetGameModeEntity():SetExecuteOrderFilter( Dynamic_Wrap( GameMode, "FilterExecuteOrder" ), self )

  -- Fix gold bounties
  GameRules:GetGameModeEntity():SetModifyGoldFilter(Dynamic_Wrap(GameMode, "ModifyGoldFilter"), GameMode)

  -- Fix xp bounties
  GameRules:GetGameModeEntity():SetModifyExperienceFilter(Dynamic_Wrap(GameMode, "ModifyExperienceFilter"), GameMode)

  -- Fix up damage
  GameRules:GetGameModeEntity():SetDamageFilter(Dynamic_Wrap(GameMode, "DamageFilter"), GameMode)

  -- Commands
  Convars:RegisterCommand( "lumber", Dynamic_Wrap(GameMode, 'LumberCommand'), "Gives you lumber", FCVAR_CHEAT )
  Convars:RegisterCommand( "lag", Dynamic_Wrap(GameMode, 'LumberAndGoldCommand'), "Gives you lumber and gold", FCVAR_CHEAT )
  Convars:RegisterCommand( "taeg", Dynamic_Wrap(GameMode, 'TestAdditionalExitGold'), "Test for additional exit gold", FCVAR_CHEAT )
  Convars:RegisterCommand( "tspu", Dynamic_Wrap(GameMode, 'TestStaticPopup'), "Test static popup", FCVAR_CHEAT )
  Convars:RegisterCommand( "deg", Dynamic_Wrap(GameMode, 'DontEndGame'), "Dont end game", FCVAR_CHEAT )
  Convars:RegisterCommand( "getgold", Dynamic_Wrap(GameMode, 'GetGold'), "Get all gold", FCVAR_CHEAT )
  Convars:RegisterCommand( "tc", Dynamic_Wrap(GameMode, 'TestCommand'), "TestCommand", FCVAR_CHEAT )
  Convars:RegisterCommand( "fgs", Dynamic_Wrap(GameMode, 'FinishGameSetup'), "FinishGameSetup", FCVAR_CHEAT )
  Convars:RegisterCommand( "st", Dynamic_Wrap(GameMode, 'SetTime'), "SetTime", FCVAR_CHEAT )

  BuildingHelper:Init()

  --Update player's UI
  Timers:CreateTimer(0.03,
  function()
    
    if GameMode.assignedPlayerHeroes then
      for k,v in pairs(GameMode.assignedPlayerHeroes) do
        if GameMode.assignedPlayerHeroes[k] and v:IsNull() == false then
          AddKeyToNetTable(k, "players_resources", "lumber", v.lumber)
          AddKeyToNetTable(k, "players_resources", "food", v.food)
          AddKeyToNetTable(k, "players_resources", "maxFood", v.maxFood)
          AddKeyToNetTable(k, "players_resources", "gold", GetCustomGold( v:GetPlayerOwnerID() ))
        end
      end
    end

    return 0.03
  end)
end

function GameMode:ReplaceWithMiniActor(player, gold)
  PrecacheUnitByNameAsync("npc_dota_hero_storm_spirit",
    function() 
      -- GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_GOODGUYS, PlayerResource:GetPlayerCountForTeam(DOTA_TEAM_GOODGUYS)-1)

      player:SetTeam(DOTA_TEAM_BADGUYS)
      CustomGameEventManager:Send_ServerToPlayer(player,"petri_team",{team = DOTA_TEAM_BADGUYS, hero = "npc_dota_hero_storm_spirit"})
      local newHero = PlayerResource:ReplaceHeroWith(player:GetPlayerID(), "npc_dota_hero_storm_spirit", GameRules.START_MINI_ACTORS_GOLD + gold, 0)

      newHero.spawnPosition = newHero:GetAbsOrigin()

      GameMode.assignedPlayerHeroes[player:GetPlayerID()] = newHero
      
      newHero:SetTeam(DOTA_TEAM_BADGUYS)

      newHero:RespawnHero(false, false, false)

      newHero:AddAbility("petri_petrosyan_flat_joke")

      newHero:SetAbilityPoints(4)
      newHero:UpgradeAbility(newHero:FindAbilityByName("petri_petrosyan_return"))
      newHero:UpgradeAbility(newHero:FindAbilityByName("petri_mini_actor_phase"))
      newHero:UpgradeAbility(newHero:FindAbilityByName("petri_petrosyan_passive"))
      newHero:UpgradeAbility(newHero:FindAbilityByName("petri_petrosyan_flat_joke"))

      newHero.key = "miniactors"
      GameMode:SetupCustomSkin(newHero, PlayerResource:GetSteamAccountID(player:GetPlayerID()), newHero.key)

      for k,v in pairs(newHero:GetChildren()) do
        if v:GetClassname() == "dota_item_wearable" then
          v:AddEffects(EF_NODRAW) 
        end
      end

      if newHero then
        EasyTimers:CreateTimer(function()
          local abilities = newHero:GetAbilityCount() - 1
          for i = 0, abilities do
            if newHero:GetAbilityByIndex(i) then
              if string.find(newHero:GetAbilityByIndex(i):GetAbilityName(), "special") then
                  newHero:GetAbilityByIndex(i):SetAbilityIndex(14+i)
                  newHero:RemoveAbility(newHero:GetAbilityByIndex(i):GetAbilityName())
              end
            end
          end
        end, DoUniqueString('fixHotKey'), 2)
      end

      Timers:CreateTimer(0.03, function ()
        newHero.spawnPosition = newHero:GetAbsOrigin()
      end)
    end
    , 
  player:GetPlayerID())
end

function GameMode:SetupCustomSkin(hero, steamID, key)
  if IsInToolsMode() then
    GameMode.CustomSkinsKVs = LoadKeyValues("scripts/kv/custom_skins.kv")
  end
  for k,v in pairs(GameMode.CustomSkinsKVs[key]) do
    local id = tonumber(k)

    if steamID == id then
      for k2,v2 in pairs(v) do
        if v2 == "model" then
          UpdateModel(hero, k2, 1)
          hero.model = k2
          hero:AddNewModifier(hero,nil,"modifier_model_change",{})
        end
      end

      for k2,v2 in pairs(v) do
        if type(v2) == "table" then
          hero[k2] = v2
        end
        if v2 == "wearable" then
          Wearables:AttachWearable(hero, k2)
        end
        if v2 == "scale" then
          hero:SetModelScale(tonumber(k2))
        end
        if v2 == "hero" then
          CustomGameEventManager:Send_ServerToAllClients("petri_set_icon",{hero = k2, pID = hero:GetPlayerID()})
        end
        if string.match(k2, "particle") then
          local attach = _G[v2.attach]
          if v2.attach == -1 then
            attach = -1
          end
          local p = ParticleManager:CreateParticle(v2.particle, attach, hero)     
          if v.color then
            print(v.color["1"], v.color["2"], v.color["3"], v.color.cp)
            ParticleManager:SetParticleControl(p,tonumber(v.color.cp),Vector(v.color["1"], v.color["2"], v.color["3"]))
          end
        end
        if v2 == "animation" then
          StartAnimation(hero, {duration=-1, activity=_G[k2], rate=1})
        end
      end

      -- for k1,v1 in pairs(hero:GetChildren()) do
      --   if v1:GetClassname() == "dota_item_wearable" then
      --     v1:AddEffects(EF_NODRAW) 
      --   end
      -- end

      return true
    end
  end
  local localization = GameMode.PETRI_LANG_LIST[hero:GetPlayerID()]

  if localization and GameMode.CustomSkinsKVs[key][localization] then
    for k2,v2 in pairs(GameMode.CustomSkinsKVs[key][localization]) do
      if v2 == "model" then
        UpdateModel(hero, k2, 1)
      end
    end

    for k2,v2 in pairs(GameMode.CustomSkinsKVs[key][localization]) do
      if v2 == "wearable" then
        Wearables:AttachWearable(hero, k2)
      end
    end

    -- for k2,v2 in pairs(hero:GetChildren()) do
    --   if v2:GetClassname() == "dota_item_wearable" then
    --     v2:AddEffects(EF_NODRAW) 
    --   end
    -- end
  end

  hero:MoveToPosition(hero:GetAbsOrigin())
end

function GameMode:SetupVIPItems(hero, steamID)
  for k,v in pairs(GameMode.VIPItemsKVs) do
    if k == tostring(steamID) then
      for item,count in pairs(v) do
        hero:AddItemByName(item)
      end
    end
  end
end

function KVNWin(keys)
  local caster = keys.caster
  local ability = keys.ability

  local s = true

  if ability:GetName() == "petri_miracle1" then
    s = false
    for _,v in pairs(Entities:FindAllByName("npc_dota_creature")) do
      if IsValidEntity(v) and v:IsAlive() and v:IsNull() == false and v:GetUnitName() == "npc_petri_loose_trigger1" then
        print("111111111111111111")
        s = true
        break
      end
    end
  elseif ability:GetName() == "petri_miracle2" then
    s = false
    for _,v in pairs(Entities:FindAllByName("npc_dota_creature")) do
      if IsValidEntity(v) and v:IsAlive() and v:IsNull() == false and v:GetUnitName() == "npc_petri_loose_trigger2" then
        print("22222222222222222")
        s = true
        break
      end
    end
  elseif ability:GetName() == "petri_miracle3" then
    s = false
    for _,v in pairs(Entities:FindAllByName("npc_dota_creature")) do
      if IsValidEntity(v) and v:IsAlive() and v:IsNull() == false and v:GetUnitName() == "npc_petri_loose_trigger3" then
        print("333333333333333")
        s = true
        break
      end
    end
  end

  if GameMode.PETRI_NO_END == false and s then
    print("aaaaaaaaaaaaaaaaaa")
    if GameMode.PETRI_GAME_HAS_ENDED == false then
      print("bbbbbbbbbbbbbbbbbbbb")
      GameMode.PETRI_GAME_HAS_ENDED = true

      Notifications:TopToAll({text="#kvn_win", duration=100, style={color="green"}, continue=false})

      for i=1,12 do
        PlayerResource:SetCameraTarget(i-1, caster)
      end

      Timers:CreateTimer(5.0,
        function()
          GameRules.Winner = DOTA_TEAM_GOODGUYS
          GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS) 
        end)
    end
  end
end

function PetrosyanWin()
  if GameMode.PETRI_NO_END == false then
    if GameMode.PETRI_GAME_HAS_ENDED == false then
      GameMode.PETRI_GAME_HAS_ENDED = true

      Notifications:TopToAll({text="#petrosyan_limit", duration=100, style={color="red"}, continue=false})
      Timers:CreateTimer(5.0,
        function()
          GameRules.Winner = DOTA_TEAM_BADGUYS
          GameRules:SetGameWinner(DOTA_TEAM_BADGUYS) 
        end)
    end
  end
end

function GameMode:ReApplySkin( keys )
  local steamID = PlayerResource:GetSteamAccountID(keys.PlayerID)
  local hero = PlayerResource:GetPlayer(keys.PlayerID):GetAssignedHero()

  if steamID and hero and hero.key then
    GameMode:SetupCustomSkin(hero, steamID, hero.key)
    -- EndAnimation(hero)
  end
end

if Wearables == nil then
    _G.Wearables = class({})
end

function Wearables:AttachWearable(unit, modelPath)
    local wearable = SpawnEntityFromTableSynchronous("prop_dynamic", {model = modelPath, DefaultAnim=animation, targetname=DoUniqueString("prop_dynamic")})

    wearable:FollowEntity(unit, true)

    unit.wearables = unit.wearables or {}
    table.insert(unit.wearables, wearable)

    return wearable
end

function Wearables:Remove(unit)
    if not unit.wearables or #unit.wearables == 0 then
        return
    end

    for _, part in pairs(unit.wearables) do
        part:RemoveSelf()
    end

    unit.wearables = {}
end

if LOADED then
  return
end
LOADED = true

GameMode.PETRI_TRUE_TIME = 0