%% Author: Administrator
%% Created: 2011-8-25
%% Description: TODO:循环任务奖励倍数刷新
-module(lib_cycle_flush).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
%%
%% Exported Functions
%%
-compile(export_all).

%%
%% API Functions
%%
%%初始化数据
init_cycle_flush(PlayerId)->
	case db_agent:select_cycle_flush(PlayerId) of
		[]->
			NowTime = util:unixtime(),
			{_,Id} = db_agent:insert_cycle_flush(PlayerId,NowTime,1),
			Data = [Id,PlayerId,1,NowTime],
			pack_ets(Data);
		Data->
			pack_ets(Data)
	end.

%%查询奖励倍数
check_mult(PlayerId)->
	case select_cyc_mult(PlayerId) of
		[]->10;
		[Mult]->
			round(Mult#ets_cycle_flush.mult*10)
	end.

%%获取真实的奖励倍数
get_award_mult(PlayerId,Task,Type)->
	case select_cyc_mult(PlayerId) of
		[]->{Task#task.exp,Task#task.spt};
		[Mult]->
			reset_award_mult(PlayerId,Mult,Type),
			{round(Mult#ets_cycle_flush.mult*Task#task.exp),round(Mult#ets_cycle_flush.mult*Task#task.spt)}
			
	end.

%%刷新奖励倍数(1成功，2物品类型不正确，3物品数量正确，4物品数量不足，5已经刷新过，不能刷新，6数据异常,7物品不存在)
flush_mult(PlayerStatus,GoodsTypeId,Num,GoodsId)->
	case check_goods_type(GoodsTypeId) of
		false->{error,2};
		true->
			case check_goods_num(GoodsTypeId,Num) of
				false->{error,3};
				true->
					case select_cyc_mult(PlayerStatus#player.id) of
						[]->{error,6};
						[Data]->
							case Data#ets_cycle_flush.mult>1 of
								true->{error,5};
								false->
									case gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'delete_one', GoodsId,Num}) of
										[1,_]->
											Mult = get_mult(GoodsTypeId),
											NewData = Data#ets_cycle_flush{mult=Mult},
											spawn(fun()->db_agent:update_cycle_flush([{mult,Mult}],[{pid,PlayerStatus#player.id}])end),
											update_cyc_mult(NewData),
											gen_server:cast(PlayerStatus#player.other#player_other.pid_task,{'trigger_task',PlayerStatus}),
											{ok,1,round(Mult*10)};
										[2,_]->{error,7};
										[3,_]->{error,4};
										_->{error,6}
									end
							end
					end
			end
	end.
%%
%% Local Functions
%%


pack_ets(Data)->
	EtsData = list_to_tuple([ets_cycle_flush|Data]),
    ets:insert(?ETS_CYCLE_FLUSH, EtsData).


%%重置奖励倍数
reset_award_mult(PlayerId,Data,Type)->
	case Type of
		reset->
			NewData = Data#ets_cycle_flush{mult=1},
			spawn(fun()->db_agent:update_cycle_flush([{mult,1}],[{pid,PlayerId}])end),
			update_cyc_mult(NewData);
		_->skip
	end.

					

%%检查物品数量
check_goods_num(GoodsId,Num)->
	case GoodsId of
		21020->Num=:=1;
		21021->Num=:=1;
		21022->Num=:=1;
		21023->Num=:=1;
		_->Num=:=1
	end.

%%检查物品类型
check_goods_type(GoodsId)->
	Goods = goods_util:get_goods_type(GoodsId),
	Goods#ets_base_goods.type =:= 15 andalso  Goods#ets_base_goods.subtype=:=20.

get_mult(GoodsId)->
	Mult = case GoodsId of
			   21020->util:rand(11,13);
			   21021->util:rand(12,15);
			   21022->util:rand(14,18);
			   21023->util:rand(20,25);
			   _->10
		   end,
	Mult/10.

select_cyc_mult(PlayerId)->
	ets:lookup(?ETS_CYCLE_FLUSH, PlayerId).
update_cyc_mult(Mult)->
	ets:insert(?ETS_CYCLE_FLUSH, Mult). 

delete_cyc_mult(PlayerId)->
	ets:delete(?ETS_CYCLE_FLUSH, PlayerId).
