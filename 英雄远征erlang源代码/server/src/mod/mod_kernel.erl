%%%------------------------------------
%%% @Module  : mod_kernel
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.06.30
%%% @Description: 核心服务
%%%------------------------------------
-module(mod_kernel).
-behaviour(gen_server).
-export([
            start_link/0,
            online_state/0
        ]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-include("common.hrl").
-include("record.hrl").

start_link() ->
    gen_server:start_link({local,?MODULE}, ?MODULE, [], []).

%% 在线状况
online_state() ->
    case ets:info(?ETS_ONLINE, size) of
        undefined ->
            [0,0];
        Num when Num < 200 -> %顺畅
            [1, Num];
        Num when Num > 200 , Num < 500 -> %正常
            [2, Num];
        Num when Num > 500 , Num < 800 -> %繁忙
            [3, Num];
        Num when Num > 800 -> %爆满
            [4, Num]
    end.

init([]) ->
    %%初始ets表
    ok = init_ets(),
    %%初始mysql
    ok = init_mysql(),
    %% 初始化物品类型及规则列表
    ok = goods_util:init_goods(),
    %经脉列表
    ok = mod_meridian:init_meridian(),
    {ok, 1}.

handle_cast(_R , Status) ->
    {noreply, Status}.

handle_call(_R , _FROM, Status) ->
    {reply, ok, Status}.

handle_info(_Reason, Status) ->
    {noreply, Status}.

terminate(normal, Status) ->
    {ok, Status}.

code_change(_OldVsn, Status, _Extra)->
    {ok, Status}.

%% ================== 私有函数 =================
%% mysql数据库连接初始化
init_mysql() ->
    mysql:start_link(?DB, ?DB_HOST, ?DB_PORT, ?DB_USER, ?DB_PASS, ?DB_NAME, fun(_, _, _, _) -> ok end, ?DB_ENCODE),
    mysql:connect(?DB, ?DB_HOST, ?DB_PORT, ?DB_USER, ?DB_PASS, ?DB_NAME, ?DB_ENCODE, true),
    ok.

%%初始ETS表
init_ets() ->
    ets:new(?ETS_ONLINE, [{keypos,#ets_online.id}, named_table, public, set]), %%用户在线列表
    ets:new(?ETS_MON, [{keypos,#ets_mon.id}, named_table, public, set]), %%用户怪物信息
    ets:new(?ETS_SCENE, [{keypos, #ets_scene.id}, named_table, public, set]), %%用户场景信息
    ets:new(?ETS_SCENE_POSES, [named_table, public, bag]),   %%场景坐标表
    ets:new(?ETS_NPC, [{keypos, #ets_npc.id}, named_table, public, set]), %%用户NPC信息
    ets:new(?ETS_GOODS_TYPE, [{keypos, #ets_goods_type.goods_id}, named_table, public, set]),
    ets:new(?ETS_GOODS_ADD_ATTRIBUTE, [{keypos, #ets_goods_add_attribute.id}, named_table, public, set]),
    ets:new(?ETS_GOODS_ATTRIBUTE_RULE, [{keypos, #ets_goods_attribute_rule.id}, named_table, public, set]),
    ets:new(?ETS_SUIT_ATTRIBUTE, [{keypos, #suit_attribute.id}, named_table, public, set]),
    ets:new(?ETS_GOODS_QUALITY_UPGRADE, [{keypos, #ets_goods_quality_upgrade.id}, named_table, public, set]),
    ets:new(?ETS_GOODS_QUALITY_BACKOUT, [{keypos, #ets_goods_quality_backout.id}, named_table, public, set]),
    ets:new(?ETS_GOODS_STRENGTHEN, [{keypos, #ets_goods_strengthen.id}, named_table, public, set]),
    ets:new(?ETS_GOODS_COMPOSE, [{keypos, #ets_goods_compose.id}, named_table, public, set]),
    ets:new(?ETS_GOODS_INLAY, [{keypos, #ets_goods_inlay.id}, named_table, public, set]),
    ets:new(?ETS_GOODS_DROP_NUM, [{keypos, #ets_goods_drop_num.id}, named_table, public, set]),
    ets:new(?ETS_GOODS_DROP_RULE, [{keypos, #ets_goods_drop_rule.id}, named_table, public, set]),
    ets:new(?ETS_SHOP, [{keypos, #ets_shop.id}, named_table, public, set]),
    ets:new(?ETS_GOODS_ONLINE, [{keypos, #goods.id}, named_table, public, set]),  %% 在线玩家的背包物品表
    ets:new(?ETS_GOODS_ATTRIBUTE, [{keypos, #goods_attribute.id}, named_table, public, set]),  %% 在线玩家的物品属性表
    ets:new(?ETS_GOODS_DROP, [{keypos, #ets_goods_drop.id}, named_table, public, set]), %% 物品掉落表
    ets:new(?ETS_ROLE_TASK, [{keypos, #role_task.id}, named_table, public, set]), %%用户任务记录
    ets:new(?ETS_ROLE_TASK_LOG, [named_table, public, bag]),
    ets:new(?ETS_TASK_QUERY_CACHE, [named_table, public, set]),
    ets:new(?ETS_RELA, [{keypos,#ets_rela.id}, named_table, public, set]), %%玩家关系记录
    ets:new(?ETS_RELA_INFO, [{keypos,#ets_rela_info.id}, named_table, public, set]), %%好友资料
    ets:new(?ETS_RELA_SET, [{keypos,#ets_rela_set.id}, named_table, public, set]), %%玩家好友分组记录
    ets:new(?ETS_PET, [{keypos,#ets_pet.id}, named_table, public, set]),                   %%宠物
    ets:new(?ETS_BASE_PET, [{keypos,#ets_base_pet.goods_id}, named_table, public, set]),   %%宠物道具配置
    ets:new(?ETS_GUILD, [{keypos,#ets_guild.id}, named_table, public, set]),               %%帮派
    ets:new(?ETS_GUILD_MEMBER, [{keypos,#ets_guild_member.id}, named_table, public, set]), %%帮派成员
    ets:new(?ETS_GUILD_APPLY, [{keypos,#ets_guild_apply.id}, named_table, public, set]),   %%帮派申请
    ets:new(?ETS_GUILD_INVITE, [{keypos,#ets_guild_invite.id}, named_table, public, set]), %%帮派邀请
    ok.
