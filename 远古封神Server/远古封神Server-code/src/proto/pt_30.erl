%%%-----------------------------------
%%% @Module  : pt_30
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 30 任务信息
%%%-----------------------------------
-module(pt_30).
-export([read/2, write/2]).
-include("common.hrl").
-include("activities.hrl").

%%
%%客户端 -> 服务端 ----------------------------
%%

%% 任务列表
read(30000, _Data) ->
    {ok, []};

%% 已接任务追踪
read(30001, _Data) ->
    {ok, []};

%% 委托任务列表
read(30002, _Data) ->
    {ok, []};

%% 接受任务
read(30003, <<TaskId:32,Color:8>>) ->
    {ok, [TaskId,Color]};

%% 完成任务
read(30004, <<TaskId:32, ILen:16, Bin/binary>>) ->
    F = fun(_, {TB, Result}) ->
            <<ItemId:32, NewTB/binary>> = TB,
            {ok, {NewTB, Result++[ItemId]}}
    end,
    {ok,{ _, ItemList}} = util:for(1, ILen, F, {Bin, []}),
    {ok, [TaskId, ItemList]};

%% 放弃任务
read(30005, <<TaskId:32>>) ->
    {ok, [TaskId]};

%% 任务对话事件
read(30007, <<TaskId:32, NpcId:32>>) ->
    {ok, [TaskId, NpcId]};

%% 触发并完成任务
read(30008, <<TaskId:32, ILen:16, Bin/binary>>) ->
    F = fun(_, {TB, Result}) ->
            <<ItemId:32, NewTB/binary>> = TB,
            {ok, {NewTB, Result++[ItemId]}}
    end,
    {ok,{ _, ItemList}} = util:for(1, ILen, F, {Bin, []}),
    {ok, [TaskId, ItemList]};

%% 获取任务奖励信息
read(30009, <<TaskId:32>>) ->
    {ok, [TaskId]};

%% 打开窗口事件
read(30010,<<Type:16>>)->
    {ok, [Type]};

%%委托任务
read(30012,<<Len:16, Bin/binary>>)->
	Fun = fun(_Elem, {TB, Result}) ->
				<<TaskId:32, Num:16, RestTB/binary>> = TB,
				{ok, {RestTB, [{TaskId, Num}|Result]}}
		  end,
	{ok, {_, TaskList}} = util:for_new(1, Len, Fun, {Bin, []}),
	{ok, [TaskList]};


%%查询委托任务
read(30013,<<TaskId:32>>)->
	{ok,[TaskId]};

%%立即完成委托任务
read(30014,<<>>)->
	{ok,[]};

%%立即完成跑商任务
read(30015,<<TaskId:32>>)->
	{ok,[TaskId]};

%%查找副本令任务信息
read(30022,<<TaskId:32>>)->
	{ok,[TaskId]};

%%使用副本令完成任务
read(30023,<<Len:16, Bin/binary>>)->
	Fun = fun(_Elem, {TB, Result}) ->
				<<TaskId:32, RestTB/binary>> = TB,
				{ok, {RestTB, [TaskId|Result]}}
		  end,
	{ok, {_, TaskList}} = util:for_new(1, Len, Fun, {Bin, []}),
	{ok, [TaskList]};

%%爱的宣言
read(30028,<<Talk/binary>>)->
	{Talk1,_} = pt:read_string(Talk),
	{ok,[Talk1]};

%% 清空角色单个任务
read(30100, <<TaskId:32>>) ->
    {ok, [TaskId]};

%% 清空角色所有任务
read(30200, <<>>) ->
    {ok, []};

%%检查是否有在线奖励
read(30070,<<>>) ->
	{ok,[]};

%%领取在线奖励
read(30071,<<>>) ->
	{ok,[]};

%%获取目标奖励信息
read(30072,<<>>) ->
	{ok,[]};

%%领取目标奖励
read(30073,<<Day:16,Times:16>>) ->
	{ok,[Day,Times]};

%%选择国家
read(30080,<<Type:8,Realm:8>>) ->
%% 	io:format("30080"),
	{ok,[Type,Realm]};

%%小飞鞋
read(30090,<<TaskId:32,Type:16,Id:32>>) ->
	{ok,[TaskId,Type,Id]};

%%每日传送
read(30091,<<Type:16,Id:32,MoneyType:16>>)->
	{ok,[Type,Id,MoneyType]};

%%世界地图传送
read(30092,<<Type:16,Id:32,MoneyType:16,SceneId:32,X:32,Y:32>>)->
	{ok,[Type,Id,MoneyType,SceneId,X,Y]};

%%查询国运时间
read(30300,<<>>)->
	{ok,[]};

%%查询委托任务
read(30400,<<>>)->
	{ok,[]};

%%发布委托任务
read(30401,<<TaskId:32,Time:16,GoodsId1:32,Num1:16,GoodsId2:32,Num2:16,MoneyType:16,Num3:32>>)->
	{ok,[TaskId,Time,GoodsId1,Num1,GoodsId2,Num2,MoneyType,Num3]};

%%接受委托任务
read(30402,<<Id:32,TaskId:32>>)->
	{ok,[Id,TaskId]};

%%取消委托任务
read(30403,<<Id:32>>)->
	{ok,[Id]};

%%答题
read(30500,<<TaskId:32,QuestionId:32>>)->
	{ok,[TaskId,QuestionId]};

%%每日任务累积
read(30600,<<>>)->
	{ok,[]};

%%查询指定部落国运时间
%% read(30301,<<>>)->
%% 	{ok,[]};


%%刷新商车
read(30700,<<>>)->
	{ok,[]};
%%刷新商车
read(30701,<<Color:8>>)->
	{ok,[Color]};

%%查询商车信息
read(30702,<<>>)->
	{ok,[]};

%%购买元宝并开始跑商
read(30703,<<Color:8>>) ->
	{ok,[Color]};

%%请求刷新有缘人时间CD
read(30800,<<>>)->
	{ok,[]};

%%刷新有缘人
read(30801,<<Type:8>>)->
	{ok,[Type]};

%%查看玩家当前状态
read(30802,<<PlayerId:32>>)->
	{ok,[PlayerId]};

%%邀请有缘人
read(30803,<<Type:8,Name/binary>>)->
	{Nickname,_} = pt:read_string(Name),
	{ok,[Type,Nickname]};

%%接受、拒绝邀请
read(30805,<<Result:8,PlayerId:32,Type:8>>)->
	{ok,[Result,PlayerId,Type]};

%%赠送礼物
read(30806,<<PlayerId:32,Type:8>>)->
	{ok,[PlayerId,Type]};

%%取消邀请
read(30808,<<PlayerId:32>>)->
	{ok,[PlayerId]};

%%评价赠送鲜花
read(30810,<<PlayerId:32,App:16,Flower:16>>)->
	{ok,[PlayerId,App,Flower]};

%%默契度测试
read(30813,<<Answer/binary>>)->
	{Answer1,_} = pt:read_string(Answer),
	{ok,[Answer1]};

%%查询登陆抽奖信息
read(30075,<<>>)->
	{ok,[]};
%%查询登陆抽奖
read(30076,<<>>)->
	{ok,[]};

read(30077,<<>>)->
	{ok,[]};

read(30078,<<>>)->
	{ok,[]};

read(30079,<<Lv:32>>)->
	{ok,[Lv]};

read(30081,<<>>)->
	{ok,[]};

read(30082,<<>>)->
	{ok,[]};

read(30083,<<Type:16,Day:16>>)->
	{ok,[Type,Day]};

read(30900,<<>>)->
	{ok,[]};

read(30901,<<>>)->
	{ok,[]};

read(30902,<<>>)->
	{ok,[]};


%%查询循环任务奖励倍数
read(30101,<<>>)->
	{ok,[]};

%%刷新循环任务奖励倍数
read(30102,<<GoodsTypeId:32,Num:16,GoodsId:32>>)->
	{ok,[GoodsTypeId,Num,GoodsId]};

%%查询刷镖信息
read(30103,<<>>)->
	{ok,[]};
%%刷镖
read(30104,<<NpcId:32>>)->
	{ok,[NpcId]};

%%查询新手礼包信息
read(30084,<<>>)->
	{ok,[]};

%%领取新手礼包信息
read(30085,<<Lv:16>>)->
	{ok,[Lv]};

%%查询活动状态
read(30087,<<>>)->
	{ok,[]};

%%查询VIP体验卡领取记录
read(30088,<<Type:16>>)->
	{ok,[Type]};

%%领取VIP体验卡
read(30089,<<Type:16>>)->
	{ok,[Type]};

%%魅力兑换物品
read(30093,<<Type:16>>)->
	{ok,[Type]};
%%购买魅力礼包
read(30094,<<>>)->
	{ok,[]};

%% -----------------------------------------------------------------
%% 30016 周年庆活动祈愿信息
%% -----------------------------------------------------------------
read(30016, _R) ->
	{ok, []};

%% -----------------------------------------------------------------
%% 30017 周年庆活动发送祈愿
%% -----------------------------------------------------------------
read(30017, <<Gid:32, Bin/binary>>) ->
	{Content, _} = pt:read_string(Bin),
    {ok, [Gid, Content]};

%% -----------------------------------------------------------------
%% 30018 获取幸运转盘数据
%% -----------------------------------------------------------------
read(30018, <<Gid:32,GoodsType:32>>) ->
	{ok, [Gid,GoodsType]};

%% -----------------------------------------------------------------
%% 30019 幸运大转盘转动
%% -----------------------------------------------------------------
read(30019, <<Gid:32,GoodsType:32,Type:8>>) ->
	{ok, [Gid,GoodsType,Type]};

%% -----------------------------------------------------------------
%% 30020 猜灯谜请求
%% -----------------------------------------------------------------
read(30020, _R) ->
	{ok, []};

%% -----------------------------------------------------------------
%% 30021 猜灯谜结果发送
%% -----------------------------------------------------------------
read(30021, <<Answer:8>>) ->
	{ok, [Answer]};

%% -----------------------------------------------------------------
%% 30024 请求表白面板
%% -----------------------------------------------------------------
read(30024, _R) ->
	{ok,[]};

%% -----------------------------------------------------------------
%% 30025 投票
%% -----------------------------------------------------------------
read(30025, <<PlayerId:32>>) ->
	{ok,[PlayerId]};

%% -----------------------------------------------------------------
%% 30026 表白
%% -----------------------------------------------------------------
read(30026, <<NameBin/binary>>) ->
	{Name, N} = pt:read_string(NameBin),
	{Content, _} = pt:read_string(N),
    {ok, [Name, Content]};

%%30029 点名
read(30029,<<Name/binary>>)->
	{Nickname,_} = pt:read_string(Name),
	{ok,[Nickname]};

%%30030应答点名
read(30030,<<Res:16,Name/binary>>)->
	{Nickname,_} = pt:read_string(Name),
	{ok,[Res,Nickname]};
%%
%% -----------------------------------------------------------------
%% 30031 竞猜面板请求
%% -----------------------------------------------------------------
read(30031, _R) ->
	{ok, []};

%% -----------------------------------------------------------------
%% 30032 开始竞猜
%% -----------------------------------------------------------------
read(30032, _R) ->
	{ok, []};

%% -----------------------------------------------------------------
%% 30034 领取奖励
%% -----------------------------------------------------------------
read(30034, _R) ->
	{ok, []};

read(Cmd, R) ->
 	io:format("{error, no_match}~p/~p.",[Cmd,R]),
    {error, no_match}.


%%
%%服务端 -> 客户端 ------------------------------------
%%

%% --- NPC对话开始 ----------------------------------

%% 任务列表
write(30000,[ActiveList, TriggerList])->
    ABin = pack_task_list(ActiveList),
    TBin = pack_task_list(TriggerList),
    Data = <<ABin/binary, TBin/binary>>,
    {ok, pt:pack(30000, Data)};

%%已接任务列表
write(30001,[TriggerList])->
	TBin = pack_task_list(TriggerList),
    Data = << TBin/binary>>,
    {ok, pt:pack(30001, Data)};

%%委托任务列表
write(30002,ConsignList)->
	TBin = pack_consign_list(ConsignList),
    Data = << TBin/binary>>,
    {ok, pt:pack(30002, Data)};

%% 接受任务
write(30003,[TId, Result])->
	{ok, pt:pack(30003, <<TId:32, Result:16>>)};

%% 完成任务
write(30004,[Result])->
	{ok, pt:pack(30004, <<Result:16>>)};

%% 放弃任务
write(30005,[Result])->
    {ok, pt:pack(30005, <<Result:8>>)};

%% 更新任务数据
write(30006, [Type,Id])->
    Data = <<Type:16,Id:32>>,
    {ok, pt:pack(30006, Data)};

%% 触发并完成任务
write(30008,[Result])->
	{ok, pt:pack(30008, <<Result:16>>)};

%% 任务奖励提示
write(30009,[Tid, Coin, Exp, Spt, BindingCoin, Attainment, GuildExp, Contrib, AwardSelectItemNum , AwardItem, AwardSelectItem])->
    AILen = length(AwardItem),
    AIBin = tool:to_binary([<<ItemIdA:32, NumA:16>>||{ItemIdA, NumA} <- AwardItem]),
    ASILen = length(AwardSelectItem),
    ASIBin = tool:to_binary([<<ItemIdB:32, NumB:16>>||{ItemIdB, NumB} <- AwardSelectItem]),
    Data = <<Tid:32, Coin:32, Exp:32, Spt:16, BindingCoin:32, Attainment:16, GuildExp:32, Contrib:32,AwardSelectItemNum:16, AILen:16, AIBin/binary,  ASILen:16, ASIBin/binary>>,
    {ok, pt:pack(30009, Data)};

%%客户端打开窗口事件
write(30010,[Res])->
	{ok, pt:pack(30010, <<Res:16>>)};

%% 通知客户端弹出部落选择界面
write(30011, []) ->
    {ok, pt:pack(30011, <<>>)};

%%委托任务
write(30012,[Result])->
	{ok,pt:pack(30012,<<Result:16>>)};

%%检查委托任务
write(30013,[Result,TaskId,Name,Times,Exp,Spt,Cul,Timestamp,Gold,Mark])->
	 NameLen = byte_size(Name),
	 {ok,pt:pack(30013,<<Result:16,TaskId:32,NameLen:16,Name/binary,Times:16,Exp:32,Spt:32,Cul:32,Timestamp:32,Gold:32,Mark:16>>)};

%%立即完成委托任务
write(30014,[Res])->
	{ok,pt:pack(30014,<<Res:16>>)};

%%立即完成跑商任务
write(30015,[Res])->
	{ok,pt:pack(30015,<<Res:16>>)};

%%查询副本令任务
write(30022,Data)->
	[Res,TaskId,Name,Times,Exp,Spt,Coin,BCoin,Cards,_,_,_] = Data,
	Name1 = tool:to_binary(Name),
	Len = byte_size(Name1),
	{ok,pt:pack(30022,<<Res:16,TaskId:32,Len:16,Name1/binary,Times:16,Exp:32,Spt:32,Coin:32,BCoin:32,Cards:16>>)};

%%使用副本令
write(30023,[Res])->
	{ok,pt:pack(30023,<<Res:16>>)};

%%通知客户端挂机
write(30027,[Type,MonId])->
	{ok,pt:pack(30027,<<Type:8,MonId:32>>)};

%%检查是否有在线奖励
write(30070,[[Times,Result,Timestamp],GoodsBag])->
	Len = length(GoodsBag),
	AIBin = tool:to_binary([pack_goods_id(Goods)||Goods <- GoodsBag]),
	{ok,pt:pack(30070,<<Times:16,Result:8,Timestamp:32,Len:16,AIBin/binary>>)};

write(30071,[Result,GoodsBag])->
	Len = length(GoodsBag),
	AIBin = tool:to_binary([pack_goods_id(Goods)||Goods <- GoodsBag]),
	{ok,pt:pack(30071,<<Result:16,Len:16,AIBin/binary>>)};

%%获取目标奖励信息
write(30072,[Day,TargetBag])->
	Days = length(TargetBag),
	AIBin = tool:to_binary([pack_target(Target)||Target <- TargetBag]),
	{ok,pt:pack(30072,<<Day:16,Days:16,AIBin/binary>>)};


%%获取目标奖励
write(30073,[Result,Day,Times])->
	{ok,pt:pack(30073,<<Day:16,Times:16,Result:16>>)};

%%查询目标奖励状态
write(30074,[Day,Times])->
	{ok,pt:pack(30074,<<Day:16,Times:16>>)};

%%检查是否有每日在线奖励
write(30900,[{Result,TimeStamp}])->
	{ok,pt:pack(30900,<<Result:8, TimeStamp:32>>)};

%%领取奖励的结果
write(30901,[Result, TimeStamp, GoodsId, IsEnd]) ->
     {ok,pt:pack(30901,<<Result:8, TimeStamp:32, GoodsId:32, IsEnd:8>>)};

%%获取boss刷新时间(倒计时)
write(30902,Result) ->
	F = fun({BossId,RetTime}) ->
				<<BossId:32,RetTime:32>>
		end,
	Bin = tool:to_binary([F(R) || R <- Result]),
	Len = length(Result),
	{ok,pt:pack(30902,<<Len:16,Bin/binary>>)};
%%选择国家结果
write(30080,[Result,Type,Realm,Bag]) ->
	{ok,pt:pack(30080,<<Result:8,Type:8,Realm:8,Bag:8>>)};

%%小飞鞋
write(30090,[Result])->
	{ok,pt:pack(30090,<<Result:16>>)};

%%每日传送
write(30091,[Result])->
	{ok,pt:pack(30091,<<Result:16>>)};

%%查询国运时间
write(30300,[Result,Realm,Remain])->
	{ok,pt:pack(30300,<<Result:8,Realm:8,Remain:32>>)};

%%查询指定部落是否国运时间
%% write(30301,[Result])->
%% 	{ok,pt:pack(30301,<<Result:8>>)};

%% 查询委托任务
write(30400,[TaskList,ConsignInfo])->
	TBin = pack_consign_task(TaskList),
	{PTimes,PTLimit,ATimes,ATLimit} = ConsignInfo,
    Data = << TBin/binary,PTimes:16,PTLimit:16,ATimes:16,ATLimit:16>>,
    {ok, pt:pack(30400, Data)};

%%发布委托任务
write(30401,[Result])->
	{ok,pt:pack(30401,<<Result:16>>)};

%%接受委托任务
write(30402,[Result])->
	{ok,pt:pack(30402,<<Result:16>>)};

%%取消委托任务
write(30403,[Result])->
	{ok,pt:pack(30403,<<Result:16>>)};

%%每日任务累积
write(30600,DailyTaskInfo)->
	TBin = pack_daily_task_info(DailyTaskInfo),
	Data = <<TBin/binary>>,
	{ok,pt:pack(30600,Data)};

%%查询商车信息
write(30700,[Times,Color])->
	{ok,pt:pack(30700,<<Times:8,Color:8>>)};

%%刷新商车
write(30701,[Res,Color])->
	{ok,pt:pack(30701,<<Res:8,Color:8>>)};

%%查询是否跑商双倍时间
write(30702,[Result,TimeStamp])->
	{ok,pt:pack(30702,<<Result:8,TimeStamp:32>>)};

write(30703,[Result]) ->
	{ok,pt:pack(30703,<<Result:8>>)};

%%##请求刷新有缘人时间CD
write(30800,[Timestamp,Invitee])->
	Len = length(Invitee),
	AIBin = tool:to_binary([pack_player_list(Name,Pid,Career,Sex)||{Name, Pid,Career,Sex} <- Invitee]),
	{ok,pt:pack(30800,<<Timestamp:32,Len:16,AIBin/binary>>)};

%%刷新有缘人
write(30801,[Result,Timestamp,PlayerList])->
	Len = length(PlayerList),
	AIBin = tool:to_binary([pack_player_list(Name,Pid,Career,Sex)||{Name, Pid,Career,Sex} <- PlayerList]),
	{ok,pt:pack(30801,<<Result:8,Timestamp:32,Len:16,AIBin/binary>>)};

%%查看玩家状态
write(30802,[Res])->
	{ok,pt:pack(30802,<<Res:8>>)};

%%邀请有缘人
write(30803,[Res])->
	{ok,pt:pack(30803,<<Res:16>>)};

%%收到邀请
write(30804,[PlayerId,Name,Career,Sex,Type])->
	Name1 = tool:to_binary(Name),
	Len = byte_size(Name1),
	{ok,pt:pack(30804,<<PlayerId:32,Len:16,Name1/binary,Career:8,Sex:8,Type:8>>)};

%%接受、拒绝邀请
write(30805,[Res,PlayerId,Name,Career,Sex])->
	Name1 = tool:to_binary(Name),
	Len = byte_size(Name1),
	{ok,pt:pack(30805,<<Res:8,PlayerId:32,Len:16,Name1/binary,Career:8,Sex:8>>)};

%%赠送礼物
write(30806,[Res])->
	{ok,pt:pack(30806,<<Res:16>>)};

%%共享经验时间
write(30807,[Timestamp])->
	{ok,pt:pack(30807,<<Timestamp:32>>)};

%%取消邀请
write(30808,[Name])->
	Name1 = tool:to_binary(Name),
	Len = byte_size(Name1),
	{ok,pt:pack(30808,<<Len:16,Name1/binary>>)};

%%共享鲜花 
write(30809,[Timestamp])->
	{ok,pt:pack(30809,<<Timestamp:32>>)};

%%评价以及赠送鲜花结构
write(30810,[Res])->
	{ok,pt:pack(30810,<<Res:16>>)};

%%收到评价以及鲜花
write(30811,[PlayerId,Name,Career,Sex,App,Flower])->
	Name1 = tool:to_binary(Name),
	Len = byte_size(Name1),
	{ok,pt:pack(30811,<<PlayerId:32,Len:16,Name1/binary,Career:8,Sex:8,App:16,Flower:16>>)};

%%开启评价提示
write(30812,[PlayerId,Name,Career,Sex])->
	Name1 = tool:to_binary(Name),
	Len = byte_size(Name1),
	{ok,pt:pack(30812,<<PlayerId:32,Len:16,Name1/binary,Career:8,Sex:8>>)};

%%默契度测试
write(30813,[IsFinish,IsFirst,Timestamp,Privity,Spirit,Question,A,B,C])->
	QuestionName = tool:to_binary(Question),
	QLen = byte_size(QuestionName),
	
	AnswerA = tool:to_binary(A),
	ALen = byte_size(AnswerA),
	
	AnswerB = tool:to_binary(B),
	BLen = byte_size(AnswerB),
	
	AnswerC = tool:to_binary(C),
	CLen = byte_size(AnswerC),
	{ok,pt:pack(30813,<<IsFinish:8,IsFirst:16,Timestamp:32,Privity:32,Spirit:32,
						QLen:16,QuestionName/binary,ALen:16,AnswerA/binary,BLen:16,AnswerB/binary,CLen:16,AnswerC/binary>>)};
	
%%登陆抽奖信息
write(30075,[GoodsId1,Days,Times,GoodsList])->
	GoodsLen = length(GoodsList),
	GoodsBin = tool:to_binary([pack_lucky_goods_id(GoodsId)||GoodsId <- GoodsList]),
	{ok,pt:pack(30075,<<GoodsId1:32,Days:16,Times:16,GoodsLen:16,GoodsBin/binary>>)};

%%登陆抽奖
write(30076,[Res,GoodsId])->
	{ok,pt:pack(30076,<<Res:16,GoodsId:32>>)};

%%领取物品
write(30077,[Res,GoodsId,Days,Times,GoodsList])->
	GoodsLen = length(GoodsList),
	GoodsBin = tool:to_binary([pack_lucky_goods_id(Goods_Id)||Goods_Id <- GoodsList]),
	{ok,pt:pack(30077,<<Res:16,GoodsId:32,Days:16,Times:16,GoodsLen:16,GoodsBin/binary>>)};

%%查询目标引导
write(30078,TargetList)->
	TargetBin = pack_target_lead(TargetList),
	{ok,pt:pack(30078,TargetBin)};

%%领取目标引导
write(30079,[Res,Rank])->
	{ok,pt:pack(30079,<<Res:16,Rank:16>>)};

%%查询登陆奖励信息（新）
write(30081,[IsCharge,Days,UnChargeGoods,ChargeGoods])->
	UnChargeLen = length(UnChargeGoods),
	GoodsBin = tool:to_binary([pack_login_award(GoodsBag,1)||GoodsBag <- UnChargeGoods]),
	ChargeLen = length(ChargeGoods),
	GoodsBin1 = tool:to_binary([pack_login_award(GoodsBag1,2)||GoodsBag1 <- ChargeGoods]),
	{ok,pt:pack(30081,<<IsCharge:8,Days:16,UnChargeLen:16,GoodsBin/binary,ChargeLen:16,GoodsBin1/binary>>)};

%%清除登陆天数
write(30082,[Res])->
	{ok,pt:pack(30082,<<Res:16>>)};

%%领取登陆物品
write(30083,[Res,Type,Days])->
	{ok,pt:pack(30083,<<Res:16,Type:16,Days:16>>)};

%%查询循环任务奖励倍数
write(30101,[Mult])->
	{ok,pt:pack(30101,<<Mult:16>>)};

%%刷新奖励倍数
write(30102,[Res,Mult])->
	{ok,pt:pack(30102,<<Res:16,Mult:16>>)};

%%查询刷镖信息
write(30103,[M1,M2,M3])->
	{ok,pt:pack(30103,<<M1:8,M2:8,M3:8>>)};

%%刷镖
write(30104,[Res])->
	{ok,pt:pack(30104,<<Res:16>>)};

%%查询新手礼包信息
write(30084,[Lv,Mark,GoodsBag])->
	Len = length(GoodsBag),
	GoodsBin = tool:to_binary(pack_novice_gift(GoodsBag,[])),
	{ok,pt:pack(30084,<<Lv:16,Mark:8,Len:16,GoodsBin/binary>>)};

%%领取新手礼包
write(30085,[Res,GoodsBag])->
	Len = length(GoodsBag),
	GoodsBin = tool:to_binary(pack_novice_goods(GoodsBag,[])),
	{ok,pt:pack(30085,<<Res:16,Len:16,GoodsBin/binary>>)};

%%拜师，收徒指引
write(30086,[Type])->
	{ok,pt:pack(30086,<<Type:8>>)};

%%开服活动信息
write(30087,ActivitiesList) ->
	F = fun([Type,State,Stime,Etime]) ->
			<<Type:16,State:8,Stime:32,Etime:32>>
		end,
	L = length(ActivitiesList),
	Bin = tool:to_binary(lists:map(F, ActivitiesList)),
	Bin2 = <<L:16,Bin/binary>>,
	{ok,pt:pack(30087, Bin2)};


%%查询VIP体验卡领取记录
write(30088,[Type,Res,G])->
	{ok, pt:pack(30088, <<Type:16,Res:8,G:32>>)};

%%领取VIP体验卡
write(30089,[Res])->
	{ok, pt:pack(30089, <<Res:16>>)};

%%魅力兑换物品
write(30093,[Res])->
	{ok, pt:pack(30093, <<Res:16>>)};

%%购买魅力礼包
write(30094,[Res])->
	{ok,pt:pack(30094,<<Res:16>>)};

%% -----------------------------------------------------------------
%% 30016 周年庆活动祈愿信息
%% -----------------------------------------------------------------
write(30016, [SubList]) ->
	Len = length(SubList),
	PackList = lists:map(fun(Elem) ->
								#ets_anniversary_bless{pname = PName,
													   gid = Gid,
													   content = Content} = Elem,
								{PLen, PBin} = lib_guild_inner:string_to_binary_and_len(PName),
								{CLen, CBin} = lib_guild_inner:string_to_binary_and_len(Content),
								<<PLen:16, PBin/binary, CLen:16, CBin/binary, Gid:32>>
						 end, SubList),
	Bin = tool:to_binary(PackList),
%% 	?DEBUG("30016 SubList is:~p", [SubList]),
	{ok,pt:pack(30016, <<Len:16,Bin/binary>>)};

%% -----------------------------------------------------------------
%% 30017 周年庆活动发送祈愿
%% -----------------------------------------------------------------
write(30017, [Result]) ->
%%	?DEBUG("30017 result is:~p", [Result]),
	{ok,pt:pack(30017, <<Result:8>>)};

%% -----------------------------------------------------------------
%% 30018 获取幸运转盘数据
%% -----------------------------------------------------------------
write(30018, [Gid,GoodsType,Result, NewGid]) ->
%%	?DEBUG("30018 result is:~p,Gid is:~p", [Result, Gid]),
	{ok,pt:pack(30018, <<Gid:32,GoodsType:32,Result:8, NewGid:32>>)};

%% -----------------------------------------------------------------
%% 30019 幸运大转盘转动
%% -----------------------------------------------------------------
write(30019, [Gid,GoodsType,Type, Result, NewGid]) ->
%%	?DEBUG("30019 Type is:~p, result is:~p,Gid is:~p", [Type, Result, Gid]),
	{ok,pt:pack(30019, <<Gid:32,GoodsType:32,Type:8, Result:8, NewGid:32>>)};

%% -----------------------------------------------------------------
%% 30020 猜灯谜请求
%% -----------------------------------------------------------------
write(30020, [Result, Lid, ENum, No]) ->
	?DEBUG("30020 result is:~p,Lid is:~p, ENum:~p, No:~p", [Result, Lid, ENum, No]),
	{ok,pt:pack(30020, <<Result:8, Lid:32, ENum:8, No:8>>)};

%% -----------------------------------------------------------------
%% 30021 猜灯谜结果发送
%% -----------------------------------------------------------------
write(30021, [Result]) ->
	?DEBUG("30021 result is:~p", [Result]),
	{ok,pt:pack(30021, <<Result:8>>)};

%%表白数据
write(30024, {List,SelfVotes,Res}) ->
	F = fun(R)->
				{Id, PName, RName, Content, Votes} = R,
				PN = tool:to_binary(PName),
				RN = tool:to_binary(RName),
				CN = tool:to_binary(Content),
				PLen = byte_size(PN),
				RLen = byte_size(RN),
				CLen = byte_size(CN),
				<<Id:32,PLen:16,PN/binary,RLen:16,RN/binary,CLen:16,CN/binary,Votes:32>>
		end,
	{Wbin,Wlen} = {[F(R) || R <- List], length(List)},
	Bin = tool:to_binary(Wbin),
	{ok, pt:pack(30024, <<Wlen:16,Bin/binary,SelfVotes:32,Res:8>>)};

%%投票
write(30025,{Res,Id,Votes}) ->
	{ok,pt:pack(30025, <<Res:8,Id:32, Votes:32>>)};

write(30026,Res) ->
	{ok,pt:pack(30026, <<Res:8>>)};

%%点名
write(30029,[Name])->
	Name1 = tool:to_binary(Name),
	Len = byte_size(Name1),
	{ok,pt:pack(30029, <<Len:16,Name1/binary>>)};

%%应答点名
write(30030,[Res])->
	{ok,pt:pack(30030, <<Res:16>>)};

%% -----------------------------------------------------------------
%% 30031 竞猜面板请求
%% -----------------------------------------------------------------
write(30031, [Type, PrizeNum, LuckyNum, MyLuckyNum, State, Prize, LuckyOnes]) ->
%% 	?DEBUG("30031, Type:~p, PrizeNum:~p, LuckyNum:~p, MyLuckyNum:~p, State:~p, Prize:~p, LuckyOnes:~p", [Type, PrizeNum, LuckyNum, MyLuckyNum, State, Prize, LuckyOnes]),
	{Len, LuckyNamesBin} = handle_30031(LuckyOnes, 0, []),
	{ok, pt:pack(30031, <<Type:8, PrizeNum:32, LuckyNum:16, MyLuckyNum:16, State:8, Prize:32, Len:16, LuckyNamesBin/binary>>)};

%% -----------------------------------------------------------------
%% 30032 开始竞猜
%% -----------------------------------------------------------------
write(30032, [Result, MyLucky]) ->
%% 	?DEBUG("Result:~p, MyLucky:~p", [Result, MyLucky]),
	{ok, pt:pack(30032, <<Result:8, MyLucky:16>>)};

%% -----------------------------------------------------------------
%% 30033 系统摇号结果
%% -----------------------------------------------------------------
write(30033, [SysLuckyNum]) ->
%% 	?DEBUG("SysLuckyNum:~p", [SysLuckyNum]),
	{ok, pt:pack(30033, <<SysLuckyNum:16>>)};

%% -----------------------------------------------------------------
%% 30034 领取奖励
%% -----------------------------------------------------------------
write(30034, [Result]) ->
	{ok, pt:pack(30034, <<Result:8>>)};

%% -----------------------------------------------------------------
%% 30035 判断是否需要通知竞猜奖励
%% -----------------------------------------------------------------
write(30035, []) ->
	{ok, pt:pack(30035, <<>>)};

%%
%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.

%% -----------私有函数------------
pack_novice_gift([],Bag)->Bag;
pack_novice_gift([{GoodsId,Num}|GoodsBag],Bag)->
	pack_novice_gift(GoodsBag,[<<GoodsId:32,Num:16>>|Bag]).

pack_novice_goods([],Bag)->Bag;
pack_novice_goods([GoodsId|GoodsBag],Bag)->
	pack_novice_goods(GoodsBag,[<<GoodsId:32>>|Bag]).

pack_task_list([]) -> <<0:16>>;
pack_task_list(TaskList) ->
	NewTaskList = fix_taskList(TaskList,[]),
    Len = length(NewTaskList),
    Bin = tool:to_binary([pack_task(X) || X <- NewTaskList]),
    <<Len:16, Bin/binary>>.

fix_taskList([],NewTaskList) ->
	NewTaskList;
fix_taskList([TaskList|T],NewTaskList)->
	case TaskList of
		skip->fix_taskList(T,NewTaskList);
		_->fix_taskList(T,[TaskList]++NewTaskList)
	end.
			 
pack_task({Tid,Lev,Type,Chlid,Name,Desc,EndNpc,Tip,Gold, Coin, Exp, 
		   Spt, BindingCoin, Attainment, Honor,RealmHonor,GuildExp, GuildCoin,Contrib, 
		   AwardSelectItemNum , AwardItem, AwardSelectItem,Times}) ->
%% 	io:format("Tid_~p_~p~n",[Tid,Lev]),
    NameLen = byte_size(Name),
    DescLen = byte_size(Desc),
    TipBin = pack_task_tip_list(Tip),
    AILen = length(AwardItem),
    AIBin = tool:to_binary([<<ItemIdA:32, NumA:16>>||{ItemIdA, NumA} <- AwardItem]),
    ASILen = length(AwardSelectItem),
    ASIBin = tool:to_binary([<<ItemIdB:32, NumB:16>>||{ItemIdB, NumB} <- AwardSelectItem]),
    <<Tid:32, Lev:16, Type:16, Chlid:16,NameLen:16, Name/binary,
	   DescLen:16, Desc/binary,EndNpc:32,Gold:32,Coin:32, Exp:32, Spt:32,
	   BindingCoin:32, Attainment:32,Honor:32,RealmHonor:32, GuildExp:32,GuildCoin:32, Contrib:32,
	  AwardSelectItemNum:16, AILen:16, AIBin/binary,  ASILen:16,
	   ASIBin/binary, TipBin/binary,Times:8>>.

%%打包系统委托任务
pack_consign_list([]) -> <<0:16>>;
pack_consign_list(TaskList) ->
    Len = length(TaskList),
	NowTime = util:unixtime(),
    Bin = tool:to_binary([pack_consign(X,NowTime) || X <- TaskList]),
    <<Len:16, Bin/binary>>.
pack_consign({Tid,Name,Times,Exp,Spt,Att,Timestamp,Gold,Type},NowTime)->
	NameLen = byte_size(Name),
	TimeRemain = Timestamp - NowTime,
	<<Tid:32,NameLen:16,Name/binary,Times:16,Exp:32,Spt:32,Att:32,TimeRemain:32,Gold:32,Type:16>>.

%%打包玩家委托任务
pack_consign_task([])-><<0:16>>;
pack_consign_task(TaskList) ->
	Len = length(TaskList),
	NowTime = util:unixtime(),
	Bin = tool:to_binary([pack_consign_player(X,NowTime) || X <- TaskList]),
    <<Len:16, Bin/binary>>.
pack_consign_player({_,Id, PlayerId,TaskId,Name,Lv,Time,State,GoodsId1,
					 Num1,GoodsId2,Num2,MoneyType,Num3,_,Accept,EndTime,_},NowTime)->
	NameLen = byte_size(Name),
	TimeRemain = case EndTime of
					 0->0;
					 _->EndTime - NowTime
				 end,
	Money = lib_task:accept_money(Time,Lv),

	<<Id:32,PlayerId:32,TaskId:32,NameLen:16,Name/binary,Lv:16,Time:16,
	  State:16,GoodsId1:32,Num1:16,GoodsId2:32,Num2:16,MoneyType:16,Num3:32,
	  Accept:32,TimeRemain:32,Money:32>>.

%%打包日常任务累积
pack_daily_task_info([])-><<0:16>>;
pack_daily_task_info(DailyTaskBag)->
	Len = length(DailyTaskBag),
	Bin = tool:to_binary([pack_daily_task(X) || X <- DailyTaskBag]),
    <<Len:16, Bin/binary>>.

pack_daily_task({TaskId,Name,Award})->
	NameLen = byte_size(Name),
	<<TaskId:32,NameLen:16,Name/binary,Award:16>>.

 %% 打包任务目标
pack_task_tip_list([]) -> <<0:16>>;
pack_task_tip_list(TipList) ->
    Len = length(TipList),
    Bin = tool:to_binary([ pack_task_tip(X) || X <- TipList]),
    <<Len:16, Bin/binary>>.
pack_task_tip(X) ->
    [Type,Finish,Id,Name,Num,NowNum,SceneId, SceneName, Ex] = X,
    NLen = byte_size(Name),
    SNLen = byte_size(SceneName),
    ExBin = tool:to_binary(util:implode("#&", Ex)),
    ExL = byte_size(ExBin),
    <<Type:16, Finish:16, Id:32, NLen:16, Name/binary, Num:16, NowNum:16, 
	  SceneId:32, SNLen:16, SceneName/binary, ExL:16, ExBin/binary>>.

%%打包玩家信息（仙侣情缘）
pack_player_list(Name,Id,Career,Sex)->
	NLen = byte_size(Name),
	<<NLen:16,Name/binary,Id:32,Career:16,Sex:16>>.

%%打包远古目标内容
pack_target(Target)->
	Len = length(Target),
	AIBin = tool:to_binary([pack_target_id(TargetId)||TargetId <- Target]),
	<<Len:16,AIBin/binary>>.

pack_target_id(TargetId)->
	<<TargetId:8>>.

pack_lucky_goods_id(GoodsId)->
	<<GoodsId:32>>.
			
%%打包目标引导
pack_target_lead(TargetLead)->
	Len = length(TargetLead),
	AIBin = tool:to_binary([pack_target_info(Lv,TargetId,Rank)||{Lv,TargetId,Rank} <- TargetLead]),
	<<Len:16,AIBin/binary>>.

pack_target_info(Lv,TargetId,Rank)->
	<<Lv:16,TargetId:8,Rank:16>>.

%%打包登陆奖励
pack_login_award(GoodsBag,Type)->
	Len = length(GoodsBag),
	{Day,GoodsList} = pack_login_info(GoodsBag,Type,0,[]),
	AIBin = tool:to_binary(GoodsList),
	<<Day:16,Len:16,AIBin/binary>>.

pack_login_info([],_Type,Day,GoodsBin)->
	{Day,GoodsBin};
pack_login_info([GoodsInfo|GoodsBag],Type,Day,GoodsBin)->
	[NewDay,GoodsId,Num] = GoodsInfo,
	if Day =/= NewDay ->
		   NewDay1 = NewDay;
	   true->
		   NewDay1 = Day
	end,
	{_,DefNum} = lib_login_award:goods(Type,NewDay1),
	pack_login_info(GoodsBag,Type,NewDay1,[<<GoodsId:32,Num:16,DefNum:16>>|GoodsBin]).

%%打包在线奖励物品信息
pack_goods_id([GoodsId,Num])->
	<<GoodsId:32,Num:16>>.

handle_30031([], Num, Result) ->
	{Num, tool:to_binary(Result)};
handle_30031([Lucky|LuckyOnes], Num, Result) ->
	#quizzes{pname = PName} = Lucky,
	{NLen, NameBin} = lib_guild_inner:string_to_binary_and_len(PName),
	NResult = [<<NLen:16, NameBin/binary>>|Result],
	handle_30031(LuckyOnes, Num+1, NResult).