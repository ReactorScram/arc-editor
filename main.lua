local arc = {
	start = { 
		pos = { 200.5, 300.5 },
		tangent = { 1.0, 0.0 },
	},
	stop = { 
		pos = { 600.5, 300.5 },
		tangent = { 1.0, 0.0 },
	},
	lines = nil,
}

local arcs = {}

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

local debug = { 0.0, 0.0 }

local function draw_arc (g, arc)
	g.setColor (255, 255, 255)
	
	if arc.lines == nil then
		local a = arc.start.pos
		local b = arc.stop.pos
		
		g.line (a [1], a [2], b [1], b [2])
		
		--g.line (b [1], b [2], b [1] + arc.stop.tangent [1] * 16, b [2] + arc.stop.tangent [2] * 16)
	else
		local ls = arc.lines
		for i = 1, #ls - 1 do
			local j = i + 1
			
			local a = ls [i]
			local b = ls [j]
			
			g.line (a [1], a [2], b [1], b [2])
		end
		
		if arc.stop.tangent then
			g.setColor (255, 64, 64)
			g.line (arc.stop.pos [1], arc.stop.pos [2], arc.stop.pos [1] + 16 * arc.stop.tangent [1], arc.stop.pos [2] + 16 * arc.stop.tangent [2])
			
			local basis = tangent_to_basis (arc.stop.tangent)
			
			local normal = from_basis ({0.0, 16.0}, basis)
			
			g.line (arc.stop.pos [1], arc.stop.pos [2], arc.stop.pos [1] + normal [1], arc.stop.pos [2] + normal [2])
		end
	end
	
	--g.setColor (64, 64, 64)
	--g.line (arc.start.pos [1], 0, arc.start.pos [1], 600)
end

local function solve_circular_arc (start, stop)
	local start_tangent = { 1.0, 0.0 }
	local overall_tangent = { stop [1] - start [1], stop [2] - start [2] }
	local ot_len = math.sqrt (math.pow (overall_tangent [1], 2.0) + math.pow (overall_tangent [2], 2.0))
	
	local overall_tangent = {overall_tangent [1] / ot_len, overall_tangent [2] / ot_len}
	
	local overall_normal = {-overall_tangent [2], overall_tangent [1]}
	
	local start_dot_normal = start_tangent [1] * overall_normal [1] + start_tangent [2] * overall_normal [2]
	
	local stop_tangent = { start_tangent [1] - 2 * start_dot_normal * overall_normal [1], start_tangent [2] - 2 * start_dot_normal * overall_normal [2] }
	
	local stop_normal = { stop_tangent [2], -stop_tangent [1] }
	
	local x_distance = stop [1] - start [1]
	
	local epsilon = 0.03125
	
	if math.abs (stop_normal [1]) < epsilon and math.abs (x_distance) > epsilon then
		-- Bail out
		return stop_normal, { start [1], start [2] }
	else
		local t = 0.0
		if math.abs (stop_normal [1]) >= epsilon then
			t = x_distance / -stop_normal [1]
		end
		local y_intercept = stop [2] + t * stop_normal [2]
		local radius = y_intercept - start [2]
		local circumference = radius * 2.0 * math.pi
		
		local segment_length = 8.0
		local segment_radians = segment_length / radius
		
		local points = {}
		
		-- The first one is just start but like whatever
		local flip_x = segment_radians < 0.0
		if flip_x then
			flip_x = 1.0
		else
			flip_x = 1.0
		end
		
		for segment = 0, 16 do
			local theta = segment * segment_radians
			
			table.insert (points, {
				start [1] + radius * flip_x * math.sin (theta),
				y_intercept - radius * math.cos (theta),
			})
		end
		
		return stop_normal, { start [1], y_intercept }, points
	end
	
	return stop_normal
	--return overall_normal
end

function bend_arc_basis (start, mouse, basis)
	local local_mouse = into_basis ({mouse [1] - start [1], mouse [2] - start [2]}, basis)
	
	local a, b, c = bend_arc ({0, 0}, local_mouse)
	
	local lines = {}
	for i, v in ipairs (c) do
		local v = from_basis (v, basis)
		lines [i] = {v [1] + start [1], v [2] + start [2]}
	end
	
	local tangent = from_basis (a, basis)
	
	return tangent, b, lines
end

function bend_arc (start, mouse)
	local theta = math.atan2 (mouse [2] - start [2], mouse [1] - start [1])
	local snapped_theta = (math.floor (((theta * 180.0 / math.pi) + 2.5) / 5.0) * 5.0) * math.pi / 180.0
	
	local radius = math.sqrt (math.pow (mouse [1] - start [1], 2.0) + math.pow (mouse [2] - start [2], 2.0))
	
	--[[
	local snapped_mouse = {
		radius * math.cos (snapped_theta) + start [1],
		radius * math.sin (snapped_theta) + start [2],
	}
	--]]
	
	local total_arc_theta = 2 * snapped_theta
	
	local num_segments = 16
	
	local arc_length = radius
	
	local curvature = total_arc_theta / arc_length
	if math.abs (curvature) < 0.0001 then
		return {1.0, 0.0}, nil, {
			start,
			{start [1] + arc_length, start [2]},
		}
	else 
		local radius = 1.0 / curvature
		
		local center = {
			start [1],
			start [2] + radius,
		}
		
		local lines = {}
		
		for i = 0, num_segments do
			local theta = i * total_arc_theta / num_segments - 0.5 * math.pi
			
			table.insert (lines, {
				center [1] + radius * math.cos (theta),
				center [2] + radius * math.sin (theta),
			})
		end
		
		return {math.cos (total_arc_theta), math.sin (total_arc_theta)}, nil, lines
	end
end

function love.draw ()
	for _, arc in ipairs (arcs) do
		draw_arc (love.graphics, arc)
	end
	draw_arc (love.graphics, arc)
	--love.graphics.line (debug [1], debug [2], arc.start.pos [1], arc.start.pos [2])
end

function love.mousemoved (x, y)
	--arc.stop.pos = { x, y }
	
	--arc.lines = solve_circular_arc (arc.start.pos, arc.stop.pos)
	arc.stop.tangent, debug, arc.lines = bend_arc_basis (arc.start.pos, {x, y}, tangent_to_basis (arc.start.tangent))
	arc.stop.pos = arc.lines [#arc.lines]
end

function love.mousepressed ()
	local old_arc = arc
	table.insert (arcs, arc)
	
	arc = {
		start = {
			pos = old_arc.stop.pos,
			tangent = old_arc.stop.tangent,
		},
		stop = {
			pos = old_arc.stop.pos,
			tangent = old_arc.stop.tangent,
		},
		lines = nil,
	}
end
