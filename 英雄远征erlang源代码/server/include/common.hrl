%%%------------------------------------------------
%%% File    : common.hrl
%%% Author  : xyao
%%% Created : 2010-04-22
%%% Description: 公共定义
%%%------------------------------------------------
%-define(SD_SERVERS, 'SD_SERVERS').
-define(ALL_SERVER_PLAYERS, 10000).

%%服务IP和端口
%-define(HOST, "localhost").
%-define(PORT, 6666).
%-define(GAYEWAY_POST, 5555).

%%安全校验
-define(TICKET, "SDFSDESF123DFSDF").

%%flash843安全沙箱
-define(FL_POLICY_REQ, <<"<pol">>).
%-define(FL_POLICY_REQ, <<"<policy-file-request/>\0">>).
-define(FL_POLICY_FILE, <<"<cross-domain-policy><allow-access-from domain='*' to-ports='*' /></cross-domain-policy>">>).

%%tcp_server监听参数
-define(TCP_OPTIONS, [binary, {packet, 0}, {active, false}, {reuseaddr, true}, {nodelay, false}, {delay_send, true}, {send_timeout, 5000}, {keepalive, true}, {exit_on_close, true}]).

%%错误处理
-define(DEBUG(F, A), util:log("debug", F, A, ?MODULE, ?LINE)).
-define(INFO(F, A), util:log("info", F, A, ?MODULE, ?LINE)).
-define(ERR(F, A), util:log("error", F, A, ?MODULE, ?LINE)).

%%数据库连接
-define(DB, sd_mysql_conn).
-define(DB_HOST, "localhost").
-define(DB_PORT, 3306).
-define(DB_USER, "sdzmmo").
-define(DB_PASS, "sdzmmo123456").
-define(DB_NAME, "sdzmmo").
-define(DB_ENCODE, utf8).

-define(DIFF_SECONDS_1970_1900, 2208988800).
-define(DIFF_SECONDS_0000_1900, 62167219200).
-define(ONE_DAY_SECONDS,        86400).

%%ETS
-define(ETS_SERVER, ets_server).
-define(ETS_ONLINE, ets_online).
-define(ETS_MON, ets_mon).
-define(ETS_NPC, ets_npc).
-define(ETS_SCENE, ets_scene).
-define(ETS_SCENE_POSES, ets_scene_poses).	%% 存放场景中可以移动的坐标，用于NPC寻路
-define(ETS_GOODS_TYPE, ets_goods_type).                        %% 物品类型表
-define(ETS_GOODS_ADD_ATTRIBUTE, ets_goods_add_attribute).      %% 装备类型附加属性表
-define(ETS_GOODS_ATTRIBUTE_RULE, ets_goods_attribute_rule).    %% 装备附加属性规则表
-define(ETS_SUIT_ATTRIBUTE, ets_suit_attribute).                %% 装备套装属性表
-define(ETS_GOODS_QUALITY_UPGRADE, ets_goods_quality_upgrade).  %% 装备品质升级规则表
-define(ETS_GOODS_QUALITY_BACKOUT, ets_goods_quality_backout).  %% 装备品质拆除规则表
-define(ETS_GOODS_STRENGTHEN, ets_goods_strengthen).            %% 装备强化规则表
-define(ETS_GOODS_COMPOSE, ets_goods_compose).                  %% 宝石合成规则表
-define(ETS_GOODS_INLAY, ets_goods_inlay).                      %% 宝石镶嵌规则表
-define(ETS_GOODS_DROP_NUM, ets_goods_drop_num).                %% 物品掉落个数规则表
-define(ETS_GOODS_DROP_RULE, ets_goods_drop_rule).              %% 物品掉落规则表
-define(ETS_SHOP, ets_shop).                                    %% 商店表
-define(ETS_GOODS_ONLINE, ets_goods_online).                    %% 在线玩家的背包物品表
-define(ETS_GOODS_ATTRIBUTE, ets_goods_attribute).              %% 在线玩家的物品属性表
-define(ETS_GOODS_DROP, ets_goods_drop).                        %% 物品掉落表
-define(ETS_ROLE_TASK, ets_role_task). %% 已接任务
-define(ETS_ROLE_TASK_LOG, ets_role_task_log).
-define(ETS_TASK_QUERY_CACHE, ets_task_query_cache).            %% 当前所有可接任务
-define(ETS_LV_EXP, ets_lv_exp).
-define(ETS_RELA, ets_rela).                                    %% 玩家关系表
-define(ETS_RELA_INFO, ets_rela_info).                          %% 好友资料
-define(ETS_RELA_SET, ets_rela_set).                            %% 玩家好友分组名字表
-define(ETS_RANK, ets_rank).                                    %% 排行榜
-define(ETS_PET,          ets_pet).                             %% 宠物
-define(ETS_BASE_PET,     ets_base_pet).                        %% 宠物道具配置
-define(ETS_GUILD,        ets_guild).                           %% 帮派
-define(ETS_GUILD_MEMBER, ets_guild_member).                    %% 帮派成员
-define(ETS_GUILD_APPLY,  ets_guild_apply).                     %% 帮派申请
-define(ETS_GUILD_INVITE, ets_guild_invite).                    %% 帮派邀请


%%打开发送消息客户端进程数量
-define(SEND_MSG, 3).
