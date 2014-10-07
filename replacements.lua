
-- ethereal comes with some intresting trees
if( minetest.get_modpath( 'ethereal' )) then
	mg_villages.ethereal_trees = {'willow','redwood','frost','mushroom','yellow','palm','banana'};
end

-- The trees modname is not unique; there are other mods which bear that name.
-- If all the other mods are present as well, it's a strong indication for realtest beeing the game.
if(	    minetest.get_modpath( 'trees' )
	and minetest.get_modpath( 'anvil')
	and minetest.get_modpath( 'joiner_table')
	and minetest.get_modpath( 'scribing_table' )) then
	mg_villages.realtest_trees = {'ash','aspen','birch','maple','chestnut','pine','spruce'};
	--print('REALTEST trees will be used.'); else print( 'NO REALTEST trees');

	-- realtest is very special as far as stairs are concerned
	mg_villages.realtest_stairs = {'default:stone','default:stone_flat','default:stone_bricks',
	                               'default:desert_stone_flat','default:desert_stone_bricks'};
	for i,v in ipairs(metals.list) do
		table.insert( mg_villages.realtest_stairs, 'metals:'..v..'_block' );
	end
	-- the list of minteral names is local; so we can't add "decorations:"..mineral[1].."_block"
end


-- only the function mg_villages.get_replacement_table(..) is called from outside this file

mg_villages.replace_materials = function( replacements, pr, original_materials, prefixes, materials, old_material )
	
	local postfixes = {};
	local use_realtest_stairs = false;
	-- handle realtest stairs/slabs
	if( mg_villages.realtest_trees 
		and #prefixes==3
		and prefixes[1]=='stairs:stair_' and prefixes[2]=='stairs:slab_' and prefixes[3]=='default:' ) then 

		prefixes  = {''};
		materials = mg_villages.realtest_stairs;
		postfixes = {''};
		use_realtest_stairs = true;	

	elseif( mg_villages.realtest_trees 
		and #prefixes==1 
		and prefixes[1]=='stairs:stair_') then
	
		return;
	else
		for i,v in ipairs( prefixes ) do
			postfixes[i] = '';
		end
	end

	local known_materials = {};
	local wood_found = false;
	-- for all alternate materials
	for i,m in ipairs( materials ) do
		-- check if that material exists for each supplied prefix
		for j,p in ipairs( prefixes ) do
			-- if wood is present, later on try moretrees wood as well
			if( 'default:wood' == m ) then
				wood_found = true;
			end
			if( minetest.registered_nodes[ p..m..postfixes[j] ] ) then
				table.insert( known_materials, m..postfixes[j] );
			end
		end	
	end
	
	-- support wooden planks from moretrees
	if( wood_found and moretrees and moretrees.treelist ) then
		for _,v in ipairs( moretrees.treelist ) do
			if( minetest.registered_nodes[ "moretrees:"..v[1].."_planks"] ) then
				table.insert( known_materials, "moretrees:"..v[1].."_planks" );
			end	
		end
	end

	if( wood_found and minetest.get_modpath('deco')) then
		local bfd_treelist = {'birch', 'cherry', 'evergreen', 'oak' };
		for _,v in ipairs( bfd_treelist ) do
			if( minetest.registered_nodes[ "deco:"..v.."_plank"] ) then
				table.insert( known_materials, "deco:"..v.."_plank" );
			end	
		end
	end
		
	if( wood_found and mg_villages.ethereal_trees ) then
		for _,v in ipairs( mg_villages.ethereal_trees ) do
			-- mushroom in ethereal is a pretty decorative material; increase its probability
			if( v == 'mushroom' ) then
				table.insert( known_materials, "ethereal:mushroom_pore" );
				table.insert( known_materials, "ethereal:mushroom_pore" );
				table.insert( known_materials, "ethereal:mushroom_pore" );
				-- also increase probability for the decorative blueish wood
				table.insert( known_materials, "ethereal:frost_wood" );
				table.insert( known_materials, "ethereal:frost_wood" );
			elseif( minetest.registered_nodes[ "ethereal:"..v.."_wood"] ) then
				table.insert( known_materials, "ethereal:"..v.."_wood" );
			end	
		end
	end

	if( wood_found and mg_villages.realtest_trees ) then
		for _,v in ipairs( mg_villages.realtest_trees ) do
			if( minetest.registered_nodes[ 'trees:'..v..'_planks'] ) then
				table.insert( known_materials, 'trees:'..v..'_planks' );
			end	
		end
	end


	-- nothing found which could be used
	if( #known_materials < 1 ) then
		return;
	end
	local new_material  = known_materials[ pr:next( 1, #known_materials )]; 

	if( use_realtest_stairs == true	) then
		table.insert( replacements, { original_materials[ 1 ], new_material..'_stair' } );
		table.insert( replacements, { original_materials[ 2 ], new_material..'_slab' } );
		table.insert( replacements, { original_materials[ 3 ], new_material } );
		table.insert( replacements, { original_materials[ 1 ]..'upside_down', new_material..'_stair_upside_down' } );
		table.insert( replacements, { original_materials[ 2 ]..'upside_down', new_material..'_slab_upside_down' } );
		return new_material;
	end

	-- no replacement necessary if we did choose the same material as before
	if( new_material == old_material or old_material == (prefixes[1]..new_material)) then
		return old_material;
	end

	for i,v in ipairs( prefixes ) do
		table.insert( replacements, { original_materials[ i ], v..new_material } );
	end
	return new_material;
end

-- replace the tree trunk as well so that it fits to the wood type
mg_villages.replace_tree_trunk = function( replacements, wood_type )
	if(     wood_type == 'default:junglewood' ) then
		table.insert( replacements, {'default:tree',  'default:jungletree'});
	elseif( wood_type == 'mg:savannawood' ) then
		table.insert( replacements, {'default:tree',  'mg:savannatree'});
	elseif( wood_type == 'mg:pinewood' ) then
		table.insert( replacements, {'default:tree',  'mg:pinetree'});

 	elseif( moretrees and moretrees.treelist ) then
		for _,v in ipairs( moretrees.treelist ) do
			if( wood_type == "moretrees:"..v[1].."_planks" ) then
				table.insert( replacements, {'default:tree',   "moretrees:"..v[1].."_trunk"});
				table.insert( replacements, {'default:leaves', "moretrees:"..v[1].."_leaves"});
			end
		end

	elseif( wood_type == 'deco:birch_plank' ) then
		table.insert( replacements, {'default:tree', "mapgen:birch_log"});
	elseif( wood_type == 'deco:cherry_plank' ) then
		table.insert( replacements, {'default:tree', "mapgen:cherry_log"});
	elseif( wood_type == 'deco:evergreen_plank' ) then
		table.insert( replacements, {'default:tree', "mapgen:evergreen_log"});
	elseif( wood_type == 'deco:oak_plank' ) then
		table.insert( replacements, {'default:tree', "mapgen:oak_log"});

	elseif( wood_type == 'ethereal:frost_wood' ) then
		table.insert( replacements, {'default:tree', "ethereal:frost_tree"});

	elseif( wood_type == "ethereal:mushroom_pore" ) then
		table.insert( replacements, {'default:tree', "ethereal:mushroom_trunk"});

	elseif( mg_villages.ethereal_trees ) then
		for _,v in ipairs( mg_villages.ethereal_trees ) do
			if( wood_type == "ethereal:"..v.."_wood" ) then
				table.insert( replacements, {'default:tree', "ethereal:"..v.."_trunk"});
			end
		end

	elseif( mg_villages.realtest_trees ) then
		for _,v in ipairs( mg_villages.realtest_trees ) do
			if( wood_type == 'trees:'..v..'_planks' ) then
				table.insert( replacements, {'default:tree', "trees:"..v..'_log'});
				-- realtest does not have most of the nodes from default, so we need to replace them as well
				table.insert( replacements, {'default:wood',         'trees:'..v..'_planks'});
				table.insert( replacements, {'default:leaves',       'trees:'..v..'_leaves'});
				table.insert( replacements, {'default:ladder',       'trees:'..v..'_ladder'});
				table.insert( replacements, {'default:chest',        'trees:'..v..'_chest'});
				table.insert( replacements, {'default:chest_locked', 'trees:'..v..'_chest_locked'});
				table.insert( replacements, {'default:fence_wood',   'fences:'..v..'_fence'});
				table.insert( replacements, {'default:bookshelf',    'decorations:bookshelf_'..v});
				table.insert( replacements, {'doors:door_wood_t_1',  'doors:door_'..v..'_t_1'});
				table.insert( replacements, {'doors:door_wood_b_1',  'doors:door_'..v..'_b_1'});
				table.insert( replacements, {'doors:door_wood_t_2',  'doors:door_'..v..'_t_2'});
				table.insert( replacements, {'doors:door_wood_b_2',  'doors:door_'..v..'_b_2'});
				-- not really wood-realted, but needs to be replaced as well
				table.insert( replacements, {'default:furnace',      'oven:oven'});
				-- farming is also handled diffrently
				table.insert( replacements, {'farming:soil_wet',     'farming:soil'});
				table.insert( replacements, {'farming:cotton_1',     'farming:flax_1'});
				table.insert( replacements, {'farming:cotton_2',     'farming:flax_1'});
				table.insert( replacements, {'farming:cotton_3',     'farming:flax_2'});
				table.insert( replacements, {'farming:cotton_4',     'farming:flax_2'});
				table.insert( replacements, {'farming:cotton_5',     'farming:flax_3'});
				table.insert( replacements, {'farming:cotton_6',     'farming:flax_3'});
				table.insert( replacements, {'farming:cotton_7',     'farming:flax_4'});
				table.insert( replacements, {'farming:cotton_8',     'farming:flax_4'});
				-- stairs and slabs made out of default wood
				table.insert( replacements, {'stairs:stair_wood',    'trees:'..v..'_planks_stair'});
				table.insert( replacements, {'stairs:slab_wood',     'trees:'..v..'_planks_slab'});
				table.insert( replacements, {'stairs:stair_woodupside_down','trees:'..v..'_planks_stair_upside_down' } );
				table.insert( replacements, {'stairs:slab_woodupside_down', 'trees:'..v..'_planks_slab_upside_down' } );
			end
		end
	else
		return nil;
	end
	return wood_type;
-- TODO if minetest.get_modpath("moreblocks") and moretrees.enable_stairsplus the
end


-- if buildings are made out of a certain wood type, people might expect trees of that type nearby
mg_villages.replace_saplings = function( replacements, wood_type )
	if(     wood_type == 'default:junglewood' ) then
		table.insert( replacements, {'default:sapling',  'default:junglesapling'});
	elseif( wood_type == 'mg:savannawood' ) then
		table.insert( replacements, {'default:sapling',  'mg:savannasapling'});
	elseif( wood_type == 'mg:pinewood' ) then
		table.insert( replacements, {'default:sapling',  'mg:pinesapling'});
 	elseif( moretrees and moretrees.treelist ) then
		for _,v in ipairs( moretrees.treelist ) do
			if( wood_type == "moretrees:"..v[1].."_planks" ) then
				table.insert( replacements, {'default:sapling', "moretrees:"..v[1].."_sapling_ongen"});
			end
		end
 	elseif( mg_villages.ethereal_trees ) then
		for _,v in ipairs( mg_villages.ethereal_trees ) do
			if( wood_type == "ethereal:"..v.."_wood" ) then
				table.insert( replacements, {'default:sapling', "ethereal"..v.."_sapling"});
			end
		end

 	elseif( mg_villages.realtest_trees ) then
		for _,v in ipairs( mg_villages.realtest_trees ) do
			if( wood_type == 'trees:'..v..'_planks' ) then
				table.insert( replacements, {'default:sapling', "trees:"..v.."_sapling"});
				table.insert( replacements, {'default:junglesapling', "trees:"..v.."_sapling"});
			end
		end

	elseif( wood_type == 'deco:birch_plank' ) then
		table.insert( replacements, {'default:sapling', "mapgen:birch_sapling"});
	elseif( wood_type == 'deco:cherry_plank' ) then
		table.insert( replacements, {'default:sapling', "mapgen:cherry_sapling"});
	elseif( wood_type == 'deco:evergreen_plank' ) then
		table.insert( replacements, {'default:sapling', "mapgen:evergreen_sapling"});
	elseif( wood_type == 'deco:oak_plank' ) then
		table.insert( replacements, {'default:sapling', "mapgen:oak_sapling"});
	end
end


-- Note: This function is taken from the villages mod (by Sokomine)
-- at least the cottages may come in a variety of building materials
-- IMPORTANT: don't add any nodes which have on_construct here UNLESS they where in the original file already
--            on_construct will only be called for known nodes that need that treatment (see villages.analyze_mts_file and on_constr)
mg_villages.get_replacement_list = function( housetype, pr )

   local replacements = {};

  -- else some grass would never (re)grow (if it's below a roof)
--   table.insert( replacements, {'default:dirt',            dirt_with_grass_replacement });
--   table.insert( replacements, {'default:dirt_with_grass', dirt_with_grass_replacement });
   table.insert( replacements, {'default:dirt',            'default:dirt_with_grass' });

   -- realtest lacks quite a lot from default
   if( mg_villages.realtest_trees ) then
	for i=1,8 do
   		table.insert( replacements, {'farming:wheat_'..i,       'farming:spelt_'..tostring( (i+(i%2))/2) });
   		table.insert( replacements, {'farming:cotton_'..i,      'farming:flax_' ..tostring( (i+(i%2))/2) });
	end
	for i=1,5 do
   		table.insert( replacements, {'default:grass_'..i,       'air' });
	end
  	table.insert(         replacements, {'default:apple',           'air' });
  	table.insert(         replacements, {'default:cobble',          'default:stone_macadam' });
  	table.insert(         replacements, {'default:obsidian_glass',  'default:glass' });
   end


   local wood_type = 'default:wood';
   -- Taokis houses from structure i/o
   if( housetype == 'taoki' ) then  

      if( mg_villages.realtest_trees ) then
         wood_type = mg_villages.replace_materials( replacements, pr,
		{'default:wood'},
		{''},
		{'default:wood'},
 		'default:wood');
         table.insert( replacements, {'stairs:stair_cobble', 'default:stone_bricks_stair' }); 
         table.insert( replacements, {'stairs:slab_cobble',  'default:stone_bricks_slab' }); 
         table.insert( replacements, {'stairs:stair_stone',  'default:stone_flat_stair' }); 
         table.insert( replacements, {'stairs:slab_stone',   'default:stone_flat_slab' }); 
      else    
      -- the main body of the houses in the .mts files is made out of wood
         wood_type = mg_villages.replace_materials( replacements, pr,
		{'default:wood'},
		{''},
		{'default:wood', 'default:junglewood', 'mg:pinewood', 'mg:savannawood',
		'default:clay', 'default:brick', 'default:sandstone', 
		'default:stonebrick', 'default:desert_stonebrick','default:sandstonebrick', 'default:sandstone','default:stone','default:desert_stone',
		'default:coalblock','default:steelblock','default:goldblock', 'default:bronzeblock', 'default:copperblock', 'wool:white',
		'default:stone_flat', 'default:desert_stone_flat', -- realtest
		'darkage:adobe', 'darkage:basalt', 'darkage:basalt_cobble', 'darkage:chalk',
		'darkage:gneiss', 'darkage:gneiss_cobble', 'darkage:marble', 'darkage:marble_tile',
		'darkage:mud', 'darkage:ors', 'darkage:ors_cobble',
		'darkage:schist', 'darkage:serpentine', 'darkage:shale', 'darkage:silt', 'darkage:slate',
		'mapgen:mese_stone', 'mapgen:soap_stone'},
		'default:wood');
      end
      -- tree trunks are seldom used in these houses; let's change them anyway
      mg_villages.replace_tree_trunk( replacements, wood_type );
		
      -- all this comes in variants for stairs and slabs as well
      mg_villages.replace_materials( replacements, pr,
		{'stairs:stair_stonebrick',  'stairs:slab_stonebrick', 'default:stonebrick'},
		{'stairs:stair_',            'stairs:slab_',           'default:'          },
		{ 'stonebrick', 'stone', 'sandstone', 'cobble'},
		'stonebrick');

      -- decorative slabs above doors etc.
      mg_villages.replace_materials( replacements, pr,
		{'stairs:stair_wood'},
		{'stairs:stair_'},
		{'stonebrick', 'stone', 'sandstone', 'cobble', 'wood', 'junglewood' },
		'wood');

      -- brick roofs are a bit odd; but then...
      -- all three shapes of roof parts have to fit together
      mg_villages.replace_materials( replacements, pr,
		{'stairs:stair_brick',  'stairs:slab_brick', 'default:brick'},
		{'stairs:stair_',       'stairs:slab_',      'default:'     },
		{ 'brick', 'stone', 'cobble', 'stonebrick', 'wood', 'junglewood', 'sandstone' },
		'brick' );

      return replacements;
   end


   if( housetype == 'nore' ) then

      mg_villages.replace_materials( replacements, pr,
--		{'default:stonebrick'},
--		{'default:'},
		{'stairs:stair_stonebrick',  'stairs:slab_stonebrick', 'default:stonebrick'},
		{'stairs:stair_',       'stairs:slab_',      'default:'     },
		{'stonebrick', 'desert_stonebrick','sandstonebrick', 'sandstone','stone','desert_stone','stone_flat','desert_stone_flat','stone_bricks','desert_strone_bricks'},
		'stonebrick');

      -- replace the wood as well
      local wood_type = mg_villages.replace_materials( replacements, pr,
		{'default:wood'},
		{''},
		{ 'default:wood', 'default:junglewood', 'mg:savannawood', 'mg:pinewood' },
		'default:wood');
      mg_villages.replace_tree_trunk( replacements, wood_type );
      mg_villages.replace_saplings(   replacements, wood_type );

      if( pr:next(1,3)==1 and not( mg_villages.realtest_trees)) then
         table.insert( replacements, {'default:glass', 'default:obsidian_glass'});
      end

      if( mg_villages.realtest_trees ) then
         table.insert( replacements, {'stairs:stair_cobble', 'default:stone_bricks_stair' }); 
         table.insert( replacements, {'stairs:slab_cobble',  'default:stone_bricks_slab' }); 
      end
      return replacements;
   end


   if( housetype == 'lumberjack' ) then

      -- replace the wood - those are lumberjacks after all
      local wood_type = mg_villages.replace_materials( replacements, pr,
		{'default:wood'},
		{''},
		{ 'default:wood', 'default:junglewood', 'mg:savannawood', 'mg:pinewood' },
		'default:wood');
      mg_villages.replace_tree_trunk( replacements, wood_type );
      mg_villages.replace_saplings(   replacements, wood_type );

      if( not( minetest.get_modpath('bell' ))) then
         table.insert( replacements, {'bell:bell',               'default:goldblock' });
      end
      return replacements;
   end


   if( housetype == 'canadian' ) then

      table.insert( replacements, {'4seasons:slimtree_wood', 'default:fence_wood'});
      if( true) then return replacements; end -- TODO
      -- remove inner corners, wallpapers etc.
      local to_air = { 38, 36, 68, 66, 69, 67, 77, 47, 44, 43, 37, 75, 45, 65, 71, 76, 46 };
      for _,v in ipairs( to_air ) do
         table.insert( replacements, {'hdb:'..tostring( v )..'_ic',  'air' });
      end
 
      to_air = { 49, 50, 52, 72, 73, 74 };
      for _,v in ipairs( to_air ) do
         table.insert( replacements, {'hdb:'..tostring( v )..'_edge',  'air' });
      end
 
      to_air = { 49, 50, 52, 72, 73, 74 };
      for _,v in ipairs( to_air ) do
         table.insert( replacements, {'hdb:'..tostring( v )..'_edgeic',  'air' });
      end

      -- thin slabs for covering walls
      to_air = { 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 65, 66, 67, 68, 69, 71, 72, 73, 74, 75, 76, 77 };
      for _,v in ipairs( to_air ) do
         table.insert( replacements, {'hdb:'..tostring( v ),  'air' });
      end

     -- these contain the majority of nodes used (junglewood is too dark)
      local materials = {'default:wood', 'mg:pinewood', 'mg:savannawood',
		'default:clay', 'default:brick', 'default:sandstone', 
		'default:stonebrick', 'default:desert_stonebrick','default:sandstonebrick', 'default:sandstone','default:stone','default:desert_stone',
		'default:coalblock','default:steelblock'};

--      local change_groups = { {49, 16, 29, 33, 82, 8}, {19,  4, 83,  2}, { 5, 80, 35, 36, 3}, {10, 31}, {28, 78}, { 6, 52, 1}, {7}};
      local change_groups = { {16, 29, 33, 82, 8}, {19,  4, 83,  2}, { 5, 80, 35, 3}, {10, 31}, {28, 78, 27}, { 6, 1}, {7}, {30,25,81,79},{64}};
      for _,cg in ipairs( change_groups ) do

         local m1 = materials[ pr:next( 1, #materials )];
         for j,v in ipairs( cg ) do
            table.insert( replacements, {'hdb:'..tostring( v ), m1 });
         end
      end

      -- hdb:9_lh and hdb:86_lh are slabs
      local materials_slab = {'stonebrick', 'stone', 'sandstone', 'cobble' };
      local slab_group = {33,58};
      for _, c in ipairs( slab_group ) do 
         local ms = materials_slab[ pr:next( 1, #materials_slab )];
         table.insert( replacements, { 'hdb:'..tostring(c)..'_lh',     'stairs:slab_'..ms });
         table.insert( replacements, { 'hdb:'..tostring(c),            'default:'..ms });
      end

      return replacements;
   end


   if( housetype == 'logcabin' ) then

      -- for logcabins, wood is the most likely type of roof material
      local roof_type = mg_villages.replace_materials( replacements, pr,
		{'stairs:stair_cobble',      'stairs:slab_cobble' },
		{'cottages:roof_connector_', 'cottages:roof_flat_' },
		{'straw', 'wood',  'wood', 'wood', 'reet', 'slate', 'red', 'brown', 'black'},
		'' );
      -- some houses have junglewood roofs
      if( roof_type ) then
         table.insert( replacements, {'stairs:stair_junglewood',          'cottages:roof_connector_'..roof_type });
         table.insert( replacements, {'stairs:slab_junglewood',           'cottages:roof_flat_'..roof_type });
         table.insert( replacements, {'cottages:roof_connector_wood',     'cottages:roof_connector_'..roof_type });
         table.insert( replacements, {'cottages:roof_flat_wood',          'cottages:roof_flat_'..roof_type });
      -- realtest does not have normal stairs
      elseif( mg_villages.realtest_trees ) then
         table.insert( replacements, {'stairs:stair_junglewood',          'trees:aspen_planks_stair' });
         table.insert( replacements, {'stairs:slab_junglewood',           'trees:aspen_planks_slab' });
      end

      if( mg_villages.realtest_trees ) then
         local wood_type = mg_villages.replace_materials( replacements, pr,
		{'default:wood'},
		{''},
		{ 'default:wood' },
		'default:wood');
         mg_villages.replace_tree_trunk( replacements, wood_type );
         mg_villages.replace_saplings(   replacements, wood_type );
         table.insert( replacements, {'default:stonebrick',      'default:stone_bricks' }); -- used for chimneys
         table.insert( replacements, {'stairs:stair_stonebrick', 'default:stone_bricks_stair' }); 
         -- table.insert( replacements, {'default:junglewood', wood_type }); -- replace the floor
         -- replace the floor with another type of wood (looks better than the same type as above)
         mg_villages.replace_materials( replacements, pr,
		{'default:junglewood'},
		{''},
		{ 'default:wood' },
		'default:junglewood');
      end
      return replacements;
   end


   if( housetype == 'grasshut' ) then

      table.insert( replacements, {'moreblocks:fence_jungle_wood',     'default:fence' });
      if( pr:next( 1, 4) == 1 ) then
         table.insert( replacements, {'dryplants:reed_roof',              'cottages:roof_straw'});
         table.insert( replacements, {'dryplants:reed_slab',              'cottages:roof_flat_straw' });
         table.insert( replacements, {'dryplants:wetreed_roof',           'cottages:roof_reet' });
         table.insert( replacements, {'dryplants:wetreed_slab',           'cottages:roof_flat_reet' });
      else -- replace the straw and cobble one of the huts uses
         table.insert( replacements, {'cottages:straw',                   'dryplants:wetreed' });
         table.insert( replacements, {'stairs:slab_cobble',               'dryplants:reed_slab' });
      end
      if( pr:next( 1, 4) == 1 ) then
         table.insert( replacements, {'dryplants:wetreed_roof_corner',    'default:wood' });
         table.insert( replacements, {'dryplants:wetreed_roof_corner_2',  'default:junglewood' });
      end
      if( not( minetest.get_modpath( 'cavestuff' ))) then
         table.insert( replacements, {'cavestuff:desert_pebble_2',        'default:slab_cobble' });
      end
   
      table.insert( replacements, {'default:desert_sand', 'default:dirt_with_grass' });
      return replacements;
   end


   if( housetype == 'claytrader' ) then
      -- the walls of the clay trader houses are made out of brick
      mg_villages.replace_materials( replacements, pr,
		{ 'stairs:stair_brick', 'stairs:slab_brick', 'default:brick' }, -- default_materials
		{ 'stairs:stair_',      'stairs:slab_',      'default:'      }, -- prefixes (for new materials)
		{ 'brick', 'stone', 'sandstone', 'sandstonebrick', 'desert_stone', 'desert_cobble', 'desert_stonebrick' }, -- new materials
		'brick' ); -- original material
	
      -- material for the floor
      mg_villages.replace_materials( replacements, pr,
		{'default:stone'},
		{'default:'},
		{ 'brick', 'stone', 'sandstone', 'sandstonebrick', 'clay', 'desert_stone', 'desert_cobble', 'desert_stonebrick',
		'default:stone_flat', 'default:desert_stone_flat', -- realtest
		},
		'stone');

      -- the clay trader homes come with stone stair roofs; slabs are used in other places as well (but those replacements here are ok)
      mg_villages.replace_materials( replacements, pr,
		{'stairs:stair_stone',       'stairs:slab_stone' },
		{'cottages:roof_connector_', 'cottages:roof_flat_' },
		{'straw', 'straw', 'straw', 'straw', 'straw',
			   'reet', 'reet', 'reet',
			   'slate', 'slate',
                           'wood',  'wood',  
                           'red',
                           'brown',
                           'black'},
		'');

      -- hills and pits that contain the materials clay traders dig for
      mg_villages.replace_materials( replacements, pr,
		{'default:stone_with_coal'},
		{'default:'},
		{'sand', 'sandstone', 'clay'},
		'');

      if( mg_villages.realtest_trees ) then
         local wood_type = mg_villages.replace_materials( replacements, pr,
		{'default:wood'},
		{''},
		{ 'default:wood' },
		'default:wood');
         mg_villages.replace_tree_trunk( replacements, wood_type );
         mg_villages.replace_saplings(   replacements, wood_type );
         table.insert( replacements, {'default:clay', 'default:dirt_with_clay'});
         local mfs2 = mg_villages.replace_materials( replacements, pr,
		{'stairs:stair_cobble',  'stairs:slab_cobble', 'default:cobble'},
		{'stairs:stair_',        'stairs:slab_',       'default:'      },
		{ 'stone' }, -- will be replaced by mg_villages.realtest_stairs
		'sandstone');
      end
      return replacements;
   end


   if( housetype == 'charachoal' ) then
      if( mg_villages.realtest_trees ) then
         local wood_type = mg_villages.replace_materials( replacements, pr,
		{'default:wood'},
		{''},
		{ 'default:wood' },
		'default:wood');
         mg_villages.replace_tree_trunk( replacements, wood_type );
         mg_villages.replace_saplings(   replacements, wood_type );

         table.insert( replacements, {'stairs:slab_loam',     'cottages:loam'});
         table.insert( replacements, {'stairs:stair_loam',    'cottages:loam'});
      end
      return replacements;
   end


   -- wells can get the same replacements as the sourrounding village; they'll get a fitting roof that way
   if( housetype ~= 'medieval' and housetype ~= 'well' and housetype ~= 'cottages') then
      return replacements;
   end

   if( not( minetest.get_modpath('bell' ))) then
      table.insert( replacements, {'bell:bell',               'default:goldblock' });
   end

   -- glass that served as a marker got copied accidently; there's usually no glass in cottages
   table.insert( replacements, {'default:glass',           'air'});

-- TODO: sometimes, half_door/half_door_inverted gets rotated wrong
--   table.insert( replacements, {'cottages:half_door',      'cottages:half_door_inverted'});
--   table.insert( replacements, {'cottages:half_door_inverted', 'cottages:half_door'});

   -- some poor cottage owners cannot afford glass
   if( pr:next( 1, 2 ) == 2 ) then
--      table.insert( replacements, {'cottages:glass_pane',    'default:fence_wood'});
      local gp = mg_villages.replace_materials( replacements, pr,
	{'cottages:glass_pane'},
	{''},
	{'xpanes:pane', 'default:glass', 'default:obsidian_glass', 'default:fence_wood',
	 'darkage:medieval_glass', 'darkage:iron_bars', 'darkage:iron_grille', 'darkage:wood_bars',
	 'darkage:wood_frame', 'darkage:wood_grille'},
	'cottages:glass_pane');
   end

   -- 'glass' is admittedly debatable; yet it may represent modernized old houses where only the tree-part was left standing
   -- loam and clay are mentioned multiple times because those are the most likely building materials in reality
   local materials = {'cottages:loam', 'cottages:loam', 'cottages:loam', 'cottages:loam', 'cottages:loam', 
                      'default:clay',  'default:clay',  'default:clay',  'default:clay',  'default:clay',
                      'default:wood','default:junglewood','default:sandstone',
                      'default:desert_stone','default:brick','default:cobble','default:stonebrick',
                      'default:desert_stonebrick','default:sandstonebrick','default:stone',
                      'mg:savannawood', 'mg:savannawood', 'mg:savannawood', 'mg:savannawood',
                      'mg:pinewood',    'mg:pinewood',    'mg:pinewood',    'mg:pinewood',
		'default:stone_flat', 'default:desert_stone_flat', -- realtest
		'darkage:adobe', 'darkage:basalt', 'darkage:basalt_cobble', 'darkage:chalk',
		'darkage:gneiss', 'darkage:gneiss_cobble', 'darkage:marble', 'darkage:marble_tile',
		'darkage:mud', 'darkage:ors', 'darkage:ors_cobble', 'darkage:reinforced_chalk',
		'darkage:reinforced_wood', 'darkage:reinforced_wood_left', 'darkage:reinforced_wood_right',
		'darkage:schist', 'darkage:serpentine', 'darkage:shale', 'darkage:silt', 'darkage:slate',
		'darkage:slate_cobble', 'darkage:slate_tile', 'darkage:stone_brick',
		'mapgen:mese_stone', 'mapgen:soap_stone'};

   -- what is sandstone (the floor) may be turned into something else
   local mfs = mg_villages.replace_materials( replacements, pr,
	{'default:sandstone'},
	{''},
	materials,
	'default:sandstone');
   if( mg_villages.realtest_trees ) then
       table.insert( replacements, {'stairs:slab_sandstone',   'default:stone_slab'});
       local mfs2 = mg_villages.replace_materials( replacements, pr,
		{'stairs:stair_sandstone',  'stairs:slab_sandstone', 'default:sandstone'},
		{'stairs:stair_',           'stairs:slab_',          'default:'         },
		{ 'stone' }, -- will be replaced by mg_villages.realtest_stairs
		'sandstone');
   elseif( mfs and mfs ~= 'default:sandstone' ) then

      if( mfs == 'cottages:loam' or mfs == 'default:clay' or mfs == 'mg:savannawood' or mfs == 'mg:pinewood') then
         mfs = 'default:wood';
      elseif( mfs =='default:sandstonebrick' or mfs == 'default:desert_stone' or mfs == 'default:desert_stonebrick'
              or not( minetest.registered_nodes[ 'stairs:slab_'..string.sub( mfs, 9 )] )) then
         mfs = '';
      end

      if( mfs and mfs ~= '' ) then      
         -- realtest needs special treatment
         table.insert( replacements, {'stairs:slab_sandstone',   'stairs:slab_'..string.sub( mfs, 9 )});
      end
   end
   -- except for the floor, everything else may be glass
   table.insert( materials, 'default:glass' );

   local uses_wood = false;
   -- bottom part of the house (usually ground floor from outside)
   local replace_clay = mg_villages.replace_materials( replacements, pr,
	{'default:clay'},
	{''},
	materials,
	'default:clay');
   if( replace_clay and replace_clay ~= 'default:clay' ) then
      uses_wood = mg_villages.replace_tree_trunk( replacements, replace_clay );
      mg_villages.replace_saplings(               replacements, replace_clay );
   end
 
   -- upper part of the house (may be the same as the material for the lower part)
   local replace_loam = mg_villages.replace_materials( replacements, pr,
	{'cottages:loam'},
	{''},
	materials,
	'cottages:loam');
   -- if the bottom was not replaced by wood, perhaps the top is
   if( not( uses_wood ) and replace_loam ) then
         mg_villages.replace_tree_trunk( replacements, replace_loam );
         mg_villages.replace_saplings(   replacements, replace_loam );
   elseif( mg_villages.realtest_trees ) then
      local wood_type = mg_villages.replace_materials( replacements, pr,
		{'default:wood'},
		{''},
		{ 'default:wood' },
		'default:wood');
      mg_villages.replace_tree_trunk( replacements, wood_type );
      mg_villages.replace_saplings(   replacements, wood_type );
   end


   -- replace cobble; for these nodes, a stony material is needed (used in wells as well)
   -- mossycobble is fine here as well
   local mcs = mg_villages.replace_materials( replacements, pr,
		{'default:cobble'},
		{'default:'},
		{'sandstone', 'desert_stone', 'desert_cobble',
                      'cobble',      'cobble',
                      'stonebrick',  'stonebrick', 'stonebrick', -- more common than other materials
                      'mossycobble', 'mossycobble','mossycobble',
                      'stone',       'stone',
                      'desert_stonebrick','sandstonebrick'},
		'cobble');
   -- set a fitting material for the slabs; mossycobble uses the default cobble slabs
   if( mg_villages.realtest_trees ) then
      local mcs2 = mg_villages.replace_materials( replacements, pr,
		{'stairs:stair_cobble',  'stairs:slab_cobble', 'default:cobble'},
		{'stairs:stair_',        'stairs:slab_',       'default:'          },
		{ 'stone' }, -- will be replaced by mg_villages.realtest_stairs
		'cobble');
      table.insert( replacements, {'moreblocks:slab_cobble',   'default:'..mcs..'_slab'});
   elseif( mcs ~= 'mossycobble' and mcs ~= 'cobble') then

      -- if no slab exists, use sandstone slabs
      if( not( mcs ) or not( minetest.registered_nodes[ 'stairs:slab_'..mcs ])) then
         mcs = 'sandstone';
      end
      table.insert( replacements, {'stairs:slab_cobble',      'stairs:slab_'..mcs});
   end
 

   -- straw is the most likely building material for roofs for historical buildings
   mg_villages.replace_materials( replacements, pr,
		-- all three shapes of roof parts have to fit together
		{ 'cottages:roof_straw',    'cottages:roof_connector_straw',   'cottages:roof_flat_straw' },
		{ 'cottages:roof_',         'cottages:roof_connector_',        'cottages:roof_flat_'},
		{'straw', 'straw', 'straw', 'straw', 'straw',
			   'reet', 'reet', 'reet',
			   'slate', 'slate',
                           'wood',  'wood',  
                           'red',
                           'brown',
                           'black'},
		'straw');

--print('REPLACEMENTS used: '..minetest.serialize( replacements )); 
   return replacements;
end


-- Translate replacement function from above (which aims at place_schematic) for the villages in Nores mapgen
mg_villages.get_replacement_ids = function( housetype, pr )

	local replace = {};
	local replacements = mg_villages.get_replacement_list( housetype, pr );
	for i,v in ipairs( replacements ) do
		if( v and #v == 2 ) then
			replace[ minetest.get_content_id( v[1] )] = minetest.get_content_id( v[2] );
		end
	end
	return replace;
end



-- mapgen based replacements work best using a table, while minetest.place_schematic(..) based spawning needs a list
mg_villages.get_replacement_table = function( housetype, pr, replacements )

	local rtable = {};
	local ids    = {};
	if( not( replacements )) then
		replacements = mg_villages.get_replacement_list( housetype, pr );
	end
	-- it is very problematic if the torches on houses melt snow and cause flooding; thus, we use a torch that is not hot
	table.insert( replacements, {'default:torch', 'mg_villages:torch'});
	for i,v in ipairs( replacements ) do
		if( v and #v == 2 ) then
			rtable[ v[1] ] = v[2];
			ids[ minetest.get_content_id( v[1] )] = minetest.get_content_id( v[2] );
		end
	end
        return { table = rtable, list = replacements, ids = ids };
end

mg_villages.get_content_id_replaced = function( node_name, replacements )
	if( not( node_name ) or not( replacements ) or not(replacements.table )) then
		return minetest.get_content_id( 'ignore' );
	end
	if( replacements.table[ node_name ]) then
		return minetest.get_content_id( replacements.table[ node_name ] );
	else
		return minetest.get_content_id( node_name );
	end
end

