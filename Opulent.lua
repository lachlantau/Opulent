-- Format: library variable name = { library requisite name, library workshop url }
local libraries = {
    http = { "http", "https://gamesense.pub/forums/viewtopic.php?id=28678" },
    images = { "images", "https://gamesense.pub/forums/viewtopic.php?id=22917" },
    clipboard = { "clipboard", "https://gamesense.pub/forums/viewtopic.php?id=28678" },
    base64 = { "base64", "https://gamesense.pub/forums/viewtopic.php?id=21619" }
}

-- Hold all of our core variables and functions.
local opulent = {
    -- Our logo data.
    logo = nil,
    -- Our script's tabs.
    tabs = { "Anti-aim", "Builder", "Visuals", "Misc", "Config" },
    -- The user's name, default to admin.
    username = "admin",
    -- The user's version, default to development.
    version = "development",
    -- Our table that will convert the loader api's version names to our desired names.
    version_names = {
        [ "User" ] = "Live",
        [ "Beta" ] = "Beta",
        [ "Debug" ] = "Nightly"
    },
    -- Create a table that will hold all of our visibility dependent menu items.
    dependent_items = { },
    -- Create another table that will hold menu item names and their respective descriptions.
    item_descriptions = { }
}

-- Our standalone menu item creation function, this allows us to easily automate everything.
-- Format: "new_item( ui.desired_item_type, 'item name', 'item descriptions', item conditions, regular arguments )"
-- Conditions format: "{ { item's object name, item's conditional value }, repeat as needed }"
function opulent.new_item( o_function, name, description, visibility_conditions, ... )
    -- Create the menu item as regular with the provided function ( o_function ) and arguments ( ... ).
    local item = o_function( "LUA", "B", name, ... )

    -- Have we provided a description for this item?
    if description ~= nil then
        -- Add this item to the description array with the respective text.
        opulent.item_descriptions[ name ] = description
    end

    -- Have we provided any visibility conditions?
    if visibility_conditions ~= nil then
        -- Same as above, add this to our list of visibility dependent menu items.
        opulent.dependent_items[ item ] = visibility_conditions
    end

    -- Finally, return the normal menu item.
    return item
end

function opulent.print( ... )
    -- Print the base of the lua named followed by \0 so that we can keep the next print on the same line.
    client.color_log( 255, 180, 220, "opulent \0" )
    -- Print " ~ " to break off from the opulent text followed by the rest of the text ( ... ).
    client.color_log( 255, 255, 255, "~ ", ... )
end

-- Convert an rgb color to hex code.
function opulent.rgb_to_hex( r, g, b, a )
    return string.format( "%02x%02x%02x%02x", r or 255, g or 255, b or 255, a or 255 )
end

-- Convert text to a fading dark gradient.
function opulent.fade_text( r, g, b, text )
    -- Create a string to hold our new gradient text.
    local new_text = ""
    -- Create a for loop for the length of our desired text.
    for i=1, text:len( ) do
        -- Do the math to get the gradient ( I have no idea what this is, but it won't impact fps ).
        local color = { r, g, b, 255 * math.abs( 1 * math.cos( 2 * math.pi * globals.curtime( ) / 4 + i * 5 / 30) ) }
        -- Now, convert our gradient to hex.
        color = opulent.rgb_to_hex( table.unpack( color ) )

        -- Finally, call string.format with our previous text, the new color and the new character.
        new_text = string.format( "%s\a%s%s", new_text, color, text:sub( i, i ) )
    end
    -- Return our new gradient text.
    return new_text
end

-- Convert time to in-game ticks.
local function time_to_ticks( t )
    return math.floor( 0.5 + ( t / globals.tickinterval( ) ) )
end

-- Convert in-game ticks to time.
local function ticks_to_time( t )
    return globals.tickinterval( ) * t
end

-- Return a vector of the second vector subtracted by the first.
local function vector_diff( vector_1, vector_2 )
    local new_vector = { }
    for i=1, #vector_1 do
        new_vector[ i ] = vector_1[ i ] - vector_2[ i ]
    end
    return new_vector
end

-- Get the length of a 3d vector.
local function length( position )
    return math.abs( position[ 1 ] ) + math.abs( position[ 2 ] ) + math.abs( position[ 3 ] )
end

-- Check if a multiselect contains the given value.
local function in_multi_select( multi_select, value )
    -- Grab the table of selected contents in the multiselect.
    local selected_contents = ui.get( multi_select )

    -- Iterate over the contents
    for i=1, #selected_contents do
        -- Does this value match our desired value?
        if selected_contents[ i ] == value then
            -- Return true, value found.
            return true
        end
    end

    -- No value found, return false.
    return false
end

-- Create a table to hold all of our anti-aim related variables and functions.
local anti_aim = {
    -- Our anti-aim states.
    states = { "Default", "Standing", "Moving", "Ducking", "In air", "Air duck", "High ground", "Low ground", "Slow motion" },
    -- Our current state.
    state = 1,
    -- The last time we were in the air.
    last_in_air = 0,
    -- The minimum value for twist.
    minimum_twist = 15,
    -- The maximum value for twist.
    maximum_twist = 90,
    -- How often (in ticks) we want our twist body yaw value to invert.
    twist_interval = 16,
    -- The minimum value for jitter.
    minimum_jitter = 1,
    -- The maximum value for jitter.
    maximum_jitter = 120,
    -- The minimum speed at which hybrid will invert our body yaw (in ticks).
    minimum_hybrid_speed = 10,
    -- Same as above, except the maximum.
    maximum_hybrid_speed = 32,
    -- Our last valid tickbase, used for immunity.
    last_tickbase = 0,
    -- Are we currently immune?
    in_immunity = false,
    -- Last time we forced defensive.
    last_force_defensive = 0,
    -- List of our previous latencies.
    latency_list = { },
    -- Our current manual anti-aim side.
    manual_side = "back",
    -- Has the user already set a manual side?
    manual_set = { [ "right" ] = false, [ "left" ] = false, [ "forward" ] = false },
    -- Where we want our head to be for each manual position.
    manual_yaw = { [ "right" ] = 90, [ "left" ] = -90, [ "forward" ] = 180, [ "back" ] = 0 },
    -- Can we currently be backstabbed?
    backstab = false
}

-- Save our panorama access to a variable so we don't have to constantly re-access it
local js = panorama.open( )

-- Create a variable that will hold our items, we define this before the items themselves otherwise
-- we wouldn't be able to access other items for the visibility checks.
local items = { }
items.master_switch = opulent.new_item( ui.new_checkbox, "\n" )
items.master_switch_label = opulent.new_item( ui.new_label, "opulent" )
items.current_tab = opulent.new_item( ui.new_combobox, "Current tab", nil, nil, table.unpack( opulent.tabs ) )

-- Initialize all of our tabs by creating them as empty arrays.
for i=1, #opulent.tabs do
    items[ opulent.tabs[ i ] ] = { }
end

items[ "Anti-aim" ].enabled = opulent.new_item( ui.new_checkbox, "\aCCC767FFEnabled" )
items[ "Anti-aim" ].options = opulent.new_item( ui.new_multiselect, "Adjustments", nil, { { items[ "Anti-aim" ].enabled, true } }, "Anti-aim on use", "Static on manual", "Static on freestand", "Edge yaw", "Roll" )
items[ "Anti-aim" ].immunity_flick = opulent.new_item( ui.new_checkbox, "Immunity flick", "when immune, meaning you cannot be hit on the server, you will get an up pitch anti-aim that may make players mispredict; no downside", { { items[ "Anti-aim" ].enabled, true } } )
items[ "Anti-aim" ].anti_backstab = opulent.new_item( ui.new_checkbox, "Anti-backstab", "will disable your anti-aim when an enemy is within your set radius and holding a knife", { { items[ "Anti-aim" ].enabled, true } } )
items[ "Anti-aim" ].anti_backstab_range = opulent.new_item( ui.new_slider, "Backstab radius", "the minimum distance an enemy has to be before your anti-aim disables", { { items[ "Anti-aim" ].enabled, true }, { items[ "Anti-aim" ].anti_backstab, true } }, 1, 300, 150, true, "u" )
items[ "Anti-aim" ].freestanding = opulent.new_item( ui.new_checkbox, "Freestanding", "standalone freestanding, allows you to enable/disable it on certain state conditions", { { items[ "Anti-aim" ].enabled, true } } )
items[ "Anti-aim" ].freestand_key = opulent.new_item( ui.new_hotkey, "Freestanding key", nil, { { items[ "Anti-aim" ].enabled, true }, { items[ "Anti-aim" ].freestanding, true } }, true )
items[ "Anti-aim" ].manual_anti_aim = opulent.new_item( ui.new_checkbox, "Manual anti-aim", "allows you to dictate where your head will be with keybinds (left, right and back)", { { items[ "Anti-aim" ].enabled, true } } )
items[ "Anti-aim" ].manual_left = opulent.new_item( ui.new_hotkey, "Left side key", nil, { { items[ "Anti-aim" ].enabled, true }, { items[ "Anti-aim" ].manual_anti_aim, true } } )
items[ "Anti-aim" ].manual_right = opulent.new_item( ui.new_hotkey, "Right side key", nil, { { items[ "Anti-aim" ].enabled, true }, { items[ "Anti-aim" ].manual_anti_aim, true } } )
items[ "Anti-aim" ].manual_back = opulent.new_item( ui.new_hotkey, "Backwards key", nil, { { items[ "Anti-aim" ].enabled, true }, { items[ "Anti-aim" ].manual_anti_aim, true } } )
items[ "Anti-aim" ].manual_forward = opulent.new_item( ui.new_hotkey, "Forwards key", nil, { { items[ "Anti-aim" ].enabled, true }, { items[ "Anti-aim" ].manual_anti_aim, true } } )

items[ "Visuals" ].indicators = opulent.new_item( ui.new_checkbox, "Indicators", "will place indicators at your crosshair" )
items[ "Visuals" ].indicator_list = opulent.new_item( ui.new_multiselect, "Indicator item list", "the items that will be displayed below your crosshair", { { items[ "Visuals" ].indicators, true } }, "Double tap", "Hide shots", "Manual", "Freestanding", "Damage override" )
items[ "Visuals" ].indicator_offset = opulent.new_item( ui.new_slider, "Indicator offset", "how far, on the Y axis, your indicators will be from your crosshair", { { items[ "Visuals" ].indicators, true } }, -150, 150, 0, true, "px" )
items[ "Misc" ].clan_tag = opulent.new_item( ui.new_checkbox, "Clan tag" )
items[ "Misc" ].animation_breaker = opulent.new_item( ui.new_checkbox, "Animation breaker", "gives you unique looking animations, offers no real benefit" )
items[ "Misc" ].animation_modifications = opulent.new_item( ui.new_multiselect, "Animation modifications", nil, { { items[ "Misc" ].animation_breaker, true } }, "Remove falling animation", "Reverse running legs" )
items[ "Misc" ].insult_on_kill = opulent.new_item( ui.new_checkbox, "Insult on kill", "synonymous with killsay, says something in chat after killing a player" )
items[ "Misc" ].insult_on_kill_type = opulent.new_item( ui.new_combobox, "Insult type", "as the names suggest, generic will give 1 automatic message after death whereas responsive will give responses to the player as they type", { { items[ "Misc" ].insult_on_kill, true } }, "Off", "Generic", "Responsive" )
items[ "Misc" ].fast_ladder = opulent.new_item( ui.new_checkbox, "Fast ladder", "will make you move across ladders faster, ascending for upwards and descending for downwards", nil )
items[ "Misc" ].fast_ladder_type = opulent.new_item( ui.new_multiselect, "Fast ladder type", nil, { { items[ "Misc" ].fast_ladder, true } }, "Ascending", "Descending" )

items[ "Builder" ].warning_label = opulent.new_item( ui.new_label, "\aCCC767FFPlease enable anti-aim for access", nil, { { items[ "Anti-aim" ].enabled, false } } )
items[ "Builder" ].state = opulent.new_item( ui.new_combobox, "State", "select which state you want to modify the settings of", { { items[ "Anti-aim" ].enabled, true } }, table.unpack( anti_aim.states ) )

-- Iterate over our anti-aim states.
for i=1, #anti_aim.states do
    -- Create an array within the builder array for this state.
    items[ "Builder" ][ anti_aim.states[ i ] ] = { }

    local current_state = items[ "Builder" ][ anti_aim.states[ i ] ]

    -- Now, create our items like normal within this array.
    current_state.yaw_base = opulent.new_item( ui.new_combobox, "Yaw base", "dictates which yaw base your anti-aim will use, universal", nil, "Local view", "At targets" )
    current_state.type = opulent.new_item( ui.new_combobox, "Anti-aim type", "\nstatic: provides a generic static anti-aim\njitter: switches between 2 values like a typical jitter, but with special customization\ntwist: uses skitter to abuse lack of eye angle lag compensation, will also flick body yaw at optimal times to prevent resolving", nil, "Static", "Jitter", "Twist" )
    current_state.twist_strength = opulent.new_item( ui.new_slider, "Twist strength", "dictates how wide your twist anti-aim will jitter", { { current_state.type, "Twist" } }, 1, 100, 0, true, "%" )
    current_state.jitter_strength = opulent.new_item( ui.new_slider, "Jitter strength", "dictates how wide your jitter is", { { current_state.type, "Jitter" } }, 1, 100, 0, true, "%" )
    current_state.jitter_position = opulent.new_item( ui.new_combobox, "Jitter position", "dictates where your real head position is, your fake retains the same position\n\ninwards: your body yaw will be negative and your head will flick inwards\noutwards: the opposite of inwards, your body yaw will be positive and you will peek out\nhybrid: uses both types in an attempt to prevent body yaw logging", { { current_state.type, "Jitter" } }, "Inwards", "Outwards", "Hybrid" )
    current_state.hybrid_speed = opulent.new_item( ui.new_slider, "Hybrid invert delay", "dictates how often hybrid will invert your real head position", { { current_state.type, "Jitter" }, { current_state.jitter_position, "Hybrid" } }, 1, 100, 0, true, "%" )
    current_state.yaw_additive = opulent.new_item( ui.new_slider, "Yaw additive", "dictates the base position of your head for the rest of your anti-aim", nil, -35, 35, 0, true, "°" )
    current_state.force_immunity = opulent.new_item( ui.new_checkbox, "Force immunity on " .. anti_aim.states[ i ]:lower( ), "this will force immunity to be on as soon as possible, this gives us inaccurate clientside data so it will also disable immunity flick on this condition" )
    current_state.disable_freestanding = opulent.new_item( ui.new_checkbox, "Disable freestanding", "will disable freestanding whenever this state is active", { { items[ "Anti-aim" ].freestanding, true } } )
    current_state.enabled = opulent.new_item( ui.new_checkbox, "Enable " .. anti_aim.states[ i ]:lower( ) .. " state" )
end

-- Our menu item references.
local references = {
    min_damage = ui.reference( "RAGE", "Aimbot", "Minimum damage" ),
    min_damage_override = { ui.reference( "RAGE", "Aimbot", "Minimum damage override" ) },
    double_tap = { ui.reference( "RAGE", "Aimbot", "Double tap" ) },
    quick_peek = { ui.reference( "RAGE", "Other", "Quick peek assist" ) },
    fake_duck = ui.reference( "RAGE", "Other", "Duck peek assist" ),
    anti_aim = ui.reference( "AA", "Anti-aimbot angles", "Enabled" ),
    pitch = { ui.reference( "AA", "Anti-aimbot angles", "Pitch" ) },
    yaw_base = ui.reference( "AA", "Anti-aimbot angles", "Yaw base" ),
    yaw = { ui.reference( "AA", "Anti-aimbot angles", "Yaw" ) },
    yaw_jitter = { ui.reference( "AA", "Anti-aimbot angles", "Yaw jitter" ) },
    body_yaw = { ui.reference( "AA", "Anti-aimbot angles", "Body yaw" ) },
    freestanding_body_yaw = ui.reference( "AA", "Anti-aimbot angles", "Freestanding body yaw" ),
    edge_yaw = ui.reference( "AA", "Anti-aimbot angles", "Edge yaw" ),
    freestanding = { ui.reference( "AA", "Anti-aimbot angles", "Freestanding" ) },
    roll = ui.reference( "AA", "Anti-aimbot angles", "Roll" ),
    fake_lag = { ui.reference( "AA", "Fake lag", "Enabled" ) },
    fake_lag_amount = ui.reference( "AA", "Fake lag", "Amount" ),
    fake_lag_variance = ui.reference( "AA", "Fake lag", "Variance" ),
    fake_lag_limit = ui.reference( "AA", "Fake lag", "Limit" ),
    leg_movement = ui.reference( "AA", "Other", "Leg movement" ),
    slow_motion = { ui.reference( "AA", "Other", "Slow motion" ) },
    on_shot = { ui.reference( "AA", "Other", "On shot anti-aim" ) },
    player_list = ui.reference( "PLAYERS", "Players", "Player list" )
}

function anti_aim.handle_states( )
    if not ui.get( items[ "Anti-aim" ].enabled ) then
        return
    end

    -- Grab our local player for repeated usage.
    local local_player = entity.get_local_player( )
    -- Grab our current target.
    local target = client.current_threat( )

    -- Grab our velocity then calculate speed.
    local velocity = { entity.get_prop( local_player, "m_vecVelocity" ) }
    local speed = math.sqrt( velocity[ 1 ] ^ 2 + velocity[ 2 ] ^ 2 )

    -- Use bit.band to find out whether or not we're in the air.
    local in_air = bit.band( entity.get_prop( local_player, "m_fFlags" ), 1 ) == 0

    -- We're in the air, let the lua know when this happened.
    if in_air then
        anti_aim.last_in_air = globals.tickcount( )
    end

    -- Have we been in the air within the last 4 ticks? If so, set our anti-aim to landing.
    local landing = not in_air and globals.tickcount( ) - anti_aim.last_in_air < 4

    -- Grab our duck amount.
    local duck_amount = entity.get_prop( local_player, "m_flDuckAmount" )
    
    -- Create our z and xy difference variables in the setting scope.
    local enemy_z_difference = 0
    local enemy_xy_difference = 0

    if target ~= nil then
        -- Grab both the target and our own origin's within an array.
        local local_origin = { entity.get_origin( local_player ) }
        local target_origin = { entity.get_origin( target ) }

        -- Calculate the z difference by subtracting the local z axis from the target's.
        enemy_z_difference = local_origin[ 3 ] - target_origin[ 3 ]
        -- Calculate our xy difference by adding both absolute values to each other.
        enemy_xy_difference = math.abs( local_origin[ 1 ] - target_origin[ 1 ] ) + math.abs( local_origin[ 2 ] - target_origin[ 2 ] )
    end

    -- Our conditions. The numbers go in the order of the states found in anti_aim.states.
    local conditions = {
        [ 1 ] = true, -- Default
        [ 2 ] = speed <= 1.1, -- Standing
        [ 3 ] = speed > 1.1, -- Moving
        [ 4 ] = duck_amount > 0 or ui.get( references.fake_duck ), -- Ducking
        [ 5 ] = in_air or landing, -- In air
        [ 6 ] = duck_amount > 0 and in_air, -- Air duck
        [ 7 ] = enemy_z_difference > 64 and enemy_xy_difference < 800, -- High ground
        [ 8 ] = enemy_z_difference < -64 and enemy_xy_difference < 800, -- Low ground
        [ 9 ] = ui.get( references.slow_motion[ 2 ] ) -- Slow motion
    }

    -- Iterate over the conditions
    for i=1, #conditions do
        -- Have we enabled this state and is the condition true?
        if ui.get( items[ "Builder" ][ anti_aim.states[ i ] ].enabled ) and conditions[ i ] then
            -- Finally, set our state to the most recent one.
            anti_aim.state = i
        end
    end
end

function anti_aim.immunity_detection( )
    -- Reset our immunity variable before running anything else.
    anti_aim.in_immunity = false

    if not ui.get( items[ "Anti-aim" ].enabled ) then
        return
    end

    -- Return if we aren't using doubletap, clientside our tickbase prop is messed up a lot with gamesense.
    if not ui.get( references.double_tap[ 1 ] ) or not ui.get( references.double_tap[ 2 ] ) or ui.get( references.fake_duck ) then
        return
    end

    -- Forcing defensive gives us an extremely unaccurate tickbase and it breaks detection, so return if it was forced.
    if globals.curtime( ) - anti_aim.last_force_defensive < 0.3 then
        return
    end

    -- Grab our tickbase.
    local tickbase = entity.get_prop( entity.get_local_player( ), "m_nTickBase" )

    -- Occasionally our tickbase will be null, so just run a sanity check here before we perform arithmetic
    if tickbase ~= nil then
        tickbase = tickbase - 1
    else
        -- Null tickbase, return.
        return
    end

    -- Add our current latency to our latency list (convert the time to ticks since that's what we're using here).
    anti_aim.latency_list[ #anti_aim.latency_list + 1 ] = time_to_ticks( client.latency( ) )

    -- While our latency list has more than 128 members, remove the oldest one.
    while #anti_aim.latency_list > 128 do
        table.remove( anti_aim.latency_list, 1 )
    end

    -- Create a variable to hold our highest latency.
    local highest_latency = 0

    -- Iterate over our latency list.
    for i=1, #anti_aim.latency_list do
        -- Is this latency higher than our saved highest latency?
        if anti_aim.latency_list[ i ] > highest_latency then
            -- Save this as the new highest latency.
            highest_latency = anti_aim.latency_list[ i ]
        end
    end

    -- Since our props are delayed by latency, we need to account for our ping when trying to detect our tickbase on the
    -- server. We'll counteract this by adding our latency onto our delta between our current tickbase and previous.
    local delta = tickbase - anti_aim.last_tickbase + highest_latency

    -- Is our current tickbase smaller than our previous? If so, this is not a valid lag record, we're immune.
    if delta < 0 then
        anti_aim.in_immunity = true
    elseif delta > 0 then
        -- This is a regular record, we're hittable on the server (unless breaking lc another way, not relevant).
        anti_aim.last_tickbase = tickbase
    end
end

function anti_aim.anti_backstab( )
    -- Restore our backstab variable to it's default value.
    anti_aim.backstab = false

    if not ui.get( items[ "Anti-aim" ].enabled ) or not ui.get( items[ "Anti-aim" ].anti_backstab ) then
        return
    end

    -- Grab a list of the enemies.
    local enemies = entity.get_players( true )
    -- Save our local player's origin.
    local local_origin = { entity.get_origin( entity.get_local_player( ) ) }

    -- Now, iterate over that list.
    for i=1, #enemies do
        -- Save our current enemy as well as their weapon and weapon name.
        local enemy = enemies[ i ]
        local weapon = entity.get_player_weapon( enemy )
        local weapon_name = entity.get_classname( weapon )

        -- Enemy isn't using a knife, continue.
        if weapon_name ~= "CKnife" then
            goto continue
        end

        -- Grab the target's origin within an array.
        local target_origin = { entity.get_origin( enemies[ i ] ) }
        
        -- Calculate the differences between our local position and the enemy position.
        local position_difference = vector_diff( target_origin, local_origin )

        -- Now, calculate the delta of those vectors.
        local delta = length( position_difference )

        -- Is the difference under or equal to our set backstab range?
        if delta <= ui.get( items[ "Anti-aim" ].anti_backstab_range ) then
            anti_aim.backstab = true
            break
        end

        ::continue::
    end
end

function anti_aim.manual_anti_aim( )
    if not ui.get( items[ "Anti-aim" ].enabled ) or not ui.get( items[ "Anti-aim" ].manual_anti_aim ) then
        -- Restore our side to backwards.
        anti_aim.manual_side = "back"
        return
    end

    if ui.get( items[ "Anti-aim" ].manual_back ) then
        -- We have the backwards key active, no need for worrying about restoration.
        anti_aim.manual_side = "back"
    elseif ui.get( items[ "Anti-aim" ].manual_forward ) and not anti_aim.manual_set[ "forward" ] then
        -- This is our second time pressing forward, the user is trying to disable this side.
        if anti_aim.manual_side == "forward" then
            anti_aim.manual_side = "back"
        -- It's our first time pressing the forward key, trigger the side as normal.
        else
            anti_aim.manual_side = "forward"
        end
        anti_aim.manual_set[ "forward" ] = true
    elseif ui.get( items[ "Anti-aim" ].manual_left ) and not anti_aim.manual_set[ "left" ] then
        -- This is our second time pressing left, the user is trying to disable this side.
        if anti_aim.manual_side == "left" then
            anti_aim.manual_side = "back"
        -- It's our first time pressing the left key, trigger the side as normal.
        else
            anti_aim.manual_side = "left"
        end
        anti_aim.manual_set[ "left" ] = true
    elseif ui.get( items[ "Anti-aim" ].manual_right ) and not anti_aim.manual_set[ "right" ] then
        -- Same as above, this is our second time pressing it so restore to backwards.
        if anti_aim.manual_side == "right" then
            anti_aim.manual_side = "back"
        -- This is our first time pressing it, make our mode right.
        else
            anti_aim.manual_side = "right"
        end
        anti_aim.manual_set[ "right" ] = true
    end

    -- The key for the forward side is not turned on, so the anti-aim isn't set.
    if not ui.get( items[ "Anti-aim" ].manual_forward ) then
        anti_aim.manual_set[ "forward" ] = false
    end

    -- The key for the left side is not turned on, so the anti-aim isn't set.
    if not ui.get( items[ "Anti-aim" ].manual_left ) then
        anti_aim.manual_set[ "left" ] = false
    end

    -- The key for the right side is not turned on, so the anti-aim isn't set.
    if not ui.get( items[ "Anti-aim" ].manual_right ) then
        anti_aim.manual_set[ "right" ] = false
    end
end

function anti_aim.handle_commands( cmd )
    -- Save our local player in a variable since we use it a lot.
    local local_player = entity.get_local_player( )
    -- Same for pitch and yaw.
    local pitch, yaw = client.camera_angles( )
    -- Grab our state, and the settings for that state.
    local state = anti_aim.states[ anti_aim.state ]
    local state_settings = items[ "Builder" ][ state ]
    -- Save a variable for with our movetype prop compared to 9, or, whether we're on a ladder.
    local on_ladder = entity.get_prop( local_player, "m_MoveType" ) == 9

    -- Are we currently on a ladder and desiring to use fast ladder?
    if ui.get( items[ "Misc" ].fast_ladder ) and on_ladder then
        -- Check if we have the ascending fast ladder option.
        if in_multi_select( items[ "Misc" ].fast_ladder_type, "Ascending" ) then
            if cmd.forwardmove > 0 then
                if pitch < 45 then
                    cmd.pitch = 89
                    cmd.in_moveright = 1
                    cmd.in_moveleft = 0
                    cmd.in_forward = 0
                    cmd.in_back = 1
                    if cmd.sidemove == 0 then
                        cmd.yaw = cmd.yaw + 90
                    end
                    if cmd.sidemove < 0 then
                        cmd.yaw = cmd.yaw + 150
                    end
                    if cmd.sidemove > 0 then
                        cmd.yaw = cmd.yaw + 30
                    end
                end 
            end
        end

        -- Check if we have the descending fast ladder option.
        if in_multi_select( items[ "Misc" ].fast_ladder_type, "Descending" ) then
            if cmd.forwardmove < 0 then
                cmd.pitch = 89
                cmd.in_moveleft = 1
                cmd.in_moveright = 0
                cmd.in_forward = 1
                cmd.in_back = 0
                if cmd.sidemove == 0 then
                    cmd.yaw = cmd.yaw + 90
                end
                if cmd.sidemove > 0 then
                    cmd.yaw = cmd.yaw + 150
                end
                if cmd.sidemove < 0 then
                    cmd.yaw = cmd.yaw + 30
                end
            end
        end
    end

    if not ui.get( items[ "Anti-aim" ].enabled ) then
        return
    end

    -- Do we have anti-aim on use enabled?
    if in_multi_select( items[ "Anti-aim" ].options, "Anti-aim on use" ) then
        -- Save the defusing and hostage grabbing props to variables.
        local is_defusing = entity.get_prop( local_player, "m_bIsDefusing" )
        local is_grabbing_hostage = entity.get_prop( local_player, "m_bIsGrabbingHostage" )

        -- If we aren't defusing or grabbing a hostage, run the code as normal.
        if is_defusing ~= 1 and is_grabbing_hostage ~= 1 then
            -- Grab our local player's weapon.
            local weapon = entity.get_player_weapon( entity.get_local_player( ) )
            -- Now, grab the name of that weapon.
            local weapon_name = entity.get_classname( weapon )

            -- If we aren't choking commands and are not holding C4, set in_use to 0.
            if cmd.chokedcommands == 0 and weapon_name ~= "CC4" then
                cmd.in_use = 0
            end
        end
    end

    -- Are we attempting to force immunity on this state?
    if ui.get( state_settings.force_immunity ) then
        -- Force immunity and let the lua know the time of this happening.
        cmd.force_defensive = 1
        anti_aim.last_force_defensive = globals.curtime( )
    end
end

function anti_aim.run( )
    if not ui.get( items[ "Anti-aim" ].enabled ) then
        return
    end

    -- Save our current state's settings to a variable for easy access.
    local state_settings = items[ "Builder" ][ anti_aim.states[ anti_aim.state ] ]
    -- Grab our desired anti-aim type.
    local anti_aim_type = ui.get( state_settings.type )

    -- Are we using the lua's standalone freestanding?
    if ui.get( items[ "Anti-aim" ].freestanding ) then
        -- Create a variable with the value of whether or not we should freestand.
        local should_freestand = ui.get( items[ "Anti-aim" ].freestand_key ) and not ui.get( state_settings.disable_freestanding )

        -- Set our freestanding key to always on, we'll use the actual checkbox to dictate the value.
        ui.set( references.freestanding[ 2 ], "Always on" )
        -- Finally, apply our should_freestand variable to the freestanding master switch.
        ui.set( references.freestanding[ 1 ], should_freestand )
    end

    -- Create an array that holds the default anti-aim settings that we're going to apply.
    local values = {
        pitch = { { "Down", 0 }, references.pitch },
        yaw_base = { ui.get( state_settings.yaw_base ), references.yaw_base },
        yaw = { { "180", ui.get( state_settings.yaw_additive ) }, references.yaw },
        yaw_jitter = { { "Off", 0 }, references.yaw_jitter },
        body_yaw = { { "Static", 90 }, references.body_yaw },
        fs_body_yaw = { false, references.freestanding_body_yaw },
        edge_yaw = { in_multi_select( items[ "Anti-aim" ].options, "Edge yaw" ), references.edge_yaw },
        roll = { in_multi_select( items[ "Anti-aim" ].options, "Roll" ) and 45 or 0, references.roll }
    }

    -- Create a variable to tell whether or not we're freestanding.
    local is_freestanding = ui.get( references.freestanding[ 1 ] ) and ui.get( references.freestanding[ 2 ] )

    -- Add our manual anti-aim value onto our yaw if it's enabled.
    if ui.get( items[ "Anti-aim" ].manual_anti_aim ) then
        values.yaw[ 1 ] = { "180", anti_aim.manual_yaw[ anti_aim.manual_side ] }
    end

    -- We'll override our non-state dependent anti-aim types here, starting with our immunity flick.
    if anti_aim.in_immunity and ui.get( items[ "Anti-aim" ].immunity_flick ) then
        anti_aim_type = "Immunity"
    -- Are we currently able to be backstabbed and attempting to prevent it?
    elseif anti_aim.backstab then
        anti_aim_type = "Anti-backstab"
    -- If we desire safe and we're using manual anti-aim or freestanding, use that side.
    elseif ( in_multi_select( items[ "Anti-aim" ].options, "Static on manual" ) and anti_aim.manual_side ~= "back" ) or
    ( in_multi_select( items[ "Anti-aim" ].options, "Static on freestand" ) and is_freestanding ) then
        anti_aim_type = "Safe"
    end

    if anti_aim_type == "Twist" then
        -- Calculate the desired percentage of twist strength based off of our maximum and minimum twist variables.
        local twist_value = math.floor( ( ui.get( state_settings.twist_strength ) * ( anti_aim.maximum_twist - anti_aim.minimum_twist ) ) / 100 ) + anti_aim.minimum_twist
        -- Now, calculate whether or not we should invert our body yaw yet.
        local should_invert = globals.tickcount( ) % anti_aim.twist_interval * 2 > anti_aim.twist_interval

        -- Set our twist settings.
        values.body_yaw[ 1 ] = { "Static", should_invert and 90 or -90 }
        values.yaw_jitter[ 1 ] = { "Skitter", twist_value }
    elseif anti_aim_type == "Jitter" then
        -- Calculate the desired percentage of jitter strength, same as twist.
        local jitter_value = math.floor( ( ui.get( state_settings.jitter_strength ) * ( anti_aim.maximum_jitter - anti_aim.minimum_jitter ) ) / 100 ) + anti_aim.minimum_jitter
        -- Create a variable to tell whether or not we desire to invert our yaw.
        local should_invert = false
        -- Grab our jitter position for repeated use.
        local jitter_position = ui.get( state_settings.jitter_position )

        -- Do we want a hybrid jitter position? This requires standalone handling.
        if jitter_position == "Hybrid" then
            -- Use the same math as above to calculate how often we want to switch with hybrid.
            local hybrid_speed = ui.get( state_settings.hybrid_speed ) * ( anti_aim.maximum_hybrid_speed - anti_aim.minimum_hybrid_speed )
            -- Now floor our calculated value and add on our minimum value.
            hybrid_speed = math.floor( hybrid_speed / 100 + anti_aim.minimum_hybrid_speed )

            -- Finally, invert our yaw value however often the user desires.
            should_invert = globals.tickcount( ) % hybrid_speed > hybrid_speed / 2
        else
            -- We can just do inline handling here, invert if we want inwards and vice versa.
            should_invert = jitter_position == "Inwards"
        end

        -- Set our jitter settings.
        values.yaw_jitter[ 1 ] = { "Center", should_invert and jitter_value or - jitter_value }
        values.body_yaw[ 1 ] = { "Jitter", 90 }
    elseif anti_aim_type == "Immunity" then
        -- The anti-aim we use here is irrelevant since we're immune, so we'll use something silly looking.
        values.pitch[ 1 ] = { "Up", 0 }
        values.yaw[ 1 ] = { "Static", 50 }
    elseif anti_aim_type == "Safe" then
        -- All we desire is an extremely safe head, so use settings that fit that.
        values.body_yaw[ 1 ] = { "Opposite", 0 }
        values.fs_body_yaw[ 1 ] = true
    elseif anti_aim_type == "Anti-backstab" then
        values.yaw_base[ 1 ] = "At targets"
        values.yaw[ 1 ] = { "180", 180 }
    end

    -- Iterate over our new anti-aim settings.
    for item_name, item in pairs( values ) do
        -- Is this menu item a table?
        if type( item[ 1 ] ) ~= "table" then
            -- Not a table, set as normal.
            ui.set( item[ 2 ], item[ 1 ] )
        else
            -- We're dealing with a table, iterate over it's members and set them individually.
            for i=1, #item[ 1 ] do
                ui.set( item[ 2 ][ i ], item[ 1 ][ i ] )
            end
        end
    end
end

function modify_animations( )
    if not ui.get( items[ "Misc" ].animation_breaker ) then
        return
    end

    local local_player = entity.get_local_player( )

    if in_multi_select( items[ "Misc" ].animation_modifications, "Remove falling animation" ) then
        entity.set_prop( local_player, "m_flPoseParameter", 1, 6 ) 
    end

    if in_multi_select( items[ "Misc" ].animation_modifications, "Reverse running legs" ) then
        entity.set_prop( local_player, "m_flPoseParameter", 0, 7 )
    end
end

-- An array to hold all of our indicator related data.
local indicators = {
    -- How long it has been since we last opened our menu.
    menu_open_time = 0,
    -- How long we want our menu notice text to show up.
    menu_notice_duration = 2,
    -- The alpha of our notice.
    notice_alpha = 0
}

function indicators.run( )
    if not entity.is_alive( entity.get_local_player( ) ) then
        return
    end

    local display_strings = {
        [ 1 ] = { "rapid", ui.get( references.double_tap[ 1 ] ) and ui.get( references.double_tap[ 2 ] ), "8BB5FFFF", "Double tap" },
        [ 2 ] = { "hide", ui.get( references.on_shot[ 1 ] ) and ui.get( references.on_shot[ 2 ] ), "AEFF36FF", "Hide shots" },
        [ 3 ] = { "freestand", ui.get( references.freestanding[ 1 ] ) and ui.get( references.freestanding[ 2 ] ), "4567BEFF", "Freestanding" },
        [ 4 ] = { "manual : " .. anti_aim.manual_side:sub( 1, 1 ):lower( ), anti_aim.manual_side ~= "back", "E75656FF", "Manual" },
        [ 5 ] = { "damage : " .. ui.get( references.min_damage_override[ 3 ] ), ui.get( references.min_damage_override[ 1 ] ) and ui.get( references.min_damage_override[ 2 ] ), "FFFFFFFF", "Damage override" }
    }

    local sc_w, sc_h = client.screen_size( )

    local indicator_offset = 50 + ui.get( items[ "Visuals" ].indicator_offset )
    local iter = 1

    local text = opulent.fade_text( 255, 180, 215, "opulent" )

    renderer.text( sc_w / 2, sc_h / 2 + indicator_offset - 12, 255, 255, 255, 255, "cb", 0, text )
    renderer.text( sc_w / 2, sc_h / 2 + indicator_offset, 255, 180, 255, 140, "c-", 0, string.format( "-    %s  -", opulent.version:upper( ) ) )

    for i=1, #display_strings do
        if display_strings[ i ][ 2 ] and in_multi_select( items[ "Visuals" ].indicator_list, display_strings[ i ][ 4 ] ) then
            renderer.text( sc_w / 2, sc_h / 2 + indicator_offset + iter * 12, 255, 255, 255, 255, "c", 0, "\a", display_strings[ i ][ 3 ], display_strings[ i ][ 1 ] )
            iter = iter + 1
        end
    end
end

-- This will be run in paint_ui as opposed to paint, which means this will run while we're dead, so
-- we'll use this for indicators that we want to display whether the local player is alive or not.
function indicators.paint_ui( )
    -- Create an array that holds all text we want to display in our indicators at the bottom of our screen.
    -- Each member will be an array that holds 2 values, the text we want colored and the text we want white.
    local indicator_items = {
        { "user: ", opulent.username:lower( ) },
        { "version: ", opulent.version },
        { "discord.gg/", "opulentlua" }
    }

    -- Create 2 variables that hold the hex codes for which colors we want.
    local regular_color = "FFFFFFFF"
    local highlight_color = "FFC0CBFF"

    -- Create a variable that will hold our concatenated indicator items.
    local display_string = ""

    -- Iterate over our indicator items.
    for i=1, #indicator_items do
        -- Save both the regular text and highlighted text to variables.
        local regular_text = indicator_items[ i ][ 1 ]
        local highlighted_text = indicator_items[ i ][ 2 ]

        -- If this isn't our last item, add a seperator to the end of the highlighted string.
        if i < #indicator_items then
            highlighted_text = highlighted_text .. " | "
        end
        
        -- Now, concatenate those strings along with their correlated hex value.
        display_string = string.format( "%s\a%s%s\a%s%s", display_string, regular_color, regular_text, highlight_color, highlighted_text )
    end

    -- Now we have dealt with concatenating the string, calculate the size of it.
    local text_w, text_h = renderer.measure_text( nil, display_string )

    -- The width of our bottom gradient, we'll do the text width + 20 pixels for padding.
    local rect_w = 20 + text_w
    -- The height of our gradient.
    local rect_h = 2

    -- Save our screen height to variables.
    local sc_w, sc_h = client.screen_size( )

    -- Is our logo data nil?
    if opulent.logo ~= nil then
        -- Create a variable for how big we want our logo to be.
        local logo_size = 30
        -- How far do we want to offset our logo from the bottom of our screen?
        local logo_offset = 50

        -- Draw our logo above the bottom text.
        opulent.logo:draw( sc_w / 2 - logo_size / 2, sc_h - logo_offset, logo_size, logo_size, 255, 255, 255, 255, false )

        -- Is our menu open?
        if ui.is_menu_open( ) then
            -- Our menu is open, if we haven't yet set our open time, do so.
            if indicators.menu_open_time == 0 then
                indicators.menu_open_time = globals.curtime( )
            end

            -- Are we still within the time of our notice duration?
            if globals.curtime( ) - indicators.menu_open_time <= indicators.menu_notice_duration then
                -- If our notice alpha isn't yet 0, it still requires interpolation, do so.
                if indicators.notice_alpha < 255 then
                    indicators.notice_alpha = indicators.notice_alpha + globals.frametime( ) * 2000
                end
            else
                -- Our notice duration has expired, hide it.
                if indicators.notice_alpha > 0 then
                    indicators.notice_alpha = indicators.notice_alpha - globals.frametime( ) * 2000
                end
            end
        else
            -- Our menu isn't open, reset our time since menu opened variable.
            indicators.menu_open_time = 0

            -- If our notice alpha isn't yet 0, it still requires interpolation, do so.
            if indicators.notice_alpha > 0 then
                indicators.notice_alpha = indicators.notice_alpha - globals.frametime( ) * 2000
            end
        end

        -- Clamp our notice alpha to 0 and 255.
        indicators.notice_alpha = math.max( 0, math.min( 255, indicators.notice_alpha ) )

        -- Grab our menu position and size.
        local menu_x, menu_y = ui.menu_position( )
        local menu_w, menu_h = ui.menu_size( )

        -- The size and position offset we want our logo to be in the notice.
        local notice_logo_size = 40
        local notice_logo_y_offset = 20

        -- Save our notice color, in hex, that we want to use for the highlighted menu text.
        local notice_color = opulent.rgb_to_hex( 255, 192, 203, indicators.notice_alpha )
        
        -- If our notice alpha is still above 0, draw the text and logo for it.
        if indicators.notice_alpha > 0 then
            renderer.text( menu_x + menu_w / 2, menu_y + menu_h + 10, 255, 255, 255, indicators.notice_alpha, "cb", 0, "Welcome back to opulent, \a", notice_color, opulent.username )
            opulent.logo:draw( menu_x + menu_w / 2 - notice_logo_size / 2, menu_y + menu_h + notice_logo_y_offset, notice_logo_size, notice_logo_size, 255, 255, 255, indicators.notice_alpha, false )
        end
    end

    -- Render the left side of our gradient.
    renderer.gradient( sc_w / 2 - rect_w / 2 + 1, sc_h - rect_h, rect_w / 2, rect_h, 255, 165, 165, 0, 255, 165, 165, 255, true )
    -- Render the right side of our gradient.
    renderer.gradient( sc_w / 2, sc_h - rect_h, rect_w / 2, rect_h, 255, 165, 165, 255, 255, 165, 165, 0, true )

    -- Finally, render our text.
    renderer.text( sc_w / 2, sc_h - rect_h - text_h, 255, 255, 255, 255, "c", 0, display_string )
end

-- An array with all of our clantag related things.
local clan_tag = {
    -- Are we trying to reset our clan tag back to default?
    reset = false,
    -- What our last modulated tick count was.
    last_count = 0,
    -- Should we flip the side we're counting on?
    flip = false,
    -- How high we want the clan tag to count.
    max_count = 10,
    -- How long (in ticks) we want the count to stay the same before updating.
    count_time = 32
}

function clan_tag.run( )
    -- Do we not have the custom clan tag enabled?
    if not ui.get( items[ "Misc" ].clan_tag ) then
        -- Are we trying to reset our clan tag?
        if clan_tag.reset then
            -- Grab our local player's clan tag prop.
            local local_tag = entity.get_prop( entity.get_player_resource( ), "m_szClan", entity.get_local_player( ) )

            -- If the tag isn't yet blank, keep attempting to reset.
            if local_tag ~= nil and local_tag ~= "" then
                -- Set our clan tag to blank.
                client.set_clan_tag( "" )
            else
                -- Clan tag successfully reset, stop trying to do so.
                clan_tag.reset = false
            end
        end
        return
    end

    -- Calculate what the tickcount would be on the server via our latency.
    local server_tickcount = globals.tickcount( ) + time_to_ticks( client.latency( ) )

    -- Calculate our tick count using some basic math, then round to the nearest with floor and + 0.5.
    local tick_count = server_tickcount % ( clan_tag.count_time * clan_tag.max_count )
    tick_count = math.floor( 0.5 + ( tick_count / clan_tag.count_time ) )

    -- If our current count is the same as the last count we had, return.
    if clan_tag.last_count == tick_count then
        return
    end

    -- Is our current count at or below 0?
    if tick_count <= 0 then
        -- Set the flip variable to the opposite of it's current value.
        clan_tag.flip = not clan_tag.flip
    end

    -- Set our baseline clan tag text, just placeholder.
    local clan_tag_text = "opulent"

    -- Are we trying to flip the side of the clan tag we count on?
    if clan_tag.flip then
        -- Use string.format and set our clan tag string to it's respective text.
        clan_tag_text = string.format( "opulent [ %s ]", clan_tag.max_count - tick_count )
    else
        -- Do the same, but count on the opposite side.
        clan_tag_text = string.format( "[ %s ] opulent", clan_tag.max_count - tick_count )
    end

    -- Set our clan tag in accordance with the new, formatted text.
    client.set_clan_tag( clan_tag_text )
    
    -- Set reset to true and let the script know we just updated the tag.
    clan_tag.reset = true
    clan_tag.last_count = tick_count
end

-- List of all our killsay functions and relevant variables.
local killsay = {
    -- A table for insults we'll use after we kill a player.
    insults = {
        -- These are our initial insults, as opposed to the replies.
        [ "initial" ] = {
            "wyd",
            "nice one",
            "?",
            "genius",
            "wp"
        },
        -- Custom initial insults if we hit a headshot.
        [ "headshot" ] = {
            "hs",
            "nice aa",
            "? hs"
        },
        -- These are our response insults.
        [ "response" ] = {
            "*DEAD*",
            "dead people cant speak",
            "u got baited",
            "thanks for the clip",
            "use mic"
        }
    },
    -- How long we want to delay the response of the killsay for it to look real.
    response_delay = 3,
    -- How long we want to wait until we no longer send a killsay if the user types.
    responsive_duration = 10,
    -- An array that holds that last time we insulted each player.
    last_insult = { }
}

function killsay.post_insult( insult_type )
    -- Standalone function because we'll use this repeatedly, save the table of insults we'll use.
    local insults = killsay.insults[ insult_type ]

    -- Run our client.exec in a delay call to put off the response for the desired time.
    client.delay_call( killsay.response_delay, function( )
        -- Finally, send a chat message with our random insult from that table.
        client.exec( "say " .. insults[ client.random_int( 1, #insults ) ] )
    end )
end

function killsay.on_death( event )
    -- Return if we aren't using killsay.
    if not ui.get( items[ "Misc" ].insult_on_kill ) then
        return
    end

    -- Convert the attacker and victim user id's to entity indices.
    local victim = client.userid_to_entindex( event.userid )
    local attacker = client.userid_to_entindex( event.attacker )
    -- Grab local for repeated use.
    local local_player = entity.get_local_player( )

    -- If our attacker isn't the local player or the victim isn't the local player (suicide), return.
    if attacker ~= local_player or victim == local_player then
        return
    end

    -- We just killed someone, send either an initial or headshot specific insult based on event.headshot.
    killsay.post_insult( event.headshot and "headshot" or "initial" )
    -- Let the lua know when we last insulted this player
    killsay.last_insult[ victim ] = globals.curtime( )
end

function killsay.on_chat( event )
    -- Return if we aren't using responsive killsay
    if not ui.get( items[ "Misc" ].insult_on_kill ) or ui.get( items[ "Misc" ].insult_on_kill_type ) ~= "Responsive" then
        return
    end

    -- Convert the person typing's userid to an entity index.
    local typer = client.userid_to_entindex( event.userid )

    -- If there isn't a time for when we last insulted this player, return.
    if not killsay.last_insult[ typer ] then
        return
    end

    -- Calculate the time it has been since we insulted the player.
    local last_insulted = globals.curtime( ) - killsay.last_insult[ typer ]

    -- If the last time we insulted them is within our responsive duration, send an insult.
    if last_insulted <= killsay.responsive_duration then
        killsay.post_insult( "response" )
    end
end

-- Create an array to hold all of our config related data.
local configs = {
    -- The name of our database where we'll hold all the data.
    db_name = "opulenty"
}

function configs.config_detected( name )
    -- Grab our config database.
    local config_database = database.read( configs.db_name )

    -- Iterate over our config database indices.
    for i=1, #config_database do
        -- If this key matches the given name, there is a config detected, return true.
        if config_database[ i ].name == name then
            return true, i
        end
    end

    -- We iterated over everything and didn't find a matching string, return false.
    return false, 0
end

function configs.update_list( )
    -- Our configs are saved to the database in a json format, so we'll use json.parse to convert them.
    local config_database = database.read( configs.db_name )

    -- Create an array that will hold the names of our configs.
    local config_names = { }

    -- Iterate over our config array.
    for i=1, #config_database do
        config_names[ #config_names + 1 ] = config_database[ i ].name
    end

    -- Update our config list with the names.
    ui.update( items[ "Config" ].config_list, config_names )
end

function configs.reset_config( )
    -- Grab our target config name.
    local config_name = ui.get( items[ "Config" ].name )

    -- Call config_detected to get the validity of the config.
    local config_detected, config_index = configs.config_detected( config_name )

    -- If there is no valid config under this name, return.
    if not config_detected then
        return
    end

    -- Grab our config database.
    local config_database = database.read( configs.db_name )

    -- Overwrite our config with the default value.
    config_database[ config_index ].data = "{ }"

    -- Now, apply our new config database.
    database.write( configs.db_name, config_database )
end

function configs.delete_config( )
    -- Grab our configs.
    local config_database = database.read( configs.db_name )

    -- Call config_detected to tell whether this is a valid config and gain access to the index.
    local config_detected, config_index = configs.config_detected( ui.get( items[ "Config" ].name ) )

    -- If this isn't a valid config, return.
    if not config_detected then
        return
    end

    -- Remove this config from our array.
    config_database[ config_index ] = nil

    -- Iterate over our config array.
    for i=1, #config_database do
        -- If this member index is greater than the index of the config we want to delete, move it down.
        if i > config_index then
            config_database[ i - 1 ] = config_database[ i ]
        end
    end

    -- Write our new data to the database.
    database.write( configs.db_name, config_database )

    -- Update our config list.
    configs.update_list( )
end

function configs.load( )
    -- Grab our target config name.
    local config_name = ui.get( items[ "Config" ].name )

    -- Call config_detected to get the validity of the config.
    local config_detected, config_index = configs.config_detected( config_name )

    -- If there is no valid config under this name, return.
    if not config_detected then
        return
    end

    -- Grab the config database.
    local config_database = database.read( configs.db_name )
    -- Now, grab our config's data within the database and convert it with json.
    local config_data = json.parse( config_database[ config_index ].data )

    -- Iterate over our item tabs.
    for i=1, #opulent.tabs do
        -- Iterate over our items in this tab.
        for k, v in pairs( items[ opulent.tabs[ i ] ] ) do
            -- If we don't have a value for this item in our config, continue.
            if config_data[ k ] == nil then
                goto continue
            end

            -- Is this item a table?
            if type( v ) ~= "table" then
                -- Set the item value with the corresponding config value.
                ui.set( v, config_data[ k ] )
            else
                -- Iterate over the item's table.
                for j=1, #v do
                    -- Set the item value, same as above.
                    ui.set( v, config_data[ k ][ i ] )
                end
            end

            -- Create our continue code block.
            ::continue::
        end
    end
end

function configs.save( )
    -- Create an array that will hold all of our item values.
    local config_data = { }

    -- Iterate over our item tabs.
    for i=1, #opulent.tabs do
        -- Now, iterate over the items within this tab.
        for k, v in pairs( items[ opulent.tabs[ i ] ] ) do
            -- Some of our values are arrays, so make sure we check for that.
            if type( v ) ~= "table" then
                -- Save the ui.type of this item since we'll use it repeatedly.
                local ui_type = ui.type( v )

                -- Ensure we aren't dealing with a button, hotkey, or label since we can't save these.
                if ui_type ~= "button" and ui_type ~= "hotkey" and ui_type ~= "label" then
                    -- Grab the value of this item and add it to our array.
                    config_data[ k ] = ui.get( v )
                end
            else
                -- We're dealing with an array, do the same but iterate over each of it's members.
                for j=1, #v do
                    ui.get( config_data[ k ][ j ], v[ j ] )
                end
            end
        end
    end

    -- Grab our config database.
    local config_database = database.read( configs.db_name )
    -- Save our target config name.
    local config_name = ui.get( items[ "Config" ].name )
    -- Create a variable that will return whether we have a config detected and if we do, it's index.
    local config_detected, config_index = configs.config_detected( config_name )

    -- Is there a config with our desired name?
    if config_detected then
        -- This config already exists, overwrite it with our new data using the given index.
        config_database[ config_index ] = { name = config_name, data = libraries.base64.encode( json.stringify( config_data ) ) }
    else
        -- No config exists with our desired name, create a new index with this config.
        config_database[ #config_database + 1 ] = { name = config_name, data = libraries.base64.encode( json.stringify( config_data ) ) }
    end

    -- Write our new config information to our database.
    database.write( configs.db_name, config_database )
    -- Update our listbox.
    configs.update_list( )
end

function configs.import( )
    -- First, decode the stringified array that we have on our clipboard.
    local config_string = libraries.base64.decode( libraries.clipboard.get( ) )
    -- Now parse it to convert it to a usable array.
    local new_config = json.parse( config_string )

    -- Iterate over our item tabs.
    for i=1, #opulent.tabs do
        -- Iterate over our items in this tab.
        for k, v in pairs( items[ opulent.tabs[ i ] ] ) do
            -- If we don't have a value for this item in our config, continue.
            if new_config[ k ] == nil then
                goto continue
            end

            -- Is this item a table?
            if type( v ) ~= "table" then
                -- Set the item value with the corresponding config value.
                ui.set( v, new_config[ k ] )
            else
                -- Iterate over the item's table.
                for j=1, #v do
                    -- Set the item value, same as above.
                    ui.set( v, new_config[ k ][ i ] )
                end
            end

            -- Create our continue code block.
            ::continue::
        end
    end
end

function configs.export( )
    -- Create an array that will hold all of our item values.
    local config_data = { }

    -- Iterate over our item tabs.
    for i=1, #opulent.tabs do
        -- Now, iterate over the items within this tab.
        for k, v in pairs( items[ opulent.tabs[ i ] ] ) do
            -- Some of our values are arrays, so make sure we check for that.
            if type( v ) ~= "table" then
                -- Save the ui.type of this item since we'll use it repeatedly.
                local ui_type = ui.type( v )

                -- Ensure we aren't dealing with a button, hotkey, or label since we can't save these.
                if ui_type ~= "button" and ui_type ~= "hotkey" and ui_type ~= "label" then
                    -- Grab the value of this item and add it to our array.
                    config_data[ k ] = ui.get( v )
                end
            else
                -- We're dealing with an array, do the same but iterate over each of it's members.
                for j=1, #v do
                    ui.get( config_data[ k ][ j ], v[ j ] )
                end
            end
        end
    end

    -- Use json to translate our array into a string.
    local config_string = json.stringify( config_data )
    -- Now translate that to base64 to condense it.
    config_string = libraries.base64.encode( config_string )

    -- Finally, set our config string to our clipboard.
    libraries.clipboard.set( config_string )
end

function configs.initialize( )
    -- Save our database to a variable.
    local config_database = database.read( configs.db_name )
    
    -- If our database is null, fill it with an array that holds an empty default config.
    if config_database == nil then
        database.write( configs.db_name, { [ 1 ] = { name = "Default", data = libraries.base64.encode( "{ }" ) } } )
    end

    -- Update our config listbox.
    configs.update_list( )

    -- Attach a ui callback to our config text list.
    ui.set_callback( items[ "Config" ].config_list, function( config_index )
        -- Save our database again, we don't want to use our old one since that's static.
        local new_config_database = database.read( configs.db_name )
        -- Convert our config index to the real list selection.
        config_index = ui.get( config_index )

        -- If the provided config index is nil, return.
        if config_index == nil then
            return
        -- If our config database with the given index is also nil, return.
        elseif not new_config_database[ config_index + 1 ] then
            return
        end

        -- Set the value of our config text name to the respective config list name.
        ui.set( items[ "Config" ].name, new_config_database[ config_index + 1 ].name )
    end )
end

-- Since we need access to all the created items, we need to make our config items down here.
items[ "Config" ].config_list = opulent.new_item( ui.new_listbox, "Config list", nil, nil, "Placeholder" )
items[ "Config" ].name = opulent.new_item( ui.new_textbox, "Config name" )
items[ "Config" ].load = opulent.new_item( ui.new_button, "Load", nil, nil, configs.load )
items[ "Config" ].save = opulent.new_item( ui.new_button, "Save", nil, nil, configs.save )
items[ "Config" ].delete = opulent.new_item( ui.new_button, "Delete", nil, nil, configs.delete_config )
items[ "Config" ].reset = opulent.new_item( ui.new_button, "Reset", nil, nil, configs.reset_config )
items[ "Config" ].import = opulent.new_item( ui.new_button, "Import from clipboard", nil, nil, configs.import )
items[ "Config" ].export = opulent.new_item( ui.new_button, "Export to clipboard", nil, nil, configs.export )

-- Set a callback on our config list to u
function opulent.handle_console( input )
    -- Enable the console text filter.
    cvar.con_filter_enable:set_raw_int( 1 )
    -- Filter out "unknown command" so that we don't get spammed when trying to use opulent commands.
	cvar.con_filter_text_out:set_string( "Unknown command" )

    -- Normalize the text input by changing it to lowercase.
    input = input:lower( )

    -- Is this user attempting to grab an explanation by beginning the command with 'explain'?
    if input:sub( 1, 7 ) == "explain" then
        -- Iterate over our item description's and their respective text.
        for k, v in pairs( opulent.item_descriptions ) do
            -- Is this feature name what the user typed into console?
            if input:sub( 9 ) == k:lower( ) then
                -- Print the item's explanation to the user's console.
                opulent.print( "here is the explanation for ", k:lower( ), ":\n", v )
                -- Give the user a successful sound to notify them.
                client.exec( "play ui\\panorama\\sidemenu_click_01" )
                -- Return out of this function, we got what we needed.
                return
            end
        end

        -- No explanation was found, inform the user.
        opulent.print( "could not find an explanation for ", input:sub( 9 ), "" )
        -- Play a warning sound.
        client.exec( "play ui\\panorama\\music_equip_01" )
    end
end

function opulent.reset_data( )
    -- Reset all variables to their default values here.
    anti_aim.in_immunity = false
    anti_aim.last_tickbase = 0
    anti_aim.last_in_air = 0
    anti_aim.last_force_defensive = 0
    anti_aim.latency_list = { }
    killsay.last_insult = { }
end

function opulent.handle_master_label( )
    -- Create our new gradient text.
    local text = opulent.fade_text( 255, 180, 215, "opulent" )

    -- Now, apply that gradient text to our master switch label.
    ui.set( items.master_switch_label, text )
end

-- Create a table that will hold all of our entry related items and functions.
local entry = {
    -- These events will be automatically set/unset in accordance with the master switch value.
    -- Format: [ "event here" ] = { list of functions you want to behind to this event }
    bound_events = {
        [ "console_input" ] = { opulent.handle_console },
        [ "setup_command" ] = { anti_aim.handle_commands },
        [ "run_command" ] = { anti_aim.manual_anti_aim, anti_aim.handle_states, anti_aim.run },
        [ "net_update_end" ] = { anti_aim.anti_backstab, anti_aim.immunity_detection },
        [ "player_death" ] = { killsay.on_death },
        [ "player_say" ] = { killsay.on_chat },
        [ "paint" ] = { clan_tag.run, indicators.run },
        [ "pre_render" ] = { modify_animations },
        [ "paint_ui" ] = { indicators.paint_ui },
        [ "level_init" ] = { opulent.reset_data },
        [ "round_end" ] = { opulent.reset_data }
    },
    -- Create a variable to tell whether or not we have fully initialized the lua.
    initialized = false
}

entry.handle_visibility = function( )
    -- Grab our master switch state for repeated use.
    local state = ui.get( items.master_switch )

    -- Iterate over all of our tabs.
    for i=1, #opulent.tabs do
        -- Now, iterate over all of our menu items within this tab.
        for k, v in pairs( items[ opulent.tabs[ i ] ] ) do
            -- If we're dealing with a table, just continue.
            if type( v ) == "table" then
                goto continue
            end

            -- Are we currently initializing the lua?
            if not entry.initialized then
                -- Grab our item's type.
                local item_type = ui.type( v )

                -- We want to re-run our visibility checks every time the value of an item changes, but some items like color
                -- pickers and sliders are never used as visibility conditions, so we don't need to attach a callback to them.
                if item_type ~= "listbox" and item_type ~= "color_picker" and item_type ~= "multiselect" and item_type ~= "slider" and item_type ~= "button" then
                    -- Attack a callback to the item for this function.
                    ui.set_callback( v, entry.handle_visibility )
                end
            end

            -- Create a state variable unique to this item.
            local item_state = state and ui.get( items.current_tab ) == opulent.tabs[ i ]

            -- Does this item have any special visibility conditions and would we otherwise be setting it to true?
            if item_state and opulent.dependent_items[ v ] ~= nil then
                -- Save the conditions to a variable for easier access.
                local item_conditions = opulent.dependent_items[ v ]
                -- Iterate over the conditions.
                for j=1, #item_conditions do
                    -- The first member of the array is the condition, the second is what the condition must be for us to
                    -- display it. Thus, we'll compare the first member to the second and if it doesn't match, hide the item.
                    if ui.get( item_conditions[ j ][ 1 ] ) ~= item_conditions[ j ][ 2 ] then
                        item_state = false
                        break
                    end
                end
            end

            -- Set the item's visibility to the master switch value.
            ui.set_visible( v, item_state )

            -- Create a code block for item's that need to skip over this handling.
            ::continue::
        end
    end

    -- Save variables for values that we're going to repeatedly use in the builder handling.
    local builder_state = ui.get( items[ "Builder" ].state )
    local anti_aim_state = ui.get( items[ "Anti-aim" ].enabled )
    local is_tab_selected = ui.get( items.current_tab ) == "Builder"

    -- Since the items within the builder tab require special handling, we'll do that here.
    for i=1, #anti_aim.states do
        -- Create our base visibility condition: master switch, anti aim, correct state and correct tab.
        local should_be_visible = state and builder_state == anti_aim.states[ i ] and is_tab_selected and anti_aim_state
        -- Save this iteration of the builder array to a variable.
        local current_builder = items[ "Builder" ][ anti_aim.states[ i ] ]
        -- Create a variable to hold the condition of whether or not this state is enabled.
        local state_enabled = ui.get( current_builder.enabled )

        -- Iterate over each state within the builder.
        for k, v in pairs( current_builder ) do
            -- Same as above, we want to attach a callback to this item to re-run the visibility when the value changes.
            if not entry.initialized then
                -- Again, we'll avoid setting callbacks on items that will not affect visibility conditions.
                local item_type = ui.type( v )

                if item_type ~= "color_picker" and item_type ~= "multiselect" and item_type ~= "slider" then
                    ui.set_callback( v, entry.handle_visibility )
                end
            end
            
            -- Create a state variable unique to this item.
            local item_state = should_be_visible
            -- Set the item's visibility to false if it isn't the enabled button or the state itself isn't enabled.
            item_state = item_state and ( k == "enabled" or state_enabled )

            -- Run the same visibility condition handling.
            if item_state and opulent.dependent_items[ v ] ~= nil then
                local item_conditions = opulent.dependent_items[ v ]
                for j=1, #item_conditions do
                    if ui.get( item_conditions[ j ][ 1 ] ) ~= item_conditions[ j ][ 2 ] then
                        item_state = false
                        break
                    end
                end
            end

            -- Finally, set our item's visibility in accordance with the new item_state variable.
            ui.set_visible( v, item_state )
        end
    end

    -- Our tab selection isn't within a tab array so it doesn't get handled, we'll do so here instead.
    ui.set_visible( items.current_tab, state )
    ui.set_callback( items.current_tab, entry.handle_visibility )

    -- Force the default builder state to on and disable the visibility for it.
    ui.set( items[ "Builder" ][ "Default" ].enabled, true )
    ui.set_visible( items[ "Builder" ][ "Default" ].enabled, false )
end

function entry.run( )
    -- Grab our master switch value.
    local state = ui.get( items.master_switch )
    -- Create a variable that will dictate whether we're setting or unsetting events based on the master switch.
    local set_event_callback = state and client.set_event_callback or client.unset_event_callback

    -- Iterate over our bound events and their respective table of functions.
    for k, v in pairs( entry.bound_events ) do
        -- Now, iterate over that table of functions.
        for i=1, #v do
            -- Set the event callback for bound even and this function.
            set_event_callback( k, v[ i ] )
        end
    end

    -- Set a ui callback for our master switch so this re-runs every time that value is changed.
    ui.set_callback( items.master_switch, entry.run )
    -- Update our visibility.
    entry.handle_visibility( )
end

-- Run our main function via do, allows us to return without having to make a standalone function.
do
    -- Since we continue iterating even if the user is missing a library, we'll need a variable to keep track
    -- of this later on so as to not let the rest of the lua continue running.
    local missing_library = false
    -- Iterate over our libraries and their contents ( name / url ).
    for k, v in pairs( libraries ) do
        -- Use pcall to simulate the function call to see if it will fetch an error.
        if not pcall( require, "gamesense/" .. v[ 1 ] ) then
            -- We don't want to use the error function because that will break us out of the loop, rather we'll just
            -- print so that the user gets a link to every missing library, not just the first one we find.
            opulent.print( "you are missing the ", v[ 1 ], "library, please subscribe here: ", v[ 2 ] )
            -- Attempt to open the missing library URL in his browser.
            js.SteamOverlayAPI.OpenExternalBrowserURL( v[ 2 ] )
            -- We're missing a library, set the variable in accordance.
            missing_library = true
        else
            -- Using this library won't fetch an error, override our value in the array with the real thing.
            libraries[ k ] = require( "gamesense/" .. v[ 1 ] )
        end
    end

    -- Is the user missing a library?
    if missing_library then
        -- Give the user an error and return.
        error( "opulent ~ please subscribe to all missing libraries" )
        return
    end

    -- Is obex_fetch available, meaning this was run through obex?
    if obex_fetch ~= nil then
        -- Grab our user's data from obex.
        local user_data = obex_fetch( )

        -- Set our user related variables in accordance with obex.
        opulent.username = user_data.username
        opulent.version = opulent.version_names[ user_data.build ]
    end

    -- Attempt to grab our logo.
    libraries.http.get( "https://REDACTED", function( success, response )
        -- If we failed to connect or our response status wasn't 200 (successful), return.
        if not success or response.status ~= 200 then
            return
        end

        -- Save our logo data to it's respective variable.
        opulent.logo = libraries.images.load_png( response.body )
    end )

    -- Run our entry function, this will handle all the visibility and callbacks.
    entry.run( )
    -- Set a standalone paint_ui callback for our master switch handling, we want this to run regardless.
    client.set_event_callback( "paint_ui", opulent.handle_master_label )
    -- Run our config initilization.
    configs.initialize( )
end