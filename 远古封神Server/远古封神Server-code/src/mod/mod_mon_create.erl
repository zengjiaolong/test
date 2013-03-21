%%%------------------------------------
%%% @Module  : mod_mon_create
%%% @Author  : ygzj
%%% @Created : 2010.10.06
%%% @Description: 生成所有怪物进程
%%%------------------------------------
-module(mod_mon_create).
-behaviour(gen_server).
-export(
 	[
		start_link/0, 
		create_mon/1,
		get_mon_auto_id/1,		
		clear_scene_mon/1,
		clear_scene_mon_by_monid/2,
		create_mon_action/7,
		create_shadow_action/5,
		shadow_skill/1,
		shadow_skill/3,
		create_some_mon/4,
		create_some_mon_loop/5,
		kill_some_mon/2
	]
).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-include("common.hrl").
-include("record.hrl").
-include("guild_info.hrl").
-record(state, {auto_id}).

%% 创建怪物
create_mon([MonId, Scene, X, Y, Type, Other]) ->
    gen_server:call(?MODULE, {create, [MonId, Scene, X, Y, Type, Other]}).

%%批量创建指定场景的某一批怪物
create_some_mon(MonId,SceneId,Type,Other)->
	Pid =  mod_scene:get_scene_real_pid(SceneId),
	Pid!{'CREATE_MON',[MonId,Type,Other]}.


create_some_mon_loop([],_,_,_,_)->ok;
create_some_mon_loop([{X,Y}|Position],Scene,MonId,Type,Other)->
	AutoId = mod_mon_create:get_mon_auto_id(1),
	create_mon_action(MonId, Scene, X, Y, Type, Other, AutoId),
%% 	create_mon([MonId, Scene, X, Y, Type, Other]),
	create_some_mon_loop(Position,Scene,MonId,Type,Other).


%%批量杀死某一批怪物
kill_some_mon(SceneId,MonId)->
	Pid =  mod_scene:get_scene_real_pid(SceneId),
	Pid!{'CLEAR_MON',[MonId]},
	ok.

%% 获取怪物自增ID
get_mon_auto_id(Num) ->
	case catch gen_server:call(?MODULE, {'GET_MON_AUTO_ID', Num}) of
		{'EXIT', _Reason} ->
			round(?MON_LIMIT_NUM / random:uniform(100));
		Ret ->
			Ret
	end.

%% 清除场景怪物
clear_scene_mon(SceneId) ->
	MonList = ets:match(?ETS_SCENE_MON, #ets_mon{pid = '$1', unique_key = '$2', scene = SceneId, _ = '_'}),
	Fun = fun([MonPid, MonUniqueKey]) ->
		case misc:is_process_alive(MonPid) of
			true ->
				MonPid ! clear;
			false ->
				lib_mon:del_mon_data(MonPid, MonUniqueKey)
		end
	end,
	lists:foreach(Fun, MonList).

clear_scene_mon_by_monid(SceneId,MonId) ->
	MonList = ets:match(?ETS_SCENE_MON, #ets_mon{pid = '$1', unique_key = '$2', scene = SceneId,mid=MonId, _ = '_'}),
	Fun = fun([MonPid, MonUniqueKey]) ->
		case misc:is_process_alive(MonPid) of
			true ->
				MonPid ! clear_outside;
			false ->
				lib_mon:del_mon_data(MonPid, MonUniqueKey)
		end
	end,
	lists:foreach(Fun, MonList).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    process_flag(trap_exit, true),
	misc:write_monitor_pid(self(), ?MODULE, {}),	
    State = #state{
		auto_id = 1
	},
    {ok, State}.

%% 更新怪物自增ID
handle_cast({'UPDATE_MON_AUTO_ID', AutoId}, State) ->
	NewAutoId = 
   		case AutoId > ?MON_LIMIT_NUM of
			true ->
		   		round(?MON_LIMIT_NUM / 100);
	   		false ->
				AutoId
        end,
	NewState = State#state{
		auto_id = NewAutoId
	},
    {noreply, NewState};

handle_cast(_R, State) ->
    {noreply, State}.

%% Type 0静态生成，1动态BOSS技能生成
handle_call({create, [MonId, SceneId, X, Y, Type, Other]} , _FROM, State) ->
	NewAutoId = 
   		case State#state.auto_id > ?MON_LIMIT_NUM of
			true ->
		   		round(?MON_LIMIT_NUM / 100);
	   		false -> 
                State#state.auto_id
        end,
	[MonPid, RetAutoId] = create_mon_action(MonId, SceneId, X, Y, Type, Other, NewAutoId),
    NewState = State#state{
		auto_id = RetAutoId
	},
    {reply, {ok, RetAutoId, MonPid}, NewState};

%% 获取怪物自增ID
handle_call({'GET_MON_AUTO_ID', Num}, _From, State) ->
	AutoId = State#state.auto_id + Num,
	NewAutoId = 
   		case AutoId > ?MON_LIMIT_NUM of
			true ->
		   		round(?MON_LIMIT_NUM / 100);
	   		false ->
				AutoId
        end,
	NewState = State#state{
		auto_id = NewAutoId
	},
    {reply, State#state.auto_id, NewState};

handle_call(_R , _FROM, State) ->
    {reply, ok, State}.

handle_info(_Reason, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()),
    ok.

code_change(_OldVsn, State, _Extra)->
	{ok, State}.

%% 怪物生成
create_mon_action(MonId, SceneId, X, Y, Type, OtherBase, AutoId) ->
	case data_agent:mon_get(MonId) of
        [] ->
            [undefined, AutoId];
        MinfoBase ->
			case lists:member(MonId, ?WARFARE_MON_IDS) of
				true ->%%神魔乱斗的怪物，需要重新计算一下血量和攻击
					Minfo = lib_warfare:make_new_moninfo(MinfoBase, OtherBase),
					Other = [];
				false ->
					Minfo = MinfoBase,
					Other = OtherBase
			end,
			case lib_mon:is_boss_mon(Minfo#ets_mon.type) of
                %% BOSS怪
                true ->
                    %% 雷泽分线不生成野外BOSS
                    case Minfo#ets_mon.type == 3 andalso (SceneId == 190 orelse SceneId == 191) of
                        false ->
                            case Minfo#ets_mon.relation of
                                %% 生命共享怪
                                [1, ShareMonId] ->
                                    NewAutoId1 = AutoId + 1,
                                    NewAutoId2 = AutoId + 2,
                                    case mod_mon_boss_active:start([Minfo, NewAutoId1, SceneId, X, Y, 3, NewAutoId2]) of
                                        {ok, Pid} ->
                                            case data_agent:mon_get(ShareMonId) of
                                                [] ->
                                                    skip;
                                                ShareMinfo ->
                                                    mod_mon_boss_active:start([ShareMinfo, NewAutoId2, SceneId, X + 4, Y + 4, 3, NewAutoId1])
                                            end,										
                                            [Pid, NewAutoId2];
                                        _ ->
                                            [undefined, AutoId]
                                    end;
                                _ ->
									NAutoId = AutoId + 1,
									NewMinfo = 
										case Minfo#ets_mon.type of
											%% 龙塔
											37 ->
												CastleRushBossHp = lib_castle_rush:get_castle_rush_boss_hp(Minfo#ets_mon.hp_lim),
												NewMonLv = 
                                                    case db_agent:get_castle_rush_mon_lv() of
                                                        undefined ->
                                                            Minfo#ets_mon.lv;
                                                        MonLv ->
                                                            case is_integer(MonLv) of
                                                                true ->
                                                                    MonLv + 5;
                                                                false ->
                                                                    Minfo#ets_mon.lv
                                                            end
                                                    end,
												Minfo#ets_mon{
													hp = CastleRushBossHp,
													hp_lim = CastleRushBossHp,
													lv = NewMonLv,
													retime = 2000			  
												};
											_ ->
												Minfo
										end,
									case mod_mon_boss_active:start([NewMinfo, NAutoId, SceneId, X, Y, Type, Other]) of
                                  		{ok, Pid} ->
                                      		[Pid, NAutoId];
                                       	_Error ->
                                      		[undefined, AutoId]
                                    end
                            end;
                        true ->
                            [undefined4, AutoId]	
                    end;
                false ->
                    NAutoId = AutoId + 1,
                    case mod_mon_active:start([Minfo, NAutoId, SceneId, X, Y, Type, self()]) of
                        {ok, Pid} ->
                            [Pid, NAutoId];
                        _ ->
                            [undefined, AutoId]
                    end
            end
    end.

%%创建玩家分身
create_shadow_action(Status,SkillList,SceneId,X,Y)->
	AutoId = mod_mon_create:get_mon_auto_id(1),
	MonId = shadow_id(Status#player.sex,Status#player.career),
	case data_agent:mon_get(MonId) of
        [] ->
            [undefined, AutoId];
        MinfoBase ->
			NewMon = copy_shadow(MinfoBase,Status,SkillList),
			case mod_mon_boss_active:start([NewMon, AutoId+1, SceneId, X, Y, 1,AutoId+2]) of
				{ok, Pid} ->
					[Pid, AutoId+1];
				_Res->
					[undefined, AutoId]
			end
	end.

%% 影子技能
shadow_skill(Player) ->
	HookConfig = get(hook_config),
	HooConfigSkillList = lib_coliseum:get_coliseum_skill_list(HookConfig),
	shadow_skill(HooConfigSkillList, Player, []).

shadow_skill([], _Status, SkillInfo) -> 
	SkillInfo;
shadow_skill([ SkillId | SkillBag], Status, SkillInfo) ->
	case lists:keyfind(SkillId, 1, Status#player.other#player_other.skill) of
        false ->
     		shadow_skill(SkillBag, Status, SkillInfo);
      	{NewSkillId, Slv} ->
			case data_skill:get(NewSkillId, Slv) of
				[]->
					shadow_skill(SkillBag, Status, SkillInfo);
				Skill->
					Cast = lists:keyfind(cast, 1, Skill#ets_skill.data),
					{_, [{_, _}, {_, CD}, {_, _}]} = Cast,
					shadow_skill(SkillBag, Status, [{SkillId, CD * 1000, 1, 0, 0} | SkillInfo])
			end
	end.

%%影子属性
copy_shadow(Mon,Status,SkillList)->
	Mon#ets_mon{
				name = Status#player.nickname,
				def = Status#player.def,
				lv = Status#player.lv,
				hp_lim = Status#player.hp_lim,
				hp = Status#player.hp_lim ,
				mp_lim = Status#player.mp_lim,
				mp = Status#player.mp_lim,
				max_attack = Status#player.max_attack,
				min_attack = Status#player.min_attack,
				att_area = Status#player.att_area,
				hit = Status#player.hit,
				dodge = Status#player.dodge,
				crit = Status#player.crit,
				anti_wind = Status#player.anti_wind,
				anti_fire = Status#player.anti_fire,
				anti_water = Status#player.anti_water,
				anti_thunder = Status#player.anti_thunder,
				anti_soil = Status#player.anti_soil,
				speed = 170,
				skill = SkillList,
				att_speed = Status#player.att_speed,
				att_type = 1
			   }.

shadow_id(Sex,Career)->
	case Sex of
		1->
			case Career of
				1->45901;
				2->45903;
				3->45905;
				4->45907;
				_5->45909
			end;
		_2->
			case Career of
				1->45902;
				2->45904;
				3->45906;
				4->45908;
				_5->45910
			end
	end.
				