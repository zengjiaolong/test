%%%--------------------------------------
%%% @Module  : pp_chat
%%% @Author  : ygzj
%%% @Created : 2010.09.28
%%% @Description:  聊天功能
%%%--------------------------------------
-module(pp_chat).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

%%世界聊天
handle(11010, Status, [Data]) when is_list(Data)->
	Data_filtered = lib_words_ver:words_filter([Data]),
	lib_chat:chat_world(Status, [Data_filtered]);

%%部落聊天
handle(11020, Status, [Data]) when is_list(Data)->
	Data_filtered = lib_words_ver:words_filter([Data]),
	lib_chat:chat_realm(Status, [Data_filtered]);

%%氏族聊天
handle(11030, Status, [Data]) when is_list(Data)->
	Data_filtered = lib_words_ver:words_filter([Data]),
	%%组织群聊界面消息,颜色代码默认为1
	DataGroup = [Status#player.id, Status#player.career, Status#player.sex, Status#player.vip, 
					 Status#player.nickname, 1, Data_filtered],
	{ok, BinData} = pt_40:write(40079, DataGroup),
	
	lib_chat:chat_guild(Status, [Data_filtered,BinData]);

%%队伍聊天
handle(11040, Status, [Data]) when is_list(Data)->
	Data_filtered = lib_words_ver:words_filter([Data]),
	lib_chat:chat_team(Status, [Data_filtered]);

%%场景聊天
handle(11050, Status, [Data]) when is_list(Data)->
	Data_filtered = lib_words_ver:words_filter([Data]),
	lib_chat:chat_scene(Status, [Data_filtered]);

%%传音
handle(11060, Status, [Color, Data]) ->
	Data_filtered = lib_words_ver:words_filter([Data]),
	lib_chat:chat_sound(Status, [Color, Data_filtered]);

%%本服聊天
handle(11090, Status, [Data]) when is_list(Data)->
	Data_filtered = lib_words_ver:words_filter([Data]),
	lib_chat:chat_sn(Status, [Data_filtered]);

%%场景大表情
handle(11100,Status,[Id])->
	case tool:is_operate_ok(pp_11100, 5) of
		true ->
			{ok,BinData} = pt_11:write(11100,[Status#player.id,Id]),
			mod_scene_agent:send_to_area_scene(Status#player.scene,Status#player.x,Status#player.y, BinData),
			ok;
		false->skip
	end;


%%私聊
%%_Uid:用户ID
%%_Nick:用户名  	(_Uid 和_Nick 任意一个即可 )
%%Data:内容
handle(11070, Status, [Uid, Data]) when is_list(Data)->
	%%跨服不能私聊
	case lib_war:is_war_server() of
		false->
			Data_filtered = lib_words_ver:words_filter([Data]),
  		  Data1 = [Status#player.id, Status#player.career, Status#player.sex, Status#player.nickname, Data_filtered],
  		  {ok, BinData} = pt_11:write(11070, Data1),
			%%判断是否存在黑名单关系(存在则屏蔽,并返回信息)
			case lib_relationship:is_exists_remote(Uid, Status#player.id, 2) of
				{_, false} ->
					lib_chat:private_to_uid(Uid, Status#player.other#player_other.pid_send, BinData);
				{_, true} ->
					lib_chat:chat_in_blacklist(Uid, Status#player.other#player_other.pid_send)
			end;
		true->skip
	end;		   

handle(11073, Status, [Id]) ->
	 case lib_chat:get_chat_info(Id) of
		 [Id, Rid, Level, Gname, GuildId] -> 
			 %%io:format("pp_chat 62line Rid = ~p, Level=~p, Gname = ~p ~n", [Rid, Level, Gname]),
			 {ok,BinData} = pt_11:write(11073,[Id, Rid, Level, Gname, GuildId]);
		 [] ->
			 %%io:format("pp_chat 65line [ ] ~n"),
			 {ok,BinData} = pt_11:write(11073,[0, 0, 0, "", 0])
     end,
     lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData);

%%拜堂对白
handle(11080, _Status, [Type,Msg]) ->
	lib_chat:broadcast_sys_msg(Type, Msg);

handle(_Cmd, _Status, _Data) ->
%%     ?DEBUG("pp_chat no match", []),
    {error, "pp_chat no match"}.
