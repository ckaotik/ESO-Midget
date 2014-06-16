local addonName, addon, _ = 'Midget', {}
local pluginName = addonName..'MrPlow'

local function Initialize(eventCode, arg1)
	if arg1 ~= addonName then return end
	EVENT_MANAGER:UnregisterForEvent(pluginName, EVENT_ADD_ON_LOADED)

	local wm = GetWindowManager()
	local LibSort = LibStub('LibSort-1.0')

	-- NOTE: these must be reflected in LibSort
	local inventories = {
		['enchanting'] = ENCHANTING.inventory,
	}

	for inventoryType, inventory in pairs(inventories) do
		ZO_PreHook(ZO_CraftingInventory, 'SortData', function(self)
			if self ~= inventory or self.sortKey ~= 'age' then return end
			for _, slot in pairs(self.list.data) do
				-- supply default values for data fields not found in crafting
				slot.data.slotType  = slot.data.slotType or _G.SLOT_TYPE_ITEM
				slot.data.age       = slot.data.age or 0
				slot.data.statValue = slot.data.statValue or 0
			end
			LibSort:ProcessInventory(inventoryType)
		end)

		local oldSort = inventory.sortFunction
		local newSort = function(entry1, entry2)
			if inventory.sortKey ~= 'age' and oldSort then
				return oldSort(entry1, entry2)
			end

			if entry1.typeId == entry2.typeId then
				return ZO_TableOrderingFunction(entry1.data, entry2.data, inventory.sortKey, LibSort.sortKeys, inventory.sortOrder)
			end
			return entry1.typeId < entry2.typeId
		end
		inventory.sortFunction = newSort

		local parent = inventory.sortHeaders.headerContainer
		local smartSort = wm:CreateControlFromVirtual('$(parent)Smart', parent, 'ZO_SortHeaderIcon')
		smartSort:SetDimensions(16, 32)
		smartSort:SetAnchor(RIGHT, parent:GetNamedChild('Name'), LEFT, -15)

		ZO_PlayerInventory_InitSortHeaderIcon(smartSort,
			'EsoUI/Art/Miscellaneous/list_sortHeader_icon_neutral.dds',
			'EsoUI/Art/Miscellaneous/list_sortHeader_icon_sortUp.dds',
			'EsoUI/Art/Miscellaneous/list_sortHeader_icon_sortDown.dds',
			'EsoUI/Art/Miscellaneous/list_sortHeader_icon_over.dds',
			'age')
		inventory.sortHeaders:AddHeader(smartSort)
		inventory.sortHeaders:SelectHeaderByKey('age')
	end
end
EVENT_MANAGER:RegisterForEvent(pluginName, EVENT_ADD_ON_LOADED, Initialize)
