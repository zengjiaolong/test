%% Author: xianrongMai
%% Created: 2012-1-4
%% Description: 周年活动处理接口
-module(lib_anniversary).

%%
%% Include files
%%

-include("common.hrl").
-include("record.hrl").
-include("activities.hrl").

%%祈祷的物品ID列表
-define(WISH_GOODS_LIST, 
		[31215,    	%%南皇时装变身券	
		 21600,   	%%五彩仙玉碎片	
		 31060,    	%%远古精魄礼包
		 16004,    	%%冰魂
		 16005,   	%%炎魄
		 16010,    	%%飞行画卷
		 16008,    	%%月兔
		 16001,    	%%冰川虎
		 16003,    	%%独角兽
		 24303,    	%%仙灵召唤卡
		 28602,    	%%VIP半年卡
		 20505,    	%%9级强化保护符
		 20504,    	%%8级强化保护符
		 21504,   	%%8级紫水晶
		 21704		%%8级紫玉	
		]).

-define(WISHTREE_LUCKYS, 5).	%%许愿树的幸运儿数量
%%
%% Exported Functions
%%
-export([
		 check_aninversary_linggen/1, 	%% 检测全身的灵根达到的数值return -> 0,50,60,70,80,90,100
		 robotmon_broadcast/1,			%% 开发部boss刷新广播
		 refresh_robotmon/1,			%% 刷新怪物操作
		 use_bigwheel/1,				%% 使用大转盘的物品(点击领取抽奖的时候)
		 get_bigwheel_goods/0,			%% 返回大转盘的物品ID和数量
		 check_bigwheel_use/3,			%% 使用远古大转盘的判断(记录删除)
		 roll_big_wheel/4,				%% 大转盘roll随机物品ID
		 check_bigwheel/2,				%% 判断是否已经转过大转盘
		 
		 check_wish_goods/1,			%% 检查物品是否合法
		 lottery_wishtree/0,			%% 抽奖得出幸运儿
		 check_wishtree_data/3,			%% 检查是否需要清理祝福的数据
		 get_wish_mark/0,				%% 做周年活动中祈祷许愿的标志
		 put_wish_mark/1,				%% 做周年活动中祈祷许愿的标志
		 
		 get_wish_tree/1,				%% 30016 周年庆活动祈愿信息
		 make_wish/5,					%% 30017 周年庆活动发送祈愿
		 
		 clear_all_old_data/0,			%% 到期清理全部的祝福许愿的数据
		 check_wish_time/2,				%% 检查是否在祝福的时间
		 load_anniversary/0				%%  初始化祈祷活动的数据
]).

%%
%% API Functions
%%



%%
%% Local Functions
%%
%%初始化祈祷活动的数据
load_anniversary() ->
	%%直接全部数据一次性的全load出来
	List = db_agent:load_anniversary(),
	lists:foreach(fun(Elem) ->
						  [Pid, PName, Gid, Time, Content] = Elem,
						  Anniversary = 
							  #ets_anniversary_bless{
													 pid = Pid,		%%玩家Id
													 pname = PName,	%%玩家名字
													 gid = Gid,		%%玩家祈祷所得的物品Id
													 time = Time,		%%祈福的时间
													 content = Content	%%祝福内容
													},
						  update_anniversary(Anniversary)
				  end, List).


update_anniversary(Anniversary) ->
	ets:insert(?ANNIVERSARY, Anniversary).
delete_all_anniversary() ->
	ets:delete_all_objects(?ANNIVERSARY).
lookup_anniversary(PlayerId) ->
	ets:lookup(?ANNIVERSARY, PlayerId).
get_all_anniversary() ->
	ets:tab2list(?ANNIVERSARY).

%%检查是否需要清理祝福的数据
check_wishtree_data(Type, NowTime, NowSec) ->
	%%周年活动时间
	{ST, ET} = lib_activities:anniversary_time(),
	{STSec, ETSec} = lib_activities:wish_tree_time(),
	case Type of
		1 ->
			if
				((STSec - ?ANNIVERSARY_TIME_STAMP*2) =< NowSec andalso NowSec =< ETSec) 
				andalso(ST =< NowTime andalso NowTime =< ET) ->
					1;
				true ->
					0
			end;
		0 ->
			
			if 
				((STSec - ?ANNIVERSARY_TIME_STAMP*2) =< NowSec andalso NowSec =< STSec)
				  andalso(ST =< NowTime andalso NowTime =< ET) ->
					%%清理数据
					clear_all_old_data(),
					%%计算活动结束的时间
					Diff = ETSec - NowSec,
					%%启动活动结束的公告
					erlang:send_after(Diff*1000, self(), {'END_WISHTREE_BROADCAST'}),
					1;
				true ->
					Type
			end
	end.

%%到期清理全部的祝福许愿的数据
clear_all_old_data() ->
	%%删除ets
	delete_all_anniversary(), 
	%%删除数据库
	erlang:spawn(fun() -> db_agent:delete_all_old_anniversary() end).

%%检查是否在祝福的时间
check_wish_time(NowSec, NowTime) ->
	%%周年活动时间
	{ST, ET} = lib_activities:anniversary_time(),
	{STSec, ETSec} = lib_activities:wish_tree_time(),
	case STSec =< NowSec andalso NowSec =< ETSec of
		false ->%%不是许愿树时间
			false;
		true ->
			ST =< NowTime andalso NowTime =< ET
	end.

%% -----------------------------------------------------------------
%% 30016 周年庆活动祈愿信息
%% -----------------------------------------------------------------
get_wish_tree(PidSend) ->
	%%获取所有的
	Anniversary = get_all_anniversary(),
	%%排序
	Sort = lists:sort(fun(A,B) ->
					   A#ets_anniversary_bless.time >= B#ets_anniversary_bless.time
			   end, Anniversary),
	%%截取前面的100条
	SubList = lists:sublist(Sort, 100),
	%%打包
	{ok, BinData30017} = pt_30:write(30016, [SubList]),
	lib_send:send_to_sid(PidSend, BinData30017).

%% -----------------------------------------------------------------
%% 30017 周年庆活动发送祈愿
%% -----------------------------------------------------------------
make_wish(PlayerId, PName, Gid, Content, NowTime) ->
	case lookup_anniversary(PlayerId) of
		[] ->%%居然还未许愿过，可以许愿
			Anniversary = 
				#ets_anniversary_bless{
									   pid = PlayerId,		%%玩家Id
									   pname = PName,	%%玩家名字
									   gid = Gid,		%%玩家祈祷所得的物品Id
									   time = NowTime,		%%祈福的时间
									   content = Content	%%祝福内容
									  },
			%%更新数据库
			erlang:spawn(fun() -> db_agent:insert_player_wish(PlayerId, PName, Gid, NowTime, Content) end),
			%%更新ets
			update_anniversary(Anniversary),
			%%世界播报
			Text = 
				io_lib:format("[<font color='#8800FF'>~s</font></a>]的祝福:<font color='#FEDB4F'>~s</font></a>！",
							  [PName, Content]),
			lib_chat:broadcast_sys_msg(12, Text),
			1;
		_ ->
			3
	end.
	
%%检查物品是否合法
check_wish_goods(Gid) ->
	lists:member(Gid, ?WISH_GOODS_LIST).

%%抽奖得出幸运儿
lottery_wishtree() ->
	%%获取所有的祝福人员
	Anniversary = get_all_anniversary(),
	case Anniversary of
		[] ->%%没人，不广播了
			skip;
		_ ->
			Wishers = lists:map(fun(Elem) ->
										#ets_anniversary_bless{pid = Pid,
															   pname = PName,
															   gid = Gid} = Elem,
										{Pid, PName, Gid}
								end, Anniversary),
			Luckies = random_wishtree(?WISHTREE_LUCKYS, Wishers, []),
			Content = make_packet_lucky(Luckies),
			%%世界广播
			lib_chat:broadcast_sys_msg(11, Content)
	end.

random_wishtree(_Num, [], Result) ->
	Result;
random_wishtree(0, _Wishers, Result) ->
	Result;
random_wishtree(Num, Wishers, Result) ->
	Len = length(Wishers),
	%%产生随机数
	R = util:rand(1, Len),
	Elem = lists:nth(R, Wishers),
	{Pid,_N,_G} = Elem,
	NWishers = lists:keydelete(Pid, 1, Wishers),
	random_wishtree(Num-1, NWishers, [Elem|Result]).

make_packet_lucky(Luckies) ->
	lists:foldl(fun({_Pid,PName,Gid}, AccIn) ->
						Title = "远古封神祈福活动",
						Content = "感谢您对远古封神的祝福，请查收您的祈福物品！",
						mod_mail:send_sys_mail([tool:to_list(PName)], Title, Content, 0, Gid, 1, 0, 0, 0),
						case goods_util:get_goods_type(Gid) of
							GoodsInfo when is_record(GoodsInfo, ets_base_goods) ->
								#ets_base_goods{color = ColorNum,
												goods_name = GoodsName} = GoodsInfo,
								Color = goods_util:get_color_hex_value(ColorNum),
								MSG  = 
									io_lib:format("[<font color='#FEDB4F'>~s</font></a>]的愿望实现了，获得了祈福物品[<font color='~s'>~s</font></a>]！ ",
												  [PName, Color, GoodsName]),
								MSG ++ AccIn;
							_ ->
								AccIn
						end
				end, "", Luckies).

						

%%做周年活动中祈祷许愿的标志
get_wish_mark() ->
	case get(wish_mark) of
		undefined ->
			0;
		Num when is_integer(Num) ->
			Num;
		_ ->
			0
	end.
put_wish_mark(NowTime) ->
	put(wish_mark, NowTime).
	

%%判断是否已经转过大转盘31229 28750
check_bigwheel(PlayerId,GoodsType) ->
	case get_bigwheel(GoodsType) of
		{ok, GoodsId} ->
			{on, GoodsId};
		fail->
			case db_agent:get_use_numtime(log_goods_counter, PlayerId, GoodsType) of%%查询幸运大转盘是否已经转过
				[] ->
					{off, 0};
				[GoodsId, _FinalTime] ->
					put_bigwheel(GoodsType,GoodsId),
					{on, GoodsId}
			end
	end.
			
get_bigwheel(GoodsType) ->
	case get(big_wheel) of
		undefined ->
			fail;
		0 ->
			fail;
		{GoodsType,GoodsId} when is_integer(GoodsId) ->
			{ok, GoodsId};
		_ ->
			fail
	end.
put_bigwheel(GoodsType,GoodsId) ->
	put(big_wheel, {GoodsType,GoodsId}).
erasse_bigwheel() ->
	erase(big_wheel).
	

%%返回大转盘的物品ID和数量
get_bigwheel_goods() ->
	[{32028,10},{32021,10},{32022,10},{32016,10},{32026,50},			%%神器类
	 {22007,1},{22000,5},{22008,5},{22006,5},{23306,10},				%%经脉类	
	 {20315,1},{21617,1},{28801,1},{21023,5},{21801,3},					%%装备类
	 {24401,1},{24105,1},{24800,3},{24400,5},{24104,5}].				%%灵兽类

%%活动大转盘roll随机物品ID
roll_big_wheel(PlayerId,GoodsType,Type,_GoodsInfo) when GoodsType == 31229 ->
	Gids =
		case Type of
			1->%%神器类
				[{32028,10},{32021,10},{32022,10},{32016,10},{32026,50}];
			2->%%经脉类	
				[{22007,1},{22000,5},{22008,5},{22006,5},{23306,10}];
			3->%%装备类
				[{20315,1},{21617,1},{28801,1},{21023,5},{21801,3}];
			4->%%灵兽类
				[{24401,1},{24105,1},{24800,3},{24400,5},{24104,5}]
		end,
	%%产生随机数
	Len = length(Gids),
	R = util:rand(1, Len),
	{Gid,_N} = lists:nth(R, Gids),
	%%数据库
	NowTime = util:unixtime(),
	%%查询幸运大转盘是否已经转过
	case db_agent:get_use_numtime(log_goods_counter, PlayerId, 31229) of
		[] ->
			ValueList = [PlayerId, 31229, Gid, NowTime],
			FieldList = [player_id, type, num, fina_time],
			db_agent:insert_user_numtime(log_goods_counter, ValueList, FieldList);
		[_Num, _FinalTime] ->
			ValueList = [{num, Gid},
						 {fina_time, NowTime}],
			WhereList = [{player_id, PlayerId},{type,31229}],
			db_agent:update_user_numtime(log_goods_counter, ValueList, WhereList)
	end,
	%%添加进程字典
	put_bigwheel(GoodsType,Gid),
	Gid;
%%普通物品转盘
roll_big_wheel(PlayerId,GoodsType,_Type,GoodsInfo) when GoodsType == 28750  ->
	GoodsTypeInfo = goods_util:get_goods_type(GoodsType),
	One = goods_util:parse_goods_other_data(GoodsTypeInfo#ets_base_goods.other_data,rgift),
	F_get = fun(Other,DataInfo)->
				{_Goods_id,_n,_bind,_Ratio} = Other,
				NewOther = {_Goods_id,_n,GoodsInfo#goods.bind,_Ratio},
					lists:duplicate(_Ratio, NewOther) ++ DataInfo
		end,
	DuplicateGoods = lists:foldl(F_get, [], One),
	Len =  length(DuplicateGoods),
	case Len > 0 of
		true ->
			R = util:rand(1,Len),
			case lists:nth(R, DuplicateGoods) of
				{Goods_id,_N,_Bind,_} ->
					%%查询幸运大转盘是否已经转过
					case db_agent:get_use_numtime(log_goods_counter, PlayerId, 28750) of
						[] ->
							ValueList = [PlayerId, 28750, Goods_id, GoodsInfo#goods.bind],
							FieldList = [player_id, type, num, fina_time],
							db_agent:insert_user_numtime(log_goods_counter, ValueList, FieldList);
						[_Num, _FinalTime] ->
							ValueList = [{num, Goods_id},
						 				{fina_time, GoodsInfo#goods.bind}],
							WhereList = [{player_id, PlayerId,{type,28750}}],
							db_agent:update_user_numtime(log_goods_counter, ValueList, WhereList)
					end,
					%%添加进程字典
					put_bigwheel(GoodsType,Goods_id),
					Goods_id;
				_ ->
					0
			end;
		false ->
			0
	end.

%% 使用远古大转盘的判断(记录删除)
check_bigwheel_use(Res, NewStatus2, GoodsTypeId) ->
	case Res of
		1 ->
			if
				GoodsTypeId == 31229 orelse GoodsTypeId == 28750 ->
					erasse_bigwheel(),
					db_agent:delete_bigwheel_use(NewStatus2#player.id,GoodsTypeId);
				true ->
					skip
			end;
		_R ->
			skip
	end.
	
%%使用大转盘的物品(点击领取抽奖的时候)
use_bigwheel([Player,GoodsType]) when GoodsType == 31229 ->
	%%查询幸运大转盘是否已经转过
	case db_agent:get_use_numtime(log_goods_counter, Player#player.id, GoodsType) of
		[] ->
			0;
		[GoodsId, _FinalTime] ->
			GoodsList = get_bigwheel_goods(),
			case lists:keyfind(GoodsId, 1, GoodsList) of
				false ->
					0;
				{_G, Num} ->
					Title = "远古大转盘",
					Content = "感谢你对远古封神的支持，请查收你获得的物品",
					mod_mail:send_sys_mail([tool:to_list(Player#player.nickname)], Title, Content, 0, GoodsId, Num, 0, 0, 0),
					case goods_util:get_goods_type(GoodsId) of
						GoodsInfo when is_record(GoodsInfo, ets_base_goods) ->
							#ets_base_goods{color = ColorNum,
											goods_name = GoodsName} = GoodsInfo,
							Color = goods_util:get_color_hex_value(ColorNum),
							Msg  = 
								io_lib:format("幸福扑面而来，“<font color='#8800FF'>咚</font></a>”一声，<font color='#FFFFFF'>~p</font></a>个[<font color='~s'>~s</font></a>]砸到了[<a href='event:1,~p,~s,~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>]的脑门！好疼的说...",
											  [Num, Color, GoodsName, Player#player.id, Player#player.nickname, Player#player.career, Player#player.sex, Player#player.nickname]),
							spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end),
							1;
						_ ->%%找不到信息，算了，不广播
							1
					end
			end
	end;

%% 普通转盘，返回值不一样
use_bigwheel([Player,GoodsStatus,GoodsType]) when GoodsType == 28750 ->
	case db_agent:get_use_numtime(log_goods_counter, Player#player.id, GoodsType) of
		[] ->
			{0 ,GoodsStatus};
		[GoodsId,BindType] ->
			case lib_goods:give_goods({GoodsId, 1 ,BindType}, GoodsStatus) of
				{ok,GoodsStatus2} ->
					{1,GoodsStatus2};
				_ -> 
					{0 ,GoodsStatus}
			end
	end;

use_bigwheel([_Player,_GoodsType]) ->
	0.
	

%%怪物刷新时间段   活动期间12：35分、18：35分
get_robotmon_time() ->
	{45300, 66900}.			%%警告，正确的时间，不要随意修改，如需使用，请用下面的测试代码
	
	%%测试用代码
%% 	{14*3600+06*60, 14*3600+08*60}.

%%刷新怪物操作		
refresh_robotmon(NowSec) ->
	%%获取圣诞节的活动时间
	{ChrStart, ChrEnd} = lib_activities:anniversary_time(),
	NowTime = util:unixtime(),
	case ChrStart =< NowTime andalso NowTime < ChrEnd of
		true ->%%活动期间哦
			{One, Two} = get_robotmon_time(),
			case (One =< NowSec andalso NowSec < (One+20)) %%12:30
				orelse (Two =< NowSec andalso NowSec < (Two+20)) of%%18:30
				true ->
					case get_robotmon_on() of
						1 ->%%已经开了
							skip;
						0 ->
							%%获取场景的Pid,九霄
							ScenePid = mod_scene:get_scene_pid(300, undefined, undefined),
							%%怪物刷新广播
							MSG = "<font color='#8800FF'>《远古封神》</font>开发部成员带着大量礼品出现九霄城内！快去抢！  <a href='event:6,300,49,99'><font color='#00FF33'><u>》》立刻前往《《</u></font></a>",
							spawn(fun()->lib_chat:broadcast_sys_msg(2, MSG)end),
							%%向场景发信息，通知生成怪物
							[First|_Other] = ?ANNIVERSARY_MON_IDS,
							gen_server:cast(ScenePid, {apply_cast, lib_scene, load_robot_mon, [First, 300, ?ROBOT_MON_COORD]}),
							?DEBUG("init the robot mon", []),
							put_robotmon_on(1)%%设置新的状态
					end;
				false ->
					put_robotmon_on(0)%%恢复状态
			end;
		false ->
			skip
	end.
	
get_robotmon_on() ->
	case get(robotmon) of
		undefined ->
			0;
		1 ->
			1;
		0 ->
			0;
		_ ->
			0
	end.
put_robotmon_on(Num) ->
	put(robotmon, Num).

%%开发部boss刷新广播
robotmon_broadcast(MonId) ->
	case MonId of
		40971 ->%%开发部一号
			MSG = "哥是斯文人，别打我！我给你钱！坐下来喝杯茶，聊聊人生理想！",
			{ok, BinData39100} = pt_39:write(39100, [11, MSG]),
			timer:apply_after(2000, mod_scene_agent, send_to_scene,[300, BinData39100]);
		40972 ->%%开发部二号
			MSG = "此路是我开，此树是我栽！人见人爱，车见车载...姐，只是个传说",
			{ok, BinData39100} = pt_39:write(39100, [12, MSG]),
			timer:apply_after(2000, mod_scene_agent, send_to_scene,[300, BinData39100]);
		40973 ->%%开发部三号
			MSG = "敢杀我？！杀了我~~~我就让你们通通掉线！",
			{ok, BinData39100} = pt_39:write(39100, [13, MSG]),
			timer:apply_after(2000, mod_scene_agent, send_to_scene,[300, BinData39100]);
		40974 -> %%开发部四号
			MSG = "来吧~~来吧~~来杀我吧~~~杀了我，让你们通通卡死！哇咔咔...",
			{ok, BinData39100} = pt_39:write(39100, [14, MSG]),
			timer:apply_after(2000, mod_scene_agent, send_to_scene,[300, BinData39100]);
		40975 ->%%开发部五号
			MSG = "本姑奶奶是远古大军终极统领，你们最好别惹我！不然让你们通通降50级！喊娘去吧，吼吼哈哈，嚯嚯嚯嚯...", 
			{ok, BinData39100} = pt_39:write(39100, [15, MSG]),
			timer:apply_after(2000, mod_scene_agent, send_to_scene,[300, BinData39100]);
%% 			spawn(fun() -> mod_scene_agent:send_to_scene(300, BinData39100) end);
		_ ->
			skip
	end.



%%检测全身的灵根达到的数值return -> 0,50,60,70,80,90,100
check_aninversary_linggen(PlayerId) ->
	case lib_meridian:get_player_meridian_info(PlayerId) of
		[] ->
			0;
		[Meri|_] ->
			LinGen = [Meri#ets_meridian.mer_yang_linggen, Meri#ets_meridian.mer_yin_linggen, 
					  Meri#ets_meridian.mer_wei_linggen, Meri#ets_meridian.mer_ren_linggen, 
					  Meri#ets_meridian.mer_du_linggen, Meri#ets_meridian.mer_chong_linggen, 
					  Meri#ets_meridian.mer_qi_linggen, Meri#ets_meridian.mer_dai_linggen],
			check_linggen_info(LinGen)
	end.
check_linggen_info(LinGen) ->
	lists:foldl(fun(Elem, AccIn) ->
						if
							Elem >= 100 ->%%灵根100
								AccIn;
							Elem >= 90 ->%%灵根90
								case AccIn >= 100 of
									true ->
										90;
									false ->
										AccIn
								end;
							Elem >= 80 ->%%灵根80
								case AccIn >= 90 of
									true ->
										80;
									false ->
										AccIn
								end;
							Elem >= 70 ->%%灵根70
								case AccIn >= 80 of
									true ->
										70;
									false ->
										AccIn
								end;
							Elem >= 60 ->%%灵根60
								case AccIn >= 70 of
									true ->
										60;
									false ->
										AccIn
								end;
							Elem >= 50 ->%%灵根50
								case AccIn >= 60 of
									true ->
										50;
									false ->
										AccIn
								end;
							Elem >= 40 ->%%灵根40
								case AccIn >= 50 of
									true ->
										40;
									false ->
										AccIn
								end;
							Elem >= 30 ->%%灵根30
								case AccIn >= 40 of
									true ->
										30;
									false ->
										AccIn
								end;
							Elem >= 20 ->%%灵根20
								case AccIn >= 30 of
									true ->
										20;
									false ->
										AccIn
								end;
							Elem >= 10 ->%%灵根10
								case AccIn >= 20 of
									true ->
										10;
									false ->
										AccIn
								end;
							true ->
								0
						end
				end, 100, LinGen).
	
