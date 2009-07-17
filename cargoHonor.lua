-- Short configuration
local hideMarks = nil	--[[	true: hides Marks of Honor tooltip information			 ]]
local hideWinLoss = nil	--[[	 true: hides Win/Loss statistics on tooltip				 ]]
local playerFaction = UnitFactionGroup("player")

local BGs = { "Alterac Valley", "Warsong Gulch", "Strand of the Ancients", "Arathi Basin", "Eye of the Storm",	-- Long form
			"Alterac", "Warsong", "SotA", "Arathi", "EotS" }	-- Short form
local achIDs = { 53, 52, 1549, 55, 54,	-- Total
				49, 105, 1550, 51, 50 }	-- Won
local itemIDs = { 20560, 20558, 42425, 20559, 29024 }

-- Get the suffix for the selected display
local getSuffix = function(i)
	return (i == 5 and "honor") or (i == 4 and " arena") or (i == 3 and " bg") or (i == 2 and " today") or " total"
end

-- Initializing the object and frame
local OnEvent = function(self, event, ...) self[event](self, event, ...) end
local dataobj = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("cargoHonor", {
	type = "data source",
	text = "0 total",
	value = "0",
	icon = "Interface\\AddOns\\cargoHonor\\"..playerFaction.."Icon",
	suffix = " total",
})
local frame = CreateFrame"Frame"

-- Print the next bg weekend and if it's currently active
local function GetCurrentNextWeekend()
	local now = date("*t")
	local week = floor(now.yday/7)+1
	if(now.wday == 3) then week = week +1 end
	week = (week + 2) % 5
	return week > 0 and week or 5, now.wday > 5 or now.wday < 3
end

-- Color function for Marks of Honor
local function ColorGradient(perc, r1, g1, b1, r2, g2, b2, r3, g3, b3)
	if perc >= 1 then return r3, g3, b3 elseif perc <= 0 then return r1, g1, b1 end

	local segment, relperc = math.modf(perc*2)
	if segment == 1 then r1, g1, b1, r2, g2, b2 = r2, g2, b2, r3, g3, b3 end
	return r1 + (r2-r1)*relperc, g1 + (g2-g1)*relperc, b1 + (b2-b1)*relperc
end

-- Get percent, win total info by battleground id
local function GetWinTotal(id)
	local total, won
	if(not id) then
		total, won = GetStatistic(839), GetStatistic(840)
	else
		total, won = GetStatistic(achIDs[id]), GetStatistic(achIDs[id+5])
	end
	if(total == "--") then total = 0 else total = tonumber(total) end
	if(won == "--") then won = 0 else won = tonumber(won) end
	
	return total > 0 and won/total, won, total
end

-- [[    Update the display !    ]] --
local session, total, startTime
local startHonor, isBG
function frame:HONOR_CURRENCY_UPDATE()
	if(cargoHonor.displ == 5) then
		local string = ""
		if(isBG) then
			string = string..(select(2, GetPVPSessionStats()) - startHonor or 0).. " | "
		end
		string = string..select(2, GetPVPSessionStats()).." | "..GetHonorCurrency().." "
		dataobj.value = string
	elseif(cargoHonor.displ == 4) then
		dataobj.value =  GetArenaCurrency()
	elseif(cargoHonor.displ == 3) then
		if(startHonor) then
			dataobj.value = select(2, GetPVPSessionStats()) - startHonor or 0
		else
			dataobj.value = 0
		end
	elseif(cargoHonor.displ == 2) then
		dataobj.value = select(2, GetPVPSessionStats())
	else
		dataobj.value = GetHonorCurrency()
	end
	dataobj.text = dataobj.value.." "..dataobj.suffix
end

--[[   Initialize all variables    ]] --
function frame:PLAYER_ENTERING_WORLD()
	if(not cargoHonor) then cargoHonor = {} end
	session = select(2, GetPVPSessionStats())
	if(startHonor and isBG) then
		cargoHonor.LastBG = session - startHonor
	end
	startHonor = session
	isBG = (select(2, IsInInstance()) =="pvp")
	if(isBG) then
		if(not startTime) then startTime = time() end
		if(not startSession) then startSession = session end
	end
	if(cargoHonor.displ == 4) then dataobj.icon = [[Interface\PVPFrame\PVP-ArenaPoints-Icon]] end
	self:HONOR_CURRENCY_UPDATE()
end

frame:SetScript("OnEvent", OnEvent)
frame:RegisterEvent"HONOR_CURRENCY_UPDATE"
frame:RegisterEvent"PLAYER_ENTERING_WORLD"

-- [[   The tooltip  ]] --
function dataobj.OnTooltipShow(tooltip)
	local id, isWeek = GetCurrentNextWeekend()
	session = select(2, GetPVPSessionStats())
	total = GetHonorCurrency()
	local perHour
	if(startTime) then perHour = (session-startSession)/((time()-startTime)/3600) end
	
	tooltip:AddDoubleLine(total.." Honor", isWeek and BGs[id+5], 0,1,0, 0,1,0)
	tooltip:AddDoubleLine("Today:", string.format("|cff00ff00%i|r (|cff00ff00%i|r/h)", session, perHour or 0), 1,1,1, 1,1,1)
	if(isBG and startHonor) then
		tooltip:AddDoubleLine("This BG:", session-startHonor, 1,1,1, 0,1,0)
	end
	if(cargoHonor and cargoHonor.LastBG) then
		tooltip:AddDoubleLine("Last BG:", cargoHonor.LastBG, 1,1,1, 0,1,0)
	end
	tooltip:AddDoubleLine("Arena points:", GetArenaCurrency(), 1,1,1, 0,1,0)
	if(isWeek) then
		id = id+1
		id = (id == 6) and 1 or id
	end
	tooltip:AddDoubleLine("Next weekend:", BGs[id+5], 1,1,1, 1,1,1)

	if(not hideMarks) then
		tooltip:AddLine(" ")
		tooltip:AddLine("Marks of Honor")
		local marks
		for i=1, 5 do
			marks = GetItemCount(itemIDs[i], true)
			if(marks > 0) then
				tooltip:AddDoubleLine(BGs[i], marks, 1,1,1, ColorGradient(marks/100, 1,0,0, 1,1,0, 0,1,0))
			end
		end
	end
	local percent, win, total = GetWinTotal()
	if(not hideWinLoss and percent) then
		tooltip:AddLine(" ")
		tooltip:AddLine("Win/Loss Ratio")
		for i=1, 5 do
			percent, win, total = GetWinTotal(i)
			if(percent) then
				tooltip:AddDoubleLine(
					format("%dx %s:", total, BGs[i]),
					format("%.0f|cffffffff%%|r", percent*100),
					1,1,1, ColorGradient(percent, 1,0,0, 1,1,0, 0,1,0)
				)
			end
		end
	end
	tooltip:AddLine(" ")
	tooltip:AddLine("Click to toggle display")
	tooltip:AddLine("Right-click to open PvP-Panel")
end

function dataobj.OnClick(self, button)
	if(button == "RightButton") then
		ToggleFrame(PVPParentFrame)
	else
		cargoHonor.displ = (cargoHonor.displ == 5 and 1) or (cargoHonor.displ and cargoHonor.displ+1) or 2
		if(cargoHonor.displ == 4) then
			dataobj.icon = [[Interface\PVPFrame\PVP-ArenaPoints-Icon]]
		elseif(cargoHonor.displ == 1) then
			dataobj.icon = "Interface\\AddOns\\cargoHonor\\"..playerFaction.."Icon"
		end
		dataobj.suffix = getSuffix(cargoHonor.displ)
		frame:HONOR_CURRENCY_UPDATE()
	end
end