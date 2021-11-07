#include maps/mp/gametypes_zm/_hud_util;
#include maps/mp/zombies/_zm_utility;
#include common_scripts/utility;
#include maps/mp/_utility;
#include maps/mp/zombies/_zm_powerups;
#include maps/mp/zombies/_zm_weapons;
#include maps/mp/zombies/_zm_magicbox;
#include maps/mp/zombies/_zm;
#include maps/mp/zombies/_zm_unitrigger;
#include maps/mp/zombies/_zm_utility;
#include maps/mp/zombies/_zm_blockers;
#include maps/mp/zombies/_zm_pers_upgrades_system;
#include maps/mp/zombies/_zm_perks;
#include maps/mp/zombies/_zm_stats;
#include maps/mp/zombies/_zm_pers_upgrades_functions;

main()
{ 
	level.VERSION = "0.3.9";

	replaceFunc( maps/mp/zombies/_zm_utility::set_run_speed, ::set_run_speed_override );
	replaceFunc( maps/mp/zombies/_zm_powerups::powerup_drop, ::powerup_drop_override );
	replaceFunc( maps/mp/zombies/_zm_powerups::func_should_drop_fire_sale, ::func_should_drop_fire_sale_override );
	replaceFunc( maps/mp/zombies/_zm_powerups::insta_kill_powerup, ::insta_kill_powerup_override );
	replaceFunc( maps/mp/zombies/_zm_powerups::insta_kill_on_hud, ::insta_kill_on_hud_override );
	replaceFunc( maps/mp/zombies/_zm_powerups::double_points_powerup, ::double_points_powerup_override );
	replaceFunc( maps/mp/zombies/_zm_powerups::point_doubler_on_hud, ::point_doubler_on_hud_override );
	// replaceFunc( maps/mp/zombies/_zm_magicbox::boxstub_update_prompt, ::boxstub_update_prompt_override );
    // replaceFunc( maps/mp/zombies/_zm_magicbox::treasure_chest_think, ::treasure_chest_think_override );
    // replaceFunc( maps/mp/zombies/_zm_magicbox_lock::watch_for_lock, ::watch_for_lock_override );
	replaceFunc( maps/mp/zombies/_zm::round_think, ::round_think_override );
	replaceFunc( maps/mp/zombies/_zm_utility::disable_player_move_states, ::disable_player_move_states_override );
	replaceFunc( maps/mp/zombies/_zm_magicbox::treasure_chest_weapon_spawn, ::treasure_chest_weapon_spawn_override );
	replaceFunc( maps/mp/zombies/_zm::ai_calculate_health, ::ai_calculate_health );
	replaceFunc( maps/mp/zombies/_zm_utility::get_player_weapon_limit, ::get_player_weapon_limit );
	replaceFunc( maps/mp/zombies/_zm_utility::get_player_perk_purchase_limit, ::get_player_perk_purchase_limit );
	replaceFunc( maps/mp/zombies/_zm_weapons::weapon_give, ::weapon_give );
	replaceFunc( maps/mp/zombies/_zm_powerups::full_ammo_powerup, ::full_ammo_powerup );

	register_weapon_mods();

    level.inital_spawn = true;
    level thread onConnect();
}
onConnect()
{
    for (;;)
    {
        level waittill("connected", player);
        player thread connected();
    }
}
connected()
{
    level endon( "game_ended" );
    self endon("disconnect");

    self.initial_spawn = true;

    for(;;)
    {
        self waittill("spawned_player");

		// testing
		// self thread give_all_perks();
		// self thread give_weapons();

    	if(self.initial_spawn)
		{
            self.initial_spawn = false;

			self iprintln("Welcome to Remix!");
			self iPrintLn("Version " + level.VERSION);
       		self setClientDvar( "com_maxfps", 101 );

			self graphic_tweaks();
			self set_movement_dvars();
			self set_players_score();
			self set_character_option();

        	self thread timer_hud();
			self thread health_bar_hud();
			self thread max_ammo_refill_clip();
			self thread carpenter_repair_shield();
			self thread inspect_weapon();
			self thread give_perma_perks();
			self thread give_bank_fridge();
			self thread mulekick_additional_perks();
        }

        if(level.inital_spawn)
		{
			level.inital_spawn = false;

			when_fire_sales_should_drop();

			level thread coop_pause();
			level thread fake_reset();
			// level thread shared_magic_box();
			level thread zombie_health_fix();

			flag_wait( "start_zombie_round_logic" );
   			wait 0.05;

			wallbuy_increase_trigger_radius();
			level thread wallbuy_dynamic_increase_trigger_radius();

			switch( getDvar("mapname") )
			{
				case "zm_transit":
					self thread jetgun_buff();
				case "zm_nuked":
				case "zm_highrise":
					slipgun_disable_reslip();
					slipgun_always_kill();
					die_rise_zone_changes();
				case "zm_prison":
				case "zm_buried":
				case "zm_tomb":
			}
		}
	}
}


/*
* *****************************************************
*	
* ********************* Overrides **********************
*
* *****************************************************
*/

set_run_speed_override()
{
	self.zombie_move_speed = "sprint";
}

powerup_drop_override( drop_point ) //checked partially changed to match cerberus output
{
	if ( level.powerup_drop_count >= level.zombie_vars[ "zombie_powerup_drop_max_per_round" ] )
	{
		return;
	}
	if ( !isDefined( level.zombie_include_powerups ) || level.zombie_include_powerups.size == 0 )
	{
		return;
	}
	rand_drop = randomint( 100 );
	if ( rand_drop > 3 ) // 2 -> 3
	{
		if ( !level.zombie_vars[ "zombie_drop_item" ] )
		{
			return;
		}
		debug = "score";
	}
	else
	{
		debug = "random";
	}
	playable_area = getentarray( "player_volume", "script_noteworthy" );
	level.powerup_drop_count++;
	powerup = maps/mp/zombies/_zm_net::network_safe_spawn( "powerup", 1, "script_model", drop_point + vectorScale( ( 0, 0, 1 ), 40 ) );
	valid_drop = 0;
	for ( i = 0; i < playable_area.size; i++ )
	{
		if ( powerup istouching( playable_area[ i ] ) )
		{
			valid_drop = 1;
			break;
		}
	}
	if ( valid_drop && level.rare_powerups_active )
	{
		pos = ( drop_point[ 0 ], drop_point[ 1 ], drop_point[ 2 ] + 42 );
		if ( check_for_rare_drop_override( pos ) )
		{
			level.zombie_vars[ "zombie_drop_item" ] = 0;
			valid_drop = 0;
		}
	}
	if ( !valid_drop )
	{
		level.powerup_drop_count--;

		powerup delete();
		return;
	}
	powerup powerup_setup();
	print_powerup_drop( powerup.powerup_name, debug );
	powerup thread powerup_timeout();
	powerup thread powerup_wobble();
	powerup thread powerup_grab();
	powerup thread powerup_move();
	powerup thread powerup_emp();
	level.zombie_vars[ "zombie_drop_item" ] = 0;
	level notify( "powerup_dropped" );
}

insta_kill_powerup_override( drop_item, player ) //checked matches cerberus output
{
	level notify( "powerup instakill_" + player.team );
	level endon( "powerup instakill_" + player.team );
	if ( isDefined( level.insta_kill_powerup_override ) )
	{
		level thread [[ level.insta_kill_powerup_override ]]( drop_item, player );
		return;
	}
	if ( is_classic() )
	{
		player thread maps/mp/zombies/_zm_pers_upgrades_functions::pers_upgrade_insta_kill_upgrade_check();
	}
	team = player.team;
	level thread insta_kill_on_hud( drop_item, team );
	level.zombie_vars[ team ][ "zombie_insta_kill" ] = 1;
	wait level.zombie_vars[ team ][ "zombie_powerup_insta_kill_time" ];
	//wait 30;
	level.zombie_vars[ team ][ "zombie_insta_kill" ] = 0;
	players = get_players( team );
	i = 0;
	while ( i < players.size )
	{
		if ( isDefined( players[ i ] ) )
		{
			players[ i ] notify( "insta_kill_over" );
		}
		i++;
	}
}

insta_kill_on_hud_override( drop_item, player_team ) //checked matches cerberus output
{
	if ( level.zombie_vars[ player_team ][ "zombie_powerup_insta_kill_on" ] )
	{
		level.zombie_vars[ player_team ][ "zombie_powerup_insta_kill_time" ] += 30;
		return;
	} 
	else
	{
		level.zombie_vars[ player_team ][ "zombie_powerup_insta_kill_time" ] = 30;
	}
	level.zombie_vars[ player_team ][ "zombie_powerup_insta_kill_on" ] = 1;
	level thread time_remaning_on_insta_kill_powerup( player_team );
}

double_points_powerup_override( drop_item, player ) //checked partially matches cerberus output did not change
{
	level notify( "powerup points scaled_" + player.team );
	level endon( "powerup points scaled_" + player.team );
	team = player.team;
	level thread point_doubler_on_hud( drop_item, team );
	if ( is_true( level.pers_upgrade_double_points ) )
	{
		player thread maps/mp/zombies/_zm_pers_upgrades_functions::pers_upgrade_double_points_pickup_start();
	}
	if ( isDefined( level.current_game_module ) && level.current_game_module == 2 )
	{
		if ( isDefined( player._race_team ) )
		{
			if ( player._race_team == 1 )
			{
				level._race_team_double_points = 1;
			}
			else
			{
				level._race_team_double_points = 2;
			}
		}
	}
	level.zombie_vars[ team ][ "zombie_point_scalar" ] = 2;
	players = get_players();
	for ( player_index = 0; player_index < players.size; player_index++ )
	{
		if ( team == players[ player_index ].team )
		{
			players[ player_index ] setclientfield( "score_cf_double_points_active", 1 );
		}
	}
	//wait 30;
	wait level.zombie_vars[ team ][ "zombie_powerup_point_doubler_time" ];
	level.zombie_vars[ team ][ "zombie_point_scalar" ] = 1;
	level._race_team_double_points = undefined;
	players = get_players();
	for ( player_index = 0; player_index < players.size; player_index++ )
	{
		if ( team == players[ player_index ].team )
		{
			players[ player_index ] setclientfield( "score_cf_double_points_active", 0 );
		}
	}
}

point_doubler_on_hud_override( drop_item, player_team ) //checked matches cerberus output
{
	self endon( "disconnect" );
	if ( level.zombie_vars[ player_team ][ "zombie_powerup_point_doubler_on" ] )
	{
		level.zombie_vars[ player_team ][ "zombie_powerup_point_doubler_time" ] += 30;
		return;
	}
	else
	{
		level.zombie_vars[ player_team ][ "zombie_powerup_point_doubler_time" ] = 30;
	}
	level.zombie_vars[ player_team ][ "zombie_powerup_point_doubler_on" ] = 1;
	level thread time_remaining_on_point_doubler_powerup( player_team );
}

boxstub_update_prompt_override( player )
{
    self setcursorhint( "HINT_NOICON" );
    if(!self trigger_visible_to_player( player ))
    {
        if(level.shared_box)
        {
            self setvisibletoplayer( player );
            self.hint_string = get_hint_string( self, "default_shared_box" );
            return 1;
        }
        return 0;
    }
    self.hint_parm1 = undefined;
    if ( isDefined( self.stub.trigger_target.grab_weapon_hint ) && self.stub.trigger_target.grab_weapon_hint )
    {
        if(level.shared_box)
        {
            self.hint_string = get_hint_string( self, "default_shared_box" );
        }    
        else
        {
            if (isDefined( level.magic_box_check_equipment ) && [[ level.magic_box_check_equipment ]]( self.stub.trigger_target.grab_weapon_name ) )
            {
				if(level.players.size < 2)
					self.hint_string = "Hold ^3&&1^7 for Equipment";
				else
                	self.hint_string = "Hold ^3&&1^7 for Equipment ^1or ^7Press ^3[{+melee}]^7 for teammates to pick it up";
            }
            else 
            {
				if(level.players.size < 2)
					self.hint_string = "Hold ^3&&1^7 for Weapon";
				else
                	self.hint_string = "Hold ^3&&1^7 for Weapon ^1or ^7Press ^3[{+melee}]^7 for teammates to pick it up";
            }
        }
    }
    else
    {
        if ( isDefined( level.using_locked_magicbox ) && level.using_locked_magicbox && isDefined( self.stub.trigger_target.is_locked ) && self.stub.trigger_target.is_locked )
        {
            self.hint_string = get_hint_string( self, "locked_magic_box_cost" );
        }
        else
        {
            self.hint_parm1 = self.stub.trigger_target.zombie_cost;
            self.hint_string = get_hint_string( self, "default_treasure_chest" );
        }
    }
    return 1;
}

treasure_chest_think_override()
{
	self endon( "kill_chest_think" );
	user = undefined;
	user_cost = undefined;
	self.box_rerespun = undefined;
	self.weapon_out = undefined;
	self thread unregister_unitrigger_on_kill_think();
	while ( 1 )
	{
		if ( !isdefined( self.forced_user ) )
		{
			self waittill( "trigger", user );
			if ( user == level )
			{
				wait 0.1;
				continue;
			}
		}
		else
		{
			user = self.forced_user;
		}
		if ( user in_revive_trigger() )
		{
			wait 0.1;
			continue;
		}
		if ( user.is_drinking > 0 )
		{
			wait 0.1;
			continue;
		}
		if ( isdefined( self.disabled ) && self.disabled )
		{
			wait 0.1;
			continue;
		}
		if ( user getcurrentweapon() == "none" )
		{
			wait 0.1;
			continue;
		}
		reduced_cost = undefined;
		if ( is_player_valid( user ) && user maps/mp/zombies/_zm_pers_upgrades_functions::is_pers_double_points_active() )
		{
			reduced_cost = int( self.zombie_cost / 2 );
		}
		if ( isdefined( level.using_locked_magicbox ) && level.using_locked_magicbox && isdefined( self.is_locked ) && self.is_locked ) 
		{
			if ( user.score >= level.locked_magic_box_cost )
			{
				user maps/mp/zombies/_zm_score::minus_to_player_score( level.locked_magic_box_cost );
				self.zbarrier set_magic_box_zbarrier_state( "unlocking" );
				self.unitrigger_stub run_visibility_function_for_all_triggers();
			}
			else
			{
				user maps/mp/zombies/_zm_audio::create_and_play_dialog( "general", "no_money_box" );
			}
			wait 0.1 ;
			continue;
		}
		else if ( isdefined( self.auto_open ) && is_player_valid( user ) )
		{
			if ( !isdefined( self.no_charge ) )
			{
				user maps/mp/zombies/_zm_score::minus_to_player_score( self.zombie_cost );
				user_cost = self.zombie_cost;
			}
			else
			{
				user_cost = 0;
			}
			self.chest_user = user;
			break;
		}
		else if ( is_player_valid( user ) && user.score >= self.zombie_cost )
		{
			user maps/mp/zombies/_zm_score::minus_to_player_score( self.zombie_cost );
			user_cost = self.zombie_cost;
			self.chest_user = user;
			break;
		}
		else if ( isdefined( reduced_cost ) && user.score >= reduced_cost )
		{
			user maps/mp/zombies/_zm_score::minus_to_player_score( reduced_cost );
			user_cost = reduced_cost;
			self.chest_user = user;
			break;
		}
		else if ( user.score < self.zombie_cost )
		{
			play_sound_at_pos( "no_purchase", self.origin );
			user maps/mp/zombies/_zm_audio::create_and_play_dialog( "general", "no_money_box" );
			wait 0.1;
			continue;
		}
		wait 0.05;
	}
	flag_set( "chest_has_been_used" );
	maps/mp/_demo::bookmark( "zm_player_use_magicbox", getTime(), user );
	user maps/mp/zombies/_zm_stats::increment_client_stat( "use_magicbox" );
	user maps/mp/zombies/_zm_stats::increment_player_stat( "use_magicbox" );
	if ( isDefined( level._magic_box_used_vo ) )
	{
		user thread [[ level._magic_box_used_vo ]]();
	}
	self thread watch_for_emp_close();
	if ( isDefined( level.using_locked_magicbox ) && level.using_locked_magicbox )
	{
		self thread maps/mp/zombies/_zm_magicbox_lock::watch_for_lock();
	}
	self._box_open = 1;
	level.box_open = 1;
	self._box_opened_by_fire_sale = 0;
	if ( isDefined( level.zombie_vars[ "zombie_powerup_fire_sale_on" ] ) && level.zombie_vars[ "zombie_powerup_fire_sale_on" ] && !isDefined( self.auto_open ) && self [[ level._zombiemode_check_firesale_loc_valid_func ]]() )
	{
		self._box_opened_by_fire_sale = 1;
	}
	if ( isDefined( self.chest_lid ) )
	{
		self.chest_lid thread treasure_chest_lid_open();
	}
	if ( isDefined( self.zbarrier ) )
	{
		play_sound_at_pos( "open_chest", self.origin );
		play_sound_at_pos( "music_chest", self.origin );
		self.zbarrier set_magic_box_zbarrier_state( "open" );
	}
	self.timedout = 0;
	self.weapon_out = 1;
	self.zbarrier thread treasure_chest_weapon_spawn( self, user );
	self.zbarrier thread treasure_chest_glowfx();
	thread maps/mp/zombies/_zm_unitrigger::unregister_unitrigger( self.unitrigger_stub );
	self.zbarrier waittill_any( "randomization_done", "box_hacked_respin" );
	if ( flag( "moving_chest_now" ) && !self._box_opened_by_fire_sale && isDefined( user_cost ) )
	{
		user maps/mp/zombies/_zm_score::add_to_player_score( user_cost, 0 );
	}
	if ( flag( "moving_chest_now" ) && !level.zombie_vars[ "zombie_powerup_fire_sale_on" ] && !self._box_opened_by_fire_sale )
	{
		self thread treasure_chest_move( self.chest_user );
	}
	else
	{
		self.grab_weapon_hint = 1;
		self.grab_weapon_name = self.zbarrier.weapon_string;
		self.chest_user = user;
		thread maps/mp/zombies/_zm_unitrigger::register_static_unitrigger( self.unitrigger_stub, ::magicbox_unitrigger_think );
		if ( isDefined( self.zbarrier ) && !is_true( self.zbarrier.closed_by_emp ) )
		{
			self thread treasure_chest_timeout();
		}
		timeout_time = 105;
		grabber = user;
		for( i=0;i<105;i++ )
		{
			if(user meleeButtonPressed() && isplayer( user ) && distance(self.origin, user.origin) <= 100)
			{
				level.magic_box_grab_by_anyone = 1;
				level.shared_box = 1;
				self.unitrigger_stub run_visibility_function_for_all_triggers();
				for( a=i;a<105;a++ )
				{
					foreach(player in level.players)
					{
						if(player usebuttonpressed() && distance(self.origin, player.origin) <= 100 && isDefined( player.is_drinking ) && !player.is_drinking)
						{
						
							player thread treasure_chest_give_weapon( self.zbarrier.weapon_string );
							a = 105;
							break;
						}
					}
					wait 0.1;
				}
				break;
			}
			if(grabber usebuttonpressed() && isplayer( grabber ) && user == grabber && distance(self.origin, grabber.origin) <= 100 && isDefined( grabber.is_drinking ) && !grabber.is_drinking)
			{
				grabber thread treasure_chest_give_weapon( self.zbarrier.weapon_string );
				break;
			}
			wait 0.1;
		}
		self.weapon_out = undefined;
		self notify( "user_grabbed_weapon" );
		user notify( "user_grabbed_weapon" );
		self.grab_weapon_hint = 0;
		self.zbarrier notify( "weapon_grabbed" );
		if ( isDefined( self._box_opened_by_fire_sale ) && !self._box_opened_by_fire_sale )
		{
			level.chest_accessed += 1;
		}
		if ( level.chest_moves > 0 && isDefined( level.pulls_since_last_ray_gun ) )
		{
			level.pulls_since_last_ray_gun += 1;
		}
		thread maps/mp/zombies/_zm_unitrigger::unregister_unitrigger( self.unitrigger_stub );
		if ( isDefined( self.chest_lid ) )
		{
			self.chest_lid thread treasure_chest_lid_close( self.timedout );
		}
		if ( isDefined( self.zbarrier ) )
		{
			self.zbarrier set_magic_box_zbarrier_state( "close" );
			play_sound_at_pos( "close_chest", self.origin );
			self.zbarrier waittill( "closed" );
			wait 1;
		}
		else
		{
			wait 3;
		}
		if ( isDefined( level.zombie_vars[ "zombie_powerup_fire_sale_on" ] ) && level.zombie_vars[ "zombie_powerup_fire_sale_on" ] || self [[ level._zombiemode_check_firesale_loc_valid_func ]]() || self == level.chests[ level.chest_index ] )
		{
			thread maps/mp/zombies/_zm_unitrigger::register_static_unitrigger( self.unitrigger_stub, ::magicbox_unitrigger_think );
		}
	}
	self._box_open = 0;
	level.box_open = 0;
	level.shared_box = 0;
	level.magic_box_grab_by_anyone = 0;
	self._box_opened_by_fire_sale = 0;
	self.chest_user = undefined;
	self notify( "chest_accessed" );
	self thread treasure_chest_think_override();
}

watch_for_lock_override()
{
    self endon( "user_grabbed_weapon" );
    self endon( "chest_accessed" );
    self waittill( "box_locked" );
    self notify( "kill_chest_think" );
    self.grab_weapon_hint = 0;
    wait 0.1;
    self thread maps/mp/zombies/_zm_unitrigger::register_static_unitrigger( self.unitrigger_stub, ::magicbox_unitrigger_think );
    self.unitrigger_stub run_visibility_function_for_all_triggers();
    self thread treasure_chest_think_override();
}

round_think_override( restart ) //checked changed to match cerberus output
{
	if ( !isDefined( restart ) )
	{
		restart = 0;
	}
	level endon( "end_round_think" );
	if ( !is_true( restart ) )
	{
		if ( isDefined( level.initial_round_wait_func ) )
		{
			[[ level.initial_round_wait_func ]]();
		}
		players = get_players();
		foreach ( player in players )
		{
			if ( is_true( player.hostmigrationcontrolsfrozen ) ) 
			{
				player freezecontrols( 0 );
			}
			player maps/mp/zombies/_zm_stats::set_global_stat( "rounds", level.round_number );
		}
	}
	setroundsplayed( level.round_number );
	for ( ;; )
	{
		maxreward = 50 * level.round_number;
		if ( maxreward > 500 )
		{
			maxreward = 500;
		}
		level.zombie_vars[ "rebuild_barrier_cap_per_round" ] = maxreward;
		level.pro_tips_start_time = getTime();
		level.zombie_last_run_time = getTime();
		if ( isDefined( level.zombie_round_change_custom ) )
		{
			[[ level.zombie_round_change_custom ]]();
		}
		else
		{
			level thread maps/mp/zombies/_zm_audio::change_zombie_music( "round_start" );
			round_one_up();
		}
		maps/mp/zombies/_zm_powerups::powerup_round_start();
		players = get_players();
		array_thread( players, ::rebuild_barrier_reward_reset );
		if ( !is_true( level.headshots_only ) && !restart )
		{
			level thread award_grenades_for_survivors();
		}
		level.round_start_time = getTime();
		while ( level.zombie_spawn_locations.size <= 0 )
		{
			wait 0.1;
		}
		level thread [[ level.round_spawn_func ]]();
		level notify( "start_of_round" );
		recordzombieroundstart();
		players = getplayers();
		for ( index = 0; index < players.size; index++  )
		{
			zonename = players[ index ] get_current_zone();
			if ( isDefined( zonename ) )
			{
				players[ index ] recordzombiezone( "startingZone", zonename );
			}
		}
		if ( isDefined( level.round_start_custom_func ) )
		{
			[[ level.round_start_custom_func ]]();
		}
		[[ level.round_wait_func ]]();
		level.first_round = 0;
		level notify( "end_of_round" );
		level thread maps/mp/zombies/_zm_audio::change_zombie_music( "round_end" );
		uploadstats();
		if ( isDefined( level.round_end_custom_logic ) )
		{
			[[ level.round_end_custom_logic ]]();
		}
		players = get_players();
		if ( is_true( level.no_end_game_check ) )
		{
			level thread last_stand_revive();
			level thread spectators_respawn();
		}
		else if ( players.size != 1 )
		{
			level thread spectators_respawn();
		}
		players = get_players();
		array_thread( players, ::round_end );
		timer = level.zombie_vars[ "zombie_spawn_delay" ];
		if ( timer > 0.08 )
		{
			level.zombie_vars[ "zombie_spawn_delay" ] = timer * 0.95;
		}
		else if ( timer < 0.08 )
		{
			level.zombie_vars[ "zombie_spawn_delay" ] = 0.08;
		}
		if ( level.gamedifficulty == 0 )
		{
			level.zombie_move_speed = level.round_number * level.zombie_vars[ "zombie_move_speed_multiplier_easy" ];
		}
		else
		{
			level.zombie_move_speed = level.round_number * level.zombie_vars[ "zombie_move_speed_multiplier" ];
		}
		level.round_number++;
		// if ( level.round_number >= 255 )
		// {
		// 	level.round_number = 255;
		// }
		setroundsplayed( level.round_number );
		matchutctime = getutc();
		players = get_players();
		foreach ( player in players )
		{
			if ( level.curr_gametype_affects_rank && level.round_number > 3 + level.start_round )
			{
				player maps/mp/zombies/_zm_stats::add_client_stat( "weighted_rounds_played", level.round_number );
			}
			player maps/mp/zombies/_zm_stats::set_global_stat( "rounds", level.round_number );
			player maps/mp/zombies/_zm_stats::update_playing_utc_time( matchutctime );
		}
		check_quickrevive_for_hotjoin(); //was commented out
		level round_over();
		level notify( "between_round_over" );
		restart = 0;
	}
}

disable_player_move_states_override( forcestancechange ) //checked matches cerberus output
{
	self allowcrouch( 1 );
	self allowlean( 0 );
	self allowads( 0 );
	self allowsprint( 1 );
	self allowprone( 0 );
	self allowmelee( 0 );
	if ( isDefined( forcestancechange ) && forcestancechange == 1 )
	{
		if ( self getstance() == "prone" )
		{
			self setstance( "crouch" );
		}
	}
}

treasure_chest_weapon_spawn_override( chest, player, respin ) //checked changed to match cerberus output
{
	if ( is_true( level.using_locked_magicbox ) )
	{
		self.owner endon( "box_locked" );
		self thread maps/mp/zombies/_zm_magicbox_lock::clean_up_locked_box();
	}
	self endon( "box_hacked_respin" );
	self thread clean_up_hacked_box();
	/*
/#
	assert( isDefined( player ) );
#/
	*/
	self.weapon_string = undefined;
	modelname = undefined;
	rand = undefined;
	number_cycles = 40;
	if ( isDefined( chest.zbarrier ) )
	{
		if ( isDefined( level.custom_magic_box_do_weapon_rise ) )
		{
			chest.zbarrier thread [[ level.custom_magic_box_do_weapon_rise ]]();
		}
		else
		{
			chest.zbarrier thread magic_box_do_weapon_rise();
		}
	}
	for ( i = 0; i < number_cycles; i++ )
	{

		if ( i < 20 )
		{
			wait 0.05 ; 
		}
		else if ( i < 30 )
		{
			wait 0.1 ; 
		}
		else if ( i < 35 )
		{
			wait 0.2 ; 
		}
		else if ( i < 38 )
		{
			wait 0.3 ; 
		}
	}
	if ( isDefined( level.custom_magic_box_weapon_wait ) )
	{
		[[ level.custom_magic_box_weapon_wait ]]();
	}
	if ( is_true( player.pers_upgrades_awarded[ "box_weapon" ] ) )
	{
		rand = maps/mp/zombies/_zm_pers_upgrades_functions::pers_treasure_chest_choosespecialweapon( player );
	}
	else
	{
		rand = treasure_chest_chooseweightedrandomweapon( player );
	}

	// first box
	if ( !isDefined(level.chest_max_move_usage) )
	{
		level.chest_max_move_usage = 8;
		
	}
	if ( !isDefined(level.weapons_needed) )
	{
		level.weapons_needed = 1 + level.players.size;
	}

	ran = randomInt( (level.chest_max_move_usage - level.weapons_needed) - level.chest_accessed );
	if ( ran == 0 && level.chest_accessed <= level.chest_max_move_usage && level.chest_moves == 0 )
	{	
		pap_triggers = getentarray( "specialty_weapupgrade", "script_noteworthy" );

		if ( treasure_chest_canplayerreceiveweapon( player, "raygun_mark2_zm", pap_triggers ) )
		{
			rand = "raygun_mark2_zm";
		}
		else if( treasure_chest_canplayerreceiveweapon( player, "ray_gun_zm", pap_triggers ) )
		{
			rand = "ray_gun_zm";
		}
		else if( treasure_chest_canplayerreceiveweapon( player, "cymbal_monkey_zm", pap_triggers ) && getDvar("mapname") != "zm_prison")
		{
			rand = "cymbal_monkey_zm";
		}
		else if( treasure_chest_canplayerreceiveweapon( player, "blundergat_zm", pap_triggers ) && getDvar("mapname") == "zm_prison")
		{
			rand = "blundergat_zm";
		}
		else if( treasure_chest_canplayerreceiveweapon( player, "emp_grenade_zm", pap_triggers ) && getDvar("mapname") == "zm_transit" && is_classic() )
		{
			rand = "emp_grenade_zm";
		}
		else if( treasure_chest_canplayerreceiveweapon( player, "m32_zm", pap_triggers ) && getDvar("mapname") == "zm_tomb")
		{
			rand = "m32_zm";
		}

		if( level.weapons_needed != 0 )
			level.weapons_needed--;
	}

	
	self.weapon_string = rand;
	wait 0.1;
	if ( isDefined( level.custom_magicbox_float_height ) )
	{
		v_float = anglesToUp( self.angles ) * level.custom_magicbox_float_height;
	}
	else
	{
		v_float = anglesToUp( self.angles ) * 40;
	}
	self.model_dw = undefined;
	self.weapon_model = spawn_weapon_model( rand, undefined, self.origin + v_float, self.angles + vectorScale( ( 0, 1, 0 ), 180 ) );
	if ( weapon_is_dual_wield( rand ) )
	{
		self.weapon_model_dw = spawn_weapon_model( rand, get_left_hand_weapon_model_name( rand ), self.weapon_model.origin - vectorScale( ( 0, 1, 0 ), 3 ), self.weapon_model.angles );
	}
	if ( getDvar( "magic_chest_movable" ) == "1" && !is_true( chest._box_opened_by_fire_sale ) && !is_true( level.zombie_vars[ "zombie_powerup_fire_sale_on" ] ) && self [[ level._zombiemode_check_firesale_loc_valid_func ]]() )
	{
		random = randomint( 100 );
		if ( !isDefined( level.chest_min_move_usage ) )
		{
			level.chest_min_move_usage = 4;
		}
		if ( level.chest_accessed < level.chest_min_move_usage )
		{
			chance_of_joker = -1;
		}
		else
		{
			chance_of_joker = level.chest_accessed + 20;
			if ( level.chest_moves == 0 && level.chest_accessed >= level.chest_max_move_usage )
			{
				chance_of_joker = 100;
			}
			if ( level.chest_accessed >= 4 && level.chest_accessed < 8 )
			{
				if ( random < 15 && level.weapons_needed == 0 ) // always get mark2 and monkeys before the box moves
				{
					chance_of_joker = 100;
				}
				else
				{
					chance_of_joker = -1;
				}
			}
			if ( level.chest_moves > 0 )
			{
				if ( level.chest_accessed >= 8 && level.chest_accessed < 13 )
				{
					if ( random < 30 )
					{
						chance_of_joker = 100;
					}
					else
					{
						chance_of_joker = -1;
					}
				}
				if ( level.chest_accessed >= 13 )
				{
					if ( random < 50 )
					{
						chance_of_joker = 100;
					}
					else
					{
						chance_of_joker = -1;
					}
				}
			}
		}
		if ( isDefined( chest.no_fly_away ) )
		{
			chance_of_joker = -1;
		}
		if ( isDefined( level._zombiemode_chest_joker_chance_override_func ) )
		{
			chance_of_joker = [[ level._zombiemode_chest_joker_chance_override_func ]]( chance_of_joker );
		}
		if ( chance_of_joker > random )
		{
			self.weapon_string = undefined;
			self.weapon_model setmodel( level.chest_joker_model );
			self.weapon_model.angles = self.angles + vectorScale( ( 0, 1, 0 ), 90 );
			if ( isDefined( self.weapon_model_dw ) )
			{
				self.weapon_model_dw delete();
				self.weapon_model_dw = undefined;
			}
			self.chest_moving = 1;
			flag_set( "moving_chest_now" );
			level.chest_accessed = 0;
			level.chest_moves++;
		}
	}
	self notify( "randomization_done" );
	if ( flag( "moving_chest_now" ) && !level.zombie_vars[ "zombie_powerup_fire_sale_on" ] && self [[ level._zombiemode_check_firesale_loc_valid_func ]]() )
	{
		if ( isDefined( level.chest_joker_custom_movement ) )
		{
			self [[ level.chest_joker_custom_movement ]]();
		}
		else
		{
			wait 0.5;
			level notify( "weapon_fly_away_start" );
			wait 2;
			if ( isDefined( self.weapon_model ) )
			{
				v_fly_away = self.origin + ( anglesToUp( self.angles ) * 500 );
				self.weapon_model moveto( v_fly_away, 4, 3 );
			}
			if ( isDefined( self.weapon_model_dw ) )
			{
				v_fly_away = self.origin + ( anglesToUp( self.angles ) * 500 );
				self.weapon_model_dw moveto( v_fly_away, 4, 3 );
			}
			self.weapon_model waittill( "movedone" );
			self.weapon_model delete();
			if ( isDefined( self.weapon_model_dw ) )
			{
				self.weapon_model_dw delete();
				self.weapon_model_dw = undefined;
			}
			self notify( "box_moving" );
			level notify( "weapon_fly_away_end" );
		}
	}
	else
	{
		acquire_weapon_toggle( rand, player );
		if ( rand == "tesla_gun_zm" || rand == "ray_gun_zm" )
		{
			if ( rand == "ray_gun_zm" )
			{
				level.pulls_since_last_ray_gun = 0;
			}
			if ( rand == "tesla_gun_zm" )
			{
				level.pulls_since_last_tesla_gun = 0;
				level.player_seen_tesla_gun = 1;
			}
		}
		if ( !isDefined( respin ) )
		{
			if ( isDefined( chest.box_hacks[ "respin" ] ) )
			{
				self [[ chest.box_hacks[ "respin" ] ]]( chest, player );
			}
		}
		else
		{
			if ( isDefined( chest.box_hacks[ "respin_respin" ] ) )
			{
				self [[ chest.box_hacks[ "respin_respin" ] ]]( chest, player );
			}
		}
		if ( isDefined( level.custom_magic_box_timer_til_despawn ) )
		{
			self.weapon_model thread [[ level.custom_magic_box_timer_til_despawn ]]( self );
		}
		else
		{
			self.weapon_model thread timer_til_despawn( v_float );
		}
		if ( isDefined( self.weapon_model_dw ) )
		{
			if ( isDefined( level.custom_magic_box_timer_til_despawn ) )
			{
				self.weapon_model_dw thread [[ level.custom_magic_box_timer_til_despawn ]]( self );
			}
			else
			{
				self.weapon_model_dw thread timer_til_despawn( v_float );
			}
		}
		self waittill( "weapon_grabbed" );
		if ( !chest.timedout )
		{
			if ( isDefined( self.weapon_model ) )
			{
				self.weapon_model delete();
			}
			if ( isDefined( self.weapon_model_dw ) )
			{
				self.weapon_model_dw delete();
			}
		}
	}
	self.weapon_string = undefined;
	self notify( "box_spin_done" );
}

ai_calculate_health( round_number ) //checked changed to match cerberus output
{
	// insta kill rounds staring at 99 then every 2 rounds after
	if(round_number >= 99 && round_number % 2 == 1)
	{
		level.zombie_health = 150;
		return;
	}

	// more linearly health formula - health is about the same at 70 
	if( level.round_number > 50 )
	{	
		round = (round_number - 50);
		multiplier = 1;
		zombie_health = 0;

		for( i = 0; i < round; i++ )
		{
			if( round % 5 == 0)
			{
				multiplier++;
			}
			zombie_health += int(5000 * multiplier);
		}
		level.zombie_health = int(zombie_health + 51780); // round 51 zombies health
	}
	else
	{
		level.zombie_health = level.zombie_vars[ "zombie_health_start" ];
		for ( i = 2; i <= round_number; i++ )
		{
			if ( i >= 10 )
			{
				old_health = level.zombie_health;
				level.zombie_health = level.zombie_health + int( level.zombie_health * level.zombie_vars[ "zombie_health_increase_multiplier" ] );
				if ( level.zombie_health < old_health )
				{
					level.zombie_health = old_health;
					return;
				}
				continue;
			}
			level.zombie_health = int( level.zombie_health + level.zombie_vars[ "zombie_health_increase" ] );
		}
	}
}

get_player_weapon_limit( player ) //checked matches cerberus output
{
	if ( isDefined( level.get_player_weapon_limit ) )
	{
		return [[ level.get_player_weapon_limit ]]( player );
	}
	weapon_limit = 3;

	return weapon_limit;
}

get_player_perk_purchase_limit() //checked matches cerberus output
{
	if ( isDefined( level.get_player_perk_purchase_limit ) )
	{
		return self [[ level.get_player_perk_purchase_limit ]]();
	}
	if( level.perk_purchase_limit <= 4 )
		level.perk_purchase_limit = 5;

	return level.perk_purchase_limit;
}

weapon_give( weapon, is_upgrade, magic_box, nosound ) //checked changed to match cerberus output
{
	primaryweapons = self getweaponslistprimaries();
	current_weapon = self getcurrentweapon();
	current_weapon = self maps/mp/zombies/_zm_weapons::switch_from_alt_weapon( current_weapon );
	if ( !isDefined( is_upgrade ) )
	{
		is_upgrade = 0;
	}
	weapon_limit = get_player_weapon_limit( self );
	if ( is_equipment( weapon ) )
	{
		self maps/mp/zombies/_zm_equipment::equipment_give( weapon );
	}
	if ( weapon == "riotshield_zm" )
	{
		if ( isDefined( self.player_shield_reset_health ) )
		{
			self [[ self.player_shield_reset_health ]]();
		}
	}
	if ( self hasweapon( weapon ) )
	{
		if ( issubstr( weapon, "knife_ballistic_" ) )
		{
			self notify( "zmb_lost_knife" );
		}
		self givestartammo( weapon );
		if ( !is_offhand_weapon( weapon ) )
		{
			self switchtoweapon( weapon );
		}
		return;
	}
	if ( is_melee_weapon( weapon ) )
	{
		current_weapon = maps/mp/zombies/_zm_melee_weapon::change_melee_weapon( weapon, current_weapon );
	}
	else if ( is_lethal_grenade( weapon ) )
	{
		old_lethal = self get_player_lethal_grenade();
		if ( isDefined( old_lethal ) && old_lethal != "" )
		{
			self takeweapon( old_lethal );
			unacquire_weapon_toggle( old_lethal );
		}
		self set_player_lethal_grenade( weapon );
	}
	else if ( is_tactical_grenade( weapon ) )
	{
		old_tactical = self get_player_tactical_grenade();
		if ( isDefined( old_tactical ) && old_tactical != "" )
		{
			self takeweapon( old_tactical );
			unacquire_weapon_toggle( old_tactical );
		}
		self set_player_tactical_grenade( weapon );
	}
	else if ( is_placeable_mine( weapon ) )
	{
		old_mine = self get_player_placeable_mine();
		if ( isDefined( old_mine ) )
		{
			self takeweapon( old_mine );
			unacquire_weapon_toggle( old_mine );
		}
		self set_player_placeable_mine( weapon );
	}
	if ( !is_offhand_weapon( weapon ) )
	{
		self maps/mp/zombies/_zm_weapons::take_fallback_weapon();
	}
	if ( primaryweapons.size >= weapon_limit )
	{
		if ( is_placeable_mine( current_weapon ) || is_equipment( current_weapon ) )
		{
			current_weapon = undefined;
		}
		if ( isDefined( current_weapon ) )
		{
			if ( !is_offhand_weapon( weapon ) )
			{
				if ( current_weapon == "tesla_gun_zm" )
				{
					level.player_drops_tesla_gun = 1;
				}
				if ( issubstr( current_weapon, "knife_ballistic_" ) )
				{
					self notify( "zmb_lost_knife" );
				}
				self takeweapon( current_weapon );
				unacquire_weapon_toggle( current_weapon );
			}
		}
	}
	if ( isDefined( level.zombiemode_offhand_weapon_give_override ) )
	{
		if ( self [[ level.zombiemode_offhand_weapon_give_override ]]( weapon ) )
		{
			return;
		}
	}
	if ( weapon == "cymbal_monkey_zm" )
	{
		self maps/mp/zombies/_zm_weap_cymbal_monkey::player_give_cymbal_monkey();
		self play_weapon_vo( weapon, magic_box );
		return;
	}
	else if ( issubstr( weapon, "knife_ballistic_" ) )
	{
		weapon = self maps/mp/zombies/_zm_melee_weapon::give_ballistic_knife( weapon, issubstr( weapon, "upgraded" ) );
	}
	else if ( weapon == "claymore_zm" )
	{
		self thread maps/mp/zombies/_zm_weap_claymore::claymore_setup();
		self play_weapon_vo( weapon, magic_box );
		return;
	}
	if ( isDefined( level.zombie_weapons_callbacks ) && isDefined( level.zombie_weapons_callbacks[ weapon ] ) )
	{
		self thread [[ level.zombie_weapons_callbacks[ weapon ] ]]();
		play_weapon_vo( weapon, magic_box );
		return;
	}
	if ( !is_true( nosound ) )
	{
		self play_sound_on_ent( "purchase" );
	}
	if ( weapon == "ray_gun_zm" )
	{
		playsoundatposition( "mus_raygun_stinger", ( 0, 0, 0 ) );
	}
	if ( !is_weapon_upgraded( weapon ) )
	{
		self giveweapon( weapon );
	}
	else
	{
		self giveweapon( weapon, 0, self get_pack_a_punch_weapon_options( weapon ) );
	}
	acquire_weapon_toggle( weapon, self );
	self givestartammo( weapon );
	if ( !is_offhand_weapon( weapon ) )
	{
		if ( !is_melee_weapon( weapon ) )
		{
			self switchtoweapon( weapon );
		}
		else
		{
			self switchtoweapon( current_weapon );
		}
	}
	if( weapon == ( "slipgun_zm" ) )
	{
		self setweaponammostock( "slipgun_zm", 25 );
	}

	self play_weapon_vo( weapon, magic_box );
}

full_ammo_powerup( drop_item, player ) //checked changed to match cerberus output
{
	players = get_players( player.team );
	if ( isdefined( level._get_game_module_players ) )
	{
		players = [[ level._get_game_module_players ]]( player );
	}
	i = 0;
	while ( i < players.size )
	{
		if ( players[ i ] maps/mp/zombies/_zm_laststand::player_is_in_laststand() )
		{
			i++;
			continue;
		}
		primary_weapons = players[ i ] getweaponslist( 1 );
		players[ i ] notify( "zmb_max_ammo" );
		players[ i ] notify( "zmb_lost_knife" );
		players[ i ] notify( "zmb_disable_claymore_prompt" );
		players[ i ] notify( "zmb_disable_spikemore_prompt" );
		x = 0;
		while ( x < primary_weapons.size )
		{
			if ( level.headshots_only && is_lethal_grenade(primary_weapons[ x ] ) )
			{
				x++;
				continue;
			}
			if ( isdefined( level.zombie_include_equipment ) && isdefined( level.zombie_include_equipment[ primary_weapons[ x ] ] ) )
			{
				x++;
				continue;
			}
			if ( isdefined( level.zombie_weapons_no_max_ammo ) && isdefined( level.zombie_weapons_no_max_ammo[ primary_weapons[ x ] ] ) )
			{
				x++;
				continue;
			}
			if ( players[ i ] hasweapon( primary_weapons[ x ] ) )
			{
				players[ i ] givemaxammo( primary_weapons[ x ] );

				if ( players[ i ] hasweapon( "slipgun_zm" ) )
				{
					players[ i ] setweaponammostock( "slipgun_zm", 25 );
				}
			}
			x++;
		}
		i++;
	}
	level thread full_ammo_on_hud( drop_item, player.team );
}


/*
* *************************************************
*	
* ****************** Functions ********************
*
* *************************************************
*/

set_movement_dvars()
{
    self setclientdvar("player_backSpeedScale", 1);
    self setclientdvar("player_strafeSpeedScale", 1);
    self setclientdvar("player_sprintStrafeSpeedScale", 1);
}

register_weapon_mods() {
    level.special_weapon_magicbox_check = ::custom_special_weapon_magicbox_check;
}

custom_special_weapon_magicbox_check( weapon ) {

    map = getDvar("mapname");
    
    if ( weapon == "ray_gun_zm" )
	{
		if ( self has_weapon_or_upgrade( "raygun_mark2_zm" ) )
		{
			return 0;
		}
	}
	if ( weapon == "raygun_mark2_zm" )
	{
		if ( self has_weapon_or_upgrade( "ray_gun_zm" ) )
		{
			return 0;
		}

		// Always give Mark2 until the box moves for first time
		if ( level.chest_moves == 0 )
		{
			return 1;
		}

        // Buried has Mark 2 weighted equally to all others
        if( map == "zm_buried") {
            return 1;
        }
        
        // (# of weapons in box) * .5 = (odds of getting Mark 2 from box)
        // Not as even as every other weapon, but more probable than it already was
        if (randomint (100) >= 50) {
            return 0;
        }
	}


    if(map == "zm_alcatraz") {
        return alcatraz_special_weapon_check(weapon);
    }
    else if( map == "zm_buried") {
        return buried_special_weapon_check(weapon);
    }
    else if(map == "zm_tomb") {
        return tomb_special_weapon_check(weapon);
    }

    return 1;
}

buried_special_weapon_check(weapon) {
    while ( weapon == "time_bomb_zm" )
    {
        players = get_players();
        i = 0;
        while ( i < players.size )
        {
            if ( is_player_valid( players[ i ], undefined, 1 ) && players[ i ] is_player_tactical_grenade( weapon ) )
            {
                return 0;
            }
            i++;
        }
    }
}

alcatraz_special_weapon_check(weapon) {

    if ( weapon != "blundergat_zm" && weapon != "minigun_alcatraz_zm" )
    {
        return 1;
    }
    players = get_players();
    count = 0;
    if ( weapon == "blundergat_zm" )
    {
        if ( self maps/mp/zombies/_zm_weapons::has_weapon_or_upgrade( "blundersplat_zm" ) )
        {
            return 0;
        }
        if ( self afterlife_weapon_limit_check( "blundergat_zm" ) )
        {
            return 0;
        }
        limit = level.limited_weapons[ "blundergat_zm" ];
    }
    else
    {
        if ( self afterlife_weapon_limit_check( "minigun_alcatraz_zm" ) )
        {
            return 0;
        }
        limit = level.limited_weapons[ "minigun_alcatraz_zm" ];
    }
    i = 0;
    while ( i < players.size )
    {
        if ( weapon == "blundergat_zm" )
        {
            if ( players[ i ] has_weapon_or_upgrade( "blundersplat_zm" ) || isDefined( players[ i ].is_pack_splatting ) && players[ i ].is_pack_splatting )
            {
                count++;
                i++;
                continue;
            }
        }
        else
        {
            if ( players[ i ] afterlife_weapon_limit_check( weapon ) )
            {
                count++;
            }
        }
        i++;
    }
    if ( count >= limit )
    {
        return 0;
    }
    return 1;
}

tomb_special_weapon_check(weapon) {
    if ( weapon == "beacon_zm" )
    {
        if ( isDefined( self.beacon_ready ) && self.beacon_ready )
        {
            return 1;
        }
        else
        {
            return 0;
        }
    }
    if ( isDefined( level.zombie_weapons[ weapon ].shared_ammo_weapon ) )
    {
        if ( self has_weapon_or_upgrade( level.zombie_weapons[ weapon ].shared_ammo_weapon ) )
        {
            return 0;
        }
    }
    return 1;
}

afterlife_weapon_limit_check( limited_weapon )
{
	while ( isDefined( self.afterlife ) && self.afterlife )
	{
		if ( limited_weapon == "blundergat_zm" )
		{
			_a1577 = self.loadout;
			_k1577 = getFirstArrayKey( _a1577 );
			while ( isDefined( _k1577 ) )
			{
				weapon = _a1577[ _k1577 ];
				if ( weapon != "blundergat_zm" && weapon != "blundergat_upgraded_zm" || weapon == "blundersplat_zm" && weapon == "blundersplat_upgraded_zm" )
				{
					return 1;
				}
				_k1577 = getNextArrayKey( _a1577, _k1577 );
			}
		}
		else while ( limited_weapon == "minigun_alcatraz_zm" )
		{
			_a1587 = self.loadout;
			_k1587 = getFirstArrayKey( _a1587 );
			while ( isDefined( _k1587 ) )
			{
				weapon = _a1587[ _k1587 ];
				if ( weapon == "minigun_alcatraz_zm" || weapon == "minigun_alcatraz_upgraded_zm" )
				{
					return 1;
				}
				_k1587 = getNextArrayKey( _a1587, _k1587 );
			}
		}
	}
	return 0;
}

func_should_drop_fire_sale_override() //checked partially changed to match cerberus output
{
	if ( level.zombie_vars[ "zombie_powerup_fire_sale_on" ] == 1 || level.chest_moves < 1 || is_true( level.disable_firesale_drop ) && level.round_number > 5 )
	{
		return 1; // firesale now drop untill you move the first box
	}
	return 0;
}

when_fire_sales_should_drop()
{
	level.zombie_powerups[ "fire_sale" ].func_should_drop_with_regular_powerups = ::func_should_drop_fire_sale_override;
}

set_character_option()
{
	if( getDvar("character") == "" )
		setDvar("character", 0 );

	if ( level.force_team_characters != 1 && getDvar("mapname") != "zm_tomb" && getDvar("mapname") != "zm_prison" ) 
	{	
		switch( getDvarInt("character") )
		{
			case 1:
				self setviewmodel( "c_zom_farmgirl_viewhands" );
				self.characterindex = 2;
				break;
			case 2:
				self setviewmodel( "c_zom_oldman_viewhands" );
				self.characterindex = 0;
				break;
			case 3:
				self setviewmodel( "c_zom_reporter_viewhands" );
				self.characterindex = 1;
				break;
			case 4:
				self setviewmodel( "c_zom_engineer_viewhands" );
				self.characterindex = 3;
				break;
		}
	}
}


/*
* *************************************************
*	
* ********************* HUD ***********************
*
* *************************************************
*/

timer_hud()
{	
	self endon("disconnect");

	self.timer_hud = newClientHudElem(self);
	self.timer_hud.alignx = "left";
	self.timer_hud.aligny = "top";
	self.timer_hud.horzalign = "user_left";
	self.timer_hud.vertalign = "user_top";
	self.timer_hud.x += 4;
	self.timer_hud.y += 2;
	self.timer_hud.fontscale = 1.4;
	self.timer_hud.alpha = 0;
	self.timer_hud.color = ( 1, 1, 1 );
	self.timer_hud.hidewheninmenu = 1;

	self thread timer_hud_watcher();
	self thread round_timer_hud();

	flag_wait( "initial_blackscreen_passed" );
	self.timer_hud setTimerUp(0);

	level waittill( "end_game" );

	level.total_time -= .1; // need to set it below the number or it shows the next number
	while(1)
	{	
		self.timer_hud setTimer(level.total_time);
		self.timer_hud.alpha = 1;
		self.round_timer_hud.alpha = 0;
		wait 0.1;
	}
}

timer_hud_watcher()
{	
	self endon("disconnect");

	if( getDvar( "hud_timer") == "" )
		setDvar( "hud_timer", 1 );

	while(1)
	{	
		while( getDvarInt( "hud_timer" ) == 0 )
		{
			wait 0.1;
		}
		self.timer_hud.alpha = 1;

		while( getDvarInt( "hud_timer" ) >= 1 )
		{
			wait 0.1;
		}
		self.timer_hud.alpha = 0;
	}
}

round_timer_hud()
{
	self endon("disconnect");

	self.round_timer_hud = newClientHudElem(self);
	self.round_timer_hud.alignx = "left";
	self.round_timer_hud.aligny = "top";
	self.round_timer_hud.horzalign = "user_left";
	self.round_timer_hud.vertalign = "user_top";
	self.round_timer_hud.x += 4;
	self.round_timer_hud.y += (2 + (15 * getDvarInt("hud_timer") ) );
	self.round_timer_hud.fontscale = 1.4;
	self.round_timer_hud.alpha = 0;
	self.round_timer_hud.color = ( 1, 1, 1 );
	self.round_timer_hud.hidewheninmenu = 1;

	flag_wait( "initial_blackscreen_passed" );

	self thread round_timer_hud_watcher();

	level.FADE_TIME = 0.2;

	while (1)
	{
		zombies_this_round = level.zombie_total + get_round_enemy_array().size;
		hordes = zombies_this_round / 24;

		self.round_timer_hud setTimerUp(0);
		start_time = int(getTime() / 1000);

		level waittill( "end_of_round" );

		end_time = int(getTime() / 1000);
		time = end_time - start_time;

		self display_round_time(time, hordes);

		level waittill( "start_of_round" );

		if( getDvarInt( "hud_round_timer" ) >= 1 )
		{
			self.round_timer_hud FadeOverTime(level.FADE_TIME);
			self.round_timer_hud.alpha = 1;
		}
	}
}

display_round_time(time, hordes)
{
	time -= 0.05;

	sph_off = 1;
	if(level.round_number >= 50 && !flag( "dog_round" ))
	{
		sph_off = 0;
	}

	self.round_timer_hud FadeOverTime(level.FADE_TIME);
	self.round_timer_hud.alpha = 0;
	wait level.FADE_TIME * 2;

	self.round_timer_hud.label = &"Round Time: ";
	self.round_timer_hud FadeOverTime(level.FADE_TIME);
	self.round_timer_hud.alpha = 1;

	for ( i = 0; i < 20 + (20 * sph_off); i++ ) // wait 10s or 5s
	{
		self.round_timer_hud setTimer(time);
		wait 0.25;
	}

	self.round_timer_hud FadeOverTime(level.FADE_TIME);
	self.round_timer_hud.alpha = 0;
	wait level.FADE_TIME * 2;

	if(sph_off == 0)
	{
		self display_sph(time, hordes);
	}

	self.round_timer_hud.label = &"";
}

display_sph( time, hordes )
{
	sph = time / hordes;

	self.round_timer_hud FadeOverTime(level.FADE_TIME);
	self.round_timer_hud.alpha = 1;
	self.round_timer_hud.label = &"SPH: ";
	self.round_timer_hud setValue(sph);

	for ( i = 0; i < 5; i++ )
	{
		wait 1;
	}

	self.round_timer_hud FadeOverTime(level.FADE_TIME);
	self.round_timer_hud.alpha = 0;

	wait level.FADE_TIME;
}

round_timer_hud_watcher()
{	
	self endon("disconnect");

	if( getDvar( "hud_round_timer") == "" )
		setDvar( "hud_round_timer", 0 );

	while(1)
	{
		while( getDvarInt( "hud_round_timer" ) == 0 )
		{
			wait 0.1;
		}
		self.round_timer_hud.y = (2 + (15 * getDvarInt("hud_timer") ) );
		self.round_timer_hud.alpha = 1;

		while( getDvarInt( "hud_round_timer" ) >= 1 )
		{
			wait 0.1;
		}
		self.round_timer_hud.alpha = 0;

	}
}

health_bar_hud()
{
	level endon("end_game");
	self endon("disconnect");

	flag_wait("initial_blackscreen_passed");

	if( getDvar( "hud_health_bar") == "" )
		setDvar( "hud_health_bar", 0 );

	health_bar = self createprimaryprogressbar();
	if (level.script == "zm_buried")
	{
		health_bar setpoint(undefined, "BOTTOM", -335, -95);
	}
	else if (level.script == "zm_tomb")
	{
		health_bar setpoint(undefined, "BOTTOM", -335, -100);
	}
	else
	{
		health_bar setpoint(undefined, "BOTTOM", -335, -70);
	}
	health_bar.hidewheninmenu = 1;
	health_bar.bar.hidewheninmenu = 1;
	health_bar.barframe.hidewheninmenu = 1;

	health_bar_text = self createprimaryprogressbartext();
	if (level.script == "zm_buried")
	{
		health_bar_text setpoint(undefined, "BOTTOM", -410, -95);
	}
	else if (level.script == "zm_tomb")
	{
		health_bar_text setpoint(undefined, "BOTTOM", -410, -100);
	}
	else
	{
		health_bar_text setpoint(undefined, "BOTTOM", -410, -70);
	}
	health_bar_text.hidewheninmenu = 1;

	while (1)
	{
		if( getDvarInt( "hud_health_bar" ) == 0)
		{	
			if (health_bar.alpha != 0)
			{
				health_bar.alpha = 0;
				health_bar.bar.alpha = 0;
				health_bar.barframe.alpha = 0;
				health_bar_text.alpha = 0;
			}
		}
		else
		{
			if (isDefined(self.e_afterlife_corpse))
			{
				if (health_bar.alpha != 0)
				{
					health_bar.alpha = 0;
					health_bar.bar.alpha = 0;
					health_bar.barframe.alpha = 0;
					health_bar_text.alpha = 0;
				}
				wait 0.05;
				continue;
			}

			if ( ( isDefined( self.waiting_to_revive ) && self.waiting_to_revive == 1) || self maps/mp/zombies/_zm_laststand::player_is_in_laststand() )
			{
				if (health_bar.alpha != 0)
				{
					health_bar.alpha = 0;
					health_bar.bar.alpha = 0;
					health_bar.barframe.alpha = 0;
					health_bar_text.alpha = 0;
				}
				wait 0.05;
				continue;
			}

			if (health_bar.alpha != 1)
			{
				health_bar.alpha = 1;
				health_bar.bar.alpha = 1;
				health_bar.barframe.alpha = 1;
				health_bar_text.alpha = 1;
			}

			health_bar updatebar(self.health / self.maxhealth);
			health_bar_text setvalue(self.health);
		}

		wait 0.05;
	}
}


/*
* *********************************************************************
*
* *************************** Self Theards *****************************
*
* *********************************************************************
*/

max_ammo_refill_clip()
{
	level endon( "end_game" );
	self endon( "disconnect" );

	for(;;)
	{
		self waittill( "zmb_max_ammo" );
		weaps = self getweaponslist( 1 );
		foreach( weap in weaps )
		{
			self setweaponammoclip( weap, weaponclipsize( weap ) );
		}
	}
}

set_players_score()
{
	flag_wait( "start_zombie_round_logic" );

	self.score = 555;
}

give_all_perks()
{	
	flag_wait( "initial_blackscreen_passed" );

	vending_triggers = getentarray( "zombie_vending", "targetname" );
	for ( i = 0; i < vending_triggers.size; i++ )
	{
		perk = vending_triggers[ i ].script_noteworthy;
		if ( isDefined( self.perk_purchased ) && self.perk_purchased == perk )
		{
			continue;
		}
		if ( perk == "specialty_weapupgrade" )
		{
			continue;
		}
		if ( !self hasperk( perk ) && !self has_perk_paused( perk ) )
		{
			self give_perk(perk, 1);
		}
		wait 0.05;
	}
}

give_weapons()
{
	flag_wait( "initial_blackscreen_passed" );
	wait 2;
	weapon = "ray_gun_zm";
	self giveWeapon(weapon);
	self switchToWeapon(weapon);
}

graphic_tweaks()
{
	self setclientdvar("r_fog", 0);
	self setclientdvar("r_dof_enable", 0);
	self setclientdvar("r_lodBiasRigid", -1000);
	self setclientdvar("r_lodBiasSkinned", -1000);
	self setClientDvar("r_lodScaleRigid", 1);
	self setClientDvar("r_lodScaleSkinned", 1);
	self setclientdvar("sm_sunquality", 2);
	self setclientdvar("r_enablePlayerShadow", 1);
}

carpenter_repair_shield()
{
    level endon("end_game");
    self endon("disconnect");
    for(;;)
    {
        level waittill( "carpenter_finished" );
        self.shielddamagetaken = 0; 
    }
}

inspect_weapon()
{
	level endon( "end_game" );
	self endon( "disconnect" );
	for(;;)
	{
		if( self actionslotthreebuttonpressed() )
		{
			self initialweaponraise( self getcurrentweapon() );
		}
		wait 0.05;
	}
}

give_perma_perks()
{
	flag_wait("initial_blackscreen_passed");
	permaperks = strTok("pers_revivenoperk,pers_insta_kill,pers_jugg,pers_sniper_counter,pers_flopper_counter,pers_perk_lose_counter,pers_box_weapon_counter,pers_multikill_headshots", ",");
	for (i = 0; i < permaperks.size; i++)
	{
		self increment_client_stat(permaperks[i], 0);
		wait 0.25;
	}
}

give_bank_fridge()
{
	flag_wait("initial_blackscreen_passed");
	self set_map_stat("depositBox", 250, level.banking_map);
	self.account_value = 250000;

	self clear_stored_weapondata();
	self setdstat( "PlayerStatsByMap", "zm_transit", "weaponLocker", "name", "an94_upgraded_zm+mms" ); //setting new weapon
	self setdstat( "PlayerStatsByMap", "zm_transit", "weaponLocker", "clip", 50 );
	self setdstat( "PlayerStatsByMap", "zm_transit", "weaponLocker", "stock", 600 );
}

mulekick_additional_perks()
{
	self endon( "disconnect" );

	for ( ;; )
	{
		self waittill_any("perk_acquired", "perk_lost");

		if (self HasPerk("specialty_additionalprimaryweapon"))
		{
			self SetPerk("specialty_fastads");
			self SetPerk("specialty_fastweaponswitch");
			self Setperk("specialty_fasttoss");
		}
		else
		{
			self UnsetPerk("specialty_fastads");
			self UnsetPerk("specialty_fastweaponswitch");
			self Unsetperk("specialty_fasttoss");
		}
	}
}


/*
* *********************************************************************
*
* *************************** Level Theards *****************************
*
* *********************************************************************
*/

fake_reset()
{
    level endon("disconnect");
	level endon("end_game");

    level.win_game = false;
	level.total_time = 0;
	level.paused_time = 0;

	flag_wait( "initial_blackscreen_passed" );

	start_time = int(getTime() / 1000);

    while(1)
    {
        current_time = int(getTime() / 1000);
		level.total_time = (current_time - level.paused_time) - start_time;
		
        if (level.total_time >= 43200) // 12h reset
        {
			players = Get_Players();	
			for(i=0;i<players.size;i++)
			{
				players[i] FreezeControls( true );
			}
            level.win_game = true;
            level notify( "end_game" );
			break;
        }

        wait 0.05;
    }
}

coop_pause()
{	
	level endon("disconnect");
	level endon("end_game");

	setDvar( "coop_pause", 0 );

	paused_time = 0;
	paused_start_time = 0;
	paused = false;

	start_time = int(getTime() / 1000);

	players = get_players();

	while(1)//(players.size > 1) // TODO
	{
		if( getDvarInt( "coop_pause" ) == 1 )
		{	
			if(get_round_enemy_array().size + level.zombie_total != 0 || flag( "dog_round" ) )
			{
				iprintln("All players will be paused at the start of the next round");
				level waittill( "end_of_round" );
			}

			players[0] SetClientDvar( "ai_disableSpawn", "1" );

			level waittill( "start_of_round" );

			black_hud = newhudelem();
			black_hud.horzAlign = "fullscreen";
			black_hud.vertAlign = "fullscreen";
			black_hud SetShader( "black", 640, 480 );
			black_hud.alpha = 0;

			black_hud FadeOverTime( 1.0 );
			black_hud.alpha = 0.7;

			paused_hud = newhudelem();
			paused_hud.horzAlign = "center";
			paused_hud.vertAlign = "middle";
			paused_hud setText("GAME PAUSED");
			paused_hud.foreground = true;
			paused_hud.fontScale = 2.3;
			paused_hud.x -= 63;
			paused_hud.y -= 20;
			paused_hud.alpha = 0;
			paused_hud.color = ( 1.0, 1.0, 1.0 );

			paused_hud FadeOverTime( 1.0 );
			paused_hud.alpha = 0.85;
			
			players = get_players();
			for(i = 0; players.size > i; i++)
			{
				players[i] freezecontrols(true);
			}

			paused = true;
			paused_start_time = int(getTime() / 1000);
			total_time = 0 - (paused_start_time - level.paused_time) - (start_time - 0.05);
			previous_paused_time = level.paused_time;

			while(paused)
			{	
				players = get_players();
				for(i = 0; players.size > i; i++)
				{
					players[i].timer_hud SetTimerUp(total_time);
				}
				
				wait 0.2;

				current_time = int(getTime() / 1000);
				current_paused_time = current_time - paused_start_time;
				level.paused_time = previous_paused_time + current_paused_time;

				if( getDvarInt( "coop_pause" ) == 0 )
				{
					paused = false;

					for(i = 0; players.size > i; i++)
					{
						players[i] freezecontrols(false);
					}

					players[0] SetClientDvar( "ai_disableSpawn", "0");

					paused_hud FadeOverTime( 0.5 );
					paused_hud.alpha = 0;
					black_hud FadeOverTime( 0.5 );
					black_hud.alpha = 0;
					wait 0.5;
					black_hud destroy();
					paused_hud destroy();
				}
			}
		}
		wait 0.05;
	}
}

shared_magic_box()
{
	add_zombie_hint( "default_shared_box", "Hold ^3&&1^7 for weapon");
	level.shared_box = 0;

	flag_wait( "initial_blackscreen_passed" );
    if( getdvar( "mapname" ) == "zm_nuked" )
    {
        wait 10;
    }
    while(1)
    {
        for(i = 0; i < level.chests.size; i++)
        {
            if (!is_true( level.chests[ i ].hidden ) && level.zombie_vars[ "zombie_powerup_fire_sale_on" ] == 0)
            {
                level.chests[i] thread reset_box();
            }
            level.chests[i].zbarrier thread tell_me();
        }
		level waittill("RunScriptAgain");
    }
}

tell_me()
{
    while(1)
    {
        self waittill( "arrived" );
        if (level.zombie_vars[ "zombie_powerup_fire_sale_on" ] == 0)
        {
            level notify("RunScriptAgain");
        }
    }
}

reset_box()
{
	self notify("kill_chest_think");
	self.grab_weapon_hint = 0;
    wait .1;
    self thread maps/mp/zombies/_zm_unitrigger::register_static_unitrigger( self.unitrigger_stub, ::magicbox_unitrigger_think );
    self.unitrigger_stub run_visibility_function_for_all_triggers();
    self thread treasure_chest_think_override();
}

zombie_health_fix()
{
	for( ; ; ) 
	{
		if(level.round_number > 158) 
		{ 
			zombies = GetAIArray("axis");

            for(i = 0; i < zombies.size; i++) 
			{
			    if (zombies[i].targetname != "zombie") 
				{ 
				}
                else if(zombies[i].targetname == "zombie") 
				{
					if(!isDefined(zombies[i].health_override)) 
					{
						zombies[i].health_override = true;
                        zombies[i].health = 1390371547;
                    }
                }
            }
        }
        wait(0.05);
    }
}

wallbuy_increase_trigger_radius()
{
	for(i = 0; i < level._unitriggers.trigger_stubs.size; i++)
	{
		if(IsDefined(level._unitriggers.trigger_stubs[i].zombie_weapon_upgrade))
		{
			level._unitriggers.trigger_stubs[i].script_length = 96;
		}
	}
}

wallbuy_dynamic_increase_trigger_radius()
{
	if(!(is_classic() && level.scr_zm_map_start_location == "processing"))
	{
		return;
	}

	while (!isDefined(level.built_wallbuys))
	{
		wait 0.5;
	}

	prev_built_wallbuys = 0;

	while (1)
	{
		if (level.built_wallbuys > prev_built_wallbuys)
		{
			prev_built_wallbuys = level.built_wallbuys;
			wallbuy_increase_trigger_radius();
		}

		if (level.built_wallbuys == -100)
		{
			wallbuy_increase_trigger_radius();
			return;
		}

		wait 0.5;
	}
}


/*
* *********************************************************************
*
* *************************** Die Rise ********************************
*
* *********************************************************************
*/

slipgun_always_kill()
{
	level.slipgun_damage = maps/mp/zombies/_zm::ai_zombie_health( 666 );
	level.zombie_vars["slipgun_max_kill_round"] = 666; 
}

slipgun_disable_reslip()
{
	level.zombie_vars["slipgun_reslip_rate"] = 0;
    level.zombie_vars["slipgun_reslip_max_spots"] = 0; //
}

die_rise_zone_changes()
{
    if(is_classic())
    {
        if(level.scr_zm_map_start_location == "rooftop")
        {
            // AN94 to Debris
            level.zones[ "zone_orange_level3a" ].adjacent_zones[ "zone_orange_level3b" ].is_connected = 0;

            // Trample Steam to Skyscraper
            level.zones[ "zone_green_level3b" ].adjacent_zones[ "zone_blue_level1c" ] structdelete();
            level.zones[ "zone_green_level3b" ].adjacent_zones[ "zone_blue_level1c" ] = undefined;
        }
    }
}

reduce_sliq_starting_ammo()
{
	if( self hasweapon( "slipgun_zm" ) && (self getammocount( "slipgun_zm" ) > 16 ) )
	{
		self setweaponammostock( "slipgun_zm", 25 );
	}
}


/*
* *********************************************************************
*
* *************************** Tranzit *********************************
*
* *********************************************************************
*/

jetgun_buff()
{
    level endon("end_game");
    self endon("disconnect");
    for(;;)
    {
        if (self hasweapon("jetgun_zm"))
        {
            self.jetgun_heatval -= 1;
            if (self.jetgun_heatval < 0)
            {
                self.jetgun_heatval = 0;
            }
            self setweaponoverheating( self.jetgun_overheating, self.jetgun_heatval );
        }
        wait 0.25;
    }
}


