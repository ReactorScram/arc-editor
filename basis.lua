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

return {
	into_basis = into_basis,
	tangent_to_basis = tangent_to_basis,
	from_basis = from_basis,
}
