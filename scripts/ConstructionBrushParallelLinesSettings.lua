---Stores the settings for the parallel lines construction brush
---@class ConstructionBrushParallelLinesSettings
---@field forwardLength table @The length in forward direction
---@field reverseLength table @The length in reverse direction
---@field headlandWidth table @The headland width
---@field stripWidth table @The strip width 
---@field keylineWidth table @The keyline width
---@field numberOfParallelLinesRight table @The number of parallel lines to the right of the keyline
---@field numberOfParallelLinesLeft table @The number of parallel lines to the left of the keyline
---@field grassType table @The grass type
---@field grassBrushParameters table @The brush parameters for the selected grass type
---@field bushType table @The bush type
---@field bushWidth table @The bush width
---@field bushBrushParameters table @The brush parameters for the selected bush type
---@field treeMinGrowthStage table @The minimum growth stage for trees to be placed
---@field treeMaxGrowthStage table @The maximum growth stage for trees to be placed
---@field treeGrowthBehavior table @The growth behavior for trees to be placed
---@field treeType32 table @The tree type to place every 32 meters
---@field treeType16 table @The tree type to place every 16 meters, unless there is a tree in the spot already
---@field treeType8 table @The tree type to place every 8 meters, unless there is a tree in the spot already
---@field treeType4 table @The tree type to place every 4 meters, unless there is a tree in the spot already
---@field treeType2 table @The tree type to place every 2 meters, unless there is a tree in the spot already
ConstructionBrushParallelLinesSettings = {}
local ConstructionBrushParallelLinesSettings_mt = Class(ConstructionBrushParallelLinesSettings)

function ConstructionBrushParallelLinesSettings.new()
	local self = setmetatable({}, ConstructionBrushParallelLinesSettings_mt)
	self.forwardLength = 500
	self.reverseLength = 500
	self.headlandWidth = 18
	self.stripWidth = 18
	self.keylineWidth = 6
	self.numberOfParallelLinesRight = 10
	self.numberOfParallelLinesLeft = 10
	self.treeMinGrowthStage = 1
	self.treeMaxGrowthStage = 7
	self.treeGrowthBehavior = ParallelLineSettingsDialogTree.TREE_GROWTH_BEHAVIOR.GROWING
	self.grassType = 1
	self.bushType = 1
	self.bushWidth = 1
	self.treeType32 = 1
	self.treeType16 = 1
	self.treeType8 = 1
	self.treeType4 = 1
	self.treeType2 = 1
	self.grassBrushParameters = {}
	self.bushBrushParameters = {}
	return self
end

function ConstructionBrushParallelLinesSettings:applySettings(settings)
	printf("Updating settings. grassType=%s", settings.grassType)
	self.forwardLength = settings.forwardLength
	self.reverseLength = settings.reverseLength
	self.headlandWidth = settings.headlandWidth
	self.stripWidth = settings.stripWidth
	self.keylineWidth = settings.keylineWidth
	self.numberOfParallelLinesLeft = settings.numberOfParallelLinesLeft
	self.numberOfParallelLinesRight = settings.numberOfParallelLinesRight
	self.treeMinGrowthStage = settings.treeMinGrowthStage
	self.treeMaxGrowthStage = settings.treeMaxGrowthStage
	self.treeGrowthBehavior = settings.treeGrowthBehavior
	self.grassType = settings.grassType
	self.grassBrushParameters = settings.grassBrushParameters
	self.bushType = settings.bushType
	self.bushBrushParameters = settings.bushBrushParameters
	self.bushWidth = settings.bushWidth
	self.treeType32 = settings.treeType32
	self.treeType16 = settings.treeType16
	self.treeType8 = settings.treeType8
	self.treeType4 = settings.treeType4
	self.treeType2 = settings.treeType2
end

---Writes event data to be sent to the server
---@param streamId number The ID of the network stream
function ConstructionBrushParallelLinesSettings:sendDataToServer(streamId)
	streamWriteUInt16(streamId, self.forwardLength)
	streamWriteUInt16(streamId, self.reverseLength)
	streamWriteUInt16(streamId, self.headlandWidth)
	streamWriteUInt16(streamId, self.stripWidth)
	streamWriteUInt16(streamId, self.keylineWidth)

	streamWriteUInt8(streamId, self.numberOfParallelLinesRight)
	streamWriteUInt8(streamId, self.numberOfParallelLinesLeft)
	streamWriteUInt8(streamId, self.grassType)
	streamWriteUInt8(streamId, self.bushType)
	streamWriteUInt8(streamId, self.bushWidth)
	streamWriteUInt8(streamId, self.treeMinGrowthStage)
	streamWriteUInt8(streamId, self.treeMaxGrowthStage)
	streamWriteUInt8(streamId, self.treeGrowthBehavior)
	streamWriteUInt8(streamId, self.treeType32)
	streamWriteUInt8(streamId, self.treeType16)
	streamWriteUInt8(streamId, self.treeType8)
	streamWriteUInt8(streamId, self.treeType4)
	streamWriteUInt8(streamId, self.treeType2)

	-- Write grass brush parameters
	streamWriteUInt8(streamId, self.grassBrushParameters.foliageId)
	streamWriteUInt8(streamId, self.grassBrushParameters.value)

	-- Write bush brush parameters
	streamWriteUInt8(streamId, self.bushBrushParameters.foliageId)
	streamWriteUInt8(streamId, self.bushBrushParameters.value)
end

---Reads event data which was sent from the client
---@param streamId number The ID of the network stream
function ConstructionBrushParallelLinesSettings:receiveDataFromClient(streamId)
	self.forwardLength = streamReadUInt16(streamId)
	self.reverseLength = streamReadUInt16(streamId)
	self.headlandWidth = streamReadUInt16(streamId)
	self.stripWidth = streamReadUInt16(streamId)
	self.keylineWidth = streamReadUInt16(streamId)
	
	self.numberOfParallelLinesRight = streamReadUInt8(streamId)
	self.numberOfParallelLinesLeft = streamReadUInt8(streamId)
	self.grassType = streamReadUInt8(streamId)
	self.bushType = streamReadUInt8(streamId)
	self.bushWidth = streamReadUInt8(streamId)
	self.treeMinGrowthStage = streamReadUInt8(streamId)
	self.treeMaxGrowthStage = streamReadUInt8(streamId)
	self.treeGrowthBehavior = streamReadUInt8(streamId)
	self.treeType32 = streamReadUInt8(streamId)
	self.treeType16 = streamReadUInt8(streamId)
	self.treeType8 = streamReadUInt8(streamId)
	self.treeType4 = streamReadUInt8(streamId)
	self.treeType2 = streamReadUInt8(streamId)

	-- Read grass brush parameters
	self.grassBrushParameters.foliageId = streamReadUInt8(streamId)
	self.grassBrushParameters.value = streamReadUInt8(streamId)

	-- Read bush brush parameters
	self.bushBrushParameters.foliageId = streamReadUInt8(streamId)
	self.bushBrushParameters.value = streamReadUInt8(streamId)
end

local instance
function ConstructionBrushParallelLinesSettings.createInstance()
	instance = ConstructionBrushParallelLinesSettings.new()
	return instance
end

function ConstructionBrushParallelLinesSettings.getInstance()
	return instance
end

function ConstructionBrushParallelLinesSettings:isGrassEnabled()
	return self.grassType ~= 1
end
function ConstructionBrushParallelLinesSettings:getGrassType()
	return self.grassType - 1
end
function ConstructionBrushParallelLinesSettings:isBushEnabled()
	return self.bushType ~= 1
end
function ConstructionBrushParallelLinesSettings:getBushType()
	return self.bushType - 1
end

function ConstructionBrushParallelLinesSettings:isTreeType32Enabled()
	return self.treeType32 ~= 1
end
function ConstructionBrushParallelLinesSettings:getTreeType32()
	return self.treeType32 - 1
end
function ConstructionBrushParallelLinesSettings:isTreeType16Enabled()
	return self.treeType16 ~= 1
end
function ConstructionBrushParallelLinesSettings:getTreeType16()
	return self.treeType16 - 1
end
function ConstructionBrushParallelLinesSettings:isTreeType8Enabled()
	return self.treeType8 ~= 1
end
function ConstructionBrushParallelLinesSettings:getTreeType8()
	return self.treeType8 - 1
end
function ConstructionBrushParallelLinesSettings:isTreeType4Enabled()
	return self.treeType4 ~= 1
end
function ConstructionBrushParallelLinesSettings:getTreeType4()
	return self.treeType4 - 1
end
function ConstructionBrushParallelLinesSettings:isTreeType2Enabled()
	return self.treeType2 ~= 1
end
function ConstructionBrushParallelLinesSettings:getTreeType2()
	return self.treeType2 - 1
end