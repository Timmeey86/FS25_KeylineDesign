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
	self.supportsTertiaryButton = false
	self.maxBrushRadius = ConstructionBrushParallelLines.CURSOR_SIZES[#ConstructionBrushParallelLines.CURSOR_SIZES] / 2
	self.freeMode = false
	self.angle = 0
	self.coords = {}
	self.keylines = {}
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
	for _, curve in ipairs(self.coords) do
		-- Other lines in blue (includes the original keyline where the player clicked)
		table.insert(lines, { coords = curve, color = {0, 1, 0} })
	end
	for j = 1, #lines do
		local curveData = lines[j]
		local color = curveData.color
		local curve = curveData.coords
		for i = 2, #curve do
			local x1, y1, z1 = curve[i - 1].x, curve[i - 1].y, curve[i - 1].z
			local x2, y2, z2 = curve[i].x,  curve[i].y, curve[i].z
			DebugUtil.drawDebugLine(x1, y1 + 0.3, z1, x2, y2 + 0.3, z2, color[1], color[2], color[3], .25)
		end
	end

end

function ConstructionBrushParallelLines:updateKeyline()
	local x, y, z = self.cursor:getHitTerrainPosition()
	self.keylines = {}
	if x ~= nil then
		local pointDistance = 1
		local pointAmount = 500
		local initialXDir, initialZDir = MathUtil.getDirectionFromYRotation(self.angle * math.pi / 180)

		-- Get the central keyline first
		local keylineCoords = KeylineCalculation.getSingleKeylineCoords(x, y, z, initialXDir, initialZDir, pointDistance, pointAmount)
		table.insert(self.keylines, keylineCoords)
		-- Get the same line in reverse direction
		local inverseKeylineCoords = KeylineCalculation.getSingleKeylineCoords(x, y, z, -initialXDir, -initialZDir, pointDistance, pointAmount)
		table.insert(self.keylines, inverseKeylineCoords)
	else
		self.coords = {}
	end
end

function ConstructionBrushParallelLines:calculateParallelCurves()
	self.coords = {}
	-- Most of these will have to be configuration options at some point
	local numLinesLeftOfKeyline = 7
	local numLinesRightOfKeyline = 7
	local parallelDistance = 18 + 6 -- 18m tramline + 6m inter-row spacing
	if #self.keylines > 0 then

		-- Get lines to the left of the main direction
		for direction = -1, 1, 2 do
			local baseCoords
			if direction == -1 then
				baseCoords = self.keylines[1]
				table.insert(self.coords, baseCoords) -- Also add the main keyline
			else
				baseCoords = self.keylines[2]
				table.insert(self.coords, baseCoords) -- Also add the reverse main keyline
			end
			for i = 1, numLinesLeftOfKeyline do
				local lineDist = i * -parallelDistance
				local parallelCurve = ParallelCurveCalculation.createOffsetCurve(baseCoords, lineDist)
				local cleanedCurve = ParallelCurveCalculation.removeLoops(parallelCurve)
				table.insert(self.coords, cleanedCurve)
			end

			-- Get lines right of the main direction
			for i = 1, numLinesRightOfKeyline do
				local lineDist = i * parallelDistance
				local parallelCurve = ParallelCurveCalculation.createOffsetCurve(baseCoords, lineDist)
				local cleanedCurve = ParallelCurveCalculation.removeLoops(parallelCurve)
				table.insert(self.coords, cleanedCurve)
			end
		end

		local mouseFarmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(self.keylines[1][1].x, self.keylines[1][1].z)
		for j = 1, #self.coords do
			-- Remove any points which are not on the same farmland
			local coords = self.coords[j]
			for i = #coords, 1, -1 do
				local coord = coords[i]
				local farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(coord.x, coord.z)
				if farmlandId ~= mouseFarmlandId then
					table.remove(coords, i)
				end
			end

			-- Add missing Y coordinates
			for i = 1, #coords do
				coords[i].y = getTerrainHeightAtWorldPos(g_terrainNode, coords[i].x, 0, coords[i].z)
			end
		end
	end
end
function ConstructionBrushParallelLines:onSculptingFinished(isValidation, errorCode, displacedVolumeOrArea) end

function ConstructionBrushParallelLines:onButtonPrimary(isDown, isDrag, isUp)
	self:setActiveSound(ConstructionSound.ID.NONE)
	if isUp then
		self.lastX = nil
		return
	else
		local treeSpacing = 10
		if #self.coords > 0 then
			for _, coordList in ipairs(self.coords) do
				-- Convert the list into a list of equidistant spacing (currently a fixed length of 1 meter)
				local spacedList = ParallelCurveCalculation.getEquidistantPoints(coordList, 1)
				for i = 1, #spacedList do
					local coord = spacedList[i]
					if math.abs(coord.x) >= g_currentMission.terrainSize/2 or math.abs(coord.z) >= g_currentMission.terrainSize/2 then
						break -- Skip any points which are out of bounds
					else
						local err = self:verifyAccess(coord.x, coord.y, coord.z)
						if err == nil or self.freeMode and err == ConstructionBrush.ERROR.PLACEMENT_BLOCKED then
							self:setActiveSound(ConstructionSound.ID.PAINT, 1 - self.brushRadius / self.maxBrushRadius)

							-- paint the ground
							local requestLandscaping = LandscapingSculptEvent.new(false, Landscaping.OPERATION.PAINT, coord.x, coord.y, coord.z, nil, nil, nil, nil, nil, nil, self.brushRadius, 1, self.brushShape, 1, self.terrainLayer)
							g_client:getServerConnection():sendEvent(requestLandscaping)
							
							-- plant evenly spaced trees
							if (i - 1) % treeSpacing == 0 then
								g_treePlantManager:plantTree(22, coord.x, coord.y, coord.z, 0, 0, 0, 3, 1, false)
							end
						else
							self.cursor:setErrorMessage(g_i18n:getText(ConstructionBrush.ERROR_MESSAGES[err]))
						end
					end
				end
			end
		end
	end
end

function ConstructionBrushParallelLines:onAxisPrimary(inputValue)
	self:setBrushSize(self.cursorSizeIndex + inputValue)
end

function ConstructionBrushParallelLines:onButtonSecondary()
	self:calculateParallelCurves()
end

function ConstructionBrushParallelLines:onButtonTertiary()
	self.freeMode = not self.freeMode
	self:setInputTextDirty()
	if self.freeMode and not g_gameSettings:getValue(GameSettings.SETTING.SHOWN_FREEMODE_WARNING) then
		InfoDialog.show(g_i18n:getText("ui_constructionFreeModeWarning"))
		g_gameSettings:setValue(GameSettings.SETTING.SHOWN_FREEMODE_WARNING, true)
	end
end

function ConstructionBrushParallelLines:getButtonPrimaryText()
	return "$l10n_input_CONSTRUCTION_PAINT"
end

function ConstructionBrushParallelLines:getAxisPrimaryText()
	return "$l10n_input_CONSTRUCTION_BRUSH_SIZE"
end

function ConstructionBrushParallelLines:getButtonSecondaryText()
	return "Calculate" -- TODO
end

function ConstructionBrushParallelLines:getButtonTertiaryText()
	return string.format(g_i18n:getText("input_CONSTRUCTION_FREEMODE"), g_i18n:getText(self.freeMode and "ui_on" or "ui_off"))
end
