---This class is responsible for exporting data to XML files and importing the result from XML files again
---A separate executable will process the exported XML files and generate new ones to be imported
---@class ExportImportInterface

ExportImportInterface = {}


g_xmlManager:addCreateSchemaFunction(function()
	ExportImportInterface.exportSchema = XMLSchema.new("keylines")
	ExportImportInterface.importSchema = XMLSchema.new("parallelLines")
end)
g_xmlManager:addInitSchemaFunction(function()
	ExportImportInterface.exportSchema:register(XMLValueType.FLOAT, "keylines.keyline(?).coords(?)#x", "X coordinate", nil, true)
	ExportImportInterface.exportSchema:register(XMLValueType.FLOAT, "keylines.keyline(?).coords(?)#z", "Z coordinate", nil, true)
	ExportImportInterface.exportSchema:register(XMLValueType.FLOAT, "keylines.fieldBoundary.coords(?)#z", "Z coordinate", nil, true)
	ExportImportInterface.exportSchema:register(XMLValueType.FLOAT, "keylines.fieldBoundary.coords(?)#z", "Z coordinate", nil, true)
	ExportImportInterface.exportSchema:register(XMLValueType.FLOAT, "keylines.settings#headlandWidth", "Headland Width", nil, true)
	ExportImportInterface.exportSchema:register(XMLValueType.FLOAT, "keylines.settings#stripWidth", "Strip Width", nil, true)
	ExportImportInterface.exportSchema:register(XMLValueType.FLOAT, "keylines.settings#keylineWidth", "Keyline Width", nil, true)
	ExportImportInterface.exportSchema:register(XMLValueType.INT, "keylines.settings#numLinesRight", "Number of Parallel Lines Right", nil, true)
	ExportImportInterface.exportSchema:register(XMLValueType.INT, "keylines.settings#numLinesLeft", "Number of Parallel Lines Left", nil, true)

	ExportImportInterface.importSchema:register(XMLValueType.FLOAT, "parallelLines.parallelLine(?).coords(?)#x", "X coordinate", nil, true)
	ExportImportInterface.importSchema:register(XMLValueType.FLOAT, "parallelLines.parallelLine(?).coords(?)#z", "Z coordinate", nil, true)
end)


XmlExporter = {}
local writerInstance = setmetatable({}, Class(XmlExporter))
writerInstance.combinedKeyline = nil

function XmlExporter:writeToXml(courseField, success)
	printf("Exporting keylines and field boundary to XML file")

	local filePath = Utils.getFilename("/keylines.xml", g_currentMission.missionInfo.savegameDirectory)
	local xmlFile = XMLFile.create("keylinesXML", filePath, "keylines", ExportImportInterface.exportSchema)
	if not xmlFile then
		Logging.error("Failed exporting keylines to XML")
		return
	end

	-- Write settings to XML
	xmlFile:setUInt("keylines.settings#numLinesRight", self.settings.numberOfParallelLinesRight)
	xmlFile:setUInt("keylines.settings#numLinesLeft", self.settings.numberOfParallelLinesLeft)
	xmlFile:setUInt("keylines.settings#headlandWidth", self.settings.headlandWidth)
	xmlFile:setUInt("keylines.settings#stripWidth", self.settings.stripWidth)
	xmlFile:setUInt("keylines.settings#keylineWidth", self.settings.keylineWidth)

	-- Write keyline coordinates to XML (currently only a single keyline)
	local xmlKey = ("keylines.keyline(0)")
	for j = 1, #self.combinedKeyline do
		local coordKey = xmlKey .. (".coords(%d)"):format(j - 1)
		xmlFile:setFloat(coordKey .. "#x", self.combinedKeyline[j].x)
		xmlFile:setFloat(coordKey .. "#z", self.combinedKeyline[j].z)
	end

	-- Convert field boundary to a polygon and export that
	if success then
		local boundaryLine = courseField.fieldRootBoundary.boundaryLine
		for i = 1, #boundaryLine do
			local coordKey = ("keylines.fieldBoundary.coords(%d)"):format(i - 1)
			xmlFile:setFloat(coordKey .. "#x", boundaryLine[i][1])
			xmlFile:setFloat(coordKey .. "#z", boundaryLine[i][2])
		end
	else
		Logging.error("Failed computing field boundary")
	end
	xmlFile:save(true)
	xmlFile:delete()
end
Player.update = Utils.appendedFunction(Player.update, function(player, dt) writerInstance:update(dt) end)
function XmlExporter:update(dt)
	if self.fieldCourse ~= nil then
		self.fieldCourse:update(dt, 0.25)
	end
end

function ExportImportInterface.exportKeylines(keylines, settings)
	-- Combine both keyline directions into a single unidirectional line
	-- We skip the initial point on the second line since it's already in the first line
	local combinedKeyline = {}
	for i = #keylines[2], 2, -1 do
		table.insert(combinedKeyline, keylines[2][i])
	end
	for i = 1, #keylines[1] do
		table.insert(combinedKeyline, keylines[1][i])
	end

	-- Get the field boundaries and write to XML once that's done
	local x, z = keylines[1][1].x, keylines[1][1].z
	writerInstance.combinedKeyline = combinedKeyline
	writerInstance.settings = settings
	-- Use default settings - we are only interested in the field boundary anyway
	local fieldCourseSettings = FieldCourseSettings.new()

	-- Trigger field course generation to get the field boundary. Once that's done, XmlExporter.writeToXml will be called
	printf("Generating field boundary for keyline export...")
	writerInstance.fieldCourse = FieldCourseField.generateAtPosition(x, z, fieldCourseSettings, XmlExporter.writeToXml, writerInstance)

	return combinedKeyline
end

function ExportImportInterface.importParallelLines()
	-- Read parallel line coordinates from an XML file
	local filePath = Utils.getFilename("/parallel_lines.xml", g_currentMission.missionInfo.savegameDirectory)
	local xmlFile = XMLFile.load("parallelLinesXML", filePath, ExportImportInterface.importSchema)
	if not xmlFile then
		Logging.error("Failed importing parallel lines from XML")
		return
	end

	-- Add the keylines to the list of all coordinates first
	local allCurves = {}

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

	-- Now calculate all the required Y values
	for i = 1, #allCurves do
		local curve = allCurves[i]
		for j = 1, #curve do
			local coord = curve[j]
			local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, coord.x, 0, coord.z)
			coord.y = y
		end
	end
	printf("Returning %d curves", #allCurves)
	return allCurves
end