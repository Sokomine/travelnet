
-- punching the travelnet updates its formspec and shows it to the player;
-- however, that would be very annoying when actually trying to dig the thing.
-- Thus, check if the player is wielding a tool that can dig nodes of the
-- group cracky
travelnet.check_if_trying_to_dig = function( puncher, node )
	-- if in doubt: show formspec
	if( not( puncher) or not( puncher:get_wielded_item())) then
		return false;
	end
	-- show menu when in creative mode
        if(   creative
	  and creative.is_enabled_for(puncher:get_player_name())
--          and (not(puncher:get_wielded_item())
--                or puncher:get_wielded_item():get_name()~="default:pick_diamond")) then
		) then
		return false;
	end
	local tool_capabilities = puncher:get_wielded_item():get_tool_capabilities();
	if( not( tool_capabilities )
	 or not( tool_capabilities["groupcaps"])
	 or not( tool_capabilities["groupcaps"]["cracky"])) then
		return false;
	end
	-- tools which can dig cracky items can start digging immediately
	return true;
end
