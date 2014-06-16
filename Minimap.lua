local addonName, addon, _ = 'Midget', {}
local pluginName = addonName..' Minimap'

-- GLOBALS: WORLD_MAP_SCENE, SCENE_MANAGER, CALLBACK_MANAGER, EVENT_ADD_ON_LOADED, SCENE_SHOWING, SCENE_HIDING, SCENE_HIDDEN, TOP, BOTTOM, TEXT_ALIGN_BOTTOM, TEXT_WRAP_MODE_ELLIPSIS, WORLD_MAP_FRAGMENT, MAP_MODE_LARGE_CUSTOM, MAP_MODE_SMALL_CUSTOM, MAP_CONTENT_DUNGEON
-- GLOBALS: ZO_SavedVars, ZO_WorldMap, ZO_WorldMapTitle, ZO_WorldMapTitleBarBG, ZO_WorldMapButtonsBG
-- GLOBALS: ZO_PreHook, ZO_PreHookHandler, ZO_WorldMap_OnResizeStop, ZO_WorldMap_GetMode, ZO_WorldMap_PanToPlayer, ZO_WorldMap_MouseDown, ZO_WorldMap_MouseUp, ZO_WorldMap_SetCustomZoomLevels, ZO_WorldMap_ToggleSize
-- GLOBALS: GetMapName, GetMapType, GetMapContentType
-- GLOBALS: zo_strsplit, zo_strjoin, pairs, tonumber, math
local LAM = LibStub('LibAddonMenu-2.0')
local LMP = LibStub('LibMediaProvider-1.0', true)

local em = GetEventManager()
local function Initialize(eventCode, arg1)
	if arg1 ~= addonName then return end
	em:UnregisterForEvent(pluginName, EVENT_ADD_ON_LOADED)

	-- settings
	local minimapDB = ZO_SavedVars:NewAccountWide(addonName..'DB', 1, 'minimap', {
		width = 200,
		height = 200, -- NOTE: ZO_WorldMap_PanToPlayer fails on non-square maps
		updateDelay = 0.2,
		showTitle = true,
		longTitles = 'anchor', -- or 'ellipsis'
		titleFont = 'ZoFontHeader2',
		zoom = 6, -- 1 = far, 9 = close
		dungeonZoom = 2,
	})


	local function GetZoomSetting()
		-- MapType: MAPTYPE_NONE, MAPTYPE_SUBZONE, MAPTYPE_ZONE, MAPTYPE_WORLD, MAPTYPE_ALLIANCE, MAPTYPE_COSMIC
		-- ContentType: MAP_CONTENT_NONE, MAP_CONTENT_AVA, MAP_CONTENT_DUNGEON
		local areaName, mapType, contentType = GetMapName(), GetMapType(), GetMapContentType()
		local zoom = (contentType and contentType == MAP_CONTENT_DUNGEON) and minimapDB.dungeonZoom
			or minimapDB.zoom
		--[[
		/script d(zo_strjoin(" / ", GetMapName(), GetMapType(), GetMapContentType()))
		Eldenwurz^N,in / 1 / 2 -- inside tree
		Eldenwurz^N,in / 1 / 0 -- outside of tree but on subzone
		Mobarmine^fd,in / 2 / 2 -- mine dungeon
		--]]
		return zoom
	end

	local function ApplyMinimapSettings()
		-- some map title adjustments
		if minimapDB.showTitle then
			ZO_WorldMapTitle:SetHidden(false)
			ZO_WorldMapTitle:SetFont(minimapDB.titleFont)
			if minimapDB.longTitles == 'ellipsis' then
				ZO_WorldMapTitle:SetHeight(26) -- = height of ZO_WorldMapTitleBar
				ZO_WorldMapTitle:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
			elseif minimapDB.longTitles == 'anchor' then
				ZO_WorldMapTitle:ClearAnchors()
				ZO_WorldMapTitle:SetAnchor(BOTTOM, nil, TOP, 0, 26) -- ZO_WorldMap
				ZO_WorldMapTitle:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
			end
		else
			ZO_WorldMapTitle:SetHidden(true)
		end
		ZO_WorldMapButtonsBG:SetAlpha(0)
		ZO_WorldMapTitleBarBG:SetAlpha(0)

		if ZO_WorldMap_GetMode() == MAP_MODE_SMALL_CUSTOM then
			local zoom = GetZoomSetting()
			ZO_WorldMap_SetCustomZoomLevels(zoom, zoom)
		end
	end

	-- settings ui
	local panelData = {
		type = 'panel',
		name = pluginName,
		author = 'ckaotik',
		version = 'dev',
		registerForRefresh = true,
		registerForDefaults = true,
	}
	local optionsTable = {
		{
			type = 'description',
			text = 'Use the world map as a minimap while out and about. \nTo resize, drag on the minimap\'s edges. Make sure to use a square format or your map will not center properly.',
		},

		{
			type = 'checkbox',
			name = 'Show zone title',
			getFunc = function() return minimapDB.showTitle end,
			setFunc = function(value) minimapDB.showTitle = value; ApplyMinimapSettings() end,
		},
		{
			type = 'dropdown',
			name = 'Handle too long titles via',
			tooltip = 'Select how the minimap should react to long zone titles.',
			choices = {'anchor', 'ellipsis'},
			disabled = function() return not minimapDB.showTitle end,
			getFunc = function() return minimapDB.longTitles end,
			setFunc = function(value) minimapDB.longTitles = value; ApplyMinimapSettings() end,
		},
		--[[ {
			type = 'colorpicker',
			name = 'Title font color',
			width = 'half',
			diabled = function() return not minimapDB.showTitle end,
			getFunc = function() return 1, 1, 1, 1 end,
			setFunc = function(r,g, b, a) end,
		}, --]]
		{
			type = 'dropdown',
			name = 'Title font',
			width = 'half',
			choices = LMP and LMP:List('font') or {'ZoFontHeader1', 'ZoFontHeader2', 'ZoFontHeader3'},
			disabled = function() return not minimapDB.showTitle end,
			getFunc = function()
				local font, size, style = zo_strsplit('|', minimapDB.titleFont)
				for label, path in pairs(LMP:HashTable('font')) do
					if path == font then return label end
				end
			end,
			setFunc = function(value)
				if LMP then
					local font, size, style = zo_strsplit('|', minimapDB.titleFont)
					value = zo_strjoin('|', LMP:Fetch('font', value) or '', size or '', style or '')
				end
				minimapDB.titleFont = value
				ApplyMinimapSettings()
			end,
		},
		{
			type = 'dropdown',
			name = 'Title font style',
			choices = {'none', 'outline', 'thin-outline', 'thick-outline', 'shadow', 'soft-shadow-thin', 'soft-shadow-thick'},
			width = 'half',
			disabled = function() return not minimapDB.showTitle end,
			getFunc = function()
				local font, size, style = zo_strsplit('|', minimapDB.titleFont)
				return style
			end,
			setFunc = function(value)
				if LMP then
					local font, size, style = zo_strsplit('|', minimapDB.titleFont)
					value = zo_strjoin('|', font or '', size or '', value or '')
				end
				minimapDB.titleFont = value
				ApplyMinimapSettings()
			end,
		},
		{
			type = 'slider',
			name = 'Title font size',
			width = 'half',
			min = 8, max = 30,
			disabled = function() return not minimapDB.showTitle end,
			getFunc = function()
				local font, size, style = zo_strsplit('|', minimapDB.titleFont)
				return tonumber(size or '')
			end,
			setFunc = function(value)
				if LMP then
					local font, size, style = zo_strsplit('|', minimapDB.titleFont)
					value = zo_strjoin('|', font or '', value or '', style or '')
				end
				minimapDB.titleFont = value
				ApplyMinimapSettings()
			end,
		},
		{
			type = 'slider',
			name = 'World zoom',
			tooltip = 'Select how far to zoom into the minimap when in the open world.',
			min = 1, max = 9, step = 1,
			getFunc = function() return minimapDB.zoom end,
			setFunc = function(value) minimapDB.zoom = value; ApplyMinimapSettings() end,
		},
		{
			type = 'slider',
			name = 'Dungeon zoom',
			tooltip = 'Select how far to zoom into the minimap when in dungeons and similar small closed areas.',
			min = 1, max = 9, step = 1,
			getFunc = function() return minimapDB.dungeonZoom end,
			setFunc = function(value) minimapDB.dungeonZoom = value; ApplyMinimapSettings() end,
		},
		{
			type = 'slider',
			name = 'Update interval (in seconds)',
			tooltip = 'Select how often the minimap should update your position.',
			min = 0.05, max = 1, step = 0.05,
			getFunc = function() return minimapDB.updateDelay end,
			setFunc = function(value) minimapDB.updateDelay = value; ApplyMinimapSettings() end,
			warning = 'Lower values will cause increased CPU load while higher values might seem to stutter.',
		},
	}
	local panel = LAM:RegisterAddonPanel(addonName..'Minimap', panelData)
	LAM:RegisterOptionControls(addonName..'Minimap', optionsTable)

	-- for easier configuration, show the map when in settings
	ZO_PreHookHandler(panel, 'OnShow', function(self) ZO_WorldMap:SetHidden(false) end)
	ZO_PreHookHandler(panel, 'OnHide', function(self) ZO_WorldMap:SetHidden(true) end)

	-- copied from default UI
	local paddingX = 4 + 4 -- left, right
	local paddingY = 4 + 26 + 36 + 4 -- top, title bar, buttons bar, bottom
	-- user changes map size, store as new size
	ZO_PreHook('ZO_WorldMap_OnResizeStop', function(self)
		local width, height = self:GetDimensions()
		minimapDB.width = math.floor(width - paddingX)
		minimapDB.height = math.floor(height - paddingY)
	end)

	-- re-show world map in minimap mode
	WORLD_MAP_SCENE:RegisterCallback('StateChange', function(oldState, newState, ...)
		if newState == SCENE_SHOWING and ZO_WorldMap_GetMode() ~= MAP_MODE_LARGE_CUSTOM then
			-- toggle full mode (which may zoom normally)
			ZO_WorldMap_SetCustomZoomLevels(nil, nil)
			ZO_WorldMap_ToggleSize()
		elseif newState == SCENE_HIDING then
			-- prepare minimap
			ZO_WorldMapTitle:SetDimensionConstraints(0, 0, minimapDB.width + paddingX, 0)
			ZO_WorldMap:SetDimensions(minimapDB.width + paddingX, minimapDB.height + paddingY)
			ZO_WorldMap_PanToPlayer()

			-- toggle minimap mode (which has fixed zoom)
			local zoom = GetZoomSetting()
			ZO_WorldMap_SetCustomZoomLevels(zoom, zoom)

			ZO_WorldMap:SetHidden(true) -- prevent flickering
			ZO_WorldMap_ToggleSize()
			if ZO_WorldMap_GetMode() == MAP_MODE_LARGE_CUSTOM then
				-- we just toggled back from a special mode
				ZO_WorldMap_ToggleSize()
			end
		elseif newState == SCENE_HIDDEN then
			-- game wants to hide world map. instead we use it as a minimap
			ZO_WorldMap:SetHidden(WORLD_MAP_FRAGMENT:GetState() ~= 'shown')
		end
	end)

	-- keep minimap centered on player
	local refreshAtTime, isPaused
	ZO_PreHookHandler(ZO_WorldMap, 'OnUpdate', function(self, currentTime)
		if ZO_WorldMap_GetMode() ~= MAP_MODE_SMALL_CUSTOM then return end
		if not refreshAtTime or refreshAtTime < currentTime and not isPaused then
			refreshAtTime = (refreshAtTime or currentTime) + minimapDB.updateDelay
			ZO_WorldMap_PanToPlayer()
		end
	end)
	ZO_PreHook('ZO_WorldMap_MouseDown', function(button) if button == 1 then isPaused = true end end)
	ZO_PreHook('ZO_WorldMap_MouseUp', function(self, button) if button == 1 then isPaused = nil end end)

	-- keep zoom updated when changing zones
	CALLBACK_MANAGER:RegisterCallback('OnWorldMapChanged', function()
		if ZO_WorldMap_GetMode() == MAP_MODE_SMALL_CUSTOM then
			local zoom = GetZoomSetting()
			ZO_WorldMap_SetCustomZoomLevels(zoom, zoom)
		end
	end)

	-- hide when in menus
	local fragment = WORLD_MAP_FRAGMENT
	SCENE_MANAGER:GetScene('hudui'):AddFragment(fragment)
	SCENE_MANAGER:GetScene('hud'):AddFragment(fragment)

	-- initialize minimap
	ApplyMinimapSettings()
	if ZO_WorldMap_GetMode() == MAP_MODE_SMALL_CUSTOM then ZO_WorldMap_ToggleSize() end
	-- SCENE_MANAGER:Show('worldMap') SCENE_MANAGER:Hide('worldMap') -- raises errors
	WORLD_MAP_SCENE:SetState(SCENE_SHOWING)
	WORLD_MAP_SCENE:SetState(SCENE_HIDING)
end
em:RegisterForEvent(pluginName, EVENT_ADD_ON_LOADED, Initialize)
