---This class creates a dialog based on the matching XML flie and handles interactions in this dialog
---@class ParallelLineSettingsDialogTree
---@field forwardLengthSetting table @The UI element for the forward length setting
---@field reverseLengthSetting table @The UI element for the reverse length setting
---@field headlandWidthSetting table @The UI element for the headland width setting
---@field stripWidthSetting table @The UI element for the strip width setting
---@field keylineWidthSetting table @The UI element for the keyline width setting
---@field numberOfParallelLinesRightSetting table @The UI element for the number of parallel lines to the right setting
---@field numberOfParallelLinesLeftSetting table @The UI element for the number of parallel lines to the left setting
---@field grassTypeSetting table @The UI element for the grass type setting
---@field bushTypeSetting table @The UI element for the bush type setting
---@field bushWidthSetting table @The UI element for the bush width setting
---@field treeType32Setting table @The UI element for the tree type 32 setting
---@field treeType16Setting table @The UI element for the tree type 16 setting
---@field treeType8Setting table @The UI element for the tree type 8 setting
---@field treeType4Setting table @The UI element for the tree type 4 setting
---@field treeType2Setting table @The UI element for the tree type 2 setting
---@field treeMinGrowthStageSetting table @The UI element for the minimum tree growth stage setting
---@field treeMaxGrowthStageSetting table @The UI element for the maximum tree growth stage setting
---@field treeGrowthBehaviorSetting table @The UI element for the tree growth behavior setting
---@field settings ConstructionBrushParallelLinesSettings @The settings object which will be updated when the user presses "yes"

ParallelLineSettingsDialogTree = {
	DIALOG_ID = "ParallelLineSettingsDialogTree",
	LENGTH_STRINGS = {},
	RESOLUTION_STRINGS = {},
	GRASS_TYPE_STRINGS = {},
	BUSH_TYPE_STRINGS = {},
	GRASS_BRUSH_PARAMETERS = {},
	BUSH_BRUSH_PARAMETERS = {},
	TREE_TYPE_STRINGS = {},
	TREE_GROWTH_BEHAVIOR = {
		GROWING = 1,
		STABLE = 2
	},
	TREE_GROWTH_BEHAVIOR_STRINGS = {
		"Growing",
		"Stable"
	},
	LENGTH_STEP = 50
}


-- Inherit from a yes/no dialog which is the closest base to what we want
local ParallelLineSettingsDialog_mt = Class(ParallelLineSettingsDialogTree, YesNoDialog)

---Creates a new instance
---@param settings table @The settings object which will be used to initialize the dialog and which will be updated when the user presses "yes"
---@return ParallelLineSettingsDialogTree @The new instance
function ParallelLineSettingsDialogTree.new(settings)
	local self = YesNoDialog.new(nil, ParallelLineSettingsDialog_mt)
	self.target = self

	-- Forward the yes/no click to this class, which will then only forward it to the callback target in the "yes" case
	self:setCallback(ParallelLineSettingsDialogTree.onYesNo, self)
	self.settings = settings

	return self
end

local instance
function ParallelLineSettingsDialogTree.createInstance(settings)
	instance = ParallelLineSettingsDialogTree.new(settings)
	return instance
end

function ParallelLineSettingsDialogTree.getInstance()
	return instance
end

function ParallelLineSettingsDialogTree:delete()
	if self.isOpen then
		self:close()
	end

	-- Force close the current UI
	g_gui:showGui(nil)

	self:superClass().delete(self)
	instance = nil

	-- Fixes bugs with keyboard focus
	FocusManager.guiFocusData["ParallelLineSettingsDialogTree"] = {
		idToElementMapping = {}
	}
end

function ParallelLineSettingsDialogTree:reload()
	g_gui.currentlyReloading = true

	local settingsObject = self.settings
	self:delete()
	self = ParallelLineSettingsDialogTree.createInstance(settingsObject)
	self:register()

	g_gui.currentlyReloading = false

	self:show()
end
---Registers the dialog with g_gui
function ParallelLineSettingsDialogTree:register()
	local xmlPath = Utils.getFilename("gui/ParallelLineSettingsDialogTree.xml", MOD_DIR)
	g_gui:loadGui(xmlPath, ParallelLineSettingsDialogTree.DIALOG_ID, self)
end

---Reacts on yes/no presses and calls the callback function which was supplied to the constructor, in the yes case
---@param yesWasPressed boolean @True if yes was pressed, false otherwise
function ParallelLineSettingsDialogTree:onYesNo(yesWasPressed)
	if yesWasPressed then
		local settings = {
			forwardLength = (self.forwardLengthSetting.state - 1) * ParallelLineSettingsDialogTree.LENGTH_STEP,
			reverseLength = (self.reverseLengthSetting.state - 1) * ParallelLineSettingsDialogTree.LENGTH_STEP,
			headlandWidth = self.headlandWidthSetting.state - 1,
			stripWidth = self.stripWidthSetting.state + 1 - 1,
			keylineWidth = self.keylineWidthSetting.state + 1 - 1,
			numberOfParallelLinesRight = self.numberOfParallelLinesRightSetting.state - 1,
			numberOfParallelLinesLeft = self.numberOfParallelLinesLeftSetting.state - 1,
			grassType = self.grassTypeSetting.state or 1,
			grassBrushParameters = ParallelLineSettingsDialogTree.GRASS_BRUSH_PARAMETERS[self.grassTypeSetting.state],
			bushType = self.bushTypeSetting.state or 1,
			bushBrushParameters = ParallelLineSettingsDialogTree.BUSH_BRUSH_PARAMETERS[self.bushTypeSetting.state],
			bushWidth = self.bushWidthSetting.state or 1,
			treeType32 = self.treeType32Setting.state or 1,
			treeType16 = self.treeType16Setting.state or 1,
			treeType8 = self.treeType8Setting.state or 1,
			treeType4 = self.treeType4Setting.state or 1,
			treeType2 = self.treeType2Setting.state or 1,
			treeMinGrowthStage = self.treeMinGrowthStageSetting.state or 1,
			-- Make sure maxGrowthStage is >= minGrowthStage
			treeMaxGrowthStage = (self.treeMinGrowthStageSetting.state and self.treeMaxGrowthStageSetting.state and self.treeMaxGrowthStageSetting.state >= self.treeMinGrowthStageSetting.state) and self.treeMaxGrowthStageSetting.state or self.treeMinGrowthStageSetting.state or 7,
			treeGrowthBehavior = self.treeGrowthBehaviorSetting.state or ParallelLineSettingsDialogTree.TREE_GROWTH_BEHAVIOR.GROWING
		}
		if settings.forwardLength == 0 and settings.reverseLength == 0 then
			Logging.error("You need to set at least forward length or reverse length > 0")
			return
		end
		printf("Calling callback function with grassType = %s", settings.grassType)
		self.settings:applySettings(settings)
	end
end

function ParallelLineSettingsDialogTree:initializeValues()
	-- One-time initialization
	for i = 0, 5000, 50 do
		table.insert(ParallelLineSettingsDialogTree.LENGTH_STRINGS, ("%d m"):format(i))
	end
	local headlandWidth = {}
	for i = 0, 72 do
		table.insert(headlandWidth, ("%d m"):format(i))
	end
	local stripWidth = {}
	for i = 1, 72 do
		table.insert(stripWidth, ("%d m"):format(i))
	end
	local keylineWidth = {}
	for i = 1, 12 do
		table.insert(keylineWidth, ("%d m"):format(i))
	end
	local amountValues = {}
	for i = 0, 50 do
		table.insert(amountValues, ("%d"):format(i))
	end
	local growthStageValues = {}
	for i = 1, 7 do
		table.insert(growthStageValues, ("%d"):format(i))
	end

	-- Get grass and bushes from the store manager - the same way the construction screen finds them
	table.insert(ParallelLineSettingsDialogTree.GRASS_BRUSH_PARAMETERS, { foliageName = "invalid", value = 0 })
	table.insert(ParallelLineSettingsDialogTree.GRASS_TYPE_STRINGS, "None")
	table.insert(ParallelLineSettingsDialogTree.BUSH_BRUSH_PARAMETERS, { foliageName = "invalid", value = 0 })
	table.insert(ParallelLineSettingsDialogTree.BUSH_TYPE_STRINGS, "None")
	for _, item in ipairs(g_storeManager:getItems()) do
		if item.brush ~= nil and item.brush.type == "foliage" then
			-- The XML file name seems to be the only thing which vaguely tells what kind of grass or bush it is	
			local filepath = item.rawXMLFilename
			local filenameWithExt = filepath:match("([^/\\]+)$")
			local filename = filenameWithExt:match("(.+)%..+$")

			local parameters = item.brush.parameters
			if parameters and #parameters > 0 then
				if parameters[1] == "decoFoliage" or parameters[1] == "meadow" then
					table.insert(ParallelLineSettingsDialogTree.GRASS_BRUSH_PARAMETERS, { foliageName = parameters[1], value = parameters[2] })
					table.insert(ParallelLineSettingsDialogTree.GRASS_TYPE_STRINGS, filename)
				elseif parameters[1]:startsWith("decoBush") then
					table.insert(ParallelLineSettingsDialogTree.BUSH_BRUSH_PARAMETERS, { foliageName = parameters[1], value = parameters[2] })
					table.insert(ParallelLineSettingsDialogTree.BUSH_TYPE_STRINGS, filename)
				end
			end
		end
	end

	table.insert(ParallelLineSettingsDialogTree.TREE_TYPE_STRINGS, "None")
	for i, treeType in ipairs(g_treePlantManager.treeTypes) do
		table.insert(ParallelLineSettingsDialogTree.TREE_TYPE_STRINGS, treeType.title)
	end

	self.forwardLengthSetting:setTexts(ParallelLineSettingsDialogTree.LENGTH_STRINGS)
	self.reverseLengthSetting:setTexts(ParallelLineSettingsDialogTree.LENGTH_STRINGS)
	self.headlandWidthSetting:setTexts(headlandWidth)
	self.stripWidthSetting:setTexts(stripWidth)
	self.keylineWidthSetting:setTexts(keylineWidth)
	self.numberOfParallelLinesRightSetting:setTexts(amountValues)
	self.numberOfParallelLinesLeftSetting:setTexts(amountValues)
	self.grassTypeSetting:setTexts(ParallelLineSettingsDialogTree.GRASS_TYPE_STRINGS)
	self.bushTypeSetting:setTexts(ParallelLineSettingsDialogTree.BUSH_TYPE_STRINGS)
	self.bushWidthSetting:setTexts(keylineWidth)
	self.treeMinGrowthStageSetting:setTexts(growthStageValues)
	self.treeMaxGrowthStageSetting:setTexts(growthStageValues)
	self.treeGrowthBehaviorSetting:setTexts(ParallelLineSettingsDialogTree.TREE_GROWTH_BEHAVIOR_STRINGS)
	self.treeType32Setting:setTexts(ParallelLineSettingsDialogTree.TREE_TYPE_STRINGS)
	self.treeType16Setting:setTexts(ParallelLineSettingsDialogTree.TREE_TYPE_STRINGS)
	self.treeType8Setting:setTexts(ParallelLineSettingsDialogTree.TREE_TYPE_STRINGS)
	self.treeType4Setting:setTexts(ParallelLineSettingsDialogTree.TREE_TYPE_STRINGS)
	self.treeType2Setting:setTexts(ParallelLineSettingsDialogTree.TREE_TYPE_STRINGS)
end

---Displays the dialog
function ParallelLineSettingsDialogTree:show()
	self:applySettings(self.settings)
	self:setDialogType(DialogElement.TYPE_QUESTION)
	g_gui:showDialog(ParallelLineSettingsDialogTree.DIALOG_ID)
end

function ParallelLineSettingsDialogTree:applySettings(settings)
	self.forwardLengthSetting:setState((settings.forwardLength / ParallelLineSettingsDialogTree.LENGTH_STEP) + 1)
	self.reverseLengthSetting:setState((settings.reverseLength / ParallelLineSettingsDialogTree.LENGTH_STEP) + 1)
	self.headlandWidthSetting:setState(settings.headlandWidth + 1)
	self.stripWidthSetting:setState(settings.stripWidth - 1 + 1)
	self.keylineWidthSetting:setState(settings.keylineWidth - 1 + 1)
	self.numberOfParallelLinesRightSetting:setState(settings.numberOfParallelLinesRight + 1)
	self.numberOfParallelLinesLeftSetting:setState(settings.numberOfParallelLinesLeft + 1)
	self.treeMinGrowthStageSetting:setState(settings.treeMinGrowthStage or 1)
	self.treeMaxGrowthStageSetting:setState(settings.treeMaxGrowthStage or 7)
	self.treeGrowthBehaviorSetting:setState(settings.treeGrowthBehavior or ParallelLineSettingsDialogTree.TREE_GROWTH_BEHAVIOR.GROWING)
	self.grassTypeSetting:setState(settings.grassType)
	self.bushTypeSetting:setState(settings.bushType)
	self.bushWidthSetting:setState(settings.bushWidth)
	self.treeType32Setting:setState(settings.treeType32)
	self.treeType16Setting:setState(settings.treeType16)
	self.treeType8Setting:setState(settings.treeType8)
	self.treeType4Setting:setState(settings.treeType4)
	self.treeType2Setting:setState(settings.treeType2)
end

function ParallelLineSettingsDialogTree:onFrameOpen(element)
	ParallelLineSettingsDialogTree:superClass().onFrameOpen(self)
end