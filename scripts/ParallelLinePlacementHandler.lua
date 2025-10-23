--- This class is responsible for placing parallel lines in a way which doesn't break the server.
ParallelLinePlacementHandler = {}
ParallelLinePlacementHandler_mt = Class(ParallelLinePlacementHandler)

function ParallelLinePlacementHandler.new()
	local self = setmetatable({}, ParallelLinePlacementHandler_mt)
	self.placementEventQueue = {}
	self.pendingPaintEvents = {}
	self.pendingFoliageEvents = {}
	self.pendingBushEvents = {}
	self.currentConnection = nil
	self.delay = 100
	return self
end

ParallelLinePlacementHandler.INSTANCE = ParallelLinePlacementHandler.new()

---Enqueues a placement event on the server / single player client
function ParallelLinePlacementHandler.addPlacementEvent(event)
	table.insert(ParallelLinePlacementHandler.INSTANCE.placementEventQueue, event)
end

function ParallelLinePlacementHandler:update(dt)
	local maxFrameBudget = 0.001 -- 1ms per frame
	local startTime = getTimeSec()
	-- paint the ground first
	if #self.pendingPaintEvents > 0 then
		printf("Processing up to %d pending paint events", #self.pendingPaintEvents)
		if self.currentConnection then
			printf("Using connection of client %d", g_currentMission.userManager:getUserIdByConnection(self.currentConnection))
		else
			printf("No client connection, using server connection")
		end
		while getTimeSec() - startTime < maxFrameBudget and #self.pendingPaintEvents > 0 do
			local event = table.remove(self.pendingPaintEvents, 1)
			if self.currentConnection then
				event:run(self.currentConnection)
			else
				-- This executes the event on the server
				g_client:getServerConnection():sendEvent(event)
			end
		end -- keep processing events until frame budget was hit
		printf("%d events remaining", #self.pendingPaintEvents)
	-- process pending grass events next
	elseif #self.pendingFoliageEvents > 0 then
		if self.delay <= 0 then
			printf("Processing up to %d pending foliage events", #self.pendingFoliageEvents)
			while getTimeSec() - startTime < maxFrameBudget and #self.pendingFoliageEvents > 0 do
				local event = table.remove(self.pendingFoliageEvents, 1)
				if self.currentConnection then
					event:run(self.currentConnection)
				else
					-- This executes the event on the server
					g_client:getServerConnection():sendEvent(event)
				end
			end -- keep processing events until frame budget was hit
			printf("%d events remaining", #self.pendingFoliageEvents)
			if #self.pendingFoliageEvents == 0 then
				-- Restore the delay for the next cycle
				self.delay = 100
			end
		else
			-- If we paint foliage too early, it seems to be executed before painting the ground, which will prevent the foliage from appearing in the first place
			self.delay = self.delay - dt
		end
	-- process bush events next
	elseif #self.pendingBushEvents > 0 then
		if self.delay <= 0 then
			printf("Processing up to %d pending bush events", #self.pendingBushEvents)
			while getTimeSec() - startTime < maxFrameBudget and #self.pendingBushEvents > 0 do
				local event = table.remove(self.pendingBushEvents, 1)
				if self.currentConnection then
					event:run(self.currentConnection)
				else
					-- This executes the event on the server
					g_client:getServerConnection():sendEvent(event)
				end
			end -- keep processing events until frame budget was hit
			printf("%d events remaining", #self.pendingBushEvents)
			if #self.pendingBushEvents == 0 then
				-- Restore the delay for the next cycle
				self.delay = 100
			end
		else
			-- If we paint foliage too early, it seems to be executed before painting the ground, which will prevent the foliage from appearing in the first place
			self.delay = self.delay - dt
		end
	-- only now start placing completely new fields
	elseif #self.placementEventQueue > 0 then
		local nextEvent = table.remove(self.placementEventQueue, 1)
		self.currentConnection = nextEvent.connection -- will be nil in single player / locally hosted multiplayer server
		self:processPlacementEvent(nextEvent)
	end
end

function ParallelLinePlacementHandler:processPlacementEvent(event)
	if event.importedParallelLines == nil or event.importedParallelLines == 0 then
		return
	end

	local first = true
	for _, coordList in ipairs(event.importedParallelLines) do
		for _, coord in ipairs(coordList) do
			if first then
				printf("Grass enabled: %s, Bush enabled: %s", tostring(event.settings:isGrassEnabled()), tostring(event.settings:isBushEnabled()))
				first = false
			end
			-- Note: We are enqueueing events based on coords, but all paint events will be processed before the first grass event is processed and so on
			-- paint the ground
			local requestLandscaping = LandscapingSculptEvent.new(false, Landscaping.OPERATION.PAINT, coord.x, coord.y, coord.z, nil, nil, nil, nil, nil, nil, event.settings.keylineWidth / 2.0, 1, Landscaping.BRUSH_SHAPE.CIRCLE, 1, event.terrainLayer)
			table.insert(self.pendingPaintEvents, requestLandscaping)

			-- plant grass if desired
			if event.settings:isGrassEnabled() then
				self:enqueueFoliagePaintEvent(self.pendingFoliageEvents, coord, event.settings.grassBrushParameters, event.settings.keylineWidth)
			end
			if event.settings:isBushEnabled() then
				local width = event.settings.bushWidth
				self:enqueueFoliagePaintEvent(self.pendingBushEvents, coord, event.settings.bushBrushParameters, width)
			end
		end
	end
	-- Plant all trees
	-- Initialize the random number generator with the same seed as the client in order to get the identical values
	-- Currently we plant this at once. If that doesn't work, we'll have to enqueue this as well
	math.randomseed(event.randomseed)
	for _, coords in ipairs(event.importedParallelLines) do
		local treeLoadingData = ParallelLinePlacementHandler.calculateTreeLoadingData(coords, event.settings)
		for _, data in ipairs(treeLoadingData) do
			g_treePlantManager:plantTree(data.treeType.index, data.x, data.y, data.z, 0, data.rotation, 0, data.treeStageIndex, data.variationIndex, data.isGrowing)
		end
	end
end

function ParallelLinePlacementHandler:enqueueFoliagePaintEvent(eventTable, coord, params, width)
	local radius = width * 0.5
	if params then
		local foliagePaint = g_currentMission.foliageSystem:getFoliagePaint(params.foliageId)
		local foliageValue = params.value
		if foliagePaint and foliageValue then
			local event = LandscapingSculptEvent.new(false, Landscaping.OPERATION.FOLIAGE, coord.x, coord.y, coord.z, nil, nil, nil, nil, nil, nil, radius, 1, Landscaping.BRUSH_SHAPE.CIRCLE, 0, nil, foliagePaint.id, tonumber(foliageValue))
			table.insert(eventTable, event)
		end
	end
end

function ParallelLinePlacementHandler.calculateTreeLoadingData(coordList, settings)
	local treeLoadingData = {}
	for i = 1, #coordList do
		local coord = coordList[i]
		-- create previews for evenly spaced trees
		local treeTypeIndex = nil
		if (i-1) % 32 == 0 and settings:isTreeType32Enabled() then
			treeTypeIndex = settings:getTreeType32()
		elseif (i-1) % 16 == 0 and settings:isTreeType16Enabled() then
			treeTypeIndex = settings:getTreeType16()
		elseif (i-1) % 8 == 0 and settings:isTreeType8Enabled() then
			treeTypeIndex = settings:getTreeType8()
		elseif (i-1) % 4 == 0 and settings:isTreeType4Enabled() then
			treeTypeIndex = settings:getTreeType4()
		elseif (i-1) % 2 == 0 and settings:isTreeType2Enabled() then
			treeTypeIndex = settings:getTreeType2()
		end

		if treeTypeIndex ~= nil then
			local treeType = g_treePlantManager:getTreeTypeDescFromIndex(treeTypeIndex)
			if not treeType then
				Logging.error("Could not find tree type with index %s", treeTypeIndex)
				continue
			end
			local maxTreeStage = math.min(#treeType.stages, settings.treeMaxGrowthStage)
			local minTreeStage = math.min(#treeType.stages, settings.treeMinGrowthStage)
			local treeStageIndex = math.random(minTreeStage, maxTreeStage)
			local treeStage = treeType.stages[treeStageIndex]

			-- Get a random variation in case the tree has more than one variation
			-- Note that there is a case where the tree is sapling-only, and the treeType.stages table does not
			-- contain stages, but rather planter configuration data, which is why we check for at least two stages
			local maxVariation = #treeStage > 2 and #treeStage or 1
			local variationIndex = math.random(1, maxVariation)

			-- random rotation to make it look more natural
			local rotation = math.random() * 2 * math.pi

			local isGrowing = settings.treeGrowthBehavior == ParallelLineSettingsDialogTree.TREE_GROWTH_BEHAVIOR.GROWING

			table.insert(treeLoadingData, {treeType = treeType, treeStageIndex = treeStageIndex, variationIndex = variationIndex, rotation = rotation, x = coord.x, y = coord.y, z = coord.z, isGrowing = isGrowing})
		end
	end
	return treeLoadingData
end

addModEventListener(ParallelLinePlacementHandler.INSTANCE)