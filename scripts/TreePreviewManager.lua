---This class is responsible for temporarily rendering and correctly unloading a single Preview Tree.
---It reuses ConstructionBrushTree whereever possible, but allows multiple previews
---@class TreePreviewHelper
---@field treeType string @The name of the tree to render. Required by ConstructionBrushTree.loadTree
---@field treeStage number @The stage of the tree to be loaded. Required by ConstructionBrushTree.loadTree
---@field variationIndex number @The tree variation index. Set to a random value by ConstructionBrush.loadTree unless set before
---@field treeGrowthFactor number @The growth factor of the tree to be loaded. Set by ConstructionBrushTree.loadTree
---@field treeTypeIndex number @The index of the tree type. Set by ConstructionBrushTree.loadTree
---@field sharedLoadRequestId number @The ID of the loadSharedI3DFile request. Set by ConstructionBrushTree.loadTree and unset by ConstructionBrushTree.onTreeLoaded or ConstructionBrushTree.unloadTree
---@field tree number @The node ID of the tree. Set by ConstructionBrushTree.onTreeLoaded and unset by ConstructionBrushTree.unloadTree
---@field x number @The x position where the tree should be rendered
---@field y number @The y position where the tree should be rendered
---@field z number @The z position where the tree should be rendered
---@field ry number @The y rotation of the tree

TreePreviewHelper = {}
local TreePreviewHelper_mt = Class(TreePreviewHelper)

---Creates a new instance
function TreePreviewHelper.new(treeType, treeStage, variationIndex, x, y, z, ry)
	local self = setmetatable({}, TreePreviewHelper_mt)
	self.treeType = treeType.name
	self.treeStage = treeStage
	self.variationIndex = variationIndex
	self.treeGrowthFactor = nil
	self.treeTypeIndex = nil
	self.sharedLoadRequestId = nil
	self.tree = nil
	self.x = x
	self.y = y
	self.z = z
	self.ry = ry
	self.isActive = true -- required so the previews are actually being loaded
	return self
end

function TreePreviewHelper:loadTree()
	printf("Loading tree preview: type %s, stage %d, variation %d at (%.1f, %.1f, %.1f) rotY %.1f", self.treeType, self.treeStage, self.variationIndex, self.x, self.y, self.z, self.ry)
	-- Pass our own instance to the base game function. It will set any values in our instance and call onTreeLoaded in our class as well
	ConstructionBrushTree.loadTree(self)
	printf("Tree: %s", self.tree)
	-- Apply the translation and rotation - our tree won't move
	if self.tree ~= nil then
		setTranslation(self.tree, self.x, self.y, self.z)
		setRotation(self.tree, 0, self.ry, 0)
		setVisibility(self.tree, true)
	end
end

function TreePreviewHelper:onTreeLoaded(i3dNode, failedReason)
	ConstructionBrushTree.onTreeLoaded(self, i3dNode, failedReason)
end

function TreePreviewHelper:unloadTree()
	if self.tree then
		setVisibility(self.tree, false)
	end

	ConstructionBrushTree.unloadTree(self)
end

-- functions for queue handling
local pendingLoadData = {}
local pendingUnloadData = {}
local currentPreviewTrees = {}

TreePreviewManager = {}
function TreePreviewManager.enqueueTreePreviewData(treeType, treeStage, variationIndex, x, y, z, ry)
	local instance = TreePreviewHelper.new(treeType, treeStage, variationIndex, x, y, z, ry)
	table.insert(pendingLoadData, instance)
end

function TreePreviewManager.removeCurrentPreviewTrees()
	for _, instance in ipairs(currentPreviewTrees) do
		table.insert(pendingUnloadData, instance)
	end
	currentPreviewTrees = {}

	-- clear the load queue as well, no point in loading these any longer
	pendingLoadData = {}
end

function TreePreviewManager.update(_, dt)

	-- process unloads first
	local startTime = getTimeSec()
	local frameBudget = 0.015 -- 15ms per frame (still > 60fps, assuming there's not much else going on)
	while getTimeSec() - startTime < frameBudget and #pendingUnloadData > 0 do
		local instance = table.remove(pendingUnloadData, 1)
		instance:unloadTree()
	end

	-- then load new trees
	while getTimeSec() - startTime < frameBudget and #pendingLoadData > 0 do
		local instance = table.remove(pendingLoadData, 1)
		instance:loadTree()
		table.insert(currentPreviewTrees, instance)
	end
end

-- causes TreePreviewManager.update to be called regularly
addModEventListener(TreePreviewManager)