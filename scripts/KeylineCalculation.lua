KeylineCalculation = {}

---Calculates coordinates along a single keyline
---@param startX number @The X coordinate of the first point
---@param startY number @The Y coordinate of all points (after all a keyline is defined as having the same height above sea level)
---@param startZ number @The Z coordinate of the first point
---@param startXDir number @The rough X direction for the second point
---@param startZDir number @The rough Z direction for the second point
---@param distance number @The distance between points on the keyline
---@param amount number @The number of points to calculate
---@return table @A list of coordinates along the keyline
function KeylineCalculation.getSingleKeylineCoords(startX, startY, startZ, startXDir, startZDir, distance, amount)
	local x, y, z = startX, startY, startZ
	local currentAngle = math.atan2(startZDir, startXDir)
	local currentCoords = {}
	table.insert(currentCoords, {x = x, y = y, z = z })
	for i = 1, amount do
		local newX, newZ, newAngle = KeylineCalculation.getNextPointOnKeyline(x, y, z, currentAngle, distance)

		x = newX
		z = newZ
		currentAngle = newAngle
		table.insert(currentCoords, {x = x, y = y, z = z })
	end

	return currentCoords
end

function KeylineCalculation.getStraightLineCoords(startX, startZ, angleDeg, distance, direction)
	local dX, dZ = MathUtil.getDirectionFromYRotation(angleDeg * math.pi / 180)
	local endX, endZ = startX + dX * distance * direction, startZ + dZ * distance * direction

	local coords = {}
	local currentX, currentZ = startX, startZ
	local totalDistance = MathUtil.vector2Length(startX - endX, startZ - endZ)
	for i = 0, totalDistance + 1 do
		table.insert(coords, {x = currentX, y = getTerrainHeightAtWorldPos(g_terrainNode, currentX, 0, currentZ), z = currentZ})
		currentX = currentX + (dX * direction)
		currentZ = currentZ + (dZ * direction)
	end
	return coords
end

---Finds the next point with as close to the same Y value as possible.
---The search will be done in a +/-90 degree arc along the previous angle
---@param x number @The previous X value
---@param y number @The initial Y value
---@param z number @The previous Z value
---@param lastAngle number @The previous angle
---@param distance number @The distance to the next point
---@return number, number, number @The new X and Z values as well as the angle from the previous point to the new point
function KeylineCalculation.getNextPointOnKeyline(x, y, z, lastAngle, distance)
	local numProbes = 16
	local leastYDiff = math.huge
	local newXDir = math.cos(lastAngle)
	local newZDir = math.sin(lastAngle)
	local nextX = x
	local nextZ = z
	for i = 0, numProbes - 1 do
		local angleDiff = ((i - numProbes / 2) / numProbes) * math.pi
		local angleX = math.cos(lastAngle + angleDiff)
		local angleZ = math.sin(lastAngle + angleDiff)
		local probeX = x + angleX * distance
		local probeZ = z + angleZ * distance
		local candidateY = getTerrainHeightAtWorldPos(g_terrainNode, probeX, 0, probeZ)
		if candidateY ~= nil then
			local yDiff = math.abs(candidateY - y)
			if yDiff < leastYDiff then
				leastYDiff = yDiff
				newXDir = angleX
				newZDir = angleZ
				nextX = probeX
				nextZ = probeZ
			end
		end
	end
	local angle = math.atan2(newZDir, newXDir)
	return nextX, nextZ, angle
end

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
function KeylineCalculation.drawLines(keylines, exportedKeylines, importedParallelLines)

	if exportedKeylines == nil then
		exportedKeylines = {}
	end
	if importedParallelLines == nil then
		importedParallelLines = {}
	end
	local lines = {}
	for _, keyline in ipairs(keylines) do
		-- Current mouse keyline in red
		table.insert(lines, { coords = keyline, color = {1, 0, 0} })
	end
	for _, keyline in ipairs(exportedKeylines) do
		-- Exported keylines in yellow
		table.insert(lines, { coords = keyline, color = {1, 1, 0} })
	end
	for i = 1, #importedParallelLines do
		local curve = importedParallelLines[i]
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

end