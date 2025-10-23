---This class is responsible for forwarding parallel line placement events to the server

ParallelLinePlacementEvent = {}
ParallelLinePlacementEvent_mt = Class(ParallelLinePlacementEvent, Event)
InitEventClass(ParallelLinePlacementEvent, "ParallelLinePlacementEvent")

function ParallelLinePlacementEvent.emptyNew()
	return Event.new(ParallelLinePlacementEvent_mt)
end

function ParallelLinePlacementEvent.new(importedParallelLines, settings, terrainLayer, randomseed)
	local self = ParallelLinePlacementEvent.emptyNew()
	self.importedParallelLines = importedParallelLines
	self.settings = settings
	self.terrainLayer = terrainLayer
	self.randomseed = randomseed
	return self
end

---Reads event data which was sent from the client
---@param streamId number The ID of the network stream
---@param connection table The connection to the event sender
function ParallelLinePlacementEvent:readStream(streamId, connection)
	local weAreTheServer = not connection:getIsServer()
	if weAreTheServer then
		-- Read settings first (fixed size)
		self.settings = ConstructionBrushParallelLinesSettings.new()
		self.settings:receiveDataFromClient(streamId)
		self.terrainLayer = streamReadUInt8(streamId)
		self.randomseed = streamReadUInt32(streamId)
		-- Now read parallel lines
		local numLines = streamReadUInt8(streamId)
		self.importedParallelLines = {}
		for i = 1, numLines do
			local numCoords = streamReadUInt16(streamId)
			local line = {}
			for j = 1, numCoords do
				local x = streamReadFloat32(streamId)
				local y = streamReadFloat32(streamId)
				local z = streamReadFloat32(streamId)
				table.insert(line, {x = x, y = y, z = z})
			end
			table.insert(self.importedParallelLines, line)
		end
		self.connection = connection -- remember the client connection so the correct user ID is being retrieved later on
		printf("Read %d imported parallel lines from stream", #self.importedParallelLines)
		ParallelLinePlacementHandler.addPlacementEvent(self)
	else
		printf("Ignoring ParallelLinePlacementEvent since we are not the server")
	end
end

---Writes event data to be sent to the server
---@param streamId number The ID of the network stream
---@param connection table The connection to the event receiver
function ParallelLinePlacementEvent:writeStream(streamId, connection)
	local weAreAClient = connection:getIsServer()
	if weAreAClient then
		-- Write settings first (fixed size)
		self.settings:sendDataToServer(streamId)
		streamWriteUInt8(streamId, self.terrainLayer)
		streamWriteUInt32(streamId, self.randomseed)
		-- Now write parallel lines
		streamWriteUInt8(streamId, #self.importedParallelLines)
		for i = 1, #self.importedParallelLines do
			local line = self.importedParallelLines[i]
			streamWriteUInt16(streamId, #line)
			for j = 1, #line do
				streamWriteFloat32(streamId, line[j].x)
				streamWriteFloat32(streamId, line[j].y)
				streamWriteFloat32(streamId, line[j].z)
			end
		end
		printf("Wrote %d imported parallel lines to stream", #self.importedParallelLines)
	else
		printf("Ignoring ParallelLinePlacementEvent since we are not connected to a server")
	end
end