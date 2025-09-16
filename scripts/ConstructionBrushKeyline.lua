-- Local values: ConstructionBrushKeyline_mt
ConstructionBrushKeyline = {}
local ConstructionBrushKeyline_mt = Class(ConstructionBrushKeyline, ConstructionBrush)
ConstructionBrushKeyline.CURSOR_SIZES = {
	0.5,
	1,
	2,
	4,
	8,
	16
}

function ConstructionBrushKeyline.new(subclass_mt, cursor)
	local self = ConstructionBrushKeyline:superClass().new(subclass_mt or ConstructionBrushKeyline_mt, cursor)
	self.supportsPrimaryButton = true
	self.supportsPrimaryDragging = false
	self.requiredPermission = Farm.PERMISSION.LANDSCAPING
	self.supportsPrimaryAxis = true
	self.primaryAxisIsContinuous = false
	self.supportsSecondaryButton = false
	self.supportsTertiaryButton = false
	self.maxBrushRadius = ConstructionBrushKeyline.CURSOR_SIZES[#ConstructionBrushKeyline.CURSOR_SIZES] / 2
	self.freeMode = false
	return self
end

function ConstructionBrushKeyline:delete()
	ConstructionBrushKeyline:superClass().delete(self)
end

function ConstructionBrushKeyline:activate()
	ConstructionBrushKeyline:superClass().activate(self)
	self.brushShape = Landscaping.BRUSH_SHAPE.CIRCLE
	self.cursor:setRotationEnabled(false)
	self.cursor:setShape(GuiTopDownCursor.SHAPES.CIRCLE)
	self.cursor:setColorMode(GuiTopDownCursor.SHAPES_COLORS.PAINTING)
	self.cursor:setTerrainOnly(true)
	self:setBrushSize(1)
	g_messageCenter:subscribe(LandscapingSculptEvent, self.onSculptingFinished, self)
end

function ConstructionBrushKeyline:deactivate()
	self.cursor:setTerrainOnly(false)
	g_messageCenter:unsubscribeAll(self)
	ConstructionBrushKeyline:superClass().deactivate(self)
end

function ConstructionBrushKeyline:copyState(from)
	self:setBrushSize(from.cursorSizeIndex)
	self.brushShape = from.brushShape
	if self.brushShape == Landscaping.BRUSH_SHAPE.CIRCLE then
		self.cursor:setShape(GuiTopDownCursor.SHAPES.CIRCLE)
	else
		self.cursor:setShape(GuiTopDownCursor.SHAPES.SQUARE)
	end
	self.freeMode = Utils.getNoNil(from.freeMode, self.freeMode)
end

function ConstructionBrushKeyline:setGroundType(groundTypeName)
	if not self.isActive then
		self.terrainLayer = g_groundTypeManager:getTerrainLayerByType(groundTypeName)
	end
end

function ConstructionBrushKeyline:setParameters(groundTypeName)
	self:setGroundType(groundTypeName)
end

function ConstructionBrushKeyline:setBrushSize(index)
	local sizes = #ConstructionBrushKeyline.CURSOR_SIZES
	self.cursorSizeIndex = math.clamp(index, 1, sizes)
	local size = ConstructionBrushKeyline.CURSOR_SIZES[self.cursorSizeIndex]
	self.brushRadius = size / 2
	self.cursor:setShapeSize(size)
end

function ConstructionBrushKeyline:toggleBrushShape()
	if self.brushShape == Landscaping.BRUSH_SHAPE.CIRCLE then
		self.brushShape = Landscaping.BRUSH_SHAPE.SQUARE
		self.cursor:setShape(GuiTopDownCursor.SHAPES.SQUARE)
	else
		self.brushShape = Landscaping.BRUSH_SHAPE.CIRCLE
		self.cursor:setShape(GuiTopDownCursor.SHAPES.CIRCLE)
	end
end

function ConstructionBrushKeyline:update(dt)
	ConstructionBrushKeyline:superClass().update(self, dt)
	local x, y, z = self.cursor:getHitTerrainPosition()
	self.coords = {}
	-- Most of these will have to be configuration options at some point
	local numLinesLeftOfKeyline = 2
	local numLinesRightOfKeyline = 2
	local pointDistance = 1
	local pointAmount = 200
	local parallelDistance = 18
	local initialXDir = 1
	local initialZDir = 0
	if x ~= nil then
		-- Get the central keyline first
		local keylineCoords = KeylineCalculation.getSingleKeylineCoords(x, y, z, initialXDir, initialZDir, pointDistance, pointAmount)
		table.insert(self.coords, keylineCoords)

		Utils.renderTextAtWorldPosition(x, y + .2, z, "0", getCorrectTextSize(.02), 0, 0, 0, 1, 1)
	end
end

function ConstructionBrushKeyline:onSculptingFinished(isValidation, errorCode, displacedVolumeOrArea) end

function ConstructionBrushKeyline:onButtonPrimary(isDown, isDrag, isUp)
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

function ConstructionBrushKeyline:onAxisPrimary(inputValue)
	self:setBrushSize(self.cursorSizeIndex + inputValue)
end

function ConstructionBrushKeyline:onButtonSecondary()
end

function ConstructionBrushKeyline:onButtonTertiary()
	self.freeMode = not self.freeMode
	self:setInputTextDirty()
	if self.freeMode and not g_gameSettings:getValue(GameSettings.SETTING.SHOWN_FREEMODE_WARNING) then
		InfoDialog.show(g_i18n:getText("ui_constructionFreeModeWarning"))
		g_gameSettings:setValue(GameSettings.SETTING.SHOWN_FREEMODE_WARNING, true)
	end
end

function ConstructionBrushKeyline:getButtonPrimaryText()
	return "$l10n_input_CONSTRUCTION_PAINT"
end

function ConstructionBrushKeyline:getAxisPrimaryText()
	return "$l10n_input_CONSTRUCTION_BRUSH_SIZE"
end

function ConstructionBrushKeyline:getButtonSecondaryText()
	return "$l10n_input_CONSTRUCTION_BRUSH_SHAPE"
end

function ConstructionBrushKeyline:getButtonTertiaryText()
	return string.format(g_i18n:getText("input_CONSTRUCTION_FREEMODE"), g_i18n:getText(self.freeMode and "ui_on" or "ui_off"))
end
