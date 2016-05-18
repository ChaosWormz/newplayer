newplayer = {}

newplayer.keyword = minetest.setting_get("interact_keyword")
if newplayer.keyword == "" then newplayer.keyword = nil end

newplayer.hudids = {}

local f = io.open(minetest.get_worldpath()..DIR_DELIM.."newplayer-rules.txt","r")
if f then
	local d = f:read("*all")
	newplayer.rules = minetest.formspec_escape(d)
	f:close()
else
	newplayer.rules = "Rules file not found!\n\nThe file should be named \"newplayer-rules.txt\" and placed in the following location:\n\n"..minetest.get_worldpath()..DIR_DELIM
end

function newplayer.showrulesform(name)
	if newplayer.keyword then
		newplayer.rules_subbed = string.gsub(newplayer.rules,"@KEYWORD",newplayer.keyword)
	else
		newplayer.rules_subbed = newplayer.rules
	end
	local form_interact = "size[8,10]"..
				"label[0,0;Server Rules]"..
				"textarea[0.25,1;8,7;rules;;"..newplayer.rules.."]"
	local form_nointeract = "size[8,10]"..
				"label[0,0;Server Rules]"..
				"textarea[0.25,1;8,7;rules;;"..newplayer.rules_subbed.."]"..
				"button[1,9;2,1;yes;I agree]"..
				"button[5,9;2,1;no;I do not agree]"
	if newplayer.keyword then
		form_nointeract = form_nointeract.."field[0.25,8;8,1;keyword;Enter keyword from rules above:;]"
	end
	local hasinteract = minetest.check_player_privs(name,{interact=true})
	if hasinteract then
		if minetest.check_player_privs(name,{server=true}) then
			form_interact = form_interact.."button_exit[1,9;2,1;quit;OK]"
			form_interact = form_interact.."button[5,9;2,1;edit;Edit]"
			form_interact = form_interact.."field[0.25,8;8,1;keyword;Keyword:;"..(newplayer.keyword or "").."]"
		else
			form_interact = form_interact.."button_exit[3,9;2,1;quit;OK]"
		end
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
	minetest.after(0,newplayer.showrulesform,name)
end)

minetest.register_on_player_receive_fields(function(player,formname,fields)
	local name = player:get_player_name()
	if formname == "newplayer:rules_nointeract" then
		if fields.quit then
			newplayer.showrulesform(name)
		elseif fields.yes then
			if not newplayer.keyword or string.lower(fields.keyword) == string.lower(newplayer.keyword) then
				local privs = minetest.get_player_privs(name)
				privs.interact = true
				minetest.set_player_privs(name,privs)
				if newplayer.hudids[name] then
					minetest.get_player_by_name(name):hud_remove(newplayer.hudids[name])
					minetest.get_player_by_name(name):hud_remove(newplayer.hudids[name]-1)
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
			else
				local form =    "size[5,3]"..
						"label[1,0;Incorrect keyword!]"..
						"button[1.5,2;2,1;quit;Try Again]"
				minetest.show_formspec(name,"newplayer:tryagain",form)
			end
		elseif fields.no then
			local form =    "size[5,3]"..
					"label[1,0;You may remain on the server,]"..
					"label[1,0.5;but you may not dig or build]"..
					"label[1,1;until you agree to the rules.]"..
					"button_exit[1.5,2;2,1;quit;OK]"
			minetest.show_formspec(name,"newplayer:disagreewarning",form)
		end
		return true
	elseif formname == "newplayer:tryagain" then
		newplayer.showrulesform(name)
		return true
	elseif formname == "newplayer:editrules" then
		if minetest.check_player_privs(name, {server=true}) then
			if fields.save then
				local f = io.open(minetest.get_worldpath()..DIR_DELIM.."newplayer-rules.txt","w")
				f:write(fields.rules)
				f:close()
				newplayer.rules = fields.rules
				if fields.keyword ~= "" then
					newplayer.keyword = fields.keyword
					minetest.setting_set("interact_keyword",fields.keyword)
					minetest.setting_save()
				else
					newplayer.keyword = nil
					minetest.setting_set("interact_keyword","")
					minetest.setting_save()
				end
				minetest.chat_send_player(name,"Rules/keyword updated successfully.")
			end
		else
			minetest.chat_send_player(name,"You hacker you... nice try!")
		end
	elseif formname == "newplayer:rules_interact" then
		if fields.edit and minetest.check_player_privs(name,{server=true}) then
			local form =    "size[8,10]"..
					"label[0,0;Editing Server Rules]"..
					"textarea[0.25,1;8,7;rules;;"..newplayer.rules.."]"..
					"button_exit[1,9;2,1;save;Save]"..
					"button_exit[5,9;2,1;quit;Cancel]"..
					"field[0.25,8;8,1;keyword;Keyword:;"..(newplayer.keyword or "").."]"
			minetest.show_formspec(name,"newplayer:editrules",form)
		end
	elseif formname == "newplayer:agreethanks" or formname == "newplayer:disagreewarning" then
		return true
	else
		return false
	end
end)

minetest.register_chatcommand("rules",{
	params = "",
	description = "View the rules",
	func = newplayer.showrulesform
	}
)

minetest.register_chatcommand("editrules",{
	params = "",
	description = "Edit the rules",
	privs = {server=true},
	func = function(name)
		local form =    "size[8,10]"..
				"label[0,0;Editing Server Rules]"..
				"textarea[0.25,1;8,7;rules;;"..newplayer.rules.."]"..
				"button_exit[1,9;2,1;save;Save]"..
				"button_exit[5,9;2,1;quit;Cancel]"..
				"field[0.25,8;8,1;keyword;Keyword:;"..(newplayer.keyword or "").."]"
		minetest.show_formspec(name,"newplayer:editrules",form)
		return true
	end}
)

minetest.register_chatcommand("set_no_interact_spawn",{
	params = "",
	description = "Set the spawn point for players without interact to your current position",
	privs = {server=true},
	func = function(name)
		local pos = minetest.get_player_by_name(name):getpos()
		minetest.setting_set("spawnpoint_no_interact",string.format("%s,%s,%s",pos.x,pos.y,pos.z))
		minetest.setting_save()
		return true, "Spawn point for players without interact set to: "..minetest.pos_to_string(pos)
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
		return true, "Spawn point for players with interact set to: "..minetest.pos_to_string(pos)
	end}
)

minetest.register_chatcommand("set_keyword",{
	params = "[keyword]",
	description = "Set the keyword used to get interact",
	privs = {server=true},
	func = function(name,param)
		if param and param ~= "" then
			newplayer.keyword = param
			minetest.setting_set("interact_keyword",param)
			minetest.setting_save()
			return true, "Keyword set to: "..param
		else
			newplayer.keyword = nil
			minetest.setting_set("interact_keyword","")
			minetest.setting_save()
			return true, "Keyword cleared."
		end
	end}
)

minetest.register_chatcommand("get_keyword",{
	params = "",
	description = "Shows the keyword used to get interact",
	privs = {server=true},
	func = function(name)
		local kw = newplayer.keyword
		if kw then
			return true, "Keyword is: "..kw
		else
			return true, "No keyword is currently set."
		end
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
				player:setpos(pos)
				return true, "Teleporting to spawn..."
			else
				return true, "ERROR: The spawn point is not set!"
			end
		else
			local pos = minetest.setting_get_pos("spawnpoint_no_interact")
			if pos then
				player:setpos(pos)
				return true, "Teleporting to spawn..."
			else
				return true, "ERROR: The spawn point is not set!"
			end
		end
	end}
)
