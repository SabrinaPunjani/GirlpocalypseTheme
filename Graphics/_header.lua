-- tables of rgba values
local dark  = {0,0,0,0.9}
local light = {0.65,0.65,0.65,1}


local ArvinsGambitIsActive = function()
	for active_relic in ivalues(ECS.Player.Relics) do
		if active_relic.name == "Arvin's Gambit" then
			return true
		end
	end
	return false
end

if ArvinsGambitIsActive() then
	ECS.SetTimer = 20 * 60
end

local endgame_warning_has_been_issued = false

local breaktimer_at_screen_start = 0
local seconds_at_screen_start = 0

local sessiontimer_actor
local breaktimer_actor

-- roll our own SecondsToMMSS() because SM's bundled
-- helper doesn't handle negative time correctly :)
local SecondsToMMSS = function(seconds)
	local minutes
	if seconds >= 0 then
		minutes = string.format("%02d", math.floor(seconds / 60))
	else
		minutes = string.format("%02d", math.ceil(seconds / 60))
	end

	local seconds = string.format("%02d", math.floor(math.abs(seconds) % 60))
	return minutes..":"..seconds
end

local SessionHasEnded = function(session_seconds)
	if (ECS.Mode == "ECS" or ECS.Mode == "Speed") and ECS.BreakTimer < 0 then return true end

	if SL.Global.TimeAtSessionStart
		and (session_seconds > ECS.SetTimer)
		and (ECS.Mode == "Warmup" or
			 ((ECS.Mode == "ECS" or ECS.Mode == "Speed") and SL.Global.Stages.PlayedThisGame >= 7) or
			 ArvinsGambitIsActive())
	then
		return true
	end

	return false
end

local InputHandler = function(event)
	if not event.PlayerNumber or not event.button then return false end

	if event.type == "InputEventType_FirstPress" and event.GameButton == "Start" then
		MESSAGEMAN:Broadcast("FadeOutWarning")
	end

	return false
end

local DeductFromBreakTimer = function()
	if ECS.Mode == "Warmup" then return false end

	local screen_name = SCREENMAN:GetTopScreen():GetName()

	if screen_name == "ScreenSelectMusic"
	or screen_name == "ScreenPlayerOptions"
	or screen_name == "ScreenPlayerOptions2"
	or screen_name == "ScreenEquipRelics"
	or screen_name == "ScreenEvaluationStage" then
		return true
	end

	return false
end

local Update = function(af, dt)
	if SL.Global.TimeAtSessionStart ~= nil then
		local cur_time = GetTimeSinceStart()
		local session_seconds = cur_time - SL.Global.TimeAtSessionStart

		-- if this game session is less than 1 hour in duration so far
		if session_seconds < ECS.SetTimer then
			sessiontimer_actor:settext( "SET - " .. SecondsToMMSS(session_seconds) )
		else
			sessiontimer_actor:settext( "SET - " .. SecondsToHHMMSS(session_seconds) ):diffuse(1,0,0,1)
		end

		if DeductFromBreakTimer() then
			if ECS.TimeToRemoveFromBreakTimer ~= 0 then
				local mpn = GAMESTATE:GetMasterPlayerNumber()
				local stats = STATSMAN:GetCurStageStats():GetPlayerStageStats(mpn)
				local failed = stats:GetFailed()

				if SCREENMAN:GetTopScreen():GetName() == "ScreenEvaluationStage" and failed or
					SCREENMAN:GetTopScreen():GetName() == "ScreenSelectMusic" and
					ECS.Player.MixTapesRandomSong == nil then
					SM(SecondsToMSS(ECS.TimeToRemoveFromBreakTimer).." removed from Break Timer")
					-- Adjust the breaktimer_at_screen_start value to account for the time removed
					breaktimer_at_screen_start = breaktimer_at_screen_start - ECS.TimeToRemoveFromBreakTimer
				end
				ECS.TimeToRemoveFromBreakTimer = 0
			end

			ECS.BreakTimer = breaktimer_at_screen_start - (cur_time - seconds_at_screen_start)
		end

		if breaktimer_actor then
			breaktimer_actor:settext( "BREAK - " .. SecondsToMMSS(ECS.BreakTimer) )

			-- BREAK'S OVER
			if ECS.BreakTimer < 0 then
				breaktimer_actor:diffuse(1,0,0,1)
			end
		end

		if SessionHasEnded(session_seconds) and (not endgame_warning_has_been_issued) then
			if SCREENMAN:GetTopScreen():GetName() == "ScreenGameplay" then
				if ECS.Mode == "Warmup" then
					-- Force users out of screen gameplay if their warmup timer has ended.
					SCREENMAN:GetTopScreen():PostScreenMessage("SM_BeginFailed", 0)
				end
			elseif SCREENMAN:GetTopScreen():GetName() == "ScreenSelectMusic" then
				endgame_warning_has_been_issued = true
				af:queuecommand("SessionHasEnded")
			end
		end
	end
end

local af = Def.ActorFrame{
	Name="Header",
	InitCommand=function(self) self:queuecommand("PostInit") end,
	PostInitCommand=function(self)
		-- Setup session timer for ECS, Speed, Warmup, and Marathon (only if it's the second attempt).
		if PREFSMAN:GetPreference("EventMode") and (ECS.Mode == "ECS" or ECS.Mode == "Speed" or ECS.Mode == "Warmup" or (ECS.Mode == "Marathon" and ArvinsGambitIsActive())) then
			-- TimeAtSessionStart will be reset to nil between game sessions
			-- thus, if it's currently nil, we're loading ScreenSelectMusic
			-- for the first time this particular game session
			local start_time = GetTimeSinceStart()
			if SCREENMAN:GetTopScreen():GetName() == "ScreenSelectMusic" and SL.Global.TimeAtSessionStart == nil then
				SL.Global.TimeAtSessionStart = start_time
			end

			breaktimer_at_screen_start = ECS.BreakTimer
			seconds_at_screen_start = start_time

			if SL.Global.TimeAtSessionStart ~= nil then
				self:SetUpdateFunction( Update )
			end
		end
	end,

	Def.Quad{
		InitCommand=function(self)
			self:zoomto(_screen.w, 32):vertalign(top):x(_screen.cx)
			if ThemePrefs.Get("VisualStyle") == "SRPG8" then
				self:diffuse(GetCurrentColor(true))
			elseif DarkUI() then
				self:diffuse(dark)
			elseif ThemePrefs.Get("VisualStyle") == "Technique" then
				self:diffusealpha(0)
			else
				self:diffuse(light)
			end
		end,
		ScreenChangedMessageCommand=function(self)
			local topscreen = SCREENMAN:GetTopScreen():GetName()
			if SL.Global.GameMode == "Casual" and (topscreen == "ScreenEvaluationStage" or topscreen == "ScreenEvaluationSummary") then
				self:diffuse(dark)
			end
			if ThemePrefs.Get("VisualStyle") == "SRPG8" then
				self:diffuse(GetCurrentColor(true))
			end
			if ThemePrefs.Get("VisualStyle") == "Technique" then
				if topscreen == "ScreenSelectMusic" and not ThemePrefs.Get("RainbowMode") then
					self:diffuse(0, 0, 0, 0.5)
				else
					self:diffusealpha(0)
				end
			end
			self:visible(topscreen ~= "ScreenCRTTestPatterns")
		end,
		ColorSelectedMessageCommand=function(self)
			if ThemePrefs.Get("VisualStyle") == "SRPG8" then
				self:diffuse(GetCurrentColor(true))
			end
		end,
		VisualStyleSelectedMessageCommand=function(self)
			if ThemePrefs.Get("VisualStyle") == "Technique" then
				self:diffusealpha(0)
			end
		end,
	},

	LoadFont("Common Header")..{
		Name="HeaderText",
		Text=ScreenString("HeaderText"),
		InitCommand=function(self) self:diffusealpha(0):horizalign(left):xy(10, 15):zoom( SL_WideScale(0.5,0.6) ) end,
		OnCommand=function(self) self:sleep(0.1):decelerate(0.33):diffusealpha(1) end,
		OffCommand=function(self) self:accelerate(0.33):diffusealpha(0) end,
		SetHeaderTextMessageCommand=function(self, params)
			self:settext(params.Text)
		end,
		ResetHeaderTextMessageCommand=function(self)
			self:settext(THEME:GetString(SCREENMAN:GetTopScreen():GetName(), "HeaderText"))
		end
	},

	-- Freeplay | Warmup | PracticeSet | ECS | Marathon
	LoadFont("Wendy/_wendy small")..{
		Name="GameModeText",
		InitCommand=function(self)
			self:diffusealpha(0):zoom( WideScale(0.5,0.6)):xy(_screen.w-70, 15):halign(1)
			if not PREFSMAN:GetPreference("MenuTimer") then
				self:x(_screen.w-10)
			end
		end,
		OnCommand=function(self)
			local screen_name = SCREENMAN:GetTopScreen():GetName()

			if screen_name == "ScreenSelectMusic"
			or screen_name == "ScreenEquipRelics"
			or screen_name == "ScreenPlayerOptions"
			or screen_name == "ScreenPlayerOptions2"
			or screen_name == "ScreenEvaluationStage"
			or screen_name == "ScreenEvaluationSummary"
			then
				self:settext(THEME:GetString("ScreenSelectPlayMode", ECS.Mode))
				self:sleep(0.1):decelerate(0.33):diffusealpha(1)
			end
		end,
		UpdateHeaderTextCommand=function(self)
			self:settext(THEME:GetString("ScreenSelectPlayMode", ECS.Mode))
		end
	}
}

-- Display session timer for ECS, Speed, Warmup, and Marathon (only if it's the second attempt).
if (ECS.Mode == "ECS" or ECS.Mode == "Speed" or ECS.Mode == "Warmup" or (ECS.Mode == "Marathon" and ArvinsGambitIsActive())) then
	af[#af+1] = Def.ActorFrame{
		OnCommand=function(self)
			local screen_name = SCREENMAN:GetTopScreen():GetName()
			if screen_name == "ScreenEvaluationSummary"	then
				self:visible(false)
			end
		end,

		-- Session Timer
		LoadFont("Wendy/_wendy small")..{
			Name="SessionTimer",
			InitCommand=function(self)
				sessiontimer_actor = self
				self:diffusealpha(0):zoom( WideScale(0.5,0.6) ):xy(_screen.cx-100, 15):halign(0)
			end,
			OnCommand=function(self)
				if not PREFSMAN:GetPreference("EventMode") then
					self:settext( SSM_Header_StageText() )
				end

				self:sleep(0.1):decelerate(0.33):diffusealpha(1)
			end,
		},
	}

	-- Only add BreakTimer in ECS/Speed Mode.
	if ECS.Mode == "ECS" or ECS.Mode == "Speed" then
		-- Break Timer
		af[#af+1] = LoadFont("Wendy/_wendy small")..{
			Name="BreakTimer",
			InitCommand=function(self)
				breaktimer_actor = self
				self:diffusealpha(0):zoom( WideScale(0.5,0.6) ):xy(_screen.cx+80, 15):halign(0)
			end,
			OnCommand=function(self)
				if not PREFSMAN:GetPreference("EventMode") then
					self:settext( SSM_Header_StageText() )
				end

				self:sleep(0.1):decelerate(0.33):diffusealpha(1)
			end,
		}
	end

	-- SessionHasEnded warning
	af[#af+1] = Def.ActorFrame{
		InitCommand=function(self) self:visible(false):diffusealpha(0) end,
		SessionHasEndedCommand=function(self)
			for player in ivalues(GAMESTATE:GetHumanPlayers()) do
				SCREENMAN:set_input_redirected(player, true)
			end
			SCREENMAN:GetTopScreen():AddInputCallback( InputHandler )
			self:visible(true):linear(0.15):diffusealpha(1)
		end,
		FadeOutWarningMessageCommand=function(self) self:linear(0.15):diffusealpha(0):queuecommand("Hide") end,
		HideCommand=function(self)
			SCREENMAN:GetTopScreen():RemoveInputCallback(InputHandler)
			for player in ivalues(GAMESTATE:GetHumanPlayers()) do
				SCREENMAN:set_input_redirected(player, false)
			end
			self:visible(false)
		end,

		Def.Quad{
			InitCommand=function(self) self:diffuse(0,0,0,0.925):FullScreen():Center() end
		},

		LoadFont("Miso/_miso")..{
			InitCommand=function(self) self:xy(_screen.cx, 200):wrapwidthpixels(380/1.5):zoom(1.5) end,
			SessionHasEndedCommand=function(self)
				local s = ""
				if ECS.Mode == "Marathon" then
					s = s .. "That's all the time you get to warmup and fix the pads bud. Hopefully you'll do a better job this time around.\n\n"
					s = s .. "Please press &START; to dismiss this message, then restart the marathon."
				else
					s = "Your " .. ECS.Mode .. " session has ended because you"
					if ECS.Mode == "ECS" or ECS.Mode == "Speed" then
						if ECS.BreakTimer < 0 then
							s = s .. " used up all your break time!\n\n"
						else
							s = s .. " played more than 7 songs and have exceeded your allotted set time!\n\n"
						end
					elseif ECS.Mode == "Warmup" then
						s = s .. "'ve played longer than 1 hour!\n\n"
					end

					s = s .. "Unless there are some extenuating circumstances that Ian has approved, it looks like your finished, bud.\n\n"
					s = s .. "Please press &START; to dismiss this message, then exit your set."
				end

				self:settext(s)
			end
		}
	}
end

return af