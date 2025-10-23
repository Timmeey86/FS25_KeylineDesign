-- Local values: ConstructionBrushParallelLines_mt
ConstructionBrushParallelLines = {}
local ConstructionBrushParallelLines_mt = Class(ConstructionBrushParallelLines, ConstructionBrush)
ConstructionBrushParallelLines.CURSOR_SIZES = {
	6
}
ConstructionBrushParallelLines.MODES = {
	TERRAIN = 1,
	STRAIGHT = 2
}


function ConstructionBrushParallelLines.new(subclass_mt, cursor)
	local self = ConstructionBrushParallelLines:superClass().new(subclass_mt or ConstructionBrushParallelLines_mt, cursor)
	self.brushIdentifier = "keylines"
	self.supportsPrimaryButton = true
	self.supportsPrimaryDragging = false
	self.requiredPermission = Farm.PERMISSION.LANDSCAPING
	self.supportsPrimaryAxis = true
	self.primaryAxisIsContinuous = false
	self.supportsSecondaryButton = true
	self.supportsTertiaryButton = true
	self.supportsSecondaryAxis = true
	self.secondaryAxisIsContinuous = false
	self.maxBrushRadius = ConstructionBrushParallelLines.CURSOR_SIZES[#ConstructionBrushParallelLines.CURSOR_SIZES] / 2
	self.freeMode = false
	self.angle = 0
	self.importedParallelLines = {}
	self.keylines = {}
	self.exportedKeylines = {}
	self.settings = ConstructionBrushParallelLinesSettings.getInstance()
	self.keylineMode = ConstructionBrushParallelLines.MODES.TERRAIN
	self.randomseed = getTimeSec()
	return self
end

function ConstructionBrushParallelLines:delete()
	ConstructionBrushParallelLines:superClass().delete(self)
end

function ConstructionBrushParallelLines:activate()
	ConstructionBrushParallelLines:superClass().activate(self)
	self.brushShape = Landscaping.BRUSH_SHAPE.CIRCLE
	self.cursor:setRotationEnabled(false)
	self.cursor:setShape(GuiTopDownCursor.SHAPES.CIRCLE)
	self.cursor:setColorMode(GuiTopDownCursor.SHAPES_COLORS.PAINTING)
	self.cursor:setTerrainOnly(true)
end

function ConstructionBrushParallelLines:deactivate()
	TreePreviewManager.removeCurrentPreviewTrees()
	self.cursor:setTerrainOnly(false)
	g_messageCenter:unsubscribeAll(self)
	ConstructionBrushParallelLines:superClass().deactivate(self)
end

function ConstructionBrushParallelLines:copyState(from)
	self.angle = from.angle
	self.importedParallelLines = {}
	self.keylines = {}
	self.exportedKeylines = {}
	self.settings = ConstructionBrushParallelLinesSettings.getInstance()
	self.keylineMode = from.keylineMode
end

function ConstructionBrushParallelLines:setGroundType(groundTypeName)
	if not self.isActive then
		self.terrainLayer = g_groundTypeManager:getTerrainLayerByType(groundTypeName)
	end
end

function ConstructionBrushParallelLines:setParameters(groundTypeName)
	self:setGroundType(groundTypeName)
end

function ConstructionBrushParallelLines:update(dt)
	ConstructionBrushParallelLines:superClass().update(self, dt)

	-- Update just the keyline. The rest is calculated on right-click
	self:updateKeyline()

	KeylineCalculation.drawLines(self.keylines, self.exportedKeylines, self.importedParallelLines)

end


function ConstructionBrushParallelLines:updateKeyline()
	local x, y, z = self.cursor:getHitTerrainPosition()
	self.keylines = {}
	if x ~= nil then
		local pointDistance = 1
		local initialXDir, initialZDir = MathUtil.getDirectionFromYRotation(self.angle * math.pi / 180)

		if self.keylineMode == self.MODES.TERRAIN then
			-- Get the central keyline first
			local keylineCoords = KeylineCalculation.getSingleKeylineCoords(x, y, z, initialXDir, initialZDir, pointDistance, self.settings.forwardLength)
			table.insert(self.keylines, keylineCoords)
			-- Get the same line in reverse direction
			local inverseKeylineCoords = KeylineCalculation.getSingleKeylineCoords(x, y, z, -initialXDir, -initialZDir, pointDistance, self.settings.reverseLength)
			table.insert(self.keylines, inverseKeylineCoords)
		else
			local straightLineCoords = KeylineCalculation.getStraightLineCoords(x, z, self.angle, self.settings.forwardLength, 1)
			table.insert(self.keylines, straightLineCoords)
			straightLineCoords = KeylineCalculation.getStraightLineCoords(x, z, self.angle, self.settings.reverseLength, -1)
			table.insert(self.keylines, straightLineCoords)
		end
	else
		self.importedParallelLines = {}
	end
end


function ConstructionBrushParallelLines:onButtonPrimary(isDown, isDrag, isUp)
	self:setActiveSound(ConstructionSound.ID.NONE)
	if isUp then
		self.lastX = nil
		return
	else
		local event = ParallelLinePlacementEvent.new(self.importedParallelLines, self.settings, self.terrainLayer, self.randomseed)
		if g_currentMission:getIsServer() then
			-- Enqueue an event (we won't actually send that over the network, but this way we have a consistent interface)
			ParallelLinePlacementHandler.addPlacementEvent(event)
		else
			-- Send an event to the server. The event will enqueue itself into the same queue as above, once received by the server
			g_client:getServerConnection():sendEvent(event)
		end
		self.keylines = {}
		self.exportedKeylines = {}
		self.importedParallelLines = {}
	end
end

function ConstructionBrushParallelLines:onAxisPrimary()
	self.keylineMode = (self.keylineMode % 2) + 1
	g_inputBinding:setActionEventTextVisibility(self.secondaryBrushAxisEvent, self.keylineMode == self.MODES.STRAIGHT)
end

function ConstructionBrushParallelLines:onAxisSecondary(delta)
	self.angle = (self.angle + delta * 5) % 360
end

function ConstructionBrushParallelLines:onButtonSecondary()
	self.exportedKeylines = {}
	self.importedParallelLines = {}
	table.insert(self.exportedKeylines, ExportImportInterface.exportKeylines(self.keylines, self.settings))
end

function ConstructionBrushParallelLines:onButtonTertiary()
	self.importedParallelLines = ExportImportInterface.importParallelLines()

	-- Generate new tree previews
	TreePreviewManager.removeCurrentPreviewTrees()

	-- Generate and remember a random seed since we are going to calculate the preview on the client and the actual trees on the server
	-- By transferring the random seed to the server, we can ensure that the actual placement matches the preview
	self.randomseed = getTimeSec()
	math.randomseed(self.randomseed)

	for _, coords in ipairs(self.importedParallelLines) do
		local keylineTreeLoadingData = ParallelLinePlacementHandler.calculateTreeLoadingData(coords, self.settings)
		for _, data in ipairs(keylineTreeLoadingData) do
			-- Instead of planting the tree already, show a preview instead
			TreePreviewManager.enqueueTreePreviewData(data.treeType, data.treeStageIndex, data.variationIndex, data.x, data.y, data.z, data.rotation, data.isGrowing)
		end
	end
end

function ConstructionBrushParallelLines:getButtonPrimaryText()
	return "3 - " .. g_i18n:getText("input_CONSTRUCTION_PAINT")
end

function ConstructionBrushParallelLines:getAxisPrimaryText()
	return "Change mode"
end

function ConstructionBrushParallelLines:getButtonSecondaryText()
	return "1 - Export keyline"
end

function ConstructionBrushParallelLines:getButtonTertiaryText()
	return "2 - Import parallel lines"
end

function ConstructionBrushParallelLines:getAxisSecondaryText()
	return ("Change angle: %d°"):format(self.angle)
end

function ConstructionBrushParallelLines:onOpenSettingsDialog()
	printf("Keyline Design: Opening settings dialog")
	ParallelLineSettingsDialogTree.getInstance():show()
end

-- Allow opening the settings menu, but in a non-standard way which shows a dialog instead
ConstructionScreen.registerBrushActionEvents = Utils.appendedFunction(ConstructionScreen.registerBrushActionEvents, function(constructionScreen)
	-- Make sure we are extending the right brush
	if constructionScreen.brush and constructionScreen.brush.brushIdentifier == "keylines" then
		printf("Keyline Design: Injecting button for settings dialog")
		local isValid
		isValid, constructionScreen.showConfigsEvent = g_inputBinding:registerActionEvent(InputAction.CONSTRUCTION_SHOW_CONFIGS, constructionScreen.brush, constructionScreen.brush.onOpenSettingsDialog, false, true, false, true)
		printf("Keyline Design: event ID = %s, isValid = %s", constructionScreen.showConfigsEvent, isValid)
		g_inputBinding:setActionEventText(constructionScreen.showConfigsEvent, g_i18n:getText("input_CONSTRUCTION_SHOW_CONFIGS"))
		g_inputBinding:setActionEventTextPriority(constructionScreen.showConfigsEvent, GS_PRIO_HIGH)
		table.insert(constructionScreen.brushEvents, constructionScreen.showConfigsEvent)
	end
end)
