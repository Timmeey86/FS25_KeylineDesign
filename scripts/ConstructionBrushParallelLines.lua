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
	self.coords = {}
	self.keylines = {}
	self.exportedKeylines = {}
	self.settings = ConstructionBrushParallelLinesSettings.getInstance()
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
	for i = 1, #self.coords do
		local curve = self.coords[i]
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
			DebugUtil.drawDebugLine(x1, y1 + 0.3, z1, x2, y2 + 0.3, z2, color[1], color[2], color[3], 0.05)

			--Utils.renderTextAtWorldPosition(x1, y1 + .4, z1 , string.format("%d", i-1), getCorrectTextSize(0.02), 0,color[1], color[2], color[3], 1)

		end
	end

end

function ConstructionBrushParallelLines:updateKeyline()
	local x, y, z = self.cursor:getHitTerrainPosition()
	self.keylines = {}
	if x ~= nil then
		local pointDistance = self.settings.resolution
		local pointAmount = self.settings.length
		local initialXDir, initialZDir = MathUtil.getDirectionFromYRotation(self.angle * math.pi / 180)

		-- Get the central keyline first
		local keylineCoords = KeylineCalculation.getSingleKeylineCoords(x, y, z, initialXDir, initialZDir, pointDistance, pointAmount)
		--keylineCoords = ParallelCurveCalculation.getEquidistantPoints(keylineCoords, self.settings.resolution)
		table.insert(self.keylines, keylineCoords)
		-- Get the same line in reverse direction
		local inverseKeylineCoords = KeylineCalculation.getSingleKeylineCoords(x, y, z, -initialXDir, -initialZDir, pointDistance, pointAmount)
		--inverseKeylineCoords = ParallelCurveCalculation.getEquidistantPoints(inverseKeylineCoords, self.settings.resolution)
		table.insert(self.keylines, inverseKeylineCoords)
	else
		self.coords = {}
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
				for i = 1, #coordList do
					local coord = coordList[i]
					if math.abs(coord.x) >= g_currentMission.terrainSize/2 or math.abs(coord.z) >= g_currentMission.terrainSize/2 then
						break -- Skip any points which are out of bounds
					else
						local err = self:verifyAccess(coord.x, coord.y, coord.z)
						if err == nil or self.freeMode and err == ConstructionBrush.ERROR.PLACEMENT_BLOCKED then
							self:setActiveSound(ConstructionSound.ID.PAINT, 1 - self.brushRadius / self.maxBrushRadius)

							-- paint the ground
							local requestLandscaping = LandscapingSculptEvent.new(false, Landscaping.OPERATION.PAINT, coord.x, coord.y, coord.z, nil, nil, nil, nil, nil, nil, self.brushRadius, 1, self.brushShape, 1, self.terrainLayer)
							g_client:getServerConnection():sendEvent(requestLandscaping)

							-- TODO: Event queue
							-- plant grass if desired
							if self.settings:isGrassEnabled() then
								local event = LandscapingSculptEvent.new(false, Landscaping.OPERATION.FOLIAGE, coord.x, coord.y, coord.z, nil, nil, nil, nil, nil, nil, self.brushRadius, 1, self.brushShape, 0, nil, g_currentMission.foliageSystem:getFoliagePaintByName("meadow").id, self.settings:getGrassType())
								g_client:getServerConnection():sendEvent(event)
							end

							-- plant evenly spaced trees
							if (i-1) % 16 == 0 and self.settings:isTreeType16Enabled() then
								-- TODO random orientation. Maybe also random variation
								g_treePlantManager:plantTree(self.settings:getTreeType16(), coord.x, coord.y, coord.z, 0, 0, 0, 1, 1, true)
							elseif (i-1) % 8 == 0 and self.settings:isTreeType8Enabled() then
								g_treePlantManager:plantTree(self.settings:getTreeType8(), coord.x, coord.y, coord.z, 0, 0, 0, 1, 1, true)
							elseif (i-1) % 4 == 0 and self.settings:isTreeType4Enabled() then
								g_treePlantManager:plantTree(self.settings:getTreeType4(), coord.x, coord.y, coord.z, 0, 0, 0, 1, 1, true)
							elseif (i-1) % 2 == 0 and self.settings:isTreeType2Enabled() then
								g_treePlantManager:plantTree(self.settings:getTreeType2(), coord.x, coord.y, coord.z, 0, 0, 0, 1, 1, true)
							elseif self.settings:isTreeType1Enabled() then
								g_treePlantManager:plantTree(self.settings:getTreeType1(), coord.x, coord.y, coord.z, 0, 0, 0, 1, 1, true)
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
	self:exportKeylines()
end

function ConstructionBrushParallelLines:onButtonTertiary()
	self:importParallelLines()
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
	if constructionScreen.brush and constructionScreen.brush.keylines ~= nil and constructionScreen.brush.coords ~= nil then
		printf("Keyline Design: Injecting button for settings dialog")
		local isValid
		isValid, constructionScreen.showConfigsEvent = g_inputBinding:registerActionEvent(InputAction.CONSTRUCTION_SHOW_CONFIGS, constructionScreen.brush, constructionScreen.brush.onOpenSettingsDialog, false, true, false, true)
		printf("Keyline Design: event ID = %s, isValid = %s", constructionScreen.showConfigsEvent, isValid)
		g_inputBinding:setActionEventText(constructionScreen.showConfigsEvent, g_i18n:getText("input_CONSTRUCTION_SHOW_CONFIGS"))
		g_inputBinding:setActionEventTextPriority(constructionScreen.showConfigsEvent, GS_PRIO_HIGH)
		table.insert(constructionScreen.brushEvents, constructionScreen.showConfigsEvent)
	end
end)

g_xmlManager:addCreateSchemaFunction(function()
	ConstructionBrushParallelLines.exportSchema = XMLSchema.new("keylines")
	ConstructionBrushParallelLines.importSchema = XMLSchema.new("parallelLines")
end)
g_xmlManager:addInitSchemaFunction(function()
	ConstructionBrushParallelLines.exportSchema:register(XMLValueType.FLOAT, "keylines.keyline(?).coords(?)#x", "X coordinate", nil, true)
	ConstructionBrushParallelLines.exportSchema:register(XMLValueType.FLOAT, "keylines.keyline(?).coords(?)#z", "Z coordinate", nil, true)

	ConstructionBrushParallelLines.importSchema:register(XMLValueType.FLOAT, "parallelLines.parallelLine(?).coords(?)#x", "X coordinate", nil, true)
	ConstructionBrushParallelLines.importSchema:register(XMLValueType.FLOAT, "parallelLines.parallelLine(?).coords(?)#z", "Z coordinate", nil, true)
end)
function ConstructionBrushParallelLines:exportKeylines()
	-- Combine both keyline directions into a single unidirectional line
	-- We skip the initial point on the second line since it's already in the first line
	local combinedKeyline = {}
	for i = #self.keylines[2], 2, -1 do
		table.insert(combinedKeyline, self.keylines[2][i])
	end
	for i = 1, #self.keylines[1] do
		table.insert(combinedKeyline, self.keylines[1][i])
	end

	-- Write keyline coordinates to an XML file
	local filePath = Utils.getFilename("/keylines.xml", g_currentMission.missionInfo.savegameDirectory)
	local xmlFile = XMLFile.create("keylinesXML", filePath, "keylines", ConstructionBrushParallelLines.exportSchema)
	if not xmlFile then
		Logging.error("Failed exporting keylines to XML")
		return
	end
	local xmlKey = ("keylines.keyline(0)")

	for j = 1, #combinedKeyline do
		local coordKey = xmlKey .. (".coords(%d)"):format(j - 1)
		xmlFile:setFloat(coordKey .. "#x", combinedKeyline[j].x)
		xmlFile:setFloat(coordKey .. "#z", combinedKeyline[j].z)
	end
	xmlFile:save(true)
	xmlFile:delete()

	-- Remember the keylines so the mouse can keep displaying keylines at the mouse position
	self.exportedKeylines = {}
	table.insert(self.exportedKeylines, combinedKeyline)
end

function ConstructionBrushParallelLines:importParallelLines()
	-- Read parallel line coordinates from an XML file
	local filePath = Utils.getFilename("/parallel_lines.xml", g_currentMission.missionInfo.savegameDirectory)
	local xmlFile = XMLFile.load("parallelLinesXML", filePath, ConstructionBrushParallelLines.importSchema)
	if not xmlFile then
		Logging.error("Failed importing parallel lines from XML")
		return
	end

	-- Add the keylines to the list of all coordinates first
	self.coords = {}
	local allCurves = {}
	table.insert(allCurves, self.exportedKeylines[1])
	table.insert(allCurves, self.exportedKeylines[2])

	-- Now read parallel lines from the XML
	xmlFile:iterate("parallelLines.parallelLine", function(_, parallelLineKey)
		local curve = {}
		xmlFile:iterate(parallelLineKey .. ".coords", function(_, coordKey)
			local x = xmlFile:getFloat(coordKey .. "#x")
			local z = xmlFile:getFloat(coordKey .. "#z")
			if x ~= nil and z ~= nil then
				table.insert(curve, {x = x, z = z})
			end
		end)
		printf("Imported %d points for parallel line %s from the XML file", #curve, parallelLineKey)
		if #curve > 0 then
			table.insert(allCurves, curve)
		end
	end)
	xmlFile:delete()

	-- Remove any points which are not on the same farmland as the keyline
	local currentFarmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(self.keylines[1][1].x, self.keylines[1][1].z)
	for _, curve in ipairs(allCurves) do
		for i = #curve, 1, -1 do
			local coord = curve[i]
			local farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(coord.x, coord.z)
			if farmlandId ~= currentFarmlandId then
				table.remove(curve, i)
			end
		end
	end

	-- Now calculate all the required Y values (except for keylines, those have the Y values already)
	for i = 1, #allCurves do
		local curve = allCurves[i]
		for j = 1, #curve do
			local coord = curve[j]
			local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, coord.x, 0, coord.z)
			coord.y = y
		end
	end

	-- Store all combined curves
	self.coords = allCurves
	-- Clear the exported keylines since they're already in self.coords
	self.exportedKeylines = {}
end