---This class creates a dialog based on the matching XML flie and handles interactions in this dialog
---@class ParallelLineSettingsDialogVines
---@field forwardLengthSetting table @The UI element for the forward length setting
---@field reverseLengthSetting table @The UI element for the reverse length setting
---@field headlandWidthSetting table @The UI element for the headland width setting
---@field stripWidthSetting table @The UI element for the strip width setting
---@field numberOfParallelLinesRightSetting table @The UI element for the number of parallel lines to the right setting
---@field numberOfParallelLinesLeftSetting table @The UI element for the number of parallel lines to the left setting
---@field settings ConstructionBrushVinesSettings @The settings object which will be updated when the user presses "yes"

ParallelLineSettingsDialogVines = {
	DIALOG_ID = "ParallelLineSettingsDialogVines",
	LENGTH_STRINGS = {},
	LENGTH_STEP = 50
}


-- Inherit from a yes/no dialog which is the closest base to what we want
local ParallelLineSettingsDialog_mt = Class(ParallelLineSettingsDialogVines, YesNoDialog)

---Creates a new instance
---@param settings table @The settings object which will be used to initialize the dialog and which will be updated when the user presses "yes"
---@return ParallelLineSettingsDialogVines @The new instance
function ParallelLineSettingsDialogVines.new(settings)
	local self = YesNoDialog.new(nil, ParallelLineSettingsDialog_mt)
	self.target = self

	-- Forward the yes/no click to this class, which will then only forward it to the callback target in the "yes" case
	self:setCallback(ParallelLineSettingsDialogVines.onYesNo, self)
	self.settings = settings

	return self
end

local instance
function ParallelLineSettingsDialogVines.createInstance(settings)
	instance = ParallelLineSettingsDialogVines.new(settings)
	return instance
end

function ParallelLineSettingsDialogVines.getInstance()
	return instance
end

function ParallelLineSettingsDialogVines:delete()
	if self.isOpen then
		self:close()
	end

	-- Force close the current UI
	g_gui:showGui(nil)

	self:superClass().delete(self)
	instance = nil

	-- Fixes bugs with keyboard focus
	FocusManager.guiFocusData["ParallelLineSettingsDialogVines"] = {
		idToElementMapping = {}
	}
end

function ParallelLineSettingsDialogVines:reload()
	g_gui.currentlyReloading = true

	local settingsObject = self.settingsObject
	self:delete()
	self = ParallelLineSettingsDialogVines.createInstance(settingsObject)
	self:register()

	g_gui.currentlyReloading = false

	self:show()
end
---Registers the dialog with g_gui
function ParallelLineSettingsDialogVines:register()
	local xmlPath = Utils.getFilename("gui/ParallelLineSettingsDialogVines.xml", MOD_DIR)
	g_gui:loadGui(xmlPath, ParallelLineSettingsDialogVines.DIALOG_ID, self)
end

---Reacts on yes/no presses and calls the callback function which was supplied to the constructor, in the yes case
---@param yesWasPressed boolean @True if yes was pressed, false otherwise
function ParallelLineSettingsDialogVines:onYesNo(yesWasPressed)
	if yesWasPressed then
		local settings = {
			forwardLength = (self.forwardLengthSetting.state - 1) * ParallelLineSettingsDialogVines.LENGTH_STEP,
			reverseLength = (self.reverseLengthSetting.state - 1) * ParallelLineSettingsDialogVines.LENGTH_STEP,
			headlandWidth = self.headlandWidthSetting.state - 1,
			stripWidth = self.stripWidthSetting.state + 6 - 1,
			numberOfParallelLinesRight = self.numberOfParallelLinesRightSetting.state - 1,
			numberOfParallelLinesLeft = self.numberOfParallelLinesLeftSetting.state - 1
		}
		if settings.forwardLength == 0 and settings.reverseLength == 0 then
			Logging.error("You need to set at least forward length or reverse length > 0")
			return
		end
		printf("Calling callback function with grassType = %s", settings.grassType)
		self.settings:applySettings(settings)
	end
end

function ParallelLineSettingsDialogVines:initializeValues()
	-- One-time initialization
	for i = 0, 5000, 50 do
		table.insert(ParallelLineSettingsDialogVines.LENGTH_STRINGS, ("%d m"):format(i))
	end
	local headlandWidth = {}
	for i = 0, 72 do
		table.insert(headlandWidth, ("%d m"):format(i))
	end
	local stripWidth = {}
	for i = 6, 72 do
		table.insert(stripWidth, ("%d m"):format(i))
	end
	local amountValues = {}
	for i = 0, 50 do
		table.insert(amountValues, ("%d"):format(i))
	end

	self.forwardLengthSetting:setTexts(ParallelLineSettingsDialogVines.LENGTH_STRINGS)
	self.reverseLengthSetting:setTexts(ParallelLineSettingsDialogVines.LENGTH_STRINGS)
	self.headlandWidthSetting:setTexts(headlandWidth)
	self.stripWidthSetting:setTexts(stripWidth)
	self.numberOfParallelLinesRightSetting:setTexts(amountValues)
	self.numberOfParallelLinesLeftSetting:setTexts(amountValues)
end

---Displays the dialog
function ParallelLineSettingsDialogVines:show()
	self:applySettings(self.settings)
	self:setDialogType(DialogElement.TYPE_QUESTION)
	g_gui:showDialog(ParallelLineSettingsDialogVines.DIALOG_ID)
end

function ParallelLineSettingsDialogVines:applySettings(settings)
	self.forwardLengthSetting:setState((settings.forwardLength / ParallelLineSettingsDialogVines.LENGTH_STEP) + 1)
	self.reverseLengthSetting:setState((settings.reverseLength / ParallelLineSettingsDialogVines.LENGTH_STEP) + 1)
	self.headlandWidthSetting:setState(settings.headlandWidth + 1)
	self.stripWidthSetting:setState(settings.stripWidth - 6 + 1)
	self.numberOfParallelLinesRightSetting:setState(settings.numberOfParallelLinesRight + 1)
	self.numberOfParallelLinesLeftSetting:setState(settings.numberOfParallelLinesLeft + 1)
end

function ParallelLineSettingsDialogVines:onFrameOpen(element)
	ParallelLineSettingsDialogVines:superClass().onFrameOpen(self)
end