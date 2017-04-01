local lume = require "lume"

local arc = nil

local arcs = {}

local lastMouse = {0, -16}

local track_radius = 10

local function tangent_to_basis (tangent)
	return {
		x = tangent,
		y = {-tangent [2], tangent [1]},
	}
end

local function into_basis (v, basis)
	return {
		v [1] * basis.x [1] + v [2] * basis.x [2],
		v [1] * basis.y [1] + v [2] * basis.y [2],
	}
end

local function from_basis (v, basis)
	return {
		v [1] * basis.x [1] + v [2] * basis.y [1],
		v [1] * basis.x [2] + v [2] * basis.y [2],
	}
end

local function draw_arc (g, arc, color)
	if not arc then
		return
	end
	
	local color = color or {255, 255, 255}
	
	g.setColor (color)
	
	if arc.params and arc.stop.tangent then
		local basis = tangent_to_basis (arc.start.tangent)
		local points = tesselate_arc_basis (arc.start.pos, arc.params, basis)
		
		local function draw_polyline (ls)
			for i = 1, #ls - 1 do
				local j = i + 1
				
				local a = ls [i]
				local b = ls [j]
				
				g.line (a [1], a [2], b [1], b [2])
			end
		end
		
		draw_polyline (tesselate_arc_basis (arc.start.pos, arc.params, basis, -10))
		draw_polyline (tesselate_arc_basis (arc.start.pos, arc.params, basis, 10))
		
		local pos = points [#points]
		
		g.setColor (255, 64, 64)
		g.line (pos [1], pos [2], pos [1] + 16 * arc.stop.tangent [1], pos [2] + 16 * arc.stop.tangent [2])
		
		local basis = tangent_to_basis (arc.stop.tangent)
		
		local normal = from_basis ({0.0, 16.0}, basis)
		
		g.line (pos [1], pos [2], pos [1] + normal [1], pos [2] + normal [2])
	end
	
	--g.setColor (64, 64, 64)
	--g.line (arc.start.pos [1], 0, arc.start.pos [1], 600)
end

function bend_arc_basis (start, mouse, basis)
	local local_mouse = into_basis ({mouse [1] - start [1], mouse [2] - start [2]}, basis)
	
	local a, arc_params = bend_arc (local_mouse)
	
	local tangent = from_basis (a, basis)
	
	return tangent, arc_params
end

function bend_arc (mouse)
	local theta = math.atan2 (mouse [2], mouse [1])
	local snapped_theta = (math.floor (((theta * 180.0 / math.pi) + 2.5) / 5.0) * 5.0) * math.pi / 180.0
	
	local radius = math.sqrt (math.pow (mouse [1], 2.0) + math.pow (mouse [2], 2.0))
	
	--[[
	local snapped_mouse = {
		radius * math.cos (snapped_theta) + start [1],
		radius * math.sin (snapped_theta) + start [2],
	}
	--]]
	
	local total_arc_theta = 2 * snapped_theta
	
	local num_segments = 16
	
	local arc_length = radius
	
	local arc_params = {
		total_theta = total_arc_theta,
		length = arc_length,
		num_segments = num_segments,
	}
	local lines = tesselate_arc (arc_params)
	local tangent = {math.cos (total_arc_theta), math.sin (total_arc_theta)}
	
	return tangent, arc_params
end

function tesselate_arc_basis (start, p, basis, offset)
	return lume.map (tesselate_arc (p, offset), function (p)
		local p2 = from_basis (p, basis)
		return {p2 [1] + start [1], p2 [2] + start [2]}
	end)
end

function tesselate_arc (p, offset)
	local offset = offset or 0.0
	local lines = {
		{0.0, offset},
	}
	
	local curvature = p.total_theta / p.length
	local theta = 0.0
	local last_point = {0.0, 0.0}
	local segment_length = p.length / p.num_segments
	for i = 1, p.num_segments - 1 do
		theta = theta + curvature * segment_length
		local point = {
			last_point [1] + segment_length * math.cos (theta),
			last_point [2] + segment_length * math.sin (theta),
		}
		if offset == 0.0 then
			table.insert (lines, point)
		else
			local normal_theta = theta + 0.5 * math.pi
			local normal = {
				offset * math.cos (normal_theta),
				offset * math.sin (normal_theta),
			}
			
			table.insert (lines, {
				point [1] + normal [1],
				point [2] + normal [2],
			})
		end
		last_point = point
	end
	
	return lines
end

function love.draw ()
	for _, arc in ipairs (arcs) do
		draw_arc (love.graphics, arc)
	end
	draw_arc (love.graphics, arc, {120, 120, 120})
	
	if not arc and #arcs == 0 then
		love.graphics.setColor (120, 120, 120)
		love.graphics.printf ("Click to start", 0, 300, 800, "center")
		
		love.graphics.setColor (255, 64, 64)
		love.graphics.line (lastMouse [1], lastMouse [2], lastMouse [1], lastMouse [2])
	end
end

function love.mousemoved (x, y)
	if arc then
		arc.stop.tangent, arc.params = bend_arc_basis (arc.start.pos, {x, y}, tangent_to_basis (arc.start.tangent))
	end
	
	lastMouse = {x, y}
end

function love.mousepressed (x, y)
	local old_arc = arc
	table.insert (arcs, arc)
	
	if old_arc then
		local old_points = tesselate_arc_basis (old_arc.start.pos, old_arc.params, tangent_to_basis (old_arc.start.tangent))
		local old_stop = old_points [#old_points]
		
		arc = {
			start = {
				pos = old_stop,
				tangent = old_arc.stop.tangent,
			},
			stop = {
				pos = old_stop,
				tangent = old_arc.stop.tangent,
			},
			params = nil,
		}
	else
		arc = {
			start = {
				pos = {x, y},
				tangent = {1, 0},
			},
			stop = {
				pos = {x, y},
				tangent = {1, 0},
			},
			params = nil,
		}
	end
end
