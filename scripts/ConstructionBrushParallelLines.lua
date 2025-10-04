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
	self.pendingFoliageEvents = {}
	self.pendingBushEvents = {}
	self.isProcessingEvents = false
	self.keylineMode = ConstructionBrushParallelLines.MODES.TERRAIN
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
	g_messageCenter:subscribe(LandscapingSculptEvent, self.onSculptingFinished, self)
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
	self.pendingFoliageEvents = {}
	self.pendingBushEvents = {}
	self.isProcessingEvents = false
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

local delay = 100
function ConstructionBrushParallelLines:update(dt)
	ConstructionBrushParallelLines:superClass().update(self, dt)

	-- Update just the keyline. The rest is calculated on right-click
	self:updateKeyline()

	KeylineCalculation.drawLines(self.keylines, self.exportedKeylines, self.importedParallelLines)

	-- Draw all lines
	if not self.isProcessingEvents and #self.pendingFoliageEvents > 0 then
		if delay <= 0 then
			self.isProcessingEvents = true
			printf("Processing %d pending foliage events", #self.pendingFoliageEvents)
			for _, event in ipairs(self.pendingFoliageEvents) do
				g_client:getServerConnection():sendEvent(event)
			end
			self.pendingFoliageEvents = {}
			self.isProcessingEvents = false
			delay = 100
		else
			-- If we paint foliage too early, it seems to be executed before painting the ground, which will prevent the foliage from appearing in the first place
			delay = delay - dt
		end
	-- delay bushes once more so grass doesn't interfere with them
	elseif not self.isProcessingEvents and #self.pendingBushEvents > 0 then
		if delay <= 0 then
			self.isProcessingEvents = true
			printf("Processing %d pending bush events", #self.pendingBushEvents)
			for _, event in ipairs(self.pendingBushEvents) do
				g_client:getServerConnection():sendEvent(event)
			end
			self.pendingBushEvents = {}
			self.isProcessingEvents = false
			delay = 100
		else
			-- If we paint foliage too early, it seems to be executed before painting the ground, which will prevent the foliage from appearing in the first place
			delay = delay - dt
		end
	end

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

function ConstructionBrushParallelLines:onSculptingFinished(isValidation, errorCode, displacedVolumeOrArea) end


function ConstructionBrushParallelLines:onButtonPrimary(isDown, isDrag, isUp)
	self:setActiveSound(ConstructionSound.ID.NONE)
	if isUp then
		self.lastX = nil
		return
	else
		if #self.importedParallelLines > 0 then
			-- Start removing previews. 
			-- Note: If it turns out the temporary overlapping between actual and preview trees causes issues, we'll have to enqueue tree placement in the tree preview manager instead of spawning them in here
			local treePreviewData = TreePreviewManager.getCurrentPreviewData()
			TreePreviewManager.removeCurrentPreviewTrees()

			for _, coordList in ipairs(self.importedParallelLines) do
				local processedCoords = 0
				for i = 1, #coordList do
					local coord = coordList[i]
					processedCoords = processedCoords + 1
					local err = self:verifyAccess(coord.x, coord.y, coord.z)
					if err == nil or self.freeMode and err == ConstructionBrush.ERROR.PLACEMENT_BLOCKED then

						-- paint the ground
						local requestLandscaping = LandscapingSculptEvent.new(false, Landscaping.OPERATION.PAINT, coord.x, coord.y, coord.z, nil, nil, nil, nil, nil, nil, self.settings.keylineWidth / 2.0, 1, Landscaping.BRUSH_SHAPE.CIRCLE, 1, self.terrainLayer)
						g_client:getServerConnection():sendEvent(requestLandscaping)

						-- plant grass if desired
						if self.settings:isGrassEnabled() then
							self:enqueueFoliagePaintEvent(self.pendingFoliageEvents, coord, self.settings.grassBrushParameters, self.settings.keylineWidth)
						end
						if self.settings:isBushEnabled() then
							local width = self.settings.bushWidth
							self:enqueueFoliagePaintEvent(self.pendingBushEvents, coord, self.settings.bushBrushParameters, width)
						end
					else
						self.cursor:setErrorMessage(g_i18n:getText(ConstructionBrush.ERROR_MESSAGES[err]))
					end
				end
			end
			-- Plant all trees
			for _, data in ipairs(treePreviewData) do
				g_treePlantManager:plantTree(data.treeType.index, data.x, data.y, data.z, 0, data.ry, 0, data.treeStage, data.variationIndex, data.isGrowing)
			end
			self.keylines = {}
			self.exportedKeylines = {}
			self.importedParallelLines = {}
		else
			printf("No parallel lines were imported")
		end
	end
	printf("Finished placing things, except for foliage")
end

function ConstructionBrushParallelLines:enqueueFoliagePaintEvent(eventTable, coord, params, width)
	local radius = width * 0.5
	if params then
		local foliagePaint = g_currentMission.foliageSystem:getFoliagePaintByName(params.foliageName)
		local foliageValue = params.value
		if foliagePaint and foliageValue then
			local event = LandscapingSculptEvent.new(false, Landscaping.OPERATION.FOLIAGE, coord.x, coord.y, coord.z, nil, nil, nil, nil, nil, nil, radius, 1, Landscaping.BRUSH_SHAPE.CIRCLE, 0, nil, foliagePaint.id, tonumber(foliageValue))
			table.insert(eventTable, event)
		end
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


	for _, coords in ipairs(self.importedParallelLines) do
		local keylineTreeLoadingData = self:calculateTreeLoadingData(coords)
		for _, data in ipairs(keylineTreeLoadingData) do
			-- Instead of planting the tree already, show a preview instead
			TreePreviewManager.enqueueTreePreviewData(data.treeType, data.treeStageIndex, data.variationIndex, data.x, data.y, data.z, data.rotation, data.isGrowing)
		end
	end
end

function ConstructionBrushParallelLines:calculateTreeLoadingData(coordList)
	local treeLoadingData = {}
	for i = 1, #coordList do
		local coord = coordList[i]
		-- create previews for evenly spaced trees
		local treeTypeIndex = nil
		if (i-1) % 32 == 0 and self.settings:isTreeType32Enabled() then
			treeTypeIndex = self.settings:getTreeType32()
		elseif (i-1) % 16 == 0 and self.settings:isTreeType16Enabled() then
			treeTypeIndex = self.settings:getTreeType16()
		elseif (i-1) % 8 == 0 and self.settings:isTreeType8Enabled() then
			treeTypeIndex = self.settings:getTreeType8()
		elseif (i-1) % 4 == 0 and self.settings:isTreeType4Enabled() then
			treeTypeIndex = self.settings:getTreeType4()
		elseif (i-1) % 2 == 0 and self.settings:isTreeType2Enabled() then
			treeTypeIndex = self.settings:getTreeType2()
		end

		if treeTypeIndex ~= nil then
			local treeType = g_treePlantManager:getTreeTypeDescFromIndex(treeTypeIndex)
			if not treeType then
				Logging.error("Could not find tree type with index %s", treeTypeIndex)
				continue
			end
			local maxTreeStage = math.min(#treeType.stages, self.settings.treeMaxGrowthStage)
			local minTreeStage = math.min(#treeType.stages, self.settings.treeMinGrowthStage)
			local treeStageIndex = math.random(minTreeStage, maxTreeStage)
			local treeStage = treeType.stages[treeStageIndex]

			-- Get a random variation in case the tree has more than one variation
			-- Note that there is a case where the tree is sapling-only, and the treeType.stages table does not
			-- contain stages, but rather planter configuration data, which is why we check for at least two stages
			local maxVariation = #treeStage > 2 and #treeStage or 1
			local variationIndex = math.random(1, maxVariation)

			-- random rotation to make it look more natural
			local rotation = math.random() * 2 * math.pi

			local isGrowing = self.settings.treeGrowthBehavior == ParallelLineSettingsDialogTree.TREE_GROWTH_BEHAVIOR.GROWING

			table.insert(treeLoadingData, {treeType = treeType, treeStageIndex = treeStageIndex, variationIndex = variationIndex, rotation = rotation, x = coord.x, y = coord.y, z = coord.z, isGrowing = isGrowing})
		end
	end
	return treeLoadingData
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
	return "Change angle"
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
