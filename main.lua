local lume = require "lume"
local Basis = require "basis"
local Tesselate = require "tesselate"

local arc = nil
local arcs = {}
local lastMouse = {0, -16}
local track_radius = 20

local tool = "select"

local drag_start = {0, 0}
local drag_data = nil

local tools = {
	['a'] = {"append", "(A)rc"},
	['e'] = {'add_expander', "(E)xpander"},
	['g'] = {"grab_points", "(G)rab point"},
}

local tool_order = {
	"a",
	"e",
	"g",
}

local selected = {}



local function is_arc_grabbable (arcs, i)
	local prev_arc = arcs [i - 1]
	local arc = arcs [i]
	
	if arc and i == 1 then
		return true
	end
	
	if prev_arc and arc then
		return prev_arc.params.is_expander
	end
end

local function bend_arc_snap (mouse)
	local theta = math.atan2 (mouse [2], mouse [1])
	local theta_gran = 7.5
	local snapped_theta = (math.floor (((theta * 180.0 / math.pi) + theta_gran * 0.5) / theta_gran) * theta_gran) * math.pi / 180.0
	
	local radius = math.sqrt (math.pow (mouse [1], 2.0) + math.pow (mouse [2], 2.0))
	
	--local total_arc_theta = 2 * theta
	local total_arc_theta = 2 * snapped_theta
	
	local num_segments = 8
	local gran = num_segments * 3
	
	local arc_length = radius
	
	local arc_params = {
		total_theta = total_arc_theta,
		length = arc_length,
		num_segments = num_segments,
	}
	--local lines = Tesselate.arc (arc_params)
	local tangent = {math.cos (total_arc_theta), math.sin (total_arc_theta)}
	
	return tangent, arc_params
end

local function bend_expander (mouse)
	local midpoint = {
		mouse [1] * 0.5,
		mouse [2] * 0.5,
	}
	
	local theta = 2.0 * math.atan2 (mouse [2], mouse [1])
	local length = 0.5 * math.sqrt (math.pow (mouse [1], 2.0) + math.pow (mouse [2], 2.0))
	
	local arc_params = {
		total_theta = theta,
		length = length,
		num_segments = 4,
		is_expander = true,
	}
	
	return {1.0, 0.0}, arc_params
end

local function bend_arc_basis (start, mouse, basis, type)
	local local_mouse = Basis.into_basis ({mouse [1] - start [1], mouse [2] - start [2]}, basis)
	
	local tangent, arc_params
	
	if type == "expander" then
		tangent, arc_params = bend_expander (local_mouse)
	else
		tangent, arc_params = bend_arc_snap (local_mouse)
	end
	
	local tangent = Basis.from_basis (tangent, basis)
	
	return tangent, arc_params
end

local function draw_arc (g, arc, color)
	if not arc then
		return
	end
	
	local color = color or {255, 255, 255}
	
	g.setColor (color)
	
	if arc.params and arc.stop.tangent then
		local basis = Basis.tangent_to_basis (arc.start.tangent)
		local points = Tesselate.arc_basis (arc.start.pos, arc.params, basis)
		
		local function draw_polyline (ls)
			for i = 1, #ls - 1 do
				local j = i + 1
				
				local a = ls [i]
				local b = ls [j]
				
				g.line (a [1], a [2], b [1], b [2])
			end
		end
		
		draw_polyline (Tesselate.arc_basis (arc.start.pos, arc.params, basis, -track_radius))
		draw_polyline (Tesselate.arc_basis (arc.start.pos, arc.params, basis, track_radius))
		
		local pos = points [#points]
		local basis = Basis.tangent_to_basis (arc.stop.tangent)
		
		g.setColor (255, 64, 64)
		g.line (pos [1], pos [2], pos [1] + 16 * arc.stop.tangent [1], pos [2] + 16 * arc.stop.tangent [2])
		
		local length = 64.0
		local normal = Basis.from_basis ({0.0, 16.0}, basis)
		
		g.line (pos [1], pos [2], pos [1] + normal [1], pos [2] + normal [2])
	end
	
	--g.setColor (64, 64, 64)
	--g.line (arc.start.pos [1], 0, arc.start.pos [1], 600)
end

local function pick_arc (mouse_local, params, segment_length)
	local curvature = params.total_theta / (params.num_segments * segment_length)
	
	local hit_radius = track_radius + 2
	
	if math.abs (curvature) < 0.0001 then
		local radius_good = mouse_local [2] >= -hit_radius and mouse_local [2] <= hit_radius
		
		local theta_good = mouse_local [1] >= 0 and mouse_local [1] <= params.length
		
		return theta_good and radius_good
	else
		local radius = 1.0 / curvature
		
		local theta = math.atan2 (mouse_local [2] - radius, mouse_local [1]) + math.pi * 0.5
		
		if params.total_theta < 0.0 then
			theta = math.atan2 ((mouse_local [2] - radius), mouse_local [1]) - math.pi * 0.5
		end
		
		local mouse_radius = math.sqrt (math.pow (mouse_local [1], 2.0) + math.pow (mouse_local [2] - radius, 2.0))
		
		local radius_good = mouse_radius <= math.abs (radius) + hit_radius and mouse_radius >= math.abs (radius) - hit_radius
		
		local theta_good = theta >= math.min (0.0, params.total_theta) and theta <= math.max (0.0, params.total_theta)
		
		return radius_good and theta_good
	end
end

local function pick_arc_basis (arc, last_mouse)
	local basis = Basis.tangent_to_basis (arc.start.tangent)
	local mouse_local = Basis.into_basis ({
		last_mouse [1] - arc.start.pos [1],
		last_mouse [2] - arc.start.pos [2],
	}, basis)
	
	local points = Tesselate.arc_basis (arc.start.pos, arc.params, basis)
	--local end_pos = points [#points]
	local segment_length = math.sqrt (math.pow (points [2][1] - points [1][1], 2.0) + math.pow (points [2][2] - points [1][2], 2.0))
	
	local hit_radius = track_radius + 2
	
	return pick_arc (mouse_local, arc.params, segment_length)
end

local function mouse_in_circle (mouse, center, radius)
	local distance_sq = math.pow (mouse [1] - center [1], 2.0) + math.pow (mouse [2] - center [2], 2.0)
	
	return distance_sq <= radius * radius
end

function love.draw ()
	if tool == "append" or tool == "add_expander" then
		for _, arc in ipairs (arcs) do
			draw_arc (love.graphics, arc, {64, 64, 64})
		end
		draw_arc (love.graphics, arc)
		
		if not arc and #arcs == 0 then
			love.graphics.setColor (120, 120, 120)
			love.graphics.printf ("Click to start", 0, 300, 800, "center")
			
			love.graphics.setColor (255, 64, 64)
			love.graphics.line (lastMouse [1], lastMouse [2], lastMouse [1] + 16.0, lastMouse [2])
		end
	elseif tool == "grab_points" then
		for _, arc in ipairs (arcs) do
			draw_arc (love.graphics, arc, {64, 64, 64})
		end
		
		for i, arc in ipairs (arcs) do
			if is_arc_grabbable (arcs, i) then
				local color = {120, 120, 120}
				
				local center = arc.start.pos
				local radius = track_radius + 2
				
				if mouse_in_circle (lastMouse, center, radius) then
					color = {255, 64, 64}
				end
				
				love.graphics.setColor (color)
				love.graphics.circle ("line", center [1], center [2], radius)
			end
		end
	elseif tool == "select" then
		for _, arc in ipairs (arcs) do
			local color = {64, 64, 64, 255}
			local selected_color = {255, 64, 255, 255}
			
			if pick_arc_basis (arc, lastMouse) then
				color = selected_color
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
			
			arc.stop.tangent, arc.params = bend_arc_basis (arc.start.pos, {x, y}, Basis.tangent_to_basis (tangent))
		end
	elseif tool == "add_expander" then
		if arc then
			if #arcs >= 1 then
				arc.stop.tangent, arc.params = bend_arc_basis (arc.start.pos, {x, y}, Basis.tangent_to_basis (arc.start.tangent), "expander")
			end
		end
	elseif tool == "grab_points" then
		if love.mouse.isDown (1) then
			local mouse_delta = {
				x - drag_start [1],
				y - drag_start [2],
			}
			
			for _, i in ipairs (drag_data) do
				for j = i, #arcs do
					local arc = arcs [j]
					local prev_arc = arcs [j - 1]
					local next_arc = arcs [j + 1]
					
					local new_start_pos = {
						arc.start.pos [1] + mouse_delta [1],
						arc.start.pos [2] + mouse_delta [2],
					}
					
					if prev_arc and prev_arc.params.is_expander then
						prev_arc.stop.tangent, prev_arc.params = bend_arc_basis (prev_arc.start.pos, new_start_pos, Basis.tangent_to_basis (prev_arc.start.tangent), "expander")
					end
					
					if arc.params.is_expander then
						local stop_pos = nil
						
						if next_arc then
							stop_pos = next_arc.start.pos
						else
							local points = Tesselate.arc_basis (arc.start.pos, arc.params, Basis.tangent_to_basis (arc.start.tangent), 0.0)
							
							stop_pos = points [#points]
						end
						
						arc.start.pos = new_start_pos
						
						arc.stop.tangent, arc.params = bend_arc_basis (new_start_pos, stop_pos, Basis.tangent_to_basis (arc.start.tangent), "expander")
						break
					end
					
					arc.start.pos = new_start_pos
				end
			end
			
			drag_start = {x, y}
		end
	end
end

local function update_live_arc ()
	local old_arc = arcs [#arcs]
	if old_arc then
		local old_p = old_arc.params
		local old_points = Tesselate.arc_basis (old_arc.start.pos, old_p, Basis.tangent_to_basis (old_arc.start.tangent))
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
		arc = nil
	end
end

function love.mousepressed (x, y, button)
	drag_start = {x, y}
	
	if button == 1 then
		if tool == "append" or tool == "add_expander" then
			if arc then
				table.insert (arcs, arc)
				update_live_arc ()
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
		elseif tool == "grab_points" then
			drag_data = {}
			
			for i, arc in ipairs (arcs) do
				local arc_is_grabbable = is_arc_grabbable (arcs, i)
				if arc_is_grabbable and mouse_in_circle (drag_start, arc.start.pos, track_radius + 2) then
					table.insert (drag_data, i)
				end
			end
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
	
	local old_tool = tool
	
	local next_tool = tools [key]
	if next_tool then
		tool = next_tool [1]
		return
	end
	
	if tool == "append" or tool == "add_expander" then
		if key == "backspace" or key == "delete" then
			arcs [#arcs] = nil
			arc = nil
			update_live_arc ()
		end
	end
end
