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
function ParallelCurveCalculation.getEquidistantPoints(curve, spacing)
    if #curve < 2 then return curve end

    local equidistant = {}
    table.insert(equidistant, {x = curve[1].x, y = getTerrainHeightAtWorldPos(g_terrainNode, curve[1].x, 0, curve[1].z), z = curve[1].z})

    local accumulatedDist = 0
    for i = 2, #curve do
        local p1 = curve[i - 1]
        local p2 = curve[i]
        local segmentLength = math.sqrt((p2.x - p1.x)^2 + (p2.z - p1.z)^2)

        while accumulatedDist + segmentLength >= spacing do
            local t = (spacing - accumulatedDist) / segmentLength
            local newX = p1.x + t * (p2.x - p1.x)
            local newZ = p1.z + t * (p2.z - p1.z)
            local newY = getTerrainHeightAtWorldPos(g_terrainNode, newX, 0, newZ)
            table.insert(equidistant, {x = newX, y = newY, z = newZ})

            -- Move to the next point along the segment
            p1.x, p1.z = newX, newZ
            segmentLength = math.sqrt((p2.x - p1.x)^2 + (p2.z - p1.z)^2)
            accumulatedDist = 0
        end
        accumulatedDist = accumulatedDist + segmentLength
    end

    return equidistant
end