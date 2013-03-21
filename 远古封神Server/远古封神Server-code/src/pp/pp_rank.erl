%%%------------------------------------
%%% @Module     : pp_rank
%%% @Author     : ygzj
%%% @Created    : 2010.10.05
%%% @Description: 排行榜处理
%%%------------------------------------
-module(pp_rank).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%% 查询人物排名 
handle(22001, PlayerStatus, [Realm, Career, Sex, Type]) ->
	PidSend = PlayerStatus#player.other#player_other.pid_send,
	mod_rank:get_role_rank(PidSend,Realm, Career, Sex, Type),
	ok;
   

%% 查询装备排名
handle(22002, PlayerStatus, Type) ->
	PidSend = PlayerStatus#player.other#player_other.pid_send,
    mod_rank:get_equip_rank(PidSend,Type),
	ok;
   

%% 查询帮会排名
handle(22003, PlayerStatus, Type) ->
	PidSend = PlayerStatus#player.other#player_other.pid_send,
    mod_rank:get_guild_rank(PidSend,Type),
	ok;
   

%%查询宠物排行
handle(22004, PlayerStatus, []) ->
	PidSend = PlayerStatus#player.other#player_other.pid_send,
	mod_rank:get_pet_rank(PidSend),
	ok;
	
%% 查询封神台霸主榜
handle(22005, PlayerStatus, []) ->
	PidSend = PlayerStatus#player.other#player_other.pid_send,
	mod_rank:get_fst_god(PidSend),
	ok;
	

%%氏族战排行
handle(22006, PlayerStatus, []) ->
	PidSend = PlayerStatus#player.other#player_other.pid_send,
	mod_rank:query_guildbat_rank(PidSend),
	ok;
	

%%%%22007 上场个人功勋排行
handle(22007, PlayerStatus, []) ->
	PidSend = PlayerStatus#player.other#player_other.pid_send,
	mod_rank:query_skymem_rank(PidSend),
	ok;


%% 查询镇妖台（单）排行
handle(22008, PlayerStatus, []) ->
	PidSend = PlayerStatus#player.other#player_other.pid_send,
	mod_rank:get_tds_rank(PidSend),
	ok;
	

%% 查询镇妖台（多）排行
handle(22009, PlayerStatus, []) ->
	PidSend = PlayerStatus#player.other#player_other.pid_send,
	mod_rank:get_tdm_rank(PidSend),
	ok;
	

%%22010	魅力值排行榜
handle(22010, PlayerStatus, []) ->
	PidSend = PlayerStatus#player.other#player_other.pid_send,
	mod_rank:get_charm_rank(PidSend),
	ok;
	

%%22011	成就值排行榜
handle(22011, PlayerStatus, []) ->
	PidSend = PlayerStatus#player.other#player_other.pid_send,
	mod_rank:get_achieve_rank(PidSend),
	ok;
	

%% 查询诛仙台霸主榜
handle(22012, PlayerStatus, []) ->
	PidSend = PlayerStatus#player.other#player_other.pid_send,
	mod_rank:get_zxt_god(PidSend),
	ok;

%% 战场排行上一场排行
handle(22013, PlayerStatus, []) ->
	gen_server:cast(mod_arena_supervisor:get_mod_arena_supervisor_work_pid(),
			{apply_asyn_cast, lib_arena, rank_total_pre_arena, [PlayerStatus#player.other#player_other.pid_send]});

%% 总排行战场总排行和周排行RankType
handle(22014, PlayerStatus, RankType) ->
	PidSend = PlayerStatus#player.other#player_other.pid_send,
	mod_rank:rank_arena_query(PidSend,RankType),
	ok;
	

%%查询某人战斗力的排名
handle(22015, PlayerStatus, PlayerId) ->
%% Data = mod_rank:get_batt_value_place(PlayerId),
	PidSend = PlayerStatus#player.other#player_other.pid_send,
	lib_rank:get_batt_value_place_db_order(PidSend,PlayerId),
	ok;
	
%%查询坐骑排名
handle(22017, PlayerStatus, []) ->
	PidSend = PlayerStatus#player.other#player_other.pid_send,
	mod_rank:rank_mount_rank(PidSend),
	ok;

%%查询神器排名
handle(22016, PlayerStatus, []) ->
	PidSend = PlayerStatus#player.other#player_other.pid_send,
	mod_rank:rank_deputy_equip_rank(PidSend),
	ok;
	
%%查询单人镇妖竞技
handle(22018,PlayerStatus,[Type]) ->
	PidSend = PlayerStatus#player.other#player_other.pid_send,
	mod_rank:rank_single_td_rank(PidSend,PlayerStatus#player.id,PlayerStatus#player.lv,Type),
	ok;

handle(22019,PlayerStatus,[])->
	mod_rank:get_single_td_award(PlayerStatus),
	ok;

%%跨服战力排名
handle(22020,PlayerStatus,[])->
	PidSend = PlayerStatus#player.other#player_other.pid_send,
	mod_rank:get_war_rank(PidSend),
	ok;


handle(_Cmd, _Status, _Data) ->
%%     ?DEBUG("pp_rank no match", []),
    {error, "pp_rank no match"}.
