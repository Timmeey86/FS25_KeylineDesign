-- mock/fake stuff
function printf(str, ...)
	print(str:format(...))
end

dofile("scripts/ParallelCurveCalculation.lua")
dofile("scripts/ParallelLineAlgorithm.lua")

local testCurve = {
{ x = 0, z = 0 },
{ x = 1, z = 0 },
{ x = 1.9848, z = -0.1736 },
{ x = 2.9245, z = -0.5156 },
{ x = 3.7905, z = -1.0156 },
{ x = 4.4333, z = -1.7816 },
{ x = 5.0761, z = -2.5476 },
{ x = 5.7189, z = -3.3136 },
{ x = 6.6586, z = -3.6556 },
{ x = 7.6434, z = -3.482 },
{ x = 8.4094, z = -2.8392 },
{ x = 8.7514, z = -1.8995 },
{ x = 8.925, z = -0.9147 },
{ x = 9.425, z = -0.0487 },
{ x = 10.1321, z = 0.6584 },
}

describe("ParallelLineAlgorithm", function()
	it("should print", function()
		local parallelCurve = ParallelLineAlgorithm.getParallelLine(testCurve, 1, 1, 0)
		for i, point in ipairs(parallelCurve) do
			printf("%.3f, %.3f", point.x, point.z)
		end
		local parallelCurve2 = ParallelLineAlgorithm.getParallelLine(parallelCurve, 1, 1, 0)
		for i, point in ipairs(parallelCurve2) do
			printf("%.3f, %.3f", point.x, point.z)
		end
	end)
end)