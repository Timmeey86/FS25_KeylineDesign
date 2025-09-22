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