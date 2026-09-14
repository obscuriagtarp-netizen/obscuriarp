return {
	{
		name = 'witch_pouch',
		label = 'Bolsa Arcana',
		owner = true,
		slots = 20,
		weight = 15000,
	},

	{
		coords = vec3(452.3, -991.4, 30.7),
		target = {
			loc = vec3(451.25, -994.28, 30.69),
			length = 1.2,
			width = 5.6,
			heading = 0,
			minZ = 29.49,
			maxZ = 32.09,
			label = 'Open personal locker'
		},
		name = 'policelocker',
		label = 'Personal locker',
		owner = true,
		slots = 70,
		weight = 70000,
		groups = shared.police
	},

	{
		coords = vec3(-1009.5, -421.49, 38.62),
		target = {
			loc = vec3(-1009.5, -421.49, 38.62),
			length = 0.6,
			width = 1.8,
			heading = 340,
			minZ = 43.34,
			maxZ = 44.74,
			label = 'Abrir baú'
		},
		name = 'emslocker',
		label = 'Baú Hospital',
		owner = false,
		slots = 70,
		weight = 170000,
		groups = {['ambulance'] = 0}
	},
	{
		coords = vec3(-332.41, -155.54, 38.06),
		target = {
			loc = vec3(-332.41, -155.54, 38.06),
			length = 0.6,
			width = 1.8,
			heading = 340,
			minZ = 43.34,
			maxZ = 44.74,
			label = 'Abrir baú'
		},
		name = 'mechaniclocker',
		label = 'Baú Mechanic',
		owner = false,
		slots = 70,
		weight = 170000,
		groups = {['mechanic'] = 0}
	},
}
