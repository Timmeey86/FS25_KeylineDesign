KeylineDesign = {}
MOD_DIR = g_currentModDirectory

-- Register the settings dialog
local settings = ConstructionBrushParallelLinesSettings.createInstance()
ParallelLineSettingsDialog.createInstance(settings)
ParallelLineSettingsDialog.getInstance():register()
BaseMission.loadMapFinished = Utils.appendedFunction(BaseMission.loadMapFinished, function(mission)
	ParallelLineSettingsDialog.getInstance():initializeValues()
end)

-- Allow reloading the settings dialog for faster development
local self = setmetatable({}, Class(KeylineDesign))
addConsoleCommand('kdReloadGui', '', 'consoleReloadGui', self)
function KeylineDesign:consoleReloadGui()
	ParallelLineSettingsDialog.getInstance():reload()
end


function KeylineDesign.buildTerrainPaintBrushes(constructionScreen, superFunc, numItems)
	numItems = superFunc(constructionScreen, numItems)

	printf("KeylineDesign: Adding Keyline Design brushes")

	local landscapingIndex = g_storeManager:getConstructionCategoryByName("landscaping").index
	local paintingTabIndex = g_storeManager:getConstructionTabByName("painting", "landscaping").index
	local keylineTabIndex = g_storeManager:getConstructionTabByName("keyline", "landscaping").index
	local parallelLineTabeIndex = g_storeManager:getConstructionTabByName("parallelLines", "landscaping").index
	local paintsTab = constructionScreen.items[landscapingIndex][paintingTabIndex]
	local keylineTab = constructionScreen.items[landscapingIndex][keylineTabIndex]
	local parallelLinesTab = constructionScreen.items[landscapingIndex][parallelLineTabeIndex]

	for _, paintBrush in ipairs(paintsTab) do
		local keylineBrush = {
			name = paintBrush.name,
			brushClass = ConstructionBrushKeyline,
			brushParameters = paintBrush.brushParameters,
			price = 0,
			imageFilename = nil,
			brandFilename = nil,
			modDlc = "FS25_KeylineDesign",
			terrainOverlayLayer = paintBrush.terrainOverlayLayer,
			uniqueIndex = numItems + 1
		}
		table.insert(keylineTab, keylineBrush)
		numItems = numItems + 1
	end
	for _, keylineBrush in ipairs(keylineTab) do
		local parallelLineBrush = {
			name = keylineBrush.name,
			brushClass = ConstructionBrushParallelLines,
			brushParameters = keylineBrush.brushParameters,
			price = keylineBrush.price,
			imageFilename = keylineBrush.imageFilename,
			brandFilename = keylineBrush.brandFilename,
			modDlc = keylineBrush.modDlc,
			terrainOverlayLayer = keylineBrush.terrainOverlayLayer,
			uniqueIndex = numItems + 1
		}
		table.insert(parallelLinesTab, parallelLineBrush)
		numItems = numItems + 1
	end

	return numItems
end
ConstructionScreen.buildTerrainPaintBrushes = Utils.overwrittenFunction(ConstructionScreen.buildTerrainPaintBrushes, KeylineDesign.buildTerrainPaintBrushes)

function KeylineDesign.loadStoreManagerMapData(storeManager, superFunc, xmlFile, missionInfo, baseDirectory)
	printf("KeylineDesign: Adding Keyline Design tab to store manager")

	local result = superFunc(storeManager, xmlFile, missionInfo, baseDirectory)

	local categoryName = "landscaping"
	local name = "keyline"
	local title = "Keyline Design" -- TODO translate
	local iconFilename = "dataS/menu/construction/ui_construction_icons.png"
	local iconUVs = GuiUtils.getUVs("0 0 1 1", "256 256")
	local baseDir = ""
	local sliceId = "gui.icon_construction_terraforming"

	storeManager:addConstructionTab(categoryName, name, title, iconFilename, iconUVs, baseDir, sliceId)

	name = "parallelLines"
	title = "Parallel lines" -- TODO translate
	storeManager:addConstructionTab(categoryName, name, title, iconFilename, iconUVs, baseDir, sliceId)

	return result
end
StoreManager.loadMapData = Utils.overwrittenFunction(StoreManager.loadMapData, KeylineDesign.loadStoreManagerMapData)
