
mg_villages.wseed = 0;

minetest.register_on_mapgen_init(function(mgparams)
        mg_villages.wseed = math.floor(mgparams.seed/10000000000)
end)

function mg_villages.get_bseed(minp)
        return mg_villages.wseed + math.floor(5*minp.x/47) + math.floor(873*minp.z/91)
end

function mg_villages.get_bseed2(minp)
        return mg_villages.wseed + math.floor(87*minp.x/47) + math.floor(73*minp.z/91) + math.floor(31*minp.y/12)
end


mg_villages.inside_village = function(x, z, village, vnoise)
        return mg_villages.get_vn(x, z, vnoise:get2d({x = x, y = z}), village) <= 40
end

mg_villages.inside_village_area = function(x, z, village, vnoise)
        return mg_villages.get_vn(x, z, vnoise:get2d({x = x, y = z}), village) <= 80
end

mg_villages.get_vn = function(x, z, noise, village)
        local vx, vz, vs = village.vx, village.vz, village.vs
        return (noise - 2) * 20 +
                (40 / (vs * vs)) * ((x - vx) * (x - vx) + (z - vz) * (z - vz))
end


mg_villages.villages_in_mapchunk = function( minp )
	local noise1raw = minetest.get_perlin(12345, 6, 0.5, 256)
	
	local vcr = VILLAGE_CHECK_RADIUS
	local villages = {}
	local generate_new_villages = true;
	for xi = -vcr, vcr do
	for zi = -vcr, vcr do
		for _, village in ipairs(mg_villages.villages_at_point({x = minp.x + xi * 80, z = minp.z + zi * 80}, noise1raw)) do
			village.to_grow = {}
			villages[#villages+1] = village
		end
		-- check if the village exists already
		local v_nr = 1;
		for v_nr, village in ipairs(villages) do
			local village_id = tostring( village.vx )..':'..tostring( village.vz );
			if( mg_villages.all_villages and mg_villages.all_villages[ village_id ]) then
				villages[ v_nr ] = mg_villages.all_villages[ village_id ];
				generate_new_villages = false;
			end
		end
	end
	end
	return villages;
end


mg_villages.node_is_ground = {}; -- store nodes which have previously been identified as ground

mg_villages.check_if_ground = function( ci )
	if( not( ci )) then
		return false;
	end
	if( mg_villages.node_is_ground[ ci ]) then
		return true;
	end
	-- analyze the node
	-- only nodes on which walking is possible may be counted as ground
	local node_name = minetest.get_name_from_content_id( ci );
	local def = minetest.registered_nodes[ node_name ];	
	if( def and def.walkable == true and def.is_ground_content == true) then
		-- store information about this node type for later use
		mg_villages.node_is_ground[ ci ] = 1;
		return true;
	end
end

-- adjust the terrain level to the respective height of the village
mg_villages.flatten_village_area = function( villages, village_noise, minp, maxp, vm, data, param2_data, a, village_area )
	local c_air    = minetest.get_content_id( 'air' );
	local c_ignore = minetest.get_content_id( 'ignore' );
	local c_stone  = minetest.get_content_id( 'default:stone');
	local c_dirt   = minetest.get_content_id( 'default:dirt');
	local c_snow   = minetest.get_content_id( 'default:snow');
	local c_dirt_with_grass = minetest.get_content_id( 'default:dirt_with_grass' );

	for z = minp.z, maxp.z do
	for x = minp.x, maxp.x do
		for _, village in ipairs(villages) do
			if( village_area[ x ][ z ][ 2 ] > 0 ) then -- inside a village
--			if( mg_villages.inside_village(x, z, village, village_noise)) then
				local buffer = {};
				local buffer_param2 = {};
				local buffer_index  = 0;
				local has_snow      = false;
				y = maxp.y;
				while( y > minp.y ) do
					local ci = data[a:index(x, y, z)];
					if(     ci == c_snow ) then
						has_snow = true;
					elseif( ci ~= c_air and ci ~= c_ignore and buffer_index == 0) then
						if( mg_villages.check_if_ground( ci ) == true) then
							-- from now on, save the nodes below
							buffer_index = 1;
						end
					end
					-- save found nodes for later use
					if( buffer_index > 0 ) then
						buffer[        buffer_index ] = ci;
						buffer_param2[ buffer_index ] = param2_data[a:index(x, y, z)];
						buffer_index = buffer_index + 1;
					end
					-- make sure there is air for the village
					if( y > village.vh and ci ~= c_ignore and ci ~= c_air ) then
						data[a:index( x, y, z)] = c_air;
					end
					y = y-1;
				end
					
				-- apply the data found in the buffer
				for i,v in ipairs( buffer ) do
					if( village.vh - i + 1 >= minp.y ) then
						if( i==1 and buffer[i]==c_dirt ) then
							buffer[i] = c_dirt_with_grass;
						end
						data[       a:index( x, village.vh - i +1, z)] = buffer[        i ];
						param2_data[a:index( x, village.vh - i +1, z)] = buffer_param2[ i ];
					end
				end
				if( has_snow ) then
					data[       a:index( x, village.vh+1, z)] = c_snow;
				end
			end
		end
	end
	end
end


mg_villages.place_villages_via_voxelmanip = function( villages, minp, maxp, vm, data, param2_data, a, top )

	local village_noise = minetest.get_perlin(7635, 3, 0.5, 16);

	-- if no voxelmanip data was passed on, read the data here
	if( not( vm ) or not( a) or not( data ) or not( param2_data ) ) then
		vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
		if( not( vm )) then 
			return;
		end

		a = VoxelArea:new{
			MinEdge={x=emin.x, y=emin.y, z=emin.z},
			MaxEdge={x=emax.x, y=emax.y, z=emax.z},
		}

		data = vm:get_data()
		param2_data = vm:get_param2_data()
	end

	-- determine which coordinates are inside the village and which are not
	local village_area = {};

	for village_nr, village in ipairs(villages) do

		-- generate the village structure: determine positions of buildings and roads
		mg_villages.generate_village( village, village_noise);

		-- mark the roads and buildings and the area between buildings in the village_area table
		-- 2: road
		-- 3: border around a road 
		-- 4: building
		-- 5: border around a building
		for _, pos in ipairs(village.to_add_data.bpos) do
			local reserved_for = 4; -- a building will be placed here
			if( pos.btype and pos.btype == 'road' ) then
				reserved_for = 2; -- the building will be a road
			end
			-- the building + a border of 1 around it
			for x = -1, pos.bsizex do
				for z = -1, pos.bsizez do
					local p = {x=pos.x+x, z=pos.z+z};
					if( not( village_area[ p.x ] )) then
						village_area[ p.x ] = {};
					end
					if( x==-1 or z==-1 or x==pos.bsizex or z==pos.bsizez ) then
						-- borders around roads are more important than borders between buildings
						if( not( village_area[ p.x ][ p.z ] ) and (reserved_for == 2 )) then
							village_area[ p.x ][ p.z ] = { village_nr, reserved_for+1}; -- border around a building
						end
					else
						village_area[ p.x ][ p.z ] = { village_nr, reserved_for }; -- the actual building
					end
				end
			end
		end
        end


	-- mark the rest ( inside_village but not part of an actual building) as well		 
	for x = minp.x, maxp.x do
		if( not( village_area[ x ] )) then
			village_area[ x ] = {};
		end
		for z = minp.z, maxp.z do
			if( not( village_area[ x ][ z ] )) then
				village_area[ x ][ z ] = { 0, 0 };

				for village_nr, village in ipairs(villages) do
					if( mg_villages.inside_village_area(x, z, village, village_noise)) then
						village_area[ x ][ z ] = { village_nr, 1};
					end
				end
			end
		end
	end


--[[
-- figuring out the height this way hardly works - because only a tiny part of the village may be contained in this chunk	
	local height_sum   = {};
	local height_count = {};
	-- initialize the variables for counting
	for village_nr, village in ipairs( villages ) do
		height_sum[   village_nr ] = 0;
		height_count[ village_nr ] = 0;
	end
	-- try to find the optimal village height by looking at the borders defined by inside_village
	for x = minp.x+1, maxp.x-1 do
		for z = minp.z+1, maxp.z-1 do
			if(     village_area[ x ][ z ][ 2 ] ~= 0
                            and village_area[ x ][ z ][ 1 ] ~= 0
			    and ( village_area[ x+1 ][ z   ][ 2 ] == 0
			       or village_area[ x-1 ][ z   ][ 2 ] == 0 
			       or village_area[  x  ][ z+1 ][ 2 ] == 0 
			       or village_area[  x  ][ z-1 ][ 2 ] == 0 )) then

				y = maxp.y;
				while( y > minp.y and y >= 0) do
					local ci = data[a:index(x, y, z)];
					if( ci ~= c_air and ci ~= c_ignore and mg_villages.check_if_ground( ci ) == true) then
						local village_nr = village_area[ x ][ z ][ 1 ];
						height_sum[   village_nr ] = height_sum[   village_nr ] + y;
						height_count[ village_nr ] = height_count[ village_nr ] + 1;
						y = minp.y - 1;
					end
					y = y-1;
				end
			end
		end
	end
	for village_nr, village in ipairs( villages ) do
		if( height_count[ village_nr ] > 0 ) then
			local ideal_height = math.floor( height_sum[ village_nr ] / height_count[ village_nr ]);
print('For village_nr '..tostring( village_nr )..', a height of '..tostring( ideal_height )..' would be optimal. Sum: '..tostring( height_sum[ village_nr ] )..' Count: '..tostring( height_count[ village_nr ])..'. VS: '..tostring( village.vs)); -- TODO
		end
	end
--]]

	mg_villages.flatten_village_area( villages, village_noise, minp, maxp, vm, data, param2_data, a, village_area );

	local c_feldweg =  minetest.get_content_id('cottages:feldweg');
	if( not( c_feldweg )) then
		c_feldweg = minetest.get_content_id('default:cobble');
	end
	local c_air = minetest.get_content_id('air');
	for _, village in ipairs(villages) do

		village.to_add_data = mg_villages.place_buildings( village, minp, maxp, data, param2_data, a, village_noise);

		mg_villages.place_dirt_roads(                      village, minp, maxp, data, param2_data, a, village_noise, c_feldweg);
	end

	-- add farmland
	local c_dirt_with_grass = minetest.get_content_id( 'default:dirt_with_grass' );
	local c_desert_sand     = minetest.get_content_id( 'default:desert_sand' );
	local c_wheat           = minetest.get_content_id( 'farming:wheat_8' );
	local c_soil_wet        = minetest.get_content_id( 'farming:soil_wet' );
	local c_soil_sand       = minetest.get_content_id( 'farming:desert_sand_soil_wet' );
	-- desert sand soil is only available in minetest_next
	if( not( c_soil_sand )) then
		c_soil_sand = c_soil_wet;
	end
	local c_water_source    = minetest.get_content_id( 'default:water_source');
	local c_clay            = minetest.get_content_id( 'default:clay');
	local c_feldweg         = minetest.get_content_id( 'cottages:feldweg');
	if( not( c_feldweg )) then
		c_feldweg = c_dirt_with_grass;
	end

	for x = minp.x, maxp.x do
		for z = minp.z, maxp.z do
			-- turn unused land (which is either dirt or desert sand) into a field that grows wheat
			if( village_area[ x ][ z ][ 2 ]==1 ) then

				local h = villages[ village_area[ x ][ z ][ 1 ] ].vh;
				local g = data[a:index( x, h, z )];
				if( g==c_dirt_with_grass ) then	
					param2_data[a:index( x, h+1, z)] = math.random( 1, 179 );
					data[a:index( x,  h+1, z)] = c_wheat;
					data[a:index( x,  h,   z)] = c_soil_wet;
					data[a:index( x,  h-1, z)] = c_water_source;
					data[a:index( x,  h-2, z)] = c_clay;
				elseif( g==c_desert_sand and c_soil_sand and c_soil_sand > 0) then
					param2_data[a:index( x, h+1, z)] = math.random( 1, 179 );
					data[a:index( x,  h+1, z)] = c_wheat;
					data[a:index( x,  h,   z)] = c_soil_sand;
					data[a:index( x,  h-1, z)] = c_clay;      -- so that desert sand soil does not fall down
					data[a:index( x,  h-2, z)] = c_water_source;
					data[a:index( x,  h-3, z)] = c_clay;
				end
			end
		end
	end


	vm:set_data(data)
	vm:set_param2_data(param2_data)

	vm:calc_lighting(
		{x=minp.x-16, y=minp.y, z=minp.z-16},
		{x=maxp.x+16, y=maxp.y, z=maxp.z+16}
	)

	vm:write_to_map(data)

	-- initialize the pseudo random generator so that the chests will be filled in a reproducable pattern
	local pr = PseudoRandom(mg_villages.get_bseed(minp));
	local meta
	for _, village in ipairs(villages) do
		for _, n in pairs(village.to_add_data.extranodes) do
			minetest.set_node(n.pos, n.node)
			if n.meta ~= nil then
				meta = minetest.get_meta(n.pos)
				meta:from_table(n.meta)
				if n.node.name == "default:chest" then
					local inv = meta:get_inventory()
					local items = inv:get_list("main")
					for i=1, inv:get_size("main") do
						inv:set_stack("main", i, ItemStack(""))
					end
					local numitems = pr:next(3, 20) 
					for i=1,numitems do
						local ii = pr:next(1, #items) 
						local prob = items[ii]:get_count() % 2 ^ 8
						local stacksz = math.floor(items[ii]:get_count() / 2 ^ 8)
						if pr:next(0, prob) == 0 and stacksz>0 then
							stk = ItemStack({name=items[ii]:get_name(), count=pr:next(1, stacksz), wear=items[ii]:get_wear(), metadata=items[ii]:get_metadata()})
							local ind = pr:next(1, inv:get_size("main"))
							while not inv:get_stack("main",ind):is_empty() do
								ind = pr:next(1, inv:get_size("main"))
							end
							inv:set_stack("main", ind, stk)
						end
					end
				end
			end
		end

		-- now add those buildings which are .mts files and need to be placed by minetest.place_schematic(...)
		mg_villages.place_schematics( village.to_add_data.bpos, village.to_add_data.replacements, a, pr );

		if( not( mg_villages.all_villages )) then
			mg_villages.all_villages = {};
		end
		-- unique id - there can only be one village at a given pair of x,z coordinates
		local village_id = tostring( village.vx )..':'..tostring( village.vz );	
		-- the village data is saved only once per village - and not whenever part of the village is generated
		if( not( mg_villages.all_villages[ village_id ])) then

			-- count how many villages we already have and assign each village a uniq number
			local count = 1;
			for _,v in pairs( mg_villages.all_villages ) do
				count = count + 1;
			end
			village.nr = count;
			mg_villages.anz_villages = count;
			mg_villages.all_villages[ village_id ] = minetest.deserialize( minetest.serialize( village ));

			print("Village No. "..tostring( count ).." of type \'"..tostring( village.village_type ).."\' of size "..tostring( village.vs ).." spawned at: x = "..village.vx..", z = "..village.vz)
			save_restore.save_data( 'mg_all_villages.data', mg_villages.all_villages );
		end
	end
end



local function spawnplayer(player)
	local noise1 = minetest.get_perlin(12345, 6, 0.5, 256)
	local min_dist = math.huge
	local min_pos = {x = 0, y = 3, z = 0}
	for bx = -20, 20 do
	for bz = -20, 20 do
		local minp = {x = -32 + 80 * bx, y = -32, z = -32 + 80 * bz}
		for _, village in ipairs(mg_villages.villages_at_point(minp, noise1)) do
			if math.abs(village.vx) + math.abs(village.vz) < min_dist then
				min_pos = {x = village.vx, y = village.vh + 2, z = village.vz}
				min_dist = math.abs(village.vx) + math.abs(village.vz)
			end
		end
	end
	end
	player:setpos(min_pos)
end

minetest.register_on_newplayer(function(player)
	spawnplayer(player)
end)

minetest.register_on_respawnplayer(function(player)
	spawnplayer(player)
	return true
end)


-- the actual mapgen
-- It only does changes if there is at least one village in the area that is to be generated.
minetest.register_on_generated(function(minp, maxp, seed)
	-- only generate village on the surface chunks
	if( minp.y ~= -32 ) then
		return;
	end
	local villages = mg_villages.villages_in_mapchunk( minp );
	if( villages and #villages > 0 ) then
		mg_villages.place_villages_via_voxelmanip( villages, minp, maxp, nil, nil,  nil, nil, nil );
	end
end)

