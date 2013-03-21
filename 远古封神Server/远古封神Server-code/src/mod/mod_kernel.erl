%%%------------------------------------
%%% @Module  : mod_kernel
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 核心服务
%%%------------------------------------
-module(mod_kernel).
-behaviour(gen_server).
-export([
            start_link/0,
			load_base_data/0,
			load_base_data/1,
			reload_base_data/0,
			reload_base_data/1
        ]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-include("common.hrl").
-include("record.hrl").
-include("achieve.hrl").
-include("activity.hrl").
-include("guild_info.hrl").

-define(AUTO_LOAD_GOODS, 10*60*1000).  %%每10分钟加载一次数据(正式上线后，去掉)

start_link() ->
    gen_server:start_link({local,?MODULE}, ?MODULE, [], []).

init([]) ->
	misc:write_monitor_pid(self(),?MODULE, {0}),
    %%初始ets表
    ok = init_ets(),
    %%初始数据库
	ok = yg:init_db(server),
	%% 加载基础数据 
	ok = load_base_data(),
	
	%% 初始双倍经验活动数据
	load_exp_activity(),
	
	%% 服务初始化是删除某些数据
	delete_data(),
    {ok, 1}.

handle_cast({set_load, Load_value}, Status) ->
	io:format("~s Server stopping......~n",[misc:time_format(now())]),	
	misc:write_monitor_pid(self(),?MODULE, {Load_value}),
	{noreply, Status};

handle_cast(_R , Status) ->
    {noreply, Status}.

handle_call(_R , _FROM, Status) ->
    {reply, ok, Status}.

handle_info({event, load_data}, Status) ->
	%% 加载基础数据
	load_base_data(),

	erlang:send_after(?AUTO_LOAD_GOODS, self(), {event, load_data}),  %% 重复加载一次数据
	{noreply, Status};

handle_info(_Reason, Status) ->
    {noreply, Status}.

terminate(normal, Status) ->
	misc:delete_monitor_pid(self()),
    {ok, Status}.

code_change(_OldVsn, Status, _Extra)->
    {ok, Status}.

%% ================== 私有函数 =================
%%重加载基础数据 暂时只添加物品，按需求添加
reload_base_data() ->
	reload_base_data(goods),
	ok.

reload_base_data(goods) ->
	goods_util:reload_goods(),
	ok.

%%服务启动时删除指定数据
delete_data() ->
	Now = util:unixtime(),
	%%五一活动开始和结束时间
	{TGStart, _TGEnd} = lib_activities:all_may_day_time(),
	if
		%% 活动前清空活动表
		Now < TGStart ->
			db_agent:del_mid_prize_table();
		true ->
			skip
	end.

%% 加载基础数据
load_base_data() ->
	load_base_data(goods),
	load_base_data(pet),
	load_base_data(scene),
	load_base_data(career),
	load_base_data(skill),
	load_base_data(task),
	load_base_data(meridian),
	load_base_data(target),
	load_base_data(business),
	load_base_privity(privity),
	load_base_herocard(herocard),
	load_base_daily_award(daily),
	load_base_tower_award(tower),
	ok.

load_base_data(goods) ->
    %%初始化物品类型及规则列表
    ok = goods_util:init_goods(),
	ok;

load_base_data(pet) ->
    %%初始化基础灵兽信息
    ok = lib_pet:load_base_pet(),
	ok = lib_pet:load_base_pet_skill_effect(),
	ok; 

load_base_data(scene) ->
	%%初始化基础Npc
	ok = lib_npc:init_base_npc(),
	%%初始化基础mon
	ok = lib_mon:init_base_mon(),	
	%%初始化基础场景信息(包括场景Npc和场景怪物)
	ok = lib_scene:init_base_scene(),
	%%初始化副本信息
	ok = lib_scene:init_base_dungeon(),	
	%%初始化国家场景分类信息
	ok = lib_npc:init_base_map(),
	ok;
load_base_data(career) ->
	%%初始化基础职业属性
	ok = lib_player:init_base_career(),	
	ok;
load_base_data(skill) ->
	%%初始化基础技能
	ok = lib_skill:init_base_skill(),	
	ok;
load_base_data(task) ->
	%%初始化基础任务
	ok = lib_task:init_base_task(),	
	%%初始化基础对话
	ok = lib_npc:init_base_talk(),
	ok;
load_base_data(meridian) ->
	%%初始化经脉基础数据
	ok = lib_meridian:init_base_meridian(),
	ok;
load_base_data(target)->
	%%初始化目标奖励
	ok = lib_target_gift:init_base_target_gift(),
	ok;

load_base_data(business)->
	%%初始化目标奖励
	ok = lib_business:init_base_business(),
	ok.

load_base_privity(privity)->
	%%初始化默契度测试题目
	ok = lib_love:init_base_privity(),
	ok.

load_base_herocard(herocard)->
	%%初始化封神贴奖励
	ok = lib_hero_card:init_base_award(),
	ok.

load_base_daily_award(daily) ->
	%%初始化每天在线奖励物品表
	ok = lib_daily_award:init_daily_award_data(),
	ok.

load_base_tower_award(tower)->
	%%初始化塔奖励
	ok = lib_scene_fst:init_base_tower_award(),
	ok.

%% 初始双倍经验活动数据
load_exp_activity() ->
	[StartTime, EndTime] =
		case db_agent:get_exp_activity() of
			[] ->
				[0, 0];
			[St, Et] ->
				[util:string_to_term(tool:to_list(St)), util:string_to_term(tool:to_list(Et))]
		end,
	ExpActivity = #ets_exp_activity{
		st = StartTime,
		et = EndTime
	},
	ets:insert(?ETS_EXP_ACTIVITY, ExpActivity).

%%初始ETS表
init_ets() -> 
	ets:new(?ETS_BASE_MON, [{keypos, #ets_mon.mid}, named_table, public, set ,?ETSRC, ?ETSWC]), 									%% 基础_怪物信息
    ets:new(?ETS_BASE_NPC, [{keypos, #ets_npc.nid}, named_table, public, set ,?ETSRC, ?ETSWC]), 									%% 基础_NPC信息
	
	ets:new(?ETS_BASE_SCENE, [{keypos, #ets_scene.id}, named_table, public, set,?ETSRC, ?ETSWC]), 									%% 基础_场景信息
	ets:new(?ETS_BASE_SCENE_POSES, [named_table, public, bag ,?ETSRC, ?ETSWC]),   													%% 基本_场景坐标表
	ets:new(?ETS_BASE_SCENE_MON, [{keypos, #ets_mon.unique_key}, named_table, public, set,?ETSRC, ?ETSWC]), 						%% 基础_场景怪物信息
	ets:new(?ETS_BASE_SCENE_UNIQUE_MON, [{keypos, #ets_base_scene_unique_mon.id}, named_table, public, set,?ETSRC, ?ETSWC]), 		%% 基础_场景怪物唯一信息
    ets:new(?ETS_BASE_SCENE_NPC, [{keypos, #ets_npc.unique_key}, named_table, public, set,?ETSRC, ?ETSWC]), 						%% 基础_场景NPC信息
    ets:new(?ETS_BASE_DUNGEON, [{keypos, #dungeon.id}, named_table, public, set ,?ETSRC, ?ETSWC]),	    						%% 基础_副本信息

    ets:new(?ETS_BASE_CAREER, [{keypos, #ets_base_career.career_id}, named_table, public, set ,?ETSRC, ?ETSWC]), 					%% 基础职业属性

    ets:new(?ETS_BASE_GOODS, [{keypos, #ets_base_goods.goods_id}, named_table, public, set ,?ETSRC, ?ETSWC]),
    ets:new(?ETS_BASE_GOODS_ADD_ATTRIBUTE, [{keypos, #ets_base_goods_add_attribute.id}, named_table, public, set,?ETSRC, ?ETSWC]),
    ets:new(?ETS_BASE_GOODS_SUIT_ATTRIBUTE, [{keypos, #ets_base_goods_suit_attribute.id}, named_table, public, set,?ETSRC, ?ETSWC]),
	ets:new(?ETS_BASE_GOODS_SUIT,[{keypos,#ets_base_goods_suit.suit_id},named_table,public,set ,?ETSRC, ?ETSWC]),
    ets:new(?ETS_BASE_GOODS_STRENGTHEN, [{keypos, #ets_base_goods_strengthen.id}, named_table, public, set ,?ETSRC, ?ETSWC]),
    ets:new(?ETS_BASE_GOODS_STRENGTHEN_ANTI,[{keypos,#ets_base_goods_strengthen_anti.id},named_table,public,set ,?ETSRC, ?ETSWC]),
    ets:new(?ETS_BASE_GOODS_STRENGTHEN_EXTRA,[{keypos,#ets_base_goods_strengthen_extra.level},named_table,public,set ,?ETSRC, ?ETSWC]),
    ets:new(?ETS_BASE_GOODS_PRACTISE,[{keypos,#ets_base_goods_practise.id},named_table,public,set ,?ETSRC, ?ETSWC]),
    ets:new(?ETS_BASE_GOODS_COMPOSE, [{keypos, #ets_base_goods_compose.id}, named_table, public, set ,?ETSRC, ?ETSWC]),
    ets:new(?ETS_BASE_GOODS_INLAY, [{keypos, #ets_base_goods_inlay.id}, named_table, public, set ,?ETSRC, ?ETSWC]),
	ets:new(?ETS_BASE_GOODS_IDECOMPOSE,[{keypos,#ets_base_goods_idecompose.id},named_table,public,set ,?ETSRC, ?ETSWC]),
	ets:new(?ETS_BASE_GOODS_ICOMPOSE,[{keypos,#ets_base_goods_icompose.id},named_table,public,set ,?ETSRC, ?ETSWC]),
    ets:new(?ETS_BASE_GOODS_DROP_NUM, [{keypos, #ets_base_goods_drop_num.id}, named_table, public, set ,?ETSRC, ?ETSWC]),
    ets:new(?ETS_BASE_GOODS_DROP_RULE, [{keypos, #ets_base_goods_drop_rule.id}, named_table, public, set ,?ETSRC, ?ETSWC]),
	ets:new(?ETS_BASE_GOODS_ORE,[{keypos,#ets_base_goods_ore.goods_id},named_table,public,set ,?ETSRC, ?ETSWC]), 
    ets:new(?ETS_BASE_SHOP, [{keypos, #ets_shop.id}, named_table, public, set ,?ETSRC, ?ETSWC]),
    ets:new(?ETS_BASE_TALK, [{keypos, #talk.id}, named_table, public, set ,?ETSRC, ?ETSWC]),
    ets:new(?ETS_BASE_TASK, [{keypos, #task.id}, named_table, public, set ,?ETSRC, ?ETSWC]),
    ets:new(?ETS_BASE_SKILL, [{keypos, #ets_skill.id}, named_table, public, set ,?ETSRC, ?ETSWC]),	
	ets:new(?ETS_BASE_MAGIC, [{keypos, #ets_base_magic.id}, named_table, public, set ,?ETSRC, ?ETSWC]),	
	

    ets:new(?ETS_ONLINE, [{keypos,#player.id}, named_table, public, set ,?ETSRC, ?ETSWC]), 			%%本节点在线用户列表
	ets:new(?ETS_ONLINE_SCENE, [{keypos,#player.id}, named_table, public, set ,?ETSRC, ?ETSWC]),  	%%本节点加载场景在线用户列表	
	
    ets:new(?ETS_SCENE, [{keypos, #ets_scene.id}, named_table, public, set ,?ETSRC, ?ETSWC]), 			%%本节点场景信息
    ets:new(?ETS_SCENE_MON, [{keypos, #ets_mon.unique_key}, named_table, public, set ,?ETSRC, ?ETSWC]), %%本节点怪物信息
    ets:new(?ETS_SCENE_NPC, [{keypos, #ets_npc.unique_key}, named_table, public, set ,?ETSRC, ?ETSWC]), %%本节点NPC信息
	ets:new(?ETS_BLACKLIST,[{keypos,#ets_blacklist.id},named_table,public,set ,?ETSRC, ?ETSWC]),	%%黑名单操作记录表
	
    ets:new(?ETS_GOODS_ONLINE, [{keypos, #goods.id}, named_table, public, set ,?ETSRC, ?ETSWC]),  				%% 本节点在线玩家的背包物品表
    ets:new(?ETS_GOODS_ATTRIBUTE, [{keypos, #goods_attribute.id}, named_table, public, set ,?ETSRC, ?ETSWC]),  	%% 本节点在线玩家的物品属性表
    ets:new(?ETS_GOODS_DROP, [{keypos, #ets_goods_drop.unique_key}, named_table, public, set ,?ETSRC, ?ETSWC]), 		%% 物品掉落表
	ets:new(?ETS_GOODS_CD, [{keypos,#ets_goods_cd.id}, named_table,public ,set ,?ETSRC, ?ETSWC]),				%% 物品使用cd表 
	ets:new(?ETS_DEPUTY_EQUIP,[{keypos,#ets_deputy_equip.id} ,named_table,public,set,?ETSRC, ?ETSWC]),	    		%%	副法宝 
	ets:new(?ETS_HOLIDAY_INFO,[{keypos,#ets_holiday_info.pid},named_table,public,set ,?ETSRC, ?ETSWC]),			%%节日活动辅助信息表  
	
    ets:new(?ETS_ROLE_TASK, [{keypos, #role_task.id}, named_table, public, set ,?ETSRC, ?ETSWC]), 	%% 角色任务记录
    ets:new(?ETS_ROLE_TASK_LOG, [named_table, public, bag ,?ETSRC, ?ETSWC]),						%% 角色任务历史记录
    ets:new(?ETS_TASK_QUERY_CACHE, [named_table, public, set ,?ETSRC, ?ETSWC]),						%% 当前所有可接任务
 	ets:new(?ETS_TASK_CACHE, [named_table, public, set ,?ETSRC, ?ETSWC]),							%% 玩家任务缓存
	
    ets:new(?ETS_RELA, [{keypos,#ets_rela.id}, named_table, public, set ,?ETSRC, ?ETSWC]), 			%% 玩家关系记录
	ets:new(?ETS_DELAYER, [{keypos,#ets_delayer.id}, named_table, public, set ,?ETSRC, ?ETSWC]), 			%% 玩家延时信息
	ets:new(?ETS_BLACKBOARD, [{keypos,#ets_blackboard.id}, named_table, public, set ,?ETSRC, ?ETSWC]),		%% 招募小黑板

    ets:new(?ETS_BASE_PET, [{keypos,#ets_base_pet.goods_id}, named_table, public, set ,?ETSRC, ?ETSWC]),   %%宠物道具配置
    ets:new(?ETS_PET, [{keypos,#ets_pet.id}, named_table, public, set ,?ETSRC, ?ETSWC]),                   %%宠物
	ets:new(?ETS_PET_BUY, [{keypos,#ets_pet_buy.id}, named_table, public, set ,?ETSRC, ?ETSWC]),         %%灵兽购买
	ets:new(?ETS_PET_SPLIT_SKILL, [{keypos,#ets_pet_split_skill.id}, named_table, public, set ,?ETSRC, ?ETSWC]), %%灵兽分离技能    
	ets:new(?ETS_BASE_PET_SKILL_EFFECT,[{keypos,#ets_base_pet_skill_effect.id}, named_table, public, set ,?ETSRC, ?ETSWC]),%%灵兽技能效果表
	ets:new(?ETS_PET_EXTRA,[{keypos,#ets_pet_extra.player_id}, named_table, public, set ,?ETSRC, ?ETSWC]),%%灵兽技能效果表
  	ets:new(?ETS_PET_EXTRA_VALUE,[{keypos,#ets_pet_extra_value.player_id}, named_table, public, set ,?ETSRC, ?ETSWC]),%%灵兽额外信息日志表
	
	ets:new(?ETS_MANOR_ENTER, [{keypos, #ets_manor_enter.player_id}, named_table, public, set ,?ETSRC, ?ETSWC]), %%用户进入农场信息 Add By ZKJ
	ets:new(?ETS_FARM_INFO, [{keypos, #ets_farm_info.mid}, named_table, public, set ,?ETSRC, ?ETSWC]),  %%田地信息 Add By ZKJ
	ets:new(?ETS_MANOR_STEAL, [{keypos, #ets_manor_steal.steal_id}, named_table, public, set ,?ETSRC, ?ETSWC]), %%偷菜信息 Add By ZKJ 
	
	ets:new(?ETS_BASE_MERIDIAN, [{keypos, #ets_base_meridian.id}, named_table, public, set ,?ETSRC, ?ETSWC]), %%经脉基础属性
	ets:new(?ETS_MERIDIAN, [{keypos, #ets_meridian.player_id}, named_table, public, set ,?ETSRC, ?ETSWC]), %%玩家经脉属性
	ets:new(?ETS_ONLINE_GIFT, [{keypos, #ets_online_gift.player_id}, named_table, public, set ,?ETSRC, ?ETSWC]), %%在线奖励玩家表
	ets:new(?ETS_BASE_ONLINE_GIFT,[{keypos, #ets_base_online_gift.id}, named_table, public,set]), %%奖励物品表
	ets:new(?ETS_CARRY_TIME,[{keypos, #ets_carry_time.realm}, named_table, public,set ,?ETSRC, ?ETSWC]), %%国运时间
	ets:new(?ETS_BASE_MAP, [{keypos, #ets_base_map.scene_id}, named_table, public, set ,?ETSRC, ?ETSWC]),%%场景分类
	ets:new(?ETS_REALM, [named_table, public, set ,?ETSRC, ?ETSWC]),						%% 阵营玩家统计缓存
	ets:new(?ETS_TARGET_GIFT, [{keypos, #ets_target_gift.player_id}, named_table, public, set ,?ETSRC, ?ETSWC]), %%目标奖励玩家表
	ets:new(?ETS_BASE_TARGET_GIFT,[{keypos, #ets_base_target_gift.day}, named_table, public,set ,?ETSRC, ?ETSWC]), %%目标奖励物品表
	ets:new(?ETS_TASK_CONSIGN, [{keypos, #ets_task_consign.id}, named_table, public, set ,?ETSRC, ?ETSWC]), %%系统委托任务
	ets:new(?ETS_CONSIGN_TASK, [{keypos, #ets_consign_task.id}, named_table, public, set ,?ETSRC, ?ETSWC]), 	%% 角色委托任务列表
	ets:new(?ETS_CONSIGN_PLAYER, [{keypos, #ets_consign_player.pid}, named_table, public, set ,?ETSRC, ?ETSWC]), 	%% 委托任务角色数值列表
	ets:new(?ETS_CARRY,[{keypos, #ets_carry.pid}, named_table, public, set ,?ETSRC, ?ETSWC]), %%运镖次数表
	ets:new(?ETS_OFFLINE_AWARD,[{keypos, #ets_offline_award.pid}, named_table, public, set ,?ETSRC, ?ETSWC]), %%离线经验累积
	ets:new(?ETS_ONLINE_AWARD,[{keypos, #ets_online_award.pid}, named_table, public, set ,?ETSRC, ?ETSWC]), %%在线累积奖励
	ets:new(?ETS_VIP_MAIL, [named_table, public, bag ,?ETSRC, ?ETSWC]), %%vip邮件服务
	ets:new(?ETS_TITLE_MAIL, [named_table, public, bag ,?ETSRC, ?ETSWC]), %%称号邮件服务
	ets:new(?ETS_BASE_BUSINESS, [{keypos, #ets_base_business.id}, named_table, public, set ,?ETSRC, ?ETSWC]),
	ets:new(?ETS_BUSINESS,[{keypos, #ets_business.player_id}, named_table, public, set ,?ETSRC, ?ETSWC]), %%跑商数据表
	ets:new(?ETS_SAME_CAR,[named_table, public, set ,?ETSRC, ?ETSWC]), %%被劫商数据
	ets:new(?ETS_LOG_ROBBED,[named_table, public, bag ,?ETSRC, ?ETSWC]), %%劫商数据表
	ets:new(?ETS_ONLINE_AWARD_HOLIDAY,[{keypos, #ets_online_award_holiday.pid}, named_table, public, set ,?ETSRC, ?ETSWC]), %%节日登陆奖励
	ets:new(?ETS_HERO_CARD,[{keypos, #ets_hero_card.pid}, named_table, public, set ,?ETSRC, ?ETSWC]), %%英雄帖表 
	ets:new(?ETS_BASE_HERO_CARD, [{keypos, #ets_base_hero_card.id}, named_table, public, set ,?ETSRC, ?ETSWC]),
	ets:new(?ETS_LOVE,[{keypos, #ets_love.pid}, named_table, public, set ,?ETSRC, ?ETSWC]), %%仙侣情缘
	ets:new(?ETS_BASE_GOODS_FASHION,[{keypos, #ets_base_goods_fashion.goods_id}, named_table, public, set ,?ETSRC, ?ETSWC]),%%时装洗炼属性表
	ets:new(?ETS_BASE_PRIVITY,[{keypos, #ets_base_privity.id}, named_table, public, set ,?ETSRC, ?ETSWC]),%%默契度测试题库
	ets:new(?ETS_LUCKYDRAW,[{keypos, #ets_luckydraw.pid}, named_table, public, set ,?ETSRC, ?ETSWC]), %%登陆抽奖 
	ets:new(?ETS_TARGETLEAD,[{keypos, #ets_targetlead.pid}, named_table, public, set ,?ETSRC, ?ETSWC]), %%目标引导
	ets:new(?ETS_ACHIEVE, [{keypos, #ets_achieve.pid}, named_table, public, set ,?ETSRC, ?ETSWC]),%%成就系统计算
	ets:new(?ACHIEVE_STATISTICS, [{keypos, #ets_ach_stats.pid}, named_table, public, set ,?ETSRC, ?ETSWC]),%%成绩系统的玩家数据
	ets:new(?ACHIEVE_LOG, [{keypos, #ets_log_ach_f.id}, named_table, public, set ,?ETSRC, ?ETSWC]),%%成绩系统的玩家日志
	ets:new(?ETS_LOGIN_AWARD,[{keypos, #ets_login_award.pid}, named_table, public, set ,?ETSRC, ?ETSWC]), %%新登录奖励 
	ets:new(?ETS_DUNGEON,[{keypos, #ets_dungeon.player_id}, named_table, public, set ,?ETSRC, ?ETSWC]), %%副本信息  
	ets:new(?ETS_DAILY_ONLINE_AWARD, [{keypos, #ets_daily_online_award.pid}, named_table, public, set ,?ETSRC, ?ETSWC]), %%每日在线奖励玩家表
	ets:new(?ETS_BASE_DAILY_GIFT,[{keypos, #ets_base_daily_gift.id}, named_table, public,set,?ETSRC, ?ETSWC]), %%每日奖励物品表
	ets:new(?ETS_EXP_ACTIVITY, [{keypos, #ets_exp_activity.st}, named_table, public, set,?ETSRC, ?ETSWC]),		%% 双倍经验活动表
	ets:new(?ETS_TOWER_AWARD, [{keypos, #ets_tower_award.id}, named_table, public, set,?ETSRC, ?ETSWC]), %%经脉基础属性
	ets:new(?ETS_PLAYER_ACTIVITY, [{keypos, #player_activity.pid}, named_table, public, set ,?ETSRC, ?ETSWC]),
	ets:new(?ETS_CYCLE_FLUSH, [{keypos, #ets_cycle_flush.pid}, named_table, public, set ,?ETSRC, ?ETSWC]),%%循环任务奖励 
	ets:new(?ETS_WAR_PLAYER,[{keypos, #ets_war_player.id}, named_table, public, set ,?ETSRC, ?ETSWC]), %%跨服战场玩家表
	ets:new(?ETS_WAR_TEAM,[{keypos, #ets_war_team.id}, named_table, public, set ,?ETSRC, ?ETSWC]), %%跨服战场队伍表
	ets:new(?ETS_WAR_VS,[{keypos, #ets_war_vs.id}, named_table, public, set ,?ETSRC, ?ETSWC]),%%跨服战场对战表 
	ets:new(?ETS_VIP, [{keypos, #ets_vip.pid}, named_table, public, set ,?ETSRC, ?ETSWC]),%%vip信息 
	ets:new(?LOG_F5_GWISH, [{keypos, #ets_f5_gwish.id}, named_table, public, set ,?ETSRC, ?ETSWC]),	%%玩家帮忙刷新任务的日志记录
	ets:new(?ETS_NOVICE_GIFT, [{keypos, #ets_novice_gift.pid}, named_table, public, set ,?ETSRC, ?ETSWC]),%%新手礼包信息
	ets:new(?ETS_WAR_AWARD,[{keypos, #ets_war_award.pid}, named_table, public, set ,?ETSRC, ?ETSWC]), %%跨服战场玩家积分表

    ets:new(?ETS_MOUNT, [{keypos, #ets_mount.id}, named_table, public, set ,?ETSRC, ?ETSWC]),	%%坐骑
	ets:new(?ETS_MOUNT_SKILL_EXP, [{keypos, #ets_mount_skill_exp.player_id}, named_table, public, set ,?ETSRC, ?ETSWC]),%%坐骑技能经验槽
	ets:new(?ETS_MOUNT_SKILL_SPLIT,[{keypos, #ets_mount_skill_split.id}, named_table, public, set ,?ETSRC, ?ETSWC]), %%坐骑技能精魂

	ets:new(?ETS_MARRY, [named_table, public, set, {keypos, #ets_marry.id},?ETSRC, ?ETSWC] ),%%结婚信息表
 	ets:new(?ETS_PROPOSE_INFO, [named_table, public, set, {keypos, #ets_propose_info.boy_id},?ETSRC, ?ETSWC]),%%提亲表
	ets:new(?ETS_FIND_EXP,[{keypos, #ets_find_exp.id}, named_table, public, set,?ETSRC, ?ETSWC]), %%经验找回
	ets:new(?ETS_SINGLE_TD_AWARD,[{keypos, #ets_find_exp.pid}, named_table, public, set,?ETSRC, ?ETSWC]), %%单人镇妖竞技奖励
	ets:new(?ETS_WAR2_RECORD,[{keypos, #ets_war2_record.pid}, named_table, public, set,?ETSRC, ?ETSWC]), %%跨服单人竞技记录
	ets:new(?ETS_WAR2_ELIMINATION,[{keypos, #ets_war2_elimination.pid}, named_table, public, set,?ETSRC, ?ETSWC]), %%跨服单人竞技淘汰赛记录
	ets:new(?ETS_WAR2_HISTORY,[{keypos, #ets_war2_history.id}, named_table, public, set,?ETSRC, ?ETSWC]), %%跨服单人竞技历史记录
	ets:new(?ETS_WAR2_BET,[{keypos, #ets_war2_bet.pid}, named_table, public, set,?ETSRC, ?ETSWC]), %%跨服下注记录
	ets:new(?ETS_FS_ERA,[{keypos, #ets_fs_era.player_id}, named_table, public, set,?ETSRC, ?ETSWC]), %%封神纪元信息记录表 
	ets:new(?ETS_WAR2_PAPE,[{keypos, #ets_war2_pape.id}, named_table, public, set,?ETSRC, ?ETSWC]), %%跨服战报  
    ets:new(?ETS_FASHION_EQUIP,[{keypos, #ets_fashion_equip.pid}, named_table, public, set,?ETSRC, ?ETSWC]), %%衣橱信息记录表
	ets:new(?ETS_TARGET,[{keypos, #ets_target.pid}, named_table, public, set,?ETSRC, ?ETSWC]), %%新玩家目标 
    ok.
