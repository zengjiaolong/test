
%%%---------------------------------------
%%% @Module  : data_dungeon
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010-08-20 10:46:50
%%% @Description:  自动生成
%%%---------------------------------------
-module(data_dungeon).
-export([get/1, get_ids/0]).
-include("record.hrl").
get_ids() ->
	[450].

				get(450) ->

					#dungeon{ 
						id=450, 
						name = <<"副本1">>, 
						def=450, 
						out=[221,29,10], 
						scene=[{450, true, <<>>},{451, false, <<"杀死10个连云庄仆从">>},{452, true, <<"杀死1个连云庄护院">>}], 
						requirement=[[451, false, kill_npc, 30031, 10, 0],[452, false, kill_npc, 30032, 1, 0]]
					};

				
get(_Id) ->
    [].
        