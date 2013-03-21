%% Author: Administrator
%% Created: 2011-12-2
%% Description: TODO: 结婚及婚宴
-module(pp_marry).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include("guild_info.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
%%
%% Exported Functions
%%
-export([handle/3]).

%%
%% API Functions
%%

%%提亲检测
handle(48000,PlayerState,[Name]) ->
%% 	Realm = 
%% 	case db_agent:get_realm_by_nick(Name) of
%% 					null ->
%% 						100;
%% 					R -> 
%% 						R   %%未离婚
%% 	end,
%% 	?DEBUG("TEST REALM = ~p~n",[Realm]),
	Player = PlayerState#player_state.player,
	lib_marry:check_boy_propose(Player,Name);

%%提亲
handle(48001,PlayerState,_) ->
%% 	Realm = 
%% 	case db_agent:get_realm_by_nick(PlayerState#player.nickname) of
%% 					null ->
%% 						100;
%% 					R -> 
%% 						R   %%未离婚
%% 	end,
%% 	?DEBUG("TEST REALM = ~p~n",[Realm]),
	Player = PlayerState#player_state.player,
	%%检测提亲条件
	{Result,GirlId} = lib_marry:check_can_propose(Player),
	case Result of
		1 ->
			lib_marry:notice_girl_propose(GirlId,Player);
		_ ->
			skip
	end;

%%女方回应提亲的处理
handle(48002, PlayerState, [Response,BoyId]) ->
	Player = PlayerState#player_state.player,
	{Result,GirlCode,BoyCode,Bpid} =
		case Response of
			0 ->
				{false,0,9,0}; %%拒绝
			1 ->
				case lib_player:get_player_pid(BoyId) of
					[]->
						{false,7,0,0};
					BoyPid ->
						case Player#player.sex of
							1 ->
								{false,2,5,0}; %% 2，结婚失败，你的性别不符合; 5, 结婚失败，对方必须是女性
							2 ->
								Ms = ets:fun2ms(fun(M) when M#ets_marry.girl_id =:= Player#player.id -> M end),
								case ets:select(?ETS_MARRY,Ms) of
									[_Marry|_Marrys] ->
										{false,3,10,0};%% 3，结婚失败，你不是单身，不能接受提亲; 10, 结婚失败，对方不是单身
									[] ->
										case lib_relationship:rela_for_marry(Player#player.id,BoyId,1) of
											{fail,RelationCode} ->
												case RelationCode of
													9 ->
														{false,8,7,0};%% 8.对方不是你的好友; 7,结婚失败，对方不是你的好友
													10 ->
														{false,9,8,0} %% 10.亲密度不足16000; 8,结婚失败，亲密度不足16000
												end;
											{ok,suc} ->
												{true,0,0,BoyPid}
										end
								end
						end
				end
		end,
	case Result of
		false ->
			if GirlCode =:= 0 ->
				   skip;
			   true ->
				   {ok,GirlBin} = pt_48:write(48002,GirlCode),
				   lib_send:send_to_sid(Player#player.other#player_other.pid_send, GirlBin)
			end,
			{ok,BoyBin} = pt_48:write(48016,BoyCode),
			lib_send:send_to_uid(BoyId,BoyBin);
		true ->
			Bpid ! {'check_can_marry',Player#player.other#player_other.pid,Player#player.id,Player#player.realm}
	end;

%%查看预订婚宴信息
handle(48003, PlayerState, _) ->
	Player = PlayerState#player_state.player,	
	Wedding_Pid = mod_wedding:get_mod_wedding_pid(),
	Wedding_Pid ! {'QUERY_WEDDING_INFO', Player#player.sex, Player#player.id};

%%预订婚宴(参数：婚宴类型，婚期)
handle(48004, PlayerState, [Wtype,Wnum]) ->
	Player = PlayerState#player_state.player,
	%%先判断玩家有没有marry关系
	Ms = 
		case Player#player.sex of
			1 ->
				ets:fun2ms(fun(M) when M#ets_marry.boy_id =:= Player#player.id -> M end);
			2 ->
				ets:fun2ms(fun(M) when M#ets_marry.girl_id =:= Player#player.id -> M end)
		end,
	if Player#player.sex =:= 2 ->
		   {ok,Bin8} = pt_48:write(48004,8),
		   lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin8);
	   true ->
		   case ets:select(?ETS_MARRY,Ms) of
			   []->
				   {ok,Bin3} = pt_48:write(48004,3),
				   lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin3);
			   [Marry|_R] ->
				   %%有marry记录
				   case Marry#ets_marry.do_wedding of
					   0 ->
						   gen_server:cast(mod_wedding:get_mod_wedding_pid(), {'BOOK_WEDDING', Player, Marry, Wtype, Wnum});
					   1 ->
						   %%已经办过
						   {ok,Bin4} = pt_48:write(48004,4),
						   lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin4)
				   end
		   end
	end;

%%打开群发喜帖的列表
handle(48005, PlayerState, _) ->
	Player = PlayerState#player_state.player,
	Ms = 
		if Player#player.sex =:= 1 ->
			   ets:fun2ms(fun(M) when M#ets_marry.boy_id =:= Player#player.id -> M end);
		   true ->
			   ets:fun2ms(fun(M) when M#ets_marry.girl_id =:= Player#player.id -> M end)
		end,
	Wpid = mod_wedding:get_mod_wedding_pid(),
	Fs =
		case lib_relationship:find_ets_rela_record(Player#player.id,1) of
			[] -> 
				[];
			L -> 
				L
		end,
	Fids = [R#ets_rela.rid || R <- Fs],
	case lib_marry:is_wedding_love_scene(Player#player.scene) of
		true ->
			case catch gen_server:call(Wpid,{'IS_COUPLE', Player}) of
				{'EXIT', _} ->
					{ok,BinData} = pt_48:write(48005,{3,0,0,[]});
				{false,_,_} ->
					{ok,BinData} = pt_48:write(48005,{4,0,0,[]}); %%婚宴场景内，只有新郎新娘可以发喜帖
				{true,_,_} ->
					{ok,BinData} = open_send_win(Wpid,Player,Fids)
			end;
		false ->
			case ets:select(?ETS_MARRY,Ms) of
				[] ->
					{ok,BinData} = pt_48:write(48005,{5,0,0,[]});%%未结婚
				_ ->
					{ok,BinData} = open_send_win(Wpid,Player,Fids)
			end
	end,
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);

%%发送喜帖
handle(48006, PlayerState, [Ids]) ->
	Player = PlayerState#player_state.player,
	Ms = 
		if Player#player.sex =:= 1 ->
			   ets:fun2ms(fun(M) when M#ets_marry.boy_id =:= Player#player.id -> M end);
		   true ->
			   ets:fun2ms(fun(M) when M#ets_marry.girl_id =:= Player#player.id -> M end)
		end,
	case ets:select(?ETS_MARRY,Ms) of
		[] ->
			{ok,BinData} = pt_48:write(48006,{4,0,[]}),%%未结婚
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		_ ->
			gen_server:cast(mod_wedding:get_mod_wedding_pid(),{'SEND_INV',Ids,Player})
	end;

%%购买喜帖
handle(48007, PlayerState, [Num]) ->
	Player = PlayerState#player_state.player,
	gen_server:cast(Player#player.other#player_other.pid,{'BUY_INVITES',Num});

%%发送贺礼信息
handle(48009,PlayerState,[Coin,Gold,Msg]) ->
	Player = PlayerState#player_state.player,
	{Result,Bin} =
	if Gold=:=0 andalso Coin=:=0 ->
		   {ok,BinData} = pt_48:write(48009,{4,0,0,0,0,0}),
		   {4,BinData};
	   length(Msg) =:= 0 ->
		   {ok,BinData} = pt_48:write(48009,{5,0,0,0,0,0}),
		   {5,BinData};
	   (Gold=:=0 andalso Coin>0)->
		   case goods_util:is_enough_money(Player,Coin,coinonly) of
			   false -> 
				   {ok,BinData} = pt_48:write(48009,{2,0,0,0,0,0}),
				   {2,BinData};
			   true ->
				   {ok,BinData} = pt_48:write(48009,{1,Player#player.id,Player#player.nickname,Coin,0,Msg}),
				   {1,BinData}
		   end;
	   (Gold>0 andalso Coin=:=0) ->
		   case goods_util:is_enough_money(Player,Gold,gold) of
			   false ->
				   {ok,BinData} = pt_48:write(48009,{3,0,0,0,0,0}),
				   {3,BinData};
			   true ->
				   {ok,BinData} = pt_48:write(48009,{1,Player#player.id,Player#player.nickname,0,Gold,Msg}),
				   {1,BinData}		   
		   end;
	   (Gold>0 andalso Coin>0) ->
		    case goods_util:is_enough_money(Player,Gold,gold) of
				false ->
					{ok,BinData} = pt_48:write(48009,{3,0,0,0,0,0}),
					{3,BinData};
				true ->
					case goods_util:is_enough_money(Player,Coin,coinonly) of
						false ->
							{ok,BinData} = pt_48:write(48009,{2,0,0,0,0,0}),
							{2,BinData};
						true ->
							{ok,BinData} = pt_48:write(48009,{1,Player#player.id,Player#player.nickname,Coin,Gold,Msg}),
							{1,BinData}
					end
			end;
	   true ->
		   {ok,BinData} = pt_48:write(48009,{6,0,0,0,0,0}),
		   {6,BinData}
	end,
	case Result of
		1 ->%%扣钱、元宝
			case gen_server:call(mod_wedding:get_mod_wedding_pid(),{'IS_COUPLE',Player}) of
				{'EXIT',_E} -> 
					{ok,BinData6} = pt_48:write(48009,{6,0,0,0,0,0}),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData6);
				{true, _T, _M} ->
					%%新郎新娘不能给自己赠送贺礼
					{ok,BinData7} = pt_48:write(48009,{7,0,0,0,0,0}),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData7);
				{false,_F,_Other} ->
					NewPlayer = lib_marry:pay_for_gift(Gold,Coin,Player),
					%%通知婚宴进程，广播此条贺礼信息
					gen_server:cast(mod_wedding:get_mod_wedding_pid(), {'SEND_GIFTS',Coin,Gold,Bin,Player#player.id,Player#player.nickname}),				
					{ok, change_status, NewPlayer}
			end;
		_->
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
	end;

%%吃饭
handle(48010, PlayerState, _) ->
	Player = PlayerState#player_state.player,
	{ok,Bin} = pt_48:write(48010,{Player#player.id,28}),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin),
	mod_scene_agent:send_to_area_scene(Player#player.scene,Player#player.x, Player#player.y, Bin),
	{ok, change_ets_table, Player#player{carry_mark = 28}};

%%拜堂
handle(48011, PlayerState, _) ->
	Player = PlayerState#player_state.player,
	gen_server:cast(mod_wedding:get_mod_wedding_pid(),{'REQUEST_WEDDINGS',Player});

%%拜堂的接受方选择:稍等
handle(48012, PlayerState, _) ->
	Player = PlayerState#player_state.player,
	gen_server:cast(mod_wedding:get_mod_wedding_pid(),{'BEGIN_WEDDINGS_WAIT',Player});

%%拜堂的接受方选择:开始
handle(48013,PlayerState,_) ->
	Player = PlayerState#player_state.player,
	gen_server:cast(mod_wedding:get_mod_wedding_pid(),{'BEGIN_WEDDINGS_NOW',Player});

%%客户端请求证书与心形动画
handle(48015,PlayerState,_) ->
	Player = PlayerState#player_state.player,
	Wpid = mod_wedding:get_mod_wedding_pid(),
	Wpid ! {'give_book',Player#player.other#player_other.pid_send};

%%离婚请求
handle(48019,PlayerState,_) ->
	Player = PlayerState#player_state.player,
	Player1 = lib_marry:divorce(2,Player),
	{ok, change_ets_table, Player1};

%%取消婚期
handle(48020,PlayerState,_) ->
	Player = PlayerState#player_state.player,
	if Player#player.sex =:= 2 ->
		   {ok,Bin} = pt_48:write(48020,4),
		   lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin);
	   true ->
		   Wpid = mod_wedding:get_mod_wedding_pid(),
		   Wpid ! {'cancel_wedding',Player#player.id}
	end;

%%查看当天预订信息
handle(48021,PlayerState,_) ->
	Player = PlayerState#player_state.player,
	Wpid = mod_wedding:get_mod_wedding_pid(),
	Wpid ! {'view_book_info',Player#player.id};

%%夫妻pk传送
handle(48023,PlayerState, [Type, OSceneId, OX, OY]) ->
	Status = PlayerState#player_state.player,
	case tool:is_operate_ok(pp_48023, 1) of
		true ->
			{Res, NewStatus} = lib_guild_call:fly_to_help_pk(Status, Type, OSceneId, OX, OY, 2),
			Result = 
				if Res =:= 19 ->  %%不让客户端重新请求
					   21;
				   true ->
					   Res
				end,
			{ok, BinData40083} = pt_40:write(40084, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData40083),
			case NewStatus#player.scene =:= ?WARFARE_SCENE_ID of
				true ->
					%%修改战斗模式为氏族模式
					NStatus = NewStatus#player{pk_mode = 3},
					%%更新玩家新模式
					ValueList = [{pk_mode, 3}],
					WhereList = [{id, NStatus#player.id}],
					db_agent:mm_update_player_info(ValueList, WhereList),
					%%通知客户端
					{ok, PkModeBinData} = pt_13:write(13012, [1, 3]),
					lib_send:send_to_sid(NStatus#player.other#player_other.pid_send, PkModeBinData),
					%%获取 冥王之灵的图标显示
					lib_warfare:get_plutos_owns(NStatus#player.other#player_other.pid_send);
				false ->
					NStatus = NewStatus
			end,
			case Result of
				1 ->%%需要保存数据的
					{ok, change_ets_table, NStatus};
				_ ->
					ok
			end;
		false ->
			{ok, BinData40083} = pt_40:write(40084, [20]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData40083),
			ok
	end;

handle(_Cmd, _PlayerState, _Data) ->
    {error, "handle_arena no match"}.
%%
%% Local Functions
%%

%%打开发送喜帖列表
open_send_win(Wpid,Player,Fids)->
	case catch gen_server:call(Wpid, {'IS_BOOK_WEDDING', Player,Fids}) of
				{'EXIT', _} ->
					{ok,BinData} = pt_48:write(48005,{3,0,0,[]});
				{false,Error} ->
					{ok,BinData} = pt_48:write(48005,{Error,0,0,[]});
				{true,Invites,FriedsInfo,Max,Invited_num} ->
					F = fun({PlayerId,[Lv,Name,Online]}) ->
								if length(Invites) =:= 0 ->
									   {PlayerId,[Name,Lv,0,Online]};
								   true ->
									   case lists:member(PlayerId, Invites) of
										   true ->
											   {PlayerId,[Name,Lv,1,Online]};
										   false -> 
											   {PlayerId,[Name,Lv,0,Online]}
									   end
								end
						end,
					NewList =[F(Info) || Info <- FriedsInfo],
					{ok,BinData} = pt_48:write(48005,{1,Invited_num,Max,NewList})
	end,
	{ok,BinData}.
	
	
	