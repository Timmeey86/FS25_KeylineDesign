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
---@return number @The X direction between the first two points (you can use this to calculate perpendicular or parallel lines)
---@return number @The Z direction between the first two points (you can use this to calculate perpendicular or parallel lines)
function KeylineCalculation.getSingleKeylineCoords(startX, startY, startZ, startXDir, startZDir, distance, amount)
	local x, y, z = startX, startY, startZ
	local currentAngle = math.atan2(startZDir, startXDir)
	local currentCoords = {}
	local mainXDir = startXDir
	local mainZDir = startZDir
	table.insert(currentCoords, {x = x, y = y, z = z })
	for i = 1, amount do
		local newX, newZ, newAngle = KeylineCalculation.getNextPointOnKeyline(x, y, z, currentAngle, distance)
		DebugUtil.drawDebugLine(x, y + 0.1, z, newX, y + 0.1, newZ, 1, 1, 1, .25)

		if i == 2 then
			-- Remember the direction for the next parallel line
			mainXDir = newX - x
			mainZDir = newZ - z
		end

		x = newX
		z = newZ
		currentAngle = newAngle
		table.insert(currentCoords, {x = x, y = y, z = z })
	end

	return currentCoords, mainXDir, mainZDir
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

---Gets a point which is distance meters away along a line perpendicular to the main direction
---@param x number @The X coordinate of the point on the keyline
---@param y number @The Y coordinate of the point on the keyline
---@param z number @The Z coordinate of the point on the keyline
---@param xDir number @The main X direction of the keyline
---@param zDir number @The main Z direction of the keyline
---@param distance number @The distance from the keyline (negative values will be on the left side, positive values on the right side)
---@return number, number, number @The X, Y and Z coordinates of the point
function KeylineCalculation.getPointOnParallelLine(x, y, z, xDir, zDir, distance)
	local x2, z2 = x - zDir * distance, z + xDir * distance
	local y2 = getTerrainHeightAtWorldPos(g_terrainNode, x2, 0, z2)
	if y2 ~= nil then
		return x2, y2, z2
	else
		return nil, nil, nil
	end
end

---Calculates a line parallel to the given line
---@param keylineCoords table @A list of coordinates along the keyline
---@param mainXDir number @The main X direction of the keyline
---@param mainZDir number @The main Z direction of the keyline
---@param distance number @The distance from the keyline (negative values will be on the left side, positive values on the right side)
---@return table @A list of coordinates along the parallel line
function KeylineCalculation.getParallelLine(keylineCoords, mainXDir, mainZDir, distance)
	local newCoords = {}
	local prevX, prevY, prevZ = nil, nil, nil
	local prevSourceX, prevSourceZ = nil, nil
	for i = 1, #keylineCoords do
		local coord = keylineCoords[i]
		local x, y, z = KeylineCalculation.getPointOnParallelLine(coord.x, coord.y, coord.z, mainXDir, mainZDir, distance)
		if x ~= nil then
			table.insert(newCoords, {x = x, y = y, z = z})

			if prevX ~= nil then
				DebugUtil.drawDebugLine(prevX, prevY + 0.1, prevZ, x, y + 0.1, z, 1, 1, 1, .25)
				-- Update the main direction as well since otherwise the distance would be off on curves
				mainXDir = coord.x - prevSourceX
				mainZDir = coord.z - prevSourceZ
			end
			prevX, prevY, prevZ = x, y, z
			prevSourceX, prevSourceZ = coord.x, coord.z
		end
	end
	return newCoords
end