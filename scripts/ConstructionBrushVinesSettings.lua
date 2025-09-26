---Stores the settings for the parallel lines construction brush
---@class ConstructionBrushVinesSettings
---@field forwardLength table @The length in forward direction
---@field reverseLength table @The length in reverse direction
---@field headlandWidth table @The headland width
---@field stripWidth table @The strip width 
---@field numberOfParallelLinesRight table @The number of parallel lines to the right of the keyline
---@field numberOfParallelLinesLeft table @The number of parallel lines to the left of the keyline
ConstructionBrushVinesSettings = {}
local ConstructionBrushVinesSettings_mt = Class(ConstructionBrushVinesSettings)

function ConstructionBrushVinesSettings.new()
	local self = setmetatable({}, ConstructionBrushVinesSettings_mt)
	self.forwardLength = 500
	self.reverseLength = 500
	self.headlandWidth = 12
	self.stripWidth = 0
	self.numberOfParallelLinesRight = 50
	self.numberOfParallelLinesLeft = 50
	return self
end

function ConstructionBrushVinesSettings:applySettings(settings)
	self.forwardLength = settings.forwardLength
	self.reverseLength = settings.reverseLength
	self.headlandWidth = settings.headlandWidth
	self.stripWidth = settings.stripWidth
	self.numberOfParallelLinesLeft = settings.numberOfParallelLinesLeft
	self.numberOfParallelLinesRight = settings.numberOfParallelLinesRight
end

local instance
function ConstructionBrushVinesSettings.createInstance()
	instance = ConstructionBrushVinesSettings.new()
	return instance
end

function ConstructionBrushVinesSettings.getInstance()
	return instance
end