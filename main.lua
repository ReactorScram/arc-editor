local lume = require "lume"

local arc = nil
local arcs = {}
local lastMouse = {0, -16}
local track_radius = 10

local tool = "append"

local tools = {
	['d'] = {"append", "(D)raw"},
	['f'] = {'nothing', "(F)ucking nothing"},
}

local tool_order = {
	"d",
	"f"
}

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
		
		draw_polyline (tesselate_arc_basis (arc.start.pos, arc.params, basis, -track_radius))
		draw_polyline (tesselate_arc_basis (arc.start.pos, arc.params, basis, track_radius))
		
		local pos = points [#points]
		local basis = tangent_to_basis (arc.stop.tangent)
		
		g.setColor (255, 64, 64)
		g.line (pos [1], pos [2], pos [1] + 16 * arc.stop.tangent [1], pos [2] + 16 * arc.stop.tangent [2])
		
		local length = 64.0
		local normal = from_basis ({0.0, 16.0}, basis)
		
		g.line (pos [1], pos [2], pos [1] + normal [1], pos [2] + normal [2])
	end
	
	--g.setColor (64, 64, 64)
	--g.line (arc.start.pos [1], 0, arc.start.pos [1], 600)
end

function bend_arc_basis (start, mouse, basis, start_curvature)
	local local_mouse = into_basis ({mouse [1] - start [1], mouse [2] - start [2]}, basis)
	
	local a, arc_params = bend_arc (local_mouse, start_curvature)
	
	local tangent = from_basis (a, basis)
	
	return tangent, arc_params
end

function bend_arc (mouse, start_curvature)
	local theta = math.atan2 (mouse [2], mouse [1])
	local theta_gran = 7.5
	local snapped_theta = (math.floor (((theta * 180.0 / math.pi) + theta_gran * 0.5) / theta_gran) * theta_gran) * math.pi / 180.0
	
	local radius = math.sqrt (math.pow (mouse [1], 2.0) + math.pow (mouse [2], 2.0))
	
	--[[
	local snapped_mouse = {
		radius * math.cos (snapped_theta) + start [1],
		radius * math.sin (snapped_theta) + start [2],
	}
	--]]
	
	local total_arc_theta = 2 * snapped_theta
	
	local num_segments = 8
	local gran = num_segments * 3
	
	local arc_length = math.floor (radius / gran) * gran
	
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
	for i = 1, p.num_segments do
		local t = i / p.num_segments
		local local_curvature = curvature
		theta = theta + 0.5 * local_curvature * segment_length
		local point = {
			last_point [1] + segment_length * math.cos (theta),
			last_point [2] + segment_length * math.sin (theta),
		}
		theta = theta + 0.5 * local_curvature * segment_length
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
	if tool == "append" then
		for _, arc in ipairs (arcs) do
			draw_arc (love.graphics, arc)
		end
		draw_arc (love.graphics, arc, {120, 120, 120})
		
		if not arc and #arcs == 0 then
			love.graphics.setColor (120, 120, 120)
			love.graphics.printf ("Click to start", 0, 300, 800, "center")
			
			love.graphics.setColor (255, 64, 64)
			love.graphics.line (lastMouse [1], lastMouse [2], lastMouse [1] + 16.0, lastMouse [2])
		end
	elseif tool == "select" then
		for _, arc in ipairs (arcs) do
			local color = {64, 64, 64, 255}
			local selected_color = {255, 64, 64, 255}
			
			local curvature = arc.params.total_theta / arc.params.length
			local mouse_local = into_basis ({
				lastMouse [1] - arc.start.pos [1],
				lastMouse [2] - arc.start.pos [2],
			}, tangent_to_basis (arc.start.tangent))
			
			if math.abs (curvature) < 0.0001 then
				local radius_good = mouse_local [2] >= -10 and mouse_local [2] <= 10
				
				local theta_good = mouse_local [1] >= 0 and mouse_local [1] <= arc.params.length
				
				if theta_good and radius_good then
					color = selected_color
				end
			else
				local radius = 1.0 / curvature
				
				local theta = math.atan2 (mouse_local [2] - radius, mouse_local [1]) + math.pi * 0.5
				
				if radius < 0.0 then
					theta = math.atan2 (mouse_local [2] - radius, mouse_local [1]) - math.pi * 0.5
				end
				
				local mouse_radius = math.sqrt (math.pow (mouse_local [1], 2.0) + math.pow (mouse_local [2] - radius, 2.0))
				
				local radius_good = mouse_radius <= radius + 10 and mouse_radius >= radius - 10
				
				local theta_good = theta >= math.min (0.0, arc.params.total_theta) and theta <= math.max (0.0, arc.params.total_theta)
				
				if theta_good and radius_good then
					color = selected_color
				end
			end
			
			draw_arc (love.graphics, arc, color)
		end
		
		love.graphics.push ()
		
		if lastMouse [2] < 300 then
			love.graphics.translate (0, 500)
		else
			love.graphics.translate (0, 60)
		end
		
		love.graphics.setColor (64, 64, 64, 192)
		love.graphics.rectangle ("fill", 0, 0, 800, 40)
		
		local help_text = table.concat (lume.map (tool_order, function (char)
			return tools [char][2]
		end), ", ")
		
		love.graphics.setColor (240, 240, 240, 255)
		love.graphics.printf (help_text, 0, 15, 800, "center")
		
		love.graphics.pop ()
	end
end

function love.mousemoved (x, y)
	lastMouse = {x, y}
end

function love.update (dt)
	local x, y = love.mouse.getPosition ()
	
	if tool == "append" then
		if arc then
			local tangent = arc.start.tangent
			
			if #arcs == 0 then
				tangent = {
					x - arc.start.pos [1],
					y - arc.start.pos [2],
				}
				
				local theta = math.atan2 (tangent [2], tangent [1])
				local theta_gran = 7.5
				local snapped_theta = (math.floor (((theta * 180.0 / math.pi) + theta_gran * 0.5) / theta_gran) * theta_gran) * math.pi / 180.0
				
				tangent = {
					math.cos (snapped_theta),
					math.sin (snapped_theta),
				}
			end
			
			arc.start.tangent = tangent
			
			local gran = 5.0 / 16.0
			arc.stop.tangent, arc.params = bend_arc_basis (arc.start.pos, {x, y}, tangent_to_basis (tangent), arc.start.curvature)
		end
	end
end

local function update_live_arc ()
	local old_arc = arcs [#arcs]
	if old_arc then
		local old_p = old_arc.params
		local old_points = tesselate_arc_basis (old_arc.start.pos, old_p, tangent_to_basis (old_arc.start.tangent))
		local old_stop = old_points [#old_points]
		
		arc = {
			start = {
				pos = old_stop,
				tangent = old_arc.stop.tangent,
			},
			stop = {},
			params = nil,
		}
	else
		arc = {
			start = {
				pos = {x, y},
				tangent = {1, 0},
			},
			stop = {},
			params = nil,
		}
	end
end

function love.mousepressed (x, y, button)
	if button == 1 then
		if tool == "append" then
			table.insert (arcs, arc)
			update_live_arc ()
		end
	elseif button == 2 then
		tool = "select"
	end
end

local function save ()
	local f = io.open ("arc-editor.lua", "w")
	
	f:write ("return " .. lume.serialize (arcs))
	
	f:close ()
end

local function load ()
	arcs = dofile ("arc-editor.lua") or {}
	update_live_arc ()
end

local function roundtrip ()
	save ()
	load ()
end

function love.load ()
	load ()
end

function love.quit ()
	save ()
end

function love.keypressed (key)
	if key == "escape" then
		tool = "select"
	end
	
	if tool == "select" then
		local next_tool = tools [key]
		if next_tool then
			tool = next_tool [1]
		end
	end
end
