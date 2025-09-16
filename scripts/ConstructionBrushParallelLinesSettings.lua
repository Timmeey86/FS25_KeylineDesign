---Stores the settings for the parallel lines construction brush
---@class ConstructionBrushParallelLinesSettings
---@field length table @The length 
---@field stripWidth table @The strip width 
---@field resolution table @The resolution 
---@field grassType table @The grass type 
---@field shrubType table @The shrub type 
---@field treeType16 table @The tree type to place every 16 meters 
---@field treeType8 table @The tree type to place every 8 meters, unless there is a tree in the spot already
---@field treeType4 table @The tree type to place every 4 meters, unless there is a tree in the spot already
---@field treeType2 table @The tree type to place every 2 meters, unless there is a tree in the spot already
---@field treeType1 table @The tree type to place every meter, unless there is a tree in the spot already
ConstructionBrushParallelLinesSettings = {}
local ConstructionBrushParallelLinesSettings_mt = Class(ConstructionBrushParallelLinesSettings)

function ConstructionBrushParallelLinesSettings.new()
	local self = setmetatable({}, ConstructionBrushParallelLinesSettings_mt)
	self.length = 500
	self.stripWidth = 16
	self.resolution = 1
	self.grassType = 1
	self.shrubType = 1
	self.treeType16 = 1
	self.treeType8 = 1
	self.treeType4 = 1
	self.treeType2 = 1
	self.treeType1 = 1
	return self
end

function ConstructionBrushParallelLinesSettings:applySettings(settings)
	printf("Updating settings. grassType=%s", settings.grassType)
	self.length = settings.length
	self.stripWidth = settings.stripWidth
	self.resolution = settings.resolution
	self.grassType = settings.grassType
	self.shrubType = settings.shrubType
	self.treeType16 = settings.treeType16
	self.treeType8 = settings.treeType8
	self.treeType4 = settings.treeType4
	self.treeType2 = settings.treeType2
	self.treeType1 = settings.treeType1
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

function ConstructionBrushParallelLinesSettings:isShrubEnabled()
	return self.shrubType ~= 1
end
function ConstructionBrushParallelLinesSettings:getShrubType()
	return self.shrubType - 1
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
function ConstructionBrushParallelLinesSettings:isTreeType1Enabled()
	return self.treeType1 ~= 1
end
function ConstructionBrushParallelLinesSettings:getTreeType1()
	return self.treeType1 - 1
end