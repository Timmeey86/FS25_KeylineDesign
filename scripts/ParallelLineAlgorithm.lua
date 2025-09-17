-- This algorithm is implemented in accordance with
-- "An offset algorithm for polyline curves" by Xu-Zhen Liu, Jun-Hai Yong, Gua-Qin Zheng and Jia-Guang Sun
-- Computers in Industry 58 (2007) 240-254
-- This is however a heavily simplified implementation with the following limitations:
-- * Only lines are supported, no arcs (so only Algorithm1 (out of 4) is implemented)
-- * Only open polylines without intersections are supported

-- The input is simply a list of X/Z coordinate pairs
-- The output will be in an identical format

-- The original algorithm handles several different cases for line segments which have arbitrary starting points, like one
-- segment starting in the middle of a different segment etc.
-- We can simplify this a lot, however, since we have a consecutive chain of segments with no intersections, so there are exactly three cases:
-- 1) The joint has a 180° angle, meaning the segments are dead straight.
-- 2) The joint is angled towards the parallel line
-- 3) The joint is angled away from the parallel line
-- We might have to handle the last point specially since it could be a closed polyline in fact.

-- The Algorithm1 of the research paper, simplified to the given cases leaves the following logic:
-- 1. Calcuate the starting point of the parallel line by moving it perpendicular to the first segment
-- 2. For each following point (remember each point defines a segment from the previous point to the current one:)
--    a) in case of a 180° angle, create a parallel point by moving the original point perpendicular (just like the starting point)
--    b) if the joint turns towards the parallel line, calculate the intersection of the current and the next segment
--       and then add that intersection point to the parallel line. The resulting segment will stop early this way.
--    c) if the joint turns away from the parallel line, calculate the intersection of the current and the next segment
--       and then add that intersection point to the parallel line. The result segment will be extended to reach the intersection point.
ParallelLineAlgorithm = {}

local function getPerpendicularPoint(x, z, xDir, zDir, distance)
	return x - zDir * distance, z + xDir * distance
end

--- Calculates the intersection of a line through x1/z1 in direction dir1X/dir1Z and a line
--- through x2/z2 in direction dir2X/dir2Z
--- Returns nil if the lines are parallel
local function getIntersectionPoint(x1, z1, dir1X, dir1Z, x2, z2, dir2X, dir2Z)
	local D = dir1X * dir2Z - dir1Z * dir2X
	if math.abs(D) < .00001 then
		return nil -- lines are parallel
	end
	local t1 = ((x2 - x1) * dir2Z - (z2 - z1) * dir2X) / D
	local x = x1 + t1 * dir1X
	local z = z1 + t1 * dir1Z
	return x, z
end

function ParallelLineAlgorithm.getParallelLine(inputCoords, distance, mainXDir, mainZDir)
	if #inputCoords < 3 then
		return nil -- need at least two segments for this to make sense
	end
	local outputCoords = {}
	local origX, origZ = inputCoords[1].x, inputCoords[1].z

	-- Calculate the initial point and direction of the first segment
	local curX, curZ = getPerpendicularPoint(origX, origZ, mainXDir, mainZDir, distance)
	local curDirX, curDirZ = inputCoords[2].x - origX, inputCoords[2].z - origZ

	table.insert(outputCoords, {x = curX, z = curZ})
	for i = 2, #inputCoords - 1 do
		-- Get the directions of the current and the following segments as well as parallel starting points
		local dir2X, dir2Z = inputCoords[i + 1].x - inputCoords[i].x, inputCoords[i + 1].z - inputCoords[i].z
		local x2, z2 = getPerpendicularPoint(inputCoords[i].x, inputCoords[i].z, dir2X, dir2Z, distance)


		-- Calculate the intersection of the two lines and use that as the next point
		local x1, z1 = curX, curZ
		curX, curZ = getIntersectionPoint(x1, z1, curDirX, curDirZ, x2, z2, dir2X, dir2Z)
		local isParallel = curX == nil
		if isParallel then
			-- Lines are parallel, just add the perpendicular point
			curX, curZ = x2, z2
		end
		table.insert(outputCoords, {x = curX, z = curZ, parallel = isParallel})

		curX, curZ = x2, z2
		curDirX, curDirZ = dir2X, dir2Z
	end

	-- Add the last point
	local endX, endZ = inputCoords[#inputCoords].x, inputCoords[#inputCoords].z
	curX, curZ = getPerpendicularPoint(endX, endZ, curDirX, curDirZ, distance)
	table.insert(outputCoords, {x = curX, z = curZ})
	return outputCoords
end
