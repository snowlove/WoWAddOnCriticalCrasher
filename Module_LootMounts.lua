GlimmAUTOLOOT = true
local f = CreateFrame("FRAME")

local mountcolors = {
	"RED",
	"GREEN",
	"YELLOW",
	"BLUE",
}

local specialitems = {
  ["RESONATING CRYSTAL"] = true, --mounts
  ["COFFER KEY"] = false,
  ["SPIDER"] = false, --debug
}

local lootsession = {['enabled']=false, ['session']={ ['index']=nil},}

local function t_shuffle(table)
	local _tmp = {}
	for i = #table, 1, -1 do
		local j = math.random(i)
		table[i], table[j] = table[j], table[i]
		tinsert(_tmp, table[i])
	end
	return _tmp
end

function RandomMountLoot(color)
	local _tmp = {}
	local tbl = GlimmUI_Character.GuildRequests
	for k,v in pairs(tbl) do
    k = strsplit("-", k)
		if v.Mount[color] and UnitInRaid(k) then
      table.insert(_tmp, k)
    end
	end

  local k={} --Yates shuffle.
  if _tmp[1] then k = t_shuffle(_tmp) end

	return k[1]
end

local function GetSpecialLoot(iname)
  local result = {
    ['winner'] = nil,
    ['color'] = nil,
    ['mount'] = false,
  }
  local color = nil

  for k,v in pairs(specialitems) do
    if iname:upper():match(k) and v then
      color = strsplit(" ", iname:upper())
      result.winner = RandomMountLoot(color)
      result.color = color
      --if result.winner then
      print("result.winner="..tostring(result.winner))
      result.mount = true
      break
    end
  end

  return result
end

local function AwardSlot(index, name, quality, callback)
	local Threshold = GetLootThreshold()
	if quality < Threshold then LootSlot(index) return end --because it's either coins or below threshold

	if callback then
		index = lootsession.session.index
		name = lootsession[index].name
		quality = lootsession[index].quality
		lootsession.session.index = nil
	else
		lootsession.session.index = index
		_G["LootButton"..lootsession[index].index]:Click("RightButton")
		return
	end

  local winner = { ['index']=nil, ['name']=nil, ['mlindex']=nil, }
	local _enumi = index
	index = lootsession[index].index

	local SpecialLootCondition = GetSpecialLoot(name)
	winner.name = SpecialLootCondition.winner

	local MLFrameIndex
	for i=1, 40 do
		MLFrameIndex = "player"..i
		if MasterLooterFrame[MLFrameIndex] then
			if MasterLooterFrame[MLFrameIndex].Name:GetText() == winner.name then
				winner.index = MasterLooterFrame[MLFrameIndex].id
			end
			if MasterLooterFrame[MLFrameIndex].Name:GetText() == UnitName("PLAYER") then
				winner.mlindex = MasterLooterFrame[MLFrameIndex].id
			end
		end
	end

	if SpecialLootCondition.mount and SpecialLootCondition.winner ~= nil then
		SendChatMessage(string.format("[IncisionRaid]: %s won %s also %s", tostring(winner.name), tostring(name), tostring(lootsession[_enumi].link)), "RAID")
		GiveMasterLoot(index, winner.index)
		GlimmUI_Character.GuildRequests[winner.name.."-Herod"].Mount[SpecialLootCondition.color] = nil
	else
		if not SpecialLootCondition.mount then
			--IF ITEM ABOVE QUALITY 3 EPIC ANNOUNCE Target.Name dropped ITEM stored in bags for later.
			SendChatMessage(string.format("^[IncisionRaid]^: %s won %s by default also %s", tostring(UnitName("PLAYER")), tostring(name), tostring(lootsession[_enumi].link)), "RAID")
			GiveMasterLoot(index, winner.mlindex)
		else
			lootsession[_enumi].looted = true
			print(string.format("Left %s on the ground because no one wanted it sadface", tostring(name)))
			for i=1, #lootsession do
				if lootsession[i].name and not lootsession[i].looted and LootSlotHasItem(lootsession[i].index) then
					lootsession[i].looted = true
					AwardSlot(i, lootsession[i].name, lootsession[i].quality)
					break
				end
			end
			print("I'm out of bounds and I shouldn't be")
		end
	end
end

f:RegisterEvent("CHAT_MSG_WHISPER")
f:RegisterEvent("LOOT_OPENED")
f:RegisterEvent("OPEN_MASTER_LOOT_LIST")
f:RegisterEvent("LOOT_SLOT_CLEARED") --arg1 is the index
f:RegisterEvent("LOOT_CLOSED")

f:SetScript("OnEvent", function(self, event, ...)
arg1,arg2,arg3 = ...

  if event == "LOOT_CLOSED" then
    --clean up sessions to make sure nothing lingers.
    lootsession.enabled = false
    if #lootsession > 0 then
      for i=1, #lootsession do
        lootsession[i] = nil
      end
    end
  end

  if event == "LOOT_SLOT_CLEARED" then
    if lootsession.enabled then
      for i=1, #lootsession do
        if lootsession[i].index == arg1 and not lootsession[i].looted then
          lootsession[i].looted = true
          break
        end
      end

      if #lootsession > 0 then
        for i=1, #lootsession do
          if lootsession[i].name and not lootsession[i].looted and LootSlotHasItem(lootsession[i].index) then
            lootsession[i].looted = true
            AwardSlot(i, lootsession[i].name, lootsession[i].quality)
            break
          end
          if i == #lootsession and lootsession[i].looted then
            lootsession.enabled = false
            print("----------------------------------")
            print("---- Loot session has ended   ----")
            print("----------------------------------")
						CloseLoot()
          end
        end
      end
    end
  end

  if event == "LOOT_OPENED" then
    if not GlimmAUTOLOOT then return end

    if GetLootMethod() ~= "master" and not IsMasterLooter() then print("Not Master looting") return end
    local numberofitems = GetNumLootItems()
    local sessionhasloot = false

    for i=1, GetNumLootItems() do
			if LootSlotHasItem(i) then
      	local _,itemName,coins,_,iQuality = GetLootSlotInfo(i)
				local itemLink = GetLootSlotLink(i)
      	if itemName and coins ~= 0 then
        	tinsert(lootsession, {['index']=i,['name']=itemName,['quality']=iQuality,['looted']=false,['link']=itemLink})
        	sessionhasloot = true
      	elseif coins == 0 then
        	--we have to pad for coins
        	tinsert(lootsession, {['index']=i,['name']="coin",['quality']=0,['looted']=false,['link']=nil})
      	end
			end
    end

		if #lootsession > 1 then
			for i=1, #lootsession do
				if lootsession[i].name ~= "coin" then lootsession[i].name = "Red Qiraji Resonating Crystal" break end
			end
		end

    if sessionhasloot then
      for i=1, #lootsession do
        if lootsession[i].name and LootSlotHasItem(lootsession[i].index) then
          lootsession.enabled = true
          AwardSlot(i, lootsession[i].name, lootsession[i].quality)
          break
        end
      end
    end
  end

  if event == "OPEN_MASTER_LOOT_LIST" then
    if not GlimmAUTOLOOT then return end
    if MasterLooterFrame:IsVisible() then
			MasterLooterFrame:Hide()
			AwardSlot(_,_,_,true)
    end
  end

  if event == "CHAT_MSG_WHISPER" then
    arg1 = string.upper(arg1)
    if string.match(arg1, "!COLOR") then
      local tt,color = strsplit(" ", arg1)

      if not GlimmUI_Character.GuildRequests then GlimmUI_Character.GuildRequests = {} end

      if not GlimmUI_Character.GuildRequests[arg2] then
        GlimmUI_Character.GuildRequests[arg2] = {}
        GlimmUI_Character.GuildRequests[arg2].Mount = {}
      end

      local _tmp = nil
      for k,v in pairs(mountcolors) do
        _tmp = string.match(color, v)
        if _tmp ~= nil then break end
      end

      if _tmp ~= nil then
        if GlimmUI_Character.GuildRequests[arg2].Mount[_tmp] then
          SendChatMessage("You already have this color set.", "WHISPER", "COMMON", arg2)
          return
        else
          GlimmUI_Character.GuildRequests[arg2].Mount[_tmp] = true
          SendChatMessage("Mount preference set: ".._tmp.." (!unsetcolor color to undo)", "WHISPER", "COMMON", arg2)
        end
      else
        SendChatMessage("Invalid color selection (Blue, Yellow, Red, Green)", "WHISPER", "COMMON", arg2)
      end
    elseif string.match(arg1, "!UNSETCOLOR") then
      local tt,color = strsplit(" ", arg1)
      if GlimmUI_Character.GuildRequests[arg2].Mount[color] then
        GlimmUI_Character.GuildRequests[arg2].Mount[color] = nil
        SendChatMessage("You have been removed from the "..color.." pool.", "WHISPER", "COMMON", arg2)
      else
        SendChatMessage("You do not have "..color.." set. (Nothing happens.)", "WHISPER", "COMMON", arg2)
        end
      end
    end
end)
