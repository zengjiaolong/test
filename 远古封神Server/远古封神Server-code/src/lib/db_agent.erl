
%%%--------------------------------------
%%% @Module  : db_agent
%%% @Author  : ygzj
%%% @Created : 2010.08.24
%%% @Description: 统一的数据库处理模块
%%%--------------------------------------
-module(db_agent).

-include("common.hrl").
-include("record.hrl").

-compile(export_all).   
 
%%%%% begin lib_account

%% 创建角色  增加插入默认字段
create_role(AccId, AccName, Sn, Career, Realm, Sex, Name, Time, LTime, X, Y, SceneId,
			 Forza, Physique, Agile, Wit, Coin, Cash, Gold, Hp, Mp, Spirit, AttArea, AttSpeed, Speed, CellNum, StoreNum, RealmHonor) ->
	case ?DB_MODULE == db_mysql of 
		true ->
			no_action;		
		_ ->			%% 部落计数器+1
			if Realm =/= 100 ->
				?DB_MODULE:findAndModify("auto_ids", lists:concat(["realm_",Realm]), "num");
			   true -> no_action
			end 
	end,	
	Player = #player{
      		accid = AccId,
      		accname = AccName,
			sn = Sn,
      		career = Career,
			realm = Realm,
      		sex = Sex,
			nickname = Name,
			reg_time = Time,
			last_login_time = LTime,
			x = X, 
			y = Y, 
			scene = SceneId, 
			forza = Forza, 
			physique = Physique, 
			agile = Agile, 
			wit = Wit,
			coin = Coin, 
			cash = Cash, 
			gold = Gold, 
			hp = Hp, 
			mp = Mp,
			spirit = Spirit, 
			att_area = AttArea, 
			att_speed = AttSpeed, 
			speed = Speed, 
			cell_num = CellNum,
			store_num = StoreNum,
			other = 0,
			realm_honor = RealmHonor						 
	},
    ValueList = lists:nthtail(2, tuple_to_list(Player)),
    [id | FieldList] = record_info(fields, player),
	Ret = ?DB_MODULE:insert(player, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			Ret;
		_ ->
			{mongo, Ret}
	end.
	
%%系统启动将所有玩家的在线改为0
init_player_online_flag()->
	?DB_MODULE:update(player, [{online_flag, 0}],[{online_flag,1}]).

%% 删除角色
delete_role(PlayerId, Accid) ->
    ?DB_MODULE:delete(player, [{id, PlayerId}, {accid, Accid}]).
	
%% 通过角色ID取得帐号ID
get_accountid_by_id(PlayerId) ->
	?DB_MODULE:select_one(player, "accid", [{id, PlayerId},{status,"<>",1}], [], [1]).
get_accid_sn_by_id(PlayerId) ->
	?DB_MODULE:select_row(player, "accid,sn", [{id, PlayerId},{status,"<>",1}], [], [1]).

%%获取名字
get_nick_by_id(PlayerId) ->
	?DB_MODULE:select_one(player, "nickname", [{id, PlayerId}], [], [1]).

%%VIP信息
get_vip_info(PlayerId) ->
	?DB_MODULE:select_one(player, "vip", [{id, PlayerId}], [], [1]).

get_realm_by_nick(Nick) ->
	?DB_MODULE:select_one(player, "realm", [{nickname, Nick}], [], [1]).

get_player_career(PlayerId)->
  	?DB_MODULE:select_one(player, "career", [{id, PlayerId}], [], [1]).

%% 通过帐号ID取得角色ID
get_playerid_by_accountid(AccId) ->
	?DB_MODULE:select_one(player, "id", [{accid, AccId}], [], [1]).

%% 通过角色ID取得帐号信息
get_info_by_id(PlayerId) ->
	?DB_MODULE:select_row(player, "*", [{id, PlayerId}], [], [1]).

%%获取账号信息
get_user_accinfo_by_accid_and_sn(AccId,Sn)->
	?DB_MODULE:select_row(user, "accid,accname,status,sn,ct", [{accid, AccId},{sn,Sn}], [], [1]).

get_equip_current(Player_Id) ->
	Mount1 = ?DB_MODULE:select_one(player, "mount", [{id, Player_Id}], [], [1]),
	WQ1 = ?DB_MODULE:select_one(goods, "id", [{player_id, Player_Id},{location,1},{type,10},{subtype, ">", 8},{subtype, "<", 14}], [], [1]),
	YF1 = ?DB_MODULE:select_one(goods, "id", [{player_id, Player_Id},{location,1},{type,10},{subtype, 24}], [], [1]),
	FBYF1 = ?DB_MODULE:select_one(goods, "id", [{player_id, Player_Id},{location,1},{type,10},{subtype, 26}], [], [1]),
	SPYF1 = ?DB_MODULE:select_one(goods, "id", [{player_id, Player_Id},{location,1},{type,10},{subtype, 27}], [], [1]),
	Mount = 
		case Mount1 of
			null -> 0;
			_ -> Mount1
		end,	
	WQ = 
		case WQ1 of
			null -> 0;
			_ -> WQ1
		end,
	YF = 
		case YF1 of
			null -> 0;
			_ -> YF1
		end,
	FBYF = 
		case FBYF1 of
			null -> 0;
			_ -> FBYF1
		end,
	SPYF = 
		case SPYF1 of
			null -> 0;
			_ -> SPYF1
		end,
	[WQ,YF,FBYF,SPYF,Mount].

%%获取角色部落、等级、氏族(用与私聊面板)
get_chat_info_by_id(PlayerId) ->
	?DB_MODULE:select_row(player, "realm, lv, guild_name, guild_id, nickname", [{id, PlayerId}], [], [1]).

get_realm_by_id(PlayerId)->
	?DB_MODULE:select_one(player, "realm", [{id, PlayerId}], [], [1]).

%% 获取角色money信息
get_player_money(PlayerId) ->
	?DB_MODULE:select_row(player,"gold,cash,coin,bcoin",[{id,PlayerId}],[],[1]).

%%玩家使用商城积分
update_sub_score(PlayerId,Score) ->
	?DB_MODULE:update(player, [{sub_score, Score}], [{player_id, PlayerId}]).

%%查询消耗积分
get_sub_score(PlayerId) ->
	?DB_MODULE:select_row(sub_score,"sub_score",[{player_id,PlayerId}],[],[1]).

%% 获取玩家的最后充值时间
get_last_pay_time(PlayerId) ->
	?DB_MODULE:select_one(log_pay,"insert_time",[{player_id,PlayerId},{pay_status,1}],[{insert_time,desc}],[1]).

%%获取玩家最早充值时间
get_first_pay_time(PlayerId)->
	?DB_MODULE:select_one(log_pay,"insert_time",[{player_id,PlayerId},{pay_status,1}],[{insert_time,asc}],[1]).
get_first_pay_time_phone(PlayerId)->
	?DB_MODULE:select_one(log_phone_pay,"insert_time",[{player_id,PlayerId},{pay_status,1}],[{insert_time,asc}],[1]).


%% 获取玩家的充值记录
get_pay_log_list(Fields,WhereList) ->
	?DB_MODULE:select_all(log_pay,Fields,WhereList).

%%获取玩家11月17日以后的充值元宝数
get_active_pay_log_sum(PlayerId) ->
	%%1321458891
	sum(log_pay, "pay_gold", [{player_id,PlayerId},{insert_time,">",1321458891}]).

%%查询充值元宝数，用于计算商城积分---2011.11.18
get_gold_for_score(PlayerId) ->
	?DB_MODULE:select_row(sub_score,"money",[{player_id,PlayerId}],[],[1]).

%% 获取玩家最后一次充值的金额
get_last_pay_value(PlayerId) ->
	?DB_MODULE:select_one(log_pay,"pay_gold",[{player_id,PlayerId},{pay_status,1}],[{insert_time,desc}],[1]).

%%充值测试
test_charge_insert(PlayerId)->
	NowTime = util:unixtime(),
	?DB_MODULE:insert(log_pay,[player_id,insert_time,pay_status],[PlayerId,NowTime,1]).

test_charge_insert(PlayerId,Gold)->
	NowTime = util:unixtime(),
	?DB_MODULE:insert(log_pay,[player_id,insert_time,pay_status,pay_gold],[PlayerId,NowTime,1,Gold]).

%%测试，清除充值列表
test_delete_charge(PlayerId)->
	?DB_MODULE:delete(log_pay,[{player_id,PlayerId}]).

%% 玩家踢出日志
insert_kick_off_log(Uid, NickName, K_type, Now_time, Scene, X, Y) ->
	?DB_MODULE:insert(?LOG_POOLID, log_kick_off, [uid, nickname, k_type, time, scene, x, y], [Uid, NickName, K_type, Now_time, Scene, X, Y]).

%% 取得指定帐号名称的角色列表 
get_role_list(Accid, Accname) ->
	Ret = ?DB_MODULE:select_row(player, "id, status, nickname, sex, lv, realm, career", 
								[{accid, Accid}, {accname, Accname}],
							   [],[1]),
	case Ret of 
		[] -> [];
		_ -> [Ret]
	end.

%% 取得指定帐号名称的角色列表 
get_role_list(Sn, Accid, Accname) ->
	Ret = ?DB_MODULE:select_row(player, "id, status, nickname, sex, lv, realm, career", 
								[{accid, Accid}, {accname, Accname},{sn, Sn}],
							   [],[1]),
	case Ret of 
		[] -> [];
		_ -> [Ret]
	end.

getin_createpage(Nowtime) ->
	?DB_MODULE:insert(stc_create_page, [cp_time], [Nowtime]).

%% 更新账号最近登录时间和IP
update_last_login(Time, LastLoginIP, PlayerId) ->
	%%暂屏蔽
	%%?DB_MODULE:insert(?LOG_POOLID, log_plogin, [{pid,PlayerId},{ac,1},{ip,LastLoginIP},{ts,Time}]),
	?DB_MODULE:update(player,[{last_login_time, Time}, {online_flag, 1}, {last_login_ip,LastLoginIP}],[{id, PlayerId}]).
 
%% 更新帐号最后登出时间和ip 
update_last_logout(_Time, _LastLoginIP, _PlayerId) ->
	%%暂屏蔽
	%%?DB_MODULE:insert(?LOG_POOLID, log_plogin, [pid,ac,ip,ts],[PlayerId,0,LastLoginIP,Time}]).
	ok.

%%更改角色配偶名
update_cuple_name(Name,PlayerId) ->
	?DB_MODULE:update(player,[{couple_name,Name}],[{id, PlayerId}]).

%% 更新角色在线状态
update_online_flag(PlayerId, Online_flag) ->
	?DB_MODULE:update(player,[{online_flag, Online_flag}],[{id, PlayerId}]).

%% 更新角色修为
updata_player_culture(PlayerId, Culture) ->
	?DB_MODULE:update(player,[{culture, Culture}],[{id, PlayerId}]).

%% 设置账号状态(0-正常，1-禁止)
set_user_status(Sn, Accid, Status) ->
	?DB_MODULE:update(user, [{status, Status}], [{accid, Accid},{sn, Sn}]).

%% 设置角色状态(0-正常，1-禁止)
set_player_status(Id, Status) ->
	?DB_MODULE:update(player, [{status, Status}], [{id, Id}]).

%% 获取角色禁言信息
get_donttalk_status(Id) ->
	?DB_MODULE:select_row(player_donttalk, "timeStart, interval_minutes",[{player_id, Id}], [], [1]).

%% 设置角色禁言信息
set_donttalk_status(Id, TimeStart, Interval_minutes) ->
	?DB_MODULE:replace(player_donttalk, 
								 [{player_id, Id}, 
								  {timeStart, TimeStart},
								  {timeEnd, 0},
								  {interval_minutes, Interval_minutes},
								  {content, ""}
								  ]).

%% 取消角色禁言
delete_donttalk(Id) ->
	?DB_MODULE:delete(player_donttalk, [{player_id, Id}]).

%% 获取user表的最新ID
get_user_id() ->
	case ?DB_MODULE =:= db_mysql of
		true ->
    		0;
		_ ->
			?DB_MODULE:select_one(auto_ids, "id", [{name, "user"}], [], [1])
	end.

%%获取玩家最近登录的时间
get_player_lastt_login(ChiefId) ->
	?DB_MODULE:select_one(player, "last_login_time", [{id, ChiefId}], [], [1]).

%%获取玩家姓名
get_player_nick(ChiefId) ->
	?DB_MODULE:select_one(player, "nickname", [{id, ChiefId}], [], [1]).

%%查询玩家多个字段属性
get_player_fields(FieldList,Id) ->
	?DB_MODULE:select_row(player, util:list_to_string(FieldList), [{id, Id}], [], [1]).

%%%%% end end


%% 初始化所有系统公告
get_sys_acm(Nowtime) ->
	?DB_MODULE:select_all(sys_acm, "id, acm_type, acm_ivl, nexttime, content, acm_color, acm_link, acm_times", [{begtime, "<=", Nowtime},{endtime, ">", Nowtime},{acm_times, ">=", 0}]).

%% 获取一条系统公告
get_one_acm(Id) ->
	?DB_MODULE:select_row(sys_acm,"id, acm_type, acm_ivl, nexttime, content, acm_color, acm_link, acm_times",[{id,Id}]).
%%%%% 凝神修炼 begin
%% 获取玩家修炼记录
get_exc_rec(Pid) ->
	?DB_MODULE:select_row(exc, "exc_status, this_beg_time, this_end_time, this_exc_time, total_exc_time, pre_pay_coin, pre_pay_gold, last_logout_time", [{player_id, Pid}], [], [1]).
  
%% 检测玩家是否第一次修炼
ver_exc_record(Id) ->
	?DB_MODULE:select_one(exc, "player_id", [{player_id, Id}], [], [1]).

%% 检测玩家的修炼状态
get_exc_status(Id) ->
	?DB_MODULE:select_one(exc, "exc_status", [{player_id, Id}], [], [1]).

%% 获取玩家的当前修炼的开始时间
get_exc_begtime(Id) ->
	?DB_MODULE:select_one(exc, "this_beg_time", [{player_id, Id}], [], [1]).

%% 获取玩家的当前修炼的结束时间
get_exc_endexc_time(Id) ->
	?DB_MODULE:select_row(exc, "this_end_time, this_exc_time", [{player_id, Id}], [], [1]).

%% 获取玩家的当前修炼的总时间
get_exc_exctime(Id) ->
	?DB_MODULE:select_one(exc, "this_exc_time", [{player_id, Id}], [], [1]).

%% 获取玩家的当天累计修炼时间
get_exc_toltime(Id) ->
	?DB_MODULE:select_one(exc, "total_exc_time", [{player_id, Id}], [], [1]).

%% 获取玩家的当前修炼预付铜币
get_exc_prepay_coin(Id) ->
	?DB_MODULE:select_one(exc, "pre_pay_coin", [{player_id, Id}], [], [1]).

%% 获取玩家的当前修炼预付元宝
get_exc_prepay_gold(Id) ->
	?DB_MODULE:select_one(exc, "pre_pay_gold", [{player_id, Id}], [], [1]).

%% 获取修炼中玩家的上次离线时间
get_exc_logout_tm(Id) ->
	?DB_MODULE:select_one(exc, "last_logout_time", [{player_id, Id}], [], [1]).

%% 插入玩家的修炼记录
add_exc_info(Id, Exc_status, This_end_time, This_exc_time, Pre_pay_coin, Pre_pay_gold) ->
	This_beg_time = This_end_time - This_exc_time * 60,
	?DB_MODULE:insert(exc,[player_id, exc_status, this_beg_time, this_end_time, this_exc_time, pre_pay_coin, pre_pay_gold, last_logout_time],
				  						[Id, Exc_status, This_beg_time, This_end_time, This_exc_time, Pre_pay_coin, Pre_pay_gold, This_beg_time]).

%% 更新玩家的修炼记录
set_exc_info(Id, Exc_status, This_end_time, This_exc_time, Pre_pay_coin, Pre_pay_gold) ->
	This_beg_time = This_end_time - This_exc_time * 60,
	?DB_MODULE:update(exc,
						[{exc_status, Exc_status},
						{this_beg_time, This_beg_time},
						{this_end_time, This_end_time},
						{this_exc_time, This_exc_time},
						{pre_pay_coin,Pre_pay_coin},
						{pre_pay_gold,Pre_pay_gold},
						{last_logout_time, This_beg_time}
						],
					[{player_id, Id}]).

%% 清理玩家的修炼记录
clear_exc_info(Id, Endtime) ->
	?DB_MODULE:update(exc,
						[{exc_status, 3},
						{this_exc_time, 0},
						{this_end_time, Endtime},
						{pre_pay_coin,0},
						{pre_pay_gold,0}
						],
					[{player_id, Id}]).

%% 插入玩家的修炼日志
add_exc_log(Pid, This_exc_time, This_beg_time, Last_logout_time, This_end_time, Total_exc_time, Act_exc_time, End_type) ->
	?DB_MODULE:insert(?LOG_POOLID, log_exc, [player_id, this_exc_time, this_beg_time, last_logout_time, this_end_time, total_exc_time, act_exc_time, end_type],
				  						[Pid, This_exc_time, This_beg_time, Last_logout_time, This_end_time, Total_exc_time, Act_exc_time, End_type]).

%% 插入玩家的修炼经验日志（1W经验以上）
add_exc_exp_log(PlayerId, This_beg_time, This_end_time, This_exc_time, Exc_time_min, Exp_inc) ->
	Nowtime = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID, log_exc_exp, [player_id, this_beg_time, this_end_time, this_exc_time, exc_time_min, exp_inc, nowtime],
				  						[PlayerId, This_beg_time, This_end_time, This_exc_time, Exc_time_min, Exp_inc, Nowtime]).

%% 设置玩家的当前修炼预付铜币
set_exc_prepay_coin(Id, Prepay) ->
	?DB_MODULE:update(exc, [{pre_pay_coin, Prepay}], [{player_id, Id}]).

%% 重置凝神修炼开始时间以及累计修炼时间初始值
reset_exc_begtime(Id, NewBegtime, NewTTtime) ->
	?DB_MODULE:update(exc, [{this_beg_time, NewBegtime}, {total_exc_time, NewTTtime}], [{player_id, Id}]).

%% 重置凝神修炼
reset_exc(Id, New_begtime, New_exc_m, NewTTtime) ->
	?DB_MODULE:update(exc, [{this_beg_time, New_begtime}, {this_exc_time, New_exc_m}, {total_exc_time, NewTTtime}], [{player_id, Id}]).

%% 重置凝神修炼开始时间
set_exc_begtime(Id, NewBegtime) ->
	?DB_MODULE:update(exc, [{this_beg_time, NewBegtime}], [{player_id, Id}]).

%% 设置玩家的当前修炼预付元宝
set_exc_prepay_gold(Id, Prepay) ->
	?DB_MODULE:update(exc, [{pre_pay_gold, Prepay}], [{player_id, Id}]).

%% 设置玩家的当前修炼的结束时间
reduce_exc_endtime(Id, Etime) ->
	?DB_MODULE:update(exc, [{this_end_time, Etime, sub}], [{player_id, Id}]).

%% 设置玩家的当天累计修炼时间
set_exc_toltime(Id, Ttime) ->
	?DB_MODULE:update(exc, [{total_exc_time, Ttime}], [{player_id, Id}]).

%% 设置修炼中玩家的离线时间
set_exc_logout_tm(Id, TimeNow) ->	
	?DB_MODULE:update(exc, [{last_logout_time, TimeNow}], [{player_id, Id}]).
	
%% 设置修炼中玩家的位置
set_exc_loc(Id, Scid, X ,Y) ->
	?DB_MODULE:update(player, [{scene, Scid}, {x, X}, {y, Y}], [{player_id, Id}]).

%%%%% 凝神修炼end

%%%%% 防沉迷 begin

%% 验证账户是否已经纳入防沉迷
ver_accid(Sn, Accid) ->
	?DB_MODULE:select_one(infant_ctrl, "accid", [{accid, Accid},{sn, Sn}], [], [1]).

%% 读取账户防沉迷类型
get_idcard_status(Sn, Accid) ->
	?DB_MODULE:select_one(user, "idcard_status", [{accid, Accid},{sn, Sn}], [], [1]).
	
%% 读取账户防沉迷类型
get_idcard_status(Sn, Accid, Accname) ->
	case ?DB_MODULE:select_one(user, "idcard_status", [{accid, Accid},{sn,Sn}], [], [1]) of
		Val0 when Val0 == undefined orelse Val0 == null ->
			?DB_MODULE:insert(user,[accid, accname, status, idcard_status, sn],
				  						[Accid, Accname, 0, 0, Sn]),
			0;
		Val ->
			Val	
	end.

%%更新玩家buff的时间，下线时间
update_pbuff_time(Now, PlayerId) ->
	?DB_MODULE:update(player_other, [{up_t, Now}], [{pid, PlayerId}]).

%%更改变性时间
update_sex_time(Now, PlayerId) ->
	?DB_MODULE:update(player_other, [{sex_change_time, Now}], [{pid, PlayerId}]).

%%更改当前称号
update_cur_title(Tid, PlayerId) ->
	?DB_MODULE:update(player_other, [{ptitle, Tid}], [{pid, PlayerId}]).

%%获取玩家buff的时间和称号集,up_t:玩家上次下线时间
get_other_player_data(PlayerId) ->
%% 	FieldList = "up_t, ptitles, ptitle, zxt_honor, quickbar",
	?DB_MODULE:select_row(player_other, "*", [{pid, PlayerId}], [{up_t, desc}], [1]).
get_player_titles_delay(PlayerId) ->
	?DB_MODULE:select_row(player_other, "ptitles", [{pid, PlayerId}], [{up_t, desc}], [1]).

%%新增玩家buff的时间，下线时间(默认值在这里添加)
insert_player_other_info(NowTime, PTitles, Quickbar, PlayerId) ->
	?DB_MODULE:insert(player_other, [pid, up_t, ptitles, ptitle, zxt_honor, quickbar], [PlayerId, NowTime, PTitles, 0, 0, Quickbar]).

%%更新player_other表
update_player_other(Table, ValueLists, WhereLists) ->
	?DB_MODULE:update(Table, ValueLists, WhereLists).

%%更新玩家player_other表的titles
update_player_other_titles(Titles, PlayerId) ->
	NewTitles = util:term_to_string(Titles),
	?DB_MODULE:update(player_other, [{ptitles, NewTitles}], [{pid, PlayerId}]).
	
%% %% 根据账户获取身份证号码（未成年人）
%% get_idcard_num(Accid) ->
%% 	?DB_MODULE:select_one(user, "idcard_num", [{accid, Accid}], [], [1]).

%% %% 根据身份证读取账户上次离线时间（身份证纳入防沉迷）
%% get_infant_time(Idcard_num) ->
%% 	?DB_MODULE:select_one(infant_ctrl, "last_logout_time", [{idcard_num, Idcard_num}], [], [1]).
	
%% 根据账户读取账户上次离线时间（账户纳入防沉迷）	
get_infant_time_byuser(Sn, Accid) ->
	?DB_MODULE:select_one(infant_ctrl_byuser, "last_logout_time", [{accid, Accid},{sn, Sn}], [], [1]).

%% %% 读取身份证累计游戏时间（身份证纳入防沉迷）
%% get_gametime(Idcard_num)->
%% 	?DB_MODULE:select_one(infant_ctrl, "total_game_time", [{idcard_num, Idcard_num}], [], [1]).
	
%% 读取账户累计游戏时间（账户纳入防沉迷）	
get_gametime_byuser(Sn, Accid)->
		?DB_MODULE:select_one(infant_ctrl_byuser, "total_game_time", [{accid, Accid},{sn, Sn}], [], [1]).
	
%% %% 设置身份证累计游戏时间（身份证纳入防沉迷）
%% set_gametime(Idcard_num, T_time)->
%% 	?DB_MODULE:update(infant_ctrl, [{total_game_time, T_time}], [{idcard_num, Idcard_num}]).

%% 设置账户累计游戏时间（账户纳入防沉迷）
set_gametime_byuser(Sn, Accid, T_time)->
	?DB_MODULE:update(infant_ctrl_byuser, [{total_game_time, T_time}], [{accid, Accid},{sn, Sn}]).	

%% %% 设置账户上次离线时间（身份证纳入防沉迷）
%% set_last_logout_time(Idcard_num, L_time)->
%% 	?DB_MODULE:update(infant_ctrl, [{last_logout_time, L_time}], [{idcard_num, Idcard_num}]).
	
%% 设置账户上次离线时间（账户纳入防沉迷）
set_last_logout_time_byuser(Sn, Accid, L_time)->
	?DB_MODULE:update(infant_ctrl_byuser, [{last_logout_time, L_time}], [{accid, Accid},{sn, Sn}]).	

%% 设置账户防沉迷类型
set_idcard_status(Sn, Accid, Idcard_status) ->
	?DB_MODULE:update(user, [{idcard_status, Idcard_status}], [{accid, Accid},{sn, Sn}]).

%% %% 记录未成年人身份证号码
%% add_idcard_num(Accid, Idcard_num) ->
%% 	?DB_MODULE:update(user, [{idcard_num, Idcard_num}], [{accid, Accid}]).

%% %% 记录被纳入防沉迷的身份证，并记录累计游戏时间以及上次登陆时间
%% add_idcard_num(Idcard_num, T_time, L_time) ->
%% 	?DB_MODULE:insert(infant_ctrl,[idcard_num, total_game_time, last_logout_time],
%% 				  											[Idcard_num,T_time,L_time]).
	
%% 记录被纳入防沉迷的账户，并记录上次登陆时间
add_idcard_num_acc(Sn, Accid, TT_time, L_time) ->
	?DB_MODULE:insert(infant_ctrl_byuser,[accid, total_game_time, last_logout_time, sn],
				  														[Accid,TT_time,L_time,Sn]).
				  														
%% %% 由于此被纳入防沉迷的账户，已被验证为未成年人，依据身份证实施防沉迷，所以删除此记录
%% delete_idcard_num_acc(Accid) ->
%% 	?DB_MODULE:delete(infant_ctrl_byuser,[{accid,Accid}]).

%% 记录被纳入防沉迷的身份证，并记录累计游戏时间以及上次登陆时间

%%%%% 防沉迷 end
	
%%%%% begin goods_util

%% 获取所有物品信息
get_base_goods_info() ->
    ?DB_MODULE:select_all(base_goods, "*", [{goods_id,">", 0}]).

%% 获取所有装备类型附加属性信息
get_base_goods_add_attribute() ->
	?DB_MODULE:select_all(base_goods_add_attribute, "*", [{goods_id,">", 0}]).

%% 获取装备套装基础表
get_base_goods_suit()->
	?DB_MODULE:select_all(base_goods_suit,"*",[{suit_id,">",0}]).

%% 获取装备套装基础表
get_base_goods_suit_by_name(Name)->
	?DB_MODULE:select_all(base_goods_suit,"*",[{suit_name,Name}]).

get_base_goods_suit_by_id(SuitId)->
	?DB_MODULE:select_all(base_goods_suit,"*",[{suit_id,SuitId}]).

%% 获取装备套装属性信息
get_base_goods_suit_attribute() ->
	?DB_MODULE:select_all(base_goods_suit_attribute, "*", [{suit_id,">",0}]).

%% 获取装备强化规则信息
get_base_goods_strengthen() ->
	?DB_MODULE:select_all(base_goods_strengthen, "*", [{goods_id,">",0}]).

%%获取防具强化抗性规则信息
get_base_goods_strengthen_anti() ->
	?DB_MODULE:select_all(base_goods_strengthen_anti, "*", [{id,">",0}]).

%%获取装备强化额外信息
get_base_goods_strengthen_extra()->
	?DB_MODULE:select_all(base_goods_strengthen_extra, "*", [{level,">",0}]).

%%插入产生随机灵兽的数据
insert_random_pet(Player_Id,Before_value,After_value,Before_value1,After_value1,Batt_before_value,Batt_after_value,Order,Ct) ->
	?DB_MODULE:insert(pet_extra_value, [player_id,before_value,after_value,before_value1,after_value1,batt_before_value,batt_after_value,order,ct],[Player_Id,Before_value,After_value,Before_value1,After_value1,Batt_before_value,Batt_after_value,Order,Ct]).

%%取用户上次刷新出来的数据
get_random_pet(PlayerId) ->
	?DB_MODULE:select_row(pet_extra_value, "*", [{player_id,PlayerId}]).

%%取用户上次刷新出来的数据
updata_random_pet(PlayerId,Before_value,After_value,Before_value1,After_value1,Batt_before_value,Batt_after_value,Order,Ct) ->
	?DB_MODULE:update(pet_extra_value, [{before_value,Before_value},{after_value,After_value},{before_value1,Before_value1},{after_value1,After_value1},{batt_before_value,Batt_before_value},{batt_after_value,Batt_after_value},{order,Order},{ct,Ct}], [{player_id,PlayerId}]).

%%插入购买随机灵兽的数据日志
insert_random_pet_buy(Player_Id,Random_value,Lukcy_value) ->
	NowTime = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID,log_pet_extra_buy, [player_id,random_value,lukcy_value,ct],[Player_Id,Random_value,Lukcy_value,NowTime]).


%%获取法宝修炼规则信息 注意此方法有待改进，系统启动时加信息加载到缓存，
%%如果正在加载过程打开页面不能加载角色列表,加载缓存完成后就可以打开角色列表
get_base_goods_practise()->
	?DB_MODULE:select_all(base_goods_practise, "*", [{id,">",0}]).

%% 获取宝石合成规则信息
get_base_goods_compose() ->
	?DB_MODULE:select_all(base_goods_compose, "*", [{goods_id,">",0}]).

%% 获取宝石镶嵌规则信息
get_base_goods_inlay() ->
	?DB_MODULE:select_all(base_goods_inlay, "*", [{goods_id,">",0}]).

%% 获取装备分解规则表
get_base_goods_idecompose()->
	?DB_MODULE:select_all(base_goods_idecompose,"*",[{id,">",0}]).

%% 获取宝石合成规则表
get_base_goods_icompose()->
	?DB_MODULE:select_all(base_goods_icompose,"*",[{goods_id,">",0}]).

%% 获取天降彩石规则表
get_base_goods_ore()->
	?DB_MODULE:select_all(base_goods_ore,"*",[{goods_id,">",0}]).

%% 获取物品掉落数量规则信息
get_base_goods_drop_num() ->
	?DB_MODULE:select_all(base_goods_drop_num, "*", [{mon_id,">",0}]).

%% 获取物品掉落规则信息
get_base_goods_drop_rule() ->
	?DB_MODULE:select_all(base_goods_drop_rule, "*", [{mon_id,">",0}]).

%%初始化时装基础数据表
get_base_goods_fashion() ->
	?DB_MODULE:select_all(base_goods_fashion, "*", [{goods_id,">",0}]).

%%查询时装洗炼未替换的属性 
get_goods_fashion_log(PlayerId, Gid) ->
	?DB_MODULE:select_row(log_fashion, "id, old_pro, new_pro", [{player_id, PlayerId},{gid, Gid},{is_oper, 1}], [], [1]).

%%插入时装洗炼记录
log_fashion([Player_Id,GoodsId,StoneId,Old_Goods_attributList,New_Goods_attributList,Cost]) ->
	NowTime = util:unixtime(),
	?DB_MODULE:insert(log_fashion,[player_id, gid, stone_id, cost, old_pro, new_pro, is_oper, washct, operct],
				  														[Player_Id,GoodsId,StoneId,Cost,Old_Goods_attributList,New_Goods_attributList,1,NowTime,0]).

%%时装日志更新替换或维持原属性,更新操作类型(0持维原属性，1未替换，2已经替换)
update_log_fashion(Oper,LogId) ->
	NowTime = util:unixtime(),
	?DB_MODULE:update(log_fashion,	 [{is_oper, Oper},{operct, NowTime}], [{id, LogId}]).

%%查询时装对应的各属性值 
get_fashion_random(GoodsTypeId) ->
	?DB_MODULE:select_row(base_goods_fashion, "*", [{goods_id, GoodsTypeId}], [], [1]).

%%查询时装对应的各属性值 
get_fashion_max_att(GoodsTypeId) ->
	Res = ?DB_MODULE:select_one(base_goods_fashion, "max_attack", [{goods_id, GoodsTypeId}], [], [1]),
	if Res ==  null ->
		   40;
	   true ->
		   Res
	end.

%%初始化装备附魔基础数据表
get_base_magic() ->
	?DB_MODULE:select_all(base_magic, "*", [{id,">",0}]).

%%查询上一次的附魔属性(取一条并从第二条开始)
get_last_magic_prop(Player_Id, Gid) ->
	List = ?DB_MODULE:select_all(log_magic, "id, prop", [{id,">",0},{backct,0},{player_id,Player_Id},{gid,Gid}],[{id,desc}],[1,1]),
	if List == [] ->
		   [];
	   true ->
		   lists:nth(1, List)
	end.

%%查询装备附魔未替换的属性 
get_equip_unreplace(PlayerId, Gid) ->
	?DB_MODULE:select_row(log_magic, "id, prop, is_bind", [{player_id, PlayerId},{gid, Gid},{is_oper, 1}], [], [1]).

%%装备附魔日志
log_magic([Player_Id,GoodsId,GoodsType,MagicId,Old_prop,Goods_attributList,Is_Bind,Cost,Is_Oper]) ->
     NowTime = util:unixtime(),
	?DB_MODULE:insert(log_magic,[player_id, gid, g_type, magid, old_prop, prop, is_bind, cost,is_oper, magct, backct],
											[Player_Id,GoodsId,GoodsType,MagicId,Old_prop,Goods_attributList,Is_Bind,Cost,Is_Oper,NowTime,0]).

%%时装日志更新替换或维持原属性,更新操作类型(0持维原属性，1未替换，2已经替换)
update_log_magic(Oper,LogId) ->
	NowTime = util:unixtime(),
	?DB_MODULE:update(log_magic, [{is_oper, Oper},{operct, NowTime}], [{id, LogId}]).

%%更新装备附魔日志
update_log_magic([Id,MagicId,Goods_attributList]) ->
     NowTime = util:unixtime(),
	 ?DB_MODULE:update(log_magic, [{prop, Goods_attributList},{magid,MagicId},{backct, NowTime}], [{id,">", Id}]).

%% 获取商店信息
get_shop_info() ->
	?DB_MODULE:select_all(shop, "*", [{goods_id,">",0}]).


%% 获取在线玩家背包物品表
%% 玩家登陆成功后获取
get_online_player_goods_by_id(PlayerId) ->
	?DB_MODULE:select_all(goods, "*", [{player_id, PlayerId}]).

%%取离线玩家物品列表信息
get_offline_goods(PlayerId,Location) ->
	?DB_MODULE:select_all(goods, "*", [{player_id, PlayerId},{location, Location}]).

%% 获取在线玩家物品属性表
%% 玩家登陆成功后获取
get_online_player_goods_attribute_by_id(PlayerId) ->
	?DB_MODULE:select_all(goods_attribute, "*", [{player_id, PlayerId}]).

%%玩家登陆成功后获取
get_online_player_goods_buff_by_id(PlayerId) ->
	?DB_MODULE:select_all(goods_buff,"id,goods_id,expire_time,data",[{player_id,PlayerId}]).

%%玩家登陆成功后获取
get_online_player_goods_cd_by_id(PlayerId) ->
	?DB_MODULE:select_all(goods_cd,"*",[{player_id,PlayerId}]).

%%获取玩家的副法宝数据
get_online_player_deputy_equip(PlayerId) ->
	?DB_MODULE:select_all(deputy_equip,"*",[{pid,PlayerId}]).

%% 获取新加入的装备
%% 新装备插入数据库后再查询获取
get_add_goods(PlayerId, GoodsTypeId, Location, Cell, Num) ->
	?DB_MODULE:select_row(goods, "*",
								 [{player_id, PlayerId},
								  {goods_id, GoodsTypeId},
								  {location, Location},
								  {cell, Cell},
								  {num, Num}],
								  [{id, desc}],
								  [1]).

%% 获取新加入的装备
%% 新装备插入数据库后再查询获取
get_add_goods_id(PlayerId, GoodsTypeId, Location, Cell, Num) ->
	Ret  = ?DB_MODULE:select_one(goods, "id",
								 [{player_id, PlayerId},
								  {goods_id, GoodsTypeId},
								  {location, Location},
								  {cell, Cell},
								  {num, Num}],
								  [{id, desc}],
								  [1]),
	case Ret of
		null -> [];
		_ -> [Ret]
	end.

%% 获取新加入的装备属性
%% 装备属性有更改后查询
get_add_goods_attribute(PlayerId, GoodsId, AttributeType, AttributeId) ->
	?DB_MODULE:select_row(goods_attribute, "*",
								 [{player_id, PlayerId},
								  {gid, GoodsId},
								  {attribute_type, AttributeType},
								  {attribute_id, AttributeId}],
								 [],
								 [1]).

%% 获取物品ID的信息
%% 对要判断物品是否存在时查询
get_goods_by_id(GoodsId) ->
	?DB_MODULE:select_row(goods, "*",
								 [{id, GoodsId}],
								 [],
								 [1]).
%% 获取物品ID的信息(交易时批量查询)
get_goods_by_ids(GoodsIdList) ->
	?DB_MODULE:select_all(goods, "*", [{id, "in", GoodsIdList}]).

%% 取物品列表
gu_get_goods_list(Table, PlayerId) ->
	gu_get_list(Table, "*",
				[{player_id, PlayerId},
				 {location, 5}]
				 ).

%% 获取同类物品列表
gu_get_type_goods_list(Table, PlayerId, GoodsTypeId, Bind) ->
	gu_get_list(Table, "*",
				[{player_id, PlayerId},
				 {goods_id, GoodsTypeId},
				 {bind, Bind},
				 {location, 5}]
				).

%% 获取同类物品列表
gu_get_type_goods_list(Table, PlayerId, GoodsTypeId) ->
	gu_get_list(Table, "*",
				[{player_id, PlayerId},
				 {goods_id, GoodsTypeId},
				 {location, 5}]
				).


%% 获取仓库物品数量
gu_get_count_store_goods_list(PlayerId) ->
	?DB_MODULE:select_count(goods,[{player_id, PlayerId}, {location, 5}]).


%% 获取物品属性表
gu_get_offline_goods_attribute_list(Table, PlayerId, GoodsId) ->
	gu_get_list(Table, "*",
				[{player_id, PlayerId},
				 {gid, GoodsId}]
				).

%% 获取类型物品属性表
gu_get_offline_goods_attribute_list(Table,PlayerId,GoodsId,AttType) ->
	gu_get_list(Table,"*",
				[{player_id,PlayerId},
				 {gid, GoodsId},
				 {attribute_type,AttType}]
				).

%% 获取物品属性表
get_goods_attribute_list_by_gid(GoodsId) ->
	gu_get_list(goods_attribute, "*",
				[{gid, GoodsId}]).

%% 取多条记录
gu_get_list(Table, Fields, Wheres) ->
    List = (catch ?DB_MODULE:select_all(Table, Fields, Wheres)),
    case is_list(List) of
        true ->
            lists:map(
			  		fun(GoodsInfo) ->
						case Table of
							goods -> list_to_tuple([goods] ++ GoodsInfo);
							goods_attribute -> list_to_tuple([goods_attribute] ++ GoodsInfo)
						end
					end,
					List);
        false ->
            []
    end.

%%%%% end

%%%%% begin lib_goods

%% 添加新物品信息
add_goods(GoodsInfo) ->
	Now = util:unixtime(),
    ValueList = lists:nthtail(2, tuple_to_list(GoodsInfo#goods{ct = Now,other_data = ""})),
    [id | FieldList] = record_info(fields, goods),
	Ret = ?DB_MODULE:insert(goods, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
    		Ret;
		_ ->
			{mongo, Ret}
	end.

%% 更新物品信息
update_goods(ValueList,WhereList) ->
	?DB_MODULE:update(goods, ValueList, WhereList).

%% 添加装备属性1
add_goods_attribute(GoodsInfo, AttributeType,ValueType, AttributeId, Hp, Mp, MaxAtt,MinAtt, Def, Hit, Dodge, Crit,Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil) ->
	Goods_attribute = #goods_attribute{
      		player_id = GoodsInfo#goods.player_id,
      		gid = GoodsInfo#goods.id,
      		attribute_type = AttributeType,
      		attribute_id = AttributeId,
			value_type = ValueType,
      		hp = Hp,
      		mp = Mp,
      		max_attack = MaxAtt,
			min_attack = MinAtt,
      		def = Def,
      		hit = Hit,
      		dodge = Dodge,
      		crit = Crit,
      		anti_wind = Anti_wind,
			anti_fire = Anti_fire,
			anti_water = Anti_water,
			anti_thunder = Anti_thunder,
			anti_soil = Anti_soil
			},
    ValueList = lists:nthtail(2, tuple_to_list(Goods_attribute)),
    [id | FieldList] = record_info(fields, goods_attribute),
	Ret = ?DB_MODULE:insert(goods_attribute, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
    		Ret;
		_ ->
			{mongo,Goods_attribute, Ret}
	end.

%% 添加装备属性2 主要添加装备的附加属性
add_goods_attribute(GoodsInfo,AttributeType,ValueType,AttributeId,Status,Hp,Mp,Forza,Agile,Wit,Physique,Crit,Dodge,Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil,Attack,Anti_rift) ->
	Goods_attribute = #goods_attribute{
      		player_id = GoodsInfo#goods.player_id,
      		gid = GoodsInfo#goods.id,
      		attribute_type = AttributeType,
      		attribute_id = AttributeId,
			value_type = ValueType,
			hp = Hp,
			mp = Mp,
			max_attack = Attack,
			min_attack = Attack,
      		forza = Forza,
			agile = Agile,
			wit = Wit,
			physique = Physique,
			crit = Crit,
			dodge = Dodge,
			anti_wind = Anti_wind,
			anti_fire = Anti_fire,
			anti_water = Anti_water,
			anti_thunder = Anti_thunder, 
			anti_soil = Anti_soil,
			anti_rift = Anti_rift,
			status =Status								  
			},
    ValueList = lists:nthtail(2, tuple_to_list(Goods_attribute)),
    [id | FieldList] = record_info(fields, goods_attribute),
	Ret = ?DB_MODULE:insert(goods_attribute, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
    		Ret;
		_ ->
			{mongo, Goods_attribute,Ret}
	end.

%% 添加装备属性3 主要是装备的宝石镶嵌
add_goods_attribute(GoodsInfo,AttributeType,ValueType,AttributeId,Goods_id,Hp, Mp, MaxAtt,MinAtt, Def, Hit, Dodge, Crit,Physique, Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil,Forza,Agile,Wit) ->
	Goods_attribute = #goods_attribute{
      		player_id = GoodsInfo#goods.player_id,
      		gid = GoodsInfo#goods.id,
			goods_id = Goods_id,
      		attribute_type = AttributeType,
      		attribute_id = AttributeId,
			value_type = ValueType,
      		hp = Hp,
      		mp = Mp,
      		max_attack = MaxAtt,
			min_attack = MinAtt,
      		def = Def,
      		hit = Hit,
      		dodge = Dodge,
      		crit = Crit,
			physique =Physique,
      		anti_wind = Anti_wind,
			anti_fire = Anti_fire,
			anti_water = Anti_water,
			anti_thunder = Anti_thunder,
			anti_soil = Anti_soil,
			forza =Forza,
			agile =Agile,
			wit =Wit
			}, 
    ValueList = lists:nthtail(2, tuple_to_list(Goods_attribute)),
    [id | FieldList] = record_info(fields, goods_attribute),
	Ret = ?DB_MODULE:insert(goods_attribute, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
    		Ret;
		_ ->
			{mongo,Goods_attribute,Ret}
	end.

%% 修改装备属性
mod_goods_attribute(AttributeInfo, Hp, Mp, MaxAtt,MinAtt, Def, Hit, Dodge, Crit, Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil) ->
	?DB_MODULE:update(goods_attribute,
								 [{hp, Hp},
								  {mp, Mp},
								  {max_attack, MaxAtt},
								  {min_attack,MinAtt},
								  {def, Def},
								  {hit, Hit},
								  {dodge, Dodge},
								  {crit, Crit},
								  {anti_wind, Anti_wind},
								  {anti_fire,Anti_fire},
								  {anti_water,Anti_water},
								  {anti_thunder,Anti_thunder},
								  {anti_soil,Anti_soil}
								 ],
								 [{id, AttributeInfo#goods_attribute.id}]).

%% 修改装备属性的[name,Value]方式
mod_goods_attribute(AttributeInfo) ->
	?DB_MODULE:update(goods_attribute,
								 [{dodge,AttributeInfo#goods_attribute.dodge},
								  {crit,AttributeInfo#goods_attribute.crit},
								  {physique,AttributeInfo#goods_attribute.physique},
								  {forza,AttributeInfo#goods_attribute.forza},
								  {agile,AttributeInfo#goods_attribute.agile},
								  {wit,AttributeInfo#goods_attribute.wit}
								  ],
								 [{id,AttributeInfo#goods_attribute.id}]).
%% 删除装备属性
del_goods_attribute(PlayerId, GoodsId, AttributeType) ->
	?DB_MODULE:delete(goods_attribute,
								 [{player_id, PlayerId},
								  {gid, GoodsId},
								  {attribute_type, AttributeType}
								 ]).

del_goods_attribute(Player_Id,Gid) ->
	?DB_MODULE:delete(goods_attribute,
								 [{player_id, Player_Id},
								  {gid, Gid}
								 ]).

del_goods_attribute(_PlayerId,GoodsId,AttributeType,AttributeId)->
	?DB_MODULE:delete(goods_attribute,
								[
								 {gid,GoodsId},
								 {attribute_type,AttributeType},
								 {attribute_id,AttributeId}
								 ]
								).

%% 删除装备属性
del_goods_attribute(Id) ->
	?DB_MODULE:delete(goods_attribute,
								 [{id, Id}]).


%% 更新玩家Money, Type为add,sub
update_player_coin(Player, Coin, Type) ->
	case Type of 
		add ->%%增加铜币
			?DB_MODULE:update(player, [{coin, Coin, add},{coin_sum, Coin, add}], [{id, Player#player.id}]);
		_ ->%%减少铜币
			KeyValueList = 
			case Player#player.bcoin < Coin of
				false -> [{bcoin, Coin, sub},{coin_sum, Coin, sub}];
				true ->  [{bcoin, 0},{coin, (Player#player.bcoin + Player#player.coin - Coin)},{coin_sum, Coin, sub}]
			end,
			?DB_MODULE:update(player, KeyValueList, [{id, Player#player.id}])
	end.

%% 扩展背包
extend_bag(CellNum, PlayerId) ->
	?DB_MODULE:update(player,
								 [{cell_num, CellNum}],
								 [{id, PlayerId}]).

%% 扩展仓库
extend_store(StoreNum, PlayerId) ->
	?DB_MODULE:update(player,
								 [{store_num, StoreNum}],
								 [{id, PlayerId}]).

%% 切换装备
change_equip(Equip, PlayerId) ->
	?DB_MODULE:update(player,
								 [{equip, Equip}],
								 [{id, PlayerId}]).


%% 更改物品格子位置
change_goods_cell(Location, Cell, Gid) ->
	?DB_MODULE:update(goods,
								 [{location, Location}, {cell, Cell}],
								 [{id, Gid}]).

%% 更改物品数量
change_goods_num(Gid, Num) ->
	?DB_MODULE:update(goods,
								 [{num, Num}],
								 [{id, Gid}]).

%% 更改物品格子位置和数量
change_goods_cell_and_num(GoodsInfo, Location, Cell, Num) ->
	?DB_MODULE:update(goods,
								 [{location, Location}, {cell, Cell}, {num, Num}],
								 [{id, GoodsInfo#goods.id}]).

%% 更改物品耐久度
change_goods_use(GoodsInfo, UseNum) ->
	?DB_MODULE:update(goods,
								 [{use_num, UseNum}],
								 [{id, GoodsInfo#goods.id}]).

%% 删除物品
delete_goods(GoodsId) ->
	?DB_MODULE:delete(goods, [{id, GoodsId}]),
	?DB_MODULE:delete(goods_attribute, [{gid, GoodsId}]).

%%删除诛邪仓库的全部物品的相关属性
delete_all_box_goods(PlayerId) ->
	?DB_MODULE:delete(goods, 
					  [{player_id, PlayerId}, 
					   {location, 7}]).

delete_all_box_goods_attribute(GoodsId) ->
	?DB_MODULE:delete(goods_attribute,
					  [{gid, GoodsId}]).

%% 返回荣誉值
query_player_honor(PlayerId) ->
	Ret = ?DB_MODULE:select_one(player,"honor",[{id,PlayerId}],[],[1]),
	case Ret of
		null -> [0];
		_ ->[Ret]
	end.

%%返回[score]
query_player_score(PlayerId) ->
	Ret = ?DB_MODULE:select_one(player,"arena_score",[{id,PlayerId}],[],[1]),
	case Ret of
		null ->[0];
		_ -> [Ret]
	end.

%%扣除竞技场积分
cost_score(PlayerStatus,Cost,Type,PointId) ->
	Cost1 = abs(Cost),
	case PlayerStatus#player.arena_score > Cost1 of		
		true -> ?DB_MODULE:update(player, [{arena_score,Cost1,sub}], [{id,PlayerStatus#player.id}]),
				spawn(fun()-> consume_log(PointId,PlayerStatus#player.id,Type,PlayerStatus#player.arena_score,Cost1,0) end);
		false -> ?DB_MODULE:update(player, [{arena_score,0}], [{id,PlayerStatus#player.id}])
	end.
  
%%返回[gold,cash]
query_player_money(PlayerId) ->
    Ret = ?DB_MODULE:select_row(player, "gold, cash", [{id, PlayerId}], [], [1]),
	case Ret of 
		[] ->[0,0];
		_ -> Ret
	end.

%%返回[coin,bcoin]
query_player_coin(PlayerId) ->
	Ret = ?DB_MODULE:select_row(player, "coin, bcoin", [{id, PlayerId}], [], [1]),
	case Ret of 
		[] ->[0,0];
		_ -> Ret
	end.

%%返回[shop_score]
query_player_shop_score(PlayerId) ->
	Ret = ?DB_MODULE:select_row(player, "shop_score", [{id, PlayerId}], [], [1]),
	case Ret of 
		[] ->[0];
		_ -> Ret
	end.

%%模拟充值测试专用
insert_pay_log(Num, User, PlayerId, NickName, 
									Lv, RegTime, FirstPay, Money, Gold, PayTime, InTime, 1, Sn) ->
	?DB_MODULE:insert(?LOG_POOLID,log_pay,[pay_num, pay_user, player_id, nickname, lv, reg_time, first_pay, 
										   money, pay_gold, pay_time, insert_time, pay_status, sn],
				  						[Num, User, PlayerId, NickName, 
										 		Lv, RegTime, FirstPay, Money, Gold, PayTime, InTime, 1, Sn]).
	

%% 扣除角色金钱
cost_money(PlayerStatus, Cost, Type, PointId) ->
	Cost1 = abs(Cost),
	Old_Num = 
		case Type of
			coin -> PlayerStatus#player.coin+PlayerStatus#player.bcoin;
			coinonly -> PlayerStatus#player.coin;
			cash -> PlayerStatus#player.cash;
			gold -> PlayerStatus#player.gold;
			bcoin -> PlayerStatus#player.bcoin;
			shop_score -> PlayerStatus#player.other#player_other.shop_score
		end,
	KeyValueList = 
	case Type of
		coin -> case PlayerStatus#player.bcoin < Cost1 of
                    false -> [{bcoin, Cost1, sub},{coin_sum, Cost1, sub}];
                    true ->  [{bcoin, 0},{coin, (PlayerStatus#player.bcoin + PlayerStatus#player.coin - Cost1)},{coin_sum, Cost1, sub}]
                end;
		coinonly -> [{coin, Cost1, sub},{coin_sum, Cost1, sub}];
		cash -> [{cash, Cost1, sub}];
		gold -> [{gold, Cost1, sub}];
		bcoin -> [{bcoin, Cost1, sub},{coin_sum, Cost1, sub}];
		shop_score -> [{sub_score,Cost1,add}] %%增加 "消耗积分"
	end,
	case Type of
		shop_score ->
			spawn(fun()-> consume_log(PointId,PlayerStatus#player.id,Type,Old_Num,Cost1,0) end),
			case get_sub_score(PlayerStatus#player.id) of
				[] ->
					?DB_MODULE:insert(sub_score,[player_id,sub_score],[PlayerStatus#player.id,Cost1]);
				[_Other] ->
					?DB_MODULE:update(sub_score, KeyValueList, [{player_id,PlayerStatus#player.id}])
			end;
		_ ->
			spawn(fun()-> consume_log(PointId,PlayerStatus#player.id,Type,Old_Num,Cost1,0) end),
			?DB_MODULE:update(player, KeyValueList, [{id,PlayerStatus#player.id}])
	end.	

%% 添加角色金钱
add_money(PlayerStatus, Sum ,Type, PointId) ->
	Sum1 = abs(Sum),
	Old_Num = 
		case Type of
			coin -> PlayerStatus#player.coin;
			coinonly -> PlayerStatus#player.coin;
			cash -> PlayerStatus#player.cash;
			gold -> PlayerStatus#player.gold;
			bcoin -> PlayerStatus#player.bcoin
		end,
	KeyValueList =
		case Type of
			coin -> [{coin, Sum1, add},{coin_sum, Sum1, add}];
			coinonly -> [{coin, Sum1, add},{coin_sum, Sum1, add}];
			bcoin ->[{bcoin, Sum1, add},{coin_sum, Sum1, add}];
			gold ->[{gold, Sum1, add}];
			cash ->[{cash, Sum1, add}];
			shop_score -> [{shop_score, Sum1, add}]
		end,
	spawn(fun()-> consume_log(PointId,PlayerStatus#player.id,Type,Old_Num,Sum1,1) end),
	?DB_MODULE:update(player,KeyValueList,[{id,PlayerStatus#player.id}]).

%% 物品绑定
bind_goods(GoodsInfo) ->
	?DB_MODULE:update(goods,
								 [{bind, 2}, {trade, 1}, {cell, GoodsInfo#goods.cell}],
								 [{id, GoodsInfo#goods.id}]).


%%当玩家删除角色时，删除有关于这角色的数据
lg_delete_role(PlayerId) ->
	?DB_MODULE:delete(goods_attribute,	 [{player_id, PlayerId}]),
	?DB_MODULE:delete(goods, [{player_id, PlayerId}]),
	?DB_MODULE:delete(goods_buff,	[{player_id, PlayerId}]),
	?DB_MODULE:delete(goods_cd, [{player_id, PlayerId}]).

%% 保存物品信息
set_goods_info(GoodsId, Field, Data) ->
	?DB_MODULE:update(goods, Field, Data, "id", GoodsId).

%%添加物品buff
add_goods_buff(PlayerId,Goods_Id,ExpireTime,Data)->
	Goods_buff = #goods_buff{
							 player_id = PlayerId,
							 goods_id = Goods_Id,
							 expire_time = ExpireTime, 
							 data = Data
							 },
    ValueList = lists:nthtail(2, tuple_to_list(Goods_buff)),
    [id | FieldList] = record_info(fields, goods_buff),
	Ret = ?DB_MODULE:insert(goods_buff, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
    		Ret;
		_ ->
			{mongo, Ret}
	end.

%%更新物品buff
update_goods_buff(PlayerId,Goods_Id,ExpireTime,Data) ->
	?DB_MODULE:update(goods_buff,
					  [{expire_time,ExpireTime},{data,Data}],
					  [{player_id,PlayerId},{goods_id,Goods_Id}]).

update_gbuff_time(NewExpirT, Id) ->
		?DB_MODULE:update(goods_buff,
						  [{expire_time, NewExpirT}],
						  [{id,Id}]).

%%更新goods_buff的部分数据
update_good_buff_info(ValueList, WhereList) ->
	?DB_MODULE:update(goods_buff, ValueList, WhereList).

%%获取物品buff
get_new_goods_buff(PlayerId,Goods_Id)->
	?DB_MODULE:select_row(goods_buff,"*",[{player_id,PlayerId},{goods_id,Goods_Id}]).

%%删除物品buff
del_goods_buff(PlayerId,Goods_Id) ->
	GoodsList = lib_goods:get_buff_goods_ids(Goods_Id),
	?DB_MODULE:delete(goods_buff,[{player_id,PlayerId},{goods_id, "in", GoodsList}]).
%%修改兼容的buff数据
change_buffid_compatibility(PlayerId, GoodsTypeId, BuffGid) ->
	?DB_MODULE:update(goods_buff, 
					  [{goods_id, BuffGid}], 
					  [{player_id,PlayerId},
					   {goods_id, GoodsTypeId}]).

del_goods_buff(Id) ->
	?DB_MODULE:delete(goods_buff,[{id,Id}]).

%%添加物品cd
add_new_goods_cd(PlayerId, Goods_Id, ExpireTime) ->
	Ets_goods_cd = #ets_goods_cd{
							 player_id = PlayerId,
							 goods_id = Goods_Id,
							 expire_time = ExpireTime
							 },
    ValueList = lists:nthtail(2, tuple_to_list(Ets_goods_cd)),
    [id | FieldList] = record_info(fields, ets_goods_cd),
	Ret = ?DB_MODULE:insert(goods_cd, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
    		Ret;
		_ ->
			{mongo, Ret}
	end.

%%获取物品cd
get_new_goods_cd(PlayerId,Goods_Id) ->
	?DB_MODULE:select_row(goods_cd,"*",[{player_id,PlayerId},{goods_id,Goods_Id}]).

%%删除物品cd
del_goods_cd(PlayerId,Goods_Id) ->
	?DB_MODULE:delete(goods_cd,[{player_id,PlayerId},{goods_id,Goods_Id}]).

del_goods_cd(Id) ->
	?DB_MODULE:delete(goods_cd,[{id,Id}]).

%%坐骑状态改变
change_mount_status(GoodsId,PlayerId) ->
	?DB_MODULE:update(player,
							[{mount, GoodsId}],
							[{id, PlayerId}]
					).

%%修改物品other_data信息
mod_goods_otherdata(GoodsId,Data) ->
	?DB_MODULE:update(goods,
					  		[{other_data,Data}],
					  		[{id,GoodsId}]
					  ).

%%修改物品评价
mod_goods_score(GoodsId,Score) ->
	?DB_MODULE:update(goods,
					  		[{score,Score}],
					  		[{id,GoodsId}]
					  ).
%%检查是否已经使用
check_ygfs_card_used(CardKey,Player_id) ->
	?DB_MODULE:select_row(cards,"*",[{player_id,Player_id}, {key,CardKey}]).

%%查找所有已经领过的礼包
get_all_given(Player_id) ->
	?DB_MODULE:select_all(cards,"*",[{player_id,Player_id}]).

%%查找首充礼包邮件记录
get_firstpay_gift_record(PlayerId) ->
	?DB_MODULE:select_all(log_mail,"*",[{uid,PlayerId}, {goods_id,28120}]).

%%查找VIP礼包邮件记录
get_vip_gift_record(PlayerId) ->
	?DB_MODULE:select_all(log_mail,"*",[{uid,PlayerId}, {goods_id,28185}]).

check_ygfs_card(Cardstring) ->
	?DB_MODULE:select_row(cards,"*",[{cardstring,Cardstring}],[],[1]).

%%激活卡类
active_ygfs_card(CardId,Player_id) ->
	Time = util:unixtime(),
	?DB_MODULE:update(cards,
					  		[{active,Time},{player_id,Player_id}],
					  		[{id,CardId}]
					  ).
%%生成卡号使用记录
active_use_ygfs_card(CardString,Player_id,Key) ->
	Time = util:unixtime(),
	?DB_MODULE:insert(cards,[cardstring,active,player_id,key],[CardString,Time,Player_id,Key]).

%%删除卡号使用记录(key =1，2，3，4)即1新手卡 2皇室特权卡 3贵族特权卡 4公民特权卡，内部使用
delete_card_used(PlayerId) ->
  ?DB_MODULE:delete(cards,[{player_id,PlayerId},{key,"in",[1,2,3,4]}]).
%%%%% end

%%%%% begin lib_guild_inner

%% 加载所有氏族信息
load_all_guild() ->
	?DB_MODULE:select_all(guild, "*", [{id,">",0}]).

%% 加载所有氏族信息
guildbat_rank_guild() ->
	?DB_MODULE:select_all(guild, 
								 "id, name, level, combat_all_num, combat_week_num", 
								 [{id,">",0}],
						  		 [{level, desc}, {combat_all_num, desc}, {id, asc}],
								 [100]
								).
%%----------------------------------------
%%加载所有的氏族日志
%%----------------------------------------
load_all_guild_log() ->
 	TimeNow = util:unixtime(),
 	TimeLast = TimeNow - 86400,
 	?DB_MODULE:select_all(log_guild, "*", [{time, ">", TimeLast}]).

delete_guild_logs(Time) ->
	?DB_MODULE:delete(log_guild,[{time, "<", Time}]).

%% 更新氏族信息
update_guild_table(ValueList, GuildId) ->
	?DB_MODULE:update(guild, ValueList, [{id, GuildId}]).

%% 查询视图格式 [{tab1,[f1,f2]},{tab2,[f3,f4]},{tab3,[f5,f6,f7]}],[{tab1,[id,1]},{tab1,[age,30]}]，[{tab1.f1,tab2.f2},{tab2.f3,tab3.f5}]
%% 加载所有氏族成员
load_all_guild_member(GuildId) ->
	case ?DB_MODULE =:= db_mysql of
		true ->
			?DB_MODULE:select_all(view_guild_member, "*", [{guild_id, GuildId}]);
		_ ->
			?DB_MODULE:select_all_from_multtable([{guild_member,[id,guild_id,guild_name,player_id,player_name,donate_funds,donate_total,donate_lasttime,donate_total_lastday,donate_total_lastweek,create_time,title,remark,honor,guild_depart_name,guild_depart_id,kill_foe,die_count,get_flags,magic_nut,feats,feats_all,f_uptime,gr,unions,tax_time]},
												 {player,[sex,jobs,lv,guild_position,last_login_time,online_flag,career,culture,vip]}],
												[{guild_member,[guild_id,GuildId]}],[{guild_member.player_id,player.id}],[],[])
	end.


%% 加载所有氏族申请
load_all_guild_apply(GuildId) ->
	case ?DB_MODULE =:= db_mysql of
		true ->
			?DB_MODULE:select_all(view_guild_apply, "*", [{guild_id, GuildId}]);
		_ ->
			?DB_MODULE:select_all_from_multtable([{guild_apply,[id,guild_id,player_id,create_time]},
											 {player,[nickname,sex,jobs,lv,career,online_flag,vip]}],
											[{guild_apply,[guild_id,GuildId]}],[{guild_apply.player_id,player.id}],[],[])
	end.


%% 加载所有氏族邀请
load_all_guild_invite(PlayerId) ->
	?DB_MODULE:select_all(guild_invite, "*", [{player_id, PlayerId}]).

%%加载所有的氏族技能属性表
load_all_guild_skills_attribute() ->
	?DB_MODULE:select_all(guild_skills_attribute, "*", [{guild_id,">",0}]).

%%添加门派
guild_insert(Guild) ->
    ValueList = lists:nthtail(2, tuple_to_list(Guild)),
    [id | FieldList] = record_info(fields, ets_guild),
	Ret = ?DB_MODULE:insert(guild, FieldList, ValueList),
	case ?DB_MODULE  =:= db_mysql of
		true ->
			Ret;
		_ ->
			{mongo, Ret}
	end.

%% 获取刚插入的氏族
guild_select_create(GuileName) ->
   ?DB_MODULE:select_row(guild, "*", [{name, GuileName}]).

guild_select_by_id(GuildId) ->
	?DB_MODULE:select_row(guild, "*", [{id, GuildId}]).

%%--------------------------------------------
%%获取刚添加的氏族日志
%%--------------------------------------------
guild_log_select_create(GuildId, GuildName) ->
	?DB_MODULE:select_row(log_guild,"*", [{guild_id, GuildId}, {guild_name, GuildName}], [{id, desc}], [1]).

%% 添加氏族成员
guild_member_insert(Guild_member) ->
    ValueList = lists:nthtail(2, tuple_to_list(Guild_member)),
    [id | FieldList] = record_info(fields, ets_insert_guild_member),
	Ret = ?DB_MODULE:insert(guild_member, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			Ret;
		_ ->
			{mongo, Ret}
	end.

%%--------------------------------------------
%%添加氏族日志
%%--------------------------------------------
guild_log_insert(Log_guild) ->
    ValueList = lists:nthtail(2, tuple_to_list(Log_guild)),
    [id | FieldList] = record_info(fields, ets_log_guild),
	Ret = ?DB_MODULE:insert(log_guild, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			Ret;
		_ ->
			{mongo, Ret}
	end.

%% 更新角色的氏族信息
guild_player_update_info(ValueList, WhereList) ->
	?DB_MODULE:update(player, ValueList, WhereList).

%% 申请解散氏族
apply_disband_guild(Disband_flag, ConfirmTime, GuildId) ->
	?DB_MODULE:update(guild,
					[{disband_flag, Disband_flag},{disband_confirm_time, ConfirmTime}],
					[{id, GuildId}]).

%% 删除氏族表
guild_delete(GuildId) ->
	?DB_MODULE:delete(guild, [{id, GuildId}]).

%%删除解散的氏族所有日志
delete_log_guild(GuildId) ->
	?DB_MODULE:delete(log_guild, [{guild_id, GuildId}]).

%%--------------------------------------------
%%删除氏族时，
%%需要同时删除相关的所有氏族日志
%%parameter:int() GuildId	氏族ID
%%--------------------------------------------
guild_log_delete(GuildId) ->
	?DB_MODULE:delete(log_guild, [{guild_id, GuildId}]).

%% 删除氏族成员表
guild_member_delete(GuildId) ->
	?DB_MODULE:delete(guild_member, [{guild_id, GuildId}]).

%% 删除氏族申请表
guild_apply_delete(GuildId) ->
	?DB_MODULE:delete(guild_apply, [{guild_id, GuildId}]).

%% 删除氏族邀请表
guild_invite_delete(GuildId) ->
	?DB_MODULE:delete(guild_invite, [{guild_id, GuildId}]).

%% 添加氏族加入申请时删除所有的其他氏族申请
guild_apply_delete_player(PlayerId) ->
	?DB_MODULE:delete(guild_apply, [{player_id, PlayerId}]).

%% 删除氏族申请
remove_guild_apply(PlayerId, GuildId) ->
	?DB_MODULE:delete(guild_apply, [{player_id, PlayerId}, {guild_id, GuildId}]).

%% 插入氏族申请
guild_apply_insert(PlayerId, GuildId, CreateTime) ->
	Guild_apply = #ets_insert_guild_apply{
						guild_id = GuildId,
						player_id = PlayerId,
						create_time = CreateTime
					 },
    ValueList = lists:nthtail(2, tuple_to_list(Guild_apply)),
    [id | FieldList] = record_info(fields, ets_insert_guild_apply),
	Ret = ?DB_MODULE:insert(guild_apply, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			Ret;
		_ ->
			{mongo, Ret}
	end.

%% 获取新的氏族信息
guild_apply_select_new(PlayerId, GuildId) ->
	case ?DB_MODULE =:= db_mysql of
		true -> %%mysql数据库
			?DB_MODULE:select_row(view_guild_apply, "*",
								 [{player_id, PlayerId}, {guild_id, GuildId}]);
		_ -> %%mongo数据库
			?DB_MODULE:	select_row_from_multtable([{guild_apply,[id,guild_id,player_id,create_time]},
											 {player,[nickname,sex,jobs,lv,career]}],
											[{guild_apply,[guild_id,GuildId]},{guild_apply,[player_id, PlayerId]}, {guild_id, GuildId}],[{guild_apply.player_id,player.id}],[],[])
	end.


%% 添加氏族邀请
guild_invite_insert(GuildInviteInit) ->
    ValueList = lists:nthtail(2, tuple_to_list(GuildInviteInit)),
    [id | FieldList] = record_info(fields, ets_guild_invite),
	Ret = ?DB_MODULE:insert(guild_invite, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			Ret;
		_ ->
			{mongo, Ret}
	end.

%%获取氏族堂名
guild_get_depart(GuildId, DepartId, GuildPosition) ->
	?DB_MODULE:select_row(player, "*",
								 [{guild_id, GuildId}, {guild_depart_id, DepartId}, {guild_position, GuildPosition}], [], [1]).

%%设置堂主职位
set_depart_position(GuildMemUpdateList,PlayerUpdateList, PlayerId) ->
	?DB_MODULE:update(player, PlayerUpdateList, [{id, PlayerId}]),
	?DB_MODULE:update(guild_member,GuildMemUpdateList, [{player_id, PlayerId}]).


%% -----------------------------------------------------------------
%% 修改氏族堂堂名
%% -----------------------------------------------------------------
modify_guild_depart_name(GuildId, DepartId, DepartName, DepartsNames) ->
	?DB_MODULE:update(guild,[{depart_names, DepartsNames}], [{id, GuildId}]),
	?DB_MODULE:update(player,[{guild_depart_name, DepartName}], [{guild_depart_id, DepartId},{guild_id, GuildId}]),
	?DB_MODULE:update(guild_member,[{guild_depart_name, DepartName}], [{guild_depart_id, DepartId}, {guild_id, GuildId}]).

%% 获取新的氏族邀请信息
guild_invite_select_new(PlayerId, GuildId) ->
	?DB_MODULE:select_row(guild_invite, "*",
								 [{player_id, PlayerId}, {guild_id, GuildId}]).

%% 删除氏族邀请
guild_invite_delete1(PlayerId, GuildId) ->
	?DB_MODULE:delete(guild_invite, 
								 [{player_id, PlayerId}, {guild_id, GuildId}]).

%% 删除氏族邀请
guild_invite_delete2(PlayerId) ->
	?DB_MODULE:delete(guild_invite, 
								 [{player_id, PlayerId}]).

%% 增加氏族成员数
guild_update_member_num(GuildId) ->
	?DB_MODULE:update(guild, 
								  [{member_num, 1, add}], 
								  [{id, GuildId}]).

%% 获取氏族最新成员数
guild_member_select_new(PlayerId, GuildId) ->
	case ?DB_MODULE =:= db_mysql of
		true -> %%mysql数据库
			?DB_MODULE:select_row(view_guild_member, "*", [{player_id, PlayerId}]);
		_ -> %%mongo数据库
		%%	?DEBUG("PlayerId:~p,GuildId:~p", [PlayerId, GuildId]),
			?DB_MODULE:select_row_from_multtable([{guild_member,[id,guild_id,guild_name,player_id,player_name,donate_funds,donate_total,donate_lasttime,donate_total_lastday,donate_total_lastweek,create_time,title,remark,honor,guild_depart_name,guild_depart_id,kill_foe,die_count,get_flags,magic_nut,feats,feats_all,f_uptime,gr,unions,tax_time]},
											 {player,[sex,jobs,lv,guild_position,last_login_time,online_flag,career,culture,vip]}],
											[{guild_member,[player_id, PlayerId]}, {guild_member,[guild_id, GuildId]}],[{guild_member.player_id,player.id}],[],[])
	end.


%% 更改氏族信息
guild_update_remove_deputy1(GuildId) ->
	?DB_MODULE:update(guild,
					  [{member_num, 1, sub}, 
					   {deputy_chief_num, 1, sub}, 
					   {deputy_chief1_id, 0}, 
					   {deputy_chief1_name, ""}], 
					  [{id, GuildId}]).

%% 更改氏族信息
guild_update_remove_deputy2(GuildId) ->
	?DB_MODULE:update(guild, 
					  [{member_num, 1, sub}, 
					   {deputy_chief_num, 1, sub}, 
					   {deputy_chief2_id, 0}, 
					   {deputy_chief2_name, ""}], 
					  [{id, GuildId}]).

%% 减少氏族成员数
guild_update_member_num_deduct(GuildId) ->
	?DB_MODULE:update(guild, 
					  [{member_num, 1, sub}], 
					  [{id, GuildId}]).

%%获取玩家的氏族中所属的堂ID
get_player_apart_id(PlayerId) ->
	Ret = ?DB_MODULE:select_one(player,  "guild_depart_id", [{id, PlayerId}]),
	case Ret of
		null -> [];
		_ -> [Ret]
	end.

% 删除氏族成员表
guild_member_delete_one(PlayerId, GuildId) ->
	?DB_MODULE:delete(guild_member,
					  [{player_id, PlayerId},
					   {guild_id, GuildId}]).

player_update_guild_position(Position, PlayerId, DepartId) ->
	?DB_MODULE:update(player, 
					  [{guild_position, Position},
					   {guild_depart_name, ""},
					   {guild_depart_id, DepartId}],
					  [{id, PlayerId}]).

update_guild_member_demise_chief(DepartId, PlayerId) ->
	?DB_MODULE:update(guild_member,[{guild_depart_name, ""},
									{guild_depart_id, DepartId}],
					  [{player_id, PlayerId}]).

%% 修改氏族宗旨
guild_update_tenet(GuildId, Tenet) ->
	?DB_MODULE:update(guild, [{tenet, Tenet}], [{id, GuildId}]).

%% 修改氏族公告
guild_update_announce(GuildId, Announce) ->
	?DB_MODULE:update(guild, [{announce, Announce}], [{id, GuildId}]).

%% 更改门派成员的职位
player_update_guild_position_deputy(NewGuildPosition, MemGuildTitle, PlayerId) ->
	?DB_MODULE:update(player,
								 [{guild_position, NewGuildPosition},
								  {guild_title, MemGuildTitle},
								  {guild_depart_id, 5},
								  {guild_depart_name, ""}],
								 [{id, PlayerId}]
								).

player_update_guild_position_depart(MemDepartId, GuildPosition, MemGuildTitle, MemDepartName, MemPlayerId) ->
	?DB_MODULE:update(player, 
								 [{guild_position, GuildPosition},
								  {guild_title, MemGuildTitle},
								  {guild_depart_id, MemDepartId},
								  {guild_depart_name, MemDepartName}],
								 [{id, MemPlayerId}]
								).

player_guild_title_update_only(GuildTitle, PlayerId) ->
	?DB_MODULE:update(player, 
					  [{guild_title, GuildTitle}],
					  [{id, PlayerId}]).

%% 更改氏族职位信息
guild_update_deduct_deputy1(GuildId) ->
	?DB_MODULE:update(guild, 
								  [{deputy_chief_num, 1, sub}, {deputy_chief1_id, 0}, {deputy_chief1_name, ""}], 
								  [{id, GuildId}]).

%% 更改氏族职位信息
guild_update_deduct_deputy2(GuildId) ->
	?DB_MODULE:update(guild, 
								  [{deputy_chief_num, 1, sub}, {deputy_chief2_id, 0}, {deputy_chief2_name, ""}], 
								  [{id, GuildId}]).

%% 副族长数增加
guild_update_add_deputy1(PlayerId, PlayerName, GuildId) ->
	?DB_MODULE:update(guild, 
								  [{deputy_chief_num, 1, add}, {deputy_chief1_id, PlayerId}, {deputy_chief1_name, PlayerName}], 
								  [{id, GuildId}]).

%% 副族长数增加
guild_update_add_deputy2(PlayerId, PlayerName, GuildId) ->
	?DB_MODULE:update(guild, 
								  [{deputy_chief_num, 1, add}, {deputy_chief2_id, PlayerId}, {deputy_chief2_name, PlayerName}], 
								  [{id, GuildId}]).

%% 更改氏族职位信息
guild_update_change_deputy1(PlayerId2, PlayerName2, GuildId) ->
	?DB_MODULE:update(guild, 
								  [{chief_id, PlayerId2}, {chief_name, PlayerName2}, {deputy_chief1_id, 0}, {deputy_chief1_name, ""}, {deputy_chief_num, 1, sub}], 
								  [{id, GuildId}]).

%% 更改氏族职位信息
guild_update_change_deputy2(PlayerId2, PlayerName2, GuildId) ->
	?DB_MODULE:update(guild, 
								  [{chief_id, PlayerId2}, {chief_name, PlayerName2}, {deputy_chief2_id, 0}, {deputy_chief2_name, ""}, {deputy_chief_num, 1, sub}], 
								  [{id, GuildId}]).

guild_update_change_chief(PlayerId2, PlayerName2, GuildId) ->
	?DB_MODULE:update(guild, 
								  [{chief_id, PlayerId2}, {chief_name, PlayerName2}], 
								  [{id, GuildId}]).

update_guild_member_position(GuildTitle, DepartId, DepartName, PlayerId) ->
	?DB_MODULE:update(guild_member, 
					  [{guild_depart_name, DepartName},
					   {guild_depart_id, DepartId},
					   {title, GuildTitle}],
					  [{player_id, PlayerId}]).

guild_member_title_update_only(GuildTitle, PlayerId) ->
	?DB_MODULE:update(guild_member,
					  [{title, GuildTitle}],
					  [{player_id, PlayerId}]).

guild_add_reputation(GuildId, Reputation) ->
	?DB_MODULE:update(guild,
					  [{reputation, Reputation}],
					  [{id, GuildId}]).
%% %%设置新的弟子职位
%% set_child_position(PlayerId, GuildTitle) ->
%% 	?DB_MODULE:update(player, 
%% 								  [{guild_depart_name, ""}, {guild_depart_id, 0}, {guild_title, GuildTitle}], 
%% 								  [{id, PlayerId}]),
%% 	?DB_MODULE:update(guild_member, 
%% 								  [{guild_depart_name, ""}, {guild_depart_id, 0}, {title, GuildTitle}], 
%% 								  [{player_id, PlayerId}]).
%% 
%% set_child_position(PlayerId, GuildMemUpdateList, PlayerUpdateList) ->
%% 	?DB_MODULE:update(player, PlayerUpdateList, {[id, PlayerId]}),
%% 	?DB_MODULE:update(guild_member,GuildMemUpdateList, {[player_id, PlayerId]}).


%% 减少玩家钱币
player_update_deduct_coin(Num, PlayerId) ->
	?DB_MODULE:update(player,
								 [{coin, Num, sub},{coin_sum, Num, sub}],
								 [{id, PlayerId}]
								).

%% 减去玩家金币
player_update_deduct_gold(Money, PlayerId) ->
	?DB_MODULE:update(player, [{gold, Money, sub}], [{id, PlayerId}]).

%% 增加氏族资金
guild_update_add_funds(Num, GuildId) ->
	?DB_MODULE:update(guild,
								 [{funds, Num, add}],
								 [{id, GuildId}]
								).

%% 氏族升级
guild_update_grade(NewMemberCapcity, NewLevel, Contribution, NewContributionDaily, NewContributionThreshold, GuildId) ->
	?DB_MODULE:update(guild,
								 [{member_capacity, NewMemberCapcity}, {level, NewLevel}, 
								  {contribution, Contribution}, {contribution_daily, NewContributionDaily},
								  {contribution_threshold, NewContributionThreshold},{disband_deadline_time, 0} ],
								 [{id, GuildId}]
								).

%%更新氏族等级后的数据信息
update_guild_upgrade(GuildId, NewFunds, NewExp, UpGradeTime) ->
	?DB_MODULE:update(guild, [{funds, NewFunds},
							  {exp, NewExp},
							  {upgrade_last_time, UpGradeTime}], 
					  [{id, GuildId}]).

 %%修改升级时间
update_guild(GuildId, UpGradeLastTimeNew) ->
	?DB_MODULE:update(guild, [{upgrade_last_time, UpGradeLastTimeNew}], [{id, GuildId}]).
	
%% 氏族贡献
guild_update_add_contribution(ContributionAdd, GuildId) ->
	?DB_MODULE:update(guild,
								 [{contribution, ContributionAdd, add}], [{id, GuildId}]).

%% 捐献金钱而更新氏族捐献信息
guild_member_update_money_donate_info(Data) ->
	[DonateFunds, DonateTotal, DonateTime, DonateAddLastWeek, DonateAddLastDay, PlayerId] = Data,
	?DB_MODULE:update(guild_member,
								 [{donate_funds, DonateFunds},
								  {donate_total, DonateTotal},
								  {donate_lasttime, DonateTime},
								  {donate_total_lastweek, DonateAddLastWeek},
								  {donate_total_lastday, DonateAddLastDay}],
								 [{player_id, PlayerId}]
								).

%% 捐献氏族建设卡而更新氏族捐献信息
guild_member_update_donate_info(Data) ->
	[DonateTotal, DonateTime, DonateAddLastWeek, DonateAddLastDay, PlayerId] = Data,
	?DB_MODULE:update(guild_member,
								 [{donate_total, DonateTotal},
								  {donate_lasttime, DonateTime},
								  {donate_total_lastweek, DonateAddLastWeek},
								  {donate_total_lastday, DonateAddLastDay}],
								 [{player_id, PlayerId}]
								).

%% 增加玩家钱币（门派日福利）
player_update_add_coin(Num, PlayerId) ->
	?DB_MODULE:update(player,
								 [{coin, Num, add},{coin_sum, Num, add}],
								 [{id, PlayerId}]
								).

% 更新氏族成员福利信息
guild_member_update_paid(NowTime, PlayerId) ->
	?DB_MODULE:update(guild_member,
								 [{paid_get_lasttime, NowTime}],
								 [{player_id, PlayerId}]
								).

%% 授予头衔
player_member_update_title(Title, PlayerId) ->
	?DB_MODULE:update(guild_member,
								 [{title, Title}],
								 [{player_id, PlayerId}]
								).

%% 修改个人备注
player_member_update_remark(Remark, PlayerId) ->
	?DB_MODULE:update(guild_member,
								 [{remark, Remark}],
								 [{player_id, PlayerId}]
								).

%% 更新处理收取每日氏族消耗
guild_update_init(Data) ->
	[GuildId, ContributionGetNextTime, Funds] = Data,
	?DB_MODULE:update(guild,
								 [
								  {consume_get_nexttime, ContributionGetNextTime},
								  {funds, Funds, sub}
								  ],
								 [{id, GuildId}]
								).

%%帮派改名
change_guildname(GuildId,GuildName) ->
	?DB_MODULE:update(guild, [{name, GuildName}], [{id, GuildId}]).

%%帮派成员表帮派改名
change_guild_membername(GuildId,GuildName) ->
	?DB_MODULE:update(guild_member, [{guild_name, GuildName}], [{guild_id, GuildId}]).

%%角色表帮派改名
change_player_guildname(GuildId,GuildName) ->
	?DB_MODULE:update(player, [{guild_name, GuildName}], [{guild_id, GuildId}]).

%%更新封神台霸主对应的帮派名
change_fst_guildname(PlayerId,GuildName) ->
	?DB_MODULE:update(fst_god, [{g_name, GuildName}], [{uid, PlayerId}]).

%%更新诛仙台霸主对应的帮派名
change_zxt_guildname(PlayerId,GuildName) ->
	?DB_MODULE:update(zxt_god, [{g_name, GuildName}], [{uid, PlayerId}]).


%%更新镇妖塔霸主对应的帮派名
change_td_single_guildname(PlayerId,GuildName) ->
	?DB_MODULE:update(td_single, [{g_name, GuildName}], [{uid, PlayerId}]).

%% 获取角色的氏族信息
get_player_guild_info(PlayerId) ->
	?DB_MODULE:select_row(player, "nickname, realm, guild_id, guild_name, guild_position, lv,quit_guild_time, sex, jobs, last_login_time, online_flag, career, culture, guild_depart_id, vip", 
								 [{id, PlayerId}]
								).

%% 获取角色的氏族信息
get_player_guild_info_by_name(PlayerNickName) ->
	?DB_MODULE:select_row(player, "id, realm, guild_id, guild_name, guild_position, lv,quit_guild_time, sex, jobs, last_login_time, online_flag, career, culture, guild_depart_id", 
								 [{nickname, PlayerNickName}]
								).

%升级氏族指定技能属性等级
guild_skills_level_upgrade(GuildId, SkillId, SkillLevelNew) ->
	?DB_MODULE:update(guild_skills_attribute, 
								 [{skill_level, SkillLevelNew}],
								 [{guild_id, GuildId}, {skill_id, SkillId}]).

%%玩家实用技能令，增加所在氏族的技能令数
add_guild_reputatioin(ValueList, FieldList) ->
		?DB_MODULE:update(guild, ValueList, FieldList).

%%更新因为技能等级变化而引起的氏族信息变化
update_guild_by_skills(ValueList, WhereList) ->
	?DB_MODULE:update(guild, ValueList, WhereList).

%%初始化氏族技能
init_guild_skill_attribute(Guild_skills_attribute) ->
    ValueList = lists:nthtail(2, tuple_to_list(Guild_skills_attribute)),
    [id | FieldList] = record_info(fields, ets_guild_skills_attribute),
	Ret = ?DB_MODULE:insert(guild_skills_attribute, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			Ret;
		_ ->
			{mongo, Ret}
	end.

%%获取氏族指定的技能信息
get_guild_skill_attribute(GuildId, SkillId) ->
	?DB_MODULE:select_row(guild_skills_attribute, "*", [{guild_id, GuildId}, {skill_id, SkillId}]).

%%删除氏族技能信息表
delete_guild_skills(GuildId) ->
	?DB_MODULE:delete(guild_skills_attribute, [{guild_id, GuildId}]).

%%添加氏族经验
increase_guild_exp(GuildId, Exp, AddFunds) ->
	?DB_MODULE:update(guild, 
					  [{exp, Exp, add},
					   {funds, AddFunds, add}],
					  [{id, GuildId}]
					  ).

change_guild_playername(GuildId,NickName,Pos) ->
	if 
		Pos == 1 ->
			?DB_MODULE:update(guild, [{chief_name, NickName}],[{id, GuildId}]);
		Pos == 2 ->
			?DB_MODULE:update(guild, [{deputy_chief1_name, NickName}],[{id, GuildId}]);
		Pos == 2 ->
			?DB_MODULE:update(guild, [{deputy_chief2_name, NickName}],[{id, GuildId}]);
	true ->
			 skip
	end.

change_guild_member_playername(PlayerId,GuildId,NickName) ->
	?DB_MODULE:update(guild_member, [{player_name, NickName}],[{guild_id, GuildId},{player_id,PlayerId}]).

%%gm命令改等级
gm_update_guild_level(GuildId, NewNum) ->
	?DB_MODULE:update(guild, [{level, NewNum}], [{id, GuildId}]).

%%GM修改guild数据
gm_guild_base(ValueList, FieldList) ->
	?DB_MODULE:update(guild, ValueList, FieldList).

%%更新氏族刷boss的时间
update_guild_lct_boss(ValueList, FieldList) ->
	?DB_MODULE:update(guild, ValueList, FieldList).

%%氏族怪物死亡
update_kill_guild_boss(ValueList, FieldList) ->
	?DB_MODULE:update(guild,  ValueList, FieldList).

%%从怪物掉落表查询boss死亡时间
query_boss_time(BossId) ->
	?DB_MODULE:select_row(?LOG_POOLID,mon_drop_analytics,"drop_time", [{mon_id, BossId}], [{drop_time, desc}], [1]).

%%氏族运镖信息
update_guild_carry_info(ValueList, FieldList)->
	?DB_MODULE:update(guild,  ValueList, FieldList).

%%神岛空战报名修改
apply_skyrush(Table, ValueList, FieldList) ->
	?DB_MODULE:update(Table, ValueList, FieldList).

%%直接从数据库里导出报名氏族战的数据
get_apply_skyrush_guilds(WhereList) ->
	Data = ?DB_MODULE:select_all(guild, "*", WhereList),
	lists:map(fun(Elem) ->
					  list_to_tuple([ets_guild] ++ Elem)
			  end, Data).				  

%%报名日志
make_guild_apply_log(FieldList, ValueList) ->
	?DB_MODULE:insert(log_sky_apply, FieldList, ValueList).

get_guild_apply_log(GuildId) ->
	?DB_MODULE:select_row(log_sky_apply, "*", [{gd, GuildId}], [{id, desc}], [1]).

update_guild_apply_log(FieldList, ValueList) ->
	?DB_MODULE:update(log_sky_apply, ValueList, FieldList).

%%玩家氏族战参加日志
make_member_join_log(FieldList, ValueList) ->
	?DB_MODULE:insert(log_sky_p, FieldList, ValueList).

%%神岛空战的修改氏族相关表方法
update_sky_guild(Table, ValueList, FieldList) ->
	?DB_MODULE:update(Table, ValueList, FieldList).

update_sky_goods(ValueList, FieldList) ->
	?DB_MODULE:update(guild, ValueList, FieldList).


%%%%% begin fst
%%获取封神台霸主列表
get_fst_god(Loc, Num) ->
	?DB_MODULE:select_all(fst_god, "id, thrutime, lv, realm, career, sex, light, nick, g_name", 
								 [{loc, Loc}], 
								 [{loc ,desc},{uid, desc}],
								 [Num]).
%%获取封神台霸主id
get_fst_god_id(Loc) ->
	Lists = ?DB_MODULE:select_all(fst_god, "uid", 
								  [{loc, Loc}]),
	lists:flatten(Lists).

%%获取封神台霸主列表（排行榜）
get_fst_god() ->
	?DB_MODULE:select_all(fst_god, "loc, uid, nick, thrutime", [{id, ">", 0}]).

%%检查是否是更高层霸主
ver_gods(Loc, Uid) ->
	?DB_MODULE:select_all(fst_god, "id", 
								 [{loc, ">=", Loc}, {uid, Uid}], 
								 [],
								 [1]).

%% 清除当层霸主
clear_gods(Loc, ThruTime) ->
	?DB_MODULE:delete(fst_god, [{loc, Loc}, {thrutime, ">", ThruTime}]).

%% 清除此ID的低层霸主
clear_gods_lower(Uid, Loc) ->
	?DB_MODULE:delete(fst_god, [{loc, "<=", Loc}, {uid, Uid}]).

%% 增加封神台霸主
add_fst_god(Loc, ThruTime, Uid, Lv, Realm, Career, Sex, Light, Nick, Guild_name) ->
	?DB_MODULE:insert(fst_god, [loc, thrutime, uid, lv, realm, career, sex, light, nick, g_name],[Loc, ThruTime, Uid, Lv, Realm, Career, Sex, Light, Nick, Guild_name]).

%%更新封神台角色名
change_fst_god_name(PlayerId,NickName) ->
	?DB_MODULE:update(fst_god, [{nick, NickName}], [{uid, PlayerId}]).


get_log_fst(Uid)->
	?DB_MODULE:select_all(log_fst_mail, "hor, exp, spr, loc, endtime", 
								 [{uid, Uid},{mailed, 1}], 
								 [],
								 [1]).

delete_log_fst(Uid) ->
	?DB_MODULE:delete(log_fst_mail, [{uid, Uid}]).
add_log_fst(Uid)->
	?DB_MODULE:insert(log_fst_mail, [uid], [Uid]).

update_log_fst(Uid, Hor, Exp, Spr, Loc, Endtime, Mailed,Type) ->
	?DB_MODULE:update(log_fst_mail, [{hor, Hor},
									 {exp, Exp},
									 {spr, Spr},
									 {loc, Loc},
									 {endtime, Endtime},
									 {mailed, Mailed},
									 {type,Type}], [{uid, Uid}]).

add_fst_log_bak(Uid, Loc,Type, Endtime)->
	?DB_MODULE:insert(log_fst, [uid, loc,type, endtime],[Uid, Loc, Type,Endtime]).
%%%%% end fst


%%%%% begin zxt
%%获取诛仙台霸主列表
get_zxt_god(Loc, Num) ->
	?DB_MODULE:select_all(zxt_god, "id, thrutime, lv, realm, career, sex, light, nick, g_name", 
								 [{loc, Loc}], 
								 [{loc ,desc},{uid, desc}],
								 [Num]).
%%获取诛仙台霸主id
get_zxt_god_id(Loc) ->
	?DB_MODULE:select_all(zxt_god, "uid", 
								 [{loc, Loc}], 
								 [],
								 []).

%%获取诛仙台霸主列表（排行榜）
get_zxt_god() ->
	?DB_MODULE:select_all(zxt_god, "loc, uid, nick, thrutime", []).

%%检查是否是更高层霸主
ver_gods_zxt(Loc, Uid) ->
	?DB_MODULE:select_all(zxt_god, "id", 
								 [{loc, ">=", Loc}, {uid, Uid}], 
								 [],
								 [1]).

%% 清除当层霸主
clear_gods_zxt(Loc, ThruTime) ->
	?DB_MODULE:delete(zxt_god, [{loc, Loc}, {thrutime, ">", ThruTime}]).

%% 清除此ID的低层霸主
clear_gods_lower_zxt(Uid, Loc) ->
	?DB_MODULE:delete(zxt_god, [{loc, "<=", Loc}, {uid, Uid}]).

%% 增加诛仙台霸主
add_zxt_god(Loc, ThruTime, Uid, Lv, Realm, Career, Sex, Light, Nick, Guild_name) ->
	?DB_MODULE:insert(zxt_god, [loc, thrutime, uid, lv, realm, career, sex, light, nick, g_name],[Loc, ThruTime, Uid, Lv, Realm, Career, Sex, Light, Nick, Guild_name]).

%%更新诛仙台角色名
change_zxt_god_name(PlayerId,NickName) ->
	?DB_MODULE:update(zxt_god, [{nick, NickName}], [{uid, PlayerId}]).


%%%%% begin 
%%获取镇妖榜列表
get_td_god(Loc, Num) ->
	?DB_MODULE:select_all(td_god, "id, thrutime, lv, realm, career, sex, light, nick, g_name", 
								 [{loc, Loc}], 
								 [{loc ,desc},{uid, desc}],
								 [Num]).

%%获取镇妖台榜列表（排行榜）
get_td_god() ->
	?DB_MODULE:select_all(td_god, "thrutime, loc, nick", []).

%%获取封神台单人记录
get_td_single(Uid) ->
	?DB_MODULE:select_row(td_single, "att_num, hor_td, mgc_td, hor_ttl", [{uid, Uid}], [], [1]).

%%增加封神台单人记录
add_td_single(Att_num, G_name, Nick, Career, Realm, Uid, Hor_td, Mgc_td, Hor_add) ->
	?DB_MODULE:insert(td_single, [att_num, g_name, nick, career, realm, uid, hor_td, mgc_td, hor_ttl],[Att_num, G_name, Nick, Career, Realm, Uid, Hor_td, Mgc_td, Hor_add]).

%%更新封神台单人记录
update_td_single(Att_num, G_name, Hor_td, Mgc_td, Hor_sum, Uid) ->
	?DB_MODULE:update(td_single, [{att_num, Att_num}, {g_name, G_name}, 
										  			{hor_td, Hor_td}, {mgc_td, Mgc_td}, 
										  			{hor_ttl, Hor_sum}],
							   			[{uid, Uid}]).

%%获取封神台多人记录
get_td_multi(Uids) ->
	?DB_MODULE:select_row(td_multi, "att_num, hor_td, mgc_td", [{uids, Uids}], [], [1]).

%%增加封神台多人记录
add_td_multi(Att_num, Nicks, Uids, Hor_td, Mgc_td) ->
	?DB_MODULE:insert(td_multi, [att_num, nicks, uids, hor_td, mgc_td],[Att_num, Nicks, Uids, Hor_td, Mgc_td]).

%%更新封神台多人记录
update_td_multi(Att_num, Uids, Hor_td, Mgc_td) ->
	?DB_MODULE:update(td_multi, [{att_num, Att_num}, {hor_td, Hor_td}, {mgc_td, Mgc_td}], [{uids, Uids}]).

%% 镇妖台（单）排行榜
get_td_single_rank(Num) ->
	?DB_MODULE:select_all(td_single, 
						  "uid, att_num, g_name, nick, career, realm, hor_td, mgc_td",
						  [{hor_td, "<>", 0}],
						  [{hor_td, desc}, {att_num, desc}, {mgc_td, desc}],
						  [Num]).
%% 镇妖台（多）排行榜
get_td_multi_rank() ->
	?DB_MODULE:select_all(td_multi, 
						  "hor_td, att_num, mgc_td, nicks",
						  [{hor_td, "<>", 0}],
						  [{hor_td, desc}, {att_num, desc}, {mgc_td, desc}],
						  [10]).

get_hor_td(Uid) ->
	?DB_MODULE:select_one(td_single, "hor_ttl", [{uid, Uid}], [], [1]).

update_hor_td(Uid, Hor, Action) ->
	?DB_MODULE:update(td_single, [{hor_ttl, Hor, Action}],[{uid, Uid}]).

change_td_single_name(PlayerId,NickName) ->
	?DB_MODULE:update(td_single, [{nick, NickName}],[{uid, PlayerId}]).

add_td_log_unread(Uid, Att_num, Hor_td, Map_type, Time)->
	?DB_MODULE:delete(log_td, [{mark, 0}, {time,  "<", Time}, {uid, Uid}]),
	?DB_MODULE:insert(log_td, [uid, att_num, hor_td, map_type, time],[Uid, Att_num, Hor_td, Map_type, Time]).

add_td_log_read(Uid, Att_num, Hor_td, Map_type, Time)->
	?DB_MODULE:insert(log_td, [uid, att_num, hor_td, map_type, time, mark],[Uid, Att_num, Hor_td, Map_type, Time, 1]).

update_td_log_read(Uid)->
	?DB_MODULE:update(log_td, [{mark, 1}], [{uid, Uid}, {mark, 0}]).

add_log_td(Uid)->
	?DB_MODULE:insert(log_td_mail, [uid],[Uid]).	

get_log_td_unread(Uid)->
	?DB_MODULE:select_row(log_td, "att_num, hor_td, map_type, time", 
								 [{uid, Uid},{mark, 0}], 
								 [],
								 [1]).

delete_log_td_unread(Uid)->
	?DB_MODULE:delete(log_td, [{uid, Uid}, {mark, 0}]).

delete_log_td_unread(Uid, Time)->
	?DB_MODULE:delete(log_td, [{uid, Uid}, {mark, 0},  {time, "<>", Time}]).

%% delete_log_td(Uid) ->
%% 	?DB_MODULE:delete(log_td_mail, [{uid, Uid}]).
%% 
%% update_log_td(Uid, Hor, Exp, Spr, Loc, Endtime, Mailed) ->
%% 	?DB_MODULE:update(log_td_mail, [{hor, Hor},
%% 									 {exp, Exp},
%% 									 {spr, Spr},
%% 									 {loc, Loc},
%% 									 {endtime, Endtime},
%% 									 {mailed, Mailed}], [{uid, Uid}]).
%% 
%% add_td_log_bak(Uid, Loc, Endtime)->
%% 	?DB_MODULE:insert(log_td, [uid, loc, endtime],[Uid, Loc, Endtime]).

%%%%%%% end td

%%%%% begin lib_mail
%% 插入邮件
insert_mail(Type, Timestamp, SName, UId, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold) ->
    ?DB_MODULE:insert(mail, 
		[type, state, timestamp, sname, uid, title, content, gid, goodtype_id, goods_num, coin, gold], 
			[Type, 2, Timestamp, SName, UId, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold]),
	1.

insert_mail_return_id(Type, Timestamp, SName, UId, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold) ->
    ?DB_MODULE:insert(mail, 
		[type, state, timestamp, sname, uid, title, content, gid, goodtype_id, goods_num, coin, gold], 
			[Type, 2, Timestamp, SName, UId, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold]).

%% 插入私人邮件日志
insert_mail_log(Time, SName, UId, RName, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold, MailId, Act) ->
    ?DB_MODULE:insert(log_mail, 
		[time, sname, uid, uname, gid, goods_id, goods_num, coin, gold, mail_id, act], 
			[Time, SName, UId, RName, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold, MailId, Act]).

%% 更新邮件日志信息(领取附件的时间)
update_mail_log(MailId, Time) ->
	?DB_MODULE:update(log_mail, [{rtime, Time}], [{mail_id, MailId}]).

%% %% 限制信件数
%% mail_num_limit(PlayerId) ->
%% 	?DB_MODULE:select_all(mail, 
%% 						  "id, type, state, timestamp, sname, uid, title, content, goods_id, goods_num, coin, gold",
%% 						  [{uid, PlayerId}]).

%% 通过Nickname获取收件人ID
get_mail_player_id(RName) ->
	Ret = ?DB_MODULE:select_one(player, "id", [{nickname, RName}], [], [1]),
	case Ret of
		null -> [];
		_ -> [Ret]
	end.

%% 由角色ID获得角色名
get_mail_player_name(Id) ->
	Ret = ?DB_MODULE:select_one(player, "nickname", [{id, Id}], [], [1]),
	case Ret of
		null -> [];
		_ -> [Ret]
	end.

%% 获取物品ID的信息(mail中)
%% 对要判断物品是否存在时查询
mail_get_goods_by_id(GoodsId) ->
	?DB_MODULE:select_all(goods, "*",
								 [{id, GoodsId}],
								 [],
								 [1]).

%% 获取物品之属性的信息(mail中)
mail_get_goods_attribute_by_id(GoodsId) ->
	?DB_MODULE:select_all(goods_attribute, "*", [{gid, GoodsId}]).

%% 获取物品ID
get_mail_goods_id(PlayerId) ->
	?DB_MODULE:select_all(goods, "id", 
								 [{player_id, PlayerId}, {location, 4}, {cell, 0}]).

%% 插入邮件物品
insert_mail_goods(FieldList, NewInfo) ->
	?DB_MODULE:insert(goods, FieldList, NewInfo),
	1.

%% 修改邮件物品数量
update_mail_goods(Num, GoodsId) ->
	?DB_MODULE:update(goods,
								 [{num, Num}],
								 [{id, GoodsId}]
								).

%% 修改物品信息
update_mail_goods(GoodsId) ->
	?DB_MODULE:update(goods,
								 [{player_id, 0}, {cell,1}],
								 [{id, GoodsId}]
								).

%% 修改物品信息
update_mail_goods(Cell, Num, GoodsId) ->
	?DB_MODULE:update(goods,
								 [{cell, Cell}, {num, Num}],
								 [{id, GoodsId}]
								).

%% 去掉信件的附件
update_mail_attachment(MailId) ->
	Now = util:unixtime(),
	?DB_MODULE:update(mail,
								 [{gid, 0}, {goods_num, 0}, {goodtype_id, 0}, {coin, 0}, {gold, 0},{rtime,Now}],
								 [{id, MailId}]
								).

%% 删除邮件物品
delete_mail_goods(GId) ->
	?DB_MODULE:delete(goods, [{id, GId}]).

%%邮件回馈
mail_feedback(Type, PlayerId, PlayerName, Title, Content, Timestamp, IP, Server) ->
	Feedback = #feedback{
				type = Type, 
				player_id = PlayerId, 
				player_name = PlayerName, 
				title = Title, 
				content = Content,
				timestamp = Timestamp, 
				ip = IP, 
				server = Server		 
						 },
    ValueList = lists:nthtail(2, tuple_to_list(Feedback)),
    [id | FieldList] = record_info(fields, feedback),
	?DB_MODULE:insert(feedback, FieldList, ValueList),
	1.

%% 获得物品类型ID
get_mail_goods_type_id(GoodsId) ->
	?DB_MODULE:select_row(goods, "player_id, goods_id", 
								 [{id, GoodsId}], 
								 [],
								 [1]).

%% 获取邮件信息
get_mail(MailId, PlayerId) ->
	?DB_MODULE:select_all(mail, "id, type, state, timestamp, sname, uid, title, content, gid, goodtype_id, goods_num, coin, gold", 
								 [{id, MailId},{uid, PlayerId}], 
								 [],
								 [1]).

%% 更新信件状态为已读
update_mail_status(MailId) ->
	?DB_MODULE:update(mail,
								 [{state, 1}],
								 [{id, MailId}]
								).

%% 获取用户信件列表
get_maillist(UId) ->
	?DB_MODULE:select_all(mail, "id, type, state, timestamp, sname, uid, title, content, gid, goods_num, coin, gold", 
								 [{uid, UId}]).

%%获取用户所有信件，按已读未读以及时间戳来排序
get_maillist_all(UId) ->
	?DB_MODULE:select_all(mail,"id, type, state, timestamp, sname, uid, title, content, gid, goods_num, coin, gold, goodtype_id", [{uid, UId}],[{state ,desc},{timestamp,desc}],[]).

%%获取用户信件数
get_mail_count(Uid) ->
	?DB_MODULE:select_count(mail,[{uid, Uid}]).

%% 获取指定信件内容
get_mail_info_by_id(Mid, PlayerId) ->
	?DB_MODULE:select_all(mail, "id, type, state, timestamp, sname, uid, title, content, gid, goods_num, coin, gold", 
								 [{id, Mid},
								  {uid, PlayerId}], 
								 [],
								 [1]).
%%获取可以删除的已读邮件列表
get_read_mail_candelete(PlayerId) ->
	List = ?DB_MODULE:select_all(mail, "id, type, state, timestamp, sname, uid, title, content, gid, goods_num, coin, gold", 
								 [{uid, PlayerId}, {id, ">", 0}], 
								 [],
								 []),
	lists:foldl(fun(Elem, AccIn) ->
						[_MailId, _Type, State, _Timestamp, _BinSName, _UId, _Title, _ConTent, GoodsId, GoodsNum, Coin, Gold] = Elem,
						if
							State =/= 1 ->
								AccIn;
							Coin > 0 ->
								AccIn;
							GoodsId > 0 ->
								AccIn;
							GoodsId > 0 ->
								AccIn;
							GoodsNum > 0 ->
								AccIn;
							Gold > 0 ->
								AccIn;
							true ->
								[Elem|AccIn]
						end
				end, [], List).

%% 获取所有信件id
get_all_mail_ids() ->
	?DB_MODULE:select_all(mail, "id", [{uid,">",0}]).


%% 根据ID获取信件内容
get_mail_info_by_mail_id(Id) ->
	?DB_MODULE:select_all(mail, "id, type, state, timestamp, sname, uid, title, content, gid, goods_num, coin, gold", 
								 [{id, Id}], 
								 [],
								 [1]).

%% 检查邮件中是否存在未读邮件
check_mail_unread(UId) ->
	?DB_MODULE:select_all(mail, "id", 
								 [{uid, UId}, {state, 2}],
						  		[],
						  		[]).

check_mail_unread_by_name(Name) ->
	?DB_MODULE:select_all(mail, "id", 
								 [{sname, Name}, {state, 2}],
						  		[],
						  		[]).
%% 删除物品ID
del_mail_goods(GoodsId) ->
	?DB_MODULE:delete(goods, [{id, GoodsId}]).

%% 删除信件
del_mail(MailId) ->
	?DB_MODULE:delete(mail, [{id, MailId}]).

%% 处理发信时的物品附件
handle_mail_goods(GoodsId) ->
	?DB_MODULE:update(goods,
								 [{player_id, 0}],
								 [{id, GoodsId}]
								).
%% 处理发信时的物品附件之属性
handle_mail_goods_attribute(GoodsId) ->
	?DB_MODULE:update(goods_attribute,
								 [{player_id, 0}],
								 [{gid, GoodsId}]
								).

%% 提取附件
attach_mail_goods(PlayerId, MinCellNum, GoodsId) ->
	?DB_MODULE:update(goods_attribute,
								 [{player_id, PlayerId}],
								 [{gid, GoodsId}]
								),
	?DB_MODULE:update(goods,
								 [{player_id, PlayerId},
								  {cell, MinCellNum},
								  {location, 4}],
								 [{id, GoodsId}]
								).	
	

%%处理附件
handle_mail_attachment(PlayerId, MinCellNum, NewNum, GoodsId) ->
	?DB_MODULE:update(goods_attribute,
								 [{player_id, PlayerId}],
								 [{gid, GoodsId}]
								),	
	?DB_MODULE:update(goods,
								 [{player_id, PlayerId},
								  {cell, MinCellNum},
								  {num, NewNum}],
								 [{id, GoodsId}]
								).

%% 处理金钱附件（提取附件时）,此方法暂时没用，用时更新gold应用增量更新
handle_mail_money(PlayerId, Coin, Gold) ->
	?DB_MODULE:update(player,
								 [{coin, Coin, add},
								  {coin_sum, Coin, add},
								  {gold, Gold, add}],
								 [{id, PlayerId}]
								).
%%%%% end


%%%%% lib_make
%% 装备强化更新（绑定状态不变）
mod_strengthen(Strengthen, Stren_fail, GoodsId) ->
	?DB_MODULE:update(goods,
								 [{stren, Strengthen},
								  {stren_fail, Stren_fail},
								  {score, 0}],
								 [{id, GoodsId}]
								).

%%装备强化更新
mod_strengthen(Strengthen, Stren_fail, Bind, Trade,GoodsId) ->
	mod_strengthen(Strengthen, Stren_fail, Bind, Trade,0,GoodsId).

%% 装备强化更新（绑定状态改变）
mod_strengthen(Strengthen, Stren_fail, Bind, Trade,Expire,GoodsId) ->
	?DB_MODULE:update(goods,
								 [{stren, Strengthen},
								  {stren_fail, Stren_fail},
								  {bind, Bind},
								  {trade, Trade},
								  {expire_time,Expire},
								  {score, 0}],
								 [{id, GoodsId}]
								).

%% 装备打孔
quality_hole(Hole, Bind, Trade, GoodsId) ->
	?DB_MODULE:update(goods,
								 [{hole, Hole},
								  {bind, Bind},
								  {trade, Trade}],
								 [{id, GoodsId}]
								).

%% 装备镶嵌成功
quality_inlay_ok(StoneCol, Stone_goods_id, Bind, Trade, GoodsId) ->
	?DB_MODULE:update(goods,
								 [{StoneCol, Stone_goods_id},
								  {bind, Bind},
								  {trade, Trade},
								  {score, 0}],
								 [{id, GoodsId}]
								).

%% 装备宝石拆除
quality_backout(GoodsInfo) ->
	?DB_MODULE:update(goods,
								 [{hole1_goods, GoodsInfo#goods.hole1_goods},
								  {hole2_goods, GoodsInfo#goods.hole2_goods},
								  {hole3_goods, GoodsInfo#goods.hole3_goods},
								  {bind, GoodsInfo#goods.bind},
								  {trade, GoodsInfo#goods.trade},
								  {score, 0}],
								 [{id, GoodsInfo#goods.id}]
								).

%%属性鉴定
identify(Aid)->
	?DB_MODULE:update(goods_attribute,
								 [{status,1}],
								 [{id,Aid}]
								 ).

%%法宝修炼
practise(GoodsInfo) ->
	?DB_MODULE:update(goods,
								 [{grade,GoodsInfo#goods.grade},
								  {spirit,GoodsInfo#goods.spirit},
								  {max_attack,GoodsInfo#goods.max_attack},
								  {min_attack,GoodsInfo#goods.min_attack},
								  {hit,GoodsInfo#goods.hit},
								  {wit,GoodsInfo#goods.wit},
								  {agile,GoodsInfo#goods.agile},
								  {forza,GoodsInfo#goods.forza},
								  {physique,GoodsInfo#goods.physique},
								  {bind,GoodsInfo#goods.bind}
%% 								  {score, erlang:round(((GoodsInfo#goods.color+1)/2+1)*5), add}
								  ],
								 [{id,GoodsInfo#goods.id}]
								 ).

%%法宝融合
merge(GoodsInfo) ->
	?DB_MODULE:update(goods,
								 [{grade,GoodsInfo#goods.grade},
								  {spirit,GoodsInfo#goods.spirit},
								  {bind,GoodsInfo#goods.bind},
								  {stren,GoodsInfo#goods.stren},
								  {stren_fail,GoodsInfo#goods.stren_fail},
								  {score, 0}],
								 [{id,GoodsInfo#goods.id}]
								 ).

%%变性时更改时装ID

fashion_change(Gid,NewGoodsId) ->
	?DB_MODULE:update(goods,
					             [{goods_id, NewGoodsId}],
					  			 [{id,Gid}]
					  ).

%%中秋时装
mid_fashion_change(Gid,NewGoodsId,NewIcon) ->
	?DB_MODULE:update(goods,
					             [{goods_id, NewGoodsId},
								  {icon, NewIcon}],
					  			 [{id,Gid}]
					  ).
%%%%% end
%%紫戒指祝福
ring_bless(Bless_level,Bless_skill,Gid) ->
	?DB_MODULE:update(goods,
								 [{bless_level,Bless_level},
								  {bless_skill,Bless_skill}],
								 [{id,Gid}]
								 ).
%%
%%%%% end


%%%%% begin lib_meridian
%获取玩家经脉属性信息
select_meridian_by_playerid(PlayerId)->
	?DB_MODULE:select_row(meridian, 
								 "*", 
								 [{player_id, PlayerId}],
						  		 [], [1]).

%获取经脉升级基础属性
select_meridian_basedata(MerType,MerLvl) ->
	?DB_MODULE:select_row(base_meridian, 
								 "*", 
								 [{mer_type, MerType}, {mer_lvl, MerLvl}]
						 		).

%% 新建经脉记录
new_meridian(PlayerId) ->
	Meridian = #ets_meridian{
					player_id = PlayerId
							},
    ValueList = lists:nthtail(2, tuple_to_list(Meridian)),
    [id | FieldList] = record_info(fields, ets_meridian),
	?DB_MODULE:insert(meridian, FieldList, ValueList).

%%删除经脉记录
delete_role_meridian(PlayerId)->
	?DB_MODULE:delete(meridian,[{player_id,PlayerId}]).

%%经脉修炼
meridian_uplvl_start(PlayerId, MeridianId, Timestamp)->
	?DB_MODULE:update(meridian,
								 [{meridian_uplevel_typeId, MeridianId},
								  {meridian_uplevel_time, Timestamp}],
								 [{player_id, PlayerId}]
								).

%%经脉修炼加速
meridian_uplvl_speed(PlayerId,Timestamp)->
	?DB_MODULE:update(meridian,
								 [{meridian_uplevel_time, Timestamp}],
								 [{player_id, PlayerId}]
								).
%%经脉修炼结束
meridian_uplvl_finish(PlayerId, MeridianType, LvlUp)->
	?DB_MODULE:update(meridian,
								 [{meridian_uplevel_typeId, 0},
								  {meridian_uplevel_time, 0},
								  {MeridianType, LvlUp, add}],
								 [{player_id, PlayerId}]
								).

%灵根洗练
update_meridian_linggen(PlayerId, LingGen, Value) ->
	?DB_MODULE:update(meridian,
								 [{LingGen, Value, add}],
								 [{player_id, PlayerId}]
								).

%%经脉突破
update_break_through(PlayerId,TopType,Value)->
	?DB_MODULE:update(meridian,
								 [{TopType, Value, add}],
								 [{player_id, PlayerId}]
								).

%%经脉突破日志
log_meridian_break(PlayerId,MerId,New,Old,Res,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID, log_meridian_break, [pid,merid,newval,oldval,res,timestamp],[PlayerId,MerId,New,Old,Res,Timestamp]).

%%更新经脉信息
update_meridian_info(ValueList, WhereList)->
	?DB_MODULE:update(meridian, ValueList, WhereList).

%%经脉修炼日志
meridian_log(PlayerId,MerId,MerLv,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID, log_meridian, 
						[player_id, mer_id,mer_lv, timestamp],
					  	[PlayerId, MerId, MerLv, Timestamp]).

%%灵根洗练日志
linggen_log(PlayerId,Mid,Old,New,Pt,Re,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID, log_linggen, 
						[pid, mid, old, new, pt, re, time],
					    [PlayerId, Mid, Old, New, Pt, Re, Timestamp]).

%%获取灵根日志
get_linggen_log(PlayerId)->
	?DB_MODULE:select_all(log_linggen,"*",[{pid,PlayerId}]).
%%%%% end

%%%%% begin mod_meridian

%% 获取指定类型的经脉信息
mm_get_meridian_info_by_type(Type,Level) ->
	?DB_MODULE:select_row(base_meridian,  "*", [{mer_type, Type},{mer_lvl, Level}]).
%%%%% end

%%%%% begin lib_pet

%% 加载初始灵兽信息
%% 系统启动后的加载
load_base_pet() ->
	?DB_MODULE:select_all(base_pet, "*", [{goods_id,">",0}]).

%% 加载初始灵兽信息
%% 系统启动后的加载
load_base_pet_skill_effect() ->
	?DB_MODULE:select_all(base_pet_skill_effect, "*", [{id,">",0}]).

%% 加载玩家所有的灵兽
select_player_all_pet(PlayerId) ->
	?DB_MODULE:select_all(pet, "*", [{player_id, PlayerId}],[{id, asc}],[]).

%%加载角色灵兽购买记录
load_all_pet_buy(PlayerId) ->
	?DB_MODULE:select_all(pet_buy, "*", [{player_id, PlayerId}],[{ct, asc}],[]).

%%删除两天前角色灵兽购买记录
delete_all_pet_buy(PlayerId) ->
	Now = util:unixtime(),
	?DB_MODULE:delete(pet_buy, [{player_id, PlayerId},{ct,"<" ,Now-2*24*60*60}]).

%%加载角色灵兽技能分离
load_all_pet_split_skill(PlayerId) ->
	?DB_MODULE:select_all(pet_split_skill, "*", [{player_id, PlayerId}],[{ct, asc}],[]).

%%加载角色灵兽额外信息
load_pet_extra(PlayerId) ->
	?DB_MODULE:select_row(pet_extra, "*", [{player_id, PlayerId}],[],[1]).

%% 更新灵兽信息
save_pet(PetId,Goods_Id,Level,Exp,Forza,Wit,Agile,Physique,Happy,Aptitude,Point,Grow,Skill_1,Skill_2,Skill_3,Skill_4,Skill_5,Skill_6,Chenge,Batt_skill,Apt_range) ->
	?DB_MODULE:update(pet,
								 [{goods_id,Goods_Id},
								  {level,Level},
								  {exp,Exp},
								  {forza, Forza},
								  {wit, Wit},
								  {agile, Agile},
								  {physique, Physique},
								  {happy,Happy},
								  {aptitude,Aptitude},
								  {point,Point},
								  {grow,Grow},
								  {skill_1,Skill_1},
								  {skill_2,Skill_2},
								  {skill_3,Skill_3},
								  {skill_4,Skill_4},
								  {skill_5,Skill_5},
								  {skill_6,Skill_6},
								  {chenge,Chenge},
								  {batt_skill,Batt_skill},
								  {apt_range,Apt_range}
								 ],
								 [{id, PetId}]
								).

save_pet_buy(Player_Id,Goods_id,Now) ->
	?DB_MODULE:insert(pet_buy, [player_id, goods_id, ct],[Player_Id, Goods_id, Now]).

%% 保存灵兽分离技能
save_pet_split_skill(Player_Id,Pet_Id,Skill,Now) ->
	?DB_MODULE:insert(pet_split_skill, [player_id, pet_id, pet_skill, ct],[Player_Id, Pet_Id, Skill, Now]).

%% 保存角色灵兽额外信息
save_pet_extra(Player_Id,Skill_exp,Lucky_value,Step) ->
	?DB_MODULE:insert(pet_extra, [player_id, skill_exp, lucky_value, auto_step],[Player_Id,Skill_exp,Lucky_value,Step]).

%% 更新角色灵兽额外信息
update_pet_extra(Player_Id,Skill_exp,Lucky_value,Batt_lucky_value,Step,Free_flush,Batt_free_flush,LastTime) ->
	?DB_MODULE:update(pet_extra, [{skill_exp,Skill_exp},{lucky_value,Lucky_value},{batt_lucky_value,Batt_lucky_value},{auto_step,Step},{free_flush,Free_flush},{batt_free_flush,Batt_free_flush},{last_time,LastTime}],[{player_id,Player_Id}]).

clear_player_pet_lucky_value() ->
	?DB_MODULE:update(pet_extra, [{lucky_value,0}],[{lucky_value, ">", 0}]).

%% 删除灵兽分离技能
delete_pet_split_skill(PetSplitSkillIdList) ->
	?DB_MODULE:delete(pet_split_skill, [{id, "in", PetSplitSkillIdList}]).

%% 删除灵兽购买日志
delete_pet_buy(Player_Id) ->
	?DB_MODULE:delete(pet_buy, [{player_id, Player_Id}]).

%% 更新灵兽分离技能
update_pet_split_skill(Id,Skill,Now) ->
	?DB_MODULE:update(pet_split_skill,[{pet_skill,Skill},{ct,Now}], [{id, Id}]).

%% 删除灵兽分离技能
del_pet_split_skill(Player_Id,Skill) ->
	Id = ?DB_MODULE:select_one(pet_split_skill,"id", [{player_id,Player_Id},{pet_skill,Skill}],[{ct, asc}], [1]),	
	?DB_MODULE:delete(pet_split_skill, [{id,Id}]).

%% 保存灵兽分离,合并技能日志(1技能分离2一键合并3技能上下左右拖动合并)
insert_log_pet_skill_oper(Player_id, Pet_id, Before_skill, After_skill, Type, Ct) ->
	?DB_MODULE:insert(?LOG_POOLID,log_pet_skill_oper, [player_id, pet_id, before_skill, after_skill, type, ct],[Player_id, Pet_id, Before_skill, After_skill, Type, Ct]).


%%生成灵兽添加默认值
give_pet(PlayerId, GoodsId, Name, Aptitude,Grow,Point, Skill) ->
	Pet = #ets_pet{
				   player_id = PlayerId,
				   goods_id = GoodsId,
				   name = Name,
				   aptitude = Aptitude,
				   grow = Grow,
				   point=Point,
				   skill_1 = Skill
				   },
    ValueList = lists:nthtail(2, tuple_to_list(Pet)),
    [id | FieldList] = record_info(fields, ets_pet),
	Ret = ?DB_MODULE:insert(pet, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
    		Ret;
		_ ->
			{mongo, Ret}
	end.

%%获取新生成的灵兽
get_new_pet(PlayerId) ->
	?DB_MODULE:select_row(pet,
								 "*",
								 [{player_id,PlayerId}],
								 [{id, desc}],
								 [1]
								).

%% 灵兽放生
free_pet(PetId) ->
	?DB_MODULE:delete(pet, [{id, PetId}]).

%% 灵兽改名
rename_pet(PetId, PetName) ->
	?DB_MODULE:update(pet,
								 [{name, PetName},
								  {rename_count, 1, add}],
								 [{id, PetId}]
								).

%% 更新灵兽状态
pet_update_status(PetId,S) ->
	?DB_MODULE:update(pet,
								 [{status, S}],
								 [{id, PetId}]
								).

%%灵兽喂养
pet_feed(PetId,H) ->
	?DB_MODULE:update(pet,
								 [{happy,H}],
								 [{id,PetId}]								 
								).

%% 灵兽属性加点
mod_pet_attribute(PetId,Forza,Agile,Wit,Physique,Point) ->
	?DB_MODULE:update(pet,
								 [{forza,Forza},
								  {agile,Agile},
								  {wit,Wit},
								  {physique,Physique},
								  {point,Point}],
								 [{id,PetId}]
								 ).

%% 灵兽技能学习
pet_learn_skill(PetId,Skill,Sid) ->
	?DB_MODULE:update(pet,
								 [{Skill,Sid}],
								 [{id,PetId}]
								 ).

%% 灵兽技能学习
update_pet_skill(PetId,[Skill_1,Skill_2,Skill_3,Skill_4,Skill_5,Skill_6]) ->
	?DB_MODULE:update(pet,
								 [{skill_1,Skill_1},{skill_2,Skill_2},{skill_3,Skill_3},{skill_4,Skill_4},{skill_5,Skill_5},{skill_6,Skill_6}],
								 [{id,PetId}]
								 ).

%%灵兽遗忘技能
pet_forget_skill(PetId,Skill)->
	?DB_MODULE:update(pet,
								 [{Skill,0}],
								 [{id,PetId}]
								 ).

%% 灵兽变身
change_pet(PetId,PetType) ->
	?DB_MODULE:update(pet,
					  		[{goods_id,PetType}],
					  		[{id,PetId}]
					  ).
%%灵兽获得成长值
pet_get_grow(PetId,Grow)->
	?DB_MODULE:update(pet,
					  		[{grow,Grow}],
					  		[{id,PetId}]
					  ).

%%灵兽训练
pet_train(PetId,Status,GoodsNum,MoneyType,MoneyNum,Auto,TrianStart,TrainTime)->
	?DB_MODULE:update(pet,
					  		[{status,Status},
							 {goods_num,GoodsNum},
							 {money_type,MoneyType},
							 {money_num,MoneyNum},
							 {auto_up,Auto},
							 {train_start,TrianStart},
							 {train_end,TrainTime}],
					  		[{id,PetId}]
					  ).
%%更新灵兽训练时间
update_train_time(PetId,Timestamp)->
	?DB_MODULE:update(pet,
					  [{train_start,Timestamp}],
					  		[{id,PetId}]
					  ).
	

%%获得灵兽日志
log_get_pet(PlayerId,PetId,GoodsId,Apt,Grow,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID, log_get_pet, [pid, pet_id, goods_id, apt, grow, timestamp],
					  		[PlayerId, PetId, GoodsId, Apt, Grow, Timestamp]).

%%灵兽放生日志
free_pet_log(PlayerId,PetId,Lv,Apt,Grow,Skill1,Skill2,Skill3,Skill4,Skill5,Skill6,Timestamp,Type)->
	?DB_MODULE:insert(?LOG_POOLID, log_free_pet, 
						[pid, pet_id, lv, apt, grow, skill_1, skill_2, skill_3, skill_4, skill_5, skill_6, timestamp, type],
					  	[PlayerId, PetId, Lv, Apt, Grow, Skill1, Skill2, Skill3, Skill4, Skill5, Skill6, Timestamp, Type]).

%%灵兽资质提示日志
upgrade_aptitude_log(UpBag)->
	[PlayerId,PetId,OldApt,NewApt,Ratio,RP,Coin,Save,Timestamp] = UpBag,
	?DB_MODULE:insert(?LOG_POOLID, log_pet_aptitude, 
						[pid, petid, old, new, ratio, rp, coin, save, time],
					  	[PlayerId, PetId, OldApt, NewApt, Ratio, RP, Coin, Save, Timestamp]).

%%灵兽成长值提升日志
upgrade_grow_log(UpBag)->
	[PlayerId,PetId,OldGrow,NewGrow,Save,Ratio,RP,Timestamp] = UpBag,
	?DB_MODULE:insert(?LOG_POOLID, log_pet_grow, 
						[pid, petid, old, new, save, ratio, rp, time],
					 	 [PlayerId, PetId, OldGrow, NewGrow, Save, Ratio, RP, Timestamp]).
%%灵兽训练日志
train_pet_log(TrainBag)->
	[Pid,PetId,Lv,Foods,Mt,M,TrainTime,Opt,Timestamp]=TrainBag,
	?DB_MODULE:insert(?LOG_POOLID, log_pet_train,
					  [pid, petid, lv, foods, money_type, money, train, opt, timestamp],
					  [Pid, PetId, Lv, Foods, Mt, M, TrainTime, Opt, Timestamp]).

%%灵兽加点日志
log_pet_addpoint(Pid,Petid,Point,Forza,Wit,Agile,Phy,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID, log_pet_addpoint,
					  [pid, petid, point, forza, wit, agile, phy, timestamp],
					  [Pid, Petid, Point, Forza, Wit, Agile, Phy, Timestamp]).

%%灵兽洗点日志
log_pet_wash_point(Pid,PetId,Point,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID, log_pet_wash_point,
					  [pid, petid, point, timestamp],
					  [Pid, PetId, Point, Timestamp]).

%%灵兽融合日志
log_pet_merge(PlayerId,PetId,GoodsId,Lv,Exp,Happy,Point,Chenge,Forza,Wit,Agile,Phy,Grow,Apt,Skill1,Skill2,Skill3,Skill4,Skill5,Aptitude,Skill_6,Apt_range,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID, log_pet_merge,
					  [pid, pet_id, goods_id, lv, exp, happy, point, chenge, forza, wit, agile, phy, grow, apt, skill1, skill2, skill3, skill4, skill5,aptitude,skill_6,apt_range,timestamp],
					  [PlayerId, PetId, GoodsId, Lv, Exp, Happy, Point, Chenge, Forza, Wit, Agile, Phy, Grow, Apt, Skill1, Skill2, Skill3, Skill4, Skill5,Aptitude,Skill_6,Apt_range,Timestamp]).


%%灵兽升级日志
log_pet_uplv(PlayerId,PetId,Lv,Exp,Apt,Grow,Point,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID, log_pet_uplv,
					  [pid, petid, lv, exp, apt, grow, point, timestamp],
					  [PlayerId, PetId, Lv, Exp, Apt, Grow, Point, Timestamp]).

%% 灵兽化形
%% add by zkj
pet_chenge(PetId,GoodsId,NowTime) ->
	?DB_MODULE:update(pet,
					  		[{goods_id,GoodsId},
							 {chenge,NowTime}],
					  		[{id,PetId}]
					  ).

%% 灵兽融合
%% add by zkj
pet_merge(PetId,Goods_Id,Level, Exp, Happy, New_remain_point, Forza, Wit, Agile, Physique, 
		  Grow,Status,Skill_1,Skill_2,Skill_3, Skill_4,Time,Chenge,Skill_5,Aptitude,Skill_6,Apt_range) ->
	?DB_MODULE:update(pet,
					  		[{goods_id,Goods_Id},
							 {level,Level},
							 {exp, Exp},
							 {happy, Happy},
							 {point, New_remain_point},
							 {forza, Forza},
							 {wit, Wit},
							 {agile, Agile},
							 {physique, Physique},
							 {grow, Grow},
							 {status, Status},
							 {skill_1, Skill_1},
							 {skill_2, Skill_2},
							 {skill_3, Skill_3},
							 {skill_4, Skill_4},
							 {time, Time},
							 {chenge, Chenge},
							 {skill_5, Skill_5},
							 {aptitude,Aptitude},
							 {skill_6, Skill_6},
							 {apt_range,Apt_range}],
					  		[{id,PetId}]
					  ).
%% 获取玩家的某个灵兽信息
%% add by zkj
select_player_petid(PetId) ->
	?DB_MODULE:select_all(pet, "*", [{id, PetId}]).


%% 删除角色
lp_delete_role(PlayerId) ->
	?DB_MODULE:delete(pet, [{player_id, PlayerId}]).
%%%%% end


%%%%% begin lib_player

%% 根据角色名称查找ID
get_role_id_by_name(Sn, Name) ->
	?DB_MODULE:select_one(player, "id", [{nickname, Name},{sn, Sn}], [], [1]).

%% 根据角色名称查找ID
get_role_id_by_name(Name) ->
	?DB_MODULE:select_one(player, "id", [{nickname, Name}], [], [1]).

get_role_name_by_id(Id)->
	?DB_MODULE:select_one(player, "nickname", [{id, Id}], [], [1]).
	
%% 检测指定名称的角色是否已存在
is_accname_exists(Sn, AccName) ->
	?DB_MODULE:select_one(player, "id", [{accname, AccName},{sn, Sn}], [], [1]).

%% 更改玩家经验、血、魔等数值
update_player_exp_data(ValueList, WhereList) ->
	?DB_MODULE:update(player, ValueList, WhereList).

%%%%% end


%%%%% begin lib_rank

%% 获取玩家基本信息
rank_get_player_info_list(PlayerId) ->
	rank_get_player_info_list(?MASTER_POOLID, PlayerId).

rank_get_player_info_list(POOLID, PlayerId) ->
	?DB_MODULE:select_all(POOLID, player, 
								 "id, nickname, realm, guild_name, career, vip", 
								 [{id, PlayerId}],
						  		 [],[]
								).

%% @doc  查询装备相关属性
rank_query_equip(Type)  ->
	rank_query_equip(?MASTER_POOLID,Type).

rank_query_equip(POOLID, Type)  ->
	[WhereType1, WhereType2] =
		case Type of
			1 -> [{subtype, ">", 8},{subtype, "<", 14}];
			2 -> [{subtype, ">", 13},{subtype, "<", 20}];
			_ -> [{},{}]
		end,
	?DB_MODULE:select_all(POOLID,goods, 
								 "id, goods_id, player_id, score", 
								 [WhereType1, WhereType2,{player_id, "<>", 0},{score, ">", 0}],
						  		 [{score, desc},{id, asc}],
						  		 [100]
								 ).

rank_query_deputy_equip(POOLID) ->
	?DB_MODULE:select_all(POOLID,deputy_equip, 
								 "id, pid, prof_lv, color, batt_val", 
								 [{id, "<>", 0},{batt_val, ">", 0}],
						  		 [{batt_val, desc},{id, asc}],
						  		 [100]
								 ).

%% {_PetId, _PetName, PlayerId, _PetLevel, _PetAptitude, _Grow}
rank_query_pet() ->
	rank_query_pet(?MASTER_POOLID).

rank_query_pet(_PoolId) ->
	?DB_MODULE:select_all(pet, 
						  "id, name, player_id, level, aptitude, grow,skill_1,skill_2,skill_3,skill_4,skill_5",
						  [{player_id, "<>", 0}],
						  [{level, desc}, {aptitude, desc}, {grow, desc}, {id, asc}],
						  [100]).

rank_query_charm() ->
	?DB_MODULE:select_all(love, 
						  "pid, charm, title",
						  [{charm, ">=", 10}],
						  [{charm, desc}],
						  [100]).

%% 查询所有玩家成就点(成就点大于10的)
rank_query_achieve() ->
	Result = ?DB_MODULE:select_all(ach_treasure, 
						  "pid, ach",
						  [{ach, ">=", 10}],
						  [{ach, desc}],
						  [100]),
	Result.

%% 主数据库中获取玩家排名信息 替换io_lib:format 
rank_get_player_info(Realm, Career, Sex, Type, Limit) ->
	rank_get_player_info(?MASTER_POOLID, Realm, Career, Sex, Type, Limit).

%% 从数据库中获取玩家排名信息 替换io_lib:format
rank_get_player_info(POOLID, Realm, Career, Sex, Type, Limit) ->
	L = [{career, Career}, {realm, Realm}, { sex, Sex}],
	Where0 = lists:map(fun({Field, Value}) ->
							if Value =/= 0 ->
									{Field, Value};
								true ->	[]
							end
						end, L),
	Where1 = [{realm, "<>", ?NEW_PLAYER_SCENE_ID}, {realm, "<>", ?NEW_PLAYER_SCENE_ID_TWO},{realm, "<>", ?NEW_PLAYER_SCENE_ID_THREE}] ++ lists:filter(fun(T)-> is_tuple(T)  end, Where0),
	case ?DB_MODULE =:= db_mysql andalso Type =:= coin_sum of
		true ->
			?DB_MODULE:select_all(player, 
								 "id, nickname, sex, career, realm, guild_name, coin+bcoin ",
								 Where1,
								 [{'coin+bcoin' ,desc}],
								 [Limit]
								 );
		_ ->
			?DB_MODULE:select_all(POOLID, player, 
								 "id, nickname, sex, career, realm, guild_name" ++ ", " ++ atom_to_list(Type),
								 Where1,
								 [{Type, desc}, {exp, desc}, {id, asc}],
								 [Limit]
								 )
	end.

loop_query_batt_value(Limit) ->
	loop_query_batt_value(?MASTER_POOLID,Limit).

loop_query_batt_value(_POOLID,Limit) ->
	?DB_MODULE:select_all(batt_value, 
								 "player_id,value",
								 [{player_id, ">", 0}],
								 [{value, desc},{id, desc}],
								 [Limit]
								 ).
	
%%角色等级排行
loop_query_lv(Limit) ->
	loop_query_lv(?MASTER_POOLID,Limit).

loop_query_lv(_POOLID,Limit) ->
	?DB_MODULE:select_all(player, 
								 "id, nickname, sex, career, realm, guild_name, lv, vip",
								 [{id, ">", 0}],
								 [{lv, desc}, {exp, desc}],
								 [Limit]
								 ).
%%角色财富排行
loop_query_coin_sum(Limit) ->
	loop_query_coin_sum(?MASTER_POOLID,Limit).

loop_query_coin_sum(_POOLID,Limit) ->
	?DB_MODULE:select_all(player, 
								 "id, nickname, sex, career, realm, guild_name, coin_sum, vip",
								 [{id, ">", 0}],
								 [{coin_sum, desc}, {lv, desc}], %%去掉{id,desc}
								 [Limit]
								 ).

%%角色荣誉排行
loop_query_honor(Limit) ->
	loop_query_honor(?MASTER_POOLID,Limit).

loop_query_honor(_POOLID,Limit) ->
	?DB_MODULE:select_all(player, 
								 "id, nickname, sex, career, realm, guild_name, realm_honor, vip",
								 [{id, ">", 0}],
								 [{realm_honor, desc}, {lv, desc}],
								 [Limit]
								 ).
%%角色修为排行
loop_query_culture(Limit) ->
	loop_query_culture(?MASTER_POOLID,Limit).

loop_query_culture(_POOLID,Limit) ->
	?DB_MODULE:select_all(player, 
								 "id, nickname, sex, career, realm, guild_name, culture, vip",
								 [{id, ">", 0}],
								 [{culture, desc}, {lv, desc}],
								 [Limit]
								 ).

%% 获取指定物品信息
rank_get_goods_by_id(GoodsId) ->
	?DB_MODULE:select_all(goods, 
								 "*",
								 [{id, GoodsId}],
								 [],
								 [1]
								 ).
%%%%% end

%%%%% begin relationship

%%建立关系(A加B)
%%IdA:角色A的id
%%IdB:角色B的id
%%Rela:A与B的关系
%%    0 =>没关系
%%    1 =>好友
%%    2 =>黑名单
%%    3 =>仇人
relationship_add(IdA, IdB, Rela,Nowtime,Close,Pkmon,Timestamp) ->
%% 	Nowtime = util:unixtime(),
	Ret = ?DB_MODULE:insert(relationship,[idA, idB, rela, time_form,close,pk_mon,timestamp], [IdA, IdB, Rela, Nowtime,Close,Pkmon,Timestamp]),
	case ?DB_MODULE =:= db_mysql of
		true ->
    		Ret;
		_ ->
			{mongo, Ret}
	end.	

%%删除某个记录
relationship_delete(Id) ->
	?DB_MODULE:delete(relationship, [{id, Id}]).

%%删除某种关系
relationship_delete(IdA, IdB, Rela) ->
	?DB_MODULE:delete(relationship, [{idA, IdA}, {idB, IdB}, {rela, Rela}]).

%%当玩家删除角色时，删除有关于这角色的数据
relationship_delete_role1(Uid) ->
	?DB_MODULE:delete(relationship, [{idA, Uid}]),
	?DB_MODULE:delete(relationship, [{idB, Uid}]).

%%获取数据库中此ID的好友数,返回如[[],[5]]
relationship_get_fri_count(Uid) ->
	NumA = ?DB_MODULE:select_count(relationship,[{idA,Uid}]),
	NumB = ?DB_MODULE:select_count(relationship,[{idB,Uid}]),
	[NumA, NumB].

%%查找AB存在的某种关系
relationship_find_close(IdA, IdB, Rela) ->
  ?DB_MODULE:select_row(relationship, "id,close", [{idA, IdA}, {idB, IdB}, {rela, Rela}], [], [1]).

%%取某条记录id
relationship_get_id(IdA, IdB, Rela) ->
	Ret = ?DB_MODULE:select_one(relationship, "id", [{idA, IdA}, {idB, IdB}, {rela, Rela}], [], [1]),
	case Ret of
		null -> [];
		_ -> [Ret]
	end.

%%查找与角色A的关系信息
relationship_find(IdA) ->
	?DB_MODULE:select_all(relationship, "id,idB,rela,time_form,close,pk_mon,timestamp", [{idA, IdA}]).

%%查找与角色B的关系信息
relationship_find(IdB, Rela) ->
	?DB_MODULE:select_all(relationship, "id,idA,rela,time_form,close,pk_mon,timestamp", [{idB, IdB},{rela, Rela}]).

%%更新角色的每日打怪亲密度上限
update_pk_mon_close_limit(IdA,IdB,NowTime)->
	?DB_MODULE:update(relationship,[{pk_mon,0},{timestamp,NowTime}],[{idA,IdA},{idB,IdB}]).

%%更新好友亲密度
update_close(Id,Close,PkMon,Timestamp)->
	?DB_MODULE:update(relationship,[{close,Close},{pk_mon,PkMon},{timestamp,Timestamp}],[{id,Id}]).

%%查找角色信息
relationship_get_player_info(Id) ->
	?DB_MODULE:select_row(player, "id, nickname, sex, lv, career", [{id, Id}]).

%%获取角色当前祝福信息
get_bless_info(PlayerId) ->
	?DB_MODULE:select_row(daily_bless, "times, b_exp, b_spr, bless_time", [{player_id, PlayerId}], [], [1]).

%%初始化角色祝福记录
insert_bless_info(PlayerId, Nowtime) ->
	?DB_MODULE:insert(daily_bless, 
						[player_id, times, b_exp, b_spr, bless_time],
					  	[PlayerId, 0, 0, 0, Nowtime]).	

%% 保存角色当前祝福信息
%% Times 每日已用祝福次数
%% BlessTime 每天第一次祝福的时间
set_bless_info(PlayerId, Times, BlessTime) ->
	?DB_MODULE:update(daily_bless, [{times, Times}, {bless_time, BlessTime}], [{player_id, PlayerId}]).

%%保存角色当前祝福次数
set_bless_times(PlayerId, Times) ->
	?DB_MODULE:update(daily_bless,
								 [{times, Times}
								 ],
								 [{player_id, PlayerId}]
								).

%%更新祝福瓶的经验与灵力、当前祝福次数
%%接收祝福
set_bless_bottle(PlayerId,[Exp,Spr])->
	?DB_MODULE:update(daily_bless, [{b_exp, Exp}, {b_spr, Spr}], [{player_id, PlayerId}]);
%%祝福别人
set_bless_bottle(PlayerId,[Exp,Spr,BlessTimes])->
	?DB_MODULE:update(daily_bless, [{b_exp, Exp}, {b_spr, Spr}, {times, BlessTimes}], [{player_id, PlayerId}]).

update_bless_bottle(VList,WList)->
	?DB_MODULE:update(daily_bless,VList,WList).

%%祝福瓶经验领取日志
insert_log_bottle_exp(PlayerId,Exp,Spr,TimeStamp,Level) ->
	?DB_MODULE:insert(?LOG_POOLID, log_bless_bottel,
					  [player_id,exp,spr,timestamp,level],
					  [PlayerId,Exp,Spr,TimeStamp,Level]).

%%%%% begin 副本进出计数器

%% 获取副本进出计数
%% @param PlayerId 玩家ID
%% @param DungeonId 副本ID
get_log_dungeon(PlayerId, DungeonId) ->
	?DB_MODULE:select_row(log_dungeon, "*", [{player_id, PlayerId},{dungeon_id, DungeonId}]).

%% 插入副本进出计数
%% @param PlayerId 玩家ID
%% @param DungeonId 副本ID
%% @param First_dungeon_time 初次进入副本时间
%% @param Dungeon_counter 进入副本的次数计数
insert_log_dungeon(PlayerId, DungeonId, First_dungeon_time, Dungeon_counter) ->
	?DB_MODULE:insert(log_dungeon, 
						[player_id, dungeon_id, first_dungeon_time, dungeon_counter],
					  	[PlayerId, DungeonId, First_dungeon_time, Dungeon_counter]).

%% 修改副本进出计数
%% @param PlayerId 玩家ID
%% @param DungeonId 副本ID
%% @param First_dungeon_time 初次进入副本时间
%% @param Dungeon_counter 进入副本的次数计数
update_log_dungeon(PlayerId, DungeonId, First_dungeon_time, Dungeon_counter) ->
	?DB_MODULE:update(log_dungeon, 
						[{first_dungeon_time, First_dungeon_time},
						 {dungeon_counter, Dungeon_counter}	 
						],
						[{player_id, PlayerId}, 
						 {dungeon_id, DungeonId}
						]					  
					  ).

%%%%% end 副本进出计数器

%%%%% begin lib_skill

%% 获取所有技能
%% PlayerId 玩家ID
%%Type:1为基本技能,2为轻功技能，3为被动技能
get_all_skill(PlayerId,Type) ->
	?DB_MODULE:select_all(skill, "skill_id, lv", [{player_id, PlayerId},{type,Type}]).
get_all_skill(PlayerId) ->
	?DB_MODULE:select_all(skill, "skill_id, lv,type", [{player_id, PlayerId}]).

%% 学习技能
%% PlayerId 玩家ID
%% SkillId 技能ID
%% Lv 技能等级
study_skill(PlayerId, SkillId, Lv, Type) ->
	?DB_MODULE:insert(skill, 
					  [player_id, skill_id, lv, type],
					  [PlayerId, SkillId, Lv, Type]).

%% 升级技能
%% PlayerId 玩家ID
%% SkillId 技能ID
%% Lv 技能等级
upgrade_skill(PlayerId, SkillId, Lv) ->
    ?DB_MODULE:update(skill, [{lv, Lv}], [{player_id, PlayerId}, {skill_id, SkillId}]).

%% 更新升级技能所需的消耗,此方法未调用，如果要调采用增量或减量方式更新
%% PlayerId 玩家ID
%% Coin 铜钱
%% Spirit 灵力
update_skill_cost(PlayerId, Coin, Spirit) ->
    ?DB_MODULE:update(player, [{coin, Coin, sub}, {coin_sum, Coin, sub}, {spirit, Spirit}], [{id, PlayerId}]).

%% 删除BUFF技能数据
%% PlayerId 玩家ID
%% SkillId 技能ID
%% Key 技能效果类型
delete_skill_buff(PlayerId, SkillId, Type) ->
    ?DB_MODULE:delete(player_buff, [{player_id, PlayerId}, {skill_id, SkillId}, {type, Type}]).

%% 插入BUFF技能数据
insert_skill_buff(Data) ->
    ?DB_MODULE:insert(player_buff, [player_id, skill_id, type, data], Data).

%% 获取玩家的BUFF信息
get_player_buff_info(PlayerId) ->
    ?DB_MODULE:select_all(player_buff, "*", [{player_id, PlayerId}]).

%%%%% end

%%%%% lib_task

%% 获取任务包信息
get_task_bag_info(PlayerId) ->
	?DB_MODULE:select_all(task_bag, 
						  "id, player_id, task_id, trigger_time, state, end_state, mark,type,other", 
						  [{player_id, PlayerId}]).

%% 删除任务包信息
delete_task_bag(PlayerId) ->
	?DB_MODULE:delete(task_bag, [{player_id, PlayerId}]).

%% 获取任务日志信息
get_task_log_info(PlayerId) ->
	?DB_MODULE:select_all(task_log, 
						  "player_id, task_id,type, trigger_time, finish_time",
						  [{player_id, PlayerId}]).

%% 删除任务日志信息
delete_task_log(PlayerId) ->
	?DB_MODULE:delete(task_log, [{player_id, PlayerId}]).
%%%%%

%%%%% log

%% 装备强化日志
log_stren(Data) -> 
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID, log_stren, 
					  [time, player_id, nickname, gid, goods_id, subtype, level, stren, ratio, ram,stren_fail, stone_id, rune_id,rune_num,prot_id,cost, status],
					  [Time|Data]).
%% 装备鉴定日志
log_identify(Data)->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID, log_identify,
					  [time,player_id,nickname,gid,goods_id,subtype,level,stone_id,cost,status],
					  [Time|Data]).
%% 装备打孔日志
log_hole(Data) ->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID, log_hole, 
					  [time, player_id, nickname, gid, goods_id, subtype,level,hole,cost,status, stone_id],
					  [Time|Data]).


%% 宝石合成日志
log_compose(Data) ->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID,log_compose, 
					  [time, player_id, nickname, goods_id, subtype,stone_num,new_id,rune_id,ratio,ram,cost,status],
					  [Time|Data]).


%% 宝石镶嵌日志
log_inlay(Data) ->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID, log_inlay, 
					  [time, player_id, nickname, gid, goods_id, subtype,level,stone_id,ratio,ram,rune_num,cost,status],
					  [Time|Data]).


%% 宝石拆除日志
log_backout(Data) ->
	Time = util:unixtime(),
	?DB_MODULE:insert(log_backout, 
					  [time, player_id, nickname, gid, goods_id, subtype,level,stone_type,inlay,ratio,ram,rune_num,cost,status],
					  [Time|Data]).


%% 法宝修炼日志
log_practise(Data) ->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID, log_practise,
					  [time,player_id, nickname, gid, goods_id ,step, grade, spirit],
					  [Time|Data]).

%% 法宝融合日志
log_merge(Data) ->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID, log_merge,
					  [time,player_id, nickname, gid_1,goods_id_1,step_1,grade_1,spirit_1,gid_2,goods_id_2,step_2,grade_2,spirit_2],
					  [Time|Data]).

%% 装备洗炼日志
log_wash(Data) ->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID, log_wash, 
					  [time, player_id, nickname, gid, goods_id, subtype,level,color,cost],
					  [Time,lists:nth(1,Data),lists:nth(2,Data),lists:nth(3,Data),lists:nth(4,Data),lists:nth(5,Data),lists:nth(6,Data),lists:nth(7,Data),lists:nth(8,Data)]).

%% 紫装融合日志
log_suitmerge(Data) ->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID, log_suitmerge,
					  [time,player_id,nickname,gid1,goods_id1,gid2,goods_id2,gid3,goods_id3,suit_id,cost],
					  [Time|Data]).

%% 五彩炼炉合成日志
log_icompose(Data) -> 
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID, log_icompose,
					  [time,player_id,nickname,new_id,ratio,ram,cost,status],
					  [Time|Data]).

%% 五彩炼炉分解日志
log_idecompose(Data) ->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID, log_idecompose,
					  [time,player_id,nickname,goods_id,gid,cost,status],
					  [Time|Data]).

%% 精炼日志
log_refine(Data) ->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID, log_refine,
					  [time,player_id,nickname,goods_id,gid,new_id,cost,status],
					  [Time|Data]).

%%淬炼日志
log_smelt(Data)->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID, log_smelt,
					  [time,player_id,nickname,gid,gid_list,goods_id_list,repair],
					  [Time|Data]).

%% 获取消费日志
get_consume_log(WhereList) ->
	?DB_MODULE:select_all(log_consume,"pid,num",WhereList,[],[]).

%% 获取充值日志
get_pay_log(WhereList) ->
	?DB_MODULE:select_all(log_pay,"player_id,pay_gold",WhereList,[],[]).

%% 商店购买日志
log_shop(Data)->
	Time = util:unixtime(),
	?DB_MODULE:insert(log_shop,
					  [shop_type,shop_subtype,player_id,nickname,goods_id,price_type,price,num,time],
					  [lists:nth(1,Data),lists:nth(2, Data),lists:nth(3, Data),lists:nth(4, Data),lists:nth(5, Data),lists:nth(6, Data),lists:nth(7, Data),lists:nth(8, Data),Time]).


%% 物品使用日志
log_use(Data) ->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID, log_use,
					  [player_id,nickname,gid,goods_id,type,subtype,num,time],
					 [lists:nth(1,Data),lists:nth(2, Data),lists:nth(3, Data),lists:nth(4, Data),lists:nth(5, Data),lists:nth(6, Data),lists:nth(7, Data),Time]).
%% 角色升级日志 
log_uplevel(Data)->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID, log_uplevel,
					  [time,player_id,lv,exp,spirit,scene,x,y,add_exp,from],
					  [Time|Data]). 

%% 获取购买记录
get_shop_log(Player_id,Goods_id,Shop_type,Shop_subtype) ->
	?DB_MODULE:select_all(log_shop,
					  "*",[{player_id,Player_id},{goods_id,Goods_id},{shop_type,Shop_type},{shop_subtype,Shop_subtype}],[{time,desc}],[1]
					  ).

%% 物品丢弃日志
log_throw(Data) ->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID, log_throw,
					  [time,player_id,nickname,gid,goods_id,color,stren,bind,type,num,attrs],
					  [Time|Data]).
%%采矿日志
log_ore(Data)->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID, log_ore,
					  [time,goods_id,player_id],
					  [Time|Data]).

%%玩家物品快照
log_goods_list([Player_id,Goods]) ->
	?DB_MODULE:replace(log_goods_list, [{player_id,Player_id}, {goods,Goods}]).

%%获取玩家物品快照
get_log_goods_list(Player_id) ->
	?DB_MODULE:select_row(log_goods_list,"player_id,goods",[{player_id,Player_id}],[],[1]).

%%物品差异记录
log_goods_diff(Data) ->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID, log_goods_diff,
					  [time,player_id,t,goods_id,gid,dnum,mnum],
					  [Time|Data]).

%%70装备炼化日志
log_equipsmelt(Data) ->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID,log_equipsmelt,
					  [time,player_id,nickname,gid,goods_id,jp,my,hf],
					  [Time|Data]
					  ).

%%神器品级提升日志
log_deputy_color(Data) ->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID,log_deputy_color,
					  [time,player_id,nickname,pre_color,color,lucky,stone,stone_num,ratio,ram,cost,status],
					  [Time|Data]
					  ).

%%神器品阶提升日志
log_deputy_step(Data) ->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID,log_deputy_step,
					  [time,player_id,nickname,pre_step,step,lucky,stone,stone_num,ratio,ram,cost,status],
					  [Time|Data]
					  ).

%%神器熟练度提升日志
log_deputy_prof(Data) ->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID,log_deputy_prof,
					  [time,player_id,nickname,stone,stone_num,pre_prof,prof,prof_lv],
					  [Time|Data]
					  ).

%%神器熟练度突破日志
log_deputy_break(Data) ->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID,log_deputy_break,
					  [time,player_id,nickname,pre_lv,lv,lucky,stone,stone_num,ratio,ram,cost,status],
					  [Time|Data]
					  ).

%%神器洗练日志
log_deputy_wash(Data) ->
	Time= util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID,log_deputy_wash,
					  [time,player_id,nickname,att,tmp_att,pre_spirit,spirit,stone,stone_num,cost],
					  [Time|Data]
					  ).

%%神器技能学习日志
log_deputy_skill(Data) ->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID,log_deputy_skill,
					  [time,player_id,nickname,pre_skills,skills,pre_culture,culture,cost],
					  [Time|Data]
					  ).
%%

%%%%%



%%%%% yg_gateway

%% 是否创建角色
is_create(Accname) ->
	?DB_MODULE:select_all(player, "id", [{accname, Accname}], [], [1]).
%%%%%

%%%%% mod_disperse

%%加入服务器集群
add_server([Ip, Port, Sid, Node]) ->
	?DB_MODULE:replace(server, 	[{id, Sid},  {ip, Ip}, {port, Port}, {node, Node}, {num,0}]).

%%退出服务器集群
del_server(Sid) ->
	?DB_MODULE:delete(server, [{id, Sid}]).

%% 获取所有服务器集群
select_all_server() ->
	?DB_MODULE:select_all(server, "*", []).

%%%%%

%%%%% mod_goods

%% 穿在身上的装备耐久减1
mg_deduct_goods_use1(PlayerId, Equip, UseNum) ->
	?DB_MODULE:update(goods, 
								 [{use_num, UseNum, sub}], 
								 [{player_id, PlayerId},
								  {location, Equip},
								  {type, 10},
								  {use_num, ">", UseNum},
								  {attrition, ">", 0}]).

mg_deduct_goods_use2(PlayerId, Equip, UseNum) ->
	?DB_MODULE:update(goods, 
								 [{use_num, 0}], 
								 [{player_id, PlayerId},
								  {location, Equip},
								  {type, 10},
								  {use_num, "<=", UseNum},
								  {use_num, ">", 0},
								  {attrition, ">", 0}]).
%%%%%


%%%%% mod_player

%% 保存玩家基本信息
save_player_table(PlayerId, FieldList, ValueList)->
	?DB_MODULE:update(player, FieldList, ValueList, "id", PlayerId).

%% 同步任务数据(插入任务日志)
syn_db_task_log_insert(Data)->
	?DB_MODULE:insert(task_log, [player_id, task_id,type, trigger_time, finish_time], Data).

%% 同步任务数据（插入任务信息包）
syn_db_task_bag_insert(Data)->
	[Rid, Tid, TriggerTime, TaskState, TaskEndState, TaskMark,TaskType,Other] = Data ,
	?DB_MODULE:insert(task_bag,
								 [player_id, task_id, trigger_time, state, end_state, mark,type,other],
								 [Rid, Tid, TriggerTime, TaskState, TaskEndState, util:term_to_string(TaskMark),TaskType,util:term_to_string(Other)]).

%% 同步任务数据（更新任务信息包）
syn_db_task_bag_update(Data)->
	[State, Mark, RoleId, TaskId] = Data,
	?DB_MODULE:update(task_bag, 
								 [{state, State},
								  {mark, util:term_to_string(Mark)}], 
								 [{player_id, RoleId},
								  {task_id, TaskId}]).

%% 同步任务数据（删除任务信息包）
syn_db_task_bag_delete(Data)->
	[RoleId, TaskId] = Data,
	?DB_MODULE:delete(task_bag, 
								 [{player_id, RoleId},
								  {task_id, TaskId},
								  {state,"<>",2}]).

%% 同步任务数据（删除任务日志）
syn_db_task_log_delete(Data)->
	[RoleId, TaskId] = Data,
	?DB_MODULE:delete(task_log, 
								 [{player_id, RoleId},
								  {task_id, TaskId}]).

%%根据id删除任务数据
del_task_by_id(Id)->
	?DB_MODULE:delete(task_bag, [{id, Id}]).

%%获取委托任务的自增id
get_task_auto_id(PlayerId,TaskId)->
	?DB_MODULE:select_one(task_bag, "id", [{player_id,PlayerId},{task_id,TaskId},{state,"<>",2}], [], [1]).

get_task_auto_id(PlayerId,TaskId,Timestamp)->
	?DB_MODULE:select_one(task_bag, "id", [{player_id,PlayerId},{task_id,TaskId},{trigger_time,Timestamp}], [], [1]).

%%修改任务状态
update_task_state(Id,State)->
	?DB_MODULE:update(task_bag, 
								 [{state, State}], 
								 [{id, Id}]).
%%根据自增id获取任务
get_task_by_auto_id(Id)->
	Ret = ?DB_MODULE:select_one(task_bag, 
								 "trigger_time", 
								 [{id, Id}],
						  		[],
						  		[1]
						  		),
	case Ret of
		null -> [];
		_ -> [Ret]
	end.

%%删除任务日志
del_task_log(PlayerId,TaskId,TriggerTime)->
	?DB_MODULE:delete(task_log, 
							 [{player_id, PlayerId},
							  {task_id,TaskId},
							  {trigger_time,TriggerTime}]).

%%添加委托任务
insert_consign_task(PlayerId,TaskId,Times,Timestamp,Exp,Spt,Cul,Gold)->
	Consign_Task  = #ets_task_consign{
						player_id = PlayerId,
						task_id = TaskId,
						timestamp = Timestamp,
						times = Times,
						exp = Exp,
						spt = Spt,
						cul = Cul,
						gold = Gold					
						},
    ValueList = lists:nthtail(2, tuple_to_list(Consign_Task)),
    [id | FieldList] = record_info(fields, ets_task_consign),
	Ret = ?DB_MODULE:insert(task_consign, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.


%%删除单个委托任务
delete_consign_task(PlayerId,TaskId,Timestamp)->
	?DB_MODULE:delete(task_consign, [{player_id, PlayerId}, {task_id, TaskId}, {timestamp,Timestamp}]).

%%删除委托任务
delete_consign_task_all(PlayerId)->
	?DB_MODULE:delete(task_consign, [{player_id, PlayerId}]).


%%获取委托任务
get_consign_task(PlayerId)->
	?DB_MODULE:select_all(task_consign, 
								 "id ,player_id,task_id ,exp,spt,cul,gold,times,timestamp", 
								 [{player_id,PlayerId}]).

%%委托任务日志
consign_task_log(PlayerId,TaskText,Gold,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID, log_consign, 
					  	[pid, consign, gold, timestamp],
					  	[PlayerId, TaskText, Gold, Timestamp]).

%%加载玩家委托的任务
init_consign_task()->
	?DB_MODULE:select_all(consign_task, "*", [{pid,">",0}]).


%%添加委托任务
new_consign_task(DataBag)->
	[PlayerId,TaskId,Name,Lv,Time,GoodsId_1,Num_1,GoodsId_2,Num_2,MoneyType,Num_3,Timestamp,AutoId]=DataBag,
	Consign_Task  = #ets_consign_task{
						pid = PlayerId,
						tid = TaskId,
						name = Name,
						lv = Lv,
						t1 = Time,
						gid_1 = GoodsId_1,
						n_1 = Num_1,
						gid_2 = GoodsId_2,
						n_2 = Num_2,
						mt = MoneyType,
						n_3 = Num_3,
						autoid=AutoId,
						t2 = Timestamp	
						},
    ValueList = lists:nthtail(2, tuple_to_list(Consign_Task)),
    [id | FieldList] = record_info(fields, ets_consign_task),
	Ret = ?DB_MODULE:insert(consign_task, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.

%%雇佣日志
employ_log(TaskBag)->
	[PlayerId,TaskId,_Name,_Lv,_Time,GoodsId_1,Num_1,GoodsId_2,Num_2,MoneyType,Num_3,Timestamp,_AutoId]=TaskBag,
	?DB_MODULE:insert(?LOG_POOLID, log_employ, 
						[pid, tid, gid1, num1, gid2, num2, money, num3, timestamp],
					  	[PlayerId, TaskId, GoodsId_1, Num_1, GoodsId_2, Num_2, MoneyType, Num_3, Timestamp]).
%%删除委托任务
del_task_consign(Id)->
	?DB_MODULE:delete(consign_task, [{id, Id}]).


%%接受委托任务
accept_consign_task(PlayerId,Timestamp,Id)->
%% 	io:format("accept_consign_task11221~n"),
	?DB_MODULE:update(consign_task,
					  [{aid,PlayerId},
					   {t3,Timestamp},
					   {state,1}],
					  [{id,Id}]).
%%更新委托任务状态
update_consign_state(Id,State)->
	?DB_MODULE:update(consign_task,
					  [{state,State}],
					  [{id,Id}]).

%%重置委托任务
reset_consign_task(Id)->
	?DB_MODULE:update(consign_task,
					  [{state,0},
					   {aid,0},
					   {t3,0}],
					  [{id,Id}]).
%%加载玩家委托信息
init_consign_player_info(PlayerId)->
	?DB_MODULE:select_row(consign_player, 
								 "id,pid,publish,pt,accept,at,timestamp", 
								 [{pid,PlayerId}]).

%%添加玩家委托信息
new_consign_player_info(PlayerId,Timestamp)->
	Consign_Player  = #ets_consign_player{
						pid = PlayerId,
						at = Timestamp,
						pt = Timestamp
						},
    ValueList = lists:nthtail(2, tuple_to_list(Consign_Player)),
    [id | FieldList] = record_info(fields, ets_consign_player),
	Ret = ?DB_MODULE:insert(consign_player, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.

%%更新玩家发布次数和时间
update_consign_publish(PlayerId,Times,Timestamp)->
	?DB_MODULE:update(consign_player,
					  [{publish,Times},
					   {pt,Timestamp}],
					  [{pid,PlayerId}]).

%%更新玩家接受次数和时间
update_consign_accept(PlayerId,Times,Timestamp)->
	?DB_MODULE:update(consign_player,
					  [{accept,Times},
					   {at,Timestamp}],
					  [{pid,PlayerId}]).

%%重置发布和接受的次数
reset_consign_times(PlayerId,Timestamp)->
	?DB_MODULE:update(consign_player,
					  [
					   {publish,0},
					   {pt,Timestamp},
					   {accept,0},
					   {at,Timestamp}],
					  [{pid,PlayerId}]).

%%获取玩家委托奖励
select_consign_award(PlayerId)->
	?DB_MODULE:select_row(consign_player, 
								 "exp,spt,cul,coin,bcoin,ge,gc", 
								 [{pid,PlayerId}]).

%%更新玩家委托奖励
update_consign_award(PlayerId,AwardBag)->
	[Exp,Spt,Cul,Coin,Bcoin,Ge,Gc] = AwardBag,
	?DB_MODULE:update(consign_player,
					  [{exp,Exp,add},
					   {spt,Spt,add},
					   {cul,Cul,add},
					   {coin,Coin,add},
					   {bcoin,Bcoin,add},
					   {ge,Ge,add},
					   {gc,Gc,add}],
					  [{pid,PlayerId}]).


%%重置玩家委托奖励
reset_consign_award(PlayerId)->
	?DB_MODULE:update(consign_player,
					  [{exp,0},
					   {spt,0},
					   {cul,0},
					   {coin,0},
					   {bcoin,0},
					   {ge,0},
					   {gc,0}],
					  [{pid,PlayerId}]).

%%离线经验累积
%%加载玩家离线经验累积信息
init_offline_award(PlayerId)->
	?DB_MODULE:select_row(offline_award, 
								 "id,pid,total,exc_t,offline_t", 
								 [{pid,PlayerId}]).

%%添加玩家离线累积信息
new_offline_award(PlayerId,Timestamp)->
	Offline  = #ets_offline_award{
						pid = PlayerId,
						offline_t = Timestamp,
						exc_t = Timestamp
						},
    ValueList = lists:nthtail(2, tuple_to_list(Offline)),
    [id | FieldList] = record_info(fields, ets_offline_award),
	Ret = ?DB_MODULE:insert(offline_award, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.

%%更新凝神时间
update_offline_exc(PlayerId,Timestamp)->
	?DB_MODULE:update(offline_award,
					  [{exc_t,Timestamp}
					   ],
					  [{pid,PlayerId}]).

%%更新离线时间
update_offline_time(PlayerId,Timestamp)->
	?DB_MODULE:update(offline_award,
					  [{offline_t,Timestamp}
					   ],
					  [{pid,PlayerId}]).


%%玩家上线
update_offline_award(PlayerId,Total,NowTime)->
	?DB_MODULE:update(offline_award,
					  [{total,Total},
					   {offline_t,NowTime},
					   {exc_t,NowTime}
					   ],
					  [{pid,PlayerId}]).

%%兑换离线凝神日志
log_offline_award(LogBag)->
	[Pid,Hour,Mult,Exp,Timestamp]=LogBag,
	?DB_MODULE:insert(?LOG_POOLID, log_offline_award, 
						[pid, hour, mult, exp, timestamp],
					  	[Pid, Hour, Mult, Exp, Timestamp]).
%%连续登陆奖励
%%加载玩家离线经验累积信息
init_online_award(PlayerId)->
	?DB_MODULE:select_row(online_award, 
								 "*", 
								 [{pid,PlayerId}]).

%%添加玩家委托信息
new_online_award(PlayerId,Lv,Timestamp,GoodsBag)->
	[G4,G8,G12] = GoodsBag,
	Online  = #ets_online_award{
						pid = PlayerId,
						lv = Lv,
						d_t = Timestamp,
						g4 = G4,
						g8 = G8,
						g12 = G12,
						h_t = Timestamp,
						w_t = Timestamp,
						m_t = Timestamp
						},
    ValueList = lists:nthtail(2, tuple_to_list(Online)),
    [id | FieldList] = record_info(fields, ets_online_award),
	Ret = ?DB_MODULE:insert(online_award, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.
%%玩家上线，更新在线数据
update_online_award(OnlineBag)->
	[_Id,PlayerId,Lv,Day,DTime,G4,G4Mark,G8,G8Mark,G12,G12Mark,
	Hour,HTime,HMark,Week,WTime,WMark,Mon,MTime,MMark]=OnlineBag,
	?DB_MODULE:update(online_award,
					  [ 
      					{pid,PlayerId},                                %% 玩家id	
						{lv,Lv},
      					{day,Day},                                %% 连续上线天数	
      					{d_t,DTime},                                %% 连续上线时间戳	
      					{g4,G4},                                 %% 第四天物品	
      					{g4_m,G4Mark},                               %% 第四天物品领取标记	
      					{g8,G8},                                 %% 第八天物品	
      					{g8_m,G8Mark},                               %% 第八天物品领取标记	
      					{g12,G12},                                %% 第十二天物品	
      					{g12_m,G12Mark},                              %% 第十二天物品领取标记	
      					{hour,Hour},                               %% 当天在线时间(S)	
      					{h_t,HTime},                                %% 天时间戳	
      					{h_m,HMark},                                %% 天奖励领取时间戳	
     					{week,Week},                               %% 每周在线时间(S)	
      					{w_t,WTime},                                %% 周时间戳	
      					{w_m,WMark},                                %% 周奖励领取标记	
      					{mon,Mon},                                %% 当月在线时间(S)	
      					{m_t,MTime},                                %% 月时间戳	
      					{m_m,MMark}            
					   ],
					  [{pid,PlayerId}]).

%%重置连续上线物品奖励
reset_online_award_goods(PlayerId,Lv,Timestamp,GoodsBag)->
	[G4,G8,G12] = GoodsBag,
	?DB_MODULE:update(online_award,
					  [{lv,Lv},
					   {day,0},
					   {d_t,Timestamp},
					   {g4,G4},
					   {g4_m,0},
					   {g8,G8},
					   {g8_m,0},
					   {g12,G12},
					   {g12_m,0}
					   ],
					  [{pid,PlayerId}]).

reset_online_award_day(PlayerId,GoodsBag)->
	[NewDay,NewDTime,NewG4,NewG4Mark,NewG8,NewG8Mark,NewG12,NewG12Mark] = GoodsBag,
	?DB_MODULE:update(online_award,
					  [{day,NewDay},
					   {d_t,NewDTime},
					   {g4,NewG4},
					   {g4_m,NewG4Mark},
					   {g8,NewG8},
					   {g8_m,NewG8Mark},
					   {g12,NewG12},
					   {g12_m,NewG12Mark}
					   ],
					  [{pid,PlayerId}]).

reset_online_award_time(PlayerId,TimeBag)->
	[Hour,HTime,Week,WTime,WMark,Mon,MTime,MMark] = TimeBag,
	?DB_MODULE:update(online_award,
					  [{hour,Hour},                               %% 当天在线时间(S)	
      					{h_t,HTime},                                %% 天时间戳	
     					{week,Week},                               %% 每周在线时间(S)	
      					{w_t,WTime},                                %% 周时间戳	
      					{w_m,WMark},                                %% 周奖励领取标记	
      					{mon,Mon},                                %% 当月在线时间(S)	
      					{m_t,MTime},                                %% 月时间戳	
      					{m_m,MMark}   
					   ],
					  [{pid,PlayerId}]).

%%领取物品标记
update_online_award_goods(PlayerId,TypeMark)->
	?DB_MODULE:update(online_award,
					  [{TypeMark,1}],
					  [{pid,PlayerId}]).
%%当天在线兑换礼券
update_online_award_hour(PlayerId,Hour,Timestamp)->
	?DB_MODULE:update(online_award,
					  [{hour,Hour},
					   {h_t,Timestamp}],
					  [{pid,PlayerId}]).
%%领取七天，三十天奖励标记
update_online_award_cash(PlayerId,TypeMark,Num)->
	?DB_MODULE:update(online_award,
					  [{TypeMark,Num}],
					  [{pid,PlayerId}]).
%%玩家下线，更新在线时间
update_online_award_time(PlayerId,Hour,Week,Mon)->
	?DB_MODULE:update(online_award,
					  [{hour,Hour},
					   {week,Week},
					   {mon,Mon}],
					  [{pid,PlayerId}]).

%%玩家上线，更新连续在线天数
update_online_award_date(PlayerId,Day)->
	?DB_MODULE:update(online_award,
					  [{day,Day}],
					  [{pid,PlayerId}]).

%%兑换物品日志
log_online_goods(LogBag)->
	[Pid,Goods,Num,Day,Timestamp]=LogBag,
	?DB_MODULE:insert(?LOG_POOLID, log_online_goods, 
						[pid, goods, num, day, timestamp],
					  	[Pid, Goods, Num, Day, Timestamp]).
%%兑换礼券日志
log_online_cash(LogBag)->
	[Pid,Hour,Cash,Type,Timestamp]=LogBag,
	?DB_MODULE:insert(?LOG_POOLID, log_online_cash, 
						[pid, hour, cash, type, timestamp],
					  	[Pid, Hour, Cash, Type, Timestamp]).

%%获取单个玩家每日在线奖励信息表
find_single_award(PlayerId) ->
	?DB_MODULE:select_row(daily_online_award, "pid, gain_times, timestamp", [{pid,PlayerId}], [], [1]).

%%增加玩家每日领奖信息记录
add_award_record(PlayerId, GainTimes, TimeStamp) ->
	?DB_MODULE:insert(daily_online_award,
					  [pid, gain_times, timestamp],
					  [PlayerId, GainTimes, TimeStamp]).

%%更新每日在线奖励信息表
update_daily_award(PlayerId, Times, Tiemstamp) ->
	?DB_MODULE:update(daily_online_award, [{gain_times, Times}, {timestamp, Tiemstamp}], [{pid, PlayerId}]).

%%获取每日在线奖励物品表
query_daily_award_goods() ->
	?DB_MODULE:select_all(base_daily_gift, "*", []).

%%增加每日在线奖励日志记录
log_daily_award(PlayerId, GoodsId, Num, GainTimes, TimeStamp) ->
	?DB_MODULE:insert(?LOG_POOLID, log_daily_award,
					  [pid, goods_id, num, gain_times, timestamp],
					  [PlayerId, GoodsId, Num, GainTimes, TimeStamp]).
%%%%% pp_chat

%% 删除指定玩家任务包
pc_del_task_bag(PlayerId) ->
	?DB_MODULE:delete(task_bag, [{player_id, PlayerId}]).

%% 删除指定玩家的任务日志
pc_del_task_log(PlayerId) ->
	?DB_MODULE:delete(task_log, [{player_id, PlayerId}]).


%%%%%
%%%%%	mod_sale
%%加载所有的交易市场记录
load_all_sale() ->
	?DB_MODULE:select_all(sale_goods, 
						  "id,sale_type,gid,goods_id,goods_name,goods_type,goods_subtype,player_id,player_name,num,career,goods_level,goods_color,price_type,price,sale_time,sale_start_time, md5_key", 
						  [{player_id,">",0}]).

load_all_sale_goods() ->
	?DB_MODULE:select_all(goods,"*", [{player_id, 0}]).

load_all_sale_goods_attributes(GId) ->
	?DB_MODULE:select_all(goods_attribute, "*", [{gid, GId}]).
	

%%向sale_goods表插入拍卖纪录数据
sale_goods(SaleGoodsValueList) ->
	ValueList = lists:nthtail(3, tuple_to_list(SaleGoodsValueList)),
	FieldList = [sale_type,gid,goods_id,goods_name,goods_type,goods_subtype,player_id,player_name,num,career,
				 goods_level,goods_color,price_type,price,sale_time,sale_start_time, md5_key],
	Ret = ?DB_MODULE:insert(sale_goods, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			Ret;
		_ ->
			{mongo, Ret}
	end.

%%获取指定的物品ID的拍卖纪录
get_sale_goods_info(GoodsId, PlayerId) ->
	WhereFieldList = [{gid, GoodsId}, {player_id, PlayerId}],
	?DB_MODULE:select_one(sale_goods, "id", WhereFieldList, [{id, desc}], [1]).

%%更新交易角色名
change_sale_goods_name(PlayerId,NickName) ->
	?DB_MODULE:update(sale_goods, [{player_name, NickName}], [{player_id,PlayerId}]).

%%物品被拍卖，修改物品goods表所属playerid	
update_goods_owner(GoodsValueList, GoodsWhereList) ->
	?DB_MODULE:update(goods, GoodsValueList, GoodsWhereList).

%%物品被拍卖，修改物品goods_attribute表所属playerid	
update_goods_attribute_owner(GoodsAttributeValue, GoodsAttributeWhereList) ->
	?DB_MODULE:update(goods_attribute, GoodsAttributeValue, GoodsAttributeWhereList).

%%取消拍卖，因此删除拍卖纪录
delete_sale_goods_record(DeleteSaleGoodsList) ->
	?DB_MODULE:delete(sale_goods, DeleteSaleGoodsList).

%%插拍卖成交的日志纪录
mark_sale_deal(FieldsList, ValuesList) ->
	?DB_MODULE:insert(?LOG_POOLID, log_sale, FieldsList, ValuesList).

%%出入拍卖的记录流向
insert_sale_flow_record(FlowRecord) ->
	ValueList = lists:nthtail(2, tuple_to_list(FlowRecord)),
	[id | FieldList] = record_info(fields, ets_log_sale_dir),
	?DB_MODULE:insert(?LOG_POOLID, log_sale_dir, FieldList, ValueList).

%%获取拍卖物品的类型ie和所属人物ID
get_sale_goods_id(GoodsId) ->
	?DB_MODULE:select_row(goods, "player_id, goods_id", 
						  [{id, GoodsId}], 
						  [],
						  [1]). 
%%查询所有的市场求购数据
load_all_buy_goods() ->
	?DB_MODULE:select_all(buy_goods, 
						  "id,pid,pname,buy_type,gid,gname,gtype,gsubtype,num,career,glv,gcolor,gstren,gattr,unprice,price_type,continue,buy_time", 
						  [{id,">",0}]).

%%插入求购数据记录
insert_buy_goods(FieldList, ValueList) ->
	?DB_MODULE:insert(buy_goods, FieldList, ValueList).

%%删除相关的求购记录
delete_buy_goods_record(WhereList) ->
	?DB_MODULE:delete(buy_goods, WhereList).

%%更新对应的求购记录数据
update_buy_goods(WhereList, ValueList) ->
	?DB_MODULE:update(player, ValueList, WhereList).
buy_update_goods(Gid) ->
	?DB_MODULE:update(goods_attribute,
					  [{player_id, 0}],
					  [{gid, Gid}]
					 ),
	?DB_MODULE:update(goods,
					  [{player_id, 0},
					   {cell, 0}],
					  [{id, Gid}]
					 ).
%%求购记录日志 
insert_log_buy_goods(LogBuyGoods) ->
	ValueList = lists:nthtail(2, tuple_to_list(LogBuyGoods)),
	[id | FieldList] = record_info(fields, log_buy_goods),
	?DB_MODULE:insert(?LOG_POOLID, log_buy_goods, FieldList, ValueList).
%%%%%

%% 更新玩家的信息
mm_update_player_info(ValueList, WhereList) ->
    ?DB_MODULE:update(player, ValueList, WhereList).

%%gm测试命令
test_update_player_info(ValueList, WhereList) ->
	?DB_MODULE:update(player, ValueList, WhereList).

test_get_scene_byname(Name) ->
	?DB_MODULE:select_row(base_scene, 
								 "sid ,name, x , y", 
								 [{sid,">",0},{name, Name}]).

test_get_scene_byid(Id) ->
	?DB_MODULE:select_row(base_scene, 
								 "sid ,name, x , y", 
								 [{sid, Id}]).
get_mon_exp_by_id(Id)->
  Ret = ?DB_MODULE:select_one(base_mon,"exp",[{mid,Id}]),
  case Ret of
	  null -> [];
	  _ -> [Ret]
  end.

%%新添在线奖励玩家信息
create_online_gift_info(PlayerId,Timestamp)->
	Online_gift  = #ets_online_gift{
						player_id = PlayerId,
						timestamp = Timestamp,
						times = 0									
						},
    ValueList = lists:nthtail(2, tuple_to_list(Online_gift)),
    [id | FieldList] = record_info(fields, ets_online_gift),
	?DB_MODULE:insert(online_gift, FieldList, ValueList).

%%删除玩家奖励记录
delete_online_gift_info(PlayerId)->
	?DB_MODULE:delete(online_gift,[{player_id,PlayerId}]).

%%获取在线奖励玩家信息
select_online_gift_info(PlayerId)->
	?DB_MODULE:select_row(online_gift, 
								 "id, player_id, times, timestamp", 
								 [{player_id, PlayerId}],
						  		[],
						  		[1]
						  		).
 

%%更新在线奖励玩家信息
update_online_gift_info(PlayerId,Timestamp) ->
	?DB_MODULE:update(online_gift,
								 [{times,1,add}, {timestamp,Timestamp}],
					             [{player_id,PlayerId}]
								 ).
%%在线奖励命令专用
gm_update_online_gift_info(PlayerId,Timestamp,Times) ->
	?DB_MODULE:update(online_gift,
								 [{times,Times}, {timestamp,Timestamp}],
					             [{player_id,PlayerId}]
								 ).

%%玩家登陆重置奖励信息
reset_online_gift_info(PlayerId,Timestamp)->
	?DB_MODULE:update(online_gift,
								 [{timestamp,Timestamp}],
								 [{player_id,PlayerId}]
								 ).

%%获取在线奖励物品信息
get_online_gift(Times)->
	?DB_MODULE:select_row(base_online_gift,
								 "*",
								 [{times,Times}]								
								).

%%领取在线奖励日志
log_online_gift(PlayerId,GoodsId,Num,Times,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID, log_online_gift,
					  [pid, goods_id, num, times, timestamp],
					  [PlayerId, GoodsId, Num, Times, Timestamp]).

%%新添目标奖励玩家信息
create_target_gift_info(PlayerId)->
	Target_gift = #ets_target_gift{
					player_id = PlayerId
							},
    ValueList = lists:nthtail(2, tuple_to_list(Target_gift)),
	[id | FieldList] = record_info(fields, ets_target_gift),
	?DB_MODULE:insert(target_gift, FieldList, ValueList).


%%删除玩家目标奖励记录
delete_target_gift_info(PlayerId)->
	?DB_MODULE:delete(target_gift,[{player_id,PlayerId}]).

%%获取目标奖励玩家信息
select_target_gift_info(PlayerId)->
	?DB_MODULE:select_row(target_gift, 
								 "*", 
								 [{player_id, PlayerId}],
						  		[],
						  		[1]
						  		).
 

%%更新目标奖励玩家信息
update_target_gift_info(PlayerId,Type) ->
	?DB_MODULE:update(target_gift,
								 [{Type,1}],
								[{player_id,PlayerId}]
								 ).

%%领取目标奖励日志
log_target_gift(PlayerId,Day,Times,Cash,Goods,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID, log_target_gift,
					  [pid, day, times, cash, goods, time],
					  [PlayerId, Day, Times, Cash, Goods, Timestamp]).
%%更新国运时间
update_carry_time(Realm,Num,TimeStart,TimeEnd,Timestamp)->
	?DB_MODULE:update(base_carry,
								 [{start_time,TimeStart},  {seq,Num}, {end_time,TimeEnd}, {timestamp,Timestamp}],
								 [{realm,Realm}]
								 ).

%%获取国运时间信息
get_carry_time({realm,Realm}) ->
	?DB_MODULE:select_row(base_carry,
								 "*",
								 [{realm,Realm}]
								 );

get_carry_time({seq,Seq}) ->
	?DB_MODULE:select_row(base_carry,
								 "*",
								 [{seq,Seq}]
								 ).

%%获取指定部落人数
get_realm(Realm)->
	Ret =
		case ?DB_MODULE =:= db_mysql of
			true ->
    			?DB_MODULE:select_count(player,[{realm, Realm}]);
			_ ->			%% 获取部落计数器
				?DB_MODULE:select_row(auto_ids,"num",[{name,lists:concat(["realm_",Realm])}])
		end,
	case Ret of
		[] ->0;
		[Num]-> Num
	end.

%%更新部落统计人数
update_realm(Realm)->
	case ?DB_MODULE =:= db_mysql of
		true ->
		   skip;
	   _->
			?DB_MODULE:findAndModify("auto_ids", lists:concat(["realm_",Realm]), "num")
	end.

%%获取充值玩家列表
get_pay_player()->
	?DB_MODULE:select_all(log_pay,"player_id",[]).
%%获取充值玩家阵营列表
get_pay_player_realm(PlayerIdList)->
	?DB_MODULE:select_all(player,"realm",[{id,"in",PlayerIdList}]).
%%获取玩家累计充值
get_player_pay(PlayerId,Timestamp) ->
	?DB_MODULE:select_all(log_pay,"pay_gold",[{player_id,PlayerId},{pay_status,1},{insert_time,"<=",Timestamp}]).

%%获取唯一副本ID(仅mongodb时使用)
get_unique_dungeon_id(SceneId)->
	AutoId = ?DB_MODULE:findAndModify("auto_ids", "dungeon_id", "counter"),
	NewAutoId = 
		if 
			AutoId > 210000 ->
				?DB_MODULE:update(auto_ids, [{counter, 1}], [{name, "dungeon_id"}]),	   
		   		1;
	   		true -> 
				AutoId
		end,
	lib_scene:create_unique_scene_id(SceneId, NewAutoId).

%% %%获取唯一封神台ID(仅mongodb时使用)
%% get_unique_fst_id(SceneId)->
%% 	AutoId = ?DB_MODULE:findAndModify("auto_ids", "fst_id", "counter"),
%% 	NewAutoId = if AutoId > 420000 ->
%% 					?DB_MODULE:update(auto_ids,
%% 								 [{counter, 1}],
%% 								 [{name, "fst_id"}]
%% 								 ),	   
%% 		   				1;
%% 	   				true -> AutoId
%% 				end,
%% 	lib_scene:create_unique_scene_id(SceneId, NewAutoId).
%% 
%% %%获取唯一封神台ID(仅mongodb时使用)
%% get_unique_td_id(SceneId)->
%% 	AutoId = ?DB_MODULE:findAndModify("auto_ids", "td_id", "counter"),
%% 	NewAutoId = if AutoId > 420000 ->
%% 					?DB_MODULE:update(auto_ids,
%% 								 [{counter, 1}],
%% 								 [{name, "td_id"}]
%% 								 ),	   
%% 		   				1;
%% 	   				true -> AutoId
%% 				end,
%% 	lib_scene:create_unique_scene_id(SceneId, NewAutoId).

%%==================================== the trade transaction begin ======================================
%%直接操作数据库,修改物品和金币铜钱的交易,执行一个事务操作
commint_trade(ResultDB, APlayerId, BPlayerId, ABCoinGold) ->
	{AGold,ACoin,BGold,BCoin} = ABCoinGold,%%玩家交易前的元宝铜币
	?DB_MODULE:transaction(
	  fun() ->
			  {DBAGold, DBACoin, DBBGold, DBBCoin, DBGoodsRecord} = ResultDB,
			  %%更新玩家金币和铜币数据
			  spawn(fun()-> commint_trade_gold(AGold, DBAGold, APlayerId) end),
			  spawn(fun()-> commint_trade_gold(BGold, DBBGold, BPlayerId) end),
			  spawn(fun()-> commint_trade_coin(ACoin, DBACoin, APlayerId) end),
			  spawn(fun()-> commint_trade_coin(BCoin, DBBCoin, BPlayerId) end),
			  %%更新物品数据
			  lists:foreach(fun(DBElem) ->
								spawn(fun() ->
									{[{player_id, DBPlayerId}, {cell, DBCell}], [{id, DBGoodsId}]} = DBElem,
									?DB_MODULE:update(goods, [{player_id, DBPlayerId}, {cell, DBCell}], [{id, DBGoodsId}]),
									?DB_MODULE:update(goods_attribute, [{player_id, DBPlayerId}], [{gid, DBGoodsId}])
								end)
							end, DBGoodsRecord)
	  end).

commint_trade_gold(OldGold, Gold, PlayerId) ->
	if 
		Gold > 0  ->
			spawn(fun()-> consume_log(1808, PlayerId, gold, OldGold, Gold, 1) end),
			?DB_MODULE:update(player, [{gold, Gold, add}], [{id, PlayerId}]);
		Gold < 0  ->
			NewGold = abs(Gold),
			spawn(fun()-> consume_log(1808, PlayerId, gold, OldGold, NewGold, 0) end),
			?DB_MODULE:update(player, [{gold, NewGold, sub}], [{id, PlayerId}]);
		true ->
			no_action
	end.

commint_trade_coin(OldCoin, Coin, PlayerId) ->
	if
		Coin > 0 ->
			spawn(fun()-> consume_log(1808, PlayerId, coinonly, OldCoin, Coin, 1) end),
			?DB_MODULE:update(player, [{coin, Coin, add},{coin_sum, Coin, add}], [{id, PlayerId}]);
		Coin < 0 ->
			NewCoin = abs(Coin),
			spawn(fun()-> consume_log(1808, PlayerId, coinonly, OldCoin, NewCoin, 0) end),
			?DB_MODULE:update(player, [{coin, NewCoin, sub},{coin_sum, NewCoin, sub}], [{id, PlayerId}]);
		true ->
			noaction
	end.
%%=============================================== end ===================================================

%%添加交易的日志记录
mark_trade_deal(Table, FieldsList, ValuesList) ->
	?DB_MODULE:insert(?LOG_POOLID, Table, FieldsList, ValuesList).

get_player_coin_gold(PlayerId) ->
	?DB_MODULE:select_row(player, "coin, gold", [{id, PlayerId}]).

%%诛邪系统
%%load诛邪的所有的物品信息
load_all_box() ->
	?DB_MODULE:select_all(base_box_goods, "*", [{goods_id,">",0}]).

%%load对应的在系统广播出现的诛邪记录
load_log_box_open(Table, WhereList) ->
  	?DB_MODULE:select_all(Table, "*", WhereList, [{open_time, desc}], [100]).


%%取得玩家指定单一属性值
get_player_properties(Properties,PlayerId) ->
	?DB_MODULE:select_one(player, ""++tool:to_list(Properties), [{id, PlayerId}]).

get_master_apprentice_properties(Properties,PlayerId) ->
	?DB_MODULE:select_one(master_apprentice, ""++tool:to_list(Properties), [{apprentenice_id, PlayerId}]).

get_master_apprentice_info(PlayerId) ->
	?DB_MODULE:select_row(master_apprentice, "lv, status, master_id", [{apprentenice_id, PlayerId}]).

get_master_charts_properties(Properties,PlayerId) ->
	?DB_MODULE:select_one(master_charts, ""++tool:to_list(Properties), [{master_id, PlayerId}]).

%%取最后的入门时间和最后报告时间
get_master_apprenticetimes(PlayerId) ->
	?DB_MODULE:select_row(master_apprentice, "join_time, last_report_time", [{apprentenice_id, PlayerId}]).

get_master_charts(Properties,PlayerId) ->
	?DB_MODULE:select_one(master_charts, ""++tool:to_list(Properties), [{master_id, PlayerId}]).

%% 更新伯乐榜徒弟数量
update_apprentice_sum(PlayerId) ->
	[Sum] = ?DB_MODULE:select_count(master_apprentice, [{master_id,PlayerId}]),
	?DB_MODULE:update(master_charts,[{appre_num,Sum}],[{master_id,PlayerId}]).
	

%%%%%begin 师徒关系
%%加载所有的师徒记录
load_master_apprentice() ->
	?DB_MODULE:select_all(master_apprentice, "*", []).

%%加载所有的师傅数据,注当有limit时，orderby加上排序字段才有效,而且最好是两个排序字段，不能只用有索引的字段排序
load_master_charts(PageNumber) ->
    case ?DB_MODULE =:= db_mysql of
		true -> 
			?DB_MODULE:select_all(master_charts,"*", [{lover_type,1}],[{award_count, desc}],[10]);
		_ ->
			?DB_MODULE:select_all(master_charts,"*", [{lover_type,1}],[{online,desc},{appre_num,asc}],[10,(PageNumber-1)*10])
	end.

update_master_charts_online(Master_Id,State)->
	case get_master_charts(Master_Id) of
		[]->skip;
		_->
			?DB_MODULE:update(master_charts,[{online,State}],[{master_id,Master_Id}])
	end.

load_master_charts_count() ->
	?DB_MODULE:select_count(master_charts,[{lover_type,1}]).

%%加载所有的师傅数据
load_master_charts() ->
	?DB_MODULE:select_all(master_charts,"*", [{lover_type,1}]).

%%创建徒弟表数据
create_master_apprentice(Apprentenice_id,Apprentenice_name,Master_id,Lv,Career,Status,Report_lv,Join_time,Last_report_time,Sex) ->
	Master_apprentice = #ets_master_apprentice{
      		apprentenice_id = Apprentenice_id,
			apprentenice_name = Apprentenice_name,
			master_id = Master_id,
			lv = Lv,
			career = Career,
			status = Status,
			report_lv = Report_lv,
			join_time = Join_time,
			last_report_time = Last_report_time,
			sex = Sex							 
			},
    ValueList = lists:nthtail(2, tuple_to_list(Master_apprentice)),
    [id | FieldList] = record_info(fields, ets_master_apprentice),
	Ret = ?DB_MODULE:insert(master_apprentice, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
    		Ret;
		_ ->
			{mongo, Ret}
	end. 
		

%%创建伯乐表数据
create_master_charts(Master_id,Master_name,Master_lv,Realm,Career,Award_count,Score_lv,Appre_num,Regist_time,Lover_type,Sex) ->
	Master_charts = #ets_master_charts{
					  master_id = Master_id,
					  master_name = Master_name,
					  master_lv = Master_lv,
					  realm = Realm,
					  career = Career,
					  award_count = Award_count,
					  score_lv = Score_lv,
					  appre_num = Appre_num,
					  regist_time = Regist_time,
					  lover_type =  Lover_type,
					  sex = Sex,
					  online= 1
			},
    ValueList = lists:nthtail(2, tuple_to_list(Master_charts)),
    [id | FieldList] = record_info(fields, ets_master_charts),
	?DB_MODULE:insert(master_charts, FieldList, ValueList).

%%更新数据徒弟表数据
update_master_apprentice(Status,Join_time,Apprentenice_id,Master_id) ->
	?DB_MODULE:update(master_apprentice,
								 [{status,Status},
								  {master_id,Master_id},
								  {join_time,Join_time}
								  ],
								 [{apprentenice_id,Apprentenice_id}]
								 ).

change_master_apprentice_name(PlayerId,NickName) ->
	?DB_MODULE:update(master_apprentice,[{apprentenice_name,NickName}],[{apprentenice_id,PlayerId}]).

update_master_apprentice_reportlv(Report_lv,Last_report_time,Apprentenice_id) ->
	?DB_MODULE:update(master_apprentice,
								 [{report_lv,Report_lv},
								  {last_report_time,Last_report_time}
								  ],
								 [{apprentenice_id,Apprentenice_id}]
								 ).
update_master_apprentice_lv(Lv,Apprentenice_id) ->
	?DB_MODULE:update(master_apprentice,
								 [{lv,Lv}
								  ],
								 [{apprentenice_id,Apprentenice_id}]
								 ).

update_master_apprentice_lv_report(Lv,Report_lv,Apprentenice_id) ->
	?DB_MODULE:update(master_apprentice,
								 [{lv,Lv},
								  {report_lv,Report_lv}
								  ],
								 [{apprentenice_id,Apprentenice_id}]
								 ).

update_master_apprentice_statu_reportlv(Status,Report_lv,Apprentenice_id) ->
	?DB_MODULE:update(master_apprentice,
								 [{status,Status},
								  {report_lv,Report_lv}
								  ],
								 [{apprentenice_id,Apprentenice_id}]
								 ).

%%更新数据伯乐表数据
update_master_charts(CreateTime,Lover_type,Master_id) ->
	?DB_MODULE:update(master_charts,
								 [{regist_time,CreateTime},{lover_type,Lover_type}],
								 [{master_id,Master_id}]
								 ).

%%更新数据伯乐表数据
update_master_charts(Lover_type,Master_id) ->
	?DB_MODULE:update(master_charts,
								 [{lover_type,Lover_type}],
								 [{master_id,Master_id}]
								 ).

change_master_charts_name(PlayerId,NickName) ->
	?DB_MODULE:update(master_charts,[{master_name,NickName}],[{master_id,PlayerId}]).	
	
%%更新数据伯乐表数据
update_master_charts_lv(Score_lv,Master_id) ->
	?DB_MODULE:update(master_charts,
								 [{score_lv,Score_lv}],
								 [{master_id,Master_id}]
								 ).
%%更新数据伯乐表数据	
update_master_charts_award_lv(Award_count,Score_lv,Master_id) ->
	?DB_MODULE:update(master_charts,
								 [{award_count , Award_count},
								  {score_lv , Score_lv}],
								 [{master_id,Master_id}]
								 ).

%%更新数据伯乐表数据
update_master_charts_masterlv(Master_lv,Master_id) ->
	?DB_MODULE:update(master_charts,
								 [{master_lv,Master_lv}],
								 [{master_id,Master_id}]
								 ).

%%更新数据伯乐表数据
update_master_charts(Award_count,Score_lv,Appre_num1,Master_id) ->
	?DB_MODULE:update(master_charts,
								 [{award_count , Award_count},
								  {score_lv , Score_lv},
								  {appre_num , Appre_num1}],
								 [{master_id,Master_id}]
								 ).

%%更新数据伯乐表数据
update_master_charts(Regist_time,Appre_num,Score_lv,Lover_type,Master_id) ->
	?DB_MODULE:update(master_charts,
								 [
								  {regist_time,Regist_time},
								  {appre_num , Appre_num},
								  {score_lv , Score_lv},
								  {lover_type , Lover_type}],
								 [{master_id,Master_id}]
								 ).

get_master_apprentice(Apprentenice_id) ->
	?DB_MODULE:select_row(master_apprentice, "*", [{apprentenice_id, Apprentenice_id}], [], [1]).

get_master_charts(Master_id) ->
	?DB_MODULE:select_row(master_charts, "*", [{master_id, Master_id}], [], [1]).

query_master_charts(Nickname) ->
	?DB_MODULE:select_row(master_charts, "*", [{master_name, Nickname}], [], [1]).
	

del_master_apprentice(Apprentenice_id) ->
	?DB_MODULE:delete(master_apprentice,[{apprentenice_id,Apprentenice_id}]),
	1.
	
%%%%%end 师徒关系=======



%%插入诛邪得到的物品记录
insert_log_box_open(Table, DataRecord) ->
    ValueList = lists:nthtail(2, tuple_to_list(DataRecord)),
    [id | FieldList] = record_info(fields, ets_log_box_open),
	Ret = ?DB_MODULE:insert(Table, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			Ret;
		_ ->
			{mongo, Ret}
	end.

get_log_box_open_new(Table, WhereList) ->
	?DB_MODULE:select_row(Table, "*", WhereList, [{id, desc}], [1]).

goods_box_to_bag(Table, ValueList, WhereList) ->
	?DB_MODULE:update(Table, ValueList, WhereList).

delete_all_box_goods(Table, WhereList) ->
	?DB_MODULE:delete(Table, WhereList).

insert_log_box_player(Table, DataRecord) ->
	ValueList = lists:nthtail(1, tuple_to_list(DataRecord)),
	FieldList = record_info(fields, ets_log_box_player),
	?DB_MODULE:insert(Table, FieldList, ValueList).

get_player_box_goods(PlayerId) ->
	?DB_MODULE:select_row(log_box_player, "*", [{player_id, PlayerId}], [{id, desc}], [1]).

update_player_box_goods_trace_time_num(Table, ValueList, WhereList)->
	?DB_MODULE:update(Table, ValueList, WhereList).

delete_log_box_player(PlayerId) ->
	?DB_MODULE:delete(log_box_player, [{player_id, PlayerId}]).

%%添加诛邪仓库删除物品的日志
insert_box_goods_log(Table, ValueList, FieldList) ->
	?DB_MODULE:insert(?LOG_POOLID, Table, FieldList, ValueList).

%% %%%%%藏宝图
%% %%添加新的藏宝图
%% insert_puzzl_map(PlayerId,MapId)->
%% 	MapInfo  = #ets_puzzle_map{
%% 						map_id = MapId,
%% 						player_id = PlayerId,
%% 						scene_id = 0,
%% 						x = 0,
%% 						y=0
%% 						},
%%     ValueList = lists:nthtail(2, tuple_to_list(MapInfo)),
%%     [id | FieldList] = record_info(fields, ets_online_gift),
%% 	?DB_MODULE:insert(puzzlemap, FieldList, ValueList).
%% 
%% %%更新藏宝图信息
%% update_puzzle_map(PlayerId,MapId,Lvl,SceneId,X,Y)->
%% 	?DB_MODULE:update(puzzlemap,
%% 								 [
%% 								  {lvl,Lvl},
%% 								  {scene_id , SceneId},
%% 								  {x , X},
%% 								  {y , Y}],
%% 								 [{map_id,MapId},
%% 								  {player_id,PlayerId}]
%% 								 ).
%% 
%% %%删除藏宝图
%% delete_puzzle_map(PlayerId,MapId) ->
%% 	?DB_MODULE:delete(puzzlemap,[{player_id,PlayerId},{map_id,MapId}]),
%% 	1.

%% 获取登录任务
get_login_prize()->
	?DB_MODULE:select_all(login_prize,"begtime,endtime,lv_lim,beg_regtime,end_regtime,gold,cash,coin,bcoin,goods_id,num,title,content",[],[],[1]).

%% 获取活动登陆奖励
get_mid_prize(Pid,Type) ->
	?DB_MODULE:select_row(mid_award,"id,pid,type,num,got",[{pid,Pid},{type,Type}],[],[1]).
%% 获取活动登陆奖励
get_mid_prize_extradata(Pid,Type) ->
	?DB_MODULE:select_row(mid_award,"id,pid,type,num,got,other",[{pid,Pid},{type,Type}],[],[1]).

%% 添加活动登陆奖励
insert_mid_prize(ColList,Data) ->
	?DB_MODULE:insert(mid_award,ColList,Data).

%% 更新活动登陆奖励
update_mid_prize(ValueList,WhereList)->
	?DB_MODULE:update(mid_award,ValueList,WhereList).
%%删除活动的奖励
delete_mid_prize(WhereList) ->
	?DB_MODULE:delete(mid_award,WhereList).

%% 删除活动记录表
del_mid_prize_table() ->
	?DB_MODULE:delete(mid_award,[{id,">",0}]).
%%获取指定类型的活动数据
select_type_mid_award(Type, Fields) ->
?DB_MODULE:select_all(mid_award,Fields,[{id, ">", 0}, {type,Type}],[],[]).

get_love_data() ->
   ?DB_MODULE:select_all(loveday,"id,pid,rid,pname,rname,content,votes,voters",[{id, ">", 0}],[],[]).

%%添加表白数据
insert_love_data(ColList,Data) ->
	?DB_MODULE:insert(loveday,ColList,Data).

%%更新表白数据
update_love_data(ValueList,WhereList)->
	?DB_MODULE:update(loveday,ValueList,WhereList).
delete_all_love_date() ->
	?DB_MODULE:delete(loveday,[{id,">",0}]).

%%查找物品购买记录
check_goods_shop(PlayerId,GoodsId)->
	?DB_MODULE:select_row(log_shop, "goods", [{goods_id, GoodsId},{player_id,PlayerId}], [], [1]).

%% 添加掉落统计信息
insert_mon_drop_analytics(Data) ->
	ColList = [mon_id, mon_name, player_id, player_name, goods_id, goods_name, goods_color, is_weapon, drop_time],
	?DB_MODULE:insert(?LOG_POOLID, mon_drop_analytics, ColList, Data).

add_online_min(Rec_time, Online_num) ->
	?DB_MODULE:insert(stc_min, [time, online_num], [Rec_time, Online_num]).

%%======================== 玩家游戏系统配置  begin =========================
%%查询玩家的游戏系统配置数据
get_player_sys_settings(PlayerId) ->
	?DB_MODULE:select_row(player_sys_setting, "*", [{player_id, PlayerId}], [], [1]).

%%初始化数据库玩家系统配置数据
init_player_sys_settings(PlayerSysSet) ->
	ValueList = lists:nthtail(1, tuple_to_list(PlayerSysSet)),
	FieldList = record_info(fields, player_sys_setting),
	?DB_MODULE:insert(player_sys_setting, FieldList, ValueList).

%%更新玩家数据库系统配置数据
update_player_sys_settings(ValueList, WhereList) ->
	?DB_MODULE:update(player_sys_setting, ValueList, WhereList).
%%======================== 玩家游戏系统配置  end ==========================

%% 初始挂机设置
init_hook_config(PlayerId) ->
	HookConfig1 = tuple_to_list(#hook_config{}),
	[_EtsKey | HookConfig2] = HookConfig1,
	NewHookConfig = util:term_to_string(HookConfig2),
	Now = util:unixtime(),
	ColList = [PlayerId, NewHookConfig, Now, lib_hook:base_hook_time(), Now],
	?DB_MODULE:insert(player_hook_setting, [player_id, hook_config, time_start, time_limit, timestamp], ColList),
	{NewHookConfig, Now, 10800, Now}.

%% 获取挂机设置
get_hook_config(PlayerId) ->
	?DB_MODULE:select_row(player_hook_setting, "hook_config, time_start, time_limit, timestamp", [{player_id, PlayerId}]).
	
%%更新挂机时间
update_hook_time(PlayerId,TimeStart,TimeLimit,Timestamp)->
	?DB_MODULE:update(player_hook_setting,[{time_start,TimeStart},{time_limit,TimeLimit},{timestamp,Timestamp}],[{player_id,PlayerId}]).

%% 更新挂机设置
update_hook_config(PlayerId, HookConfig) ->
	HookConfig1 = tuple_to_list(HookConfig),
	[_EtsKey | HookConfig2] = HookConfig1,
	NewHookConfig = util:term_to_string(HookConfig2),
	?DB_MODULE:update(player_hook_setting, [{hook_config, NewHookConfig}], [{player_id, PlayerId}]).

%%获取CD时间
get_guild_manor_cd(PlayerId) ->
	Ret = ?DB_MODULE:select_one(guild_manor_cd, "end_time", [{player_id, PlayerId}], [{id, desc}], [1]),
	case Ret of
		null -> [];
		_ -> [Ret]
	end.

%%修改CD时间
update_guild_manor_cd(PlayerId, NewEndTime) ->
	?DB_MODULE:update(guild_manor_cd, [{end_time, NewEndTime}], [{player_id, PlayerId}]).

%%添加CD记录
add_guild_manor_cd(PlayerId, SceneId, ManorCD, GuildWeal) ->
	FieldsList = [player_id, end_time, scene, welfare],
	ValueList = [PlayerId, ManorCD, SceneId, GuildWeal],
	?DB_MODULE:insert(guild_manor_cd, FieldsList, ValueList).

%%获取上次进去的时候的场景id
get_guild_manor_enter_coord(PlayerId) ->
	Ret = ?DB_MODULE:select_one(guild_manor_cd, "scene", [{player_id, PlayerId}], [{id, desc}], [1]),
	case Ret of
		null -> [];
		_ -> [Ret]
	end.

%%修改进入领地之前的场景id
update_guild_manor_enter_coord(PlayerId, SceneId) ->
	?DB_MODULE:update(guild_manor_cd, [{scene, SceneId}], [{player_id, PlayerId}]).

%%更新CD时间和修改进入领地之前的场景id
update_guild_manor_cd_and_coord(PlayerId, NewTime, SceneId) ->
	?DB_MODULE:update(guild_manor_cd, [{end_time, NewTime}, {scene, SceneId}], [{player_id, PlayerId}]).

get_weal_lasttime(PlayerId) ->
	Ret = ?DB_MODULE:select_one(guild_manor_cd, "welfare", [{player_id, PlayerId}], [{id, desc}], [1]),
	case Ret of
		null -> [];
		_ -> [Ret]
	end.

update_weal_lasttime(PlayerId, NewTime) ->
	?DB_MODULE:update(guild_manor_cd, [{welfare, NewTime}], [{player_id, PlayerId}]).

%% %%获取氏族玩家的技能令和更新技能令
%% get_player_g_skilltos(PlayerId) ->
%% 	?DB_MODULE:select_row(guild_manor_cd, "skto", [{player_id, PlayerId}], [{id, desc}], [1]).
%% update_player_g_skilltos(PlayerId, NewSkillTos) ->
%% 	?DB_MODULE:update(guild_manor_cd, [{skto, NewSkillTos}], [{player_id, PlayerId}]).
%%删除CD记录
delete_guild_manor_cd(PlayerId) ->
	?DB_MODULE:delete(guild_manor_cd, [{player_id, PlayerId}]).

%%PlayerId角色Id
%%Type消费类型
%%Num消费数目，正值
%%LogTime%%消费时间
%%PointId消费点，例(2701)27表示师傅模块，01表示购买决裂书
%%Oper操作类型，1是增加,0减少,
consume_log(PointId,PlayerId,Type,Old_num,Num,Oper) ->
	CurrentTime = util:unixtime(),
	 [H1, H2, _H3, _H4] = integer_to_list(PointId),
	 Module = list_to_atom(""++[H1,H2]),
	if
		Type =:= gold orelse Type =:= cash orelse Num >= 10000 ->
			?DB_MODULE:insert(log_consume,[pid, mod, pit, type, old_num, num, oper, ct],
				  						[PlayerId, Module, PointId, Type, Old_num, Num, Oper, CurrentTime]);
		true -> skip
	end.
%%氏族功勋使用日志
log_feat_count(ShopType, PlayerId, OldFeat, NewFeat, GoodsTypeId, GoodsNum) ->
	CurrentTime = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID,log_guild_feat,
					  [pid,oldf,newf,type,gid,num,ct],
					  [PlayerId, OldFeat, NewFeat, ShopType, GoodsTypeId, GoodsNum, CurrentTime]).

%% 暂时不提交，注释掉
%%氏族仓库初始化，获取所有的仓库物品
get_guild_storage(GuildId) ->
	?DB_MODULE:select_all(goods, "*", [{player_id, 0}, {equip_type, GuildId}, {location, 8}]).

%%氏族仓库初始化，获取所有氏族仓库物品的附加属性
get_warehouse_goods_attribute(GoodsId) ->
	?DB_MODULE:select_all(goods_attribute, "*", [{gid,GoodsId}]).

%%把物品由氏族仓库放进角色背包
put_goods_into_bag(PlayerId, Cell, GuildId, Location, GoodsId) ->
	?DB_MODULE:update(goods_attribute,
					  [{player_id, PlayerId}],
					  [{gid, GoodsId}]),
	?DB_MODULE:update(goods,
					  [{player_id, PlayerId},
					   {cell, Cell},
					   {equip_type, GuildId},
					   {location, Location}],
					  [{id, GoodsId}]).

%%把物品有角色背包放进氏族仓库
goods_player_to_warehouse(GoodsId, GuildId, Location, Cell) ->
	?DB_MODULE:update(goods_attribute,
					  [{player_id, 0}],
					  [{gid, GoodsId}]),
	?DB_MODULE:update(goods,
					  [{player_id, 0},
					   {cell, Cell},
					   {equip_type, GuildId},
					   {location, Location}],
					  [{id, GoodsId}]).

%%更细氏族仓库当前物品数目
update_guild_warehouse(Table, ValueList, WhereList) ->
	?DB_MODULE:update(Table, ValueList, WhereList).

%%氏族解散，删除氏族仓库中的所有物品
delete_warehouse_each_disband(GoodsId) ->
	?DB_MODULE:delete(goods, [{id, GoodsId}]),
	?DB_MODULE:delete(goods_attribute, [{gid, GoodsId}]).

%%添加氏族仓库的物品流向记录日志
insert_warehouse_flow_log(WarehouseGoodsDir) ->
	ValueList = lists:nthtail(2, tuple_to_list(WarehouseGoodsDir)),
	[id | FieldList] = record_info(fields, ets_log_warehouse_flowdir),
	?DB_MODULE:insert(?LOG_POOLID, log_warehouse_flowdir, FieldList, ValueList).

%%数据库查询方法 in特殊用法
find() ->
 	?DB_MODULE:select_all(player, "id,nickname", [{id, "in", [1,2]}]).

find_vip(PlayerId_list) ->
	?DB_MODULE:select_all_sequence(player, "vip", [{id, "in", PlayerId_list}],[],[]).
find_vip_lv(PlayerId_list) ->
	?DB_MODULE:select_all_sequence(player, "vip,lv", [{id, "in", PlayerId_list}],[],[]).

%%求和
%%Tablename  player
%%Field  "gold"
%%WhereList [{id,1}]或[{id,"in",[1,2,3]}]或[{id,"nin",[1,2,3]}]
%%eg: db_mongo:sum(log_pay,"pay_gold",[{player_id,1},{pay_time,">=",1297267201},{pay_time,"<=",1397267201}]).
sum(Tablename, Field, WhereList) ->
	?DB_MODULE:sum(Tablename, Field, WhereList).

%% 统计剩余元宝（交易铜）数
sum_remain_gold_coin(TodaySec) ->
	Gold = sum(player, "gold", [{gold, ">", 0}]),
	Coin = sum(player, "coin", [{coin, ">", 0}]),
	Now = util:unixtime(),
	EndTime = Now - TodaySec,
	StartTime = EndTime - 86400,
	PayGold = sum(log_pay, "pay_gold", [{pay_status, 1}, {pay_time, ">=", StartTime}, {pay_time, "<=", EndTime}]),
	UseGold = sum_consume(StartTime, EndTime),
	?DB_MODULE:insert(log_gold_coin, [gold, coin, pay_gold, use_gold, utime], [Gold, Coin, PayGold, UseGold, StartTime]).
%% 统计当天消耗元宝
sum_consume(StartTime, EndTime) ->
	ConsumeList = ?DB_MODULE:select_all(log_consume, "num", [{type, "gold"}, {ct, ">=", StartTime}, {ct, "<=", EndTime}], [], []),
	SumFun = fun([N], Num) ->
		Num + N
	end,
	lists:foldl(SumFun, 0, ConsumeList).

%% 玩家流失率
count_player_leave(TodaySec) ->
	Now = util:unixtime(),
	EndTime = Now - TodaySec,
	StartTime = EndTime - 86400,
	%% 累计玩家
	[RegNum] = ?DB_MODULE:select_count(player, [{reg_time, "<", EndTime}]),
	LeaveTime = EndTime - 3600 * 72,
	%% 流失玩家
	[Leave] = ?DB_MODULE:select_count(player, [{last_login_time, ">", 0}, {last_login_time, "<", LeaveTime}]),
	%% 新玩家
	[New] = ?DB_MODULE:select_count(player, [{reg_time, ">=", StartTime}, {reg_time, "<", EndTime}]),
	%% 流失率
	LeaveRate = round((Leave / RegNum) * 10000) / 100,
	%% 昨天注册人数
	YesStartTime = StartTime - 86400,
	YesEndTime = EndTime - 86400,
	[YestodayRegNum] = ?DB_MODULE:select_count(player, [{reg_time, ">=", YesStartTime}, {reg_time, "<", YesEndTime}]),
	%% 回访人数
	[Back] = ?DB_MODULE:select_count(player, [{reg_time, ">=", YesStartTime}, {reg_time, "<", YesEndTime}, {last_login_time, ">", StartTime}, {last_login_time, "<", EndTime}]),
	%% 回访率
	BackRate = 
		if
			YestodayRegNum > 0 ->
				round((Back / YestodayRegNum) * 10000) / 100;
			true ->
				0
		end,
	?DB_MODULE:insert(log_count_player_leave, [time, new, leave, reg_num, leave_rate, back, back_rate], [EndTime, New, Leave, RegNum, LeaveRate, Back, BackRate]).

%%加载竞技场总排行
load_arena_data() ->
	?DB_MODULE:select_all(arena, "id,player_id,nickname,realm,career,lv,wins,score", []).

load_arena_week_data() ->
	?DB_MODULE:select_all(arena_week, "*", [{id,">",0}]).

%% 插入竞技场总排行
insert_arena(Data) ->
	Ret = ?DB_MODULE:insert(arena, [player_id, nickname, realm, career, lv, att, sex, wins, score, pid, jtime], Data),
	case ?DB_MODULE of
		db_mysql ->
    		Ret;
		_ ->
			{mongo, Ret}
	end.

%% 插入战场日志
insert_log_arena(Data) ->
	Ret = ?DB_MODULE:insert(log_arena, [player_id, nickname, zone, bid, stime, jtime, etime, ltime], Data),
	case ?DB_MODULE of
		db_mysql ->
    		Ret;
		_ ->
			{mongo, Ret}
	end.

%% 更新玩家进入战场时间（给前端发送进入战场信号）
update_arena_start_time(PlayerId, Zone, Bid) ->
	Now = util:unixtime(),
	{Time1, Time2} = util:get_midnight_seconds(Now),
	ColList = [
		{zone, Zone},
		{bid, Bid},
		{stime, Now}		   
	],
	Condition = [
		{player_id, PlayerId},
		{jtime, ">", Time1},
		{jtime, "<", Time2},
		{stime, 0}
	],
	?DB_MODULE:update(log_arena, ColList, Condition).

%% 更新玩家进入战场时间
update_arena_enter_time(PlayerId) ->
	Now = util:unixtime(),
	{Time1, Time2} = util:get_midnight_seconds(Now),
	Condition = [
		{player_id, PlayerId},
		{jtime, ">=", Time1},
		{jtime, "<=", Time2},
		{etime, 0}
	],
	?DB_MODULE:update(log_arena, [{etime, Now}], Condition).

%% 更新玩家退出战场时间
update_arena_leave_time(PlayerId) ->
	Now = util:unixtime(),
	{Time1, Time2} = util:get_midnight_seconds(Now),
	Condition = [
		{player_id, PlayerId},
		{jtime, ">=", Time1},
		{jtime, "<=", Time2},
		{ltime, 0}
	],
	?DB_MODULE:update(log_arena, [{ltime, Now}], Condition).

%%插入竞技场一周排行
insert_arena_week(Data) ->
	Ret = ?DB_MODULE:insert(arena_week, [player_id, nickname, realm, career, lv, area, camp, type, score, ctime, killer], Data),
	case ?DB_MODULE of
		db_mysql ->
    		Ret;
		_ ->
			{mongo, Ret}
	end.

%% 更新竞技场总排行
update_arena(PlayerId, Lv, Wins, Score) ->
	?DB_MODULE:update(arena, [{lv, Lv}, {wins, Wins}, {score ,Score}], [{player_id, PlayerId}]).

%% 更新竞技场总排行角色名
update_arena_playername(PlayerId, NewNickName) ->
	?DB_MODULE:update(arena, [{nickname ,NewNickName}], [{player_id, PlayerId}]).

%% 更新竞技场周排行角色名
update_arena_week_playername(PlayerId, NewNickName) ->
	?DB_MODULE:update(arena_week, [{nickname ,NewNickName}], [{player_id, PlayerId}]).

%% 更新竞技场战场信息
update_arena_battle_info(PlayerId, List) ->
	?DB_MODULE:update(arena, List, [{player_id, PlayerId}]).

%%查询指定时间以前的数据
get_arena_week(Time) ->
	?DB_MODULE:select_all(arena_week, "*", [{player_id,">",0}, {ctime, "<", Time}]).

%%删除指定时间以前的数据
delete_arena_week(Time) ->
	?DB_MODULE:delete(arena_week, [{player_id,">",0}, {ctime, "<", Time}]).

delete_arena(PlayerId) ->
	?DB_MODULE:delete(arena, [{player_id, PlayerId}]).

%%查询指定时间段内的数据
get_arena_week(Time1,Time2) ->
	?DB_MODULE:select_all(arena_week, "*", [{player_id,">",0}, {ctime, ">", Time1}, {ctime, "<", Time2}]).

%% 查询指定时间段内的数据
get_arena_week_Ids(Time1, Time2) ->
	?DB_MODULE:select_all(arena_week, "player_id", [{player_id,">",0}, {ctime, ">", Time1}, {ctime, "<", Time2}]).

%% 获取当天报名战场的玩家
get_join_arene_player(Time1, Time2) ->       
	ColList = "player_id,nickname,realm,career,lv,att,sex",
	?DB_MODULE:select_all(arena, ColList, [{player_id,">",0}, {jtime, ">", Time1}, {jtime, "<", Time2}]).
	
%% 获取竞技场玩家数据
get_arena_data_by_id(PlayerId, CollList) ->
	?DB_MODULE:select_row(arena, CollList, [{player_id, PlayerId}]).

%% 更新玩家竞技场状态
update_arena_status(PlayerId, Arena) ->
	?DB_MODULE:update(player, [{arena, Arena}], [{id, PlayerId}]).

%% 更新玩家积分
update_arena_score(PlayerId, ArenaScore, Arena) ->
	?DB_MODULE:update(player, [{arena_score, ArenaScore}, {arena, Arena}], [{id, PlayerId}]).

update_arena_score_add(PlayerId, ArenaScore, Arena) ->
    ?DB_MODULE:update(player, [{arena_score, ArenaScore, add}, {arena, Arena}], [{id, PlayerId}]).	

%%新的玩家运镖数据
insert_carry(PlayerId,Timestamp)->
	Carry  = #ets_carry{
						pid = PlayerId,
						carry_time = Timestamp,
						bandits_time = Timestamp,
						quality = 1
						},
    ValueList = lists:nthtail(2, tuple_to_list(Carry)),
    [id | FieldList] = record_info(fields, ets_carry),
	Ret = ?DB_MODULE:insert(carry, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.

%%查询玩家运镖数据
select_carry(PlayerId)->
	?DB_MODULE:select_row(carry, "*", [{pid, PlayerId}]).

%%更新玩家运镖次数
update_carry_times(PlayerId)->
	?DB_MODULE:update(carry, [{carry, 1,add}], [{pid, PlayerId}]).

%%重置玩家运镖次数
reset_carry_times(PlayerId,Timestamp)->
	?DB_MODULE:update(carry, [{carry, 0},{carry_time,Timestamp}], [{pid, PlayerId}]).

%%更新玩家劫镖次数
update_bandits_times(PlayerId)->
	?DB_MODULE:update(carry, [{bandits, 1,add}], [{pid, PlayerId}]).

%%重置玩家劫镖次数
reset_bandits_times(PlayerId,Timestamp)->
	?DB_MODULE:update(carry, [{bandits, 0},{bandits_time,Timestamp}], [{pid, PlayerId}]).

%%重置运镖信息
reset_carry(ValueList,WhereList)->
	?DB_MODULE:update(carry,ValueList,WhereList).

%%获取玩家氏族id
get_guild_id(PlayerId)->
	?DB_MODULE:select_one(player, "guild_id", [{id,PlayerId}], [], [1]).

get_box_scene(PlayerId) ->
	?DB_MODULE:select_row(box_scene, "*", [{player_id, PlayerId}], [], [1]).

get_num_box_scene(PlayerId) ->
	Ret = ?DB_MODULE:select_one(box_scene, "num", [{player_id, PlayerId}], [{id, desc}], [1]),
	case Ret of
		null -> [];
		_ -> [Ret]
	end.

insert_box_scene(BoxScene) ->
	[ id | FeildList] = record_info(fields, ets_box_scene),
	ValueList = lists:nthtail(2, tuple_to_list(BoxScene)),
	?DB_MODULE:insert(box_scene, FeildList, ValueList).

update_box_scene(ValueList, PlayerId) ->
	?DB_MODULE:update(box_scene, ValueList, [{player_id, PlayerId}]).
	
%%设置玩家vip状态
set_vip_state(PlayerId,Vip,VipTime)->
	?DB_MODULE:update(player,[{vip,Vip},{vip_time,VipTime}],[{id,PlayerId}]).

%%玩家使用蟠桃的相关数据库操作
insert_user_numtime(Table, ValueList, FieldList) ->
	?DB_MODULE:insert(Table, FieldList, ValueList).

update_user_numtime(Table, ValueList, WhereList) ->
	?DB_MODULE:update(Table, ValueList, WhereList).

get_use_numtime(Table, PlayerId, Type) ->
	?DB_MODULE:select_row(Table, "num, fina_time", [{player_id, PlayerId}, {type, Type}], [{id, desc}], [1]).

%%创建田地信息
%%ADD By ZKJ
del_farm_info_by_id(Id)->
	?DB_MODULE:delete(manor_farm_info, [{id, Id}]).

del_farm_info_by_pid(Pid)->
	?DB_MODULE:delete(manor_farm_info, [{pid, Pid}]).

insert_farm_info(Table, FieldList, ValueList) ->
	?DB_MODULE:insert(Table, FieldList, ValueList).

update_farm_info(Table, ValueList, WhereList) ->
	?DB_MODULE:update(Table, ValueList, WhereList).

select_form_info(Table, FieldList, ValueList) ->
	?DB_MODULE:select_all(Table, FieldList, ValueList).

select_one_log(Table, FieldList, WhereList, Orderby, Limit) ->
	?DB_MODULE:select_all(Table, FieldList, WhereList, Orderby, Limit).

select_form_info(Player_id) ->
	?DB_MODULE:select_row(farm, "farm1, farm2, farm3, farm4, farm5, farm6, farm7, farm8, farm9, farm10, farm11, farm12",[{player_id,Player_id}],[],[1]).
	
%%每日传送日志
log_deliver(PlayerId,Type,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID, log_deliver, [pid, deliver_type, timestamp], [PlayerId, Type, Timestamp]).

%%答题模块,随机从题库中抽取Sum条记录
load_base_answer(Sum) ->
	[Count] = ?DB_MODULE:select_count(base_answer,[]),
	F = fun(List) ->
				RandomList1 =  util:filter_list(List,1,0),
				_RandomList2 = lists:sublist(RandomList1,Sum)
		end,
	OrderSumList = F([util:rand(1,Count) || _SeqNum <- lists:seq(1, 200)]),
   	?DB_MODULE:select_all(base_answer, "*", [{order, "in", OrderSumList}]).

%%创建答题日志
create_log_answer(PlayerId,Score,Exp,Spirit,CreateTime) ->
	?DB_MODULE:insert(?LOG_POOLID,log_answer, 
					  [pid, score, exp, spirit, ctime],
					  [PlayerId, Score, Exp, Spirit, CreateTime]).

%%创建新跑商数据
create_new_business(PlayerId,Timestamp)->
	Business  = #ets_business{
						player_id = PlayerId,
						timestamp = Timestamp
						%%free =1,
						%%free_time = Timestamp
						},
    ValueList = lists:nthtail(2, tuple_to_list(Business)),
    [id | FieldList] = record_info(fields, ets_business),
	Ret = ?DB_MODULE:insert(business, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.


%%加载跑商数据
select_business(PlayerId)->
	?DB_MODULE:select_row(business,"id,player_id,times,timestamp,color,lv,current",[{player_id,PlayerId}]).

%%刷新商车
refresh_car(PlayerId,Color,Free,FreeTime,Once,Total)->
	?DB_MODULE:update(business,
					  [{color,Color},{free,Free},{free_time,FreeTime},{once,Once},{total,Total}],
					  [{player_id,PlayerId}]).

%%刷新商车日志
log_refresh_car(PlayerId,Type,Times,Color,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID, log_refresh_car,
					  [pid, type, times, color, timestamp],
					  [PlayerId, Type, Times, Color, Timestamp]).

%%开始跑商
start_business(PlayerId,Lv,Color)->
	?DB_MODULE:update(business,[
								{times,1,add},
								{lv,Lv},
								{current,0},
							    {once,0},
								{color,Color}
								],
					  [{player_id,PlayerId}]).

%%商车被劫
robbed_car(PlayerId)->
	?DB_MODULE:update(business,
					  [{current,1,add}],
					  [{player_id,PlayerId}]).

reset_business(PlayerId)->
	?DB_MODULE:update(business,[
								{color,4},
								{current,0}
								],
					  [{player_id,PlayerId}]).

reset_business_times(PlayerId,Times,Color,Timestamp)->
	?DB_MODULE:update(business,[
								{times,Times},
								{timestamp,Timestamp},
								{color,Color}
								],
					  [{player_id,PlayerId}]).

update_business_info(PlayerId,Times,Timestamp,Free,FreeTime)->
	?DB_MODULE:update(business,[{free,Free},
								{free_time,FreeTime},
								{times,Times},
								{timestamp,Timestamp}],[{player_id,PlayerId}]).

%%劫商日志
log_business_robbed(PlayerId,RobbedId,Color,Timestamp)->
	?DB_MODULE:insert(log_business_robbed,
					  [player_id, robbed_id, color, timestamp],
					  [PlayerId, RobbedId, Color, Timestamp]).

%%加载劫商数据
select_robbed_log(PlayerId)->
		?DB_MODULE:select_all(log_business_robbed, 
								 "id,player_id,robbed_id,timestamp", 
								 [{player_id,PlayerId}]).

%%加载被劫商数据
select_business_log(PlayerId)->
	?DB_MODULE:select_all(log_business_robbed, 
								 "id,player_id,robbed_id,timestamp", 
								 [{robbed_id,PlayerId}]).

%%节日登陆奖励
new_online_award_holiday(PlayerId,Day,Timestamp)->
	Online  = #ets_online_award_holiday{
						pid=PlayerId,
						every_day_time=Timestamp,
						continuous_day=Day
						},
    ValueList = lists:nthtail(2, tuple_to_list(Online)),
    [id | FieldList] = record_info(fields, ets_online_award_holiday),
	Ret = ?DB_MODULE:insert(online_award_holiday, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.

%%加载数据
select_online_award_holiday(PlayerId)->
	?DB_MODULE:select_row(online_award_holiday,"*",[{pid,PlayerId}]).

%%更新节日登陆奖励
update_online_award_holiday(PlayerId,EveryDayTime,EveryDayMark,ContinuousDay,ContinuousMark)->
	?DB_MODULE:update(online_award_holiday,
					  [{every_day_time,EveryDayTime},
					   {every_day_mark,EveryDayMark},
					   {continuous_day,ContinuousDay},
					   {continuous_mark,ContinuousMark}
					   ],
					  [{pid,PlayerId}]).



%%新建英雄帖数据
new_hero_card(PlayerId,Timestamp)->
	HeroCard  = #ets_hero_card{
						pid=PlayerId,
						timestamp=Timestamp
						},
    ValueList = lists:nthtail(2, tuple_to_list(HeroCard)),
    [id | FieldList] = record_info(fields, ets_hero_card),
	Ret = ?DB_MODULE:insert(hero_card, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.

%%加载数据
select_hero_card(PlayerId)->
	?DB_MODULE:select_row(hero_card,"*",[{pid,PlayerId}]).
%%更新使用次数
update_hero_times(PlayerId,Times,Timestamp)->
	?DB_MODULE:update(hero_card,[{times,Times},{timestamp,Timestamp}],[{pid,PlayerId}]).

%%更新颜色
update_hero_card(PlayerId,Lv,Color,Times,Timestamp)->
	?DB_MODULE:update(hero_card,[{lv,Lv},{color,Color},{times,Times},{timestamp,Timestamp}],[{pid,PlayerId}]).

%%重置
reset_hero_card(PlayerId)->
	?DB_MODULE:update(hero_card,[{lv,0},{color,0}],[{pid,PlayerId}]).
	

%%新建仙侣情缘数据
new_love(PlayerId,Timestamp,BeInvite)->
	Love  = #ets_love{
						pid=PlayerId,
						timestamp=Timestamp,
						be_invite = util:term_to_string(BeInvite),
						task_content = util:term_to_string([])
						},
    ValueList = lists:nthtail(2, tuple_to_list(Love)),
    [id | FieldList] = record_info(fields, ets_love),
	Ret = ?DB_MODULE:insert(love, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.

%%加载仙侣情缘数据
select_love(PlayerId)->
	?DB_MODULE:select_row(love,"*",[{pid,PlayerId}]).

%%更新情缘信息
update_love(ValueList,WhereList)->
	 ?DB_MODULE:update(love,ValueList,WhereList).

%%更新刷新时间
update_refresh_time(PlayerId,Timestamp,BeInvite)->
	?DB_MODULE:update(love,[{refresh,Timestamp},{be_invite,BeInvite}],[{pid,PlayerId}]).

%%更新邀请状态和次数
update_invite_state_and_times(PlayerId,Status,Timestamp,Mult,Times,Invitee)->
	?DB_MODULE:update(love,[{status,Status},{duration,Timestamp},{mult,Mult},{times,Times},{invitee,Invitee}],[{pid,PlayerId}]).

reset_invite_state(PlayerId)->
	?DB_MODULE:update(love,[{status,0},{duration,0},{mult,1},{invitee,[]}],[{pid,PlayerId}]).
reset_invite_state1(PlayerId)->
	?DB_MODULE:update(love,[{status,0},{duration,0},{mult,1}],[{pid,PlayerId}]).

%%
%%重置次数
update_invite_times(PlayerId,Timestamp,BeInvite)->
	?DB_MODULE:update(love,[{times,0},{timestamp,Timestamp},{be_invite,BeInvite},{task_times,0},{task_content,[]}],[{pid,PlayerId}]).

%%查找状态()
check_invite_state(PlayerId)->
	?DB_MODULE:select_row(love,"status,times",[{pid,PlayerId},{status,0},{times,"<",2}]).

%%获取一批符合条件的玩家
get_player_macth_status(Sex,Type)->
	?DB_MODULE:select_all(player, 
								 "nickname,id,career,sex", 
								 [{sex,"<>",Sex},{lv,">",29},{online_flag,1}],
						  		 [{Type,desc}], [30]).

log_invite(PlayerId,InviteId,Mult,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID, log_invite,
					  [pid, inviteid, mult, time],
					  [PlayerId, InviteId, Mult, Timestamp]).

get_online_player_match(Type, PlayerId) ->
	?DB_MODULE:select_all(player, 
						  "id", 
						  [{online_flag,1}, {id, "<>", PlayerId}],
						  [{Type,desc}], [10]).
%%更新魅力值
update_charm(PlayerId,Charm)->
	?DB_MODULE:update(love,[{charm,Charm}],[{pid,PlayerId}]).

%%增量更新魅力值
update_charm_add(PlayerId,Charm)->
	?DB_MODULE:update(love,[{charm,Charm,add}],[{pid,PlayerId}]).

%%更新成就点
update_achieve(PlayerId,Achieve)->
	?DB_MODULE:update(love,[{charm,Achieve}],[{pid,PlayerId}]).

%%更新玩家头衔
update_title(PlayerId,Title,Timestamp)->
	?DB_MODULE:update(love,[{title,Title},{title_time,Timestamp}],[{pid,PlayerId}]).

%%兑换魅力称号日志
log_convert_charm(PlayerId,Title,Charm,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID, log_convert_charm,
					  [pid, title, charm, timestamp],
					  [PlayerId, Title, Charm, Timestamp]).

%%查找任务记录
check_task_by_id(PlayerId,TaskList)->
	?DB_MODULE:select_all(task_log,"task_id",[{task_id,"in",TaskList},{player_id,PlayerId}]).

check_task_accept(PlayerId,TaskList)->
	?DB_MODULE:select_all(task_bag,"task_id",[{task_id,"in",TaskList},{player_id,PlayerId}]).
%%查询任务状态
check_task_can_finish(PlayerId,TaskList)->
	?DB_MODULE:select_all(task_bag,"state",[{task_id,"in",TaskList},{player_id,PlayerId}]).

%%更新默契度信息
update_privity(PlayerId,PrivityInfo)->
	?DB_MODULE:update(love,[{privity_info,PrivityInfo}],[{pid,PlayerId}]).

%% 插入玩家参与度
insert_join_summary(KeyList, ValList) ->
	?DB_MODULE:insert(?LOG_POOLID, log_join_summary, KeyList, ValList).

%% 获取玩家参与值
get_join_data(PlayerId, DataList) ->
	?DB_MODULE:select_row(log_join, DataList, [{pid, PlayerId}], [{jtime, desc}], [1]).

%% 初始当天参与值
init_today_join_data(PlayerId, Jtime) ->
	?DB_MODULE:insert(log_join, [pid, jtime], [PlayerId, Jtime]).

%% 更新参与值
update_join_data(PlayerId, Type) ->
	Now = util:unixtime(),
	{DayStart, DayEnd} = util:get_midnight_seconds(Now),
	?DB_MODULE:update(log_join, [{Type, 1, add}], [{pid, PlayerId}, {jtime, ">", DayStart}, {jtime, "<", DayEnd}]).

%% 当天登录人数
day_login_num(DayStart, DayEnd) ->
	?DB_MODULE:select_count(player, [{last_login_time, ">", DayStart}, {last_login_time, "<", DayEnd}]).
%% 老玩家数
day_old_player_num(DayStart, DayEnd, PlayerIdList) ->
	?DB_MODULE:select_count(player, [{last_login_time, ">", DayStart}, {last_login_time, "<", DayEnd}, {id, "in", PlayerIdList}]).

%% 获取参与项目数
count_join_data(Item, DayStart, DayEnd) ->
	?DB_MODULE:select_count(log_join, [{Item, ">", 0}, {jtime, ">", DayStart}, {jtime, "<", DayEnd}]).

%% 每天注册的玩家数
day_reg_num(DayStart, DayEnd) ->
	?DB_MODULE:select_count(player, [{reg_time, ">", DayStart}, {reg_time, "<", DayEnd}]).

old_player(DayStart, DayEnd) ->
	?DB_MODULE:select_all(log_join, "pid", [{jtime, ">", DayStart}, {jtime, "<", DayEnd}], [], []).

insert_login_data(LoginNum, OldNum, RegNum, Ltime) ->
	?DB_MODULE:insert(?LOG_POOLID, log_login,  [login, old,  reg,  ltime], [LoginNum, OldNum, RegNum, Ltime]).

%% 玩家注册登录元宝数据统计
insert_daily_data(RegNum, LoginNum, Ctime) ->
	RemainGold = sum(player, "gold", [{gold, ">", 0}]),
	?DB_MODULE:insert(?LOG_POOLID, log_login,  [reg_num, login_num, remain_gold, ctime], [RegNum, LoginNum, RemainGold, Ctime]).
	
%%新增登陆抽奖数据
insert_lucky_draw(PlayerId,Timestamp,GoodsList)->
	?DB_MODULE:insert(lucky_draw,  [pid, days, times, timestamp, goodslist], [PlayerId, 1, 1, Timestamp, GoodsList]).

%%获取玩家抽奖数据
select_lucky_draw(PlayerId)->
	?DB_MODULE:select_row(lucky_draw,"*",[{pid,PlayerId}]).

%%更新登陆抽奖数据
update_lucky_draw_days(PlayerId,Days,Times,Timestamp)->
	?DB_MODULE:update(lucky_draw,[{days,Days},{times,Times},{timestamp,Timestamp}],[{pid,PlayerId}]).

%%更新登陆抽奖物品信息
update_lucky_draw_goods(PlayerId,GoodsId,Times,GoodsList)->
	?DB_MODULE:update(lucky_draw,[{times,Times},{goods_id,GoodsId},{goodslist,GoodsList}],[{pid,PlayerId}]).

%%抽奖日志
log_lucky_draw(PlayerId,Days,Times,GoodsId,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID, log_lucky_draw, [pid, days, times, goods, timestamp], [PlayerId, Days, Times, GoodsId, Timestamp]).
 
%%新增目标引导表
insert_target_lead(PlayerId)->
	TL  = #ets_targetlead{
						pid=PlayerId
						},
    ValueList = lists:nthtail(2, tuple_to_list(TL)),
    [id | FieldList] = record_info(fields, ets_targetlead),
	Ret = ?DB_MODULE:insert(target_lead, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.

select_target_lead(PlayerId)->
	?DB_MODULE:select_row(target_lead,"*",[{pid,PlayerId}]).

update_target_lead(PlayerId,Type)->
	?DB_MODULE:update(target_lead,[{Type,1}],[{pid,PlayerId}]).

log_vip(PlayerId,GoodsId,Timestamp)->
	?DB_MODULE:insert(log_vip,  [pid, gid, time], [PlayerId ,GoodsId, Timestamp]).

check_vip_log(PlayerId,GoodsList)->
	?DB_MODULE:select_all(log_vip,"gid",[{gid,"in",GoodsList},{pid,PlayerId}]).

%%新增登录奖励信息
insert_login_award(PlayerId,Days,Timestamp,UnCharge,Charge,Mark)->
	AwardOnline  = #ets_login_award{
						pid=PlayerId,
						days = Days,
						time=Timestamp,
						un_charge=UnCharge,
						charge=Charge,
						charge_mark = Mark
						},
    ValueList = lists:nthtail(2, tuple_to_list(AwardOnline)),
    [id | FieldList] = record_info(fields, ets_login_award),
	Ret = ?DB_MODULE:insert(login_award, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.
%%获取登录奖励信息
select_login_award(PlayerId)->
	?DB_MODULE:select_row(login_award,"*",[{pid,PlayerId}]).

%%更新登录奖励
update_login_award(ValueList,WhereList)->
	 ?DB_MODULE:update(login_award,ValueList,WhereList).

%%领取日志
log_login_award(Pid,Type,Days,GoodsId,Num,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID, log_login_award,  [pid, type, days, goods_id, num, timestamp], [Pid , Type, Days, GoodsId, Num, Timestamp]).
	
%获取成就系统的各个表的数据
get_player_achieve(Table, PlayerId) ->
	?DB_MODULE:select_row(Table, "*", [{pid, PlayerId}], [], [1]).

%%向成就系统的数据表插入新的数据
insert_player_achieve(Table, Fields, Values) ->
	?DB_MODULE:insert(Table, Fields, Values).

%%更新玩家的成就系统信息
update_player_achieve(Table, ValueList, WhereList) ->
	?DB_MODULE:update(Table, ValueList, WhereList).

%%新增statistics表中玩家的记录
insert_ach_stats(PlayerId) ->
	TL  = #ets_ach_stats{pid=PlayerId},
	ValueList = lists:nthtail(2, tuple_to_list(TL)),
    [id | FieldList] = record_info(fields, ets_ach_stats),
	Ret = ?DB_MODULE:insert(achieve_statistics, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.
%%统计过去开诛邪的数据
get_box_open_nums(PlayerId, Type) ->
	?DB_MODULE:select_all(log_box_open, "num", [{player_id,PlayerId}, {hole_type, Type}], [], []).

%%更新statistics表中的字段
update_ach_stats(Table, ValueList, WhereList) ->
	?DB_MODULE:update(Table, ValueList, WhereList).

%%做玩家成就完成情况的日志记录
insert_ach_log(NewLog) ->
	ValueList = lists:nthtail(2, tuple_to_list(NewLog)),
	[id | FieldList] = record_info(fields, ets_log_ach_f),
	Ret = ?DB_MODULE:insert(log_ach_finish, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.

get_ach_log(PlayerId) ->
	?DB_MODULE:select_all(log_ach_finish, "id,ach_num,time", [{pid,PlayerId}],[{time, desc}], [50]).

%%更新装备/卸载八神珠
update_ach_pearl(Table, ValueList, WhereList) ->
	?DB_MODULE:update(Table, ValueList, WhereList).

%统计成就系统中需要统计的数量
get_ach_olddata_count(Table, WhereList) ->
	?DB_MODULE:select_count(Table, WhereList).


change_feedback_name(PlayerId,NickName) ->
	?DB_MODULE:update(feedback, [{player_name,NickName}], [{player_id,PlayerId}]).

change_log_arena_name(PlayerId,NickName) ->
	?DB_MODULE:update(log_arena, [{nickname,NickName}], [{player_id,PlayerId}]).

change_log_backout_name(PlayerId,NickName) ->
	?DB_MODULE:update(log_backout, [{nickname,NickName}], [{player_id,PlayerId}]).

change_log_box_open_name(PlayerId,NickName) ->
	?DB_MODULE:update(log_box_open, [{player_name,NickName}], [{player_id,PlayerId}]).

change_log_compose_name(PlayerId,NickName) ->
	?DB_MODULE:update(?LOG_POOLID, log_compose, [{nickname,NickName}], [{player_id,PlayerId}]).

change_log_hole_name(PlayerId,NickName) ->
	?DB_MODULE:update(?LOG_POOLID, log_hole, [{nickname,NickName}], [{player_id,PlayerId}]).

change_log_icompose_name(PlayerId,NickName) ->
	?DB_MODULE:update(?LOG_POOLID, log_icompose, [{nickname,NickName}], [{player_id,PlayerId}]).

change_log_idecompose_name(PlayerId,NickName) ->
	?DB_MODULE:update(?LOG_POOLID, log_idecompose, [{nickname,NickName}], [{player_id,PlayerId}]).

change_log_identify_name(PlayerId,NickName) ->
	?DB_MODULE:update(?LOG_POOLID, log_identify, [{nickname,NickName}], [{player_id,PlayerId}]).

change_log_inlay_name(PlayerId,NickName) ->
	?DB_MODULE:update(?LOG_POOLID, log_inlay, [{nickname,NickName}], [{player_id,PlayerId}]).

change_log_kick_off_name(PlayerId,NickName) ->
	?DB_MODULE:update(?LOG_POOLID, log_kick_off, [{nickname,NickName}], [{uid,PlayerId}]).

change_log_manor_steal_name(PlayerId,NickName) ->
	?DB_MODULE:update(log_manor_steal, [{nickname,NickName}], [{player_id,PlayerId}]).

change_log_merge_name(PlayerId,NickName) ->
	?DB_MODULE:update(?LOG_POOLID, log_merge, [{nickname,NickName}], [{player_id,PlayerId}]).

change_log_pay_name(PlayerId,NickName) ->
	?DB_MODULE:update(log_pay, [{nickname,NickName}], [{player_id,PlayerId}]).

change_log_practise_name(PlayerId,NickName)->
	?DB_MODULE:update(?LOG_POOLID, log_practise, [{nickname,NickName}], [{player_id,PlayerId}]).

change_log_quality_out_name(PlayerId,NickName) ->
	?DB_MODULE:update(?LOG_POOLID, log_quality_out, [{nickname,NickName}], [{player_id,PlayerId}]).

change_log_quality_up_name(PlayerId,NickName) ->
	?DB_MODULE:update(?LOG_POOLID, log_quality_up, [{nickname,NickName}], [{player_id,PlayerId}]).

change_log_refine_name(PlayerId,NickName) ->
	?DB_MODULE:update(?LOG_POOLID, log_refine, [{nickname,NickName}], [{player_id,PlayerId}]).

change_log_sale_name(PlayerId,NickName) ->
	?DB_MODULE:update(?LOG_POOLID, log_sale, [{buyer_name,NickName}], [{buyer_id,PlayerId}]),
	?DB_MODULE:update(?LOG_POOLID, log_sale, [{saler_name,NickName}], [{saler_id,PlayerId}]).

change_log_shop_name(PlayerId,NickName) ->
	?DB_MODULE:update(log_shop, [{nickname,NickName}], [{player_id,PlayerId}]).

change_log_smelt_name(PlayerId,NickName) ->
	?DB_MODULE:update(?LOG_POOLID, log_smelt, [{nickname,NickName}], [{player_id,PlayerId}]).

change_log_stren_name(PlayerId,NickName) ->
	?DB_MODULE:update(?LOG_POOLID, log_stren, [{nickname,NickName}], [{player_id,PlayerId}]).

change_log_suitmerge_name(PlayerId,NickName) ->
	?DB_MODULE:update(?LOG_POOLID, log_suitmerge, [{nickname,NickName}], [{player_id,PlayerId}]).

change_log_throw_name(PlayerId,NickName) ->
	?DB_MODULE:update(?LOG_POOLID, log_throw, [{nickname,NickName}], [{player_id,PlayerId}]).

change_log_trade_name(PlayerId,NickName) ->
	?DB_MODULE:update(?LOG_POOLID, log_trade, [{donor_name,NickName}], [{donor_id,PlayerId}]),
	?DB_MODULE:update(?LOG_POOLID, log_trade, [{gainer_name,NickName}], [{gainer_id,PlayerId}]).

change_log_use_name(PlayerId,NickName) ->
	?DB_MODULE:update(?LOG_POOLID, log_use, [{nickname,NickName}], [{player_id,PlayerId}]).

change_log_wash_name(PlayerId,NickName) ->
	?DB_MODULE:update(?LOG_POOLID, log_wash, [{nickname,NickName}], [{player_id,PlayerId}]).

change_mon_drop_analytics_name(PlayerId,NickName) ->
	?DB_MODULE:update(?LOG_POOLID, mon_drop_analytics, [{player_name,NickName}], [{player_id,PlayerId}]).

change_player_name(PlayerId,NickName) ->
	?DB_MODULE:update(player, [{nickname,NickName}], [{id,PlayerId}]).

%%查相同的角色名,返回id集合
get_samenickname() ->
	Data = ?DB_MODULE:select_all(player, "id,nickname", [{id,">",0}]),
	case Data of
		[] -> [];
		_ ->
			Data1 = [(Nickname) || [_Id,Nickname] <- Data],
			Data2 = lists:usort(Data1),
			Data3 = Data1 -- Data2,
			F = fun(Nickname1) ->
						?DB_MODULE:select_all(player, "id", [{nickname,Nickname1}])
				end,
			Data4 = [F(Nickname1) || Nickname1 <- Data3],
			lists:flatten(Data4)			
	end.

%%查相同的accname + sn
get_sameaccname_sn(TableName) ->
	Data = ?DB_MODULE:select_all(TableName, "accname,sn", [{id,">",0}]),
	case Data of
		[] -> [];
		_ ->
			Data1 = lists:usort(Data),
			if Data1 == Data ->
				   [];
			   true ->
				   Data2 = Data -- Data1,
				   Data2
			end
	end.

%%查相同的key为"id"或"id,sn"或"accid,accname,sn"
get_samekey(Table_name,Key) ->
	Result1 = ?DB_MODULE:select_all(Table_name,tool:to_list(Key),[]),
	Result2 = [{Key2,1} || Key2 <- Result1],
	Result3 = loop_samekey(Result2,[]),
	[{Key3,Num3} || {Key3,Num3} <-Result3,Num3 > 1].

loop_samekey([],Result1) ->
	Result1;
loop_samekey([H | Rest],Result1) ->
	{Key,Num} = H,
	case lists:keyfind(Key, 1, Result1) of
		false ->
			loop_samekey(Rest,[{Key,Num} | Result1]);
		{Key,NewNum} ->
			loop_samekey(Rest, lists:keyreplace(Key, 1, Result1, {Key,NewNum+1}))
	end.


%%对于大数据查重则用下面方法
get_other_samekey(Table_name,Key,WhereList) ->
	Result1 = db_mongo:select_all(Table_name,tool:to_list(Key),WhereList),
	KeyList = [tool:to_atom(StringKey) || StringKey <- string:tokens(Key,",")],
	KeyLength = length(KeyList),
	F = fun(Row) -> 
				WhereList1 = [{lists:nth(Num, KeyList),lists:nth(Num, Row)} || Num <- lists:seq(1,KeyLength)],
				[Sum] = db_mongo:select_count(Table_name,WhereList1),
				{Row,Sum}
		end,
	Result2 = [F(Row) || Row <- Result1],
	Result3 = loop__other_samekey(Result2,[]),
	Result3.

loop__other_samekey([],Result1) ->
	Result1;
loop__other_samekey([H | Rest],Result1) ->
	{Key,Num} = H,
	case lists:keyfind(Key, 1, Result1) of
		false ->
			loop__other_samekey(Rest,[{Key,Num} | Result1]);
		{Key,NewNum} ->
			loop__other_samekey(Rest, lists:keyreplace(Key, 1, Result1, {Key,NewNum+1}))
	end.

%%清除指定玩家Id的成就数据
delete_player_ach_info(PlayerId) ->
	?DB_MODULE:delete(ach_epic,[{pid,PlayerId}]),
	?DB_MODULE:delete(ach_fs,[{pid,PlayerId}]),
	?DB_MODULE:delete(ach_interact,[{pid,PlayerId}]),
	?DB_MODULE:delete(ach_task,[{pid,PlayerId}]),
	?DB_MODULE:delete(ach_treasure,[{pid,PlayerId}]),
	?DB_MODULE:delete(ach_trials,[{pid,PlayerId}]),
	?DB_MODULE:delete(ach_yg,[{pid,PlayerId}]),
	?DB_MODULE:delete(achieve_statistics,[{pid,PlayerId}]),
	?DB_MODULE:delete(log_ach_finish,[{pid,PlayerId}]),
	?DB_MODULE:delete(player_other,[{pid,PlayerId}]),
	?DB_MODULE:delete(goods, [{goods_id, "in", [30025, 30026, 
												30000, 30001, 
												30015, 30016, 
												30020, 30021, 
												30035, 30036, 
												30005, 30006, 
												30030, 30031, 
												30010, 30011]}, {player_id, PlayerId}]),
	ok.

%%更新cion+bcion = coin_sum
coin_sum_process(PlayerId) ->
	?DB_MODULE:coin_sum_process(player,[],[{id,PlayerId}]).



%%加载跑商基础数据
get_base_business()->
	?DB_MODULE:select_all(base_business, "*", [{id, ">", 0}], [], []).

%%加载封神贴基础数据
get_base_hero_card()->
	?DB_MODULE:select_all(base_hero_card, "*", [{id, ">", 0}], [], []).

%%加载默契度测试题库
get_base_privity()->
	?DB_MODULE:select_all(base_privity, "*", [{id, ">", 0}], [], []).

%%统计默契度测试题库数目
count_base_privity()->
	?DB_MODULE:select_count(base_privity,[]).

%%加载经脉基础数据
get_base_meridian()->
	?DB_MODULE:select_all(base_meridian, "*", [{id, ">", 0}], [], []).

%%加载怪物基础数据
get_base_mon()->
	?DB_MODULE:select_all(base_mon, "*", [{mid, ">", 0}], [], []).

%%加载NPC基础数据
get_base_npc()->
	?DB_MODULE:select_all(base_npc, "*", [{nid, ">", 0}], [], []).

%%加载NPC对话
get_base_talk()->
	?DB_MODULE:select_all(base_talk, "*", [{id, ">", 0}], [], []).

%%加载地图分类数据
get_base_map()->
	?DB_MODULE:select_all(base_map, "*", [{scene_id, ">", 0}], [], []).

%%加载职业基础数据
get_base_career()->
	?DB_MODULE:select_all(base_career, "*", [{career_id, ">", 0}], [], []).

%%加载场景基础数据
get_base_scene()->
	?DB_MODULE:select_all(base_scene, "sid", [{sid, ">", 0}]).

%%加载某场景基础数据
get_base_scene_one(SceneId)->
	?DB_MODULE:select_row(base_scene, "*", [{sid, SceneId}], [], [1]).

%%加载副本地图数据
get_base_dungeon()->
	?DB_MODULE:select_all(base_dungeon, "*", [{id, ">", 0}], [], []).

%%加载技能基础数据
get_base_skill()->
	?DB_MODULE:select_all(base_skill, "*", [{id, ">", 0}], [], []).

%%加载目标奖励基础数据
get_base_target_gift()->
	?DB_MODULE:select_all(base_target_gift, "*", [{day, ">", 0}], [], []).

%%加载任务基础数据
get_base_task()->
	?DB_MODULE:select_all(base_task, "*", [{id, ">", 0}], [], []).

%%根据accid获取玩家id
get_id_by_accid(Accid,Sn)->
	?DB_MODULE:select_row(player, "id, nickname", [{accid, Accid},{sn, Sn}],[],[1]).
repair_get_achs_need(LastTime) ->
	?DB_MODULE:select_all(player, "id", [{last_login_time, ">=",LastTime}]).

%% 添加双倍经验活动
add_exp_activity(St, Et, Now) ->
	?DB_MODULE:insert(exp_activity, [st, et, time], [St, Et, Now]).

get_exp_activity() ->
	?DB_MODULE:select_row(exp_activity, "st, et", [], [{time, desc}], [1]).


%%加载塔奖励数据
get_base_tower_award()-> 
	?DB_MODULE:select_all(base_tower_award, "*", [], [], []).

%%加载诛仙台荣誉
select_zxt_honor(PlayerId)->
	?DB_MODULE:select_row(player_other, "zxt_honor", [{pid,PlayerId}],[1]).

%%更新诛仙台荣誉
update_zxt_honor(PlayerId,Honor)->
	?DB_MODULE:update(player_other,[{zxt_honor,Honor}],[{pid,PlayerId}]).

%%诛仙台荣誉兑换日志
log_zxt_honor(PlayerId,Honor,GoodsId,Num,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID,log_zxt_honor,[pid,honor,goods,num,timestamp],[PlayerId,Honor,GoodsId,Num,Timestamp]).



%%查询多个玩家的一个或多个字段
%%db_agent:get_player_mult_properties([1,2,3,4],[lv,nickname,exp]). 
%%取值：Data = db_agent:get_player_mult_properties([1,2,3,4],[lv,gold,exp])
%%取等级 :{1,[50,1,60]} = lists:keyfind(1,1,Data)
get_player_mult_properties(PropertiesList,PlayerIdList) ->
	if PlayerIdList == [] orelse  PropertiesList == [] ->
		   [];
	   true ->
		   Propertiestring = util:list_to_string(PropertiesList ++ [id]),
		   AllData = ?DB_MODULE:select_all(player, Propertiestring, [{id,"in",PlayerIdList}],[],[]),
		   case AllData of
			   [] -> [];
			   _ ->
				 F = fun(Data) ->
							  Data1 = lists:reverse(Data),
							  [Player_Id | RestList] = Data1,
							  {Player_Id,lists:reverse(RestList)}
					  end,
				[F(Data) || Data <- AllData]
		   end			
	end.

%%插入活跃度数据
inset_player_activity(PlayerId, NowTime, Act, ActionsStr, GoodsStr) ->
	?DB_MODULE:insert(player_activity,[pid,act,retime,actions,goods],[PlayerId, Act, NowTime, ActionsStr, GoodsStr]).
%%更新玩家活跃度数据
update_player_activity(Table, ValueList, WhereList) ->
	?DB_MODULE:update(Table,ValueList, WhereList).
get_player_activity(PlayerId) ->
	?DB_MODULE:select_row(player_activity,"act, retime, actions, goods", [{pid, PlayerId}], [1]).

%%添加玩家完成活跃度的日志记录
insert_activity_log(PlayerId, Count, NowTime) ->
	?DB_MODULE:insert(?LOG_POOLID,log_player_activity,[pid, type, time],[PlayerId, Count, NowTime]).

%%添加循环任务奖励倍数刷新
insert_cycle_flush(PlayerId,Timestamp,Mult)->
	Data  = #ets_cycle_flush{
						pid=PlayerId,
						mult=Mult,
						timestamp=Timestamp
						}, 
    ValueList = lists:nthtail(2, tuple_to_list(Data)),
    [id | FieldList] = record_info(fields, ets_cycle_flush),
	Ret = ?DB_MODULE:insert(cycle_flush, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.

select_cycle_flush(PlayerId)->
	?DB_MODULE:select_row(cycle_flush,"*",[{pid,PlayerId}]).

update_cycle_flush(ValueList,WhereList)->
	 ?DB_MODULE:update(cycle_flush,ValueList,WhereList).

%% 添加在线时间纪录
insert_player_online_time(PlayerId, Now) ->
	?DB_MODULE:insert(?LOG_POOLID, log_online_time,  [player_id, ctime], [PlayerId, Now]).

%% 获取角色在线时间
get_player_online_time(PlayerId) ->
	?DB_MODULE:select_all(log_online_time, "otime", [{player_id, PlayerId}], [{id, desc}], [1]).

%% 更新在线时间
update_player_online_time(PlayerId, OnlineTime, Otime) ->
	?DB_MODULE:update(?LOG_POOLID, log_online_time, [{otime, OnlineTime}], [{player_id, PlayerId}, {otime, Otime}]).

get_midaward_date(Table,RelaNameStr1,RelaNameStr2) ->
	?DB_MODULE:select_row(Table, "rela", [{rela, "in", [RelaNameStr1,RelaNameStr2]}]).
insert_midaward_data(Table, Fields, Values) ->
	?DB_MODULE:insert(Table, Fields, Values).
delete_midaward_date(Table,RelaNameStr1,RelaNameStr2) ->
	?DB_MODULE:delete(Table, [{rela, "in", [RelaNameStr1,RelaNameStr2]}]).
get_close_ok(CloseLimit) ->
	?DB_MODULE:select_all(relationship, "idA,idB", [{close, ">=", CloseLimit}], [],[]).
get_player_name(PlayerId) ->
	?DB_MODULE:select_row(player, "nickname", [{id, PlayerId}], [], [1]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%跨服战场%%%%%%%%%%%%%%%%%%%%%%%%%%
%%加载有参战资格的服务器列表
select_server_all()->
	?DB_MODULE:select_all(base_war_server, "platform,sn,name,state", [], [{sn,asc}], []).
select_server(Platform)->
	?DB_MODULE:select_all(base_war_server, "sn,name,state", [{platform,Platform}], [], []).
select_server_state(Platform,Sn)->
	?DB_MODULE:select_row(base_war_server,"state",[{platform,Platform},{sn,Sn}],[], [1]).
select_server_ip(Platform,Sn)->
	?DB_MODULE:select_row(base_war_server,"ip,port",[{platform,Platform},{sn,Sn}],[], [1]).

%%获取玩家信息
get_player_bag(Timestamp)->
%% 	?DB_MODULE:select_all(war_player,"pid,nickname",[{sign_up,1},{enter,1}],[],[]).
	?DB_MODULE:select_all(player,"id,nickname",[{lv,">=",30},{last_login_time,">=",Timestamp}],[],[]).
check_war_player(PlayerId)->
	?DB_MODULE:select_row(war_player,"pid",[{pid,PlayerId},{sign_up,1},{enter,1}]).

%%新加跨服战场玩家信息
insert_war_player(PlayerId,NickName,Realm,Career,Level,Platform,Sn,Times,IsInvite,Sex,Att)->
	WarPlayer  = #ets_war_player{
						pid=PlayerId,
						nickname=NickName,
						realm=Realm,
						career = Career,
						level=Level,
						platform = Platform,
						sn=Sn,
						times = Times,
						sex=Sex,
						is_invite=IsInvite,
						att =  Att,
						sign_up=1
						}, 
    ValueList = lists:nthtail(2, tuple_to_list(WarPlayer)),
    [id | FieldList] = record_info(fields, ets_war_player),
	Ret = ?DB_MODULE:insert(war_player, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.

copy_war_player(ValueList,WhereList)->
	 ?DB_MODULE:insert(war_player,ValueList,WhereList).

%%加载跨服战场玩家信息
select_war_player()->
	?DB_MODULE:select_all(war_player, "*", [{id, ">", 0}], [], []).


select_war_player_id()->
	?DB_MODULE:select_all(war_player, "pid", [{sign_up,1}], [], []).


select_war_player_by_id(PlayerId)->
	?DB_MODULE:select_row(war_player,"*",[{pid,PlayerId}]).

%%更新跨服战场玩家信息
update_war_player(ValueList,WhereList)->
	?DB_MODULE:update(war_player,ValueList,WhereList).

%%清除跨服战场玩家信息
clear_war_player()->
	?DB_MODULE:delete(war_player,[]).


delete_war_player(Id)->
	?DB_MODULE:delete(war_player,[{id,Id}]).

%%参赛日志
log_war_player(PlayerId,Times,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID,log_war_player,[{pid,PlayerId},{times,Times},{timestamp,Timestamp}]).

%%添加队伍信息
insert_war_team(Platform,Sn,Name,Team,Lv,Times,Point)->
	Ret = ?DB_MODULE:insert(war_team,[platform,sn,name,team,lv,times,point],[Platform,Sn,Name,Team,Lv,Times,Point]),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.

%%加载跨服战场队伍信息
select_war_team_all()->
	?DB_MODULE:select_all(war_team, "*", [{id, ">", 0}], [], []).
select_war_team(Times)->
	?DB_MODULE:select_all(war_team, "*", [{times,Times}], [], []).

%%获取指定队伍信息
select_war_team_by_lv(Times,Lv,Type)->
	?DB_MODULE:select_all(war_team, 
								 "id,platform,sn,name", 
								 [{times,Times},{lv,Lv}],
						  		 [{point,Type},{total,Type},{id,Type}], []).


select_war_team_by_lv(Times,Lv)->
	?DB_MODULE:select_all(war_team, 
								 "id,platform,sn,name", 
								 [{times,Times},{lv,Lv}],
						  		 [{id,asc}], []).

select_war_team_by_times(Times)->
	?DB_MODULE:select_all(war_team, 
								 "id", 
								 [{times,Times}],
						  		 [{id,asc}], []).
select_war_team_info(Platform,Sn,Times)->
	?DB_MODULE:select_all(war_team, 
								 "id", 
								 [{platform,Platform},{sn,Sn},{times,Times}],
						  		 [{id,asc}], []).

%%更新跨服战场队伍信息
update_war_team(ValueList,WhereList)->
	?DB_MODULE:update(war_team,ValueList,WhereList).

%%删除跨服战场队伍信息
delete_war_team(Times)->
	?DB_MODULE:delete(war_team,[{times,Times}]).

%%添加对战队伍信息
insert_war_vs(PlatformA,SnA,NameA,PlatformB,SnB,NameB,Times,Lv,Round,ResA,ResB,Timestamp)->
	Ret = ?DB_MODULE:insert(war_vs,[platform_a,sn_a,name_a,platform_b,sn_b,name_b,times,lv,round,res_a,res_b,timestamp],[PlatformA,SnA,NameA,PlatformB,SnB,NameB,Times,Lv,Round,ResA,ResB,Timestamp]),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.

%%加载对战队伍信息
select_war_vs()->
	?DB_MODULE:select_all(war_vs, "*", [{id, ">", 0}], [], []).

%%更新跨服战场队伍对战信息
update_war_vs(ValueList,WhereList)->
	?DB_MODULE:update(war_vs,ValueList,WhereList).
%%清除对战信息
delete_war_vs()->
	?DB_MODULE:delete(war_vs,[]).

%%新加大会状态
insert_war_state()->
	?DB_MODULE:insert(war_state,[times],[1]).
%%查询大会状态
select_war_state()->
	?DB_MODULE:select_row(war_state,"type,times,state,lv,round,max_round",[],[1]).

%%更新大会状态
update_war_state(ValueList,WhereList)->
	?DB_MODULE:update(war_state,ValueList,WhereList).

%%加载玩家评价表
load_appraise_data() ->
	?DB_MODULE:select_all(appraise, "*", [{id,">",0}]).

insert_appraise(Owner_id, OtherId, Type,Adore_num,Handle_num,Ct) ->
	?DB_MODULE:insert(appraise, [owner_id, other_id, type, adore_num, handle_num, ct], [Owner_id, OtherId, Type,Adore_num,Handle_num,Ct]).

update_appraise(Adore_num,Handle_num,Ct,Id) ->
	?DB_MODULE:update(appraise, [{adore_num,Adore_num},{handle_num,Handle_num},{ct,Ct}], [{id,Id}]).

get_goods_type(Gid) ->
	?DB_MODULE:select_one(goods, "goods_id", [{id,Gid}], [], [1]).

get_war_equip_list(PlayerId) ->
	?DB_MODULE:select_all(goods, "*", [{player_id, PlayerId}, {location,"in" ,[1,2]}]).

get_war_mount_list(PlayerId)->
	?DB_MODULE:select_all(goods, "*", [{player_id, PlayerId}, {type,10},{subtype,22}]).

get_war_equip_attr_list(PlayerId, GoodsId) ->
	?DB_MODULE:select_all(goods_attribute, "*", [{player_id, PlayerId}, {gid, GoodsId}]).

check_equip_att(PlayerId) ->
	?DB_MODULE:select_all(goods_attribute, "*", [{player_id, PlayerId}]).

get_war_title_by_id(PlayerId)->
	?DB_MODULE:select_row(player_other, "ptitles,ptitle,quickbar,war_honor", [{pid, PlayerId}], [], [1]).

get_war_deputy_equip(PlayerId)->
	?DB_MODULE:select_all(deputy_equip, "*", [{pid, PlayerId}]).

%%加载所有的氏族结盟/归附数据
load_all_guild_union() ->
	?DB_MODULE:select_all(guild_union, 
						  "id, agid, bgid, agname, bgname, acid, bcid, acname, bcname, alv, blv, amem, bmem, type, apt, unions", 
						  [{id,">",0}]).
%%氏族结盟/归附的数据库操作
db_update_union(Table, ValueList, WhereList) ->
	?DB_MODULE:update(Table,ValueList,WhereList).
db_delete_union(Table, WhereList) ->
	?DB_MODULE:delete(Table,WhereList).
db_insert_union(GUnion) ->
	#guild_union{agid = Agid,                               				%% A氏族Id	
				 bgid = Bgid,                               				%% B氏族Id	
				 agname = AGName,                            				%% A氏族名称	
				 bgname = BGName,                            				%% B氏族名称	
				 acid = ACId,                           					%% A氏族族长ID	
				 bcid = BCId,                               				%% B氏族族长ID	
				 acname = ACName,                            				%% A氏族族长名称	
				 bcname = BCName,                          					%% B氏族族长名称	
				 alv = ALv,                               					%% A氏族等级	
				 blv = BLv,                               					%% B氏族等级	
				 amem = AMem,            									%% A氏族成员情况[当前人口数，人口最大容量]	
				 bmem = BMem,            									%% B氏族成员情况[当前人口数，人口最大容量]	
				 type = Type,                               				%% 申请类型	
				 apt = Apt,                               					%% 申请时间	
				 unions = Union                               				%% 当前结盟或归附的状态，0：申请中；1，2，3，4：流程中	
				} = GUnion,
	AMemStr = util:term_to_string(AMem),
	BMemStr = util:term_to_string(BMem),
	ValueList = [Agid, Bgid, AGName, BGName, ACId, BCId, ACName, BCName, ALv, BLv, AMemStr, BMemStr, Type, Apt, Union],
    [id | FieldList] = record_info(fields, guild_union),
	Ret = ?DB_MODULE:insert(guild_union, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.
add_gunion_log(Fields, Values) ->
	?DB_MODULE:insert(?LOG_POOLID, log_guild_union, Fields, Values).

get_war_equip_pet(PlayerId) ->
	?DB_MODULE:select_all(pet, "*", [{player_id, PlayerId}, {status, 1}]).


%%更新角色战斗力值
update_batt_value(Player_Id,Batt_value) ->
	?DB_MODULE:replace(batt_value,	[{player_id, Player_Id}, {value, Batt_value}]).

%%查询所有角色战斗力值
get_all_batt_value() ->
	?DB_MODULE:select_all(batt_value, "player_id,value", [{player_id, ">" , 0}],[{value, desc}],[]).

%%获取氏族祝福帮助日志
db_get_f5gwish(PId,ToDay) ->
	WhereList = [{pid, PId}, {time, ">", ToDay}],
	?DB_MODULE:select_all(log_f5_gwish,
					   "id,pid,hpid,hpname,hluck,ocolor,ncolor,tid,time",
					   WhereList,
					   [{desc, time}], [50]).
db_insert_gwish(Table, Fields, Values) ->
	?DB_MODULE:insert(Table, Fields, Values).
db_get_gwish(Table, FieldsList, WhereList) ->
	?DB_MODULE:select_row(Table, FieldsList, WhereList, [], [1]).
db_update_gwish(Table, ValueList, WhereList) ->
	?DB_MODULE:update(Table,ValueList,WhereList).
db_delete_gwish(Table, WhereList) ->
	?DB_MODULE:delete(Table,WhereList).

%%查询所有的灵兽
query_all_pet() ->
	?DB_MODULE:select_all(pet, "*", [{id, ">", 0}]).


%%添加vip信息
insert_vip_info(PlayerId,Times,Timestamp)->
	Ret = ?DB_MODULE:insert(vip_info,[pid,times,timestamp],[PlayerId,Times,Timestamp]),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.

%%获取vip信息
select_vip_info(PlayerId)->
	?DB_MODULE:select_row(vip_info,"*",[{pid,PlayerId}]).

%%更新VIp信息
update_vip_info(ValueList,WhereList)->
	?DB_MODULE:update(vip_info,ValueList,WhereList).
add_gwish_logs(F5GWish) ->
	#ets_f5_gwish{pid = DPId,                                %% 玩家Id(被刷的玩家的Id)	
				  hpid = SPId,                               %% 帮忙刷新的玩家的Id	
				  hpname = SPName,                            %% 帮忙刷新的玩家的名字	
				  hluck = Luck,                              %% 帮忙刷新的玩家的运势	
				  ocolor = DOTColor,                            %% 被帮忙的玩家原来的任务运势等级，N：N星	
				  ncolor = TColor,                             %% 被帮忙的玩家新的任务运势等级，N：N星	
				  tid = TId,
				  time = NowTime                                %% .0帮忙时间	
				 } = F5GWish,
	ValueList = [DPId, SPId, SPName, Luck, DOTColor, TColor, TId, NowTime],
	[id | FieldList] = record_info(fields, ets_f5_gwish),
	Ret = ?DB_MODULE:insert(log_f5_gwish, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.

%%副法宝
add_deputy_equip(Fields,Values) ->
	?DB_MODULE:insert(deputy_equip,Fields,Values).

%%修改副法宝
mod_deputy_equip(ValueList,WhereList) ->
	?DB_MODULE:update(deputy_equip,ValueList,WhereList).
	
%%把全服的称号集数据load出来，最多11条数据
load_server_titles(Fields, Types) ->
	?DB_MODULE:select_all(server_titles, Fields, [{type, "in", Types}], [], []).
%% init_title_data(Type) ->
%% 	IdsStr = util:term_to_string([]),
%% 	Fields = [type, ids],
%% 	?DB_MODULE:insert(server_titles,Fields,[Type,IdsStr]).
db_insert_server_titles(Table, Fields, Values) ->
	?DB_MODULE:insert(Table, Fields, Values).
delete_server_titles(Table, WhereList) ->
	?DB_MODULE:delete(Table,WhereList).
select_server_titles(Table, FieldList, WhereList) ->
	?DB_MODULE:select_row(Table, FieldList, WhereList, [], [1]).
update_server_titles(Table, ValueList, WhereList) ->
	?DB_MODULE:update(Table,ValueList,WhereList).
%%新手礼包
init_novice_gift(PlayerId,Timestamp)->
	Data  = #ets_novice_gift{
						pid=PlayerId,
						timestamp=Timestamp
						}, 
    ValueList = lists:nthtail(2, tuple_to_list(Data)),
    [id | FieldList] = record_info(fields, ets_novice_gift),
	Ret = ?DB_MODULE:insert(novice_gift, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.
%%获取玩家新手礼包领取信息
select_novice_gift(PlayerId)->
	?DB_MODULE:select_row(novice_gift,"*",[{pid,PlayerId}]).
%%更新玩家新手礼包领取信息
update_novice_gift(ValueList,WhereList)->
	 ?DB_MODULE:update(novice_gift,ValueList,WhereList).

%%做成就数据兼容性处理需要用到的方法
find_allcompare_ach_fslg() ->
	?DB_MODULE:select_all(achieve_statistics,
					   "pid,fslg",
						  [{id, ">", 0}],
						  [], []).
update_compare_ach_fslg(ValueList, WhereList) ->
	?DB_MODULE:update(achieve_statistics, ValueList, WhereList).

%%查询VIP体验卡领取记录
check_vip_experience(PlayerId,Type)->
	?DB_MODULE:select_row(log_vip_experience,"goods_id",[{pid,PlayerId},{mark,Type}]).

%%添加VIP体验卡领取记录
insert_vip_experience(PlayerId,GoodsId,Timestamp,Type)->
	?DB_MODULE:insert(log_vip_experience,[pid,goods_id,mark,timestamp],[PlayerId,GoodsId,Type,Timestamp]).

%%氏族召唤功能专用
update_guild_call(Table, ValueList, WhereList) ->
	?DB_MODULE:update(Table, ValueList, WhereList).


%%加载跨服战场玩家积分奖励
select_war_award()->
	?DB_MODULE:select_all(war_award,"*",[],[],[]).

%%新加奖励信息
new_war_award(PlayerId,Point,Timestamp)->
	Data  = #ets_war_award{
						pid=PlayerId,
						point= Point,
						timestamp=Timestamp
						}, 
    ValueList = lists:nthtail(2, tuple_to_list(Data)),
    [id | FieldList] = record_info(fields, ets_war_award),
	Ret = ?DB_MODULE:insert(war_award, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.

new_war_award1(PlayerId,Grade,Rank,Point,Goods,NowTime)->
	Data  = #ets_war_award{
						pid=PlayerId,
						grade = Grade,
						rank = Rank,
						newp= Point,
						goods = Goods,
						timestamp=NowTime
						}, 
    ValueList = lists:nthtail(2, tuple_to_list(Data)),
    [id | FieldList] = record_info(fields, ets_war_award),
	Ret = ?DB_MODULE:insert(war_award, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.

%%更新跨服战场玩家积分奖励
update_war_award(ValueList,WhereList)->
	 ?DB_MODULE:update(war_award,ValueList,WhereList).

%%查询跨服奖励
select_war_award(PlayerId)->
	?DB_MODULE:select_row(war_award,"goods",[{pid,PlayerId}],[],[1]).

%%积分兑换日志
log_war_award(Pid,GoodsId,Num,Type,Point,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID,log_war_award,[pid,goods_id,num,type,point,timestamp],[Pid,GoodsId,Num,Type,Point,Timestamp]).

%%亲密度消耗日志
log_close_consume(IdA,IdB,Type,Close,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID,log_close_consume,[ida,idb,type,close,timestamp],[IdA,IdB,Type,Close,Timestamp]).

%%增加亲密度日志
log_close_add(Id,RequestId,ResponseId,Close,Time) ->
	?DB_MODULE:insert(?LOG_POOLID,log_close_add,[rela_id,idA,idB,close,time],[Id,RequestId,ResponseId,Close,Time]).

%%删除亲密度日志记录
delete_log_close(Rid) ->
	?DB_MODULE:delete(?LOG_POOLID,log_close_add, [{rela_id, Rid}]).

%% 攻城战报名
castle_rush_join(CastleRushList, GuildId) ->
	?DB_MODULE:delete(castle_rush_join, [{guild_id, GuildId}]),
	?DB_MODULE:insert(castle_rush_join, [guild_id, guild_lv, guild_num, guild_name, guild_chief, ctime], CastleRushList).

%% 初始攻城战信息
init_castle_rush_info(BossHp) ->
	?DB_MODULE:insert(castle_rush_info, [boss_hp], [BossHp]).

%% 获取攻城战信息
get_castle_rush_info() ->
	?DB_MODULE:select_row(castle_rush_info, "*", [], [], [1]).

%% 获取城战信息
get_castle_rush_info_by_field(Field) ->
	?DB_MODULE:select_one(castle_rush_info, Field, [], [], [1]).

%%获取单条结婚记录
get_marry_info(Id) ->
	?DB_MODULE:select_row(marry, "*", [{id, Id}], [], [1]).

%%获取单条结婚记录(现在没有过滤条件，原来有{do_wedding,1},{divorce,0})
get_marry_row(PlayerId,Field) ->
	?DB_MODULE:select_row(marry, "*", [{Field, PlayerId}], [], [1]).

%%根据男方ID
get_marry_by_boy(BoyId) ->
	?DB_MODULE:select_one(marry, "do_wedding", [{boy_id, BoyId}], [], [1]).

del_marry_by_boy(Bid) ->
	?DB_MODULE:delete(marry, [{boy_id, Bid}]).

%%根据女方ID
get_marry_by_girl(GirlId) ->
	?DB_MODULE:select_one(marry, "do_wedding", [{girl_id, GirlId}], [], [1]).

del_marry_by_girl(Gid) ->
	?DB_MODULE:delete(marry, [{girl_id, Gid}]).


%%查询未能正常举办的婚宴
get_expire_wedding(Now) ->
	?DB_MODULE:select_all(wedding, "*", [{do_wedding,0},{book_time,"<",Now}],[],[]).

%%查询当天还未举办的婚宴
get_today_wedding(TodaySec) ->
	?DB_MODULE:select_all(wedding, "*", [{do_wedding,0},{wedding_start,">",TodaySec}],[],[]).

%%结婚
do_marry(Now,BoyId,GirlId) ->
	?DB_MODULE:insert(marry, [boy_id,girl_id,marry_time],[BoyId,GirlId,Now]).

update_marry(ValueList,Where) ->
	?DB_MODULE:update(marry, ValueList, Where).

%%删除结婚记录
delete_marry_info(Id) ->
	?DB_MODULE:delete(marry, [{id, Id}]).

%%更新喜帖花费
update_invite_cost(Cost,Wid,Field) ->
	?DB_MODULE:update(wedding, [{Field, Cost}], [{id,Wid}]).

%%预订婚宴
insert_wedding(MarryId,Bid,Gid,BoyName,GirlName,WType,WNum,WStart,BookTime,Gold) ->
	?DB_MODULE:insert(wedding,[marry_id,boy_id,girl_id,boy_name,girl_name,wedding_type,wedding_num,wedding_start,book_time,gold],
					  [MarryId,Bid,Gid,BoyName,GirlName,WType,WNum,WStart,BookTime,Gold]).

update_marry_time(Id,Time) ->
	?DB_MODULE:update(marry, [{marry_time, Time}], [{id,Id}]).

update_divorce_time(Id,Time) ->
	?DB_MODULE:update(marry, [{div_time, Time}], [{id,Id}]).


%%根据男方名字获取婚宴记录
is_did_wedding(Name) ->
	?DB_MODULE:select_row(wedding, "*", [{boy_name, Name}], [], [1]).

is_wedding_booked(Num) ->
	?DB_MODULE:select_row(wedding, "*", [{wedding_num, Num}], [], [1]).

%%根据结婚ID查询婚宴
get_wedding_by_mid(Mid) ->
	?DB_MODULE:select_row(wedding, "*", [{marry_id, Mid}], [], [1]).

%%修改邀请好友
update_inv_ids(Field,Ids,Wid)->
	?DB_MODULE:update(wedding, [{Field, Ids}], [{id,Wid}]).

%%更新婚宴中收到的铜币、元宝
update_rec(Gold,Coin,MarryId)->
	?DB_MODULE:update(marry,[{rec_coin, Coin, add},{rec_gold, Gold, add}],[{id,MarryId}]).

%%婚宴结束
do_wedding_end(MarryId,WeddingId) ->
	?DB_MODULE:update(marry, [{do_wedding, 1}], [{id,MarryId}]),
	?DB_MODULE:update(wedding, [{do_wedding, 1}], [{id,WeddingId}]).

%%删除婚宴记录
delete_wedding(WeddingId) ->
		?DB_MODULE:delete(wedding, [{id, WeddingId}]).

%%删除婚宴记录
delete_wedding_by_boy(Bid) ->
		?DB_MODULE:delete(wedding, [{boy_id, Bid}]).

delete_wedding_by_girl(Gid) ->
		?DB_MODULE:delete(wedding, [{girl_id, Gid}]).

%%结婚日志
log_add_marry(Bid,Gid,Coin,Time) ->
	?DB_MODULE:insert(?LOG_POOLID, log_marry, [boy_id,girl_id,coin,marry_time], [Bid, Gid, Coin, Time]).

%%婚宴日志
log_add_wedding(Bid,Gid,Wid,Gold,IsWedding,BookTime,W_num) ->
	?DB_MODULE:insert(?LOG_POOLID, log_wedding, [boy_id, girl_id, wedding_id, gold, is_wedding, book_time, wedding_num], [Bid,Gid,Wid,Gold,IsWedding,BookTime,W_num]).

%%婚宴日志更新
log_update_wedding(Wid) ->
	?DB_MODULE:update(?LOG_POOLID, log_wedding, [{is_wedding, 1}], [{wedding_id, Wid}]).

%%婚宴购买喜帖日志
log_wedding_pay_inv(Bname,Gname,Bc,Gc) ->
	?DB_MODULE:insert(?LOG_POOLID, log_wedding_pay_inv, [boy_name,girl_name,boy_cost,girl_cost], [Bname,Gname,Bc,Gc]).

%%贺礼日志
log_wedding_gift(Sid,Sname,Rname,Stime,Gold,Coin) ->
	?DB_MODULE:insert(?LOG_POOLID, log_wedding_gift,[sender_id,sender_name,receive_name,send_time,gold,coin],[Sid,Sname,Rname,Stime,Gold,Coin]).

%%取消婚期日志
log_cancel_wedding(Wid,Wstart,Wnum,Wgold,Ctime,Ccost) ->
	?DB_MODULE:insert(?LOG_POOLID, log_cancel_wedding, [w_id,w_start,w_num,w_gold,cancel_time,cancel_cost], [Wid,Wstart,Wnum,Wgold,Ctime,Ccost]).

%%离婚日志
log_divorce(Mid,ReqId,BoyId,Gid,Type,DivTime) ->
	?DB_MODULE:insert(?LOG_POOLID, log_divorce, [marry_id,req_id,boy_id,girl_id,type,div_time],[Mid,ReqId,BoyId,Gid,Type,DivTime]).

%% 更新龙塔得血量值
update_castle_rush_boss_hp(Hp) ->
	?DB_MODULE:update(castle_rush_info, [{boss_hp, Hp}], []).

%% 更新攻城战信息
update_castle_rush_info(ValList) ->
	?DB_MODULE:update(castle_rush_info, ValList, []).

%% 获取参加攻城战的氏族
get_castle_rush_join_guild_list() ->
	?DB_MODULE:select_all(castle_rush_join, "*", [], [], []).

get_castle_rush_join_by_guild_id(GuildId) ->
	?DB_MODULE:select_one(castle_rush_join, "id", [{guild_id, GuildId}], [], [1]).

%% 清楚攻城战报名列表
delete_castle_rush_join_list() ->
	?DB_MODULE:delete(castle_rush_join, []).

%% 删除氏族战功排行
del_castle_rush_guild_rank() ->
	?DB_MODULE:delete(castle_rush_guild_rank, []).

%% 添加氏族战功数据
insert_castle_rush_guild_data(CastleRushData) ->
	?DB_MODULE:insert(castle_rush_guild_rank, [guild_id, guild_name, guild_lv, member, score], CastleRushData).

%% 获取参加攻城战的氏族
get_castle_rush_guild_rank() ->
	?DB_MODULE:select_all(castle_rush_guild_rank, "guild_id, guild_name, guild_lv, member, score", [], [], []).

%% 删除个人战功排行
del_castle_rush_player_rank() ->
	?DB_MODULE:delete(castle_rush_player_rank, []).

%% 添加个人战功数据
insert_castle_rush_player_data(CastleRushData) ->
	?DB_MODULE:insert(castle_rush_player_rank, [player_id, nickname, guild_id, career, lv, kill, die, guild, person, feats], CastleRushData).

%% 获取参加攻城战的氏族
get_castle_rush_player_rank() ->
	?DB_MODULE:select_all(castle_rush_player_rank, "player_id, nickname, guild_id, career, lv, kill, die, guild, person, feats", [], [], []).

%% 更新领取攻城战税收时间
update_castle_rush_tax_time(PlayerId, TaxTime) ->
	?DB_MODULE:update(player, [{prestige, TaxTime}], [{id, PlayerId}]).

%% 获取攻城战奖励成员
get_castle_rush_award_member(GuildId) ->
	?DB_MODULE:select_all(castle_rush_player_rank, "player_id, nickname, feats", [{guild_id, GuildId}], [], []).

%% 获取龙塔等级
get_castle_rush_mon_lv() ->
	?DB_MODULE:select_one(player, "lv", [], [{lv, desc}], [1]).

%% 获取城战税收时间
get_castle_rush_tax_time(PlayerId) ->
	?DB_MODULE:select_one(player, "prestige", [{id, PlayerId}], [], [1]).

%% castle_rush_test(Hp) ->
%% 	?DB_MODULE:insert(castle_rush_info, [boss_hp], [Hp]).



%%获取当前服务器的最高等级
get_max_level() ->
	?DB_MODULE:select_one(player, "lv", [{id, ">", 0}, {lv, ">", 37}], [{lv, desc}], [1]).

%% 获取最新的神魔乱斗中怪物的血量和攻击增量级数
get_mon_warfare() ->
	?DB_MODULE:select_all(mon_warfare, "mon_id, add", [{mon_id , ">", 0}], [], []).
%%更新神魔乱斗中怪物的血量和攻击增量级数
update_mon_warfare(ValueList, WhereList) ->
	 ?DB_MODULE:update(mon_warfare,ValueList,WhereList).
insert_mon_warfare(MonId) ->
	Fields = [mon_id, add],
	Values = [MonId, 1],
	?DB_MODULE:insert(mon_warfare, Fields, Values).

%%插入一条氏族联盟申请的记录接口
db_insert_alliance_apply(Data) ->
	ValueList = Data,
	FieldList = [agid,bgid,agname,bgname,alv,blv,arealm,brealm,amem,bmem,acid,bcid,acname,bcname,time],
	Ret = ?DB_MODULE:insert(guild_alliance_apply, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.
db_insert_alliance(Data) ->
	ValueList = Data,
	FieldList = [gid,bgid,bname,brealm],
	Ret = ?DB_MODULE:insert(guild_alliance, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.

%%删除氏族联盟的处理接口
delete_alliance(Table, WhereList) ->
	?DB_MODULE:delete(Table,WhereList).
%%因为氏族联盟而修改氏族数据
db_update_guild_alliance(ValueList, WhereList) ->
	?DB_MODULE:update(guild, ValueList, WhereList).
db_update_alliance(Table, ValueList, WhereList) ->
	?DB_MODULE:update(Table, ValueList, WhereList).
get_all_alliances() ->
	?DB_MODULE:select_all(guild_alliance, "id,gid,bgid,bname,brealm", [{id , ">", 0}], [], []).
get_all_alliance_apply() ->
	?DB_MODULE:select_all(guild_alliance_apply, "id,agid,bgid,agname,bgname,alv,blv,arealm,brealm,amem,bmem,acid,bcid,acname,bcname,time", [{id , ">", 0}], [], []).

insert_alliance_log(SourGid, DestGid, SourName, DestName, Type, NowTime) ->
	Data = [SourGid, DestGid, SourName, DestName, Type, NowTime],
	Fields = [agid,bgid,agname,bgname,type,time],
	?DB_MODULE:insert(?LOG_POOLID,log_guild_alliance,Fields,Data).

%%做一些特殊的成就数据记录
make_log_update_ach(PlayerId, Ach, Data, NowTime) ->
	Values = [PlayerId, Ach, Data, NowTime],
	Fields = [pid, ach, data, time],
	?DB_MODULE:insert(?LOG_POOLID, log_update_ach, Fields, Values).

%%坐骑
select_all_mount() ->
	?DB_MODULE:select_all(mount, "*", [], [], []).

select_all_mount_skill_split() ->
	?DB_MODULE:select_all(mount_skill_split, "*", [], [], []).

%%坐骑
select_all_mount(PlayerId) ->
	?DB_MODULE:select_all(mount, "*", [{player_id,PlayerId}], [], []).

%%坐骑
select_mount_info(MountId) ->
	?DB_MODULE:select_row(mount, "*", [{id,MountId}], [], [1]).

select_mount_skill_exp(PlayerId) ->
	?DB_MODULE:select_row(mount_skill_exp, "*", [{player_id,PlayerId}], [], [1]).

%%查询玩家最高等级的出站坐骑
select_out_mount_db(PlayerId) ->
	?DB_MODULE:select_row(mount, "*", [{player_id,PlayerId},{status,1}], [{level,desc}], [1]).

select_all_mount_skill_split(PlayerId) ->
	?DB_MODULE:select_all(mount_skill_split, "*", [{player_id,PlayerId}], [], []).

select_mount_skill_split(MountSkillSplitId) ->
	?DB_MODULE:select_row(mount_skill_split, "*", [{id,MountSkillSplitId}], [], [1]).
	
give_mount(Id,PlayerId,GoodsId,Name,Speed,Stren,Step,Level,Exp,Luck_val,Close,Color,Lp,Xp,Tp,Qp,Skill_1,Skill_2,Skill_3,Skill_4,Skill_5,Skill_6,Skill_7,Skill_8,Status,Icon,Title,Mount_val,Last_time,Ct) ->
	?DB_MODULE:replace(mount,	[{id,Id},{player_id,PlayerId},{goods_id,GoodsId},{name,Name},{speed,Speed},{stren,Stren},{step,Step},{level,Level},{exp,Exp},{luck_val,Luck_val},
								 	 {close,Close},{color,Color},{lp,Lp},{xp,Xp},{tp,Tp},{qp,Qp},{skill_1,Skill_1},{skill_2,Skill_2},{skill_3,Skill_3},{skill_4,Skill_4},{skill_5,Skill_5},
								     {skill_6,Skill_6},{skill_7,Skill_7},{skill_8,Skill_8},{status,Status},{icon,Icon},{title,Title},{mount_val,Mount_val},{last_time,Last_time},{ct,Ct}]).

save_mount(Id,Goods_id,Level,Exp,Luck_val,Close,Speed,Color,Stren,Step,Lp,Xp,Tp,Qp,Skill_1,Skill_2,Skill_3,Skill_4,Skill_5,Skill_6,Skill_7,Skill_8,Status,Icon,Last_time) ->
	ValueList = [{goods_id,Goods_id},{level,Level},{exp,Exp},{luck_val,Luck_val},{close,Close},{speed,Speed},{color,Color},{stren,Stren},{step,Step},{lp,Lp},{xp,Xp},{tp,Tp},{qp,Qp},
				 {skill_1,Skill_1},{skill_2,Skill_2},{skill_3,Skill_3},{skill_4,Skill_4},{skill_5,Skill_5},{skill_6,Skill_6},{skill_7,Skill_7},{skill_8,Skill_8},{status,Status},{icon,Icon},{last_time,Last_time}],
	WhereList = [{id,Id}],
	update_mount(ValueList, WhereList).

update_mount(ValueList, WhereList) ->
	?DB_MODULE:update(mount, ValueList, WhereList).

%% 坐骑放生
free_mount(MountId) ->
	?DB_MODULE:delete(mount, [{id,MountId}]).

%% 坐骑改名
rename_mount(MountId, Name) ->
	?DB_MODULE:update(mount,
								 [{name, Name}],
								 [{id, MountId}]
								).

%% 更新坐骑状态
mount_update_status(MountId,Status) ->
	?DB_MODULE:update(mount,
								 [{status, Status}],
								 [{id, MountId}]
								).

save_mount_skill_exp(PlayerId,Total_exp,Auto_step,Btn_1,Btn_2,Btn_3,Btn_4,Btn_5,Btn4_type,Btn5_type,Active_type) ->
	?DB_MODULE:insert(mount_skill_exp,[player_id,total_exp,auto_step,btn_1,btn_2,btn_3,btn_4,btn_5,btn4_type,btn5_type,active_type],[PlayerId,Total_exp,Auto_step,Btn_1,Btn_2,Btn_3,Btn_4,Btn_5,Btn4_type,Btn5_type,Active_type]).

update_mount_skill_exp(ValueList, WhereList) ->
	?DB_MODULE:update(mount_skill_exp, ValueList, WhereList).

save_mount_skill_split(PlayerId,Skill_id,Exp,Color,Level,Type) ->
	?DB_MODULE:insert(mount_skill_split,[player_id,skill_id,exp,color,level,type],[PlayerId,Skill_id,Exp,Color,Level,Type]).

update_mount_skill_split(ValueList, WhereList) ->
	?DB_MODULE:update(mount_skill_split, ValueList, WhereList).

delete_mount_skill_split(MountSkillSplitId) ->
	?DB_MODULE:delete(mount_skill_split, [{id,MountSkillSplitId}]).

delete_all_mount_skill_split(PlayerId) ->
	?DB_MODULE:delete(mount_skill_split, [{player_id,PlayerId}]).

update_mount_value(MountId,Level,Exp,MountVal) ->
	?DB_MODULE:update(mount, [{mount_val, MountVal},{level,Level},{exp,Exp}], [{id, MountId}]).

rank_mount_rank(POOLID,Num) ->
	?DB_MODULE:select_all(POOLID,mount, "player_id,id,name,level,color,step,mount_val", [{player_id, ">" , 0},{mount_val, ">", 0}],[{mount_val, desc}],[Num]).

%%player_id,id,name,level,color,step,title,mount_val
rank_mount_rank_all(POOLID) ->
	?DB_MODULE:select_all(POOLID,mount, "*", [],[{mount_val, desc}],[]).

%%更新斗兽榜数据
update_mount_arena(ValueList, WhereList) ->
	?DB_MODULE:update(mount_arena, ValueList, WhereList).

%%删除一条斗兽数据
delete_mount_arena(Id) ->
	?DB_MODULE:delete(mount_arena,[{id,Id}]).

%%斗兽挑战日志
log_mount_cge(DataList) ->
	?DB_MODULE:insert(?LOG_POOLID, log_mount_arena, [cge_pid,def_pid,cge_mid,def_mid,rounds,time,winner_mid,cge_rank,def_rank],DataList).

%%领取斗兽奖励日志表
log_mount_award(Data) ->
	?DB_MODULE:insert(?LOG_POOLID, log_mount_award, [pid,mid,cash,bcoin,goods_id,num,time],Data).
	
%%更新斗兽近况表
update_mount_recent(ValueList, WhereList) ->
	?DB_MODULE:update(mount_arena_recent, ValueList, WhereList).

log_mount_change([GId,Player_id,Nickname,Goods_id,Goods_name,Speed,Stren,Step,Level,Lp,Xp,Tp,Qp]) ->
	Now = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID,log_mount_change,[gid,player_id,nickname,goods_id,goods_name,speed,stren,step,level,lp,xp,tp,qp,ct],[GId,Player_id,Nickname,Goods_id,Goods_name,Speed,Stren,Step,Level,Lp,Xp,Tp,Qp,Now]).

log_mount_active_type([PlayerId,Nickname,Goods_id,Goods_name]) ->
	Now = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID,log_mount_active_type,[player_id,nickname,goods_id,goods_name,ct],[PlayerId,Nickname,Goods_id,Goods_name,Now]).

log_mount_oper_step([Mount_id,PlayerId,Nickname,Oper,Cost,Step1,Step2,Name1,Name2,Lp1,Lp2,Xp1,Xp2,Tp1,Tp2,Qp1,Qp2,Luck_val1,Luck_val2,Close1,Close2]) ->
	Now = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID,log_mount_oper_step,[mount_id,player_id,nickname,oper,cost,step1,step2,name1,name2,lp1,lp2,xp1,xp2,tp1,tp2,qp1,qp2,luck_val1,luck_val2,close1,close2,ct],[Mount_id,PlayerId,Nickname,Oper,Cost,Step1,Step2,Name1,Name2,Lp1,Lp2,Xp1,Xp2,Tp1,Tp2,Qp1,Qp2,Luck_val1,Luck_val2,Close1,Close2,Now]).

log_mount_oper_4sp([Mount_id,PlayerId,Nickname,Cost,Title1,Title2,Color1,Color2,Lp1,Lp2,Xp1,Xp2,Tp1,Tp2,Qp1,Qp2]) ->
	Now = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID,log_mount_oper_4sp,[mount_id,player_id,nickname,cost,title1,title2,color1,color2,lp1,lp2,xp1,xp2,tp1,tp2,qp1,qp2,ct],[Mount_id,PlayerId,Nickname,Cost,Title1,Title2,Color1,Color2,Lp1,Lp2,Xp1,Xp2,Tp1,Tp2,Qp1,Qp2,Now]).

log_mount_skill_split([Mount_split_id,Player_id,Nickname,Cash,SkillId,Exp,Color,Level,Type,Btn_Order]) ->
	Now = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID,log_mount_skill_split,[mount_split_id,player_id,nickname,cash,skillid,exp,color,level,type,btn_order,ct],[Mount_split_id,Player_id,Nickname,Cash,SkillId,Exp,Color,Level,Type,Btn_Order,Now]).

log_mount_split_oper([Mount_split_id,Player_id,Nickname,MountId,SkillId,Exp,Step,Level,Type,Sell_cash,Fetch_exp,OldSkill,NewSkill,OperType]) ->
	Now = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID,log_mount_split_oper,[mount_split_id,player_id,nickname,mount_id,skillid,exp,color,level,type,sell_cash,fetch_exp,oldskill,newskill,opertype,ct],[Mount_split_id,Player_id,Nickname,MountId,SkillId,Exp,Step,Level,Type,Sell_cash,Fetch_exp,OldSkill,NewSkill,OperType,Now]).

add_mount_to_arena(Data) ->
	?DB_MODULE:insert(mount_arena,[player_id, mount_id, rank, rank_award, player_name, realm, mount_step, mount_name, title, 
								   mount_typeid, mount_color,mount_level,mount_val,win_times,get_ward_time,recent_win], Data).

%%战报记录
add_battle_result(Winner,Losers,Rounds,Time,A_mount_id,A_player_name,A_mount_name,A_mount_color,A_mount_type,
				   B_mount_id,B_player_name,B_mount_name,B_mount_color,B_mount_type,InitData,Data) ->
	?DB_MODULE:insert(mount_battle_result,[winner,losers,rounds,time,a_mount_id,a_player_name,a_mount_name,a_mount_color,a_mount_type,
										   b_mount_id,b_player_name,b_mount_name,b_mount_color,b_mount_type,init,battle_data],[Winner,Losers,Rounds,Time,A_mount_id,A_player_name,A_mount_name,A_mount_color,A_mount_type,
				   B_mount_id,B_player_name,B_mount_name,B_mount_color,B_mount_type,InitData,Data]).
%%请求战报
select_battle_result(Id) ->
	?DB_MODULE:select_row(mount_battle_result, "*", [{id, Id}], [], [1]).

%%所有斗兽榜数据
select_all_mount_arena() ->
	?DB_MODULE:select_all(mount_arena, "*", [{player_id, ">" , 0},{mount_id, ">", 0}],[],[]).

%%斗兽竞技信息
select_mount_arena(PlayerId,MountId) ->
	?DB_MODULE:select_row(mount_arena, "*", [{player_id,PlayerId},{mount_id,MountId}], [], [1]).

%%斗兽近况信息
select_mount_recent(PlayerId) ->
	?DB_MODULE:select_row(mount_arena_recent, "*", [{player_id,PlayerId}], [], [1]).

add_mount_recent(Data) ->
	?DB_MODULE:insert(mount_arena_recent,[player_id, cge_times, gold_cge_times, last_cge_time, last_cost_time, recent],Data).

%% 获取斗兽信息
get_mount_arena_info() ->
    ?DB_MODULE:select_all(mount_arena, "*", [{mount_id, ">", 0},{player_id, ">",0},{rank, ">", 0}],[{rank, asc}],[]).

%%获取排名为0的所有坐骑
get_42f_info() ->
    ?DB_MODULE:select_all(mount_arena, "*", [{mount_id, ">", 0},{player_id, ">",0},{rank, 0}],[],[]).

get_out_arena_info() ->
    ?DB_MODULE:select_all(mount_arena, "*", [{mount_id, ">", 0},{player_id, ">",0},{rank, ">", ?MAX_MOUNT_NUM}],[],[]).

%% 插入玩家登陆日志
insert_login_user(PlayerId, NickName, Utime, Ip) ->
	?DB_MODULE:insert(?LOG_POOLID, log_login_user, [player_id, nickname, utime, ip], [PlayerId, NickName, Utime, Ip]).

%% 更新玩家登陆日志
upadte_login_user(PlayerId, Utime, Dtime) ->
	NewUtime = Utime - 5,
	?DB_MODULE:update(?LOG_POOLID, log_login_user, [{dtime, Dtime}], [{player_id, PlayerId}, {utime, ">", NewUtime}]).

%%查询经验找回玩家
check_find_exp_player(Timestamp)->
	?DB_MODULE:select_all(player,"id,lv,guild_id",[{lv,">=",25},{last_login_time,">=",Timestamp}],[],[]).

%%查询经验找回记录
select_find_exp(PlayerId)->
	?DB_MODULE:select_all(find_exp, "*", [{pid,PlayerId}], [], []).

%%添加经验找回记录
insert_find_exp(PlayerId,TaskId,Name,Type,Timestamp,Times,Lv,Exp,Spt)->
	?DB_MODULE:insert(find_exp,[pid,task_id,name,type,timestamp,times,lv,exp,spt],[PlayerId,TaskId,Name,Type,Timestamp,Times,Lv,Exp,Spt]).

%%更新经验找回数据
update_find_exp(ValueList,WhereList)->
	 ?DB_MODULE:update(find_exp,ValueList,WhereList).

%%删除经验找回奖励
delete_find_exp(Id)->
	?DB_MODULE:delete(find_exp,[{id,Id}]).

%%查找经验找回记录
check_find_exp_by_type(Type,TaskId,PlayerId)->
	?DB_MODULE:select_all(find_exp, "id", [{type,Type},{task_id,TaskId},{pid,PlayerId}], [], []).

%%查找任务日志
check_task_log_by_date(PlayerId,TaskId,Date1,Date2)->
	?DB_MODULE:select_all(task_log,"task_id",[{player_id,PlayerId},{task_id,TaskId},{finish_time,">",Date1},{finish_time,"<",Date2}],[],[]).

%%添加经验找回兑换日志
log_find_exp(PlayerId,TaskId,Name,Type,Date,Times,Lv,Exp,Spt,Timestamp,Money,Color)->
	?DB_MODULE:insert(?LOG_POOLID,log_find_exp,[pid,task_id,name,type,date,times,lv,exp,spt,timestamp,money,color],[PlayerId,TaskId,Name,Type,Date,Times,Lv,Exp,Spt,Timestamp,Money,Color]).

%%灵兽化形日志
log_pet_chenge(PlayerId,PetId,GoodsIdOld,GoodsIdNew,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID,log_pet_chenge,[pid,pet_id,goods_id_old,goods_id_new,timestamp],[PlayerId,PetId,GoodsIdOld,GoodsIdNew,Timestamp]).


%%加载任务包
get_task_bag()->
	?DB_MODULE:select_all(task_bag, "task_id,player_id", [],[], []).

%% 删除任务
del_task_bag(PlayerId,TaskId)->
	?DB_MODULE:delete(task_bag, [{player_id,PlayerId},{task_id,TaskId}]).

%% 获取神器
get_god_weapon()->
	?DB_MODULE:select_all(goods,"id,player_id",[{spirit,1},{type,10}],[],[]).

%%
get_mount_16009()->
	?DB_MODULE:select_all(goods,"id,player_id",[{goods_id,16009}],[],[]).

%%删除神器
del_god_weapon(GoodsId)->
	delete_goods(GoodsId).

%%load整个表的数据
load_anniversary() ->
	?DB_MODULE:select_all(anniversary_bless, "pid, pname, gid, time, content", [{id , ">", 0}], [], []).
%%删除所有过期的数据
delete_all_old_anniversary() ->
	?DB_MODULE:delete(anniversary_bless,[]).
%%插入玩家的祝福语句
insert_player_wish(PlayerId, PName, Gid, NowTime, Content) ->
%% 	?DEBUG("insert_player_wish", []),
	Fields = [pid, pname, gid, time, content],
	Values = [PlayerId, PName, Gid, NowTime, Content],
	?DB_MODULE:insert(anniversary_bless, Fields, Values).

%%删除大转盘的数据
delete_bigwheel_use(PlayerId,GoodsType) ->
	?DB_MODULE:delete(log_goods_counter, [{player_id, PlayerId}, {type, GoodsType}]).
%%更新猜灯谜的数据
update_lantern_riddles(ValueList, WhereList) ->
	?DB_MODULE:update(lantern_award,ValueList,WhereList).
%%新插一条猜灯谜的数据
insert_lantern_riddles(PlayerId) ->
	Fields = [pid,time,num,state,qid],
	Values = [PlayerId, 0, 0, 0, 0],
	?DB_MODULE:insert(lantern_award, Fields, Values).
%%获取玩家的猜灯谜数据
get_lantern_riddles(PlayerId) ->
	?DB_MODULE:select_row(lantern_award, "time, num, state, qid", [{pid, PlayerId}], [], [1]).

%%加载单人镇妖竞技奖励
get_single_td_award()->
	?DB_MODULE:select_all(td_single_award,"*",[],[],[]).

%%添加单人镇妖奖励
new_single_td_award(PlayerId,Lv,Order,Timestamp)->
	?DB_MODULE:insert(td_single_award,[pid,lv,order,timestamp],[PlayerId,Lv,Order,Timestamp]).

%%更新单人镇妖奖励
update_single_td_awrd(ValueList, WhereList)->
	?DB_MODULE:update(td_single_award,ValueList,WhereList).

%%新插一条猜灯谜的数据
%%删除单人镇妖奖励
del_single_td_award(PlayerId)->
	?DB_MODULE:delete(td_single_award,[{pid,PlayerId}]).

%%删除所有的单人镇妖奖励
del_single_td_award_all()->
	?DB_MODULE:delete(td_single_award,[]).

%%单人镇妖竞技榜奖励日志
log_single_td_award(PlayerId,Order,Lv,Spt,BCoin,Timestamp)->
	?DB_MODULE:insert(?LOG_POOLID,log_single_td_award,[pid,order,lv,spt,bcoin,timestamp],[PlayerId,Order,Lv,Spt,BCoin,Timestamp]).
get_player_feats(PlayerId) ->
	?DB_MODULE:select_one(guild_member,"feats_all",[{player_id,PlayerId}],[],[1]).

%%添加副本日志
log_dungeon_times(PlayerId,SceneId,Timestamp)->
	?DB_MODULE:insert(log_dungeon_times,[pid,scene_id,timestamp],[PlayerId,SceneId,Timestamp]).
%%查找副本日志
select_dungeon_log(PlayerId,SceneId,Timestamp1,Timestamp2)->
	?DB_MODULE:select_all(log_dungeon_times,"*",[{pid,PlayerId},{scene_id,SceneId},{timestamp,">=",Timestamp1},{timestamp,"<=",Timestamp2}],[],[]).
delete_dungeon_log(PlayerId,Timestamp)->
	?DB_MODULE:delete(log_dungeon_times,[{pid,PlayerId},{timestamp,"<",Timestamp}]).

%%添加经验找回日期日志
log_find_exp_date(PlayerId,Timestamp)->
	?DB_MODULE:insert(log_find_exp_date,[pid,timestamp],[PlayerId,Timestamp]).
%%查找经验找回日期日志
select_find_exp_date(PlayerId,Timestamp)->
	?DB_MODULE:select_all(log_find_exp_date,"timestamp",[{pid,PlayerId},{timestamp,">=",Timestamp}],[],[]).
%%删除经验找回日期日志
delete_find_exp_date(PlayerId,Timestamp)->
	?DB_MODULE:delete(log_find_exp_date,[{pid,PlayerId},{timestamp,"<",Timestamp}]).

%%查询充值反馈活动时间
get_payrew_time() ->
	?DB_MODULE:select_row(payrew_setting,"begtime,endtime",[{on,1}],[],[1]).

%%查询充值反馈活动内容
get_payrew_info(PlayerId) ->
	?DB_MODULE:select_row(payrew,"*",[{player_id,PlayerId}],[],[1]).
insert_payrew_info(PlayerId,Begtime,Endtime) ->
	?DB_MODULE:insert(payrew,[player_id,begtime,endtime,rewgold],[PlayerId,Begtime,Endtime,0]).
update_payrew_info(ValueList,WhereList) ->
	?DB_MODULE:update(payrew,ValueList,WhereList).

%%充值祈福活动相关
get_pay_pray_time(Now)->
	?DB_MODULE:select_row(pay_pray_setting,"begtime,endtime",[{begtime,"<",Now},{endtime,">",Now}],[{begtime,asc}],[1]).
get_pay_pray_info(PlayerId) ->
	?DB_MODULE:select_row(pay_pray,"ctime,mult,free,charge,st,et",[{player_id,PlayerId}],[],[1]).
insert_pay_pray_info(PlayerId,Ctime,Mult,Free,Charge,ST,ET) ->
	?DB_MODULE:insert(pay_pray,[player_id,ctime,mult,free,charge,st,et],[PlayerId,Ctime,Mult,Free,Charge,ST,ET]).
update_pay_pray_info(PlayerId,Ctime,Mult,Free,Charge,ST,ET) ->
	?DB_MODULE:update(pay_pray,[{ctime,Ctime},{mult,Mult},{free,Free},{charge,Charge},{st,ST},{et,ET}],[{player_id,PlayerId}]).

%%获取神魔乱斗玩家的绑定铜数据
get_warfare_award(Pid) ->
	?DB_MODULE:select_row(warfare_award, "time, award", [{pid, Pid}], [], [1]).
%%插入新的玩家的神魔乱斗的绑定铜数据
insert_warfare_award(Pid, LTime, Num) ->
	Fields = [pid, time, award],
	Values = [Pid, LTime, Num],
	?DB_MODULE:insert(warfare_award, Fields, Values).

%%玩家下线时更新玩家的绑定铜数据
update_warfare_award(Pid, LTime, Num) ->
	?DB_MODULE:update(warfare_award, [{time, LTime}, {award, Num}], [{pid, Pid}]).

%%获取物品的对应的附加属性列表
get_goods_attrlist_by_gidtype(Gid,AttType) ->
	?DB_MODULE:select_all(goods_attribute, "*", [{gid, Gid}, {attribute_type, AttType}]).


%%加载跨服单人竞技记录
select_war2_record()->
	?DB_MODULE:select_all(war2_record,"*",[],[],[]).

%%添加跨服单人竞技记录
insert_war2_record([PlayerId,NickName,Career,Sex,Lv,BattValue,Platform,Sn,Grade,State,Timestamp,Seed])->
	Data  = #ets_war2_record{
						 pid = PlayerId,
						 nickname = NickName,
						 career = Career,
						 sex = Sex, 		 
						 lv = Lv,
						 batt_value = BattValue,
						 platform = Platform,
						 sn = Sn,
						 grade = Grade,
						 state = State,
						 timestamp = Timestamp,
						 seed = Seed
						}, 
    ValueList = lists:nthtail(2, tuple_to_list(Data)),
    [id | FieldList] = record_info(fields, ets_war2_record),
	Ret = ?DB_MODULE:insert(war2_record, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.
%%更新跨服单人竞技记录
update_war2_record(ValueList,WhereList)->
	?DB_MODULE:update(war2_record,ValueList,WhereList).

%%清除跨服单人竞技记录
delete_war2_record()->
	?DB_MODULE:delete(war2_record,[]).
delete_war2_record(PlayerId)->
	?DB_MODULE:delete(war2_record,[{pid,PlayerId}]).

select_war2_record_by_id(PlayerId)->
	?DB_MODULE:select_row(war2_record,"*",[{pid,PlayerId}]).

%%加载跨服竞技淘汰赛记录
select_war2_elimination()->
	?DB_MODULE:select_all(war2_elimination,"*",[],[],[]).
%%清除跨服单人竞技淘汰赛记录
delete_war2_elimination()->
	?DB_MODULE:delete(war2_elimination,[]).
%%添加跨服单人竞技淘汰赛记录
insert_war2_elimination([PlayerId,Nickname,Lv,Career,Sex,BattValue,Platform,Sn,Grade,Subarea,Num,State,Win])->
	Data  = #ets_war2_elimination{
							  pid = PlayerId,
							  nickname = Nickname,
							  lv = Lv,
							  career = Career,
							  sex = Sex,
							  batt_value = BattValue,
							  platform = Platform,
							  sn = Sn,
							  grade = Grade,
							  subarea = Subarea,
							  num = Num,
							  state = State,
							  elimination = Win 
						}, 
    ValueList = lists:nthtail(2, tuple_to_list(Data)),
    [id | FieldList] = record_info(fields, ets_war2_elimination),
	Ret = ?DB_MODULE:insert(war2_elimination, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.

%%更新跨服单人竞技淘汰赛记录
update_war2_elimination(ValueList,WhereList)->
	?DB_MODULE:update(war2_elimination,ValueList,WhereList).

%%添加跨服单人竞技历史记录
insert_war2_history([Nickname,Enemy,State,Result,Timestamp])->
	?DB_MODULE:insert(war2_history,[nickname,type,enemy,state,result,timestamp],[Nickname,1,Enemy,State,Result,Timestamp]).
%%添加跨服单人竞技冠军记录
insert_war2_champion([Nickname,Career,Sex,Platform,Sn,Grade,Times,Timestamp])->
	?DB_MODULE:insert(war2_history,[nickname,career,sex,platform,sn,grade,times,timestamp],[Nickname,Career,Sex,Platform,Sn,Grade,Times,Timestamp]).

%%加载个人跨服竞技历史记录
select_war2_history(Nickname)->
	?DB_MODULE:select_all(war2_history,"id,enemy,result,state,timestamp",[{nickname,Nickname},{type,1}],[],[]).
%%加载跨服单人冠军记录
select_war2_champion(Grade)->
	?DB_MODULE:select_all(war2_history,"nickname,career,sex,platform,sn",[{grade,Grade},{type,0}],[{id,desc}],[2]). 

%%清除历史记录
delete_war2_history()->
	?DB_MODULE:delete(war2_history,[{type,1}]).

%%添加跨服单人竞技状态
insert_war2_state()->
	?DB_MODULE:insert(war2_state,[times,state],[1,0]).

%%加载跨服单人竞技状态
select_war2_state()->
	?DB_MODULE:select_row(war2_state,"times,state",[],[1]).

update_war2_state(ValueList,WhereList)->
	?DB_MODULE:update(war2_state,ValueList,WhereList).

%%添加新投注
new_war2_bet([PlayerId,Name,Type,Total,State,Nickname,BetId,Platform,Sn,Grade])->
	Data  = #ets_war2_bet{
						  pid = PlayerId,
						  name = Name,
						  type = Type,
						  total = Total,
						  state = State,
						  platform=Platform,
						  sn=Sn,
						  bet_id=BetId,
						  nickname=Nickname,
						  grade = Grade
						 }, 
	ValueList = lists:nthtail(2, tuple_to_list(Data)),
	[id | FieldList] = record_info(fields, ets_war2_bet),
	Ret = ?DB_MODULE:insert(war2_bet, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.

%%下注日志
log_war2_bet([PlayerId,Type,Total,Nickname,State,Timestamp])->
	?DB_MODULE:insert(?LOG_POOLID,log_war2_bet, [pid,type,total,nickname,state,timestamp], [PlayerId,Type,Total,Nickname,State,Timestamp]).

%% 加载所有投注
select_war2_bet()->
	?DB_MODULE:select_all(war2_bet,"*",[],[],[]).

%%删除所有投注
delete_war2_bet()->
	?DB_MODULE:delete(war2_bet,[]).

%%获取封神争霸功勋
select_war_honor(PlayerId)->
	?DB_MODULE:select_row(player_other,"war_honor",[{pid,PlayerId}]).

%%更新封神争霸贡献
update_war_honor(PlayerId,WarHonor)->
	?DB_MODULE:update(player_other,[{war_honor,WarHonor}],[{pid,PlayerId}]).

%%封神纪元
load_player_era_info(PlayerId) ->
	?DB_MODULE:select_row(fs_era, "*", [{player_id, PlayerId}]).
%%添加封神纪元信息
add_player_era_info(Keys,Values) ->
	?DB_MODULE:insert(fs_era,Keys,Values).

%%更新封神纪元通关信息
update_player_era_info(PlayerId,LvInfo,Prize) ->
	?DB_MODULE:update(fs_era,[{lv_info,LvInfo},{prize,Prize}],[{player_id,PlayerId}]).
%%更新封神纪元奖励信息
update_player_era_prize(PlayerId,Prize) ->
	?DB_MODULE:update(fs_era,[{prize,Prize}],[{player_id,PlayerId}]).
%%更新封神纪元属性
update_player_era_attribute(PlayerId,Attack,Hp,Mp,Def,AntiAll) ->
	?DB_MODULE:update(fs_era,[{attack,Attack},{hp,Hp},{mp,Mp},{def,Def},{anti_all,AntiAll}],[{player_id,PlayerId}]).
%%查找封神纪元通关记录保持者
get_era_top_player(Stage) ->
	?DB_MODULE:select_row(fs_era_top,"player_id,nickname,time",[{stage,Stage}],[{time,asc}],[1]).
%%更新封神纪元通关记录
update_era_top_player(PlayerId,Stage,Time) ->
	?DB_MODULE:update(fs_era_top,[{stage,Stage},{time,Time}],[{player_id,PlayerId}]).
update_era_top_player(PlayerId,Nickname,Stage,Time) ->
	?DB_MODULE:update(fs_era_top,[{player_id,PlayerId},{nickname,Nickname},{time,Time}],[{stage,Stage}]).
%%增加封神纪元通关记录
insert_era_top_player(PlayerId,Nickname,Stage,Time) ->
	?DB_MODULE:insert(fs_era_top,[player_id,nickname,stage,time],[PlayerId,Nickname,Stage,Time]).

%% 插入语句
insert(Table, FieldList, ValueList) ->
	?DB_MODULE:insert(Table, FieldList, ValueList).

%% 删除语句
delete(Table, WhereList) ->
	?DB_MODULE:delete(Table, WhereList).

%% 查找语句
select_all(Table, FieldList, WhereList, OrderByList) ->
	?DB_MODULE:select_all(Table, FieldList, WhereList, OrderByList, []).
select_all(Table, FieldList, WhereList, OrderByList, Num) ->
	?DB_MODULE:select_all(Table, FieldList, WhereList, OrderByList, [Num]).

%% 查找语句
select_one(Table, FieldList, WhereList) ->
	?DB_MODULE:select_one(Table, FieldList, WhereList, [], [1]).

%% 查找语句
select_row(Table, FieldList, WhereList) ->
	?DB_MODULE:select_row(Table, FieldList, WhereList).

%% 更新语句
update(Table, ValueList, WhereList) ->
	?DB_MODULE:update(Table, ValueList, WhereList).

%%获取跨服战报
select_war2_pape()->
?DB_MODULE:select_all(war2_pape,"*",[],[],[]).

%%删除所有战报
delete_war2_pape()->
	?DB_MODULE:delete(war2_pape,[]).

%%添加新战报
%% new_war2_pape([Grade,State,PidA,NameA,PA,SA,PidB,NameB,PB,SB,Round,Winner])->
%% 		Data  = #ets_war2_pape{
%% 						  grade=Grade,
%% 						  state=State,
%% 						  pid_a=PidA,
%% 						  name_a=NameA,
%% 						  platform_a=PA,
%% 						  sn_a=SA,
%% 						  pid_b=PidB,
%% 						 name_b=NameB,
%% 						  platform_b=PB,
%% 						  sn_b=SB,
%% 						  round=Round,
%% 						  winner=Winner
%% 						 },
new_war2_pape(Data)-> 
	ValueList = lists:nthtail(2, tuple_to_list(Data)),
	[id | FieldList] = record_info(fields, ets_war2_pape),
	Ret = ?DB_MODULE:insert(war2_pape, FieldList, ValueList),
	case ?DB_MODULE =:= db_mysql of
		true ->
			{mysql,Ret};
		_ ->
			{mongo, Ret}
	end.

%%魅力值增加日志
log_charm([Pid,Type,Cid,Flower,Charm,Timestamp])->
	?DB_MODULE:insert(?LOG_POOLID,log_charm,[pid,type,client_id,flower,charm,timestamp],[Pid,Type,Cid,Flower,Charm,Timestamp]).

%%镇妖功勋兑换日志
log_td_honor_consume([Pid,GoodsId,Num,Consume,Timestamp])->
	?DB_MODULE:insert(?LOG_POOLID,log_td_honor_consume,[pid,goods_id,num,consume,timestamp],[Pid,GoodsId,Num,Consume,Timestamp]).

%%获取夫妻传送技能CD
init_couple_skill(PlayerId)->
	?DB_MODULE:select_row(player_other,"couple_skill",[{pid,PlayerId}]).

update_couple_skill(PlayerId,CD)->
	?DB_MODULE:update(player_other,[{couple_skill,CD}],[{pid,PlayerId}]).
get_player_wardrobe(Pid) ->
	?DB_MODULE:select_row(fashion_equip, "yfid, yftj, fbid, fbtj, gsid, gstj", [{pid, Pid}], [], [1]).
insert_player_wardrobe(Fields, Values) ->
	?DB_MODULE:insert(fashion_equip, Fields, Values).
update_player_wardrobe(WhereList, ValueList) ->
	?DB_MODULE:update(fashion_equip, ValueList, WhereList).
update_goods_icon(Gid, NIcon) ->
	?DB_MODULE:update(goods,
					  [{icon, NIcon}],
					  [{id,Gid}]
					 ).
insert_log_fashion_equip(Pid,Sex,Type,EquipId) ->
	Time = util:unixtime(),
	?DB_MODULE:insert(?LOG_POOLID, log_wardrobe_activite,
					  [pid,sex,type,equipid,time],
					  [Pid,Sex,Type,EquipId,Time]).

%%添加物品开出新物品的记录
insert_log_goods_open(Pid, Gid, GoodsTypeId, GiveGoodsTypeId, GNum) ->
	NowTime = util:unixtime(),
	Fields = [pid, gid, goods_id, ggoods_id, gnum, time],
	Values = [Pid, Gid, GoodsTypeId, GiveGoodsTypeId, GNum, NowTime],
	?DB_MODULE:insert(?LOG_POOLID, log_goods_open,
					  Fields, Values).

%%更新物品的使用激活次数
update_goods_used(ValueList, WhereList) ->
	?DB_MODULE:update(goods, ValueList, WhereList).


%%新添目标
new_target(Target_gift)->
    ValueList = lists:nthtail(2, tuple_to_list(Target_gift)),
	[id | FieldList] = record_info(fields, ets_target),
	?DB_MODULE:insert(target, FieldList, ValueList).


%%删除玩家目标奖励记录
delete_target(PlayerId)->
	?DB_MODULE:delete(target,[{pid,PlayerId}]).

%%获取目标奖励玩家信息
select_target(PlayerId)->
	?DB_MODULE:select_row(target, 
								 "*", 
								 [{pid, PlayerId}],
						  		[],
						  		[1]
						  		).
 
update_target_old(ValueList, WhereList) ->
	?DB_MODULE:update(target, ValueList, WhereList).

%%更新目标奖励玩家信息
update_target(PlayerId,Type) ->
	?DB_MODULE:update(target,
								 [{Type,1}],
								[{pid,PlayerId}]
								 ).