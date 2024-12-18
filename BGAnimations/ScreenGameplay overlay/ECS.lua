local player = ...
local profile_name = PROFILEMAN:GetPlayerName(player)
local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)

local CreateScoreFile = function(day, month_string, year, seconds, hour, minute, second)
	-- Don't write any files in a practice set.
	if ECS.IsPractice then return end

	local passed_song = pss:GetFailed() and "Failed" or "Passed"

	local dance_points = pss:GetPercentDancePoints()
	local percent_score = FormatPercentScore( dance_points ):sub(1,-2):gsub(" ", "")

	local song = GAMESTATE:GetCurrentSong()
	local group_name = song:GetGroupName()
	local song_name = song:GetMainTitle()
	local music_rate = GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred"):MusicRate() or 1
	music_rate = string.format("%.2f", music_rate)

	if not IsPlayingFromPackForDivision() and not IsPlayingMarathon() then return end

	local attempt_number = ECS.Mode == "Speed" and ECS.SpeedAttemptNumber or 0

	-- ----------------------------------------------------------
	local base_theme_path = THEME:GetCurrentThemeDirectory()
	local path = base_theme_path.."ECSData/"..day..month_string..year.."-"..seconds.."-"..ECS.Players[profile_name].id.."-".."SCORE-"..ECS.Mode.."-"..attempt_number..".txt"

	local data = ""
	data = data..percent_score .."\n"
	data = data..passed_song.."\n"
	data = data..group_name.."\n"
	data = data..song_name.."\n"
	data = data..day.." "..month_string.." "..year.."\n"
	data = data..hour..":"..minute..":"..second.."\n"
	data = data..music_rate.."\n"

	local f = RageFileUtil.CreateRageFile()

	if f:Open(path, 2) then
		f:Write( data )
	else
		local fError = f:GetError()
		SM("There was some kind of error writing your score to disk.  You should let Archi know.")
		Trace( "[FileUtils] Error writing to ".. path ..": ".. fError )
		f:ClearError()
	end

	f:destroy()
end

local CreateRelicFile = function(day, month_string, year, seconds)
	-- Don't write any files in a practice set.
	if ECS.IsPractice then return end

	local song = GAMESTATE:GetCurrentSong()
	local group_name = song:GetGroupName()

	if not IsPlayingFromPackForDivision() and not IsPlayingMarathon() then return end

	local attempt_number = ECS.Mode == "Speed" and ECS.SpeedAttemptNumber or 0

	local base_theme_path = THEME:GetCurrentThemeDirectory()
	local path = base_theme_path.."ECSData/"..day..month_string..year.."-"..seconds.."-"..ECS.Players[profile_name].id.."-".."RELIC-"..ECS.Mode.."-"..attempt_number..".txt"
	local data = ""

	for i=1, 5 do
		local relic = ECS.Player.Relics[i]
		--local name = relic and relic.name or "*"
		local name = "*"
		if relic then
			-- Only do drops for Great Power since it has BP, and rename it back to Dragonball.
			local adjusted_name = relic.name
			if relic.name:match("^Dragonball") then
				if relic.name == "Dragonball - Great Power" then
					adjusted_name = "Dragonball"
				else
					adjusted_name = "*"
				end
			end

			name = adjusted_name
		end

		data = data .. name .. "\n"
	end

	local f = RageFileUtil.CreateRageFile()

	if f:Open(path, 2) then
		f:Write( data )
	else
		local fError = f:GetError()
		SM("There was some kind of error writing your score to disk.  You should let Archi know.")
		Trace( "[FileUtils] Error writing to ".. path ..": ".. fError )
		f:ClearError()
	end

	f:destroy()
end

-- ----------------------------------------------------------
local WriteRelicDataToDisk = function()
	-- Don't write any files in a practice set.
	if ECS.IsPractice then return end

	-- Speed doesn't use relics so nothing to write.
	if ECS.Mode == "Speed" then return end

	local p = PlayerNumber:Reverse()[GAMESTATE:GetMasterPlayerNumber()] + 1
	local profile_dir = PROFILEMAN:GetProfileDir("ProfileSlot_Player"..p)

	if profile_dir then

		local s = "return {\n"
		for relic in ivalues(ECS.Players[profile_name].relics) do
			if relic.quantity then
				s = s .. "\t{name=\"" .. relic.name .. "\", quantity=" .. relic.quantity .."},\n"
			else
				s = s .. "\t{name=\"" .. relic.name .. "\"},\n"
			end
		end
		s = s .. "}"


		local f = RageFileUtil.CreateRageFile()
		local path = profile_dir .. THEME:GetThemeDisplayName() .. "_Player_Relic_Data.lua"

		if f:Open(path, 2) then
			f:Write( s )
		else
			local fError = f:GetError()
			Trace( "[FileUtils] Error writing to ".. path ..": ".. fError )
			f:ClearError()
		end

		f:destroy()
	end
end

-- ----------------------------------------------------------

local ExpendChargesOnActiveRelics = function()
	for relic in ivalues(ECS.Players[profile_name].relics) do
		for active_relic in ivalues(ECS.Player.Relics) do
			local name = active_relic.name
			if name:match("^Dragonball") then
				name = "Dragonball"
			end

			if name == relic.name and active_relic.is_consumable and relic.quantity > 0 then
				relic.quantity = relic.quantity - 1
			end
		end
	end
end

-- ----------------------------------------------------------

local RestoreChargesForNonWrapperRelics = function()
	for relic in ivalues(ECS.Players[profile_name].relics) do
		for active_relic in ivalues(ECS.Player.Relics) do
			local name = active_relic.name
			if name:match("^Dragonball") then
				name = "Dragonball"
			end
			if name == relic.name and relic.name ~= "Wrapper" and active_relic.is_consumable then
				relic.quantity = relic.quantity + 1
			end
		end
	end
end

-- ----------------------------------------------------------

local ApplyRelicActions = function()
	for active_relic in ivalues(ECS.Player.Relics) do
		if active_relic.name == "Xynn's Mix Tape" and GetQuantityForRelic(active_relic.name) > 0 then
			-- Don't want to run into an infinite loop so use the MixTapesUsed flag.
			-- Handle this first so that we can reload immediately before applying any
			-- other relics.
			if ECS.Player.MixTapesRandomSong == nil then
				local song = GAMESTATE:GetCurrentSong()
				local group = song:GetGroupName()
				local all_songs = SONGMAN:GetSongsInGroup(group)
				local random_song = all_songs[math.random(#all_songs)]

				ECS.Player.MixTapesRandomSong = random_song

				SCREENMAN:GetTopScreen():SetNextScreenName("ScreenSelectMusic")
				SCREENMAN:GetTopScreen():StartTransitioningScreen("SM_GoToNextScreen")
			else
				ECS.Player.MixTapesRandomSong = nil
			end
		end
	end

	for active_relic in ivalues(ECS.Player.Relics) do
		if not active_relic.is_consumable or GetQuantityForRelic(active_relic.name) > 0 then
			active_relic.action(ECS.Player.Relics)
		end
	end
end

-- ----------------------------------------------------------
-- actually hook into the screen so that we can do thing at screen's OnCommand and OffCommand
local af = Def.ActorFrame{}
af[#af+1] = Def.Actor{
	HealthStateChangedMessageCommand=function(self, params)
		if params.PlayerNumber == player and params.HealthState == "HealthState_Dead" and ECS.Player.WrapperActive then
			if ECS.Player.MixTapesRandomSong == nil then
				-- Consume the wrapper.
				ECS.Player.WrapperActive = false
				RestoreChargesForNonWrapperRelics()
				SCREENMAN:GetTopScreen():SetPrevScreenName("ScreenGameplay"):SetNextScreenName("ScreenGameplay"):begin_backing_out()
			end
		end
	end,
	OnCommand=function(self)
		-- Speed mode doesn't have relics, but the functions are still safe to call.
		if ECS.Mode == "ECS" or ECS.Mode == "Speed" or ECS.Mode == "Marathon" then
			-- relic actions depend on the current screen,
			-- so ApplyRelicActions() must be called from OnCommand
			
			ApplyRelicActions()
			
			if ECS.Player.MixTapesRandomSong == nil then
				ExpendChargesOnActiveRelics()
			end
		end
	end,
	OffCommand=function(self)
		-- Speed mode doesn't have relics, but the functions are still safe to call.
		if ECS.Mode == "ECS" or ECS.Mode == "Speed" or ECS.Mode == "Marathon" then
			local year, month, day = Year(), MonthOfYear() + 1, DayOfMonth()
			local hour, minute, second = Hour(), Minute(), Second()
			local seconds = (hour*60*60) + (minute*60) + second
			local month_string = THEME:GetString("Months", "Month"..month)

			-- Check if player has failed.
			local failed = pss:GetFailed()

			-- The cases where we don't want to write a score file are:
			-- 1. The player is about to play a random song from a mixtape OR
			-- 2. The player has Wrappers active and has failed (they will restart).
			if not (ECS.Player.MixTapesRandomSong ~= nil or (ECS.Player.WrapperActive and failed)) then
				CreateScoreFile(day, month_string, year, seconds, hour, minute, second)
				CreateRelicFile(day, month_string, year, seconds)
				WriteRelicDataToDisk()
			end

			-- We can always reset the Wrapper status (when we're not about to random a song).
			if ECS.Player.MixTapesRandomSong == nil and ECS.Player.WrapperActive then
				ECS.Player.WrapperActive = false
			end
		end
	end
}

-- -----------------------------------------------------------------------
local mmss = "%d:%02d"

local SecondsToMMSS = function(s)
	-- native floor division sounds nice but isn't available in Lua 5.1
	local mins  = math.floor((s % 3600) / 60)
	local secs  = s - (mins * 60)
	return mmss:format(mins, secs)
end

local FaustsScalpelIsActive = function()
	for active_relic in ivalues(ECS.Player.Relics) do
		if active_relic.name == "Faust's Scalpel" then
			return true
		end
	end
	return false
end

local SeaRingIsActive = function()
	for active_relic in ivalues(ECS.Player.Relics) do
		if active_relic.name == "Sea Ring" then
			return true
		end
	end
	return false
end

local NurseJoyPlushIsActive = function()
	for active_relic in ivalues(ECS.Player.Relics) do
		if active_relic.name == "Nurse Joy Plush" then
			return true
		end
	end
	return false
end

local DaggerOfTimeIsActive = function()
	for active_relic in ivalues(ECS.Player.Relics) do
		if active_relic.name == "Dagger of Time" then
			return true
		end
	end
	return false
end

if SeaRingIsActive() then
	local dirTime = 2

	local textureWidth = 1280
	local textureHeight = 96
	local zoom = 0.5
	local bodyHeight = SCREEN_HEIGHT / zoom

	local numTextures = 3

	local songLength = GAMESTATE:GetCurrentSong():MusicLengthSeconds() / SL.Global.ActiveModifiers.MusicRate
	local loops = math.ceil(songLength / dirTime)
	
	local totalHeight = SCREEN_HEIGHT + textureHeight / 2

	-- We want to go up and down, but down shouldn't go as far as up since we
	-- want the level to rise throughout the chart.
	-- It should scale totalHeight with the number of loops.
	local upChange = -totalHeight / (loops / 4)
	local downChange = -upChange / 2

	local maxShift = 3
	local curShift = 0
	local shiftOffset = 25

	local seaLevels = Def.ActorFrame{
		InitCommand=function(self)
			self:xy(SCREEN_CENTER_X, totalHeight):zoom(zoom)
		end,

		OnCommand=function(self)
			self:queuecommand("GoUp")
		end,

		GoUpCommand=function(self)
			local x = curShift
			if x == -1 * maxShift then
				x = x + 1
			elseif x == maxShift then
				x = x - 1
			else
				local rand = math.random(0, 1)
				if rand == 0 then rand = -1 end
				x = rand + x
			end
			curShift = x

			self:spring(dirTime):x(shiftOffset * x):addy(upChange):queuecommand("GoDown")
		end,

		GoDownCommand=function(self)
			local x = curShift
			if x == -1 * maxShift then
				x = x + 1
			elseif x == maxShift then
				x = x - 1
			else
				local rand = math.random(0, 1)
				if rand == 0 then rand = -1 end
				x = rand + x
			end
			curShift = x


			self:spring(dirTime):x(shiftOffset * x):addy(downChange):queuecommand("GoUp")
		end,
		
		Def.Quad{
			InitCommand=function(self)
				-- Take me out of heeeerrreeeee
				local waterColour = "#0072FF"
				local alpha = 0.6

				self:SetWidth(textureWidth*numTextures)
						:SetHeight(bodyHeight)
						:diffusetopedge(0, 0.445313, 1, alpha)
						:diffusebottomedge(0, 0.445313, 1, 1)
						:y(textureHeight/2 + bodyHeight/2 + 1)
			end,
		},

		-- Add some padding at the end.
		Def.Quad{
			InitCommand=function(self)
				self:SetWidth(textureWidth*numTextures)
						:SetHeight(bodyHeight)
						:diffuse(color("0,0.445313,1"))
						:y(textureHeight/2 + bodyHeight/2 + bodyHeight + 1)
			end,
		},
	}

	for i=1,numTextures do
		local offset = ((numTextures - 1) / 2 + (i - numTextures)) * textureWidth

		seaLevels[#seaLevels+1] = Def.Sprite{
			Texture=THEME:GetPathG("","_ECS/sealevel.png"),
			InitCommand=function(self)
				self:x(offset)
			end,
		}
	end

	af[#af+1] = seaLevels
end

if NurseJoyPlushIsActive() then
	local lifeHitCount = 5
	af[#af+1] = Def.ActorFrame{
		LifeChangedMessageCommand=function(self, params)
			if params.Player == player and lifeHitCount ~= 0 and params.LifeMeter:GetLife() < 1.0 then
				local pn = ToEnumShortString(player)
				if SCREENMAN:GetTopScreen() then
					local player_af = SCREENMAN:GetTopScreen():GetChild("Player"..pn)
					if player_af then
						player_af:SetLife(1.0)
						lifeHitCount = lifeHitCount - 1
					end
				end
			end
		end,
	}
end

if IsPlayingMarathon() then
	af[#af+1] = Def.ActorFrame{
		OnCommand=function(self)
			-- Force 1.0x for music rate if dagger not active.
			-- It's possible for dagger to be available but the player not opting to
			-- use it, so the music rate selector will be available but we want to
			-- ensure the players actually play on 1.0x.
			if not DaggerOfTimeIsActive() then
				GAMESTATE:ApplyGameCommand("mod,1.0xmusic")
				SL.Global.ActiveModifiers.MusicRate = 1
			end

			ECS.Player.MarathonRateMod = SL.Global.ActiveModifiers.MusicRate
		end
	}
end

local second_to_pause = {
	["lower"] = 1835.285,
	["mid"] = 1499.724243,
	["upper"] = 1843.990967,
}

local pause_duration_seconds = 300
local elapsed_seconds = 0

local InputHandler = function(event)
	if not event.PlayerNumber or not event.button then return false end

	MESSAGEMAN:Broadcast("TestInputEvent", event)

	if event.type == "InputEventType_FirstPress" and event.GameButton == "Start" then
		MESSAGEMAN:Broadcast("UnpauseMarathon")
	end

	return false
end

if ECS.Mode == "Marathon" and FaustsScalpelIsActive() and IsPlayingMarathon() then
	af[#af+1] = Def.ActorFrame{
		InitCommand=function(self) end,
		OnCommand=function(self) SCREENMAN:GetTopScreen():AddInputCallback( InputHandler ) self:queuecommand("Loop") end,
		LoopCommand=function(self)
			if GAMESTATE:GetNumPlayersEnabled() == 1 then
				-- We don't need to divide by rate since we always want the break to happen in the same spot regardless.
				local cur_second = GAMESTATE:GetPlayerState(player):GetSongPosition():GetMusicSeconds()
				if cur_second >= second_to_pause[GetDivision()] then
					self:queuecommand("PauseMarathon")
				else
					self:sleep(0.1):queuecommand("Loop")
				end
			end
		end,
		PauseMarathonCommand=function(self)
			SCREENMAN:GetTopScreen():PauseGame(true)
			self:queuecommand("Wait")
		end,
		WaitCommand=function(self)
			if SCREENMAN:GetTopScreen():IsPaused() then
				elapsed_seconds = elapsed_seconds + 1
				if elapsed_seconds < pause_duration_seconds then
					self:sleep(1):queuecommand("Wait")
				else
					MESSAGEMAN:Broadcast("UnpauseMarathon")
				end
			end
		end,
		UnpauseMarathonMessageCommand=function(self)
			if SCREENMAN:GetTopScreen():IsPaused() then
				SCREENMAN:GetTopScreen():PauseGame(false)
			end
		end,

		Def.ActorFrame {
			InitCommand=function(self) self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y-70):visible(false) end,
			WaitCommand=function(self)
				if SCREENMAN:GetTopScreen():IsPaused() then
					self:visible(true)
				end
			end,
			UnpauseCommand=function(self) self:visible(false) end,
			-- slightly darken the entire screen
			Def.Quad {
				InitCommand=function(self) self:FullScreen():diffuse(Color.Black):diffusealpha(0.4) end
			},
			Def.Quad {
				InitCommand=function(self) self:diffuse(Color.White):zoomto(202, 202) end
			},
			Def.Quad {
				InitCommand=function(self) self:diffuse(Color.Black):zoomto(200, 200) end
			},
			LoadFont("Common Normal")..{
				InitCommand=function(self)
					local text = "You may end your break time early by pressing the &START; button"
					self:y(40):wrapwidthpixels(200):settext(text)
				end,
			},
			LoadActor( THEME:GetPathB("", "_modules/TestInput Pad/default.lua"), {Player=player, ShowMenuButtons=false, ShowPlayerLabel=false})..{
				InitCommand=function(self)
					self:zoom(0.8):y(260)
				end,
			}
		},

		LoadFont("Common Normal")..{
			InitCommand=function(self)
				local w = SL_WideScale(310, 417)
				self:horizalign(left):xy(_screen.cx + w/2 + 105, 20)
			end,
			LoopCommand=function(self)
				local cur_second = GAMESTATE:GetPlayerState(player):GetSongPosition():GetMusicSeconds()
				if cur_second > 0 then
					if cur_second < second_to_pause[GetDivision()] then
						self:settext(SecondsToMMSS((second_to_pause[GetDivision()] - cur_second + 1)/SL.Global.ActiveModifiers.MusicRate))
					end
				end
			end,
			WaitCommand=function(self)
				local remaining_pause_duration = pause_duration_seconds - elapsed_seconds + 1
				self:horizalign(center):xy(SCREEN_CENTER_X, SCREEN_CENTER_Y-95)
				if remaining_pause_duration >= 0 then
					if remaining_pause_duration <= 5 then
						self:diffuse(color("#ff3030"))
					end
					self:settext(SecondsToMMSS(remaining_pause_duration))
				end
			end,
			UnpauseMarathonMessageCommand=function(self)
				self:visible(false)
			end,
		},
		LoadFont("Common Normal")..{
			InitCommand=function(self)
				local w = SL_WideScale(310, 417)
				self:horizalign(right):xy(_screen.cx + w/2 + 95, 20):settext("Pausing in:"):visible(true)
			end,
			WaitCommand=function(self)
				self:horizalign(center):xy(SCREEN_CENTER_X, SCREEN_CENTER_Y-120)
				self:settext("Unpausing in:")
			end,
			UnpauseMarathonMessageCommand=function(self)
				self:visible(false)
			end,
		},
	}
end

return af