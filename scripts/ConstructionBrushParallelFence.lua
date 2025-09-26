---This class allows placing several parallel fences (grapes/olives etc) at once
---@class ConstructionBrushParallelFence
---@field fence PlaceableFence @the fence instance (contains all the grape vines of the player's farm, one segment for each line)

ConstructionBrushParallelFence = {}
local ConstructionBrushParallelFence_mt = Class(ConstructionBrushParallelFence, ConstructionBrush)

function ConstructionBrushParallelFence.new(subclass_mt, cursor)
	local self = ConstructionBrushParallelFence:superClass().new(subclass_mt or ConstructionBrushParallelFence_mt, cursor)
	self.supportsPrimaryButton = true
	self.supportsSecondaryButton = true
	self.supportsTertiaryButton = true
	self.brushIdentifier = "fence"
	self.supportsSnapping = false
	self.supportsPrimaryAxis = true
	self.supportsSecondaryAxis = true
	self.angle = 0
	self.keylines = {}
	self.importedParallelLines = {}
	self.exportedKeylines = {}
	self.settings = ConstructionBrushVinesSettings.getInstance()
	self.fence = {}
	self.pendingSegments = {}
	return self
end

function ConstructionBrushParallelFence:setParameters(filename, isGate, gateIndex)
	self.xmlFilename = filename
	printf("Setting XML filename %s", filename)
	-- No gate support
end

-- Called when the user clicks on a matching brush in the construction screen
function ConstructionBrushParallelFence:activate()
	ConstructionBrushParallelFence:superClass().activate(self)
	-- If the type of fence/vine has been placed already, use the same placeable, otherwise load a new one
	ConstructionBrushFence.acquirePlaceable(self)
	self.parallelSnappingEnabled = false
	-- at this point, either self.fence is set, or self.onPlaceableCreated will be called soon
	self.pendingSegments = {}
end
function ConstructionBrushParallelFence:deactivate()
	self:releasePlaceable()
	self.fence = nil
	self.doFindPlaceable = false
	g_messageCenter:unsubscribeAll(self)
	ConstructionBrushParallelFence:superClass().deactivate(self)
	self.pendingSegments = {}
end

function ConstructionBrushParallelFence:onPlaceableCreated(errorCode, ...)
	g_messageCenter:unsubscribe(BuyPlaceableEvent, self)
	if errorCode == BuyPlaceableEvent.STATE_FAILED_TO_LOAD then
		self.cursor:setErrorMessage("Failed loading placeable")
	else
		self.doFindPlaceable = true -- Find the fence in the next update
	end
end

function ConstructionBrushParallelFence:releasePlaceable()
	if self.fence ~= nil then
		if self.fence:getPreviewSegment() ~= nil then
			self.fence:setPreviewSegment(nil)
		end
		self.fence = nil
		self:setInputTextDirty()
	end
end

function ConstructionBrushParallelFence:updateKeyline()
	local x, y, z = self.cursor:getHitTerrainPosition()
	self.keylines = {}
	if x ~= nil then
		local straightLineCoords = KeylineCalculation.getStraightLineCoords(x, z, self.angle, self.settings.forwardLength, 1)
		table.insert(self.keylines, straightLineCoords)
		straightLineCoords = KeylineCalculation.getStraightLineCoords(x, z, self.angle, self.settings.reverseLength, -1)
		table.insert(self.keylines, straightLineCoords)
	else
		self.importedParallelLines = {}
	end
end

function ConstructionBrushParallelFence:findPlaceable()
	-- We can reuse the ConstructionBrushFence implementation for that since it only affects self.fence (and self.parallelSnappingEnabled)
	local fence = ConstructionBrushFence.findPlaceable(self)
	self.parallelSnappingEnabled = false -- we don't need that
	return fence
end

function ConstructionBrushParallelFence:update(dt)
	ConstructionBrushParallelFence:superClass().update(self, dt)

	if self.doFindPlaceable then
		-- The fence was created when clicking on the brush in the construction menu, we need to find it again
		self.fence = self:findPlaceable()
		self:setInputTextDirty()
		self.doFindPlaceable = false
		self.parallelSnappingEnabled = false
	end
	self:updateKeyline()

	KeylineCalculation.drawLines(self.keylines, self.exportedKeylines, self.importedParallelLines)
end

function ConstructionBrushParallelFence:onButtonPrimary()
	for _, segment in ipairs(self.pendingSegments) do
		local event = PlaceableFenceAddSegmentEvent.new(self.fence, segment.x1, segment.z1, segment.x2, segment.z2, true, true, nil, 0)
		g_client:getServerConnection():sendEvent(event)
	end
	if self.fence:getPreviewSegment() ~= nil then
		self.fence:setPreviewSegment(nil)
	end
end

function ConstructionBrushParallelFence:onButtonSecondary()
	self.exportedKeylines = {}
	self.importedParallelLines = {}
	table.insert(self.exportedKeylines, ExportImportInterface.exportKeylines(self.keylines, self.settings))
end

function ConstructionBrushParallelFence:onButtonTertiary()
	self.importedParallelLines = ExportImportInterface.importParallelLines()

	local first = true
	self.pendingSegments = {}
	for _, line in ipairs(self.importedParallelLines) do
		if #line < 2 then
			continue
		end
		local firstCoord = line[1]
		local lastCoord = line[#line]
		local segment = self.fence:createSegment(firstCoord.x, firstCoord.z, lastCoord.x, lastCoord.z, true, nil)
		if first then
			self.fence:setPreviewSegment(segment)
			first = false
		end
		table.insert(self.pendingSegments, segment)
	end
end

PlaceableVine.onLoad = Utils.prependedFunction(PlaceableVine.onLoad, function(vine, savegame)
	print("PlaceableVine:onLoad")
	printCallstack()
end)

function ConstructionBrushParallelFence:getButtonPrimaryText()
	return "Place orchards"
end

function ConstructionBrushParallelFence:getButtonSecondaryText()
	return "Export keyline"
end

function ConstructionBrushParallelFence:getAxisPrimary()
	return "Change angle (1°)"
end
function ConstructionBrushParallelFence:getAxisSecondaryText()
	return "Change angle (10°)"
end

function ConstructionBrushParallelFence:onAxisPrimary(delta)
	self.angle = (self.angle + delta) % 360
end

function ConstructionBrushParallelFence:onAxisSecondary(delta)
	self.angle = (self.angle + delta * 10) % 360
end

function ConstructionBrushParallelFence:getButtonTertiaryText()
	return "Import parallel lines"
end

function ConstructionBrushParallelFence:onOpenSettingsDialog()
	printf("Keyline Design: Opening settings dialog")
	ParallelLineSettingsDialogVines.getInstance():show()
end

-- Allow opening the settings menu, but in a non-standard way which shows a dialog instead
ConstructionScreen.registerBrushActionEvents = Utils.appendedFunction(ConstructionScreen.registerBrushActionEvents, function(constructionScreen)
	-- Make sure we are extending the right brush
	if constructionScreen.brush and constructionScreen.brush.brushIdentifier == "fence" then
		printf("Keyline Design: Injecting button for settings dialog")
		local isValid
		isValid, constructionScreen.showConfigsEvent = g_inputBinding:registerActionEvent(InputAction.CONSTRUCTION_SHOW_CONFIGS, constructionScreen.brush, constructionScreen.brush.onOpenSettingsDialog, false, true, false, true)
		printf("Keyline Design: event ID = %s, isValid = %s", constructionScreen.showConfigsEvent, isValid)
		g_inputBinding:setActionEventText(constructionScreen.showConfigsEvent, g_i18n:getText("input_CONSTRUCTION_SHOW_CONFIGS"))
		g_inputBinding:setActionEventTextPriority(constructionScreen.showConfigsEvent, GS_PRIO_HIGH)
		table.insert(constructionScreen.brushEvents, constructionScreen.showConfigsEvent)
	end
end)