ParallelCurveCalculation = {}

---Creates an offset curve from the given coords where coords is a list of {x=..., z=...} points
---@param coords table @A list of coordinates along the original curve
---@param offset number @The distance to offset the curve
---@return table @A list of coordinates along the offset curve
function ParallelCurveCalculation.createOffsetCurve(coords, offset)
    if coords == nil then
        Logging.error("Offset curve is nil")
        printCallstack()
    end
    local offset_curve = {}

    local function normalize(dx, dz)
        local len = math.sqrt(dx * dx + dz * dz)
        if len == 0 then return 0, 0 end
        return dx / len, dz / len
    end

    for i = 1, #coords do
        local prev = coords[math.max(i - 1, 1)]
        local curr = coords[i]
        local next = coords[math.min(i + 1, #coords)]

        -- Calculate tangent vector
        local tx = next.x - prev.x
        local tz = next.z - prev.z
        local nx, nz = normalize(-tz, tx) -- Perpendicular (normal) vector

        -- Offset point
        local ox = curr.x + nx * offset
        local oz = curr.z + nz * offset

        table.insert(offset_curve, {x = ox, z = oz})
    end

    return offset_curve
end

function ParallelCurveCalculation.removeLoops(offsetCoords)
    -- Helper: Check if two segments (p1-p2, q1-q2) intersect
    local function segmentsIntersect(p1, p2, q1, q2)
        local function ccw(a, b, c)
            return (c.z - a.z) * (b.x - a.x) > (b.z - a.z) * (c.x - a.x)
        end
        return (ccw(p1, q1, q2) ~= ccw(p2, q1, q2)) and (ccw(p1, p2, q1) ~= ccw(p1, p2, q2))
    end

    -- Remove large loops by checking if the curve crosses itself (not just adjacent segments)
    local n = #offsetCoords
    local keep = {}
    for i = 1, n do keep[i] = true end

    -- Check all pairs of non-adjacent segments for intersection
    for i = 1, n - 2 do
        local p1, p2 = offsetCoords[i], offsetCoords[i + 1]
        for j = i + 2, n - 1 do
            -- Skip consecutive segments (they share a point)
            if math.abs(i - j) > 1 then
                local q1, q2 = offsetCoords[j], offsetCoords[j + 1]
                if segmentsIntersect(p1, p2, q1, q2) then
                    -- Remove the points between i+1 and j (the loop)
                    for k = i + 1, j do
                        keep[k] = false
                    end
                end
            end
        end
    end

    -- Collect cleaned points
    local cleaned = {}
    for i = 1, n do
        if keep[i] then
            table.insert(cleaned, offsetCoords[i])
        end
    end
    return cleaned
end

---Converts a list of X/Z values with arbitrary spacing into a list of points with equal spacing
function ParallelCurveCalculation.getEquidistantPoints(curve, spacing, maxPoints)
    -- Space out the points evenly along the curve
    if #curve < 2 then
        return curve -- Not enough points to process
    end
    local curveLength = 0
    local segmentLengths = {}
    for i = 2, #curve do
        local dx = curve[i].x - curve[i - 1].x
        local dz = curve[i].z - curve[i - 1].z
        local segLen = math.sqrt(dx * dx + dz * dz)
        table.insert(segmentLengths, segLen)
        curveLength = curveLength + segLen
    end
    local numNewPoints = math.floor(curveLength / spacing)
    if maxPoints ~= nil and numNewPoints > maxPoints * 1.5 then
        numNewPoints = maxPoints * 1.5
    end
    if numNewPoints < 2 then
        return { curve[1], curve[#curve] } -- Just return start and end if too few points
    end
    local newCurve = {}
    local currentSeg = 1
    local currentSegPos = 0
    table.insert(newCurve, { x = curve[1].x, z = curve[1].z }) -- Start point
    for i = 1, numNewPoints - 1 do
        local targetDist = i * spacing
        while currentSeg <= #segmentLengths and currentSegPos + segmentLengths[currentSeg] < targetDist do
            currentSegPos = currentSegPos + segmentLengths[currentSeg]
            currentSeg = currentSeg + 1
        end
        if currentSeg > #segmentLengths then
            break -- Reached the end of the curve
        end
        local segStart = curve[currentSeg]
        local segEnd = curve[currentSeg + 1]
        local segLen = segmentLengths[currentSeg]
        local segFraction = (targetDist - currentSegPos) / segLen
        local newX = segStart.x + (segEnd.x - segStart.x) * segFraction
        local newZ = segStart.z + (segEnd.z - segStart.z) * segFraction
        table.insert(newCurve, { x = newX, z = newZ })
    end
    -- add the last point
    table.insert(newCurve, { x = curve[#curve].x, z = curve[#curve].z })
    return newCurve
end