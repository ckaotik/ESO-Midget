local addonName, addon, _ = 'Midget', {}

-- GLOBALS: ZO_SavedVars, Midget_Controller, COMPASS_PINS, BUFF_EFFECT_TYPE_BUFF, BUFF_EFFECT_TYPE_DEBUFF, LINK_STYLE_DEFAULT
-- GLOBALS: d, GetFrameTimeSeconds, GetNumBuffs, GetUnitBuffInfo, GetBagInfo, GetSlotStackSize, GetItemName, GetItemLink, GetGroupSize, GetGroupUnitTagByIndex, GetUnitName, GetMapPlayerPosition
-- GLOBALS: select
local wm = GetWindowManager()
local em = GetEventManager()

local function Initialize(eventCode, arg1, ...)
	if arg1 ~= addonName then return end
	EVENT_MANAGER:UnregisterForEvent(addonName, EVENT_ADD_ON_LOADED)

	-- Show equipped indicator on repair dialog
	-- ----------------------------------------------------
	ZO_PreHook(ZO_RepairWindowList.dataTypes[1], 'setupCallback', function(self, data, list)
		local icon = self:GetNamedChild('EquippedIndicator')
		if data.bagId == BAG_WORN then
			if not icon then
				icon = wm:CreateControl(self:GetName()..'EquippedIndicator', self, CT_TEXTURE)
				icon:SetAnchor(CENTER, self:GetNamedChild('ButtonIcon'), CENTER, 0, 0)
				icon:SetDrawTier(DT_LOW)
				icon:SetDimensions(50, 50)
				icon:SetTexture('/esoui/art/actionbar/passiveabilityframe_round_over.dds')
			end
			icon:SetHidden(false)
		elseif icon then
			icon:SetHidden(true)
		end
	end)

	-- Add keybind for split stack on mouseover
	-- ----------------------------------------------------
	-- TODO: SlotMouseoverCommand
	-- function ZO_InventorySlotActions:AddSlotAction(actionStringId, actionCallback, actionType, visibilityFunction, options)
	-- slotActions:AddSlotAction(SI_ITEM_ACTION_SPLIT_STACK, function() TrySplitStack(inventorySlot) end, "secondary")
	local keybind = {
		name = GetString(SI_INVENTORY_SPLIT_STACK_TITLE),
		keybind = 'UI_SHORTCUT_NEGATIVE', -- UI_SHORTCUT_SECONDARY, UI_SHORTCUT_TERTIARY
		callback = function(keybind)
			if not keybind.owner then return end
			ZO_StackSplit_SplitItem(keybind.owner)
		end,
		alignment = KEYBIND_STRIP_ALIGN_RIGHT,
	}
	local function ShowKeybind(self) keybind.owner = self; KEYBIND_STRIP:AddKeybindButton(keybind) end
	local function HideKeybind() keybind.owner = nil; KEYBIND_STRIP:RemoveKeybindButton(keybind) end

	local function OnMouseEnter(self)
		-- TODO: Prevents taken mail to be sent back: ZO_MailInbox
		if self:GetOwningWindow() ~= ZO_PlayerInventory then return end

		local button = self:GetNamedChild('Button')
		if not button then return end
		HideKeybind()

		local data = self.dataEntry and self.dataEntry.data
		if button and CheckInventorySpaceSilently(1)
			and ZO_InventorySlot_IsSplittableType(button)
			and ZO_InventorySlot_GetStackCount(button) > 1 then
			ShowKeybind(button)
		end
	end
	ZO_PreHook(_G, 'ZO_InventorySlot_OnMouseEnter', OnMouseEnter)
	ZO_PreHook(_G, 'ZO_InventorySlot_RemoveMouseOverKeybinds', HideKeybind)

	-- allow SHIFT+Click on inventory to post link to chat
	-- ----------------------------------------------------
	ZO_PreHook(_G, 'ZO_InventorySlot_OnSlotClicked', function(self, button)
		if button == 1 and IsShiftKeyDown() then
			local itemLink
			local bag, slot = ZO_Inventory_GetBagAndIndex(self:GetNamedChild('Button'))
			if bag and slot then
				itemLink = GetItemLink(bag, slot)
			elseif not MAIL_INBOX.control:IsHidden() then
				local mailId = MAIL_INBOX:GetOpenMailId()
				itemLink = GetAttachedItemLink(mailId, slot)
			end

			if itemLink then
				ZO_LinkHandler_InsertLink(zo_strformat(SI_TOOLTIP_ITEM_NAME, itemLink))
			end
		end
	end)

	-- rune translations
	-- ----------------------------------------------------
	ZO_PreHook(ZO_EnchantingTopLevelInventoryBackpack.dataTypes[1], 'setupCallback', function(self, data, list)
		local label = self:GetNamedChild('Translation')
		if not label then
			label = wm:CreateControl('$(parent)Translation', self, CT_LABEL)
			label:SetFont('ZoFontGame')
			label:SetAnchor(RIGHT, self, RIGHT, -100)
			label:SetDrawTier(DT_HIGH)
		end

		local bag, slot = self.dataEntry.data.bagId, self.dataEntry.data.slotIndex
		local text = GetRunestoneTranslatedName(bag, slot)
		label:SetText(text or '')
	end)

	-- TODO: someone logs on, add friend note: [@friend] has logged on (BFF!)
	-- ----------------------------------------------------
	em:RegisterForEvent(addonName, EVENT_FRIEND_PLAYER_STATUS_CHANGED, function(eventID, account, oldStatus, newStatus)
		if oldStatus == PLAYER_STATUS_OFFLINE and newStatus == PLAYER_STATUS_ONLINE then
			local friendIndex, note
			for index = 1, GetNumFriends() do
				local name, status, lastOnline
				name, note, status, lastOnline = GetFriendInfo(index)
				if name == account then friendIndex = index break end
			end
			if not friendIndex then return end

			local _, characterName, zoneName, classType, alliance, level, veteranRank = GetFriendCharacterInfo(friendIndex)
			local link = ZO_LinkHandler_CreateDisplayNameLink(account)
			local characterLink = ZO_LinkHandler_CreateCharacterLink(characterName)
			local msg = zo_strformat('<<4>> |t28:28:<<2>>|t<<3>>|t28:28:EsoUI/Art/Campaign/<<1>>.dds|t has logged on.<<5>>',
				alliance == ALLIANCE_ALDMERI_DOMINION and 'overview_allianceIcon_aldmeri'
					or alliance == ALLIANCE_DAGGERFALL_COVENANT and 'overview_allianceIcon_daggefall'
					or alliance == ALLIANCE_EBONHEART_PACT and 'overview_allianceIcon_ebonheart' or '',
				GetClassIcon(classType),
				characterLink or characterName,
				veteranRank > 0 and ('VR'..veteranRank) or ('L'..level),
				note > '' and ' ['..note..']' or ''
			)
			CHAT_SYSTEM:AddMessage(msg)
		end
	end)

	-- EVENT_GUILD_MEMBER_PLAYER_STATUS_CHANGED(guildID, account, oldState, newState)
	-- GetNumGuildMembers(guildID); name, note, rank, status, lastOnline = GetGuildMemberInfo(integer guildId, luaindex memberIndex)

	-- TODO: comparative tooltips w/ alternate weapons
	-- ----------------------------------------------------
	-- TODO: settings when to show comparative tooltips and what to compare to
	-- ----------------------------------------------------
	--[[
	-- /script d{SLOT_TYPE_PENDING_CHARGE, SLOT_TYPE_ENCHANTMENT, SLOT_TYPE_ENCHANTMENT_RESULT, SLOT_TYPE_REPAIR, SLOT_TYPE_PENDING_REPAIR, SLOT_TYPE_CRAFTING_COMPONENT, SLOT_TYPE_PENDING_CRAFTING_COMPONENT, SLOT_TYPE_SMITHING_MATERIAL, SLOT_TYPE_SMITHING_STYLE, SLOT_TYPE_SMITHING_TRAIT, SLOT_TYPE_SMITHING_BOOSTER, SLOT_TYPE_LIST_DIALOG_ITEM}

	local _ZO_InventorySlot_OnMouseEnter = ZO_InventorySlot_OnMouseEnter
	_G.ZO_InventorySlot_OnMouseEnter = function(inventorySlot, ...)
		-- call original function first
		local isShown = _ZO_InventorySlot_OnMouseEnter(inventorySlot, ...)
		if not isShown then return end

		-- then we can start
		local button = inventorySlot:GetNamedChild('Button')
		local slotType = ZO_InventorySlot_GetType(button)

		if slotType == _G.SLOT_TYPE_CRAFTING_COMPONENT then
			local tooltip = ItemTooltip
			tooltip:HideComparativeTooltips()
			tooltip:ShowComparativeTooltips()
			ZO_PlayShowAnimationOnComparisonTooltip(ComparativeTooltip1)
			ZO_PlayShowAnimationOnComparisonTooltip(ComparativeTooltip2)
			ZO_Tooltips_SetupDynamicTooltipAnchors(tooltip, button.tooltipAnchor or button, ComparativeTooltip1, ComparativeTooltip2)
		end
	end
	--]]
end
em:RegisterForEvent(addonName, EVENT_ADD_ON_LOADED, Initialize)

--[[ Notes to self
-- ----------------------------------------------------
	-- ZO_InventorySlot_ShowContextMenu
	-- ZO_InventorySlot_IsSplittableType
	-- ZO_InventorySlot_GetStackCount

	ZO_AlertEvent(EVENT_GUILD_BANK_TRANSFER_ERROR, GUILD_BANK_NO_WITHDRAW_PERMISSION)
	ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_INVENTORY_ERROR_INVENTORY_FULL)

	ZO_InventoryManager:ApplyBackpackLayout, :DoesBagHaveEmptySlot, :GenerateListOfVirtualStackedItems, :GetNumBackpackSlots, :RefreshInventorySlot, ...

	ZO_InventorySlot_SetupUsableAndLockedColor, ZO_InventorySlot_SetupTextUsableAndLockedColor, ZO_InventorySlot_SetupIconUsableAndLockedColor - learnable recipes

	ZO_Tooltips_SetupDynamicTooltipAnchors(ItemTooltip, self)

	ZO_PreHookHandler(ItemTooltip, 'OnAddGameData', function(self, ...)
		d('OnAddGameData', self:GetName(), ...)
	end)

	addon.db = ZO_SavedVars:New(addonName..'DB', 1, nil, {
		-- default settings
	})

	local control = wm:CreateTopLevelWindow(addonName)
	control:SetHandler('OnUpdate', Update)

	split stack:
	CallSecureProtected('PickupInventoryItem', bagID, itemIndex, count)
	local toBag = 1
	local toSlot = FindFirstEmptySlotInBag(toBag)
	CallSecureProtected('PlaceInInventory', toBag, toSlot)

	-- when pulling multiple times from one slot, wait for event
	/script CallSecureProtected('PickupInventoryItem', 1, 38, 5)
	/script CallSecureProtected('PlaceInInventory', 1, FindFirstEmptySlotInBag(1))

	texture string: |t40:40:EsoUI/Art/UnitFrames/target_veteranRank_icon.dds|t
	ZO_Tooltip_AddDivider(tooltip)
	local mouseOverControl = moc()

	AddMenuItem(label, callback)
	ShowMenu(owner)

	ZO_SortHeader_SetMouseCallback(control, handlerName) -- e.g. OnMouseEnter

	["GetAlchemyItemTraits"] = function: 161AA860
	["GetAlchemyResultingItemInfo"] = function: 161AA770
	["GetAlchemyResultingItemLink"] = function: 161AA7C0

	SplitString(':', 'my:text')

	zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemName(bagId, slotIndex))
	/script for k,v in ipairs(EsoStrings) do if v:lower():find('bank') then d(k..' - '..v) end end
	GetString / EsoStrings + LocalizeString(EsoStrings[stringIndex], ...) -- variables, including Kopf^m,auf

	/script local search = 'aufteilen'; for id, text in pairs(EsoStrings) do if text:lower():find(search) then for k, v in safepairs(_G) do if type(v) == 'number' and k:find("^SI_") and v == id then d(k..' ('..id..'): '..text) end end end end

	Pretty display names: zo_strformat(SI_TOOLTIP_ITEM_NAME, name)

	LocalizeString
		<<1[kein/ein/$d]>> 		kein, ein, 2
		<<and(1,2)>> 			3 und 15
		<<C:1{der $s/die $s/das $s}>>      der mann, die frau, das kind
		<<A:1>>					der Mann
		<<p:1>> 				er/sie/es
		den <<C:1>> 			das Inventar

	Top right alert messages:
		ZO_Alert(UI_ALERT_CATEGORY_ALERT, 1, "Attempting to invite")
--]]
