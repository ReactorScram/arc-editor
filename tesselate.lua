local lume = require "lume"
local Basis = require "basis"

local function tesselate_arc (p, offset)
	local offset = offset or 0.0
	
	local points = {{0, 0}}
	local normals = {{0, offset}}
	
	local curvature = p.total_theta / p.num_segments
	local theta = 0.0
	local last_point = {0.0, 0.0}
	--local segment_length = p.length / p.num_segments
	local segment_length = 1.0
	for i = 1, p.num_segments do
		local t = i / p.num_segments
		local local_curvature = curvature
		theta = theta + 0.5 * local_curvature * segment_length
		local point = {
			last_point [1] + segment_length * math.cos (theta),
			last_point [2] + segment_length * math.sin (theta),
		}
		theta = theta + 0.5 * local_curvature * segment_length
		
		table.insert (points, point)
		
		if offset == 0.0 then
			table.insert (normals, {0, 0})
		else
			local normal_theta = theta + 0.5 * math.pi
			local normal = {
				offset * math.cos (normal_theta),
				offset * math.sin (normal_theta),
			}
			
			table.insert (normals, normal)
		end
		last_point = point
	end
	
	local effective_length = math.sqrt (math.pow (last_point [1], 2.0) + math.pow (last_point [2], 2.0))
	
	local scale = p.length / effective_length
	
	for i, v in ipairs (points) do
		points [i] = {
			v [1] * scale,
			v [2] * scale,
		}
	end
	
	local lines = {}
	
	for i = 1, #points do
		table.insert (lines, {
			points [i][1] + normals [i][1],
			points [i][2] + normals [i][2],
		})
	end
	
	if p.is_expander then
		local original_count = #lines
		local midpoint = points [original_count]
		for i = 1, original_count do
			local mirr_i = original_count - i + 1
			
			table.insert (lines, {
				2.0 * midpoint [1] - points [mirr_i][1] + normals [mirr_i][1],
				2.0 * midpoint [2] - points [mirr_i][2] + normals [mirr_i][2],
			})
		end
	end
	
	return lines
end

local function tesselate_arc_basis (start, p, basis, offset)
	return lume.map (tesselate_arc (p, offset), function (p)
		local p2 = Basis.from_basis (p, basis)
		return {p2 [1] + start [1], p2 [2] + start [2]}
	end)
end


return {
	arc_basis = tesselate_arc_basis,
	arc = tesselate_arc,
}
