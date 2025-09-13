-- Local values: ConstructionBrushParallelLines_mt
ConstructionBrushParallelLines = {}
local ConstructionBrushParallelLines_mt = Class(ConstructionBrushParallelLines, ConstructionBrush)
ConstructionBrushParallelLines.CURSOR_SIZES = {
	0.5,
	1,
	2,
	4,
	8,
	16
}

function ConstructionBrushParallelLines.new(subclass_mt, cursor)
	local self = ConstructionBrushParallelLines:superClass().new(subclass_mt or ConstructionBrushParallelLines_mt, cursor)
	self.supportsPrimaryButton = true
	self.supportsPrimaryDragging = false
	self.requiredPermission = Farm.PERMISSION.LANDSCAPING
	self.supportsPrimaryAxis = true
	self.primaryAxisIsContinuous = false
	self.supportsSecondaryButton = false
	self.supportsTertiaryButton = false
	self.maxBrushRadius = ConstructionBrushParallelLines.CURSOR_SIZES[#ConstructionBrushParallelLines.CURSOR_SIZES] / 2
	self.freeMode = false
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
	local x, y, z = self.cursor:getHitTerrainPosition()
	self.coords = {}
	-- Most of these will have to be configuration options at some point
	local numLinesLeftOfKeyline = 2
	local numLinesRightOfKeyline = 2
	local pointDistance = 1
	local pointAmount = 500
	local parallelDistance = 18
	local initialXDir = 1
	local initialZDir = 0
	if x ~= nil then
		-- Get the central keyline first
		local keylineCoords, mainXDir, mainZDir = KeylineCalculation.getSingleKeylineCoords(x, y, z, initialXDir, initialZDir, pointDistance, pointAmount)
		table.insert(self.coords, keylineCoords)

		Utils.renderTextAtWorldPosition(x, y + .2, z, "0", getCorrectTextSize(.02), 0, 0, 0, 1, 1)

		-- Get lines to the left of the main direction
		for i = 1, numLinesLeftOfKeyline do
			local lineDist = i * -parallelDistance
			local parallelCoords = KeylineCalculation.getParallelLine(keylineCoords, mainXDir, mainZDir, lineDist)
			table.insert(self.coords, parallelCoords)
			if #parallelCoords > 0 then
				local x2, y2, z2 = parallelCoords[1].x, parallelCoords[1].y, parallelCoords[1].z
				Utils.renderTextAtWorldPosition(x2, y2 + .2, z2, string.format("%d", i), getCorrectTextSize(.02), 0, 0, 0, 1, 1)
			end
		end

		-- Get lines right of the main direction
		for i = 1, numLinesRightOfKeyline do
			local lineDist = i * parallelDistance
			local parallelCoords = KeylineCalculation.getParallelLine(keylineCoords, mainXDir, mainZDir, lineDist)
			table.insert(self.coords, parallelCoords)
			if #parallelCoords > 0 then
				local x2, y2, z2 = parallelCoords[1].x, parallelCoords[1].y, parallelCoords[1].z
				Utils.renderTextAtWorldPosition(x2, y2 + .2, z2, string.format("%d", i), getCorrectTextSize(.02), 0, 0, 0, 1, 1)
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
		if #self.coords > 0 then
			for _, coordList in ipairs(self.coords) do
				for _, coord in ipairs(coordList) do
					if coord.x <= 0 or coord.x >= g_currentMission.terrainSize or coord.z <= 0 or coord.z >= g_currentMission.terrainSize then
						break -- Skip any points which are out of bounds
					else
						local err = self:verifyAccess(coord.x, coord.y, coord.z)
						if err == nil or self.freeMode and err == ConstructionBrush.ERROR.PLACEMENT_BLOCKED then
							self:setActiveSound(ConstructionSound.ID.PAINT, 1 - self.brushRadius / self.maxBrushRadius)
							local requestLandscaping = LandscapingSculptEvent.new(false, Landscaping.OPERATION.PAINT, coord.x, coord.y, coord.z, nil, nil, nil, nil, nil, nil, self.brushRadius, 1, self.brushShape, 1, self.terrainLayer)
							g_client:getServerConnection():sendEvent(requestLandscaping)
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
	return "$l10n_input_CONSTRUCTION_BRUSH_SHAPE"
end

function ConstructionBrushParallelLines:getButtonTertiaryText()
	return string.format(g_i18n:getText("input_CONSTRUCTION_FREEMODE"), g_i18n:getText(self.freeMode and "ui_on" or "ui_off"))
end
