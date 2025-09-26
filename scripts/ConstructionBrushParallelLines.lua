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
			for _, coordList in ipairs(self.importedParallelLines) do
				local removedCoords = 0
				local processedCoords = 0
				for i = 1, #coordList do
					local coord = coordList[i]
					if math.abs(coord.x) >= g_currentMission.terrainSize/2 or math.abs(coord.z) >= g_currentMission.terrainSize/2 then
						removedCoords = removedCoords + 1
						continue -- Skip any points which are out of bounds
					else
						processedCoords = processedCoords + 1
						local err = self:verifyAccess(coord.x, coord.y, coord.z)
						if err == nil or self.freeMode and err == ConstructionBrush.ERROR.PLACEMENT_BLOCKED then

							-- paint the ground
							local requestLandscaping = LandscapingSculptEvent.new(false, Landscaping.OPERATION.PAINT, coord.x, coord.y, coord.z, nil, nil, nil, nil, nil, nil, self.settings.keylineWidth / 2.0, 1, Landscaping.BRUSH_SHAPE.CIRCLE, 1, self.terrainLayer)
							g_client:getServerConnection():sendEvent(requestLandscaping)

							-- plant grass if desired
							if self.settings:isGrassEnabled() then
								local event = LandscapingSculptEvent.new(false, Landscaping.OPERATION.FOLIAGE, coord.x, coord.y, coord.z, nil, nil, nil, nil, nil, nil, self.settings.keylineWidth / 2.0, 1, Landscaping.BRUSH_SHAPE.CIRCLE, 0, nil, g_currentMission.foliageSystem:getFoliagePaintByName("meadow").id, self.settings:getGrassType())
								table.insert(self.pendingFoliageEvents, event)
							end

							-- plant evenly spaced trees
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
									return
								end
								local maxTreeStage = #treeType.stages
								-- Get a random stage so the player can harvest some trees during the first winter and replace them
								-- and will always have trees to replace
								local treeStageIndex = math.random(1, maxTreeStage)
								local treeStage = treeType.stages[treeStageIndex]
								-- Get a random variation in case the tree has more than one variation
								-- Note that there is a case where the tree is sapling-only, and the treeType.stages table does not
								-- contain stages, but rather planter configuration data
								local maxVariation = #treeStage > 2 and #treeStage or 1
								local variationIndex = math.random(1, maxVariation)
								local rotation = math.random() * 2 * math.pi
								local isGrowing = true
								g_treePlantManager:plantTree(treeTypeIndex, coord.x, coord.y, coord.z, 0, rotation, 0, treeStageIndex, variationIndex, isGrowing)
							end
						else
							self.cursor:setErrorMessage(g_i18n:getText(ConstructionBrush.ERROR_MESSAGES[err]))
						end
					end
				end
				printf("Removed/processed: %d/%d", removedCoords, processedCoords)
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
end

function ConstructionBrushParallelLines:getButtonPrimaryText()
	return "$l10n_input_CONSTRUCTION_PAINT"
end

function ConstructionBrushParallelLines:getAxisPrimaryText()
	return "Change mode"
end

function ConstructionBrushParallelLines:getButtonSecondaryText()
	return "Export keyline"
end

function ConstructionBrushParallelLines:getButtonTertiaryText()
	return "Import parallel lines"
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