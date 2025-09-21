-- Local values: ConstructionBrushParallelLines_mt
ConstructionBrushParallelLines = {}
local ConstructionBrushParallelLines_mt = Class(ConstructionBrushParallelLines, ConstructionBrush)
ConstructionBrushParallelLines.CURSOR_SIZES = {
	6
}

function ConstructionBrushParallelLines.new(subclass_mt, cursor)
	local self = ConstructionBrushParallelLines:superClass().new(subclass_mt or ConstructionBrushParallelLines_mt, cursor)
	self.supportsPrimaryButton = true
	self.supportsPrimaryDragging = false
	self.requiredPermission = Farm.PERMISSION.LANDSCAPING
	self.supportsPrimaryAxis = true
	self.primaryAxisIsContinuous = false
	self.supportsSecondaryButton = true
	self.supportsTertiaryButton = true
	self.maxBrushRadius = ConstructionBrushParallelLines.CURSOR_SIZES[#ConstructionBrushParallelLines.CURSOR_SIZES] / 2
	self.freeMode = false
	self.angle = 0
	self.importedParallelLines = {}
	self.keylines = {}
	self.exportedKeylines = {}
	self.settings = ConstructionBrushParallelLinesSettings.getInstance()
	self.pendingFoliageEvents = {}
	self.isProcessingEvents = false
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
	self:setBrushSize(1)
	g_messageCenter:subscribe(LandscapingSculptEvent, self.onSculptingFinished, self)
end

function ConstructionBrushParallelLines:deactivate()
	self.cursor:setTerrainOnly(false)
	g_messageCenter:unsubscribeAll(self)
	ConstructionBrushParallelLines:superClass().deactivate(self)
end

function ConstructionBrushParallelLines:copyState(from)
	self:setBrushSize(from.cursorSizeIndex)
	self.brushShape = from.brushShape
	if self.brushShape == Landscaping.BRUSH_SHAPE.CIRCLE then
		self.cursor:setShape(GuiTopDownCursor.SHAPES.CIRCLE)
	else
		self.cursor:setShape(GuiTopDownCursor.SHAPES.SQUARE)
	end
	self.freeMode = Utils.getNoNil(from.freeMode, self.freeMode)
end

function ConstructionBrushParallelLines:setGroundType(groundTypeName)
	if not self.isActive then
		self.terrainLayer = g_groundTypeManager:getTerrainLayerByType(groundTypeName)
	end
end

function ConstructionBrushParallelLines:setParameters(groundTypeName)
	self:setGroundType(groundTypeName)
end

function ConstructionBrushParallelLines:setBrushSize(index)
	local sizes = #ConstructionBrushParallelLines.CURSOR_SIZES
	self.cursorSizeIndex = math.clamp(index, 1, sizes)
	local size = ConstructionBrushParallelLines.CURSOR_SIZES[self.cursorSizeIndex]
	self.brushRadius = size / 2
	self.cursor:setShapeSize(size)
end

function ConstructionBrushParallelLines:toggleBrushShape()
	if self.brushShape == Landscaping.BRUSH_SHAPE.CIRCLE then
		self.brushShape = Landscaping.BRUSH_SHAPE.SQUARE
		self.cursor:setShape(GuiTopDownCursor.SHAPES.SQUARE)
	else
		self.brushShape = Landscaping.BRUSH_SHAPE.CIRCLE
		self.cursor:setShape(GuiTopDownCursor.SHAPES.CIRCLE)
	end
end


-- HSV to RGB conversion function
local function hsvToRgb(h, s, v)
	local r, g, b

	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local t = v * (1 - (1 - f) * s)

	i = i % 6

	if i == 0 then r, g, b = v, t, p
	elseif i == 1 then r, g, b = q, v, p
	elseif i == 2 then r, g, b = p, v, t
	elseif i == 3 then r, g, b = p, q, v
	elseif i == 4 then r, g, b = t, p, v
	elseif i == 5 then r, g, b = v, p, q
	end

	return r, g, b
end

local delay = 100
function ConstructionBrushParallelLines:update(dt)
	ConstructionBrushParallelLines:superClass().update(self, dt)

	-- Update just the keyline. The rest is calculated on right-click
	self:updateKeyline()

	-- Draw all lines
	local lines = {}
	for _, keyline in ipairs(self.keylines) do
		-- Current mouse keyline in red
		table.insert(lines, { coords = keyline, color = {1, 0, 0} })
	end
	for _, keyline in ipairs(self.exportedKeylines) do
		-- Exported keylines in yellow
		table.insert(lines, { coords = keyline, color = {1, 1, 0} })
	end
	for i = 1, #self.importedParallelLines do
		local curve = self.importedParallelLines[i]
		-- Cycle through 24 distinguishable colors based on i
		local colorIndex = ((i - 1) % 6) + 1
		local hue = (colorIndex - 1) / 6
		local r, g, b = hsvToRgb(hue, 1, 1)
		table.insert(lines, { coords = curve, color = {r, g, b} })
	end
	for j = 1, #lines do
		local curveData = lines[j]
		local color = curveData.color
		local curve = curveData.coords
		for i = 2, #curve do
			local x1, y1, z1 = curve[i - 1].x, curve[i - 1].y, curve[i - 1].z
			local x2, y2, z2 = curve[i].x,  curve[i].y, curve[i].z
			if y1 == nil or y2 == nil then
				break
			end
			DebugUtil.drawDebugLine(x1, y1 + 1, z1, x2, y2 + 1, z2, color[1], color[2], color[3], 0)

			--Utils.renderTextAtWorldPosition(x1, y1 + .4, z1 , string.format("%d", i-1), getCorrectTextSize(0.02), 0,color[1], color[2], color[3], 1)

		end
	end

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

		-- Get the central keyline first
		local keylineCoords = KeylineCalculation.getSingleKeylineCoords(x, y, z, initialXDir, initialZDir, pointDistance, self.settings.forwardLength)
		table.insert(self.keylines, keylineCoords)
		-- Get the same line in reverse direction
		local inverseKeylineCoords = KeylineCalculation.getSingleKeylineCoords(x, y, z, -initialXDir, -initialZDir, pointDistance, self.settings.reverseLength)
		table.insert(self.keylines, inverseKeylineCoords)
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
							self:setActiveSound(ConstructionSound.ID.PAINT, 1 - self.brushRadius / self.maxBrushRadius)

							-- paint the ground
							local requestLandscaping = LandscapingSculptEvent.new(false, Landscaping.OPERATION.PAINT, coord.x, coord.y, coord.z, nil, nil, nil, nil, nil, nil, self.brushRadius, 1, self.brushShape, 1, self.terrainLayer)
							g_client:getServerConnection():sendEvent(requestLandscaping)

							-- plant grass if desired
							if self.settings:isGrassEnabled() then
								local event = LandscapingSculptEvent.new(false, Landscaping.OPERATION.FOLIAGE, coord.x, coord.y, coord.z, nil, nil, nil, nil, nil, nil, self.brushRadius, 1, self.brushShape, 0, nil, g_currentMission.foliageSystem:getFoliagePaintByName("meadow").id, self.settings:getGrassType())
								table.insert(self.pendingFoliageEvents, event)
							end

							-- plant evenly spaced trees
							local treeStage = 2 -- first stage after sapling
							local variation = 1 -- TODO: Get max variations per tree type and pick random value
							local isGrowing = true
							if (i-1) % 32 == 0 and self.settings:isTreeType32Enabled() then
								-- TODO random orientation. Maybe also random variation
								g_treePlantManager:plantTree(self.settings:getTreeType32(), coord.x, coord.y, coord.z, 0, 0, 0, treeStage, variation, isGrowing)
							elseif (i-1) % 16 == 0 and self.settings:isTreeType16Enabled() then
								g_treePlantManager:plantTree(self.settings:getTreeType16(), coord.x, coord.y, coord.z, 0, 0, 0, treeStage, variation, isGrowing)
							elseif (i-1) % 8 == 0 and self.settings:isTreeType8Enabled() then
								g_treePlantManager:plantTree(self.settings:getTreeType8(), coord.x, coord.y, coord.z, 0, 0, 0, treeStage, variation, isGrowing)
							elseif (i-1) % 4 == 0 and self.settings:isTreeType4Enabled() then
								g_treePlantManager:plantTree(self.settings:getTreeType4(), coord.x, coord.y, coord.z, 0, 0, 0, treeStage, variation, isGrowing)
							elseif (i-1) % 2 == 0 and self.settings:isTreeType2Enabled() then
								g_treePlantManager:plantTree(self.settings:getTreeType2(), coord.x, coord.y, coord.z, 0, 0, 0, treeStage, variation, isGrowing)
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

function ConstructionBrushParallelLines:onAxisPrimary(inputValue)
	self:setBrushSize(self.cursorSizeIndex + inputValue)
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
	return "$l10n_input_CONSTRUCTION_BRUSH_SIZE"
end

function ConstructionBrushParallelLines:getButtonSecondaryText()
	return "Export keyline"
end

function ConstructionBrushParallelLines:getButtonTertiaryText()
	return "Import parallel lines"
end

function ConstructionBrushParallelLines:onOpenSettingsDialog()
	printf("Keyline Design: Opening settings dialog")
	ParallelLineSettingsDialog.getInstance():show()
end

-- Allow opening the settings menu, but in a non-standard way which shows a dialog instead
ConstructionScreen.registerBrushActionEvents = Utils.appendedFunction(ConstructionScreen.registerBrushActionEvents, function(constructionScreen)
	-- Make sure we are extending the right brush
	if constructionScreen.brush and constructionScreen.brush.keylines ~= nil and constructionScreen.brush.importedParallelLines ~= nil then
		printf("Keyline Design: Injecting button for settings dialog")
		local isValid
		isValid, constructionScreen.showConfigsEvent = g_inputBinding:registerActionEvent(InputAction.CONSTRUCTION_SHOW_CONFIGS, constructionScreen.brush, constructionScreen.brush.onOpenSettingsDialog, false, true, false, true)
		printf("Keyline Design: event ID = %s, isValid = %s", constructionScreen.showConfigsEvent, isValid)
		g_inputBinding:setActionEventText(constructionScreen.showConfigsEvent, g_i18n:getText("input_CONSTRUCTION_SHOW_CONFIGS"))
		g_inputBinding:setActionEventTextPriority(constructionScreen.showConfigsEvent, GS_PRIO_HIGH)
		table.insert(constructionScreen.brushEvents, constructionScreen.showConfigsEvent)
	end
end)