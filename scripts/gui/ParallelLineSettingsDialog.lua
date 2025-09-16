---This class creates a dialog based on the matching XML flie and handles interactions in this dialog
---@class ParallelLineSettingsDialog
---@field lengthSetting table @The UI element for the length setting
---@field stripWidthSetting table @The UI element for the strip width setting
---@field resolutionSetting table @The UI element for the resolution setting
---@field grassTypeSetting table @The UI element for the grass type setting
---@field shrubTypeSetting table @The UI element for the shrub type setting
---@field treeType16Setting table @The UI element for the tree type 16 setting
---@field treeType8Setting table @The UI element for the tree type 8 setting
---@field treeType4Setting table @The UI element for the tree type 4 setting
---@field treeType2Setting table @The UI element for the tree type 2 setting
---@field treeType1Setting table @The UI element for the tree type 1 setting
---@field settings ConstructionBrushParallelLinesSettings @The settings object which will be updated when the user presses "yes"

ParallelLineSettingsDialog = {
	DIALOG_ID = "ParallelLineSettingsDialog",
	LENGTH_STRINGS = {},
	STRIP_WIDTH_STRINGS = {},
	RESOLUTION_STRINGS = {},
	GRASS_TYPE_STRINGS = {},
	SHRUB_TYPE_STRINGS = {},
	TREE_TYPE_STRINGS = {},
	LENGTH_STEP = 50
}


-- Inherit from a yes/no dialog which is the closest base to what we want
local ParallelLineSettingsDialog_mt = Class(ParallelLineSettingsDialog, YesNoDialog)

---Creates a new instance
---@param settings table @The settings object which will be used to initialize the dialog and which will be updated when the user presses "yes"
---@return ParallelLineSettingsDialog @The new instance
function ParallelLineSettingsDialog.new(settings)
	local self = YesNoDialog.new(nil, ParallelLineSettingsDialog_mt)
	self.target = self

	-- Forward the yes/no click to this class, which will then only forward it to the callback target in the "yes" case
	self:setCallback(ParallelLineSettingsDialog.onYesNo, self)
	self.settings = settings

	return self
end

local instance
function ParallelLineSettingsDialog.createInstance(settings)
	instance = ParallelLineSettingsDialog.new(settings)
	return instance
end

function ParallelLineSettingsDialog.getInstance()
	return instance
end

function ParallelLineSettingsDialog:delete()
	if self.isOpen then
		self:close()
	end

	-- Force close the current UI
	g_gui:showGui(nil)

	self:superClass().delete(self)
	instance = nil

	-- Fixes bugs with keyboard focus
	FocusManager.guiFocusData["ParallelLineSettingsDialog"] = {
		idToElementMapping = {}
	}
end

function ParallelLineSettingsDialog:reload()
	g_gui.currentlyReloading = true

	local settingsObject = self.settingsObject
	self:delete()
	self = ParallelLineSettingsDialog.createInstance(settingsObject)
	self:register()

	g_gui.currentlyReloading = false

	self:show()
end
---Registers the dialog with g_gui
function ParallelLineSettingsDialog:register()
	local xmlPath = Utils.getFilename("gui/ParallelLineSettingsDialog.xml", MOD_DIR)
	g_gui:loadGui(xmlPath, ParallelLineSettingsDialog.DIALOG_ID, self)
end

---Reacts on yes/no presses and calls the callback function which was supplied to the constructor, in the yes case
---@param yesWasPressed boolean @True if yes was pressed, false otherwise
function ParallelLineSettingsDialog:onYesNo(yesWasPressed)
	if yesWasPressed then
		local settings = {
			length = self.lengthSetting.state * ParallelLineSettingsDialog.LENGTH_STEP,
			stripWidth = self.stripWidthSetting.state,
			resolution = self.resolutionSetting.state,
			grassType = self.grassTypeSetting.state or 1,
			shrubType = self.shrubTypeSetting.state or 1,
			treeType16 = self.treeType16Setting.state or 1,
			treeType8 = self.treeType8Setting.state or 1,
			treeType4 = self.treeType4Setting.state or 1,
			treeType2 = self.treeType2Setting.state or 1,
			treeType1 = self.treeType1Setting.state or 1
		}
		printf("Calling callback function with grassType = %s", settings.grassType)
		self.settings:applySettings(settings)
	end
end

function ParallelLineSettingsDialog:initializeValues()
	-- One-time initialization
	for i = 50, 5000, 50 do
		table.insert(ParallelLineSettingsDialog.LENGTH_STRINGS, ("%d m"):format(i))
	end
	for i = 6, 72 do
		table.insert(ParallelLineSettingsDialog.STRIP_WIDTH_STRINGS, ("%d m"):format(i))
	end
	for i = 1, 10 do
		table.insert(ParallelLineSettingsDialog.RESOLUTION_STRINGS, ("%d"):format(i))
	end
	table.insert(ParallelLineSettingsDialog.GRASS_TYPE_STRINGS, "None")
	local grassLayer = g_currentMission.foliageSystem:getFoliagePaintByName("meadow")
	if grassLayer then
		local maxValue = 2^grassLayer.numStateChannels-1
		for i = 1, maxValue do
			table.insert(ParallelLineSettingsDialog.GRASS_TYPE_STRINGS, ("Type %d"):format(i))
		end
	end
	-- TODO SHRUB_TYPES
	ParallelLineSettingsDialog.SHRUB_TYPE_STRINGS = { "Not Supported" }

	table.insert(ParallelLineSettingsDialog.TREE_TYPE_STRINGS, "None")
	for i, treeType in ipairs(g_treePlantManager.treeTypes) do
		table.insert(ParallelLineSettingsDialog.TREE_TYPE_STRINGS, treeType.name)
	end

	self.lengthSetting:setTexts(ParallelLineSettingsDialog.LENGTH_STRINGS)
	self.stripWidthSetting:setTexts(ParallelLineSettingsDialog.STRIP_WIDTH_STRINGS)
	self.resolutionSetting:setTexts(ParallelLineSettingsDialog.RESOLUTION_STRINGS)
	self.grassTypeSetting:setTexts(ParallelLineSettingsDialog.GRASS_TYPE_STRINGS)
	self.shrubTypeSetting:setTexts(ParallelLineSettingsDialog.SHRUB_TYPE_STRINGS)
	self.treeType16Setting:setTexts(ParallelLineSettingsDialog.TREE_TYPE_STRINGS)
	self.treeType8Setting:setTexts(ParallelLineSettingsDialog.TREE_TYPE_STRINGS)
	self.treeType4Setting:setTexts(ParallelLineSettingsDialog.TREE_TYPE_STRINGS)
	self.treeType2Setting:setTexts(ParallelLineSettingsDialog.TREE_TYPE_STRINGS)
	self.treeType1Setting:setTexts(ParallelLineSettingsDialog.TREE_TYPE_STRINGS)
end

---Displays the dialog
function ParallelLineSettingsDialog:show()
	self:applySettings(self.settings)
	self:setDialogType(DialogElement.TYPE_QUESTION)
	g_gui:showDialog(ParallelLineSettingsDialog.DIALOG_ID)
end

function ParallelLineSettingsDialog:applySettings(settings)
	self.lengthSetting:setState(settings.length / ParallelLineSettingsDialog.LENGTH_STEP)
	self.stripWidthSetting:setState(settings.stripWidth)
	self.resolutionSetting:setState(settings.resolution)
	self.grassTypeSetting:setState(settings.grassType)
	self.shrubTypeSetting:setState(settings.shrubType)
	self.treeType16Setting:setState(settings.treeType16)
	self.treeType8Setting:setState(settings.treeType8)
	self.treeType4Setting:setState(settings.treeType4)
	self.treeType2Setting:setState(settings.treeType2)
	self.treeType1Setting:setState(settings.treeType1)
end

function ParallelLineSettingsDialog:onFrameOpen(element)
	ParallelLineSettingsDialog:superClass().onFrameOpen(self)
end