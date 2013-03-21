%% Author: Administrator
%% Created: 2011-8-17
%% Description: TODO: Add description to pp_war
-module(pp_war).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
%%
%% Exported Functions
%%
-export([handle/3]).

%% =================================================================
%% Description: 跨服战场协议处理
%% =================================================================

%%查看历届大会记录
handle(45001,Status,[Times])->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(), {'match_record', [Status,Times]});

%%报名
handle(45002,Status,[])->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(), {'sign_up', [Status]});

%%查看报名信息
handle(45003,Status,[])->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(), {'sign_up_info', [Status]});

%%资格邀请
%% handle(45004,Status,[NickName])->skip;
%% 	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(), {'invite', [Status,NickName]});

%%请求资格转让
%% handle(45005,Status,[NickName])->skip;
%% 	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(), {'transfer_request', [Status,NickName]});

%%回应资格转让
%% handle(45006,Status,[Res,NickName])->skip;
%% 	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(), {'transfer_answer', [Status,Res,NickName]});

%%查看参赛队伍
handle(45007,Status,[])->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(), {'match_team', [Status]});

%%进入大会
handle(45008,Status,[])->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'enter_match',[Status]});

%%领取奖品
handle(45009,Status,[])->
	mod_war_supervisor:get_award(Status);

%%查看参赛队伍
handle(45010,Status,[])->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'war_team',[Status]});

%%查看队伍对阵表
handle(45011,Status,[])->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'war_vs',[Status]}); 

%%查看积分表
handle(45012,Status,[])->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'war_point',[Status]});

%%查看比赛状态
handle(45013,Status,[])->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'war_state',[Status]});

%%查看比赛时间
handle(45014,Status,[])->
	case lib_war:is_war_server() of
		true->
			gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'war_time',[Status]});
		false->skip
	end;

%%查看比赛信息
handle(45015,Status,[])->
	gen_server:cast(Status#player.other#player_other.pid_dungeon,{'fight_info',Status#player.id,Status#player.other#player_other.pid_send});

%%VIP领取药品
handle(45017,Status,[])->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'get_vip_drug',[Status]});

%%查看比赛比分
handle(45018,Status,[])->
	gen_server:cast(Status#player.other#player_other.pid_dungeon,{'result',Status#player.id,Status#player.other#player_other.pid_send});

%%查看分组其他比分
handle(45019,Status,[])->
	case lib_war:is_fight_scene(Status#player.scene) of
		true->
			gen_server:cast(Status#player.other#player_other.pid_dungeon,{'other_result',Status#player.id,Status#player.other#player_other.pid_send});
		false->
			{ok,BinData} = pt_45:write(45019,[[]]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
	end;

%%请求返回休息区
handle(45020,Status,[])->
	case lib_war:is_fight_scene(Status#player.scene) of
		true->
			gen_server:cast(Status#player.other#player_other.pid_dungeon,{'send_to_rest',Status#player.id,Status#player.other#player_other.pid});
		false->skip
	end;

%%请求封神大会入口状态
%% handle(45021,Status,[])->
%% 	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'check_enter_war_state',[Status]});

%%退出封神大会
handle(45022,Status,[])->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'exit_war',[Status]});

%%取消封神大会报名
handle(45023,Status,[])->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'cancel_sign_up',[Status]});

%%提交战旗(1提交成功，2没有战旗可提交,3不能在该区域提交战旗 )
%% handle(45024,Status,[])->skip;
%% 	io:format("45024>>>>>~p/~p/~p/~p~n",[Status#player.x,Status#player.y,Status#player.other#player_other.leader,Status#player.carry_mark]),
%% 	case Status#player.carry_mark of
%% 		26->
%% 			case check_flag_place(Status#player.x,Status#player.y,Status#player.other#player_other.leader) of
%% 				false->
%% 					{ok,BinData} = pt_45:write(45024,[3]),
%% 					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
%% 				true->
%% 					gen_server:cast(Status#player.other#player_other.pid_dungeon,{'COMMIT_FLAG',[Status#player.other#player_other.pid,
%% 																								Status#player.id,Status#player.nickname,
%% 																								Status#player.other#player_other.leader,
%% 																								Status#player.carry_mark]})
%% 			end;
%% 		_->
%% 			{ok,BinData} = pt_45:write(45024,[2]),
%% 			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData) 
%% 	end;

%%查询积分

handle(45025,Status,[])->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(), {'get_war_awrd_point', [Status]});

%%积分兑换物品
handle(45026,Status,[GoodsId,Num])->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(), {'change_goods', [Status,GoodsId,Num]});

%%跨服单人竞技报名
handle(45101,Status,[])->
	gen_server:cast(mod_war2_supervisor:get_mod_war2_supervisor_pid(), {'APPLY',[Status]});

%%获取跨服单人竞技信息
handle(45102,Status,[Type])->
	gen_server:cast(mod_war2_supervisor:get_mod_war2_supervisor_pid(),{'WAR2_INFO',[Status,Type]});

%%单人竞技选拔赛配对
handle(45103,Status,[])->
	gen_server:cast(Status#player.other#player_other.pid_dungeon, {'MATCH_FIGHT',[Status]}),
	ok;

%%请求返回分区休息区
handle(45105,Status,[])->
	gen_server:cast(Status#player.other#player_other.pid_dungeon, {'REQUST_TO_SUBAREA',[Status#player.other#player_other.pid]}),
	ok;

%%查看个人历史记录
handle(45107,Status,[])->
	NewState = 
		case catch gen_server:call(mod_war2_supervisor:get_mod_war2_supervisor_pid(),{'HISTORY_STATE',[Status#player.id,Status#player.nickname]}) of
			{ok,State}->State;
			_->0
		end,
	lib_war2:get_history(Status,NewState),
	ok;

%%查询奖励信息
handle(45114,Status,[])->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'CHECK_GOODS_AWARD',[Status]});

%%领取物品奖励
handle(45108,Status,[])->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'GOODS_AWARD',[Status]});

%%查询我的下注
handle(45109,Status,[])->
	gen_server:cast(mod_war2_supervisor:get_mod_war2_supervisor_pid(),{'MY_BET',[Status]});

%%下注
handle(45110,Status,[Type,Money,PlayerId])->
	gen_server:cast(mod_war2_supervisor:get_mod_war2_supervisor_pid(),{'BETTING',[Status,Type,Money,PlayerId]});

%%进入单人竞技
handle(45111,Status,[])->
	gen_server:cast(mod_war2_supervisor:get_mod_war2_supervisor_pid(),{'ENTER_WAR2',[Status]});

%%玩家逃跑
handle(45115,Status,[])->
	gen_server:cast(Status#player.other#player_other.pid_dungeon, {'ESCAPE',[Status#player.other#player_other.pid,Status#player.id,Status#player.nickname,Status#player.carry_mark]});

%%查询比赛状态
handle(45118,Status,[])->
	gen_server:cast(mod_war2_supervisor:get_mod_war2_supervisor_pid(),{'GET_WAR2_STATE',[Status]});

%%查询战报
handle(45119,Status,[Grade,State,PidA,PidB])->
	gen_server:cast(mod_war2_supervisor:get_mod_war2_supervisor_pid(),{'CHECK_WAR2_PAPE',[Status,Grade,State,PidA,PidB]});

%%选择观战
handle(45120,Status,[FightId])->
	gen_server:cast(mod_war2_supervisor:get_mod_war2_supervisor_pid(),{'CHOICE_VIEW',[Status,FightId]});

handle(Cmd, _Status, _Data) ->
    ?DEBUG("pp_war no match ~p", [Cmd]),
    {error, "pp_war no match"}.

%%11,87
%% check_flag_place(X,Y,Color)->
%% 	case Color of
%% 		11->
%% 			{[Xd,Yd],[Xu,Yu]} = {[6,87],[15,95]},
%% 			if X >= Xd andalso X =< Xu andalso Y >= Yd andalso Y =< Yu ->true;
%% 			   true->false
%% 			end;
%% 		_->
%% 			{[Xd,Yd],[Xu,Yu]} = {[56,16],[65,24]},
%% 			if X >= Xd andalso X =< Xu andalso Y >= Yd andalso Y =< Yu ->true;
%% 			   true->false
%% 			end
%% 	end.