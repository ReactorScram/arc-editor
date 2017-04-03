local lume = require "lume"
local Basis = require "basis"
local Tesselate = require "tesselate"

local arcs = require "arc-editor"

local polylines = {}

local track_radius = 20

for _, arc in ipairs (arcs) do
	local basis = Basis.tangent_to_basis (arc.start.tangent)
	
	table.insert (polylines, Tesselate.arc_basis (arc.start.pos, arc.params, basis, -track_radius))
	table.insert (polylines, Tesselate.arc_basis (arc.start.pos, arc.params, basis, track_radius))
end

print ("return " .. lume.serialize (polylines))
