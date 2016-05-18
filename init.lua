newplayer = {}

newplayer.hudids = {}

local f = io.open(minetest.get_modpath("newplayer")..DIR_DELIM.."rules.txt","r")
if f then
	local d = f:read("*all")
	newplayer.rules = minetest.formspec_escape(d)
	f:close()
else
	newplayer.rules = "Rules file not found!\n\nThe file should be named \"rules.txt\" and placed in the following location:\n\n"..minetest.get_modpath("newplayer")..DIR_DELIM
end

function newplayer.showrulesform(name)
	local form_interact = "size[8,9]"..
				"label[0,0;Server Rules]"..
				"textarea[0.25,1;8,7;rules;;"..newplayer.rules.."]"..
				"button_exit[3,8;2,1;quit;OK]"
	local form_nointeract = "size[8,9]"..
				"label[0,0;Server Rules]"..
				"textarea[0.25,1;8,7;rules;;"..newplayer.rules.."]"..
				"button[1,8;2,1;yes;I agree]"..
				"button[5,8;2,1;no;I do not agree]"
	local hasinteract = minetest.check_player_privs(name,{interact=true})
	if hasinteract then
		minetest.show_formspec(name,"newplayer:rules_interact",form_interact)
	else
		minetest.show_formspec(name,"newplayer:rules_nointeract",form_nointeract)
	end
end

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	if minetest.check_player_privs(name,{interact=true}) then
		return
	end
	local nointeractspawn = minetest.setting_get_pos("spawnpoint_no_interact")
	if nointeractspawn then
		player:setpos(nointeractspawn)
	end
	newplayer.hudids[name] = player:hud_add({
		hud_elem_type = "text",
		position = {x=0.5,y=0.5},
		scale = {x=100,y=100},
		text = "BUILDING DISABLED\nYou must agree to\nthe rules before building!\nUse the /rules command\nto see them.",
		number = 0xFF6666,
		alignment = {x=0,y=0},
		offset = {x=0,y=0}
	})
	minetest.after(3,newplayer.showrulesform,name)
end)

minetest.register_on_player_receive_fields(function(player,formname,fields)
	if formname ~= "newplayer:rules_nointeract" then
		return false
	end
	local name = player:get_player_name()
	if fields.quit then
		newplayer.showrulesform(name)
	elseif fields.yes then
		local privs = minetest.get_player_privs(name)
		privs.interact = true
		minetest.set_player_privs(name,privs)
		if newplayer.hudids[name] then
			minetest.get_player_by_name(name):hud_remove(newplayer.hudids[name])
			newplayer.hudids[name] = nil
		end
		local spawn = minetest.setting_get_pos("spawnpoint_interact")
		if spawn then
			minetest.chat_send_player(name,"Teleporting to spawn...")
			player:setpos(spawn)
		else
			minetest.chat_send_player(name,"ERROR: The spawn point is not set!")
		end
		local form =    "size[5,3]"..
				"label[1,0;Thank you for agreeing]"..
				"label[1,0.5;to the rules!]"..
				"label[1,1;You are now free to play normally.]"..
				"label[1,1.5;You can also use /spawn to return here.]"..
				"button_exit[1.5,2;2,1;quit;OK]"
		minetest.show_formspec(name,"newplayer:agreethanks",form)
	elseif fields.no then
		local form =    "size[5,3]"..
				"label[1,0;You may remain on the server\,]"..
				"label[1,0.5;but you may not dig or build]"..
				"label[1,1;until you agree to the rules.]"..
				"button_exit[1.5,2;2,1;quit;OK]"
		minetest.show_formspec(name,"newplayer:disagreewarning",form)
	end
	return true
end)

minetest.register_chatcommand("rules",{
	params = "",
	description = "View the rules",
	func = newplayer.showrulesform
	}
)

minetest.register_chatcommand("set_no_interact_spawn",{
	params = "",
	description = "Set the spawn point for players without interact to your current position",
	privs = {server=true},
	func = function(name)
		local pos = minetest.get_player_by_name(name):getpos()
		minetest.setting_set("spawnpoint_no_interact",string.format("%s,%s,%s",pos.x,pos.y,pos.z))
		minetest.setting_save()
		minetest.chat_send_player(name,"Spawn point for players without interact set to: "..minetest.pos_to_string(pos))
	end}
)

minetest.register_chatcommand("set_interact_spawn",{
	params = "",
	description = "Set the spawn point for players with interact to your current position",
	privs = {server=true},
	func = function(name)
		local pos = minetest.get_player_by_name(name):getpos()
		minetest.setting_set("spawnpoint_interact",string.format("%s,%s,%s",pos.x,pos.y,pos.z))
		minetest.setting_save()
		minetest.chat_send_player(name,"Spawn point for players with interact set to: "..minetest.pos_to_string(pos))
	end}
)

minetest.register_chatcommand("spawn",{
	params = "",
	description = "Teleport to the spawn",
	func = function(name)
		local hasinteract = minetest.check_player_privs(name,{interact=true})
		local player = minetest.get_player_by_name(name)
		if hasinteract then
			local pos = minetest.setting_get_pos("spawnpoint_interact")
			if pos then
				minetest.chat_send_player(name,"Teleporting to spawn...")
				player:setpos(pos)
			else
				minetest.chat_send_player(name,"ERROR: The spawn point is not set!")
			end
		else
			local pos = minetest.setting_get_pos("spawnpoint_no_interact")
			if pos then
				minetest.chat_send_player(name,"Teleporting to spawn...")
				player:setpos(pos)
			else
				minetest.chat_send_player(name,"ERROR: The spawn point is not set!")
			end
		end
	end}
)
