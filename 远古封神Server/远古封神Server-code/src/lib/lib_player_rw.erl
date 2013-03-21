%%%------------------------------------------------	
%%% File    : lib_player_rw.erl	
%%% Author  : ygzj	
%%% Created : 2012-04-25 16:24:46	
%%% Description: 从record生成的代码	
%%% Warning:  由程序自动生成，请不要随意修改！	
%%%------------------------------------------------		
 	
-module(lib_player_rw).	
 	
%%  	
%% Include files  	
-include("common.hrl"). 	
-include("record.hrl"). 	
  	
%% 	
%% Exported Functions 	
%% 	
-compile(export_all). 	
  	
%%获取用户信息(按[字段1,字段2,...])	
%% handle_call({'PLAYER',  [x ,y]}, _from, Status)	
get_player_info_fields(Player, List) ->	
	lists:map(fun(T) ->	
			case T of	
				id -> Player#player.id;	
				accid -> Player#player.accid;	
				accname -> Player#player.accname;	
				nickname -> Player#player.nickname;	
				status -> Player#player.status;	
				reg_time -> Player#player.reg_time;	
				last_login_time -> Player#player.last_login_time;	
				last_login_ip -> Player#player.last_login_ip;	
				sex -> Player#player.sex;	
				career -> Player#player.career;	
				realm -> Player#player.realm;	
				prestige -> Player#player.prestige;	
				spirit -> Player#player.spirit;	
				jobs -> Player#player.jobs;	
				gold -> Player#player.gold;	
				cash -> Player#player.cash;	
				coin -> Player#player.coin;	
				bcoin -> Player#player.bcoin;	
				coin_sum -> Player#player.coin_sum;	
				scene -> Player#player.scene;	
				x -> Player#player.x;	
				y -> Player#player.y;	
				lv -> Player#player.lv;	
				exp -> Player#player.exp;	
				hp -> Player#player.hp;	
				mp -> Player#player.mp;	
				hp_lim -> Player#player.hp_lim;	
				mp_lim -> Player#player.mp_lim;	
				forza -> Player#player.forza;	
				agile -> Player#player.agile;	
				wit -> Player#player.wit;	
				max_attack -> Player#player.max_attack;	
				min_attack -> Player#player.min_attack;	
				def -> Player#player.def;	
				hit -> Player#player.hit;	
				dodge -> Player#player.dodge;	
				crit -> Player#player.crit;	
				att_area -> Player#player.att_area;	
				pk_mode -> Player#player.pk_mode;	
				pk_time -> Player#player.pk_time;	
				title -> Player#player.title;	
				couple_name -> Player#player.couple_name;	
				position -> Player#player.position;	
				evil -> Player#player.evil;	
				honor -> Player#player.honor;	
				culture -> Player#player.culture;	
				state -> Player#player.state;	
				physique -> Player#player.physique;	
				anti_wind -> Player#player.anti_wind;	
				anti_fire -> Player#player.anti_fire;	
				anti_water -> Player#player.anti_water;	
				anti_thunder -> Player#player.anti_thunder;	
				anti_soil -> Player#player.anti_soil;	
				anti_rift -> Player#player.anti_rift;	
				cell_num -> Player#player.cell_num;	
				mount -> Player#player.mount;	
				guild_id -> Player#player.guild_id;	
				guild_name -> Player#player.guild_name;	
				guild_position -> Player#player.guild_position;	
				quit_guild_time -> Player#player.quit_guild_time;	
				guild_title -> Player#player.guild_title;	
				guild_depart_name -> Player#player.guild_depart_name;	
				guild_depart_id -> Player#player.guild_depart_id;	
				speed -> Player#player.speed;	
				att_speed -> Player#player.att_speed;	
				equip -> Player#player.equip;	
				vip -> Player#player.vip;	
				vip_time -> Player#player.vip_time;	
				online_flag -> Player#player.online_flag;	
				pet_upgrade_que_num -> Player#player.pet_upgrade_que_num;	
				daily_task_limit -> Player#player.daily_task_limit;	
				carry_mark -> Player#player.carry_mark;	
				task_convoy_npc -> Player#player.task_convoy_npc;	
				other -> Player#player.other;	
				store_num -> Player#player.store_num;	
				online_gift -> Player#player.online_gift;	
				target_gift -> Player#player.target_gift;	
				arena -> Player#player.arena;	
				arena_score -> Player#player.arena_score;	
				sn -> Player#player.sn;	
				realm_honor -> Player#player.realm_honor;	
				base_player_attribute -> Player#player.other#player_other.base_player_attribute;	
				base_attribute -> Player#player.other#player_other.base_attribute;	
				two_attribute -> Player#player.other#player_other.two_attribute;	
				pet_attribute -> Player#player.other#player_other.pet_attribute;	
				pet_skill_mult_attribute -> Player#player.other#player_other.pet_skill_mult_attribute;	
				mount_mult_attribute -> Player#player.other#player_other.mount_mult_attribute;	
				equip_attrit -> Player#player.other#player_other.equip_attrit;	
				equip_current -> Player#player.other#player_other.equip_current;	
				equip_attribute -> Player#player.other#player_other.equip_attribute;	
				equip_player_attribute -> Player#player.other#player_other.equip_player_attribute;	
				equip_mult_attribute -> Player#player.other#player_other.equip_mult_attribute;	
				meridian_attribute -> Player#player.other#player_other.meridian_attribute;	
				leader -> Player#player.other#player_other.leader;	
				skill -> Player#player.other#player_other.skill;	
				light_skill -> Player#player.other#player_other.light_skill;	
				passive_skill -> Player#player.other#player_other.passive_skill;	
				deputy_skill -> Player#player.other#player_other.deputy_skill;	
				deputy_prof_lv -> Player#player.other#player_other.deputy_prof_lv;	
				deputy_passive_att -> Player#player.other#player_other.deputy_passive_att;	
				stren -> Player#player.other#player_other.stren;	
				fbyfstren -> Player#player.other#player_other.fbyfstren;	
				spyfstren -> Player#player.other#player_other.spyfstren;	
				fullstren -> Player#player.other#player_other.fullstren;	
				suitid -> Player#player.other#player_other.suitid;	
				out_pet -> Player#player.other#player_other.out_pet;	
				socket -> Player#player.other#player_other.socket;	
				socket2 -> Player#player.other#player_other.socket2;	
				socket3 -> Player#player.other#player_other.socket3;	
				pid_socket -> Player#player.other#player_other.pid_socket;	
				pid -> Player#player.other#player_other.pid;	
				pid_goods -> Player#player.other#player_other.pid_goods;	
				pid_send -> Player#player.other#player_other.pid_send;	
				pid_send2 -> Player#player.other#player_other.pid_send2;	
				pid_send3 -> Player#player.other#player_other.pid_send3;	
				pid_dungeon -> Player#player.other#player_other.pid_dungeon;	
				pid_fst -> Player#player.other#player_other.pid_fst;	
				pid_team -> Player#player.other#player_other.pid_team;	
				pid_scene -> Player#player.other#player_other.pid_scene;	
				pid_task -> Player#player.other#player_other.pid_task;	
				pid_meridian -> Player#player.other#player_other.pid_meridian;	
				pid_love -> Player#player.other#player_other.pid_love;	
				node -> Player#player.other#player_other.node;	
				battle_status -> Player#player.other#player_other.battle_status;	
				battle_limit -> Player#player.other#player_other.battle_limit;	
				trade_status -> Player#player.other#player_other.trade_status;	
				trade_list -> Player#player.other#player_other.trade_list;	
				goods_buff -> Player#player.other#player_other.goods_buff;	
				fst_exp_ttl -> Player#player.other#player_other.fst_exp_ttl;	
				fst_spr_ttl -> Player#player.other#player_other.fst_spr_ttl;	
				fst_hor_ttl -> Player#player.other#player_other.fst_hor_ttl;	
				be_bless_time -> Player#player.other#player_other.be_bless_time;	
				bless_limit_time -> Player#player.other#player_other.bless_limit_time;	
				bless_list -> Player#player.other#player_other.bless_list;	
				exc_status -> Player#player.other#player_other.exc_status;	
				mount_stren -> Player#player.other#player_other.mount_stren;	
				guild_h_skills -> Player#player.other#player_other.guild_h_skills;	
				guild_feats -> Player#player.other#player_other.guild_feats;	
				blacklist -> Player#player.other#player_other.blacklist;	
				charm -> Player#player.other#player_other.charm;	
				peach_revel -> Player#player.other#player_other.peach_revel;	
				privity_info -> Player#player.other#player_other.privity_info;	
				ach_pearl -> Player#player.other#player_other.ach_pearl;	
				goods_buf_cd -> Player#player.other#player_other.goods_buf_cd;	
				goods_ring4 -> Player#player.other#player_other.goods_ring4;	
				heartbeat -> Player#player.other#player_other.heartbeat;	
				battle_dict -> Player#player.other#player_other.battle_dict;	
				is_spring -> Player#player.other#player_other.is_spring;	
				zxt_honor -> Player#player.other#player_other.zxt_honor;	
				team_buff_level -> Player#player.other#player_other.team_buff_level;	
				die_time -> Player#player.other#player_other.die_time;	
				war_die_times -> Player#player.other#player_other.war_die_times;	
				love_invited -> Player#player.other#player_other.love_invited;	
				batt_value -> Player#player.other#player_other.batt_value;	
				turned -> Player#player.other#player_other.turned;	
				titles -> Player#player.other#player_other.titles;	
				accept -> Player#player.other#player_other.accept;	
				double_rest_id -> Player#player.other#player_other.double_rest_id;	
				realm_honor_player_list -> Player#player.other#player_other.realm_honor_player_list;	
				hook_pick -> Player#player.other#player_other.hook_pick;	
				hook_equip_list -> Player#player.other#player_other.hook_equip_list;	
				hook_quality_list -> Player#player.other#player_other.hook_quality_list;	
				shop_score -> Player#player.other#player_other.shop_score;	
				castle_king -> Player#player.other#player_other.castle_king;	
				g_alliance -> Player#player.other#player_other.g_alliance;	
				war_honor -> Player#player.other#player_other.war_honor;	
				war_honor_value -> Player#player.other#player_other.war_honor_value;	
				war2_scene -> Player#player.other#player_other.war2_scene;	
				shadow -> Player#player.other#player_other.shadow;	
				couple_skill -> Player#player.other#player_other.couple_skill;	
				pet_batt_skill -> Player#player.other#player_other.pet_batt_skill;	
				_ -> undefined	
			end	
		end, List).	
 	
%%设置用户信息(按[{字段1,值1},{字段2,值2, add},{字段3,值3, sub}...])	
%% handle_cast({'SET_PLAYER',[{x, 10} ,{y, 20, add},  ,{hp, 20, sub}]}, Status)	
set_player_info_fields(Player, []) ->	
	Player;	
set_player_info_fields(Player, [H|T]) ->	
	NewPlayer =	
		case H of	
				{id, Val, add} -> Player#player{id=Player#player.id + Val};	
				{id, Val, sub} -> Player#player{id=Player#player.id - Val};	
				{id, Val, _} -> Player#player{id= Val};	
				{id, Val} -> Player#player{id= Val};	
				{accid, Val, add} -> Player#player{accid=Player#player.accid + Val};	
				{accid, Val, sub} -> Player#player{accid=Player#player.accid - Val};	
				{accid, Val, _} -> Player#player{accid= Val};	
				{accid, Val} -> Player#player{accid= Val};	
				{accname, Val, add} -> Player#player{accname=Player#player.accname + Val};	
				{accname, Val, sub} -> Player#player{accname=Player#player.accname - Val};	
				{accname, Val, _} -> Player#player{accname= Val};	
				{accname, Val} -> Player#player{accname= Val};	
				{nickname, Val, add} -> Player#player{nickname=Player#player.nickname + Val};	
				{nickname, Val, sub} -> Player#player{nickname=Player#player.nickname - Val};	
				{nickname, Val, _} -> Player#player{nickname= Val};	
				{nickname, Val} -> Player#player{nickname= Val};	
				{status, Val, add} -> Player#player{status=Player#player.status + Val};	
				{status, Val, sub} -> Player#player{status=Player#player.status - Val};	
				{status, Val, _} -> Player#player{status= Val};	
				{status, Val} -> Player#player{status= Val};	
				{reg_time, Val, add} -> Player#player{reg_time=Player#player.reg_time + Val};	
				{reg_time, Val, sub} -> Player#player{reg_time=Player#player.reg_time - Val};	
				{reg_time, Val, _} -> Player#player{reg_time= Val};	
				{reg_time, Val} -> Player#player{reg_time= Val};	
				{last_login_time, Val, add} -> Player#player{last_login_time=Player#player.last_login_time + Val};	
				{last_login_time, Val, sub} -> Player#player{last_login_time=Player#player.last_login_time - Val};	
				{last_login_time, Val, _} -> Player#player{last_login_time= Val};	
				{last_login_time, Val} -> Player#player{last_login_time= Val};	
				{last_login_ip, Val, add} -> Player#player{last_login_ip=Player#player.last_login_ip + Val};	
				{last_login_ip, Val, sub} -> Player#player{last_login_ip=Player#player.last_login_ip - Val};	
				{last_login_ip, Val, _} -> Player#player{last_login_ip= Val};	
				{last_login_ip, Val} -> Player#player{last_login_ip= Val};	
				{sex, Val, add} -> Player#player{sex=Player#player.sex + Val};	
				{sex, Val, sub} -> Player#player{sex=Player#player.sex - Val};	
				{sex, Val, _} -> Player#player{sex= Val};	
				{sex, Val} -> Player#player{sex= Val};	
				{career, Val, add} -> Player#player{career=Player#player.career + Val};	
				{career, Val, sub} -> Player#player{career=Player#player.career - Val};	
				{career, Val, _} -> Player#player{career= Val};	
				{career, Val} -> Player#player{career= Val};	
				{realm, Val, add} -> Player#player{realm=Player#player.realm + Val};	
				{realm, Val, sub} -> Player#player{realm=Player#player.realm - Val};	
				{realm, Val, _} -> Player#player{realm= Val};	
				{realm, Val} -> Player#player{realm= Val};	
				{prestige, Val, add} -> Player#player{prestige=Player#player.prestige + Val};	
				{prestige, Val, sub} -> Player#player{prestige=Player#player.prestige - Val};	
				{prestige, Val, _} -> Player#player{prestige= Val};	
				{prestige, Val} -> Player#player{prestige= Val};	
				{spirit, Val, add} -> Player#player{spirit=Player#player.spirit + Val};	
				{spirit, Val, sub} -> Player#player{spirit=Player#player.spirit - Val};	
				{spirit, Val, _} -> Player#player{spirit= Val};	
				{spirit, Val} -> Player#player{spirit= Val};	
				{jobs, Val, add} -> Player#player{jobs=Player#player.jobs + Val};	
				{jobs, Val, sub} -> Player#player{jobs=Player#player.jobs - Val};	
				{jobs, Val, _} -> Player#player{jobs= Val};	
				{jobs, Val} -> Player#player{jobs= Val};	
				{gold, Val, add} -> Player#player{gold=Player#player.gold + Val};	
				{gold, Val, sub} -> Player#player{gold=Player#player.gold - Val};	
				{gold, Val, _} -> Player#player{gold= Val};	
				{gold, Val} -> Player#player{gold= Val};	
				{cash, Val, add} -> Player#player{cash=Player#player.cash + Val};	
				{cash, Val, sub} -> Player#player{cash=Player#player.cash - Val};	
				{cash, Val, _} -> Player#player{cash= Val};	
				{cash, Val} -> Player#player{cash= Val};	
				{coin, Val, add} -> Player#player{coin=Player#player.coin + Val};	
				{coin, Val, sub} -> Player#player{coin=Player#player.coin - Val};	
				{coin, Val, _} -> Player#player{coin= Val};	
				{coin, Val} -> Player#player{coin= Val};	
				{bcoin, Val, add} -> Player#player{bcoin=Player#player.bcoin + Val};	
				{bcoin, Val, sub} -> Player#player{bcoin=Player#player.bcoin - Val};	
				{bcoin, Val, _} -> Player#player{bcoin= Val};	
				{bcoin, Val} -> Player#player{bcoin= Val};	
				{coin_sum, Val, add} -> Player#player{coin_sum=Player#player.coin_sum + Val};	
				{coin_sum, Val, sub} -> Player#player{coin_sum=Player#player.coin_sum - Val};	
				{coin_sum, Val, _} -> Player#player{coin_sum= Val};	
				{coin_sum, Val} -> Player#player{coin_sum= Val};	
				{scene, Val, add} -> Player#player{scene=Player#player.scene + Val};	
				{scene, Val, sub} -> Player#player{scene=Player#player.scene - Val};	
				{scene, Val, _} -> Player#player{scene= Val};	
				{scene, Val} -> Player#player{scene= Val};	
				{x, Val, add} -> Player#player{x=Player#player.x + Val};	
				{x, Val, sub} -> Player#player{x=Player#player.x - Val};	
				{x, Val, _} -> Player#player{x= Val};	
				{x, Val} -> Player#player{x= Val};	
				{y, Val, add} -> Player#player{y=Player#player.y + Val};	
				{y, Val, sub} -> Player#player{y=Player#player.y - Val};	
				{y, Val, _} -> Player#player{y= Val};	
				{y, Val} -> Player#player{y= Val};	
				{lv, Val, add} -> Player#player{lv=Player#player.lv + Val};	
				{lv, Val, sub} -> Player#player{lv=Player#player.lv - Val};	
				{lv, Val, _} -> Player#player{lv= Val};	
				{lv, Val} -> Player#player{lv= Val};	
				{exp, Val, add} -> Player#player{exp=Player#player.exp + Val};	
				{exp, Val, sub} -> Player#player{exp=Player#player.exp - Val};	
				{exp, Val, _} -> Player#player{exp= Val};	
				{exp, Val} -> Player#player{exp= Val};	
				{hp, Val, add} -> Player#player{hp=Player#player.hp + Val};	
				{hp, Val, sub} -> Player#player{hp=Player#player.hp - Val};	
				{hp, Val, _} -> Player#player{hp= Val};	
				{hp, Val} -> Player#player{hp= Val};	
				{mp, Val, add} -> Player#player{mp=Player#player.mp + Val};	
				{mp, Val, sub} -> Player#player{mp=Player#player.mp - Val};	
				{mp, Val, _} -> Player#player{mp= Val};	
				{mp, Val} -> Player#player{mp= Val};	
				{hp_lim, Val, add} -> Player#player{hp_lim=Player#player.hp_lim + Val};	
				{hp_lim, Val, sub} -> Player#player{hp_lim=Player#player.hp_lim - Val};	
				{hp_lim, Val, _} -> Player#player{hp_lim= Val};	
				{hp_lim, Val} -> Player#player{hp_lim= Val};	
				{mp_lim, Val, add} -> Player#player{mp_lim=Player#player.mp_lim + Val};	
				{mp_lim, Val, sub} -> Player#player{mp_lim=Player#player.mp_lim - Val};	
				{mp_lim, Val, _} -> Player#player{mp_lim= Val};	
				{mp_lim, Val} -> Player#player{mp_lim= Val};	
				{forza, Val, add} -> Player#player{forza=Player#player.forza + Val};	
				{forza, Val, sub} -> Player#player{forza=Player#player.forza - Val};	
				{forza, Val, _} -> Player#player{forza= Val};	
				{forza, Val} -> Player#player{forza= Val};	
				{agile, Val, add} -> Player#player{agile=Player#player.agile + Val};	
				{agile, Val, sub} -> Player#player{agile=Player#player.agile - Val};	
				{agile, Val, _} -> Player#player{agile= Val};	
				{agile, Val} -> Player#player{agile= Val};	
				{wit, Val, add} -> Player#player{wit=Player#player.wit + Val};	
				{wit, Val, sub} -> Player#player{wit=Player#player.wit - Val};	
				{wit, Val, _} -> Player#player{wit= Val};	
				{wit, Val} -> Player#player{wit= Val};	
				{max_attack, Val, add} -> Player#player{max_attack=Player#player.max_attack + Val};	
				{max_attack, Val, sub} -> Player#player{max_attack=Player#player.max_attack - Val};	
				{max_attack, Val, _} -> Player#player{max_attack= Val};	
				{max_attack, Val} -> Player#player{max_attack= Val};	
				{min_attack, Val, add} -> Player#player{min_attack=Player#player.min_attack + Val};	
				{min_attack, Val, sub} -> Player#player{min_attack=Player#player.min_attack - Val};	
				{min_attack, Val, _} -> Player#player{min_attack= Val};	
				{min_attack, Val} -> Player#player{min_attack= Val};	
				{def, Val, add} -> Player#player{def=Player#player.def + Val};	
				{def, Val, sub} -> Player#player{def=Player#player.def - Val};	
				{def, Val, _} -> Player#player{def= Val};	
				{def, Val} -> Player#player{def= Val};	
				{hit, Val, add} -> Player#player{hit=Player#player.hit + Val};	
				{hit, Val, sub} -> Player#player{hit=Player#player.hit - Val};	
				{hit, Val, _} -> Player#player{hit= Val};	
				{hit, Val} -> Player#player{hit= Val};	
				{dodge, Val, add} -> Player#player{dodge=Player#player.dodge + Val};	
				{dodge, Val, sub} -> Player#player{dodge=Player#player.dodge - Val};	
				{dodge, Val, _} -> Player#player{dodge= Val};	
				{dodge, Val} -> Player#player{dodge= Val};	
				{crit, Val, add} -> Player#player{crit=Player#player.crit + Val};	
				{crit, Val, sub} -> Player#player{crit=Player#player.crit - Val};	
				{crit, Val, _} -> Player#player{crit= Val};	
				{crit, Val} -> Player#player{crit= Val};	
				{att_area, Val, add} -> Player#player{att_area=Player#player.att_area + Val};	
				{att_area, Val, sub} -> Player#player{att_area=Player#player.att_area - Val};	
				{att_area, Val, _} -> Player#player{att_area= Val};	
				{att_area, Val} -> Player#player{att_area= Val};	
				{pk_mode, Val, add} -> Player#player{pk_mode=Player#player.pk_mode + Val};	
				{pk_mode, Val, sub} -> Player#player{pk_mode=Player#player.pk_mode - Val};	
				{pk_mode, Val, _} -> Player#player{pk_mode= Val};	
				{pk_mode, Val} -> Player#player{pk_mode= Val};	
				{pk_time, Val, add} -> Player#player{pk_time=Player#player.pk_time + Val};	
				{pk_time, Val, sub} -> Player#player{pk_time=Player#player.pk_time - Val};	
				{pk_time, Val, _} -> Player#player{pk_time= Val};	
				{pk_time, Val} -> Player#player{pk_time= Val};	
				{title, Val, add} -> Player#player{title=Player#player.title + Val};	
				{title, Val, sub} -> Player#player{title=Player#player.title - Val};	
				{title, Val, _} -> Player#player{title= Val};	
				{title, Val} -> Player#player{title= Val};	
				{couple_name, Val, add} -> Player#player{couple_name=Player#player.couple_name + Val};	
				{couple_name, Val, sub} -> Player#player{couple_name=Player#player.couple_name - Val};	
				{couple_name, Val, _} -> Player#player{couple_name= Val};	
				{couple_name, Val} -> Player#player{couple_name= Val};	
				{position, Val, add} -> Player#player{position=Player#player.position + Val};	
				{position, Val, sub} -> Player#player{position=Player#player.position - Val};	
				{position, Val, _} -> Player#player{position= Val};	
				{position, Val} -> Player#player{position= Val};	
				{evil, Val, add} -> Player#player{evil=Player#player.evil + Val};	
				{evil, Val, sub} -> Player#player{evil=Player#player.evil - Val};	
				{evil, Val, _} -> Player#player{evil= Val};	
				{evil, Val} -> Player#player{evil= Val};	
				{honor, Val, add} -> Player#player{honor=Player#player.honor + Val};	
				{honor, Val, sub} -> Player#player{honor=Player#player.honor - Val};	
				{honor, Val, _} -> Player#player{honor= Val};	
				{honor, Val} -> Player#player{honor= Val};	
				{culture, Val, add} -> Player#player{culture=Player#player.culture + Val};	
				{culture, Val, sub} -> Player#player{culture=Player#player.culture - Val};	
				{culture, Val, _} -> Player#player{culture= Val};	
				{culture, Val} -> Player#player{culture= Val};	
				{state, Val, add} -> Player#player{state=Player#player.state + Val};	
				{state, Val, sub} -> Player#player{state=Player#player.state - Val};	
				{state, Val, _} -> Player#player{state= Val};	
				{state, Val} -> Player#player{state= Val};	
				{physique, Val, add} -> Player#player{physique=Player#player.physique + Val};	
				{physique, Val, sub} -> Player#player{physique=Player#player.physique - Val};	
				{physique, Val, _} -> Player#player{physique= Val};	
				{physique, Val} -> Player#player{physique= Val};	
				{anti_wind, Val, add} -> Player#player{anti_wind=Player#player.anti_wind + Val};	
				{anti_wind, Val, sub} -> Player#player{anti_wind=Player#player.anti_wind - Val};	
				{anti_wind, Val, _} -> Player#player{anti_wind= Val};	
				{anti_wind, Val} -> Player#player{anti_wind= Val};	
				{anti_fire, Val, add} -> Player#player{anti_fire=Player#player.anti_fire + Val};	
				{anti_fire, Val, sub} -> Player#player{anti_fire=Player#player.anti_fire - Val};	
				{anti_fire, Val, _} -> Player#player{anti_fire= Val};	
				{anti_fire, Val} -> Player#player{anti_fire= Val};	
				{anti_water, Val, add} -> Player#player{anti_water=Player#player.anti_water + Val};	
				{anti_water, Val, sub} -> Player#player{anti_water=Player#player.anti_water - Val};	
				{anti_water, Val, _} -> Player#player{anti_water= Val};	
				{anti_water, Val} -> Player#player{anti_water= Val};	
				{anti_thunder, Val, add} -> Player#player{anti_thunder=Player#player.anti_thunder + Val};	
				{anti_thunder, Val, sub} -> Player#player{anti_thunder=Player#player.anti_thunder - Val};	
				{anti_thunder, Val, _} -> Player#player{anti_thunder= Val};	
				{anti_thunder, Val} -> Player#player{anti_thunder= Val};	
				{anti_soil, Val, add} -> Player#player{anti_soil=Player#player.anti_soil + Val};	
				{anti_soil, Val, sub} -> Player#player{anti_soil=Player#player.anti_soil - Val};	
				{anti_soil, Val, _} -> Player#player{anti_soil= Val};	
				{anti_soil, Val} -> Player#player{anti_soil= Val};	
				{anti_rift, Val, add} -> Player#player{anti_rift=Player#player.anti_rift + Val};	
				{anti_rift, Val, sub} -> Player#player{anti_rift=Player#player.anti_rift - Val};	
				{anti_rift, Val, _} -> Player#player{anti_rift= Val};	
				{anti_rift, Val} -> Player#player{anti_rift= Val};	
				{cell_num, Val, add} -> Player#player{cell_num=Player#player.cell_num + Val};	
				{cell_num, Val, sub} -> Player#player{cell_num=Player#player.cell_num - Val};	
				{cell_num, Val, _} -> Player#player{cell_num= Val};	
				{cell_num, Val} -> Player#player{cell_num= Val};	
				{mount, Val, add} -> Player#player{mount=Player#player.mount + Val};	
				{mount, Val, sub} -> Player#player{mount=Player#player.mount - Val};	
				{mount, Val, _} -> Player#player{mount= Val};	
				{mount, Val} -> Player#player{mount= Val};	
				{guild_id, Val, add} -> Player#player{guild_id=Player#player.guild_id + Val};	
				{guild_id, Val, sub} -> Player#player{guild_id=Player#player.guild_id - Val};	
				{guild_id, Val, _} -> Player#player{guild_id= Val};	
				{guild_id, Val} -> Player#player{guild_id= Val};	
				{guild_name, Val, add} -> Player#player{guild_name=Player#player.guild_name + Val};	
				{guild_name, Val, sub} -> Player#player{guild_name=Player#player.guild_name - Val};	
				{guild_name, Val, _} -> Player#player{guild_name= Val};	
				{guild_name, Val} -> Player#player{guild_name= Val};	
				{guild_position, Val, add} -> Player#player{guild_position=Player#player.guild_position + Val};	
				{guild_position, Val, sub} -> Player#player{guild_position=Player#player.guild_position - Val};	
				{guild_position, Val, _} -> Player#player{guild_position= Val};	
				{guild_position, Val} -> Player#player{guild_position= Val};	
				{quit_guild_time, Val, add} -> Player#player{quit_guild_time=Player#player.quit_guild_time + Val};	
				{quit_guild_time, Val, sub} -> Player#player{quit_guild_time=Player#player.quit_guild_time - Val};	
				{quit_guild_time, Val, _} -> Player#player{quit_guild_time= Val};	
				{quit_guild_time, Val} -> Player#player{quit_guild_time= Val};	
				{guild_title, Val, add} -> Player#player{guild_title=Player#player.guild_title + Val};	
				{guild_title, Val, sub} -> Player#player{guild_title=Player#player.guild_title - Val};	
				{guild_title, Val, _} -> Player#player{guild_title= Val};	
				{guild_title, Val} -> Player#player{guild_title= Val};	
				{guild_depart_name, Val, add} -> Player#player{guild_depart_name=Player#player.guild_depart_name + Val};	
				{guild_depart_name, Val, sub} -> Player#player{guild_depart_name=Player#player.guild_depart_name - Val};	
				{guild_depart_name, Val, _} -> Player#player{guild_depart_name= Val};	
				{guild_depart_name, Val} -> Player#player{guild_depart_name= Val};	
				{guild_depart_id, Val, add} -> Player#player{guild_depart_id=Player#player.guild_depart_id + Val};	
				{guild_depart_id, Val, sub} -> Player#player{guild_depart_id=Player#player.guild_depart_id - Val};	
				{guild_depart_id, Val, _} -> Player#player{guild_depart_id= Val};	
				{guild_depart_id, Val} -> Player#player{guild_depart_id= Val};	
				{speed, Val, add} -> Player#player{speed=Player#player.speed + Val};	
				{speed, Val, sub} -> Player#player{speed=Player#player.speed - Val};	
				{speed, Val, _} -> Player#player{speed= Val};	
				{speed, Val} -> Player#player{speed= Val};	
				{att_speed, Val, add} -> Player#player{att_speed=Player#player.att_speed + Val};	
				{att_speed, Val, sub} -> Player#player{att_speed=Player#player.att_speed - Val};	
				{att_speed, Val, _} -> Player#player{att_speed= Val};	
				{att_speed, Val} -> Player#player{att_speed= Val};	
				{equip, Val, add} -> Player#player{equip=Player#player.equip + Val};	
				{equip, Val, sub} -> Player#player{equip=Player#player.equip - Val};	
				{equip, Val, _} -> Player#player{equip= Val};	
				{equip, Val} -> Player#player{equip= Val};	
				{vip, Val, add} -> Player#player{vip=Player#player.vip + Val};	
				{vip, Val, sub} -> Player#player{vip=Player#player.vip - Val};	
				{vip, Val, _} -> Player#player{vip= Val};	
				{vip, Val} -> Player#player{vip= Val};	
				{vip_time, Val, add} -> Player#player{vip_time=Player#player.vip_time + Val};	
				{vip_time, Val, sub} -> Player#player{vip_time=Player#player.vip_time - Val};	
				{vip_time, Val, _} -> Player#player{vip_time= Val};	
				{vip_time, Val} -> Player#player{vip_time= Val};	
				{online_flag, Val, add} -> Player#player{online_flag=Player#player.online_flag + Val};	
				{online_flag, Val, sub} -> Player#player{online_flag=Player#player.online_flag - Val};	
				{online_flag, Val, _} -> Player#player{online_flag= Val};	
				{online_flag, Val} -> Player#player{online_flag= Val};	
				{pet_upgrade_que_num, Val, add} -> Player#player{pet_upgrade_que_num=Player#player.pet_upgrade_que_num + Val};	
				{pet_upgrade_que_num, Val, sub} -> Player#player{pet_upgrade_que_num=Player#player.pet_upgrade_que_num - Val};	
				{pet_upgrade_que_num, Val, _} -> Player#player{pet_upgrade_que_num= Val};	
				{pet_upgrade_que_num, Val} -> Player#player{pet_upgrade_que_num= Val};	
				{daily_task_limit, Val, add} -> Player#player{daily_task_limit=Player#player.daily_task_limit + Val};	
				{daily_task_limit, Val, sub} -> Player#player{daily_task_limit=Player#player.daily_task_limit - Val};	
				{daily_task_limit, Val, _} -> Player#player{daily_task_limit= Val};	
				{daily_task_limit, Val} -> Player#player{daily_task_limit= Val};	
				{carry_mark, Val, add} -> Player#player{carry_mark=Player#player.carry_mark + Val};	
				{carry_mark, Val, sub} -> Player#player{carry_mark=Player#player.carry_mark - Val};	
				{carry_mark, Val, _} -> Player#player{carry_mark= Val};	
				{carry_mark, Val} -> Player#player{carry_mark= Val};	
				{task_convoy_npc, Val, add} -> Player#player{task_convoy_npc=Player#player.task_convoy_npc + Val};	
				{task_convoy_npc, Val, sub} -> Player#player{task_convoy_npc=Player#player.task_convoy_npc - Val};	
				{task_convoy_npc, Val, _} -> Player#player{task_convoy_npc= Val};	
				{task_convoy_npc, Val} -> Player#player{task_convoy_npc= Val};	
				{store_num, Val, add} -> Player#player{store_num=Player#player.store_num + Val};	
				{store_num, Val, sub} -> Player#player{store_num=Player#player.store_num - Val};	
				{store_num, Val, _} -> Player#player{store_num= Val};	
				{store_num, Val} -> Player#player{store_num= Val};	
				{online_gift, Val, add} -> Player#player{online_gift=Player#player.online_gift + Val};	
				{online_gift, Val, sub} -> Player#player{online_gift=Player#player.online_gift - Val};	
				{online_gift, Val, _} -> Player#player{online_gift= Val};	
				{online_gift, Val} -> Player#player{online_gift= Val};	
				{target_gift, Val, add} -> Player#player{target_gift=Player#player.target_gift + Val};	
				{target_gift, Val, sub} -> Player#player{target_gift=Player#player.target_gift - Val};	
				{target_gift, Val, _} -> Player#player{target_gift= Val};	
				{target_gift, Val} -> Player#player{target_gift= Val};	
				{arena, Val, add} -> Player#player{arena=Player#player.arena + Val};	
				{arena, Val, sub} -> Player#player{arena=Player#player.arena - Val};	
				{arena, Val, _} -> Player#player{arena= Val};	
				{arena, Val} -> Player#player{arena= Val};	
				{arena_score, Val, add} -> Player#player{arena_score=Player#player.arena_score + Val};	
				{arena_score, Val, sub} -> Player#player{arena_score=Player#player.arena_score - Val};	
				{arena_score, Val, _} -> Player#player{arena_score= Val};	
				{arena_score, Val} -> Player#player{arena_score= Val};	
				{sn, Val, add} -> Player#player{sn=Player#player.sn + Val};	
				{sn, Val, sub} -> Player#player{sn=Player#player.sn - Val};	
				{sn, Val, _} -> Player#player{sn= Val};	
				{sn, Val} -> Player#player{sn= Val};	
				{realm_honor, Val, add} -> Player#player{realm_honor=Player#player.realm_honor + Val};	
				{realm_honor, Val, sub} -> Player#player{realm_honor=Player#player.realm_honor - Val};	
				{realm_honor, Val, _} -> Player#player{realm_honor= Val};	
				{realm_honor, Val} -> Player#player{realm_honor= Val};	
				{base_player_attribute, Val, add} -> Player#player{other=Player#player.other#player_other{base_player_attribute = Player#player.other#player_other.base_player_attribute + Val}};	
				{base_player_attribute, Val, sub} -> Player#player{other=Player#player.other#player_other{base_player_attribute = Player#player.other#player_other.base_player_attribute - Val}};	
				{base_player_attribute, Val, _} -> Player#player{other=Player#player.other#player_other{base_player_attribute =  Val}};	
				{base_player_attribute, Val} -> Player#player{other=Player#player.other#player_other{base_player_attribute =  Val}};	
				{base_attribute, Val, add} -> Player#player{other=Player#player.other#player_other{base_attribute = Player#player.other#player_other.base_attribute + Val}};	
				{base_attribute, Val, sub} -> Player#player{other=Player#player.other#player_other{base_attribute = Player#player.other#player_other.base_attribute - Val}};	
				{base_attribute, Val, _} -> Player#player{other=Player#player.other#player_other{base_attribute =  Val}};	
				{base_attribute, Val} -> Player#player{other=Player#player.other#player_other{base_attribute =  Val}};	
				{two_attribute, Val, add} -> Player#player{other=Player#player.other#player_other{two_attribute = Player#player.other#player_other.two_attribute + Val}};	
				{two_attribute, Val, sub} -> Player#player{other=Player#player.other#player_other{two_attribute = Player#player.other#player_other.two_attribute - Val}};	
				{two_attribute, Val, _} -> Player#player{other=Player#player.other#player_other{two_attribute =  Val}};	
				{two_attribute, Val} -> Player#player{other=Player#player.other#player_other{two_attribute =  Val}};	
				{pet_attribute, Val, add} -> Player#player{other=Player#player.other#player_other{pet_attribute = Player#player.other#player_other.pet_attribute + Val}};	
				{pet_attribute, Val, sub} -> Player#player{other=Player#player.other#player_other{pet_attribute = Player#player.other#player_other.pet_attribute - Val}};	
				{pet_attribute, Val, _} -> Player#player{other=Player#player.other#player_other{pet_attribute =  Val}};	
				{pet_attribute, Val} -> Player#player{other=Player#player.other#player_other{pet_attribute =  Val}};	
				{pet_skill_mult_attribute, Val, add} -> Player#player{other=Player#player.other#player_other{pet_skill_mult_attribute = Player#player.other#player_other.pet_skill_mult_attribute + Val}};	
				{pet_skill_mult_attribute, Val, sub} -> Player#player{other=Player#player.other#player_other{pet_skill_mult_attribute = Player#player.other#player_other.pet_skill_mult_attribute - Val}};	
				{pet_skill_mult_attribute, Val, _} -> Player#player{other=Player#player.other#player_other{pet_skill_mult_attribute =  Val}};	
				{pet_skill_mult_attribute, Val} -> Player#player{other=Player#player.other#player_other{pet_skill_mult_attribute =  Val}};	
				{mount_mult_attribute, Val, add} -> Player#player{other=Player#player.other#player_other{mount_mult_attribute = Player#player.other#player_other.mount_mult_attribute + Val}};	
				{mount_mult_attribute, Val, sub} -> Player#player{other=Player#player.other#player_other{mount_mult_attribute = Player#player.other#player_other.mount_mult_attribute - Val}};	
				{mount_mult_attribute, Val, _} -> Player#player{other=Player#player.other#player_other{mount_mult_attribute =  Val}};	
				{mount_mult_attribute, Val} -> Player#player{other=Player#player.other#player_other{mount_mult_attribute =  Val}};	
				{equip_attrit, Val, add} -> Player#player{other=Player#player.other#player_other{equip_attrit = Player#player.other#player_other.equip_attrit + Val}};	
				{equip_attrit, Val, sub} -> Player#player{other=Player#player.other#player_other{equip_attrit = Player#player.other#player_other.equip_attrit - Val}};	
				{equip_attrit, Val, _} -> Player#player{other=Player#player.other#player_other{equip_attrit =  Val}};	
				{equip_attrit, Val} -> Player#player{other=Player#player.other#player_other{equip_attrit =  Val}};	
				{equip_current, Val, add} -> Player#player{other=Player#player.other#player_other{equip_current = Player#player.other#player_other.equip_current + Val}};	
				{equip_current, Val, sub} -> Player#player{other=Player#player.other#player_other{equip_current = Player#player.other#player_other.equip_current - Val}};	
				{equip_current, Val, _} -> Player#player{other=Player#player.other#player_other{equip_current =  Val}};	
				{equip_current, Val} -> Player#player{other=Player#player.other#player_other{equip_current =  Val}};	
				{equip_attribute, Val, add} -> Player#player{other=Player#player.other#player_other{equip_attribute = Player#player.other#player_other.equip_attribute + Val}};	
				{equip_attribute, Val, sub} -> Player#player{other=Player#player.other#player_other{equip_attribute = Player#player.other#player_other.equip_attribute - Val}};	
				{equip_attribute, Val, _} -> Player#player{other=Player#player.other#player_other{equip_attribute =  Val}};	
				{equip_attribute, Val} -> Player#player{other=Player#player.other#player_other{equip_attribute =  Val}};	
				{equip_player_attribute, Val, add} -> Player#player{other=Player#player.other#player_other{equip_player_attribute = Player#player.other#player_other.equip_player_attribute + Val}};	
				{equip_player_attribute, Val, sub} -> Player#player{other=Player#player.other#player_other{equip_player_attribute = Player#player.other#player_other.equip_player_attribute - Val}};	
				{equip_player_attribute, Val, _} -> Player#player{other=Player#player.other#player_other{equip_player_attribute =  Val}};	
				{equip_player_attribute, Val} -> Player#player{other=Player#player.other#player_other{equip_player_attribute =  Val}};	
				{equip_mult_attribute, Val, add} -> Player#player{other=Player#player.other#player_other{equip_mult_attribute = Player#player.other#player_other.equip_mult_attribute + Val}};	
				{equip_mult_attribute, Val, sub} -> Player#player{other=Player#player.other#player_other{equip_mult_attribute = Player#player.other#player_other.equip_mult_attribute - Val}};	
				{equip_mult_attribute, Val, _} -> Player#player{other=Player#player.other#player_other{equip_mult_attribute =  Val}};	
				{equip_mult_attribute, Val} -> Player#player{other=Player#player.other#player_other{equip_mult_attribute =  Val}};	
				{meridian_attribute, Val, add} -> Player#player{other=Player#player.other#player_other{meridian_attribute = Player#player.other#player_other.meridian_attribute + Val}};	
				{meridian_attribute, Val, sub} -> Player#player{other=Player#player.other#player_other{meridian_attribute = Player#player.other#player_other.meridian_attribute - Val}};	
				{meridian_attribute, Val, _} -> Player#player{other=Player#player.other#player_other{meridian_attribute =  Val}};	
				{meridian_attribute, Val} -> Player#player{other=Player#player.other#player_other{meridian_attribute =  Val}};	
				{leader, Val, add} -> Player#player{other=Player#player.other#player_other{leader = Player#player.other#player_other.leader + Val}};	
				{leader, Val, sub} -> Player#player{other=Player#player.other#player_other{leader = Player#player.other#player_other.leader - Val}};	
				{leader, Val, _} -> Player#player{other=Player#player.other#player_other{leader =  Val}};	
				{leader, Val} -> Player#player{other=Player#player.other#player_other{leader =  Val}};	
				{skill, Val, add} -> Player#player{other=Player#player.other#player_other{skill = Player#player.other#player_other.skill + Val}};	
				{skill, Val, sub} -> Player#player{other=Player#player.other#player_other{skill = Player#player.other#player_other.skill - Val}};	
				{skill, Val, _} -> Player#player{other=Player#player.other#player_other{skill =  Val}};	
				{skill, Val} -> Player#player{other=Player#player.other#player_other{skill =  Val}};	
				{light_skill, Val, add} -> Player#player{other=Player#player.other#player_other{light_skill = Player#player.other#player_other.light_skill + Val}};	
				{light_skill, Val, sub} -> Player#player{other=Player#player.other#player_other{light_skill = Player#player.other#player_other.light_skill - Val}};	
				{light_skill, Val, _} -> Player#player{other=Player#player.other#player_other{light_skill =  Val}};	
				{light_skill, Val} -> Player#player{other=Player#player.other#player_other{light_skill =  Val}};	
				{passive_skill, Val, add} -> Player#player{other=Player#player.other#player_other{passive_skill = Player#player.other#player_other.passive_skill + Val}};	
				{passive_skill, Val, sub} -> Player#player{other=Player#player.other#player_other{passive_skill = Player#player.other#player_other.passive_skill - Val}};	
				{passive_skill, Val, _} -> Player#player{other=Player#player.other#player_other{passive_skill =  Val}};	
				{passive_skill, Val} -> Player#player{other=Player#player.other#player_other{passive_skill =  Val}};	
				{deputy_skill, Val, add} -> Player#player{other=Player#player.other#player_other{deputy_skill = Player#player.other#player_other.deputy_skill + Val}};	
				{deputy_skill, Val, sub} -> Player#player{other=Player#player.other#player_other{deputy_skill = Player#player.other#player_other.deputy_skill - Val}};	
				{deputy_skill, Val, _} -> Player#player{other=Player#player.other#player_other{deputy_skill =  Val}};	
				{deputy_skill, Val} -> Player#player{other=Player#player.other#player_other{deputy_skill =  Val}};	
				{deputy_prof_lv, Val, add} -> Player#player{other=Player#player.other#player_other{deputy_prof_lv = Player#player.other#player_other.deputy_prof_lv + Val}};	
				{deputy_prof_lv, Val, sub} -> Player#player{other=Player#player.other#player_other{deputy_prof_lv = Player#player.other#player_other.deputy_prof_lv - Val}};	
				{deputy_prof_lv, Val, _} -> Player#player{other=Player#player.other#player_other{deputy_prof_lv =  Val}};	
				{deputy_prof_lv, Val} -> Player#player{other=Player#player.other#player_other{deputy_prof_lv =  Val}};	
				{deputy_passive_att, Val, add} -> Player#player{other=Player#player.other#player_other{deputy_passive_att = Player#player.other#player_other.deputy_passive_att + Val}};	
				{deputy_passive_att, Val, sub} -> Player#player{other=Player#player.other#player_other{deputy_passive_att = Player#player.other#player_other.deputy_passive_att - Val}};	
				{deputy_passive_att, Val, _} -> Player#player{other=Player#player.other#player_other{deputy_passive_att =  Val}};	
				{deputy_passive_att, Val} -> Player#player{other=Player#player.other#player_other{deputy_passive_att =  Val}};	
				{stren, Val, add} -> Player#player{other=Player#player.other#player_other{stren = Player#player.other#player_other.stren + Val}};	
				{stren, Val, sub} -> Player#player{other=Player#player.other#player_other{stren = Player#player.other#player_other.stren - Val}};	
				{stren, Val, _} -> Player#player{other=Player#player.other#player_other{stren =  Val}};	
				{stren, Val} -> Player#player{other=Player#player.other#player_other{stren =  Val}};	
				{fbyfstren, Val, add} -> Player#player{other=Player#player.other#player_other{fbyfstren = Player#player.other#player_other.fbyfstren + Val}};	
				{fbyfstren, Val, sub} -> Player#player{other=Player#player.other#player_other{fbyfstren = Player#player.other#player_other.fbyfstren - Val}};	
				{fbyfstren, Val, _} -> Player#player{other=Player#player.other#player_other{fbyfstren =  Val}};	
				{fbyfstren, Val} -> Player#player{other=Player#player.other#player_other{fbyfstren =  Val}};	
				{spyfstren, Val, add} -> Player#player{other=Player#player.other#player_other{spyfstren = Player#player.other#player_other.spyfstren + Val}};	
				{spyfstren, Val, sub} -> Player#player{other=Player#player.other#player_other{spyfstren = Player#player.other#player_other.spyfstren - Val}};	
				{spyfstren, Val, _} -> Player#player{other=Player#player.other#player_other{spyfstren =  Val}};	
				{spyfstren, Val} -> Player#player{other=Player#player.other#player_other{spyfstren =  Val}};	
				{fullstren, Val, add} -> Player#player{other=Player#player.other#player_other{fullstren = Player#player.other#player_other.fullstren + Val}};	
				{fullstren, Val, sub} -> Player#player{other=Player#player.other#player_other{fullstren = Player#player.other#player_other.fullstren - Val}};	
				{fullstren, Val, _} -> Player#player{other=Player#player.other#player_other{fullstren =  Val}};	
				{fullstren, Val} -> Player#player{other=Player#player.other#player_other{fullstren =  Val}};	
				{suitid, Val, add} -> Player#player{other=Player#player.other#player_other{suitid = Player#player.other#player_other.suitid + Val}};	
				{suitid, Val, sub} -> Player#player{other=Player#player.other#player_other{suitid = Player#player.other#player_other.suitid - Val}};	
				{suitid, Val, _} -> Player#player{other=Player#player.other#player_other{suitid =  Val}};	
				{suitid, Val} -> Player#player{other=Player#player.other#player_other{suitid =  Val}};	
				{out_pet, Val, add} -> Player#player{other=Player#player.other#player_other{out_pet = Player#player.other#player_other.out_pet + Val}};	
				{out_pet, Val, sub} -> Player#player{other=Player#player.other#player_other{out_pet = Player#player.other#player_other.out_pet - Val}};	
				{out_pet, Val, _} -> Player#player{other=Player#player.other#player_other{out_pet =  Val}};	
				{out_pet, Val} -> Player#player{other=Player#player.other#player_other{out_pet =  Val}};	
				{socket, Val, add} -> Player#player{other=Player#player.other#player_other{socket = Player#player.other#player_other.socket + Val}};	
				{socket, Val, sub} -> Player#player{other=Player#player.other#player_other{socket = Player#player.other#player_other.socket - Val}};	
				{socket, Val, _} -> Player#player{other=Player#player.other#player_other{socket =  Val}};	
				{socket, Val} -> Player#player{other=Player#player.other#player_other{socket =  Val}};	
				{socket2, Val, add} -> Player#player{other=Player#player.other#player_other{socket2 = Player#player.other#player_other.socket2 + Val}};	
				{socket2, Val, sub} -> Player#player{other=Player#player.other#player_other{socket2 = Player#player.other#player_other.socket2 - Val}};	
				{socket2, Val, _} -> Player#player{other=Player#player.other#player_other{socket2 =  Val}};	
				{socket2, Val} -> Player#player{other=Player#player.other#player_other{socket2 =  Val}};	
				{socket3, Val, add} -> Player#player{other=Player#player.other#player_other{socket3 = Player#player.other#player_other.socket3 + Val}};	
				{socket3, Val, sub} -> Player#player{other=Player#player.other#player_other{socket3 = Player#player.other#player_other.socket3 - Val}};	
				{socket3, Val, _} -> Player#player{other=Player#player.other#player_other{socket3 =  Val}};	
				{socket3, Val} -> Player#player{other=Player#player.other#player_other{socket3 =  Val}};	
				{pid_socket, Val, add} -> Player#player{other=Player#player.other#player_other{pid_socket = Player#player.other#player_other.pid_socket + Val}};	
				{pid_socket, Val, sub} -> Player#player{other=Player#player.other#player_other{pid_socket = Player#player.other#player_other.pid_socket - Val}};	
				{pid_socket, Val, _} -> Player#player{other=Player#player.other#player_other{pid_socket =  Val}};	
				{pid_socket, Val} -> Player#player{other=Player#player.other#player_other{pid_socket =  Val}};	
				{pid, Val, add} -> Player#player{other=Player#player.other#player_other{pid = Player#player.other#player_other.pid + Val}};	
				{pid, Val, sub} -> Player#player{other=Player#player.other#player_other{pid = Player#player.other#player_other.pid - Val}};	
				{pid, Val, _} -> Player#player{other=Player#player.other#player_other{pid =  Val}};	
				{pid, Val} -> Player#player{other=Player#player.other#player_other{pid =  Val}};	
				{pid_goods, Val, add} -> Player#player{other=Player#player.other#player_other{pid_goods = Player#player.other#player_other.pid_goods + Val}};	
				{pid_goods, Val, sub} -> Player#player{other=Player#player.other#player_other{pid_goods = Player#player.other#player_other.pid_goods - Val}};	
				{pid_goods, Val, _} -> Player#player{other=Player#player.other#player_other{pid_goods =  Val}};	
				{pid_goods, Val} -> Player#player{other=Player#player.other#player_other{pid_goods =  Val}};	
				{pid_send, Val, add} -> Player#player{other=Player#player.other#player_other{pid_send = Player#player.other#player_other.pid_send + Val}};	
				{pid_send, Val, sub} -> Player#player{other=Player#player.other#player_other{pid_send = Player#player.other#player_other.pid_send - Val}};	
				{pid_send, Val, _} -> Player#player{other=Player#player.other#player_other{pid_send =  Val}};	
				{pid_send, Val} -> Player#player{other=Player#player.other#player_other{pid_send =  Val}};	
				{pid_send2, Val, add} -> Player#player{other=Player#player.other#player_other{pid_send2 = Player#player.other#player_other.pid_send2 + Val}};	
				{pid_send2, Val, sub} -> Player#player{other=Player#player.other#player_other{pid_send2 = Player#player.other#player_other.pid_send2 - Val}};	
				{pid_send2, Val, _} -> Player#player{other=Player#player.other#player_other{pid_send2 =  Val}};	
				{pid_send2, Val} -> Player#player{other=Player#player.other#player_other{pid_send2 =  Val}};	
				{pid_send3, Val, add} -> Player#player{other=Player#player.other#player_other{pid_send3 = Player#player.other#player_other.pid_send3 + Val}};	
				{pid_send3, Val, sub} -> Player#player{other=Player#player.other#player_other{pid_send3 = Player#player.other#player_other.pid_send3 - Val}};	
				{pid_send3, Val, _} -> Player#player{other=Player#player.other#player_other{pid_send3 =  Val}};	
				{pid_send3, Val} -> Player#player{other=Player#player.other#player_other{pid_send3 =  Val}};	
				{pid_dungeon, Val, add} -> Player#player{other=Player#player.other#player_other{pid_dungeon = Player#player.other#player_other.pid_dungeon + Val}};	
				{pid_dungeon, Val, sub} -> Player#player{other=Player#player.other#player_other{pid_dungeon = Player#player.other#player_other.pid_dungeon - Val}};	
				{pid_dungeon, Val, _} -> Player#player{other=Player#player.other#player_other{pid_dungeon =  Val}};	
				{pid_dungeon, Val} -> Player#player{other=Player#player.other#player_other{pid_dungeon =  Val}};	
				{pid_fst, Val, add} -> Player#player{other=Player#player.other#player_other{pid_fst = Player#player.other#player_other.pid_fst + Val}};	
				{pid_fst, Val, sub} -> Player#player{other=Player#player.other#player_other{pid_fst = Player#player.other#player_other.pid_fst - Val}};	
				{pid_fst, Val, _} -> Player#player{other=Player#player.other#player_other{pid_fst =  Val}};	
				{pid_fst, Val} -> Player#player{other=Player#player.other#player_other{pid_fst =  Val}};	
				{pid_team, Val, add} -> Player#player{other=Player#player.other#player_other{pid_team = Player#player.other#player_other.pid_team + Val}};	
				{pid_team, Val, sub} -> Player#player{other=Player#player.other#player_other{pid_team = Player#player.other#player_other.pid_team - Val}};	
				{pid_team, Val, _} -> Player#player{other=Player#player.other#player_other{pid_team =  Val}};	
				{pid_team, Val} -> Player#player{other=Player#player.other#player_other{pid_team =  Val}};	
				{pid_scene, Val, add} -> Player#player{other=Player#player.other#player_other{pid_scene = Player#player.other#player_other.pid_scene + Val}};	
				{pid_scene, Val, sub} -> Player#player{other=Player#player.other#player_other{pid_scene = Player#player.other#player_other.pid_scene - Val}};	
				{pid_scene, Val, _} -> Player#player{other=Player#player.other#player_other{pid_scene =  Val}};	
				{pid_scene, Val} -> Player#player{other=Player#player.other#player_other{pid_scene =  Val}};	
				{pid_task, Val, add} -> Player#player{other=Player#player.other#player_other{pid_task = Player#player.other#player_other.pid_task + Val}};	
				{pid_task, Val, sub} -> Player#player{other=Player#player.other#player_other{pid_task = Player#player.other#player_other.pid_task - Val}};	
				{pid_task, Val, _} -> Player#player{other=Player#player.other#player_other{pid_task =  Val}};	
				{pid_task, Val} -> Player#player{other=Player#player.other#player_other{pid_task =  Val}};	
				{pid_meridian, Val, add} -> Player#player{other=Player#player.other#player_other{pid_meridian = Player#player.other#player_other.pid_meridian + Val}};	
				{pid_meridian, Val, sub} -> Player#player{other=Player#player.other#player_other{pid_meridian = Player#player.other#player_other.pid_meridian - Val}};	
				{pid_meridian, Val, _} -> Player#player{other=Player#player.other#player_other{pid_meridian =  Val}};	
				{pid_meridian, Val} -> Player#player{other=Player#player.other#player_other{pid_meridian =  Val}};	
				{pid_love, Val, add} -> Player#player{other=Player#player.other#player_other{pid_love = Player#player.other#player_other.pid_love + Val}};	
				{pid_love, Val, sub} -> Player#player{other=Player#player.other#player_other{pid_love = Player#player.other#player_other.pid_love - Val}};	
				{pid_love, Val, _} -> Player#player{other=Player#player.other#player_other{pid_love =  Val}};	
				{pid_love, Val} -> Player#player{other=Player#player.other#player_other{pid_love =  Val}};	
				{node, Val, add} -> Player#player{other=Player#player.other#player_other{node = Player#player.other#player_other.node + Val}};	
				{node, Val, sub} -> Player#player{other=Player#player.other#player_other{node = Player#player.other#player_other.node - Val}};	
				{node, Val, _} -> Player#player{other=Player#player.other#player_other{node =  Val}};	
				{node, Val} -> Player#player{other=Player#player.other#player_other{node =  Val}};	
				{battle_status, Val, add} -> Player#player{other=Player#player.other#player_other{battle_status = Player#player.other#player_other.battle_status + Val}};	
				{battle_status, Val, sub} -> Player#player{other=Player#player.other#player_other{battle_status = Player#player.other#player_other.battle_status - Val}};	
				{battle_status, Val, _} -> Player#player{other=Player#player.other#player_other{battle_status =  Val}};	
				{battle_status, Val} -> Player#player{other=Player#player.other#player_other{battle_status =  Val}};	
				{battle_limit, Val, add} -> Player#player{other=Player#player.other#player_other{battle_limit = Player#player.other#player_other.battle_limit + Val}};	
				{battle_limit, Val, sub} -> Player#player{other=Player#player.other#player_other{battle_limit = Player#player.other#player_other.battle_limit - Val}};	
				{battle_limit, Val, _} -> Player#player{other=Player#player.other#player_other{battle_limit =  Val}};	
				{battle_limit, Val} -> Player#player{other=Player#player.other#player_other{battle_limit =  Val}};	
				{trade_status, Val, add} -> Player#player{other=Player#player.other#player_other{trade_status = Player#player.other#player_other.trade_status + Val}};	
				{trade_status, Val, sub} -> Player#player{other=Player#player.other#player_other{trade_status = Player#player.other#player_other.trade_status - Val}};	
				{trade_status, Val, _} -> Player#player{other=Player#player.other#player_other{trade_status =  Val}};	
				{trade_status, Val} -> Player#player{other=Player#player.other#player_other{trade_status =  Val}};	
				{trade_list, Val, add} -> Player#player{other=Player#player.other#player_other{trade_list = Player#player.other#player_other.trade_list + Val}};	
				{trade_list, Val, sub} -> Player#player{other=Player#player.other#player_other{trade_list = Player#player.other#player_other.trade_list - Val}};	
				{trade_list, Val, _} -> Player#player{other=Player#player.other#player_other{trade_list =  Val}};	
				{trade_list, Val} -> Player#player{other=Player#player.other#player_other{trade_list =  Val}};	
				{goods_buff, Val, add} -> Player#player{other=Player#player.other#player_other{goods_buff = Player#player.other#player_other.goods_buff + Val}};	
				{goods_buff, Val, sub} -> Player#player{other=Player#player.other#player_other{goods_buff = Player#player.other#player_other.goods_buff - Val}};	
				{goods_buff, Val, _} -> Player#player{other=Player#player.other#player_other{goods_buff =  Val}};	
				{goods_buff, Val} -> Player#player{other=Player#player.other#player_other{goods_buff =  Val}};	
				{fst_exp_ttl, Val, add} -> Player#player{other=Player#player.other#player_other{fst_exp_ttl = Player#player.other#player_other.fst_exp_ttl + Val}};	
				{fst_exp_ttl, Val, sub} -> Player#player{other=Player#player.other#player_other{fst_exp_ttl = Player#player.other#player_other.fst_exp_ttl - Val}};	
				{fst_exp_ttl, Val, _} -> Player#player{other=Player#player.other#player_other{fst_exp_ttl =  Val}};	
				{fst_exp_ttl, Val} -> Player#player{other=Player#player.other#player_other{fst_exp_ttl =  Val}};	
				{fst_spr_ttl, Val, add} -> Player#player{other=Player#player.other#player_other{fst_spr_ttl = Player#player.other#player_other.fst_spr_ttl + Val}};	
				{fst_spr_ttl, Val, sub} -> Player#player{other=Player#player.other#player_other{fst_spr_ttl = Player#player.other#player_other.fst_spr_ttl - Val}};	
				{fst_spr_ttl, Val, _} -> Player#player{other=Player#player.other#player_other{fst_spr_ttl =  Val}};	
				{fst_spr_ttl, Val} -> Player#player{other=Player#player.other#player_other{fst_spr_ttl =  Val}};	
				{fst_hor_ttl, Val, add} -> Player#player{other=Player#player.other#player_other{fst_hor_ttl = Player#player.other#player_other.fst_hor_ttl + Val}};	
				{fst_hor_ttl, Val, sub} -> Player#player{other=Player#player.other#player_other{fst_hor_ttl = Player#player.other#player_other.fst_hor_ttl - Val}};	
				{fst_hor_ttl, Val, _} -> Player#player{other=Player#player.other#player_other{fst_hor_ttl =  Val}};	
				{fst_hor_ttl, Val} -> Player#player{other=Player#player.other#player_other{fst_hor_ttl =  Val}};	
				{be_bless_time, Val, add} -> Player#player{other=Player#player.other#player_other{be_bless_time = Player#player.other#player_other.be_bless_time + Val}};	
				{be_bless_time, Val, sub} -> Player#player{other=Player#player.other#player_other{be_bless_time = Player#player.other#player_other.be_bless_time - Val}};	
				{be_bless_time, Val, _} -> Player#player{other=Player#player.other#player_other{be_bless_time =  Val}};	
				{be_bless_time, Val} -> Player#player{other=Player#player.other#player_other{be_bless_time =  Val}};	
				{bless_limit_time, Val, add} -> Player#player{other=Player#player.other#player_other{bless_limit_time = Player#player.other#player_other.bless_limit_time + Val}};	
				{bless_limit_time, Val, sub} -> Player#player{other=Player#player.other#player_other{bless_limit_time = Player#player.other#player_other.bless_limit_time - Val}};	
				{bless_limit_time, Val, _} -> Player#player{other=Player#player.other#player_other{bless_limit_time =  Val}};	
				{bless_limit_time, Val} -> Player#player{other=Player#player.other#player_other{bless_limit_time =  Val}};	
				{bless_list, Val, add} -> Player#player{other=Player#player.other#player_other{bless_list = Player#player.other#player_other.bless_list + Val}};	
				{bless_list, Val, sub} -> Player#player{other=Player#player.other#player_other{bless_list = Player#player.other#player_other.bless_list - Val}};	
				{bless_list, Val, _} -> Player#player{other=Player#player.other#player_other{bless_list =  Val}};	
				{bless_list, Val} -> Player#player{other=Player#player.other#player_other{bless_list =  Val}};	
				{exc_status, Val, add} -> Player#player{other=Player#player.other#player_other{exc_status = Player#player.other#player_other.exc_status + Val}};	
				{exc_status, Val, sub} -> Player#player{other=Player#player.other#player_other{exc_status = Player#player.other#player_other.exc_status - Val}};	
				{exc_status, Val, _} -> Player#player{other=Player#player.other#player_other{exc_status =  Val}};	
				{exc_status, Val} -> Player#player{other=Player#player.other#player_other{exc_status =  Val}};	
				{mount_stren, Val, add} -> Player#player{other=Player#player.other#player_other{mount_stren = Player#player.other#player_other.mount_stren + Val}};	
				{mount_stren, Val, sub} -> Player#player{other=Player#player.other#player_other{mount_stren = Player#player.other#player_other.mount_stren - Val}};	
				{mount_stren, Val, _} -> Player#player{other=Player#player.other#player_other{mount_stren =  Val}};	
				{mount_stren, Val} -> Player#player{other=Player#player.other#player_other{mount_stren =  Val}};	
				{guild_h_skills, Val, add} -> Player#player{other=Player#player.other#player_other{guild_h_skills = Player#player.other#player_other.guild_h_skills + Val}};	
				{guild_h_skills, Val, sub} -> Player#player{other=Player#player.other#player_other{guild_h_skills = Player#player.other#player_other.guild_h_skills - Val}};	
				{guild_h_skills, Val, _} -> Player#player{other=Player#player.other#player_other{guild_h_skills =  Val}};	
				{guild_h_skills, Val} -> Player#player{other=Player#player.other#player_other{guild_h_skills =  Val}};	
				{guild_feats, Val, add} -> Player#player{other=Player#player.other#player_other{guild_feats = Player#player.other#player_other.guild_feats + Val}};	
				{guild_feats, Val, sub} -> Player#player{other=Player#player.other#player_other{guild_feats = Player#player.other#player_other.guild_feats - Val}};	
				{guild_feats, Val, _} -> Player#player{other=Player#player.other#player_other{guild_feats =  Val}};	
				{guild_feats, Val} -> Player#player{other=Player#player.other#player_other{guild_feats =  Val}};	
				{blacklist, Val, add} -> Player#player{other=Player#player.other#player_other{blacklist = Player#player.other#player_other.blacklist + Val}};	
				{blacklist, Val, sub} -> Player#player{other=Player#player.other#player_other{blacklist = Player#player.other#player_other.blacklist - Val}};	
				{blacklist, Val, _} -> Player#player{other=Player#player.other#player_other{blacklist =  Val}};	
				{blacklist, Val} -> Player#player{other=Player#player.other#player_other{blacklist =  Val}};	
				{charm, Val, add} -> Player#player{other=Player#player.other#player_other{charm = Player#player.other#player_other.charm + Val}};	
				{charm, Val, sub} -> Player#player{other=Player#player.other#player_other{charm = Player#player.other#player_other.charm - Val}};	
				{charm, Val, _} -> Player#player{other=Player#player.other#player_other{charm =  Val}};	
				{charm, Val} -> Player#player{other=Player#player.other#player_other{charm =  Val}};	
				{peach_revel, Val, add} -> Player#player{other=Player#player.other#player_other{peach_revel = Player#player.other#player_other.peach_revel + Val}};	
				{peach_revel, Val, sub} -> Player#player{other=Player#player.other#player_other{peach_revel = Player#player.other#player_other.peach_revel - Val}};	
				{peach_revel, Val, _} -> Player#player{other=Player#player.other#player_other{peach_revel =  Val}};	
				{peach_revel, Val} -> Player#player{other=Player#player.other#player_other{peach_revel =  Val}};	
				{privity_info, Val, add} -> Player#player{other=Player#player.other#player_other{privity_info = Player#player.other#player_other.privity_info + Val}};	
				{privity_info, Val, sub} -> Player#player{other=Player#player.other#player_other{privity_info = Player#player.other#player_other.privity_info - Val}};	
				{privity_info, Val, _} -> Player#player{other=Player#player.other#player_other{privity_info =  Val}};	
				{privity_info, Val} -> Player#player{other=Player#player.other#player_other{privity_info =  Val}};	
				{ach_pearl, Val, add} -> Player#player{other=Player#player.other#player_other{ach_pearl = Player#player.other#player_other.ach_pearl + Val}};	
				{ach_pearl, Val, sub} -> Player#player{other=Player#player.other#player_other{ach_pearl = Player#player.other#player_other.ach_pearl - Val}};	
				{ach_pearl, Val, _} -> Player#player{other=Player#player.other#player_other{ach_pearl =  Val}};	
				{ach_pearl, Val} -> Player#player{other=Player#player.other#player_other{ach_pearl =  Val}};	
				{goods_buf_cd, Val, add} -> Player#player{other=Player#player.other#player_other{goods_buf_cd = Player#player.other#player_other.goods_buf_cd + Val}};	
				{goods_buf_cd, Val, sub} -> Player#player{other=Player#player.other#player_other{goods_buf_cd = Player#player.other#player_other.goods_buf_cd - Val}};	
				{goods_buf_cd, Val, _} -> Player#player{other=Player#player.other#player_other{goods_buf_cd =  Val}};	
				{goods_buf_cd, Val} -> Player#player{other=Player#player.other#player_other{goods_buf_cd =  Val}};	
				{goods_ring4, Val, add} -> Player#player{other=Player#player.other#player_other{goods_ring4 = Player#player.other#player_other.goods_ring4 + Val}};	
				{goods_ring4, Val, sub} -> Player#player{other=Player#player.other#player_other{goods_ring4 = Player#player.other#player_other.goods_ring4 - Val}};	
				{goods_ring4, Val, _} -> Player#player{other=Player#player.other#player_other{goods_ring4 =  Val}};	
				{goods_ring4, Val} -> Player#player{other=Player#player.other#player_other{goods_ring4 =  Val}};	
				{heartbeat, Val, add} -> Player#player{other=Player#player.other#player_other{heartbeat = Player#player.other#player_other.heartbeat + Val}};	
				{heartbeat, Val, sub} -> Player#player{other=Player#player.other#player_other{heartbeat = Player#player.other#player_other.heartbeat - Val}};	
				{heartbeat, Val, _} -> Player#player{other=Player#player.other#player_other{heartbeat =  Val}};	
				{heartbeat, Val} -> Player#player{other=Player#player.other#player_other{heartbeat =  Val}};	
				{battle_dict, Val, add} -> Player#player{other=Player#player.other#player_other{battle_dict = Player#player.other#player_other.battle_dict + Val}};	
				{battle_dict, Val, sub} -> Player#player{other=Player#player.other#player_other{battle_dict = Player#player.other#player_other.battle_dict - Val}};	
				{battle_dict, Val, _} -> Player#player{other=Player#player.other#player_other{battle_dict =  Val}};	
				{battle_dict, Val} -> Player#player{other=Player#player.other#player_other{battle_dict =  Val}};	
				{is_spring, Val, add} -> Player#player{other=Player#player.other#player_other{is_spring = Player#player.other#player_other.is_spring + Val}};	
				{is_spring, Val, sub} -> Player#player{other=Player#player.other#player_other{is_spring = Player#player.other#player_other.is_spring - Val}};	
				{is_spring, Val, _} -> Player#player{other=Player#player.other#player_other{is_spring =  Val}};	
				{is_spring, Val} -> Player#player{other=Player#player.other#player_other{is_spring =  Val}};	
				{zxt_honor, Val, add} -> Player#player{other=Player#player.other#player_other{zxt_honor = Player#player.other#player_other.zxt_honor + Val}};	
				{zxt_honor, Val, sub} -> Player#player{other=Player#player.other#player_other{zxt_honor = Player#player.other#player_other.zxt_honor - Val}};	
				{zxt_honor, Val, _} -> Player#player{other=Player#player.other#player_other{zxt_honor =  Val}};	
				{zxt_honor, Val} -> Player#player{other=Player#player.other#player_other{zxt_honor =  Val}};	
				{team_buff_level, Val, add} -> Player#player{other=Player#player.other#player_other{team_buff_level = Player#player.other#player_other.team_buff_level + Val}};	
				{team_buff_level, Val, sub} -> Player#player{other=Player#player.other#player_other{team_buff_level = Player#player.other#player_other.team_buff_level - Val}};	
				{team_buff_level, Val, _} -> Player#player{other=Player#player.other#player_other{team_buff_level =  Val}};	
				{team_buff_level, Val} -> Player#player{other=Player#player.other#player_other{team_buff_level =  Val}};	
				{die_time, Val, add} -> Player#player{other=Player#player.other#player_other{die_time = Player#player.other#player_other.die_time + Val}};	
				{die_time, Val, sub} -> Player#player{other=Player#player.other#player_other{die_time = Player#player.other#player_other.die_time - Val}};	
				{die_time, Val, _} -> Player#player{other=Player#player.other#player_other{die_time =  Val}};	
				{die_time, Val} -> Player#player{other=Player#player.other#player_other{die_time =  Val}};	
				{war_die_times, Val, add} -> Player#player{other=Player#player.other#player_other{war_die_times = Player#player.other#player_other.war_die_times + Val}};	
				{war_die_times, Val, sub} -> Player#player{other=Player#player.other#player_other{war_die_times = Player#player.other#player_other.war_die_times - Val}};	
				{war_die_times, Val, _} -> Player#player{other=Player#player.other#player_other{war_die_times =  Val}};	
				{war_die_times, Val} -> Player#player{other=Player#player.other#player_other{war_die_times =  Val}};	
				{love_invited, Val, add} -> Player#player{other=Player#player.other#player_other{love_invited = Player#player.other#player_other.love_invited + Val}};	
				{love_invited, Val, sub} -> Player#player{other=Player#player.other#player_other{love_invited = Player#player.other#player_other.love_invited - Val}};	
				{love_invited, Val, _} -> Player#player{other=Player#player.other#player_other{love_invited =  Val}};	
				{love_invited, Val} -> Player#player{other=Player#player.other#player_other{love_invited =  Val}};	
				{batt_value, Val, add} -> Player#player{other=Player#player.other#player_other{batt_value = Player#player.other#player_other.batt_value + Val}};	
				{batt_value, Val, sub} -> Player#player{other=Player#player.other#player_other{batt_value = Player#player.other#player_other.batt_value - Val}};	
				{batt_value, Val, _} -> Player#player{other=Player#player.other#player_other{batt_value =  Val}};	
				{batt_value, Val} -> Player#player{other=Player#player.other#player_other{batt_value =  Val}};	
				{turned, Val, add} -> Player#player{other=Player#player.other#player_other{turned = Player#player.other#player_other.turned + Val}};	
				{turned, Val, sub} -> Player#player{other=Player#player.other#player_other{turned = Player#player.other#player_other.turned - Val}};	
				{turned, Val, _} -> Player#player{other=Player#player.other#player_other{turned =  Val}};	
				{turned, Val} -> Player#player{other=Player#player.other#player_other{turned =  Val}};	
				{titles, Val, add} -> Player#player{other=Player#player.other#player_other{titles = Player#player.other#player_other.titles + Val}};	
				{titles, Val, sub} -> Player#player{other=Player#player.other#player_other{titles = Player#player.other#player_other.titles - Val}};	
				{titles, Val, _} -> Player#player{other=Player#player.other#player_other{titles =  Val}};	
				{titles, Val} -> Player#player{other=Player#player.other#player_other{titles =  Val}};	
				{accept, Val, add} -> Player#player{other=Player#player.other#player_other{accept = Player#player.other#player_other.accept + Val}};	
				{accept, Val, sub} -> Player#player{other=Player#player.other#player_other{accept = Player#player.other#player_other.accept - Val}};	
				{accept, Val, _} -> Player#player{other=Player#player.other#player_other{accept =  Val}};	
				{accept, Val} -> Player#player{other=Player#player.other#player_other{accept =  Val}};	
				{double_rest_id, Val, add} -> Player#player{other=Player#player.other#player_other{double_rest_id = Player#player.other#player_other.double_rest_id + Val}};	
				{double_rest_id, Val, sub} -> Player#player{other=Player#player.other#player_other{double_rest_id = Player#player.other#player_other.double_rest_id - Val}};	
				{double_rest_id, Val, _} -> Player#player{other=Player#player.other#player_other{double_rest_id =  Val}};	
				{double_rest_id, Val} -> Player#player{other=Player#player.other#player_other{double_rest_id =  Val}};	
				{realm_honor_player_list, Val, add} -> Player#player{other=Player#player.other#player_other{realm_honor_player_list = Player#player.other#player_other.realm_honor_player_list + Val}};	
				{realm_honor_player_list, Val, sub} -> Player#player{other=Player#player.other#player_other{realm_honor_player_list = Player#player.other#player_other.realm_honor_player_list - Val}};	
				{realm_honor_player_list, Val, _} -> Player#player{other=Player#player.other#player_other{realm_honor_player_list =  Val}};	
				{realm_honor_player_list, Val} -> Player#player{other=Player#player.other#player_other{realm_honor_player_list =  Val}};	
				{hook_pick, Val, add} -> Player#player{other=Player#player.other#player_other{hook_pick = Player#player.other#player_other.hook_pick + Val}};	
				{hook_pick, Val, sub} -> Player#player{other=Player#player.other#player_other{hook_pick = Player#player.other#player_other.hook_pick - Val}};	
				{hook_pick, Val, _} -> Player#player{other=Player#player.other#player_other{hook_pick =  Val}};	
				{hook_pick, Val} -> Player#player{other=Player#player.other#player_other{hook_pick =  Val}};	
				{hook_equip_list, Val, add} -> Player#player{other=Player#player.other#player_other{hook_equip_list = Player#player.other#player_other.hook_equip_list + Val}};	
				{hook_equip_list, Val, sub} -> Player#player{other=Player#player.other#player_other{hook_equip_list = Player#player.other#player_other.hook_equip_list - Val}};	
				{hook_equip_list, Val, _} -> Player#player{other=Player#player.other#player_other{hook_equip_list =  Val}};	
				{hook_equip_list, Val} -> Player#player{other=Player#player.other#player_other{hook_equip_list =  Val}};	
				{hook_quality_list, Val, add} -> Player#player{other=Player#player.other#player_other{hook_quality_list = Player#player.other#player_other.hook_quality_list + Val}};	
				{hook_quality_list, Val, sub} -> Player#player{other=Player#player.other#player_other{hook_quality_list = Player#player.other#player_other.hook_quality_list - Val}};	
				{hook_quality_list, Val, _} -> Player#player{other=Player#player.other#player_other{hook_quality_list =  Val}};	
				{hook_quality_list, Val} -> Player#player{other=Player#player.other#player_other{hook_quality_list =  Val}};	
				{shop_score, Val, add} -> Player#player{other=Player#player.other#player_other{shop_score = Player#player.other#player_other.shop_score + Val}};	
				{shop_score, Val, sub} -> Player#player{other=Player#player.other#player_other{shop_score = Player#player.other#player_other.shop_score - Val}};	
				{shop_score, Val, _} -> Player#player{other=Player#player.other#player_other{shop_score =  Val}};	
				{shop_score, Val} -> Player#player{other=Player#player.other#player_other{shop_score =  Val}};	
				{castle_king, Val, add} -> Player#player{other=Player#player.other#player_other{castle_king = Player#player.other#player_other.castle_king + Val}};	
				{castle_king, Val, sub} -> Player#player{other=Player#player.other#player_other{castle_king = Player#player.other#player_other.castle_king - Val}};	
				{castle_king, Val, _} -> Player#player{other=Player#player.other#player_other{castle_king =  Val}};	
				{castle_king, Val} -> Player#player{other=Player#player.other#player_other{castle_king =  Val}};	
				{g_alliance, Val, add} -> Player#player{other=Player#player.other#player_other{g_alliance = Player#player.other#player_other.g_alliance + Val}};	
				{g_alliance, Val, sub} -> Player#player{other=Player#player.other#player_other{g_alliance = Player#player.other#player_other.g_alliance - Val}};	
				{g_alliance, Val, _} -> Player#player{other=Player#player.other#player_other{g_alliance =  Val}};	
				{g_alliance, Val} -> Player#player{other=Player#player.other#player_other{g_alliance =  Val}};	
				{war_honor, Val, add} -> Player#player{other=Player#player.other#player_other{war_honor = Player#player.other#player_other.war_honor + Val}};	
				{war_honor, Val, sub} -> Player#player{other=Player#player.other#player_other{war_honor = Player#player.other#player_other.war_honor - Val}};	
				{war_honor, Val, _} -> Player#player{other=Player#player.other#player_other{war_honor =  Val}};	
				{war_honor, Val} -> Player#player{other=Player#player.other#player_other{war_honor =  Val}};	
				{war_honor_value, Val, add} -> Player#player{other=Player#player.other#player_other{war_honor_value = Player#player.other#player_other.war_honor_value + Val}};	
				{war_honor_value, Val, sub} -> Player#player{other=Player#player.other#player_other{war_honor_value = Player#player.other#player_other.war_honor_value - Val}};	
				{war_honor_value, Val, _} -> Player#player{other=Player#player.other#player_other{war_honor_value =  Val}};	
				{war_honor_value, Val} -> Player#player{other=Player#player.other#player_other{war_honor_value =  Val}};	
				{war2_scene, Val, add} -> Player#player{other=Player#player.other#player_other{war2_scene = Player#player.other#player_other.war2_scene + Val}};	
				{war2_scene, Val, sub} -> Player#player{other=Player#player.other#player_other{war2_scene = Player#player.other#player_other.war2_scene - Val}};	
				{war2_scene, Val, _} -> Player#player{other=Player#player.other#player_other{war2_scene =  Val}};	
				{war2_scene, Val} -> Player#player{other=Player#player.other#player_other{war2_scene =  Val}};	
				{shadow, Val, add} -> Player#player{other=Player#player.other#player_other{shadow = Player#player.other#player_other.shadow + Val}};	
				{shadow, Val, sub} -> Player#player{other=Player#player.other#player_other{shadow = Player#player.other#player_other.shadow - Val}};	
				{shadow, Val, _} -> Player#player{other=Player#player.other#player_other{shadow =  Val}};	
				{shadow, Val} -> Player#player{other=Player#player.other#player_other{shadow =  Val}};	
				{couple_skill, Val, add} -> Player#player{other=Player#player.other#player_other{couple_skill = Player#player.other#player_other.couple_skill + Val}};	
				{couple_skill, Val, sub} -> Player#player{other=Player#player.other#player_other{couple_skill = Player#player.other#player_other.couple_skill - Val}};	
				{couple_skill, Val, _} -> Player#player{other=Player#player.other#player_other{couple_skill =  Val}};	
				{couple_skill, Val} -> Player#player{other=Player#player.other#player_other{couple_skill =  Val}};	
				{pet_batt_skill, Val, add} -> Player#player{other=Player#player.other#player_other{pet_batt_skill = Player#player.other#player_other.pet_batt_skill + Val}};	
				{pet_batt_skill, Val, sub} -> Player#player{other=Player#player.other#player_other{pet_batt_skill = Player#player.other#player_other.pet_batt_skill - Val}};	
				{pet_batt_skill, Val, _} -> Player#player{other=Player#player.other#player_other{pet_batt_skill =  Val}};	
				{pet_batt_skill, Val} -> Player#player{other=Player#player.other#player_other{pet_batt_skill =  Val}};	
			_ -> Player	
		end,	
	set_player_info_fields(NewPlayer, T).	
	
	
%% 根据表名获取其完全字段	
get_table_fields(Table_name) ->	
	Table_fileds = [ 	
		{ log_vip_experience,[{id, 0},{pid, 0},{goods_id, 0},{mark, 0},{timestamp, 0}]},	
		{ach_epic,[{id, 0},{pid, 0},{e1, 0},{e2, 0},{e3, 0},{e4, 0},{e5, 0},{e6, 0},{e7, 0},{e8, 0},{e9, 0},{e10, 0},{e11, 0},{e12, 0},{e13, 0},{e14, 0},{e15, 0},{e16, 0},{e17, 0},{e18, 0},{e19, 0},{e20, 0},{e21, 0},{e22, 0},{e23, 0},{e24, 0},{e25, 0},{e26, 0},{e27, 0},{ef, 0}]},	
		{ach_fs,[{id, 0},{pid, 0},{f1, 0},{f2, 0},{f3, 0},{f4, 0},{f5, 0},{f6, 0},{f7, 0},{f8, 0},{f9, 0},{f10, 0},{f11, 0},{f12, 0},{f13, 0},{f14, 0},{f15, 0},{f16, 0},{f17, 0},{f18, 0},{f19, 0},{f20, 0},{f21, 0},{f22, 0},{f23, 0},{f24, 0},{f25, 0},{f26, 0},{f27, 0},{f28, 0},{f29, 0},{f30, 0},{f31, 0},{f32, 0},{f33, 0},{f34, 0},{f35, 0},{f36, 0},{f37, 0},{f38, 0},{f39, 0},{f40, 0},{f41, 0},{f42, 0},{f43, 0},{f44, 0},{f45, 0},{f46, 0},{f47, 0},{f48, 0},{f49, 0},{f50, 0},{ff, 0}]},	
		{ach_interact,[{id, 0},{pid, 0},{in1, 0},{in2, 0},{in3, 0},{in4, 0},{in5, 0},{in6, 0},{in7, 0},{in8, 0},{in9, 0},{in10, 0},{in11, 0},{in12, 0},{in13, 0},{in14, 0},{in15, 0},{in16, 0},{in17, 0},{in18, 0},{in19, 0},{in20, 0},{in21, 0},{in22, 0},{in23, 0},{in24, 0},{in25, 0},{in26, 0},{in27, 0},{in28, 0},{in29, 0},{in30, 0},{in31, 0},{in32, 0},{inf, 0}]},	
		{ach_task,[{id, 0},{pid, 0},{t1, 0},{t2, 0},{t3, 0},{t4, 0},{t5, 0},{t6, 0},{t7, 0},{t8, 0},{t9, 0},{t10, 0},{t11, 0},{t12, 0},{t13, 0},{t14, 0},{t15, 0},{t16, 0},{t17, 0},{t18, 0},{t19, 0},{t20, 0},{t21, 0},{t22, 0},{t23, 0},{t24, 0},{t25, 0},{t26, 0},{t27, 0},{tf, 0}]},	
		{ach_treasure,[{id, 0},{pid, 0},{ach, 0},{ts1, 0},{ts2, 0},{ts3, 0},{ts4, 0},{ts5, 0},{ts6, 0},{ts7, 0},{ts8, 0},{ts9, 0},{ts10, 0},{ts11, 0},{ts12, 0},{ts13, 0},{ts14, 0},{ts15, 0},{ts16, 0},{ts17, 0},{ts18, 0},{ts19, 0},{ts20, 0},{ts21, 0},{ts22, 0},{ts23, 0},{ts24, 0},{ts25, 0},{ts26, 0},{ts27, 0},{ts28, 0},{ts101, 0},{ts102, 0},{ts103, 0},{ts104, 0},{ts105, 0},{ts106, 0},{ts107, 0},{ts108, 0}]},	
		{ach_trials,[{id, 0},{pid, 0},{tr1, 0},{tr2, 0},{tr3, 0},{tr4, 0},{tr5, 0},{tr6, 0},{tr7, 0},{tr8, 0},{tr9, 0},{tr10, 0},{tr11, 0},{tr12, 0},{tr13, 0},{tr14, 0},{tr15, 0},{tr16, 0},{tr17, 0},{tr18, 0},{tr19, 0},{tr20, 0},{tr21, 0},{tr22, 0},{tr23, 0},{tr24, 0},{tr25, 0},{tr26, 0},{tr27, 0},{tr28, 0},{tr29, 0},{tr30, 0},{tr31, 0},{tr32, 0},{tr33, 0},{tr34, 0},{tr35, 0},{tr36, 0},{tr37, 0},{tr38, 0},{tr39, 0},{tr40, 0},{tr41, 0},{tr42, 0},{tr43, 0},{tr44, 0},{tr45, 0},{tr46, 0},{tr47, 0},{tr48, 0},{tr49, 0},{tr50, 0},{tr51, 0},{tr52, 0},{tr53, 0},{tr54, 0},{tr55, 0},{tr56, 0},{tr57, 0},{tr58, 0},{tr59, 0},{tr60, 0},{tr61, 0},{tr62, 0},{tr63, 0},{trf, 0}]},	
		{ach_yg,[{id, 0},{pid, 0},{y1, 0},{y2, 0},{y3, 0},{y4, 0},{y5, 0},{y6, 0},{y7, 0},{y8, 0},{y9, 0},{y10, 0},{y11, 0},{y12, 0},{y13, 0},{y14, 0},{y15, 0},{y16, 0},{y17, 0},{y18, 0},{y19, 0},{y20, 0},{y21, 0},{y22, 0},{y23, 0},{y24, 0},{y25, 0},{yf, 0}]},	
		{achieve_statistics,[{id, 0},{pid, 0},{trc, 0},{tg, 0},{tfb, 0},{tcul, 0},{tca, 0},{tbus, 0},{tfst, 0},{tcyc, 0},{trm, 0},{trb, "[0,0,0,0,0,0]"},{trbc, "[0,0,0]"},{trbus, 0},{trfst, "[0,0,0]"},{trar, 0},{trf, 0},{trstd, "[0,0,0]"},{trmtd, "[0,0,0]"},{trfbb, "[0,0,0,0]"},{trsixfb, "[0,0,0]"},{trzxt, "[0,0,0]"},{trsm, 0},{trtrain, 0},{trjl, 0},{trds, 0},{trgg, 0},{ygcul, 0},{fsb, "[0,0,0]"},{fssh, 0},{fsc, "[0,0]"},{fssa, "[0,0]"},{fslg, 0},{infl, 0},{inlv, 0},{inlved, 0},{infai, 0},{infao, 0}]},	
		{adminchange,[{id, 0},{name, []},{pid, []},{url, []}]},	
		{admingroup,[{gid, 0},{gname, []},{groupbackground, "0"},{grights, []},{else, []},{ctime, 0},{mtime, 0}]},	
		{adminkind,[{kid, 0},{name, []},{pid, 0},{filename, []},{show, "YES"},{ctime, 0},{mtime, 0}]},	
		{adminlog,[{id, 0},{uid, 0},{username, []},{text, []},{ip, []},{ctime, 0}]},	
		{adminuser,[{uid, 0},{passport, []},{password, []},{username, []},{gid, 0},{super, "NO"},{last_ip, []},{ctime, 0},{mtime, 0},{else, []}]},	
		{adminweallog,[{id, 0},{weal_name, []},{weal_account, []},{weal_nickname, []},{weal_lv, 0},{weal_gold, 0},{weal_send_gold, 0},{weal_goods_type, []},{weal_goods_name, []},{weal_goods_send_num, 0},{weal_apply, []},{weal_review, "0"}]},	
		{anniversary_bless,[{id, 0},{pid, 0},{pname, []},{gid, 0},{time, 0},{content, []}]},	
		{appraise,[{id, 0},{owner_id, 0},{other_id, 0},{type, 0},{adore_num, 0},{handle_num, 0},{ct, 0}]},	
		{arena,[{id, 0},{player_id, 0},{nickname, []},{realm, 0},{career, 0},{lv, 0},{att, 0},{sex, 0},{wins, 0},{score, 0},{pid, "[0,0]"},{jtime, 0}]},	
		{arena_week,[{id, 0},{player_id, 0},{nickname, []},{realm, 0},{career, 0},{lv, 0},{area, 0},{camp, 0},{type, 0},{score, 0},{ctime, 0},{killer, 0}]},	
		{base_answer,[{id, 0},{reply, []},{quest, []},{opt1, []},{opt2, []},{opt3, []},{opt4, []},{order, 0}]},	
		{base_boss_drop,[{id, 0},{mon_id, 0},{color, 0},{limit_num, 0}]},	
		{base_box_goods,[{id, 0},{hole_type, 0},{goods_id, 0},{pro, "0.0000000000"},{num_limit, 0},{goods_id_replace, 0},{show_type, 0}]},	
		{base_business,[{id, 0},{lv, 0},{color, 0},{exp, 0},{spt, 0}]},	
		{base_career,[{career_id, 0},{career_name, []},{forza, 0},{physique, 0},{agile, 0},{wit, 0},{hp_init, 0},{hp_physique, 0.0},{hp_lv, 0.0},{mp_init, 0},{mp_wit, 0.0},{mp_lv, 0.0},{att_init_min, 0},{att_init_max, 0},{att_forza, 0.0},{att_agile, 0.0},{att_wit, 0.0},{hit_init, 0},{hit_forza, 0.0},{hit_agile, 0.0},{hit_wit, 0.0},{hit_lv, 0.0},{dodge_init, 0},{dodge_agile, 0.0},{dodge_lv, 0.0},{crit_init, 0},{crit_lv, 0.0},{att_speed, 0},{init_scene, 0},{init_x, 0},{init_y, 0},{init_att_area, 0},{init_speed, 0},{init_spirit, 0},{init_gold, 0},{init_cash, 0},{init_coin, 0},{init_goods, []}]},	
		{base_carry,[{realm, 0},{seq, 0},{start_time, 0},{end_time, 0},{timestamp, 0}]},	
		{base_culture_state,[{id, 1},{min_state, 0},{state_name, []}]},	
		{base_daily_gift,[{id, 0},{goods_id, 0},{amount, 0}]},	
		{base_dungeon,[{id, 0},{name, []},{def, 0},{out, []},{scene, []},{requirement, []}]},	
		{base_gift,[{id, 0},{key, 0},{goods_id, 0},{goods_name, []}]},	
		{base_goods,[{goods_id, 0},{goods_name, []},{icon, []},{intro, []},{type, 0},{subtype, 0},{equip_type, 0},{bind, 0},{price_type, 0},{price, 0},{trade, 0},{sell_price, 0},{sell, 0},{isdrop, 0},{level, 0},{career, 0},{sex, 0},{job, 0},{forza_limit, 0},{physique_limit, 0},{wit_limit, 0},{agile_limit, 0},{realm, 0},{spirit, 0},{hp, 0},{mp, 0},{forza, 0},{physique, 0},{wit, 0},{agile, 0},{max_attack, 0},{min_attack, 0},{def, 0},{hit, 0},{dodge, 0},{crit, 0},{ten, 0},{anti_wind, 0},{anti_fire, 0},{anti_water, 0},{anti_thunder, 0},{anti_soil, 0},{anti_rift, 0},{speed, 0},{attrition, 0},{suit_id, 0},{max_hole, 0},{max_stren, 0},{max_overlap, 0},{grade, 0},{step, 0},{color, 0},{other_data, []},{expire_time, 0}]},	
		{base_goods_add_attribute,[{id, 0},{goods_id, 0},{color, 0},{attribute_type, 0},{attribute_id, 0},{value_type, 0},{value, 0},{identify, 0}]},	
		{base_goods_attribute,[{attribute_id, 0},{attribute_name, []}]},	
		{base_goods_compose,[{id, 0},{goods_id, 0},{new_id, 0},{fail_id, 0},{coin, 0}]},	
		{base_goods_drop_num,[{id, 0},{mon_id, 0},{drop_num, 0},{ratio, 0}]},	
		{base_goods_drop_rule,[{id, 0},{mon_id, 0},{goods_id, 0},{type, 0},{goods_num, 0},{ratio, 0},{extra, 0}]},	
		{base_goods_fashion,[{id, 0},{goods_id, 0},{max_crit, 0},{min_crit, 0},{max_dodge, 0},{min_dodge, 0},{max_hit, 0},{min_hit, 0},{max_mp, 0},{min_mp, 0},{max_physique, 0},{min_physique, 0},{max_attack, 0},{min_attack, 0},{max_anti_all, 0},{min_anti_all, 0},{max_forza, 0},{min_forza, 0},{max_wit, 0},{min_wit, 0},{max_agile, 0},{min_agile, 0},{max_anti_wind, 0},{min_anti_wind, 0},{max_anti_thunder, 0},{min_anti_thunder, 0},{max_anti_water, 0},{min_anti_water, 0},{max_anti_fire, 0},{min_anti_fire, 0},{max_anti_soil, 0},{min_anti_soil, 0},{max_att_per, 0},{min_att_per, 0},{max_hp_per, 0},{min_hp_per, 0}]},	
		{base_goods_icompose,[{id, 0},{type, "0"},{subtype, "0"},{goods_id, 0},{price, 0},{ratio, 0},{require, []}]},	
		{base_goods_idecompose,[{id, 0},{type, 0},{subtype, 0},{goods_id, 0},{color, 0},{lv_up, 0},{lv_down, 0},{price, 0},{ratio, 0},{target, []}]},	
		{base_goods_inlay,[{id, 0},{goods_id, 0},{equip_types, []},{low_level, 0},{fail_goods_id, 0}]},	
		{base_goods_ore,[{goods_id, 0},{n1, 0},{n2, 0},{w, 0}]},	
		{base_goods_practise,[{id, 0},{att_num, 0},{subtype, 0},{step, 1},{color, 0},{grade, 0},{max_attack, 0},{min_attack, 0},{hit, 0},{wit, 0},{agile, 0},{forza, 0},{physique, 0},{spirit, 0}]},	
		{base_goods_strengthen,[{id, 0},{goods_id, 0},{strengthen, 0},{ratio, 0},{coin, 0},{value, 0},{fail, 0},{type, 0}]},	
		{base_goods_strengthen_anti,[{id, 0},{subtype, 0},{step, 0},{stren, 0},{value, 0}]},	
		{base_goods_strengthen_extra,[{level, 0},{crit7, 0},{crit8, 0},{crit9, 0},{crit10, 0},{hp7, 0},{hp8, 0},{hp9, 0},{hp10, 0}]},	
		{base_goods_subtype,[{type, 0},{subtype, 0},{subtype_name, []}]},	
		{base_goods_suit,[{suit_id, 0},{suit_name, []},{suit_intro, []},{suit_totals, 0},{suit_goods, []},{suit_effect, []}]},	
		{base_goods_suit_attribute,[{id, 0},{career_id, 0},{suit_id, 0},{suit_num, 0},{level, 0},{hp_lim, 0},{mp_lim, 0},{max_attack, 0},{min_attack, 0},{forza, 0},{agile, 0},{wit, 0},{physique, 0},{hit, 0},{dodge, 0},{crit, 0},{anti_wind, 0},{def, 0},{anti_fire, 0},{anti_water, 0},{anti_thunder, 0},{anti_soil, 0}]},	
		{base_goods_type,[{type, 0},{type_name, []}]},	
		{base_hero_card,[{id, 0},{goods_id, 0},{task_id, 0},{lv, 0},{color, 0},{exp, 0},{spt, 0}]},	
		{base_magic,[{id, 0},{step, 1},{pack, 1},{prop, []},{ratio, "0.000"},{max_value, 0},{min_value, 0}]},	
		{base_map,[{scene_id, 0},{scene_name, []},{realm, 0},{realm_name, []}]},	
		{base_meridian,[{id, 0},{name, []},{mer_type, 0},{mer_lvl, 0},{hp, 0},{def, 0},{mp, 0},{hit, 0},{crit, 0},{shun, 0},{att, 0},{ten, 0},{player_level, 0},{spirit, 0},{timestamp, 0}]},	
		{base_mon,[{mid, 0},{name, []},{scene, 0},{icon, 0},{def, 0},{lv, 0},{hp, 0},{hp_lim, 0},{mp, 0},{mp_lim, 0},{max_attack, 0},{min_attack, 0},{att_area, 0},{trace_area, 0},{guard_area, 0},{spirit, 0},{hook_spirit, 0},{exp, 0},{hook_exp, 0},{init_hit, 800},{hit, 0},{init_dodge, 50},{dodge, 0},{init_crit, 50},{crit, 0},{anti_wind, 0},{anti_fire, 0},{anti_water, 0},{anti_thunder, 0},{anti_soil, 0},{speed, 0},{skill, []},{retime, 0},{att_speed, 0},{x, "0"},{y, "0"},{att_type, 0},{id, 0},{pid, 0},{battle_status, 0},{relation, []},{type, 1},{unique_key, 0},{status, 0}]},	
		{base_npc,[{nid, 0},{name, []},{scene, 0},{icon, 0},{npctype, 0},{x, 0},{y, 0},{talk, 0},{id, 0},{unique_key, 0}]},	
		{base_npc_bind_item,[{id, 0},{npc_id, 0},{item_id, 0},{prob, 0}]},	
		{base_online_gift,[{id, 0},{goodsbag, []},{level, 0},{times, 0},{timestamp, 0}]},	
		{base_pet,[{goods_id, 0},{goods_name, []},{name, []},{aptitude_down, 0},{aptitude_up, 0},{skill, 0}]},	
		{base_pet_skill_effect,[{id, 0},{skill_id, 0},{lv, 0},{step, 0},{per, "0.0000"},{fix, 0}]},	
		{base_privity,[{id, 0},{question, []},{a, []},{b, []},{c, []}]},	
		{base_scene,[{sid, 0},{type, 0},{name, []},{x, 0},{y, 0},{requirement, []},{elem, []},{npc, []},{mon, []},{mask, []},{safe, []},{id, 0}]},	
		{base_shop_type,[{shop_type, 0},{npc_name, []},{shop_subtype, 0},{subtype_name, []}]},	
		{base_skill,[{id, 0},{name, []},{desc, []},{career, 0},{mod, 0},{type, 0},{obj, 0},{area, 0},{area_obj, 0},{level_effect, []},{place, []},{assist_type, 0},{limit_action, 0},{hate, "0"},{data, []}]},	
		{base_skill_pet,[{id, 0},{name, []},{type, []},{lv, 0},{rate, "0"},{hurt_rate, "0"},{hurt, 0},{cd, 0},{data, []},{desc, []},{effect, 0},{lastime, 0}]},	
		{base_talk,[{id, 0},{content, []}]},	
		{base_target_gift,[{day, 0},{name, "0"},{time_limit, 0},{target, []},{gift, []},{gift_certificate, 0},{explanation, []},{tip, []}]},	
		{base_task,[{id, 0},{name, []},{desc, []},{class, 0},{type, 0},{child, 0},{kind, 0},{level, 1},{level_limit, 0},{repeat, 0},{realm, 0},{career, 0},{prev, 0},{next, 0},{start_item, []},{end_item, []},{start_npc, []},{end_npc, 0},{start_talk, 0},{end_talk, 0},{unfinished_talk, 0},{condition, []},{content, []},{talk_item, []},{state, 0},{exp, 0},{coin, 0},{binding_coin, 0},{spt, 0},{attainment, 0},{contrib, 0},{honor, 0},{guild_exp, 0},{guild_coin, 0},{award_item, []},{award_select_item, []},{award_select_item_num, 0},{award_gift, []},{start_cost, 0},{end_cost, 0},{next_cue, 0},{realm_honor, 0},{time_start, 0},{time_end, 0}]},	
		{base_tower_award,[{id, 0},{exp, 0},{spt, 0},{honor, 0},{time, 0},{type, 0}]},	
		{base_war_server,[{id, 0},{sn, 0},{name, "0"},{platform, "0"},{ip, "0"},{port, 0},{state, 0}]},	
		{batt_value,[{id, 0},{player_id, 0},{value, 0}]},	
		{box_scene,[{id, 0},{player_id, 0},{mlist, []},{glist, []},{num, 0},{scene, 0},{x, 0},{y, 0},{goods_id, 0}]},	
		{business,[{id, 0},{player_id, 0},{times, 0},{timestamp, 0},{color, 4},{lv, 0},{current, 0},{free, 0},{free_time, 0},{once, 0},{total, 0}]},	
		{buy_goods,[{id, 0},{pid, 0},{pname, []},{buy_type, 0},{gid, 0},{gname, []},{gtype, 0},{gsubtype, 0},{num, 0},{career, 0},{glv, 0},{gcolor, 99},{gstren, 0},{gattr, 0},{unprice, 0},{price_type, 1},{continue, 12},{buy_time, 0}]},	
		{cards,[{id, 0},{cardstring, []},{begtime, 0},{endtime, 0},{active, 0},{player_id, 0},{key, []}]},	
		{carry,[{id, 0},{pid, 0},{carry, 0},{carry_time, 0},{bandits, 0},{bandits_time, 0},{quality, 1},{taihao, 0},{vnwa, 0},{huayang, 0}]},	
		{castle_rush_guild_rank,[{id, 0},{guild_id, 0},{guild_name, []},{guild_lv, 0},{member, 0},{score, 0}]},	
		{castle_rush_info,[{id, 0},{win_guild, 0},{last_win_guild, 0},{boss_hp, 0},{king, []},{king_id, 0},{king_login_time, 0}]},	
		{castle_rush_join,[{id, 0},{guild_id, 0},{guild_lv, 0},{guild_num, 0},{guild_name, []},{guild_chief, []},{ctime, 0}]},	
		{castle_rush_player_rank,[{id, 0},{player_id, 0},{guild_id, 0},{nickname, []},{career, 0},{lv, 0},{kill, 0},{die, 0},{guild, 0},{person, 0},{feats, 0}]},	
		{charge_activity,[{id, 0},{st, 0},{et, 0},{gold, 0},{type, 0},{items, []},{title, []},{content, []}]},	
		{charge_activity_log,[{id, 0},{ca_st, 0},{ca_id, 0},{ctime, 0},{role_id, 0}]},	
		{coliseum_info,[{id, 0},{award_time, 0},{king_id, 0}]},	
		{coliseum_rank,[{id, 0},{player_id, 0},{nickname, []},{lv, 0},{realm, 0},{sex, 0},{career, 0},{battle, 0},{win, 0},{trend, 0},{rank, 0},{report, []},{time, 0}]},	
		{consign_player,[{id, 0},{pid, 0},{publish, 0},{pt, 0},{accept, 0},{at, 0},{timestamp, 0},{exp, 0},{spt, 0},{cul, 0},{coin, 0},{bcoin, 0},{ge, 0},{gc, 0}]},	
		{consign_task,[{id, 0},{pid, 0},{tid, 0},{name, []},{lv, 0},{t1, 0},{state, 0},{gid_1, 0},{n_1, 0},{gid_2, 0},{n_2, 0},{mt, 0},{n_3, 0},{t2, 0},{aid, 0},{t3, 0},{autoid, 0}]},	
		{cycle_flush,[{id, 0},{pid, 0},{mult, "0"},{timestamp, 0}]},	
		{daily_bless,[{id, 0},{player_id, 0},{times, 0},{b_exp, 0},{b_spr, 0},{bless_time, 0}]},	
		{daily_online_award,[{pid, 0},{gain_times, 0},{timestamp, 0}]},	
		{deputy_equip,[{id, 0},{pid, 0},{step, 0},{color, 0},{prof, 0},{prof_lv, 0},{lucky_color, 0},{lucky_step, 0},{lucky_prof, 0},{skills, []},{att, []},{tmp_att, []},{batt_val, 0},{reset, 0}]},	
		{exc,[{player_id, 0},{exc_status, 3},{this_beg_time, 0},{this_end_time, 0},{this_exc_time, 0},{total_exc_time, 0},{pre_pay_coin, 1},{pre_pay_gold, 1},{last_logout_time, 0},{id, 0}]},	
		{exp_activity,[{id, 0},{st, 0},{et, 0},{mul, 2},{time, 0}]},	
		{farm,[{player_id, 0},{farm1, "0"},{farm2, "0"},{farm3, "0"},{farm4, "0"},{farm5, "0"},{farm6, "0"},{farm7, "0"},{farm8, "0"},{farm9, "0"},{farm10, "0"},{farm11, "0"},{farm12, "0"},{client, "0"},{p_status, 0}]},	
		{fashion_equip,[{id, 0},{pid, 0},{yfid, 0},{yftj, []},{fbid, 0},{fbtj, []},{gsid, 0},{gstj, []}]},	
		{feedback,[{id, 0},{type, 1},{state, 0},{player_id, 0},{player_name, []},{title, []},{content, 0},{timestamp, 0},{ip, []},{server, []},{gm, []},{reply, []},{reply_time, 0}]},	
		{find_exp,[{id, 0},{pid, 0},{name, "0"},{task_id, 0},{type, 0},{timestamp, 0},{times, 0},{lv, 0},{exp, 0},{spt, 0}]},	
		{fs_era,[{player_id, 0},{attack, 0},{hp, 0},{mp, 0},{def, 0},{anti_all, 0},{lv_info, []},{prize, []}]},	
		{fs_era_top,[{player_id, 0},{nickname, []},{stage, 0},{time, 0}]},	
		{fst_god,[{id, 0},{thrutime, 0},{loc, 0},{g_name, []},{nick, []},{sex, 1},{career, 0},{realm, 0},{uid, 0},{lv, 1},{light, 0}]},	
		{goods,[{id, 0},{player_id, 0},{goods_id, 0},{type, 0},{subtype, 0},{equip_type, 0},{price_type, 0},{price, 0},{sell_price, 0},{bind, 0},{career, 0},{trade, 0},{sell, 0},{isdrop, 0},{level, 0},{spirit, 0},{hp, 0},{mp, 0},{forza, 0},{physique, 0},{agile, 0},{wit, 0},{max_attack, 0},{min_attack, 0},{def, 0},{hit, 0},{dodge, 0},{crit, 0},{ten, 0},{anti_wind, 0},{anti_fire, 0},{anti_water, 0},{anti_thunder, 0},{anti_soil, 0},{anti_rift, 0},{speed, 0},{attrition, 0},{use_num, 0},{suit_id, 0},{stren, 0},{stren_fail, 0},{hole, 0},{hole1_goods, 0},{hole2_goods, 0},{hole3_goods, 0},{location, 0},{cell, 0},{num, 0},{grade, 0},{step, 0},{color, 0},{other_data, []},{expire_time, 0},{score, 0},{bless_level, 0},{bless_skill, 0},{icon, 0},{ct, 0},{used, 0}]},	
		{goods_attribute,[{id, 0},{player_id, 0},{gid, 0},{goods_id, 0},{attribute_type, 0},{attribute_id, 0},{value_type, 0},{hp, 0},{mp, 0},{max_attack, 0},{min_attack, 0},{forza, 0},{agile, 0},{wit, 0},{physique, 0},{att, 0},{def, 0},{hit, 0},{dodge, 0},{crit, 0},{ten, 0},{anti_wind, 0},{anti_fire, 0},{anti_water, 0},{anti_thunder, 0},{anti_soil, 0},{anti_rift, 0},{status, 1}]},	
		{goods_buff,[{id, 0},{player_id, 0},{goods_id, 0},{expire_time, 0},{data, []}]},	
		{goods_cd,[{id, 0},{player_id, 0},{goods_id, 0},{expire_time, 0}]},	
		{guild,[{id, 0},{name, []},{announce, []},{chief_id, 0},{chief_name, []},{deputy_chief1_id, 0},{deputy_chief1_name, []},{deputy_chief2_id, 0},{deputy_chief2_name, []},{deputy_chief_num, 0},{member_num, 0},{member_capacity, 0},{realm, 0},{level, 0},{upgrade_last_time, 0},{reputation, 0},{lct_boss, "[0,0,0]"},{boss_sv, 0},{skills, 0},{exp, 0},{funds, 0},{storage_num, 0},{storage_limit, 0},{consume_get_nexttime, 0},{combat_num, 0},{combat_victory_num, 0},{combat_all_num, 0},{combat_week_num, "[0,0]"},{sky_apply, 0},{sky_award, []},{a_plist, []},{jion_ltime, 0},{create_time, 0},{depart_names, []},{carry, 0},{bandits, 0},{unions, 0},{union_gid, 0},{union_id, 0},{targid, 0},{convence, "[0,0]"},{castle_rush_award, []},{del_alliance, 0}]},	
		{guild_alliance,[{id, 0},{gid, 0},{bgid, 0},{bname, []},{brealm, 0}]},	
		{guild_alliance_apply,[{id, 0},{agid, 0},{bgid, 0},{agname, []},{bgname, []},{alv, 0},{blv, 0},{arealm, 0},{brealm, 0},{amem, "[0,0]"},{bmem, "[0,0]"},{acid, 0},{bcid, 0},{acname, []},{bcname, []},{time, 0}]},	
		{guild_apply,[{id, 0},{guild_id, 0},{player_id, 0},{create_time, 0}]},	
		{guild_invite,[{id, 0},{guild_id, 0},{player_id, 0},{create_time, 0},{recommander_id, 0},{recommander_name, []}]},	
		{guild_manor_cd,[{id, 0},{player_id, 0},{end_time, 0},{scene, 0},{welfare, 0}]},	
		{guild_member,[{id, 0},{guild_id, 0},{guild_name, []},{player_id, 0},{player_name, []},{donate_funds, 0},{donate_total, 0},{donate_lasttime, 0},{donate_total_lastday, 0},{donate_total_lastweek, 0},{create_time, 0},{title, []},{remark, []},{honor, 0},{guild_depart_name, []},{guild_depart_id, 0},{kill_foe, 0},{die_count, 0},{get_flags, 0},{magic_nut, 0},{feats, 0},{feats_all, 0},{f_uptime, 0},{gr, 0},{unions, 0},{tax_time, 0}]},	
		{guild_skills_attribute,[{id, 0},{guild_id, 0},{skill_id, 0},{skill_name, []},{skill_level, 0}]},	
		{guild_union,[{id, 0},{agid, 0},{bgid, 0},{agname, []},{bgname, []},{acid, 0},{bcid, 0},{acname, []},{bcname, []},{alv, 0},{blv, 0},{amem, "[0,0]"},{bmem, "[0,0]"},{type, 0},{apt, 0},{unions, 0}]},	
		{guild_wish,[{id, 0},{pid, 0},{luck, 0},{t_color, 0},{tid, 0},{tstate, 0},{task, 0},{help, 0},{bhelp, 0},{flush, 0},{time, 0},{finish, []}]},	
		{hero_card,[{id, 0},{pid, 0},{times, 0},{lv, 0},{color, 0},{timestamp, 0}]},	
		{infant_ctrl_byuser,[{accid, 0},{total_game_time, 0},{last_logout_time, 0},{sn, 0},{id, 0}]},	
		{lantern_award,[{id, 0},{pid, 0},{time, 0},{num, 0},{state, 0},{qid, 0}]},	
		{log_ach_finish,[{id, 0},{pid, 0},{ach_num, 0},{time, 0}]},	
		{log_admin_ban,[{id, 0},{time, 0},{user, []},{banid, 0},{reason, []},{type, 0}]},	
		{log_answer,[{id, 0},{pid, 0},{score, 0},{exp, 0},{spirit, 0},{ctime, 0}]},	
		{log_arena,[{id, 0},{player_id, 0},{nickname, []},{zone, 0},{bid, 0},{stime, 0},{jtime, 0},{etime, 0},{ltime, 0}]},	
		{log_backout,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{gid, 0},{goods_id, 0},{subtype, 0},{level, 0},{inlay, 0},{ratio, 0},{ram, 0},{rune_num, 0},{cost, 0},{status, 0},{stone_type, 0}]},	
		{log_bless_bottel,[{id, 0},{player_id, 0},{exp, 0},{spr, 0},{timestamp, 0},{level, 0}]},	
		{log_box_open,[{id, 0},{player_id, 0},{player_name, []},{hole_type, 0},{goods_id, 0},{goods_name, []},{gid, 0},{num, 1},{show_type, 0},{open_time, 0}]},	
		{log_box_player,[{player_id, 0},{purple_time, 0},{open_counter, 0},{purple_num, 0},{box_goods_trace, []}]},	
		{log_box_throw,[{id, 0},{time, 0},{player_id, 0},{gid, 0},{goods_id, 0},{num, 0}]},	
		{log_business_robbed,[{id, 0},{player_id, 0},{robbed_id, 0},{color, 0},{timestamp, 0}]},	
		{log_buy_goods,[{id, 0},{buyid, 0},{buy_type, 0},{sid, 0},{sname, []},{bid, 0},{bname, []},{snum, 0},{unprice, 0},{num, 0},{ptype, 0},{goodsid, 0},{gid, 0},{f_type, 0},{f_time, 0},{continue, 0}]},	
		{log_cancel_wedding,[{id, 0},{w_id, 0},{w_start, 0},{w_num, 0},{w_gold, 0},{cancel_time, 0},{cancel_cost, 0}]},	
		{log_change_name,[{id, 0},{pid, 0},{nickname, "\"\""},{type, 1},{send, 0},{ct, 0}]},	
		{log_charm,[{id, 0},{pid, 0},{type, 0},{client_id, 0},{flower, 0},{charm, 0},{timestamp, 0}]},	
		{log_close_add,[{id, 0},{rela_id, 0},{idA, 0},{idB, 0},{close, 0},{time, 0}]},	
		{log_close_consume,[{id, 0},{ida, 0},{idb, 0},{type, 0},{close, 0},{timestamp, 0}]},	
		{log_coliseum_report,[{id, 0},{player_id, 0},{c_id, 0},{name, []},{relation, 0},{win, 0},{rank, 0},{ctime, 0}]},	
		{log_compose,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{goods_id, 0},{subtype, 0},{stone_num, 0},{new_id, 0},{rune_id, 0},{ratio, 0},{ram, 0},{cost, 0},{status, 0}]},	
		{log_consign,[{id, 0},{pid, 0},{consign, []},{gold, 0},{timestamp, 0}]},	
		{log_consume,[{id, 0},{pid, 0},{mod, 0},{pit, 0},{type, "\"\""},{old_num, 0},{num, 0},{oper, 0},{ct, 0}]},	
		{log_convert_charm,[{id, 0},{pid, 0},{title, 0},{charm, 0},{timestamp, 0}]},	
		{log_count_player_leave,[{id, 0},{time, 0},{new, 0},{leave, 0},{reg_num, 0},{leave_rate, "0"},{back, 0},{back_rate, "0"}]},	
		{log_daily_award,[{id, 0},{pid, 0},{goods_id, 0},{num, 0},{gain_times, 0},{timestamp, 0}]},	
		{log_deliver,[{id, 0},{pid, 0},{deliver_type, 0},{timestamp, 0}]},	
		{log_deputy_break,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{pre_lv, 0},{lv, 0},{lucky, 0},{stone, 0},{stone_num, 0},{ratio, 0},{ram, 0},{cost, 0},{status, 0}]},	
		{log_deputy_color,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{pre_color, 0},{color, 0},{lucky, 0},{stone, 0},{stone_num, 0},{ratio, 0},{ram, 0},{cost, 0},{status, 0}]},	
		{log_deputy_prof,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{stone, 0},{stone_num, 0},{pre_prof, 0},{prof, 0},{prof_lv, 0}]},	
		{log_deputy_skill,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{pre_skills, 0},{skills, 0},{pre_culture, 0},{culture, 0},{cost, 0}]},	
		{log_deputy_step,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{pre_step, 0},{step, 0},{lucky, 0},{stone, 0},{stone_num, 0},{ratio, 0},{ram, 0},{cost, 0},{status, 0}]},	
		{log_deputy_wash,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{att, 0},{tmp_att, 0},{pre_spirit, 0},{spirit, 0},{stone, 0},{stone_num, 0},{cost, 0}]},	
		{log_divorce,[{id, 0},{marry_id, 0},{req_id, 0},{boy_id, 0},{girl_id, 0},{type, 0},{div_time, 0}]},	
		{log_dungeon,[{player_id, 0},{dungeon_id, 0},{first_dungeon_time, 0},{dungeon_counter, 0}]},	
		{log_dungeon_times,[{id, 0},{pid, 0},{scene_id, 0},{timestamp, 0}]},	
		{log_employ,[{id, 0},{tid, 0},{pid, 0},{gid1, 0},{num1, 0},{gid2, 0},{num2, 0},{money, 0},{num3, 0},{timestamp, 0}]},	
		{log_equipsmelt,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{gid, 0},{goods_id, 0},{jp, 0},{my, 0},{hf, 0}]},	
		{log_exc,[{player_id, 0},{this_beg_time, 0},{this_end_time, 0},{this_exc_time, 0},{total_exc_time, 0},{last_logout_time, 0},{id, 0},{act_exc_time, 0},{end_type, 0}]},	
		{log_exc_exp,[{player_id, 0},{this_beg_time, 0},{this_end_time, 0},{this_exc_time, 0},{exc_time_min, 0},{nowtime, 0},{id, 0},{exp_inc, 0}]},	
		{log_f5_gwish,[{id, 0},{pid, 0},{hpid, 0},{hpname, []},{hluck, 0},{ocolor, 0},{ncolor, 0},{tid, 0},{time, 0}]},	
		{log_fashion,[{id, 0},{player_id, 0},{gid, 0},{stone_id, 0},{cost, 0},{old_pro, []},{new_pro, []},{is_oper, 0},{washct, 0},{operct, 0}]},	
		{log_find_exp,[{id, 0},{pid, 0},{name, "0"},{task_id, 0},{type, 0},{times, 0},{lv, 0},{exp, 0},{spt, 0},{date, 0},{timestamp, 0},{money, 0},{color, 0}]},	
		{log_find_exp_date,[{id, 0},{pid, 0},{timestamp, 0}]},	
		{log_free_pet,[{id, 0},{pid, 0},{pet_id, 0},{lv, 0},{apt, 0},{grow, 0},{skill_1, 0},{skill_2, 0},{skill_3, 0},{skill_4, 0},{skill_5, 0},{timestamp, 0},{type, 0}]},	
		{log_fst,[{uid, 0},{endtime, 0},{loc, 0},{id, 0},{type, 0}]},	
		{log_fst_mail,[{uid, 0},{endtime, 0},{loc, 0},{id, 0},{exp, 0},{spr, 0},{hor, 0},{mailed, 0},{type, 0}]},	
		{log_get_pet,[{id, 0},{pid, 0},{pet_id, 0},{goods_id, 0},{apt, 0},{grow, 0},{timestamp, 0}]},	
		{log_gold_coin,[{id, 0},{gold, 0},{coin, 0},{pay_gold, 0},{use_gold, 0},{utime, 0}]},	
		{log_goods_counter,[{id, 0},{player_id, 0},{type, 0},{num, 0},{fina_time, 0}]},	
		{log_goods_diff,[{id, 0},{time, 0},{player_id, 0},{t, 0},{goods_id, 0},{gid, 0},{dnum, 0},{mnum, 0}]},	
		{log_goods_list,[{player_id, 0},{goods, []}]},	
		{log_goods_open,[{id, 0},{pid, 0},{gid, 0},{goods_id, 0},{ggoods_id, 0},{gnum, 0},{time, 0}]},	
		{log_guild,[{id, 0},{guild_id, 0},{guild_name, []},{time, 0},{content, []}]},	
		{log_guild_alliance,[{id, 0},{agid, 0},{bgid, 0},{agname, []},{bgname, []},{type, 0},{time, 0}]},	
		{log_guild_feat,[{id, 0},{pid, 0},{oldf, 0},{newf, 0},{type, 0},{gid, 0},{num, 0},{ct, 0}]},	
		{log_guild_union,[{id, 0},{agid, 0},{bgid, 0},{agname, []},{bgname, []},{time, 0}]},	
		{log_hero_card,[{id, 0},{pid, 0},{lv, 0},{color, 0},{timestamp, 0}]},	
		{log_hole,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{gid, 0},{goods_id, 0},{stone_id, 0},{subtype, 0},{level, 0},{hole, 0},{cost, 0},{status, 0}]},	
		{log_icompose,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{new_id, 0},{ratio, 0},{ram, 0},{cost, 0},{status, 0}]},	
		{log_idecompose,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{goods_id, 0},{gid, 0},{cost, 0},{status, 0}]},	
		{log_identify,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{gid, 0},{goods_id, 0},{subtype, 0},{level, 0},{stone_id, 0},{cost, 0},{status, 0}]},	
		{log_inlay,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{gid, 0},{goods_id, 0},{subtype, 0},{level, 0},{stone_id, 0},{ratio, 0},{ram, 0},{rune_num, 0},{cost, 0},{status, 0}]},	
		{log_invite,[{id, 0},{pid, 0},{inviteid, 0},{mult, 0},{time, 0}]},	
		{log_join,[{id, 0},{pid, 0},{fst, 0},{tds, 0},{tdm, 0},{fb_911, 0},{fb_920, 0},{fb_930, 0},{fb_940, 0},{fb_950, 0},{business, 0},{carry, 0},{peach, 0},{arena, 0},{guild, 0},{wild_boss, 0},{guild_boss, 0},{guild_carry, 0},{exc, 0},{orc, 0},{answer, 0},{train, 0},{spring, 0},{jtime, 0}]},	
		{log_join_summary,[{id, 0},{fst, 0},{fst_num, 0},{td, 0},{td_num, 0},{fb_911, 0},{fb_911_num, 0},{fb_920, 0},{fb_920_num, 0},{fb_930, 0},{fb_930_num, 0},{fb_940, 0},{fb_940_num, 0},{fb_950, 0},{fb_950_num, 0},{business, 0},{business_num, 0},{carry, 0},{carry_num, 0},{peach, 0},{peach_num, 0},{arena, 0},{arena_num, 0},{guild, 0},{guild_num, 0},{wild_boss, 0},{wild_boss_num, 0},{guild_boss, 0},{guild_boss_num, 0},{guild_carry, 0},{guild_carry_num, 0},{exc, 0},{exc_num, 0},{orc, 0},{orc_num, 0},{answer, 0},{answer_num, 0},{train, 0},{train_num, 0},{spring, 0},{spring_num, 0},{login_num, 0},{jtime, 0}]},	
		{log_kick_off,[{id, 0},{uid, 0},{nickname, []},{k_type, 0},{time, 0},{scene, 0},{x, 0},{y, 0},{other, []}]},	
		{log_linggen,[{id, 0},{pid, 0},{mid, 0},{old, 0},{new, 0},{pt, 0},{re, 0},{time, 0}]},	
		{log_login,[{id, 0},{login, 0},{old, 0},{reg, 0},{ltime, 0}]},	
		{log_login_award,[{id, 0},{pid, 0},{type, 0},{days, 0},{goods_id, 0},{num, 0},{timestamp, 0}]},	
		{log_login_user,[{id, 0},{player_id, 0},{nickname, []},{utime, 0},{dtime, 0},{ip, []}]},	
		{log_lucky_draw,[{id, 0},{pid, 0},{days, 0},{times, 0},{goods, 0},{timestamp, 0}]},	
		{log_magic,[{id, 0},{player_id, 0},{gid, 0},{g_type, 0},{magid, 0},{old_prop, []},{prop, []},{is_bind, 0},{cost, 0},{magct, 0},{backct, 0},{is_oper, 0},{oper_ct, 0}]},	
		{log_mail,[{id, 0},{time, 0},{sname, []},{uid, 0},{uname, []},{gid, 0},{goods_num, 0},{coin, 0},{gold, 0},{goods_id, 0},{act, 0},{rtime, 0},{mail_id, 0}]},	
		{log_manor_steal,[{steal_id, 0},{player_id, 0},{steal_time, 0},{actions, 0},{pid, 0},{nickname, []},{fid, 0},{sgoodsid, 0},{count, 0},{read, 0}]},	
		{log_marry,[{id, 0},{boy_id, 0},{girl_id, 0},{coin, 0},{marry_time, 0}]},	
		{log_merge,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{gid_1, 0},{goods_id_1, 0},{step_1, 0},{grade_1, 0},{spirit_1, 0},{gid_2, 0},{goods_id_2, 0},{step_2, 0},{grade_2, 0},{spirit_2, 0}]},	
		{log_meridian,[{id, 0},{player_id, 0},{mer_id, 0},{mer_lv, 0},{timestamp, 0}]},	
		{log_meridian_break,[{id, 0},{pid, 0},{merid, 0},{newval, 0},{oldval, 0},{res, 0},{timestamp, 0}]},	
		{log_mount_active_type,[{id, 0},{player_id, 0},{nickname, []},{goods_id, 0},{goods_name, []},{ct, 0}]},	
		{log_mount_arena,[{id, 0},{cge_pid, 0},{def_pid, 0},{cge_mid, 0},{def_mid, 0},{rounds, 0},{time, 0},{winner_mid, 0},{cge_rank, 0},{def_rank, 0}]},	
		{log_mount_award,[{id, 0},{pid, 0},{mid, 0},{cash, 0},{bcoin, 0},{goods_id, 0},{num, 0},{time, 0}]},	
		{log_mount_change,[{id, 0},{gid, 0},{player_id, 0},{nickname, []},{goods_id, 0},{goods_name, []},{speed, 0},{stren, 0},{step, 0},{level, 0},{lp, 0},{xp, 0},{tp, 0},{qp, 0},{ct, 0}]},	
		{log_mount_oper_4sp,[{id, 0},{mount_id, 0},{player_id, 0},{nickname, []},{cost, 0},{title1, []},{title2, []},{color1, 0},{color2, 0},{lp1, 0},{lp2, 0},{xp1, 0},{xp2, 0},{tp1, 0},{tp2, 0},{qp1, 0},{qp2, 0},{ct, 0}]},	
		{log_mount_oper_step,[{id, 0},{mount_id, 0},{player_id, 0},{nickname, []},{oper, 0},{cost, 0},{step1, 0},{step2, 0},{name1, []},{name2, []},{lp1, 0},{lp2, 0},{xp1, 0},{xp2, 0},{tp1, 0},{tp2, 0},{qp1, 0},{qp2, 0},{luck_val1, 0},{luck_val2, 0},{close1, 0},{close2, 0},{ct, 0}]},	
		{log_mount_skill_split,[{id, 0},{mount_split_id, 0},{player_id, 0},{nickname, []},{cash, 0},{skillid, 0},{exp, 0},{color, 0},{level, 0},{type, 0},{btn_order, 0},{ct, 0}]},	
		{log_mount_split_oper,[{id, 0},{mount_split_id, 0},{player_id, 0},{nickname, []},{mount_id, 0},{skillid, 0},{exp, 0},{color, 0},{level, 0},{type, 0},{sell_cash, 0},{fetch_exp, 0},{oldskill, []},{newskill, []},{opertype, 0},{ct, 0}]},	
		{log_offline_award,[{id, 0},{pid, 0},{hour, 0},{mult, 0},{exp, 0},{timestamp, 0}]},	
		{log_online_cash,[{id, 0},{pid, 0},{hour, 0},{cash, 0},{type, 0},{timestamp, 0}]},	
		{log_online_gift,[{id, 0},{pid, 0},{goods_id, 0},{num, 0},{times, 0},{timestamp, 0}]},	
		{log_online_goods,[{id, 0},{pid, 0},{goods, 0},{num, 0},{day, 0},{timestamp, 0}]},	
		{log_online_time,[{id, 0},{player_id, 0},{otime, 0},{ctime, 0}]},	
		{log_ore,[{id, 0},{time, 0},{goods_id, 0},{player_id, 0}]},	
		{log_pay,[{id, 0},{pay_num, []},{pay_user, []},{player_id, 0},{nickname, []},{lv, 0},{reg_time, 0},{first_pay, 0},{money, 0},{pay_gold, 0},{pay_time, 0},{insert_time, 0},{pay_status, 0},{sn, 0}]},	
		{log_pet_addpoint,[{id, 0},{pid, 0},{petid, 0},{point, 0},{forza, 0},{agile, 0},{wit, 0},{phy, 0},{timestamp, 0}]},	
		{log_pet_aptitude,[{id, 0},{pid, 0},{petid, 0},{old, 0},{new, 0},{ratio, 0},{rp, 0},{coin, 0},{time, 0},{save, 0}]},	
		{log_pet_chenge,[{id, 0},{pid, 0},{pet_id, 0},{goods_id_old, 0},{goods_id_new, 0},{timestamp, 0}]},	
		{log_pet_extra_buy,[{id, 0},{player_id, 0},{random_value, []},{lukcy_value, 0},{ct, 0}]},	
		{log_pet_grow,[{id, 0},{pid, 0},{petid, 0},{old, 0},{new, 0},{save, 0},{radio, 0},{rp, 0},{time, 0}]},	
		{log_pet_merge,[{id, 0},{pid, 0},{pet_id, 0},{goods_id, 0},{lv, 0},{exp, 0},{happy, 0},{point, 0},{chenge, 0},{forza, 0},{wit, 0},{agile, 0},{phy, 0},{grow, 0},{apt, 0},{skill1, 0},{skill2, 0},{skill3, 0},{skill4, 0},{skill5, 0},{timestamp, 0}]},	
		{log_pet_skill_oper,[{id, 0},{player_id, 0},{pet_id, 0},{before_skill, []},{after_skill, []},{type, 0},{ct, 0}]},	
		{log_pet_train,[{id, 0},{pid, 0},{petid, 0},{lv, 0},{foods, 0},{money_type, 0},{money, 0},{trian, 0},{opt, 0},{timestamp, 0}]},	
		{log_pet_uplv,[{id, 0},{pid, 0},{petid, 0},{lv, 0},{exp, 0},{apt, 0},{grow, 0},{point, 0},{timestamp, 0}]},	
		{log_pet_wash_point,[{id, 0},{pid, 0},{petid, 0},{point, 0},{timestamp, 0}]},	
		{log_phone_pay,[{id, 0},{pay_num, []},{pay_user, []},{player_id, 0},{nickname, []},{lv, 0},{reg_time, 0},{first_pay, 0},{money, 0},{pay_gold, 0},{pay_time, 0},{insert_time, 0},{pay_status, 0}]},	
		{log_player_activity,[{id, 0},{pid, 0},{type, 0},{time, 0}]},	
		{log_player_leave,[{id, 0},{new, 0},{leave, 0},{reg_num, 0},{leave_rate, "0"},{back, 0},{back_rate, "0"},{time, 0}]},	
		{log_plogin,[{id, 0},{pid, 0},{ac, 0},{ip, []},{ts, 0}]},	
		{log_practise,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{gid, 0},{goods_id, 0},{step, 0},{grade, 0},{spirit, 0}]},	
		{log_quality_out,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{gid, 0},{goods_id, 0},{subtype, 0},{level, 0},{quality, 0},{stone_id, 0},{stone_num, 0},{cost, 0},{status, 0}]},	
		{log_quality_up,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{gid, 0},{goods_id, 0},{subtype, 0},{level, 0},{quality, 0},{quality_his, 0},{quality_fail, 0},{stone_id, 0},{cost, 0},{status, 0}]},	
		{log_refine,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{goods_id, 0},{gid, 0},{new_id, 0},{cost, 0},{status, 0}]},	
		{log_refresh_car,[{id, 0},{pid, 0},{type, 0},{times, 0},{color, 0},{timestamp, 0}]},	
		{log_sale,[{id, 0},{sale_id, 0},{buyer_id, 0},{saler_id, 0},{buyer_name, []},{saler_name, []},{deal_time, 0},{gid, 0},{goods_id, 0},{goods_name, []},{num, 0},{price_type, 1},{price, 0},{buyer_gold_bef, 0},{buyer_gold_aft, 0},{buyer_coin_bef, 0},{buyer_coin_aft, 0}]},	
		{log_sale_dir,[{id, 0},{sale_id, 0},{player_id, 0},{flow_time, 0},{flow_type, 1},{sale_type, 1},{gid, 0},{goods_id, 0},{num, 0},{price_type, 1},{price, 0}]},	
		{log_shop,[{id, 0},{shop_type, 0},{shop_subtype, 0},{player_id, 0},{nickname, []},{goods_id, 0},{price_type, 0},{price, 0},{num, 0},{time, 0}]},	
		{log_single_td_award,[{id, 0},{pid, 0},{order, 0},{lv, 0},{spt, 0},{bcoin, 0},{timestamp, 0}]},	
		{log_sky_apply,[{id, 0},{gd, 0},{at, 0}]},	
		{log_sky_p,[{id, 0},{pd, 0},{jt, 0}]},	
		{log_smelt,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{gid, 0},{gid_list, []},{goods_id_list, []},{repair, 0}]},	
		{log_st_dairy,[{id, 0},{reg_num, 0},{login_num, 0},{remain_gold, 0},{ctime, 0}]},	
		{log_stren,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{gid, 0},{goods_id, 0},{subtype, 0},{level, 0},{stren, 0},{ratio, 0},{ram, 0},{stren_fail, 0},{stone_id, 0},{rune_id, 0},{rune_num, 0},{prot_id, 0},{cost, 0},{status, 0}]},	
		{log_suitmerge,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{gid1, 0},{goods_id1, 0},{gid2, 0},{goods_id2, 0},{gid3, 0},{goods_id3, 0},{cost, 0},{suit_id, 0}]},	
		{log_target_gift,[{id, 0},{pid, 0},{day, 0},{times, 0},{cash, 0},{goods, []},{time, 0}]},	
		{log_td,[{att_num, 0},{id, 0},{uid, 0},{hor_td, 0},{map_type, 0},{time, 0},{mark, 0}]},	
		{log_td_honor_consume,[{id, 0},{pid, 0},{goods_id, 0},{num, 0},{consume, 0},{timestamp, 0}]},	
		{log_throw,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{gid, 0},{goods_id, 0},{color, 0},{stren, 0},{bind, 0},{type, 0},{num, 0},{attrs, []}]},	
		{log_trade,[{id, 0},{donor_id, 0},{gainer_id, 0},{donor_name, []},{gainer_name, []},{deal_time, 0},{gid, 0},{goods_id, 0},{type, 1},{num, 0},{donor_coin_bef, 0},{donor_gold_bef, 0},{gainer_coin_bef, 0},{gainer_gold_bef, 0},{donor_coin_aft, 0},{donor_gold_aft, 0},{gainer_coin_aft, 0},{gainer_gold_aft, 0}]},	
		{log_update_ach,[{id, 0},{pid, 0},{ach, 0},{data, 0},{time, 0}]},	
		{log_uplevel,[{id, 0},{time, 0},{player_id, 0},{lv, 0},{exp, 0},{spirit, 0},{scene, 0},{x, 0},{y, 0},{add_exp, 0},{from, 0}]},	
		{log_use,[{id, 0},{player_id, 0},{nickname, []},{gid, 0},{goods_id, 0},{type, 0},{subtype, 0},{num, 0},{time, 0}]},	
		{log_vip,[{id, 0},{pid, 0},{gid, 0},{time, 0}]},	
		{log_vip_experience,[{id, 0},{pid, 0},{goods_id, 0},{mark, 0},{timestamp, 0}]},	
		{log_war2_bet,[{id, 0},{pid, 0},{type, 0},{total, 0},{nickname, []},{state, 0},{timestamp, 0}]},	
		{log_war_award,[{id, 0},{pid, 0},{goods_id, 0},{num, 0},{point, 0},{type, 0},{timestamp, 0}]},	
		{log_war_player,[{id, 0},{pid, 0},{times, 0},{timestamp, 0}]},	
		{log_wardrobe_activite,[{id, 0},{pid, 0},{sex, 0},{type, 0},{equipid, 0},{time, 0}]},	
		{log_warehouse_flowdir,[{id, 0},{guild_id, 0},{gid, 0},{goods_id, 0},{player_id, 0},{flow_type, 0},{flow_time, 0}]},	
		{log_wash,[{id, 0},{time, 0},{player_id, 0},{nickname, []},{gid, 0},{goods_id, 0},{subtype, 0},{level, 0},{color, 0},{cost, 0}]},	
		{log_wedding,[{id, 0},{boy_id, 0},{girl_id, 0},{wedding_id, 0},{gold, 0},{is_wedding, 0},{book_time, 0},{wedding_num, 0}]},	
		{log_wedding_gift,[{id, 0},{sender_id, 0},{sender_name, "\"\""},{receive_name, "\"\""},{send_time, 0},{gold, 0},{coin, 0}]},	
		{log_wedding_pay_inv,[{id, 0},{boy_name, "\"\""},{girl_name, "\"\""},{boy_cost, 0},{girl_cost, 0}]},	
		{log_zxt_honor,[{id, 0},{pid, 0},{honor, 0},{goods, 0},{num, 0},{timestamp, 0}]},	
		{login_award,[{id, 0},{pid, 0},{days, 0},{time, 0},{un_charge, []},{charge, []},{charge_mark, 0}]},	
		{login_prize,[{id, 0},{begtime, 0},{endtime, 0},{lv_lim, 0},{beg_regtime, 0},{end_regtime, 0},{gold, 0},{cash, 0},{coin, 0},{bcoin, 0},{goods_id, 0},{num, 0},{title, []},{content, []}]},	
		{love,[{id, 0},{pid, 0},{charm, 0},{refresh, 0},{status, 0},{duration, 0},{mult, 1},{times, 0},{timestamp, 0},{invitee, []},{title, 0},{title_time, 0},{privity_info, []},{be_invite, []},{task_times, 0},{task_content, []}]},	
		{loveday,[{id, 0},{pid, 0},{rid, 0},{pname, []},{rname, []},{content, []},{votes, 0},{voters, []}]},	
		{lucky_draw,[{id, 0},{pid, 0},{goods_id, 0},{days, 0},{times, 0},{timestamp, 0},{goodslist, []}]},	
		{mail,[{id, 0},{type, 0},{state, 0},{timestamp, 0},{sname, []},{uid, 0},{title, []},{content, []},{gid, 0},{goods_num, 0},{coin, 0},{gold, 0},{goodtype_id, 0}]},	
		{mail_review,[{id, 0},{playerType, 0},{playersArr, []},{dataArr, []},{wealArr, []},{ctime, 0},{admin_username, []}]},	
		{manage_platform,[{id, 0},{plat_name, []}]},	
		{manage_server,[{id, 0},{plat_id, 0},{server_name, []},{server_url, []}]},	
		{manor_farm_info,[{mid, 0},{pid, 0},{fid, 0},{fstate, 0},{sgoodsid, 0},{sstate, 0},{plant, 0},{grow, 0},{fruit, 0},{celerate, 0}]},	
		{marry,[{id, 0},{boy_id, 0},{girl_id, 0},{do_wedding, 0},{marry_time, 0},{rec_gold, 0},{rec_coin, 0},{divorce, 0},{div_time, 0}]},	
		{master_apprentice,[{id, 0},{apprentenice_id, 0},{apprentenice_name, []},{master_id, 0},{lv, 0},{career, 0},{status, 0},{report_lv, 0},{join_time, 0},{last_report_time, 0},{sex, 0}]},	
		{master_charts,[{id, 0},{master_id, 0},{master_name, []},{master_lv, 0},{realm, 0},{career, 0},{award_count, 0},{score_lv, 0},{appre_num, 0},{regist_time, 0},{lover_type, 0},{sex, 1},{online, 1}]},	
		{meridian,[{id, 0},{player_id, 0},{mer_yang, 0},{mer_yin, 0},{mer_wei, 0},{mer_ren, 0},{mer_du, 0},{mer_chong, 0},{mer_qi, 0},{mer_dai, 0},{mer_yang_linggen, 0},{mer_yin_linggen, 0},{mer_wei_linggen, 0},{mer_ren_linggen, 0},{mer_du_linggen, 0},{mer_chong_linggen, 0},{mer_qi_linggen, 0},{mer_dai_linggen, 0},{meridian_uplevel_typeId, 0},{meridian_uplevel_time, 0},{yang_top, 0},{yin_top, 0},{wei_top, 0},{ren_top, 0},{du_top, 0},{chong_top, 0},{qi_top, 0},{dai_top, 0}]},	
		{mid_award,[{id, 0},{pid, 0},{type, 0},{num, 0},{got, 0},{other, []}]},	
		{mid_close_award,[{id, 0},{rela, []},{time, 0}]},	
		{mon_drop_analytics,[{id, 0},{mon_id, 0},{mon_name, []},{player_id, 0},{player_name, []},{goods_id, 0},{goods_name, []},{goods_color, 0},{drop_time, 0}]},	
		{mon_warfare,[{id, 0},{mon_id, 0},{add, 0}]},	
		{mount,[{id, 0},{player_id, 0},{goods_id, 0},{name, []},{level, 1},{exp, 0},{luck_val, 0},{close, 0},{step, 0},{speed, 0},{title, []},{color, 1},{stren, 0},{lp, 0},{xp, 0},{tp, 0},{qp, 0},{skill_1, "[1,0,0,0,0,0]"},{skill_2, "[2,0,0,0,0,0]"},{skill_3, "[3,0,0,0,0,0]"},{skill_4, "[4,0,0,0,0,0]"},{skill_5, "[5,0,0,0,0,0]"},{skill_6, "[6,0,0,0,0,0]"},{skill_7, "[7,0,0,0,0,0]"},{skill_8, "[8,0,0,0,0,0]"},{status, 0},{icon, 0},{ct, 0},{mount_val, 0},{last_time, 0}]},	
		{mount_arena,[{id, 0},{player_id, 0},{mount_id, 0},{rank, 0},{rank_award, 0},{player_name, []},{realm, 0},{mount_step, 0},{mount_name, []},{mount_title, []},{mount_typeid, 0},{mount_color, 0},{mount_level, 1},{mount_val, 0},{win_times, 0},{get_ward_time, 1},{recent_win, 1}]},	
		{mount_arena_recent,[{id, 0},{player_id, 0},{cge_times, 0},{gold_cge_times, 0},{last_cge_time, 0},{last_cost_time, 0},{recent, []}]},	
		{mount_battle_result,[{id, 0},{winner, 0},{losers, 0},{rounds, 0},{time, 0},{a_mount_id, 0},{a_player_name, []},{a_mount_name, []},{a_mount_color, 0},{a_mount_type, 0},{b_mount_id, 0},{b_player_name, []},{b_mount_name, []},{b_mount_color, 0},{b_mount_type, 0},{init, []},{battle_data, []}]},	
		{mount_skill_exp,[{id, 0},{player_id, 1},{total_exp, 0},{auto_step, 1},{btn_1, 1},{btn_2, 0},{btn_3, 0},{btn_4, 0},{btn_5, 0},{btn4_type, 0},{btn5_type, 0},{active_type, []}]},	
		{mount_skill_split,[{id, 0},{player_id, 0},{skill_id, 0},{exp, 0},{color, 0},{level, 0},{type, 0}]},	
		{novice_gift,[{id, 0},{pid, 0},{mark8, 0},{mark14, 0},{mark18, 0},{mark22, 0},{mark26, 0},{mark31, 0},{timestamp, 0}]},	
		{offline_award,[{id, 0},{pid, 0},{total, 0},{exc_t, 0},{offline_t, 0}]},	
		{online_award,[{id, 0},{pid, 0},{lv, 0},{day, 1},{d_t, 0},{g4, 0},{g4_m, 0},{g8, 0},{g8_m, 0},{g12, 0},{g12_m, 0},{hour, 0},{h_t, 0},{h_m, 0},{week, 0},{w_t, 0},{w_m, 0},{mon, 0},{m_t, 0},{m_m, 0}]},	
		{online_award_holiday,[{id, 0},{pid, 0},{every_day_time, 0},{every_day_mark, 0},{continuous_day, 0},{continuous_mark, 0}]},	
		{online_gift,[{id, 0},{player_id, 0},{times, 0},{timestamp, 0}]},	
		{pay_pray,[{player_id, 0},{ctime, 0},{mult, 0},{free, 0},{charge, 0},{st, 0},{et, 0}]},	
		{pay_pray_setting,[{id, 0},{begtime, 0},{endtime, 0}]},	
		{payrew,[{player_id, 0},{begtime, 0},{endtime, 0},{rewgold, 0}]},	
		{payrew_setting,[{on, 0},{begtime, 0},{endtime, 0}]},	
		{pet,[{id, 0},{player_id, 0},{goods_id, 0},{name, []},{rename_count, 0},{level, 1},{exp, 0},{happy, 1000},{point, 2},{forza, 0},{wit, 0},{agile, 0},{physique, 0},{aptitude, 0},{grow, 0},{status, 0},{skill_1, "[0,0,0,0]"},{skill_2, "[0,0,0,0]"},{skill_3, "[0,0,0,0]"},{skill_4, "[0,0,0,0]"},{time, 0},{goods_num, 0},{money_type, 0},{money_num, 0},{auto_up, 0},{train_start, 0},{train_end, 0},{chenge, 0},{skill_5, "[0,0,0,0]"},{ct, 0},{skill_6, "[0,0,0,0]"},{batt_skill, []},{apt_range, 0}]},	
		{pet_buy,[{id, 0},{player_id, 0},{goods_id, 0},{ct, 0}]},	
		{pet_extra,[{id, 0},{player_id, 0},{skill_exp, 0},{lucky_value, 0},{batt_lucky_value, 0},{auto_step, 0},{free_flush, 0},{batt_free_flush, 0},{last_time, 0}]},	
		{pet_extra_value,[{id, 0},{player_id, 0},{before_value, []},{after_value, []},{before_value1, []},{after_value1, []},{batt_before_value, []},{batt_after_value, []},{order, 0},{ct, 0}]},	
		{pet_split_skill,[{id, 0},{player_id, 0},{pet_id, 0},{pet_skill, []},{ct, 0}]},	
		{player,[{id, 0},{accid, 0},{accname, []},{nickname, []},{status, 0},{reg_time, 0},{last_login_time, 0},{last_login_ip, []},{sex, 1},{career, 0},{realm, 0},{prestige, 0},{spirit, 0},{jobs, 0},{gold, 0},{cash, 0},{coin, 0},{bcoin, 0},{coin_sum, 0},{scene, 0},{x, 0},{y, 0},{lv, 1},{exp, 0},{hp, 0},{mp, 0},{hp_lim, 0},{mp_lim, 0},{forza, 0.0},{agile, 0.0},{wit, 0.0},{max_attack, 0},{min_attack, 0},{def, 0},{hit, 0},{dodge, 0},{crit, 0},{att_area, 0},{pk_mode, 1},{pk_time, 0},{title, []},{couple_name, []},{position, []},{evil, 0},{honor, 0},{culture, 0},{state, 1},{physique, 0},{anti_wind, 0},{anti_fire, 0},{anti_water, 0},{anti_thunder, 0},{anti_soil, 0},{anti_rift, 0},{cell_num, 100},{mount, 0},{guild_id, 0},{guild_name, []},{guild_position, 0},{quit_guild_time, 0},{guild_title, []},{guild_depart_name, []},{guild_depart_id, 0},{speed, 0},{att_speed, 100},{equip, 1},{vip, 0},{vip_time, 0},{online_flag, 0},{pet_upgrade_que_num, 0},{daily_task_limit, 0},{carry_mark, 0},{task_convoy_npc, 0},{other, 0},{store_num, 36},{online_gift, 0},{target_gift, 0},{arena, 0},{arena_score, 0},{sn, 0},{realm_honor, 0}]},	
		{player_activity,[{id, 0},{pid, 0},{act, 0},{retime, 0},{actions, []},{goods, []}]},	
		{player_backup,[{id, 0},{player_id, 0},{hp_lim, 0},{mp_lim, 0},{att_max, 0},{att_min, 0},{buff, []},{hit, 0},{dodge, 0},{crit, 0},{deputy_skill, []},{deputy_passive_skill, []},{deputy_prof_lv, 0},{anti_wind, 0},{anti_water, 0},{anti_thunder, 0},{anti_fire, 0},{anti_soil, 0},{stren, []},{suitid, 0},{goods_ring4, []},{equip_current, []},{out_pet_id, 0},{pet_batt_skill, []}]},	
		{player_buff,[{id, 0},{player_id, 0},{skill_id, 0},{type, []},{data, []}]},	
		{player_donttalk,[{player_id, 0},{timeStart, 0},{timeEnd, 0},{interval_minutes, 0},{content, []}]},	
		{player_hook_setting,[{id, 0},{player_id, 0},{hook_config, []},{mon_limit, "[0,0]"},{time_start, 0},{time_limit, 0},{timestamp, 0}]},	
		{player_other,[{id, 0},{pid, 0},{up_t, 0},{sex_change_time, 0},{ptitles, []},{ptitle, []},{zxt_honor, 0},{quickbar, []},{coliseum_time, 0},{coliseum_cold_time, 0},{coliseum_surplus_time, 0},{coliseum_extra_time, 0},{is_avatar, 0},{coliseum_rank, 0},{war_honor, "[0,0,0,0,0]"},{couple_skill, 0}]},	
		{player_sys_setting,[{player_id, 0},{shield_role, 0},{shield_skill, 0},{shield_rela, 0},{shield_team, 0},{shield_chat, 0},{music, 50},{soundeffect, 50},{fasheffect, 0},{smelt, 0}]},	
		{relationship,[{id, 0},{idA, 0},{idB, 0},{rela, 0},{time_form, 0},{close, 1},{pk_mon, 0},{timestamp, 0}]},	
		{sale_goods,[{id, 0},{sale_type, 1},{gid, 0},{goods_id, 0},{goods_name, []},{goods_type, 0},{goods_subtype, 0},{player_id, 0},{player_name, []},{num, 0},{career, 0},{goods_level, 0},{goods_color, 99},{price_type, 1},{price, 0},{sale_time, 12},{sale_start_time, 0},{md5_key, []}]},	
		{server,[{id, 0},{ip, []},{port, 0},{node, []},{num, 0},{stop_access, 0}]},	
		{server_titles,[{id, 0},{type, 0},{pid, 0}]},	
		{shop,[{id, 0},{shop_type, 0},{shop_subtype, 0},{goods_id, 0},{total, 0}]},	
		{skill,[{player_id, 0},{skill_id, 0},{lv, 0},{id, 0},{type, 1}]},	
		{stc_create_page,[{id, 0},{cp_time, 0}]},	
		{stc_min,[{id, 0},{time, 0},{online_num, 0}]},	
		{sub_score,[{player_id, 0},{sub_score, 0},{money, 0}]},	
		{sys_acm,[{id, 0},{acm_type, 0},{begtime, 0},{endtime, 0},{acm_ivl, 0},{nexttime, 0},{content, []},{acm_color, "#FF0000"},{acm_link, []},{acm_times, 0}]},	
		{system_config,[{id, 0},{name, []},{value, 0.0},{desc, []}]},	
		{target,[{id, 0},{pid, 0},{a_pet, 0},{out_mount, 0},{meridian_uplv, 0},{master, 0},{lv_20, 0},{friend, 0},{lv_30, 0},{dungeon_25, 0},{pet_lv_5, 0},{battle_value_850, 0},{arena, 0},{mount_step_2, 0},{dungeon_35, 0},{mount_3, 0},{lg20_one, 0},{pet_lv_15, 0},{fst_6, 0},{td_20, 0},{deputy_klj, 0},{mount_gold, 0},{pet_a35_g30, 0},{dungeon_45, 0},{fst_14, 0},{deputy_green, 0},{step_5, 0},{qi_lv4_lg40, 0},{weapon_7, 0},{dungeon_55, 0},{zxt_14, 0},{td_70, 0},{pet_a45_g40, 0},{mount_step_3, 0},{deputy_nws, 0},{lg_50_all, 0},{step_7, 0},{deputy_snd, 0},{pet_a55_g50, 0},{zxt_20, 0},{battle_value_15000, 0},{mount_step_4, 0}]},	
		{target_gift,[{id, 0},{player_id, 0},{first, 0},{first_two, 0},{first_three, 0},{first_four, 0},{first_five, 0},{second, 0},{second_two, 0},{second_three, 0},{second_four, 0},{second_five, 0},{third, 0},{third_two, 0},{third_three, 0},{third_four, 0},{third_five, 0},{fourth, 0},{fourth_two, 0},{fourth_three, 0},{fourth_four, 0},{fifth, 0},{fifth_two, 0},{fifth_three, 0},{sixth, 0},{sixth_two, 0},{sixth_three, 0},{seventh, 0},{seventh_two, 0},{seventh_three, 0},{eighth, 0},{eighth_two, 0},{ninth, 0},{ninth_two, 0},{tenth, 0}]},	
		{target_lead,[{id, 0},{pid, 0},{pet, 0},{mount, 0},{save_html, 0},{guild, 0},{magic, 0},{light, 0},{carry, 0},{suit1, 0},{train, 0},{suit2, 0},{fst, 0},{td, 0},{business, 0},{peach, 0},{weapon, 0},{arena, 0},{fs_era, 0},{mount_arena, 0}]},	
		{task_bag,[{id, 0},{player_id, 0},{task_id, 0},{trigger_time, 0},{state, 0},{end_state, 0},{mark, []},{type, 0},{other, []}]},	
		{task_consign,[{id, 0},{player_id, 0},{task_id, 0},{exp, 0},{spt, 0},{cul, 0},{gold, 0},{times, 0},{timestamp, 0}]},	
		{task_log,[{player_id, 0},{task_id, 0},{type, 0},{trigger_time, 0},{finish_time, 0}]},	
		{td_multi,[{att_num, 0},{id, 0},{uids, []},{nicks, []},{hor_td, 0},{mgc_td, 0}]},	
		{td_single,[{att_num, 0},{id, 0},{g_name, []},{nick, []},{career, 0},{realm, 0},{uid, 0},{hor_td, 0},{mgc_td, 0},{hor_ttl, 0}]},	
		{td_single_award,[{id, 0},{pid, 0},{order, 0},{lv, 0},{timestamp, 0}]},	
		{test,[{id, 0},{row, []},{r, 0},{comment, []}]},	
		{user,[{id, 0},{accid, 0},{accname, []},{status, 0},{idcard_status, 0},{sn, 0},{ct, 0}]},	
		{vip_info,[{id, 0},{pid, 0},{times, 0},{timestamp, 0}]},	
		{war2_bet,[{id, 0},{pid, 0},{name, "0"},{type, 0},{total, 0},{state, 0},{nickname, 0},{bet_id, 0},{grade, 1},{platform, "0"},{sn, 0}]},	
		{war2_elimination,[{id, 0},{pid, 0},{nickname, "0"},{lv, 0},{career, 0},{sex, 0},{batt_value, 0},{platform, "0"},{sn, 0},{grade, 0},{subarea, 0},{num, 0},{state, 0},{wins, 0},{elimination, 0},{popular, 0},{champion, 0}]},	
		{war2_history,[{id, 0},{pid, 0},{nickname, "0"},{career, 0},{sex, 0},{type, 0},{grade, 0},{platform, "0"},{sn, 0},{enemy, "0"},{state, 0},{result, "0"},{times, 0},{timestamp, 0}]},	
		{war2_pape,[{id, 0},{grade, 0},{state, 0},{pid_a, 0},{pid_b, 0},{round, 0},{winner, "0"}]},	
		{war2_record,[{id, 0},{pid, 0},{nickname, "0"},{career, 0},{sex, 0},{lv, 0},{batt_value, 0},{platform, "0"},{sn, 0},{seed, 0},{grade, 0},{subarea, 0},{state, 0},{wins, 0},{last_win, 0},{offtrack, 0},{timestamp, 0}]},	
		{war2_state,[{id, 0},{times, 0},{state, 0},{timestamp, 0}]},	
		{war_award,[{id, 0},{pid, 0},{point, 0},{grade, 0},{rank, 0},{newp, 0},{goods, "0"},{timestamp, 0}]},	
		{war_player,[{id, 0},{pid, 0},{nickname, []},{realm, 0},{career, 0},{level, 0},{sex, 0},{platform, "0"},{sn, 0},{times, 0},{sign_up, 0},{timestamp, 0},{transfer, 0},{lv, 0},{invite, 0},{is_invite, 0},{double_hit, 0},{title, 0},{max_hit, 0},{kill, 0},{die, 0},{point, 0},{drug, 0},{att, 0},{att_flag, 0}]},	
		{war_state,[{id, 0},{type, 0},{times, 0},{state, 0},{lv, 0},{round, 0},{max_round, 0},{timestamp, 0}]},	
		{war_team,[{id, 0},{sn, 0},{platform, "0"},{name, "''"},{team, []},{lv, 0},{times, 0},{point, 0},{total, 0},{syn, 0}]},	
		{war_vs,[{id, 0},{sn_a, 0},{platform_a, "0"},{name_a, "0"},{sn_b, 0},{platform_b, "0"},{name_b, "0"},{times, 0},{lv, 0},{round, 0},{res_a, 0},{res_b, 0},{timestamp, 0}]},	
		{warfare_award,[{id, 0},{pid, 0},{award, 0},{time, 0}]},	
		{wedding,[{id, 0},{marry_id, 0},{boy_name, []},{girl_name, []},{boy_id, 0},{girl_id, 0},{boy_invite, []},{girl_invite, []},{wedding_type, 0},{wedding_num, 0},{wedding_start, 0},{book_time, 0},{gold, 0},{boy_cost, 0},{girl_cost, 0},{do_wedding, 0}]},	
		{zxt_god,[{id, 0},{thrutime, 0},{loc, 0},{g_name, []},{nick, []},{sex, 1},{career, 0},{realm, 0},{uid, 0},{lv, 1},{light, 0}]},	
		{null,""}], 	
	case lists:keysearch(Table_name,1, Table_fileds) of 	
		{value,{_, Val}} -> Val; 	
		_ -> undefined 	
	end. 	
	
	
%% 获取所有表名	
get_all_tables() ->	
	[ 	
		 log_vip_experience,	
		ach_epic,	
		ach_fs,	
		ach_interact,	
		ach_task,	
		ach_treasure,	
		ach_trials,	
		ach_yg,	
		achieve_statistics,	
		adminchange,	
		admingroup,	
		adminkind,	
		adminlog,	
		adminuser,	
		adminweallog,	
		anniversary_bless,	
		appraise,	
		arena,	
		arena_week,	
		base_answer,	
		base_boss_drop,	
		base_box_goods,	
		base_business,	
		base_career,	
		base_carry,	
		base_culture_state,	
		base_daily_gift,	
		base_dungeon,	
		base_gift,	
		base_goods,	
		base_goods_add_attribute,	
		base_goods_attribute,	
		base_goods_compose,	
		base_goods_drop_num,	
		base_goods_drop_rule,	
		base_goods_fashion,	
		base_goods_icompose,	
		base_goods_idecompose,	
		base_goods_inlay,	
		base_goods_ore,	
		base_goods_practise,	
		base_goods_strengthen,	
		base_goods_strengthen_anti,	
		base_goods_strengthen_extra,	
		base_goods_subtype,	
		base_goods_suit,	
		base_goods_suit_attribute,	
		base_goods_type,	
		base_hero_card,	
		base_magic,	
		base_map,	
		base_meridian,	
		base_mon,	
		base_npc,	
		base_npc_bind_item,	
		base_online_gift,	
		base_pet,	
		base_pet_skill_effect,	
		base_privity,	
		base_scene,	
		base_shop_type,	
		base_skill,	
		base_skill_pet,	
		base_talk,	
		base_target_gift,	
		base_task,	
		base_tower_award,	
		base_war_server,	
		batt_value,	
		box_scene,	
		business,	
		buy_goods,	
		cards,	
		carry,	
		castle_rush_guild_rank,	
		castle_rush_info,	
		castle_rush_join,	
		castle_rush_player_rank,	
		charge_activity,	
		charge_activity_log,	
		coliseum_info,	
		coliseum_rank,	
		consign_player,	
		consign_task,	
		cycle_flush,	
		daily_bless,	
		daily_online_award,	
		deputy_equip,	
		exc,	
		exp_activity,	
		farm,	
		fashion_equip,	
		feedback,	
		find_exp,	
		fs_era,	
		fs_era_top,	
		fst_god,	
		goods,	
		goods_attribute,	
		goods_buff,	
		goods_cd,	
		guild,	
		guild_alliance,	
		guild_alliance_apply,	
		guild_apply,	
		guild_invite,	
		guild_manor_cd,	
		guild_member,	
		guild_skills_attribute,	
		guild_union,	
		guild_wish,	
		hero_card,	
		infant_ctrl_byuser,	
		lantern_award,	
		log_ach_finish,	
		log_admin_ban,	
		log_answer,	
		log_arena,	
		log_backout,	
		log_bless_bottel,	
		log_box_open,	
		log_box_player,	
		log_box_throw,	
		log_business_robbed,	
		log_buy_goods,	
		log_cancel_wedding,	
		log_change_name,	
		log_charm,	
		log_close_add,	
		log_close_consume,	
		log_coliseum_report,	
		log_compose,	
		log_consign,	
		log_consume,	
		log_convert_charm,	
		log_count_player_leave,	
		log_daily_award,	
		log_deliver,	
		log_deputy_break,	
		log_deputy_color,	
		log_deputy_prof,	
		log_deputy_skill,	
		log_deputy_step,	
		log_deputy_wash,	
		log_divorce,	
		log_dungeon,	
		log_dungeon_times,	
		log_employ,	
		log_equipsmelt,	
		log_exc,	
		log_exc_exp,	
		log_f5_gwish,	
		log_fashion,	
		log_find_exp,	
		log_find_exp_date,	
		log_free_pet,	
		log_fst,	
		log_fst_mail,	
		log_get_pet,	
		log_gold_coin,	
		log_goods_counter,	
		log_goods_diff,	
		log_goods_list,	
		log_goods_open,	
		log_guild,	
		log_guild_alliance,	
		log_guild_feat,	
		log_guild_union,	
		log_hero_card,	
		log_hole,	
		log_icompose,	
		log_idecompose,	
		log_identify,	
		log_inlay,	
		log_invite,	
		log_join,	
		log_join_summary,	
		log_kick_off,	
		log_linggen,	
		log_login,	
		log_login_award,	
		log_login_user,	
		log_lucky_draw,	
		log_magic,	
		log_mail,	
		log_manor_steal,	
		log_marry,	
		log_merge,	
		log_meridian,	
		log_meridian_break,	
		log_mount_active_type,	
		log_mount_arena,	
		log_mount_award,	
		log_mount_change,	
		log_mount_oper_4sp,	
		log_mount_oper_step,	
		log_mount_skill_split,	
		log_mount_split_oper,	
		log_offline_award,	
		log_online_cash,	
		log_online_gift,	
		log_online_goods,	
		log_online_time,	
		log_ore,	
		log_pay,	
		log_pet_addpoint,	
		log_pet_aptitude,	
		log_pet_chenge,	
		log_pet_extra_buy,	
		log_pet_grow,	
		log_pet_merge,	
		log_pet_skill_oper,	
		log_pet_train,	
		log_pet_uplv,	
		log_pet_wash_point,	
		log_phone_pay,	
		log_player_activity,	
		log_player_leave,	
		log_plogin,	
		log_practise,	
		log_quality_out,	
		log_quality_up,	
		log_refine,	
		log_refresh_car,	
		log_sale,	
		log_sale_dir,	
		log_shop,	
		log_single_td_award,	
		log_sky_apply,	
		log_sky_p,	
		log_smelt,	
		log_st_dairy,	
		log_stren,	
		log_suitmerge,	
		log_target_gift,	
		log_td,	
		log_td_honor_consume,	
		log_throw,	
		log_trade,	
		log_update_ach,	
		log_uplevel,	
		log_use,	
		log_vip,	
		log_vip_experience,	
		log_war2_bet,	
		log_war_award,	
		log_war_player,	
		log_wardrobe_activite,	
		log_warehouse_flowdir,	
		log_wash,	
		log_wedding,	
		log_wedding_gift,	
		log_wedding_pay_inv,	
		log_zxt_honor,	
		login_award,	
		login_prize,	
		love,	
		loveday,	
		lucky_draw,	
		mail,	
		mail_review,	
		manage_platform,	
		manage_server,	
		manor_farm_info,	
		marry,	
		master_apprentice,	
		master_charts,	
		meridian,	
		mid_award,	
		mid_close_award,	
		mon_drop_analytics,	
		mon_warfare,	
		mount,	
		mount_arena,	
		mount_arena_recent,	
		mount_battle_result,	
		mount_skill_exp,	
		mount_skill_split,	
		novice_gift,	
		offline_award,	
		online_award,	
		online_award_holiday,	
		online_gift,	
		pay_pray,	
		pay_pray_setting,	
		payrew,	
		payrew_setting,	
		pet,	
		pet_buy,	
		pet_extra,	
		pet_extra_value,	
		pet_split_skill,	
		player,	
		player_activity,	
		player_backup,	
		player_buff,	
		player_donttalk,	
		player_hook_setting,	
		player_other,	
		player_sys_setting,	
		relationship,	
		sale_goods,	
		server,	
		server_titles,	
		shop,	
		skill,	
		stc_create_page,	
		stc_min,	
		sub_score,	
		sys_acm,	
		system_config,	
		target,	
		target_gift,	
		target_lead,	
		task_bag,	
		task_consign,	
		task_log,	
		td_multi,	
		td_single,	
		td_single_award,	
		test,	
		user,	
		vip_info,	
		war2_bet,	
		war2_elimination,	
		war2_history,	
		war2_pape,	
		war2_record,	
		war2_state,	
		war_award,	
		war_player,	
		war_state,	
		war_team,	
		war_vs,	
		warfare_award,	
		wedding,	
		zxt_god,	
		null 	
	]. 	
