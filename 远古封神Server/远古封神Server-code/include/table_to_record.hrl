%%%------------------------------------------------	
%%% File    : table_to_record.erl	
%%% Author  : ygzj	
%%% Created : 2012-04-25 16:24:41	
%%% Description: 从mysql表生成的record	
%%% Warning:  由程序自动生成，请不要随意修改！	
%%%------------------------------------------------		
 	
	
%% 服务器列表	
%% server ==> server 	
-record(server, {	
      id = 0,                                 %% 编号Id	
      ip = "",                                %% ip地址	
      port = 0,                               %% 端口号	
      node = "",                              %% 节点	
      num = 0,                                %% 节点用户数	
      stop_access = 0                         %% 是否停止登陆该节点，0为可以登录，1为停止登陆	
    }).	
	
%% 角色基本信息	
%% player ==> player 	
-record(player, {	
      id,                                     %% 用户ID	
      accid = 0,                              %% 平台账号ID	
      accname = "",                           %% 平台账号	
      nickname = "",                          %% 玩家名	
      status = 0,                             %% 玩家状态（0正常、1禁止、2战斗中、3死亡、4蓝名、5挂机、6打坐、7凝神修炼8采矿,9答题）,	
      reg_time = 0,                           %% 注册时间	
      last_login_time = 0,                    %% 最后登陆时间	
      last_login_ip = "",                     %% 最后登陆IP	
      sex = 1,                                %% 性别 1男 2女	
      career = 0,                             %% 职业 1，2，3，4，5（分别是玄武--战士、白虎--刺客、青龙--弓手、朱雀--牧师、麒麟--武尊）	
      realm = 0,                              %% 落部  1女娲族、2神农族、3伏羲族、100新手	
      prestige = 0,                           %% 声望	
      spirit = 0,                             %% 灵力	
      jobs = 0,                               %% 职位	
      gold = 0,                               %% 元宝	
      cash = 0,                               %% 礼金	
      coin = 0,                               %% 铜钱	
      bcoin = 0,                              %% 绑定的铜钱	
      coin_sum = 0,                           %% 币铜总和	
      scene = 0,                              %% 场景ID	
      x = 0,                                  %% X坐标	
      y = 0,                                  %% Y坐标	
      lv = 1,                                 %% 等级	
      exp = 0,                                %% 经验	
      hp = 0,                                 %% 气血	
      mp = 0,                                 %% 内息	
      hp_lim = 0,                             %% 气血上限	
      mp_lim = 0,                             %% 内息上限	
      forza = 0.00,                           %% 力量	
      agile = 0.00,                           %% 敏捷	
      wit = 0.00,                             %% 智力	
      max_attack = 0,                         %% 最大攻击力	
      min_attack = 0,                         %% 最小攻击力	
      def = 0,                                %% 防御	
      hit = 0,                                %% 命中率	
      dodge = 0,                              %% 躲避	
      crit = 0,                               %% 暴击	
      att_area = 0,                           %% 攻击距离	
      pk_mode = 1,                            %% pk模式(1.和平模式;2.部落模式;3.帮派模式;4.组队模式;5.自由模式)	
      pk_time = 0,                            %% 上一次切换PK和平模式的时间	
      title = "",                             %% 称号	
      couple_name = "",                       %% 配偶	
      position = "",                          %% 官职	
      evil = 0,                               %% 罪恶	
      honor = 0,                              %% 荣誉	
      culture = 0,                            %% 修为	
      state = 1,                              %% 玩家身份 1普通玩家 2指导员3gm	
      physique = 0,                           %% 体质	
      anti_wind = 0,                          %% 风抗	
      anti_fire = 0,                          %% 火抗	
      anti_water = 0,                         %% 水抗	
      anti_thunder = 0,                       %% 雷抗	
      anti_soil = 0,                          %% 土抗	
      anti_rift = 0,                          %% 抗性穿透	
      cell_num = 100,                         %% 背包格子数	
      mount = 0,                              %% 坐骑ID	
      guild_id = 0,                           %% 帮派ID	
      guild_name = "",                        %% 帮派名称	
      guild_position = 0,                     %% 帮派职位	
      quit_guild_time = 0,                    %% 最近一次退出帮派时间	
      guild_title = "",                       %% 帮派称号	
      guild_depart_name = "",                 %% 所属堂名	
      guild_depart_id = 0,                    %% 所属堂ID默认值为0，一般弟子时为5,	
      speed = 0,                              %% 移动速度	
      att_speed = 100,                        %% 攻击速度	
      equip = 1,                              %% 当前装备: 1 装备一  2 装备二 3 装备三	
      vip = 0,                                %% VIP(0没有，1月卡，2季卡，3半年卡)	
      vip_time = 0,                           %% vip时间	
      online_flag = 0,                        %% 在线标记，0不在线 1在线	
      pet_upgrade_que_num = 0,                %% 宠物升级队列个数	
      daily_task_limit = 0,                   %% 日常任务可接上限	
      carry_mark = 0,                         %% 是否运镖标记	
      task_convoy_npc = 0,                    %% 护送NPC	
      other,                                  %% 其他附加数据集	
      store_num = 36,                         %% 仓库格子数	
      online_gift = 0,                        %% 在线礼物领取标记	
      target_gift = 0,                        %% 目标奖励标记	
      arena = 0,                              %% 竞技场状态，0没报名、1竞技中、2已报名竞技场、3竞技场死亡状态	
      arena_score = 0,                        %% 竞技场积分	
      sn = 0,                                 %% 服务器标识	
      realm_honor = 0                         %% 部落荣誉	
    }).	
	
%% 玩家物品记录	
%% goods ==> goods 	
-record(goods, {	
      id,                                     %% 物品Id	
      player_id = 0,                          %% 角色Id	
      goods_id = 0,                           %% 物品类型Id，对应ets_goods_type.goods_id	
      type = 0,                               %% 物品类型	
      subtype = 0,                            %% 物品子类型	
      equip_type = 0,                         %% 装备类型：0为个人的物品，不为0时，记录的是氏族id表示物品在该氏族仓库,	
      price_type = 0,                         %% 价格类型：1 铜钱 2 银两，3 金币，4 绑定的铜钱,	
      price = 0,                              %% 购买价格	
      sell_price = 0,                         %% 出售价格	
      bind = 0,                               %% 绑定状态，0没绑定，1使用后绑定，2已绑定	
      career = 0,                             %% 职业0无限制 12345	
      trade = 0,                              %% 交易状态，0为可交易，1为不可交易	
      sell = 0,                               %% 出售状态，0为可出售，1为不可出售	
      isdrop = 0,                             %% 丢弃状态，0为可丢弃，1为不可丢弃	
      level = 0,                              %% 物品等级	
      spirit = 0,                             %% 灵力	
      hp = 0,                                 %% 血量	
      mp = 0,                                 %% 内力	
      forza = 0,                              %% 力量	
      physique = 0,                           %% 体质	
      agile = 0,                              %% 敏捷	
      wit = 0,                                %% 智力	
      max_attack = 0,                         %% 最大攻击力	
      min_attack = 0,                         %% 最小攻击力	
      def = 0,                                %% 防御	
      hit = 0,                                %% 命中	
      dodge = 0,                              %% 躲避	
      crit = 0,                               %% 暴击	
      ten = 0,                                %% 坚韧	
      anti_wind = 0,                          %% 抗风	
      anti_fire = 0,                          %% 火抗	
      anti_water = 0,                         %% 水抗	
      anti_thunder = 0,                       %% 雷抗	
      anti_soil = 0,                          %% 土抗	
      anti_rift = 0,                          %% 抗性穿透	
      speed = 0,                              %% 速度	
      attrition = 0,                          %% 耐久度上限，当前耐久度由lib_goods:get_goods_attrition(UseNum)算得	
      use_num = 0,                            %% 可使用次数，由lib_goods:get_goods_use_num(Attrition)算得	
      suit_id = 0,                            %% 套装ID，0为无	
      stren = 0,                              %% 强化等级	
      stren_fail = 0,                         %% 历史最高强化失败次数	
      hole = 0,                               %% 镶孔数	
      hole1_goods = 0,                        %% 孔1所镶物品ID	
      hole2_goods = 0,                        %% 孔2所镶物品ID	
      hole3_goods = 0,                        %% 孔3所镶物品ID	
      location = 0,                           %% 物品所在位置，1 装备一，2成就背包，3 暂没用 4 背包，5 仓库，6任务物品，7诛邪仓库 ，8氏族仓库，9临时矿包,10农场背包,11衣橱12.灵兽战斗技能书包,	
      cell = 0,                               %% 物品所在格子位置	
      num = 0,                                %% 物品数量	
      grade,                                  %% 修炼等级	
      step = 0,                               %% 品阶物	
      color = 0,                              %% 物品颜色，0 白色，1 绿色，2 蓝色，3 金色，4 紫色	
      other_data,                             %% 用于保存额外的数据，比如灵兽粮食的快乐值，礼包中的一些赠送物品ID，金币数据	
      expire_time = 0,                        %% 有效期，0为无	
      score = 0,                              %% 	
      bless_level = 0,                        %% 福祝等级	
      bless_skill = 0,                        %% 福祝技能	
      icon = 0,                               %% 使用外形	
      ct = 0,                                 %% 生成时间	
      used = 0                                %% 使用过次数	
    }).	
	
%% 玩家物品属性表	
%% goods_attribute ==> goods_attribute 	
-record(goods_attribute, {	
      id,                                     %% 编号	
      player_id = 0,                          %% 角色Id	
      gid = 0,                                %% 物品Id	
      goods_id = 0,                           %% 物品类型id	
      attribute_type = 0,                     %% 属性类型，1 附加，2 强化，3镶嵌，6时装洗炼 7附魔,	
      attribute_id = 0,                       %% 属性类型Id	
      value_type = 0,                         %% 属性值类型，0为数值，1为百分比	
      hp = 0,                                 %% 气血	
      mp = 0,                                 %% 内力	
      max_attack = 0,                         %% 最大攻击力	
      min_attack = 0,                         %% 最小攻击力	
      forza = 0,                              %% 力量	
      agile = 0,                              %% 敏捷	
      wit = 0,                                %% 智力	
      physique = 0,                           %% 	
      att = 0,                                %% 攻击	
      def = 0,                                %% 防御	
      hit = 0,                                %% 命中	
      dodge = 0,                              %% 躲避	
      crit = 0,                               %% 暴击	
      ten = 0,                                %% 坚韧	
      anti_wind = 0,                          %% 	
      anti_fire = 0,                          %% 	
      anti_water = 0,                         %% 	
      anti_thunder = 0,                       %% 	
      anti_soil = 0,                          %% 土抗	
      anti_rift = 0,                          %% 抗性穿透	
      status = 1                              %% 是否生效，1为生效，0为不生效	
    }).	
	
%% 物品buff效果表	
%% goods_buff ==> goods_buff 	
-record(goods_buff, {	
      id,                                     %% 自增id	
      player_id = 0,                          %% 角色ID	
      goods_id = 0,                           %% 物品类型ID	
      expire_time = 0,                        %% 过期时间	
      data = ""                               %% 效果数据	
    }).	
	
%% goods_cd	
%% goods_cd ==> ets_goods_cd 	
-record(ets_goods_cd, {	
      id,                                     %% 自增id	
      player_id = 0,                          %% 角色ID	
      goods_id = 0,                           %% 物品ID	
      expire_time = 0                         %% 过期时间	
    }).	
	
%% 副法宝	
%% deputy_equip ==> ets_deputy_equip 	
-record(ets_deputy_equip, {	
      id,                                     %% 自增id	
      pid = 0,                                %% 玩家ID	
      step = 0,                               %% 阶	
      color = 0,                              %% 品质:0白色1绿色 2蓝色 3 金色 4 紫色	
      prof = 0,                               %% 练度熟	
      prof_lv = 0,                            %% 熟练度等级	
      lucky_color = 0,                        %% 品级幸运值	
      lucky_step = 0,                         %% 品阶幸运值	
      lucky_prof = 0,                         %% 熟练度幸运值	
      skills,                                 %% 技能	
      att,                                    %% 熟悉值	
      tmp_att,                                %% 临时属性值	
      batt_val = 0,                           %% 战斗力值	
      reset = 0                               %% 幸运值重置时间戳	
    }).	
	
%% 答题	
%% base_answer ==> ets_base_answer 	
-record(ets_base_answer, {	
      id,                                     %% 主键	
      reply = "",                             %% 答案	
      quest = "",                             %% 问题 	
      opt1 = "",                              %% 项选1	
      opt2 = "",                              %% 项选2	
      opt3 = "",                              %% 项选3	
      opt4 = "",                              %% 项选4	
      order = 0                               %% 序号	
    }).	
	
%% 职业类型表	
%% base_career ==> ets_base_career 	
-record(ets_base_career, {	
      career_id = 0,                          %% 职业编号	
      career_name = "",                       %% 职业名称	
      forza = 0,                              %% 力量	
      physique = 0,                           %% 体质	
      agile = 0,                              %% 敏捷	
      wit = 0,                                %% 智力	
      hp_init = 0,                            %% 初始气血	
      hp_physique = 0.00,                     %% 气血/体质	
      hp_lv = 0.00,                           %% 气血/lv	
      mp_init = 0,                            %% 初始法力	
      mp_wit = 0.00,                          %% 法力/智力	
      mp_lv = 0.00,                           %% 法力/lv	
      att_init_min = 0,                       %% 最小攻击	
      att_init_max = 0,                       %% 最大攻击	
      att_forza = 0.00,                       %% 攻击力/力量	
      att_agile = 0.00,                       %% 攻击力/敏捷	
      att_wit = 0.00,                         %% 攻击力/智力	
      hit_init = 0,                           %% 初始命中	
      hit_forza = 0.00,                       %% 命中/力量	
      hit_agile = 0.00,                       %% 命中/敏捷	
      hit_wit = 0.00,                         %% 命中/智力	
      hit_lv = 0.00,                          %% 命中/lv	
      dodge_init = 0,                         %% 初始闪躲	
      dodge_agile = 0.00,                     %% 闪躲/敏捷	
      dodge_lv = 0.00,                        %% 闪躲/lv	
      crit_init = 0,                          %% 初始闪躲	
      crit_lv = 0.00,                         %% 暴击/lv	
      att_speed = 0,                          %% 攻击速度	
      init_scene = 0,                         %% 初始场景	
      init_x = 0,                             %% 初始X	
      init_y = 0,                             %% 初始Y	
      init_att_area = 0,                      %% 初始攻击距离	
      init_speed = 0,                         %% 初始移动速度	
      init_spirit = 0,                        %% 初始灵力	
      init_gold = 0,                          %% 初始元宝	
      init_cash = 0,                          %% 初始礼金	
      init_coin = 0,                          %% 初始铜	
      init_goods                              %% 初始赠送物品	
    }).	
	
%% 境界表	
%% base_culture_state ==> ets_base_culture_state 	
-record(ets_base_culture_state, {	
      id = 1,                                 %% 境界级别	
      min_state = 0,                          %% 最低修为值	
      state_name = ""                         %% 境界	
    }).	
	
%% 场景数据结构	
%% base_scene ==> ets_scene 	
-record(ets_scene, {	
      sid,                                    %% 场景id	
      type = 0,                               %% 0:城镇 1:野外场景, 2:副本, 5:氏族领地, 6:竞技场, 7:封神台,8:秘境,9:神岛,	
      name = "",                              %% 场景名称	
      x = 0,                                  %% 默认x坐标	
      y = 0,                                  %% 默认y坐标	
      requirement,                            %% 进入需求	
      elem,                                   %% 场景元素	
      npc,                                    %% 场景NPC数据结构,	
      mon,                                    %% 场景怪物数据结构,	
      mask,                                   %% 场景移动坐标信息	
      safe = "",                              %% 安全区	
      id = 0                                  %% 场景唯一ID	
    }).	
	
%% 怪物表	
%% base_mon ==> ets_mon 	
-record(ets_mon, {	
      mid,                                    %% 怪物编号	
      name = "",                              %% 名字	
      scene = 0,                              %% 所属场景	
      icon = 0,                               %% 资源	
      def = 0,                                %% 防御值	
      lv = 0,                                 %% 等级	
      hp = 0,                                 %% 血	
      hp_lim = 0,                             %% 血上限	
      mp = 0,                                 %% 蓝	
      mp_lim = 0,                             %% 蓝上限	
      max_attack = 0,                         %% 最大攻击力	
      min_attack = 0,                         %% 最小攻击力	
      att_area = 0,                           %% 攻击范围	
      trace_area = 0,                         %% 追踪范围	
      guard_area = 0,                         %% 警戒范围	
      spirit = 0,                             %% 灵力	
      hook_spirit = 0,                        %% 挂机灵力	
      exp = 0,                                %% 怪物经验	
      hook_exp = 0,                           %% 挂机经验	
      init_hit = 800,                         %% 初始命中	
      hit = 0,                                %% 当前命中	
      init_dodge = 50,                        %% 初始闪躲	
      dodge = 0,                              %% 当前闪躲	
      init_crit = 50,                         %% 初始暴击	
      crit = 0,                               %% 当前暴击	
      anti_wind = 0,                          %% 风抗性	
      anti_fire = 0,                          %% 火抗性	
      anti_water = 0,                         %% 水抗性	
      anti_thunder = 0,                       %% 雷抗性	
      anti_soil = 0,                          %% 土抗	
      speed = 0,                              %% 移动速度	
      skill = [],                             %% 技能	
      retime = 0,                             %% 重生时间	
      att_speed = 0,                          %% 攻击速度	
      x = <<"0">>,                            %% 当前位置x	
      y = <<"0">>,                            %% 当前位置y	
      att_type = 0,                           %% 怪物类型（0被动，1主动）	
      id = 0,                                 %% 实例怪物唯一ID	
      pid,                                    %% 怪物活动进程Pid	
      battle_status,                          %% 战斗状态	
      relation = [],                          %% 关系	
      type = 1,                               %% 1普通怪、2精英怪、3野外BOSS、4副本怪、5副本BOSS、6采集怪、7捕捉怪、9诛邪怪10塔怪(物攻)、11~15塔怪(属攻)，20塔怪boss(物攻)、21~25塔怪boss(属攻),30,31神岛怪,34跨服战场boss，35跨服战场小怪,98TD小怪,99TD(boss),100TD守卫,101TD镇妖剑,	
      unique_key = 0,                         %% unique_key用于ets的记录的唯一标记	
      status                                  %% 怪物状态	
    }).	
	
%% NPC表 	
%% base_npc ==> ets_npc 	
-record(ets_npc, {	
      nid = 0,                                %% NPC编号	
      name = "",                              %% 字名	
      scene = 0,                              %% 场景	
      icon = 0,                               %% 图标资源	
      npctype = 0,                            %% 0:没有类型1:帮2:技3:仓4:杂5:商6:铁7:宝8:兽9:传10:镖11:药12:修13:委14:战15:鉴16:移17:荣18:师20:荣21:台	
      x = 0,                                  %% 位置X	
      y = 0,                                  %% 位置X	
      talk = 0,                               %% 对话	
      id = 0,                                 %% 唯一ID	
      unique_key = 0                          %% unique_key用于ets的记录的唯一标记	
    }).	
	
%% 物品基础表	
%% base_goods ==> ets_base_goods 	
-record(ets_base_goods, {	
      goods_id = 0,                           %% 物品类型编号	
      goods_name = "",                        %% 物品名称	
      icon = "",                              %% 物品图标	
      intro,                                  %% 物品描述信息	
      type = 0,                               %% 物品类型：10装备类，15宝石类，20护符类，25丹药类，30增益类，35灵兽类，40帮派类，45任务类，50其他类；参照base_goods_type表	
      subtype = 0,                            %% 物品子类型。装备子类型：1 武器，2 衣服，3 头盗，4 手套，5 鞋子，6 项链，7 戒指。增益子类型：1 药品，2 经验。 坐骑子类型：1 一人坐骑 2 二人坐骑 3 三人坐骑；参照base_goods_subtype表	
      equip_type = 0,                         %% 装备类型：0为个人的物品，不为0时，记录的是氏族id表示物品在该氏族仓库,	
      bind = 0,                               %% 是否绑定，0没绑定，1使用后绑定，2已绑定	
      price_type = 0,                         %% 价格类型：1 铜钱 2 银两，3 金币，4 绑定的铜钱,	
      price = 0,                              %% 物品购买价格	
      trade = 0,                              %% 是否交易，1为不可交易，0为可交易	
      sell_price = 0,                         %% 物品出售价格	
      sell = 0,                               %% 是否出售，0可出售，1不可出售	
      isdrop = 0,                             %% 是否丢弃，0可丢弃，1不可丢弃	
      level = 0,                              %% 等级限制，0为不限	
      career = 0,                             %% 职业限制，0为不限	
      sex = 0,                                %% 性别限制，0为不限，1为男，2为女	
      job = 0,                                %% 职位限制，0为不限	
      forza_limit = 0,                        %% 力量需求，0为不限	
      physique_limit = 0,                     %% 体质需求，0为不限	
      wit_limit = 0,                          %% 智力需求，0为不限	
      agile_limit = 0,                        %% 敏捷需求，0为不限	
      realm = 0,                              %% 部落限制，0为不限	
      spirit = 0,                             %% 灵力	
      hp = 0,                                 %% 气血	
      mp = 0,                                 %% 内力	
      forza = 0,                              %% 力量	
      physique = 0,                           %% 体质	
      wit = 0,                                %% 智力	
      agile = 0,                              %% 敏捷	
      max_attack = 0,                         %% 最大攻击力	
      min_attack = 0,                         %% 最小攻击力	
      def = 0,                                %% 防御	
      hit = 0,                                %% 命中	
      dodge = 0,                              %% 躲避	
      crit = 0,                               %% 暴击	
      ten = 0,                                %% 坚韧	
      anti_wind = 0,                          %% 风抗	
      anti_fire = 0,                          %% 火抗	
      anti_water = 0,                         %% 水抗	
      anti_thunder = 0,                       %% 雷抗	
      anti_soil = 0,                          %% 土抗	
      anti_rift = 0,                          %% 抗性穿透	
      speed = 0,                              %% 速度	
      attrition = 0,                          %% 耐久度，0为永不磨损	
      suit_id = 0,                            %% 套装ID，0为不是套装	
      max_hole = 0,                           %% 可镶嵌孔数，0为不可打孔	
      max_stren = 0,                          %% 最大强化等级，0为不可强化	
      max_overlap = 0,                        %% 可叠加数，0为不可叠加	
      grade = 0,                              %% 修炼等级	
      step = 0,                               %% 物品阶	
      color = 0,                              %% 物品颜色，0 白色，1 绿色，2 蓝色，3 金色，4 紫色	
      other_data,                             %% 用于保存额外的数据，比如灵兽粮食的快乐值，礼包中的一些赠送物品ID，金币数据\r\n	
      expire_time = 0                         %% 有效期，0为不限，单位为秒	
    }).	
	
%% 装备类型附加属性表	
%% base_goods_add_attribute ==> ets_base_goods_add_attribute 	
-record(ets_base_goods_add_attribute, {	
      id,                                     %% 编号	
      goods_id = 0,                           %% 物品类型ID	
      color = 0,                              %% 装备颜色	
      attribute_type = 0,                     %% 属性类型，1单属性，2双属性-13双属性-2，4双属性-3,5饰品属性-单，6饰品属性-全,	
      attribute_id = 0,                       %% 属性类型Id	
      value_type = 0,                         %% 属性值类型	
      value = 0,                              %% 数值	
      identify = 0                            %% 	
    }).	
	
%% 装备套装属性表	
%% base_goods_suit_attribute ==> ets_base_goods_suit_attribute 	
-record(ets_base_goods_suit_attribute, {	
      id,                                     %% 编号	
      career_id = 0,                          %% 职业限制，0为不限	
      suit_id = 0,                            %% 套装编号ID	
      suit_num = 0,                           %% 套装件数	
      level = 0,                              %% 等级需求	
      hp_lim = 0,                             %% 气血上限	
      mp_lim = 0,                             %% 法力上限	
      max_attack = 0,                         %% 最大攻击力	
      min_attack = 0,                         %% 最小攻击力	
      forza = 0,                              %% 力量	
      agile = 0,                              %% 敏捷	
      wit = 0,                                %% 智力	
      physique = 0,                           %% 体质	
      hit = 0,                                %% 命中	
      dodge = 0,                              %% 躲避	
      crit = 0,                               %% 暴击	
      anti_wind = 0,                          %% 风抗	
      def = 0,                                %% 防御	
      anti_fire = 0,                          %% 火抗	
      anti_water = 0,                         %% 水抗	
      anti_thunder = 0,                       %% 雷抗	
      anti_soil = 0                           %% 土抗	
    }).	
	
%% 装备套装表	
%% base_goods_suit ==> ets_base_goods_suit 	
-record(ets_base_goods_suit, {	
      suit_id = 0,                            %% 套装编号ID	
      suit_name = "",                         %% 套装名称	
      suit_intro = "",                        %% 套装描述信息	
      suit_totals = 0,                        %% 套装总件数	
      suit_goods = "",                        %% 包含物品	
      suit_effect = ""                        %% 属性个数对应效果	
    }).	
	
%% 装备强化规则表	
%% base_goods_strengthen ==> ets_base_goods_strengthen 	
-record(ets_base_goods_strengthen, {	
      id,                                     %% 编号	
      goods_id = 0,                           %% 强化石物品类型Id，对应ets_base_goods.goods_id	
      strengthen = 0,                         %% 装备强化等级	
      ratio = 0,                              %% 成功率	
      coin = 0,                               %% 消耗铜钱数	
      value = 0,                              %% 百分值	
      fail = 0,                               %% 失败时降到级别	
      type = 0                                %% 强化类型	
    }).	
	
%% 防具强化抗性数值表	
%% base_goods_strengthen_anti ==> ets_base_goods_strengthen_anti 	
-record(ets_base_goods_strengthen_anti, {	
      id,                                     %% 自增id	
      subtype = 0,                            %% 装备子类型	
      step = 0,                               %% 阶	
      stren = 0,                              %% 强化等级	
      value = 0                               %% 抗性值	
    }).	
	
%% 装备强化额外信息表（附加属性值）	
%% base_goods_strengthen_extra ==> ets_base_goods_strengthen_extra 	
-record(ets_base_goods_strengthen_extra, {	
      level,                                  %% 装备等级	
      crit7 = 0,                              %% 暴击	
      crit8 = 0,                              %% 8级暴击值	
      crit9 = 0,                              %% 9级暴击值	
      crit10 = 0,                             %% 10级暴击值	
      hp7 = 0,                                %% 气血	
      hp8 = 0,                                %% 8级气血加成	
      hp9 = 0,                                %% 9级气血加成	
      hp10 = 0                                %% 10级气血加成	
    }).	
	
%% 装备修炼规则表	
%% base_goods_practise ==> ets_base_goods_practise 	
-record(ets_base_goods_practise, {	
      id,                                     %% 编号	
      att_num = 0,                            %% 属性类型1单属性2双属性	
      subtype = 0,                            %% 法宝subtype	
      step = 1,                               %% 阶	
      color = 0,                              %% 1绿2蓝3金紫	
      grade = 0,                              %% 修炼等级	
      max_attack = 0,                         %% 最大值	
      min_attack = 0,                         %% 最小值	
      hit = 0,                                %% 命中	
      wit = 0,                                %% 智力	
      agile = 0,                              %% 敏捷	
      forza = 0,                              %% 力量	
      physique = 0,                           %% 体质	
      spirit = 0                              %% 需要灵力	
    }).	
	
%% 宝石合成规则表	
%% base_goods_compose ==> ets_base_goods_compose 	
-record(ets_base_goods_compose, {	
      id,                                     %% 编号	
      goods_id = 0,                           %% 宝石物品类型Id，对应ets_base_goods.goods_id	
      new_id = 0,                             %% 合成新的宝石	
      fail_id = 0,                            %% 失败返回物品id	
      coin = 0                                %% 消耗铜钱数	
    }).	
	
%% 宝石镶嵌规则表	
%% base_goods_inlay ==> ets_base_goods_inlay 	
-record(ets_base_goods_inlay, {	
      id,                                     %% 编号	
      goods_id = 0,                           %% 宝石物品类型Id，对应ets_base_goods.goods_id	
      equip_types = "",                       %% 可以镶嵌的装备类型	
      low_level = 0,                          %% 最低镶嵌等级	
      fail_goods_id = 0                       %% 失败返回物品类型id	
    }).	
	
%% base_goods_idecompose	
%% base_goods_idecompose ==> ets_base_goods_idecompose 	
-record(ets_base_goods_idecompose, {	
      id,                                     %% 自增id	
      type = 0,                               %% 物品类型	
      subtype = 0,                            %% 物品子类型	
      goods_id = 0,                           %% 物品类型id	
      color = 0,                              %% 装备颜色	
      lv_up = 0,                              %% 物品等级上限	
      lv_down = 0,                            %% 物品等级下限	
      price = 0,                              %% 分解费用	
      ratio = 0,                              %% 成功率	
      target = ""                             %% 分解生成目标[{goods_idnum},{}],	
    }).	
	
%% base_goods_icompose	
%% base_goods_icompose ==> ets_base_goods_icompose 	
-record(ets_base_goods_icompose, {	
      id,                                     %% 自增ID	
      type = <<"0">>,                         %% 品物类型	
      subtype = <<"0">>,                      %% 物品子类型	
      goods_id = 0,                           %% 物品类型ID	
      price = 0,                              %% 需求金钱	
      ratio = 0,                              %% 几率	
      require = ""                            %% 需要物品	
    }).	
	
%% 物品掉落数量规则表	
%% base_goods_drop_num ==> ets_base_goods_drop_num 	
-record(ets_base_goods_drop_num, {	
      id,                                     %% 编号	
      mon_id = 0,                             %% 怪物编号	
      drop_num = 0,                           %% 掉落个数	
      ratio = 0                               %% 机率	
    }).	
	
%% 物品掉落规则表	
%% base_goods_drop_rule ==> ets_base_goods_drop_rule 	
-record(ets_base_goods_drop_rule, {	
      id,                                     %% 编号	
      mon_id = 0,                             %% 怪物编号	
      goods_id = 0,                           %% 物品类型编号	
      type = 0,                               %% 物品类型	
      goods_num = 0,                          %% 掉落数量	
      ratio = 0,                              %% 掉落机率	
      extra = 0                               %% 特殊掉落，1特殊	
    }).	
	
%% base_goods_ore	
%% base_goods_ore ==> ets_base_goods_ore 	
-record(ets_base_goods_ore, {	
      goods_id = 0,                           %% 物品类型ID	
      n1 = 0,                                 %% 物品产出数量	
      n2 = 0,                                 %% 物品产出数量2	
      w = 0                                   %% 权重	
    }).	
	
%% 商店表	
%% shop ==> ets_shop 	
-record(ets_shop, {	
      id,                                     %% 编号	
      shop_type = 0,                          %% 商店类型，1为商城，n npcID	
      shop_subtype = 0,                       %% 商店子类型，1热卖商品，2坐骑宠物，3辅助材料，4丹药宝石，5礼券商店6特惠商品,	
      goods_id = 0,                           %% 物品类型ID	
      total = 0                               %% 出售的总个数	
    }).	
	
%% 对话	
%% base_talk ==> talk 	
-record(talk, {	
      id,                                     %% 编号	
      content                                 %% 对话内容	
    }).	
	
%% 任务数据	
%% base_task ==> task 	
-record(task, {	
      id,                                     %% 任务id	
      name = "",                              %% 任务名	
      desc,                                   %% 描述	
      class = 0,                              %% 任务分类，0普通任务，1运镖任务，2帮会任务	
      type = 0,                               %% 任务类型(主线，支线，日常)	
      child = 0,                              %% 子类	
      kind = 0,                               %% 任务种类	
      level = 1,                              %% 最低等级限制	
      level_limit = 0,                        %% 最高等级限制	
      repeat = 0,                             %% 是否允许重复做	
      realm = 0,                              %% 部落	
      career = 0,                             %% 职业限制	
      prev = 0,                               %% 上一个必须完成的任务id	
      next = 0,                               %% 下个关联任务id，即这个任务完成后触发任务	
      start_item,                             %% 开始获得物品{ItemId Number},	
      end_item,                               %% 完成回收物品	
      start_npc,                              %% 开始npcid	
      end_npc = 0,                            %% 结束npcid	
      start_talk = 0,                         %% 开始npc对话	
      end_talk = 0,                           %% 结束npc对话	
      unfinished_talk = 0,                    %% 未完成对话	
      condition,                              %% 任务触发条件	
      content,                                %% 任务内容	
      talk_item,                              %% 对话获得物品	
      state = 0,                              %% 完成任务需要的状态值 state = length(content)	
      exp = 0,                                %% 经验 (任务完成的奖励)	
      coin = 0,                               %% 铜币	
      binding_coin = 0,                       %% 绑定金	
      spt = 0,                                %% 灵力	
      attainment = 0,                         %% 修为	
      contrib = 0,                            %% 贡献	
      honor = 0,                              %% 荣誉	
      guild_exp = 0,                          %% 帮会经验	
      guild_coin = 0,                         %% 帮会资金	
      award_item,                             %% 奖励物品	
      award_select_item,                      %% 奖励可选物品	
      award_select_item_num = 0,              %% 可选奖励物品数量	
      award_gift,                             %% 礼包奖励	
      start_cost = 0,                         %% 触发扣除铜币	
      end_cost = 0,                           %% 完成扣除铜币	
      next_cue = 0,                           %% 是否提示下一任务	
      realm_honor = 0,                        %% 部落荣誉	
      time_start = 0,                         %% 任务可接时间	
      time_end = 0                            %% 任务不可接时间	
    }).	
	
%% 角色任务记录	
%% task_bag ==> role_task 	
-record(role_task, {	
      id,                                     %% 唯一标识id(运行时生成)	
      player_id,                              %% 角色id	
      task_id = 0,                            %% 任务id	
      trigger_time = 0,                       %% 触发时间	
      state = 0,                              %% 任务状态	
      end_state = 0,                          %% 结束状态	
      mark,                                   %% 任务记录器格式[State=int()Finish=bool(), Type=atom((), ...],	
      type = 0,                               %% 任务类型	
      other                                   %% 任务额外数据记录	
    }).	
	
%% 角色任务历史记录	
%% task_log ==> role_task_log 	
-record(role_task_log, {	
      player_id,                              %% 角色id	
      task_id = 0,                            %% 任务id	
      type = 0,                               %% 任务类型	
      trigger_time = 0,                       %% 接受时间	
      finish_time = 0                         %% 完成时间	
    }).	
	
%% 人物技能数据	
%% base_skill ==> ets_skill 	
-record(ets_skill, {	
      id,                                     %% 编号(25000 之前是怪物技能id ，25000之后是人物技能id)	
      name = "",                              %% 技能名称	
      desc = "",                              %% 技能描述	
      career = 0,                             %% 1:战士（玄武），2:刺客（白虎），3:弓手（青龙），4:牧师（朱雀），5:武尊(麒麟)	
      mod = 0,                                %% 模式:单体1/全体2	
      type = 0,                               %% 主动1/铺助2	
      obj = 0,                                %% 释放目标	
      area = 0,                               %% 攻击范围，格子数	
      area_obj = 0,                           %% 攻击范围目标，0以被击方的坐标为中心，1攻击方	
      level_effect = "",                      %% 升级效果	
      place = "",                             %% 产地	
      assist_type = 0,                        %% 1特殊（加血、回血、吸收伤害等）、0普通（加命中、躲闪等状态BUFF），不是辅助的技能为0	
      limit_action = 0,                       %% 动作限制	
      hate = <<"0">>,                         %% 技能仇恨	
      data                                    %% 效果	
    }).	
	
%% 宠物技能数据	
%% base_skill_pet ==> ets_pet_skill 	
-record(ets_pet_skill, {	
      id = 0,                                 %% 技能ID	
      name = "",                              %% 技能名	
      type,                                   %% 类型	
      lv = 0,                                 %% 技能分为低级，中级，高级和顶级技能	
      rate = 0,                               %% 技能触发概率	
      hurt_rate = 0,                          %% 技能伤害倍率	
      hurt = 0,                               %% 固定伤害	
      cd = 0,                                 %% 冷却时间	
      data = [],                              %% 技能数据	
      desc = "",                              %% 技能描述	
      effect = 0,                             %% 效果值，1定身、2击晕、3沉默、4减速	
      lastime = 0                             %% 效果的持续时间	
    }).	
	
%% 氏族	
%% guild ==> ets_guild 	
-record(ets_guild, {	
      id,                                     %% 编号	
      name = "",                              %% 族氏名称	
      announce = "",                          %% 氏族公告	
      chief_id = 0,                           %% 现任族长ID	
      chief_name = "",                        %% 现任族长昵称	
      deputy_chief1_id = 0,                   %% 长老1ID	
      deputy_chief1_name = "",                %% 长老1昵称	
      deputy_chief2_id = 0,                   %% 长老2ID	
      deputy_chief2_name = "",                %% 长老2昵称	
      deputy_chief_num = 0,                   %% 长老数	
      member_num = 0,                         %% 当前成员数	
      member_capacity = 0,                    %% 成员数上限	
      realm = 0,                              %% 落部	
      level = 0,                              %% 级别	
      upgrade_last_time = 0,                  %% 氏族最近升级的开始时间	
      reputation = 0,                         %% 氏族技能令数	
      lct_boss = <<"[0,0,0]">>,               %% 上次召唤boss的时间	
      boss_sv = 0,                            %% 氏族领地里面是否有boss存活，0没有，1为有	
      skills = 0,                             %% 剩余的氏族技能点，用于氏族技能升级，氏族每升级一级，增加2个技能点	
      exp = 0,                                %% 氏族经验值	
      funds = 0,                              %% 氏族资金	
      storage_num = 0,                        %% 当前仓库大小	
      storage_limit = 0,                      %% 仓库容量	
      consume_get_nexttime = 0,               %% 下次收取氏族消耗的时间	
      combat_num = 0,                         %% 上次氏族参战成员人数		
      combat_victory_num = 0,                 %% 上次氏族参战功勋	
      combat_all_num = 0,                     %% 氏族总功勋		
      combat_week_num = <<"[0,0]">>,          %% 本周氏族功勋	
      sky_apply = 0,                          %% 氏族战的上次报名时间	
      sky_award = [],                         %% 标注氏族参加氏族战后的奖励	
      a_plist = [],                           %% 玩家获取氏族战物品奖励的数量列表	
      jion_ltime = 0,                         %% 上次参战时间	
      create_time = 0,                        %% 创建时间	
      depart_names = "",                      %% 所有的堂名	
      carry = 0,                              %% 氏族运镖时间	
      bandits = 0,                            %% 氏族劫镖时间	
      unions = 0,                             %% 当前结盟或归附的状态，0:没状态1:流程中,	
      union_gid = 0,                          %% 结盟、归附时被合并的氏族的Id	
      union_id = 0,                           %% 执行流程时的那个申请条目的Id	
      targid = 0,                             %% 目标氏族的Id	
      convence = <<"[0,0]">>,                 %% 氏族族长召唤的次数数据	
      castle_rush_award = [],                 %% 攻城战奖励	
      del_alliance = 0                        %% 中止联盟的时间戳	
    }).	
	
%% 氏族成员	
%% view_guild_member ==> ets_guild_member 	
-record(ets_guild_member, {	
      id = 0,                                 %% 	
      guild_id = 0,                           %% 	
      guild_name = "",                        %% 	
      player_id = 0,                          %% 	
      player_name = "",                       %% 	
      donate_funds = 0,                       %% 	
      donate_total = 0,                       %% 	
      donate_lasttime = 0,                    %% 	
      donate_total_lastday = 0,               %% 	
      donate_total_lastweek = 0,              %% 	
      create_time = 0,                        %% 	
      title = "",                             %% 	
      remark = "",                            %% 	
      honor = 0,                              %% 	
      guild_depart_name = "",                 %% 	
      guild_depart_id = 0,                    %% 	
      kill_foe = 0,                           %% 	
      die_count = 0,                          %% 	
      get_flags = 0,                          %% 	
      magic_nut = 0,                          %% 	
      feats = 0,                              %% 	
      feats_all = 0,                          %% 	
      f_uptime = 0,                           %% 	
      gr = 0,                                 %% 	
      unions = 0,                             %% 	
      tax_time = 0,                           %% 	
      sex = 1,                                %% 	
      jobs = 0,                               %% 	
      lv = 1,                                 %% 	
      guild_position = 0,                     %% 	
      last_login_time = 0,                    %% 	
      online_flag = 0,                        %% 	
      career = 0,                             %% 	
      culture = 0,                            %% 	
      vip = 0                                 %% 	
    }).	
	
%% 氏族申请	
%% view_guild_apply ==> ets_guild_apply 	
-record(ets_guild_apply, {	
      id = 0,                                 %% 	
      guild_id = 0,                           %% 	
      player_id = 0,                          %% 	
      create_time = 0,                        %% 	
      nickname = "",                          %% 	
      sex = 1,                                %% 	
      jobs = 0,                               %% 	
      lv = 1,                                 %% 	
      career = 0,                             %% 	
      online_flag = 0,                        %% 	
      vip = 0                                 %% 	
    }).	
	
%% 氏族成员，警告：此ets只能用于insert成员数据时用	
%% guild_member ==> ets_insert_guild_member 	
-record(ets_insert_guild_member, {	
      id,                                     %% 编号	
      guild_id = 0,                           %% 氏族ID	
      guild_name = "",                        %% 氏族名称	
      player_id = 0,                          %% 角色ID	
      player_name = "",                       %% 角色昵称	
      donate_funds = 0,                       %% 总共捐献资金数	
      donate_total = 0,                       %% 总贡献	
      donate_lasttime = 0,                    %% 最后贡献时间	
      donate_total_lastday = 0,               %% 最后贡献时间当天的贡献	
      donate_total_lastweek = 0,              %% 最后贡献时间当周的贡献	
      create_time = 0,                        %% 创建时间	
      title = "",                             %% 称号	
      remark = "",                            %% 备注	
      honor = 0,                              %% 荣誉	
      guild_depart_name = "",                 %% 所属堂名	
      guild_depart_id = 0,                    %% 所属堂ID（默认为0，不属于任何堂）	
      kill_foe = 0,                           %% 杀敌数	
      die_count = 0,                          %% 死亡数	
      get_flags = 0,                          %% 夺旗数	
      magic_nut = 0,                          %% 魔核数	
      feats = 0,                              %% 当日功勋	
      feats_all = 0,                          %% 个人总功勋	
      f_uptime = 0,                           %% 上次个人功勋更新时间	
      gr = 0,                                 %% 是否已经领取了奖励0没有领取,1已经领取,	
      unions = 0,                             %% 联盟归附时族长选成员的标识	
      tax_time = 0                            %% 上一次领取攻城战税收的时间	
    }).	
	
%% 氏族失去你请记录，警告：此ets只能用于insert成员数据时用	
%% guild_apply ==> ets_insert_guild_apply 	
-record(ets_insert_guild_apply, {	
      id,                                     %% 编号	
      guild_id = 0,                           %% 申请氏族ID	
      player_id = 0,                          %% 申请角色ID	
      create_time = 0                         %% 申请时间	
    }).	
	
%% 氏族邀请	
%% guild_invite ==> ets_guild_invite 	
-record(ets_guild_invite, {	
      id,                                     %% 编号	
      guild_id = 0,                           %% 氏族ID	
      player_id = 0,                          %% 角色ID	
      create_time = 0,                        %% 邀请时间	
      recommander_id = 0,                     %% 推荐人Id	
      recommander_name = ""                   %% 推荐人名字	
    }).	
	
%% 氏族技能属性表	
%% guild_skills_attribute ==> ets_guild_skills_attribute 	
-record(ets_guild_skills_attribute, {	
      id,                                     %% 录记ID	
      guild_id = 0,                           %% 氏族ID	
      skill_id = 0,                           %% 技能ID，1：氏族仓库，2：氏族福利，3：人口	
      skill_name = "",                        %% 能技名字	
      skill_level = 0                         %% 技能等级	
    }).	
	
%% 帮派事件日志	
%% log_guild ==> ets_log_guild 	
-record(ets_log_guild, {	
      id,                                     %% 事件ID	
      guild_id = 0,                           %% 帮派ID	
      guild_name = "",                        %% 帮派名字	
      time = 0,                               %% 帮派事件发生时间	
      content = ""                            %% 帮派事件内容	
    }).	
	
%% 氏族仓库的物品流向记录	
%% log_warehouse_flowdir ==> ets_log_warehouse_flowdir 	
-record(ets_log_warehouse_flowdir, {	
      id,                                     %% 记录id	
      guild_id = 0,                           %% 氏族Id	
      gid = 0,                                %% 物品Idgid,	
      goods_id = 0,                           %% 物品类型id，goods_id	
      player_id = 0,                          %% 玩家Id	
      flow_type,                              %% 物品流向类型，0：从氏族仓库里取出；1：放进氏族仓库	
      flow_time = 0                           %% 物品操作时间	
    }).	
	
%% 宠物道具配置	
%% base_pet ==> ets_base_pet 	
-record(ets_base_pet, {	
      goods_id = 0,                           %% 物品编号	
      goods_name = "",                        %% 物品名称	
      name = "",                              %% 物品使用后名称	
      aptitude_down = 0,                      %% 资质下限	
      aptitude_up,                            %% 资质上限	
      skill = 0                               %% 天赋技能	
    }).	
	
%% 宠物	
%% pet ==> ets_pet 	
-record(ets_pet, {	
      id,                                     %% 编号	
      player_id = 0,                          %% 角色ID	
      goods_id = 0,                           %% 宠物类型ID	
      name = "",                              %% 宠物名称	
      rename_count = 0,                       %% 重命名次数	
      level = 1,                              %% 级别	
      exp = 0,                                %% 经验	
      happy = 1000,                           %% 快乐值	
      point = 2,                              %% 分配点数	
      forza = 0,                              %% 力量	
      wit = 0,                                %% 智慧	
      agile = 0,                              %% 敏捷	
      physique = 0,                           %% 体质	
      aptitude = 0,                           %% 资质值	
      grow = 0,                               %% 成长值	
      status = 0,                             %% 状态值 0 休眠 1出战2训练	
      skill_1 = <<"[0,0,0,0]">>,              %% 技能1[Id等级,阶数,经验],	
      skill_2 = <<"[0,0,0,0]">>,              %% 技能2[Id等级,阶数,经验],	
      skill_3 = <<"[0,0,0,0]">>,              %% 技能3[Id等级,阶数,经验],	
      skill_4 = <<"[0,0,0,0]">>,              %% 技能4[Id等级,阶数,经验],	
      time = 0,                               %% 经验增加的时间验证	
      goods_num = 0,                          %% 训练口粮数量	
      money_type = 0,                         %% 训练使用金钱类型	
      money_num = 0,                          %% 训练使用金钱数目	
      auto_up = 0,                            %% 是否自动升级	
      train_start = 0,                        %% 训练到期时间	
      train_end = 0,                          %% 训练到期时间	
      chenge = 0,                             %% 是否化形（0:未化形，1:第一次化形 2为第二次化形）,	
      skill_5 = <<"[0,0,0,0]">>,              %% 技能5[Id等级,阶数,经验],	
      ct = 0,                                 %% 创建时间	
      skill_6 = <<"[0,0,0,0]">>,              %% 技能6[Id等级,阶数,经验],	
      batt_skill = [],                        %% 战斗技能[Id]	
      apt_range = 0                           %% 成长额外已经加点范围3-8 3 表示30~39,4表示40~49...,	
    }).	
	
%% 副本数据	
%% base_dungeon ==> dungeon 	
-record(dungeon, {	
      id,                                     %% 副本编号	
      name = "",                              %% 副本名称	
      def = 0,                                %% 进入副本的默认场景	
      out = [],                               %% 传出副本时场景和坐标{场景id x, y},	
      scene = [],                             %% 整个副本所有的场景 {场景id 是否激活}  只有激活的场景才能进入,	
      requirement = []                        %% 场景的激活条件    [影响场景 是否完成, kill, npcId, 需要数量, 现在数量],	
    }).	
	
%% 副本进出次数计数器	
%% log_dungeon ==> ets_dungeon 	
-record(ets_dungeon, {	
      player_id = 0,                          %% 角色id	
      dungeon_id = 0,                         %% 副本id	
      first_dungeon_time = 0,                 %% 初次进入副本时间	
      dungeon_counter = 0                     %% 进入副本的次数计数	
    }).	
	
%% 师徒关系表	
%% master_apprentice ==> ets_master_apprentice 	
-record(ets_master_apprentice, {	
      id,                                     %% 编号	
      apprentenice_id = 0,                    %% 徒弟ID	
      apprentenice_name = "",                 %% 师傅名字	
      master_id = 0,                          %% 师傅ID	
      lv = 0,                                 %% 等级	
      career = 0,                             %% 徒弟职业	
      status = 0,                             %% 徒弟当前状态（0没关系，1已出师，2学徒，3申请中）	
      report_lv = 0,                          %% 可汇报等级（本次汇报徒弟的等级相对于上一次汇报所提高的等级）	
      join_time = 0,                          %% 入门时间	
      last_report_time = 0,                   %% 最近报告时间	
      sex = 0                                 %% 性别	
    }).	
	
%% 师傅表(伯乐榜)	
%% master_charts ==> ets_master_charts 	
-record(ets_master_charts, {	
      id,                                     %% 编号	
      master_id = 0,                          %% 师傅ID	
      master_name = "",                       %% 师傅姓名	
      master_lv = 0,                          %% 师傅等级	
      realm = 0,                              %% 所属部落	
      career = 0,                             %% 师傅职业	
      award_count = 0,                        %% 师道值	
      score_lv = 0,                           %% 成绩级数	
      appre_num = 0,                          %% 师门人数	
      regist_time = 0,                        %% 登记时间	
      lover_type = 0,                         %% 是否上伯乐榜榜(0：不上，1：上)	
      sex = 1,                                %% 1男2女	
      online = 1                              %% 1在线0否	
    }).	
	
%% 玩家经脉等级表	
%% meridian ==> ets_meridian 	
-record(ets_meridian, {	
      id,                                     %% 经脉ID	
      player_id = 0,                          %% 玩家ID	
      mer_yang = 0,                           %% 阳脉等级	
      mer_yin = 0,                            %% 阴脉等级	
      mer_wei = 0,                            %% 维脉等级	
      mer_ren = 0,                            %% 任脉等级	
      mer_du = 0,                             %% 督脉等级	
      mer_chong = 0,                          %% 冲脉等级	
      mer_qi = 0,                             %% 奇脉等级	
      mer_dai = 0,                            %% 带脉等级	
      mer_yang_linggen = 0,                   %% 阳脉灵根	
      mer_yin_linggen = 0,                    %% 阴脉灵根	
      mer_wei_linggen = 0,                    %% 维脉灵根	
      mer_ren_linggen = 0,                    %% 任脉灵根	
      mer_du_linggen = 0,                     %% 督脉灵根	
      mer_chong_linggen = 0,                  %% 冲脉灵根	
      mer_qi_linggen = 0,                     %% 奇脉灵根	
      mer_dai_linggen = 0,                    %% 带脉灵根	
      meridian_uplevel_typeId = 0,            %% 升级中的经脉类型	
      meridian_uplevel_time = 0,              %% 升级结束时间	
      yang_top = 0,                           %% 阳脉突破值	
      yin_top = 0,                            %% 阴脉突破值	
      wei_top = 0,                            %% 维脉突破值	
      ren_top = 0,                            %% 任脉突破值	
      du_top = 0,                             %% 督脉突破值	
      chong_top = 0,                          %% 冲脉突破值	
      qi_top = 0,                             %% 奇脉突破值	
      dai_top = 0                             %% 带脉突破值	
    }).	
	
%% 经脉表	
%% base_meridian ==> ets_base_meridian 	
-record(ets_base_meridian, {	
      id,                                     %% 编号	
      name = "",                              %% 经脉名称	
      mer_type = 0,                           %% 经脉种类	
      mer_lvl = 0,                            %% 等级种类	
      hp = 0,                                 %% 气血值	
      def = 0,                                %% 防御值	
      mp = 0,                                 %% 内力值	
      hit = 0,                                %% 命中值	
      crit = 0,                               %% 暴击值	
      shun = 0,                               %% 闪避值	
      att = 0,                                %% 攻击值	
      ten = 0,                                %% 全抗值	
      player_level = 0,                       %% 玩家修炼等级	
      spirit = 0,                             %% 灵力需求	
      timestamp = 0                           %% 修炼时间需求	
    }).	
	
%% 物品拍卖流向日志表（记录拍卖的物品或者元宝铜钱的流向日志）	
%% log_sale_dir ==> ets_log_sale_dir 	
-record(ets_log_sale_dir, {	
      id,                                     %% 日志记录Id	
      sale_id = 0,                            %% 拍卖记录Id	
      player_id = 0,                          %% 卖家Id	
      flow_time = 0,                          %% 变动时间	
      flow_type = 1,                          %% 流向类型：1：上架，0：取消或者系统主动下架	
      sale_type = 1,                          %% 拍卖类型（1，实物；2，元宝或铜钱）	
      gid = 0,                                %% 物品ID，当ID为0时，表示拍卖的为元宝	
      goods_id = 0,                           %% 品物基本类型ID	
      num = 0,                                %% 货币（拍卖的物品是元宝或铜钱时，此值存在数值，不是元宝时，此值为该物品的数量）	
      price_type = 1,                         %% 拍卖价格类型：1铜钱，2元宝当gid和goods_id都为0时，1表示拍卖的是元宝，2表示拍卖的是铜钱,	
      price = 0                               %% 拍卖价格	
    }).	
	
%% 在线奖励	
%% online_gift ==> ets_online_gift 	
-record(ets_online_gift, {	
      id,                                     %% 	
      player_id = 0,                          %% 玩家id	
      times = 0,                              %% 当日领取次数	
      timestamp = 0                           %% 领取时间	
    }).	
	
%% 在线奖励物品表	
%% base_online_gift ==> ets_base_online_gift 	
-record(ets_base_online_gift, {	
      id,                                     %% 	
      goodsbag = [],                          %% 物品列表	
      level = 0,                              %% 等级	
      times = 0,                              %% 第几份	
      timestamp = 0                           %%  时间间隔	
    }).	
	
%% 国运时间表	
%% base_carry ==> ets_carry_time 	
-record(ets_carry_time, {	
      realm = 0,                              %% 部落	
      seq = 0,                                %% 序号	
      start_time = 0,                         %% 开始时间	
      end_time = 0,                           %% 结束时间	
      timestamp = 0                           %% 生成时间	
    }).	
	
%% 玩家地图分类表	
%% base_map ==> ets_base_map 	
-record(ets_base_map, {	
      scene_id = 0,                           %% 地图id	
      scene_name = "",                        %% 地图名称	
      realm = 0,                              %% 国家id	
      realm_name = ""                         %% 国家名称	
    }).	
	
%% 诛邪系统物品信息表	
%% base_box_goods ==> ets_base_box_goods 	
-record(ets_base_box_goods, {	
      id,                                     %% 信息表记录Id	
      hole_type = 0,                          %% 妖洞类型：1，百年妖洞；2，千年妖洞；3，万年妖洞	
      goods_id = 0,                           %% 物品基本类型Id	
      pro = 0.0000000000,                     %% 掉落概率	
      num_limit = 0,                          %% 最大掉落数量限制	
      goods_id_replace = 0,                   %% 当掉落的数量超过限制时用于替代的物品基本类型Id	
      show_type = 0                           %% 是否发系统公告和全服显示记录：1，显示；0，不显示	
    }).	
	
%% 诛邪系统打开妖洞丢落的装备的记录	
%% log_box_open ==> ets_log_box_open 	
-record(ets_log_box_open, {	
      id,                                     %% 日志记录Id	
      player_id = 0,                          %% 玩家Id	
      player_name = "",                       %% 玩家名字	
      hole_type,                              %% 妖洞类型：1，百年妖洞；2，千年妖洞；3，万年妖洞	
      goods_id,                               %% 物品基本类型Id	
      goods_name = "",                        %% 物品名称	
      gid = 0,                                %% 物品gid如果是从秘境里出来的物品，则此处填0,	
      num = 1,                                %% 开的物品数量	
      show_type = 0,                          %% 是否发系统公告和全服显示记录：1，显示；0，不显示	
      open_time = 0                           %% 得到该物品时的时间	
    }).	
	
%% 玩家开封印次数计算器和时间计时器	
%% log_box_player ==> ets_log_box_player 	
-record(ets_log_box_player, {	
      player_id = 0,                          %% 玩家Id	
      purple_time = 0,                        %% 最近开出紫装的时间	
      open_counter = 0,                       %% 封印开诛邪次数	
      purple_num,                             %% 在400次之前开出紫装的数量，数量达到2之后不再累加0	
      box_goods_trace = []                    %% 开封印限制级物品数量记录	
    }).	
	
%% 记录玩家进入的诛邪副本场景数据	
%% box_scene ==> ets_box_scene 	
-record(ets_box_scene, {	
      id = 0,                                 %% ID	
      player_id = 0,                          %% 玩家ID	
      mlist = [],                             %% 场景怪物数据结构,	
      glist = [],                             %% 邪诛的物品列表（持续更新）	
      num = 0,                                %% 当天进入的次数	
      scene = 0,                              %% 原来的场景ID	
      x = 0,                                  %% 原来场景的X坐标	
      y = 0,                                  %% 原来场景的Y坐标	
      goods_id = 0                            %% 当前使用的秘境令ID	
    }).	
	
%% 玩家反馈	
%% feedback ==> feedback 	
-record(feedback, {	
      id,                                     %% ID	
      type = 1,                               %% 类型(1-Bug/2-投诉/3-建议/4-其它)	
      state = 0,                              %% 状态(已回复1/未回复0)	
      player_id = 0,                          %% 玩家ID	
      player_name = "",                       %% 玩家名	
      title = "",                             %% 标题	
      content,                                %% 内容	
      timestamp = 0,                          %% Unix时间戳	
      ip = "",                                %% 玩家IP	
      server = "",                            %% 服务器	
      gm = "",                                %% 游戏管理员	
      reply,                                  %% 回复内容	
      reply_time = 0                          %% 回复时间	
    }).	
	
%% 目标奖励基础表	
%% base_target_gift ==> ets_base_target_gift 	
-record(ets_base_target_gift, {	
      day = 0,                                %% 天数	
      name = <<"0">>,                         %% 名称	
      time_limit = 0,                         %% 时间限制	
      target,                                 %% 成就目标	
      gift,                                   %% 礼物列表	
      gift_certificate = 0,                   %% 礼券	
      explanation,                            %%  领取说明	
      tip                                     %% 提示	
    }).	
	
%% 目标奖励玩家表	
%% target_gift ==> ets_target_gift 	
-record(ets_target_gift, {	
      id,                                     %% 	
      player_id = 0,                          %% 玩家id	
      first = 0,                              %% 第一天1	
      first_two = 0,                          %% 第一天2	
      first_three = 0,                        %% 第一天3	
      first_four = 0,                         %% 第一天4	
      first_five = 0,                         %% 第一天5	
      second = 0,                             %% 第二天1	
      second_two = 0,                         %% 第二天2	
      second_three = 0,                       %% 第二天3	
      second_four = 0,                        %% 第二天4	
      second_five = 0,                        %% 第二天5	
      third = 0,                              %% 第三天1	
      third_two = 0,                          %% 第三天2	
      third_three = 0,                        %% 第三天3	
      third_four = 0,                         %% 第三天4	
      third_five = 0,                         %% 第三天5	
      fourth = 0,                             %% 第四天1	
      fourth_two = 0,                         %% 第四天2	
      fourth_three = 0,                       %% 第四天3	
      fourth_four = 0,                        %% 第四天4	
      fifth = 0,                              %% 第五天1	
      fifth_two = 0,                          %% 第五天2	
      fifth_three = 0,                        %% 第五天3	
      sixth = 0,                              %% 第六天1	
      sixth_two = 0,                          %% 第六天2	
      sixth_three = 0,                        %% 第六天3	
      seventh = 0,                            %% 第七天1	
      seventh_two = 0,                        %% 第七天2	
      seventh_three = 0,                      %% 第七天3	
      eighth = 0,                             %% 第八天1	
      eighth_two = 0,                         %% 第八天2	
      ninth = 0,                              %% 第九天1	
      ninth_two = 0,                          %% 第八天2	
      tenth = 0                               %% 第十天	
    }).	
	
%% 委托任务表	
%% task_consign ==> ets_task_consign 	
-record(ets_task_consign, {	
      id,                                     %% 	
      player_id = 0,                          %% 玩家id	
      task_id = 0,                            %% 任务id	
      exp = 0,                                %% 经验	
      spt = 0,                                %% 灵力	
      cul = 0,                                %% 修为	
      gold = 0,                               %% 元宝	
      times = 0,                              %% 委托次数	
      timestamp = 0                           %% 委托时间	
    }).	
	
%% 玩家游戏系统设置	
%% player_sys_setting ==> player_sys_setting 	
-record(player_sys_setting, {	
      player_id = 0,                          %% 玩家Id	
      shield_role = 0,                        %% 蔽屏附近玩家和宠物，0：不屏蔽；1：屏蔽	
      shield_skill = 0,                       %% 屏蔽技能特效， 0：不屏蔽；1：屏蔽	
      shield_rela = 0,                        %% 屏蔽好友请求，0：不屏蔽；1：屏蔽	
      shield_team = 0,                        %% 屏蔽组队邀请，0：不屏蔽；1：屏蔽	
      shield_chat = 0,                        %% 屏蔽聊天传闻，0：不屏蔽；1：屏蔽	
      music = 50,                             %% 游戏音乐，默认值为50	
      soundeffect = 50,                       %% 游戏音效，默认值为50	
      fasheffect = 0,                         %% 时装显示(0对别人显示，1对别人不显示)	
      smelt = 0                               %% 玩家第一次打开炼器面板时显示指引面板	
    }).	
	
%% 战场总排行表	
%% arena ==> ets_arena 	
-record(ets_arena, {	
      id,                                     %% 主键	
      player_id = 0,                          %% 色角id	
      nickname = "",                          %% 色角昵称	
      realm = 0,                              %% 落部	
      career = 0,                             %% 职业	
      lv = 0,                                 %% 级等	
      att = 0,                                %% 攻击	
      sex = 0,                                %% 性别	
      wins = 0,                               %% 获胜次数	
      score = 0,                              %% 积分	
      pid = <<"[0,0]">>,                      %% 竞技场信息	
      jtime = 0                               %% 报名竞技场时间	
    }).	
	
%% 战场周排行表	
%% arena_week ==> ets_arena_week 	
-record(ets_arena_week, {	
      id,                                     %% 主键	
      player_id = 0,                          %% 角色id	
      nickname = "",                          %% 玩家昵称	
      realm = 0,                              %% 落部	
      career = 0,                             %% 职业	
      lv = 0,                                 %% 级等	
      area = 0,                               %% 战区	
      camp = 0,                               %% 所在方(1天龙2地龙),	
      type = 0,                               %% 败胜 (1败2胜),	
      score = 0,                              %% 积分	
      ctime = 0,                              %% 创建时间	
      killer = 0                              %% 杀人数	
    }).	
	
%% 玩家委托任务列表	
%% consign_task ==> ets_consign_task 	
-record(ets_consign_task, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      tid = 0,                                %% 任务id	
      name = "",                              %% 任务名称	
      lv = 0,                                 %% 任务等级	
      t1 = 0,                                 %% 委托到期时间	
      state = 0,                              %% 任务状态	
      gid_1 = 0,                              %% 物品奖励1	
      n_1 = 0,                                %% 物品奖励1数量	
      gid_2 = 0,                              %% 物品奖励2	
      n_2 = 0,                                %% 物品奖励2数量	
      mt = 0,                                 %% 金钱类型	
      n_3 = 0,                                %% 金钱数量	
      t2 = 0,                                 %% 发布委托时间	
      aid = 0,                                %% 接受任务玩家id	
      t3 = 0,                                 %% 接受任务时间	
      autoid = 0                              %% 任务表的自增id	
    }).	
	
%% 委托玩家列表	
%% consign_player ==> ets_consign_player 	
-record(ets_consign_player, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      publish = 0,                            %% 发布次数	
      pt = 0,                                 %% 发布时间戳	
      accept = 0,                             %% 接受次数	
      at = 0,                                 %% 接受时间戳	
      timestamp = 0,                          %% 时间戳	
      exp = 0,                                %% 经验	
      spt = 0,                                %% 灵力	
      cul = 0,                                %% 修为	
      coin = 0,                               %% 铜钱	
      bcoin = 0,                              %% 绑定铜	
      ge = 0,                                 %% 氏族经验	
      gc = 0                                  %% 氏族贡献	
    }).	
	
%% 玩家运劫镖次数表	
%% carry ==> ets_carry 	
-record(ets_carry, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      carry = 0,                              %% 运镖次数	
      carry_time = 0,                         %% 运镖时间	
      bandits = 0,                            %% 劫镖次数	
      bandits_time = 0,                       %% 劫镖时间	
      quality = 1,                            %% 镖车品质	
      taihao = 0,                             %% 太昊镖师	
      vnwa = 0,                               %% 女娲镖师	
      huayang = 0                             %% 华阳镖师	
    }).	
	
%% 离线经验累积表	
%% offline_award ==> ets_offline_award 	
-record(ets_offline_award, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      total = 0,                              %% 总累积时间	
      exc_t = 0,                              %% 当天凝神时间	
      offline_t = 0                           %% 离线时间	
    }).	
	
%% 连续在线奖励表	
%% online_award ==> ets_online_award 	
-record(ets_online_award, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      lv = 0,                                 %% 玩家等级	
      day = 1,                                %% 连续上线天数	
      d_t = 0,                                %% 连续上线时间戳	
      g4 = 0,                                 %% 第四天物品	
      g4_m = 0,                               %% 第四天物品领取标记	
      g8 = 0,                                 %% 第八天物品	
      g8_m = 0,                               %% 第八天物品领取标记	
      g12 = 0,                                %% 第十二天物品	
      g12_m = 0,                              %% 第十二天物品领取标记	
      hour = 0,                               %% 当天在线时间(S)	
      h_t = 0,                                %% 天时间戳	
      h_m = 0,                                %% 天奖励领取时间戳	
      week = 0,                               %% 每周在线时间(S)	
      w_t = 0,                                %% 周时间戳	
      w_m = 0,                                %% 周奖励领取标记	
      mon = 0,                                %% 当月在线时间(S)	
      m_t = 0,                                %% 月时间戳	
      m_m = 0                                 %% 月奖励领取标记	
    }).	
	
%% 跑商表	
%% business ==> ets_business 	
-record(ets_business, {	
      id,                                     %% 	
      player_id = 0,                          %% 玩家id	
      times = 0,                              %% 跑商次数	
      timestamp = 0,                          %% 跑商时间戳	
      color = 4,                              %% 商车颜色	
      lv = 0,                                 %% 玩家等级	
      current = 0,                            %% 当前被劫次数	
      free = 0,                               %% 免费刷新次数	
      free_time = 0,                          %% 免费刷新时间	
      once = 0,                               %% 中途免费一次	
      total = 0                               %% 总次数	
    }).	
	
%% 劫商日志表	
%% log_business_robbed ==> ets_log_robbed 	
-record(ets_log_robbed, {	
      id,                                     %% 	
      player_id = 0,                          %% 打劫者id	
      robbed_id = 0,                          %% 被劫者id	
      color = 0,                              %% 商车颜色	
      timestamp = 0                           %% 时间戳	
    }).	
	
%% 跑速奖励表	
%% base_business ==> ets_base_business 	
-record(ets_base_business, {	
      id,                                     %% 	
      lv = 0,                                 %% 玩家等级	
      color = 0,                              %% 商车颜色	
      exp = 0,                                %% 经验	
      spt = 0                                 %% 灵力	
    }).	
	
%% 节日登陆奖励	
%% online_award_holiday ==> ets_online_award_holiday 	
-record(ets_online_award_holiday, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      every_day_time = 0,                     %% 每天登陆时间戳	
      every_day_mark = 0,                     %% 每天登陆领取奖励标记	
      continuous_day = 0,                     %% 连续登陆天数	
      continuous_mark = 0                     %% 连续登陆领取标记	
    }).	
	
%% 英雄帖	
%% hero_card ==> ets_hero_card 	
-record(ets_hero_card, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      times = 0,                              %% 次数	
      lv = 0,                                 %% 玩家等级	
      color = 0,                              %% 颜色	
      timestamp = 0                           %% 时间戳	
    }).	
	
%% 英雄帖奖励表	
%% base_hero_card ==> ets_base_hero_card 	
-record(ets_base_hero_card, {	
      id,                                     %% 	
      goods_id = 0,                           %% 物品id	
      task_id = 0,                            %% 任务id	
      lv = 0,                                 %% 等级	
      color = 0,                              %% 颜色	
      exp = 0,                                %% 经验	
      spt = 0                                 %% 灵力	
    }).	
	
%% 仙侣情缘	
%% love ==> ets_love 	
-record(ets_love, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      charm = 0,                              %% 魅力值	
      refresh = 0,                            %% 刷新时间间隔	
      status = 0,                             %% 当前状态	
      duration = 0,                           %% 持续时间	
      mult = 1,                               %% 经验倍数	
      times = 0,                              %% 被邀请次数	
      timestamp = 0,                          %% 时间戳	
      invitee,                                %% 被邀请人信息[idname,career,realm,sex],	
      title = 0,                              %% 被邀请人信息称号id	
      title_time = 0,                         %% 称号到期时间	
      privity_info,                           %% 默契度测试信息	
      be_invite,                              %% 有缘人列表	
      task_times = 0,                         %% 爱侣任务次数	
      task_content                            %% 爱侣任务内容	
    }).	
	
%% 默契度题库	
%% base_privity ==> ets_base_privity 	
-record(ets_base_privity, {	
      id,                                     %% 	
      question,                               %% 题目	
      a,                                      %% 答案a 	
      b,                                      %% 答案b 	
      c                                       %% 答案c	
    }).	
	
%% 时装基础数据表	
%% base_goods_fashion ==> ets_base_goods_fashion 	
-record(ets_base_goods_fashion, {	
      id,                                     %% 自增id	
      goods_id = 0,                           %% 物品类型编号	
      max_crit = 0,                           %% 暴击上限	
      min_crit = 0,                           %% 暴击下限	
      max_dodge = 0,                          %% 躲避上限	
      min_dodge = 0,                          %% 躲避下限	
      max_hit = 0,                            %% 命中上限	
      min_hit = 0,                            %% 命中下限	
      max_mp = 0,                             %% 法力上限	
      min_mp = 0,                             %% 法力下限	
      max_physique = 0,                       %% 体质上限	
      min_physique = 0,                       %% 体质下限	
      max_attack = 0,                         %% 最大攻击	
      min_attack = 0,                         %% 最小攻击	
      max_anti_all = 0,                       %% 风雷水火土抗上限	
      min_anti_all = 0,                       %% 风雷水火土抗下限	
      max_forza = 0,                          %% 最大力量	
      min_forza = 0,                          %% 最小力量	
      max_wit = 0,                            %% 最大智力	
      min_wit = 0,                            %% 最小智力	
      max_agile = 0,                          %% 最大敏捷	
      min_agile = 0,                          %% 最小敏捷	
      max_anti_wind = 0,                      %% 最大风抗	
      min_anti_wind = 0,                      %% 最小风抗	
      max_anti_thunder = 0,                   %% 最大雷抗	
      min_anti_thunder = 0,                   %% 最小雷抗	
      max_anti_water = 0,                     %% 最大水抗	
      min_anti_water = 0,                     %% 最小水抗	
      max_anti_fire = 0,                      %% 最大火抗	
      min_anti_fire = 0,                      %% 最小火抗	
      max_anti_soil = 0,                      %% 最大土抗	
      min_anti_soil = 0,                      %% 最小土抗	
      max_att_per = 0,                        %% 最大攻击百分比	
      min_att_per = 0,                        %% 最小攻击百分比	
      max_hp_per = 0,                         %% 最大气血百分比	
      min_hp_per = 0                          %% 最小气血百分比	
    }).	
	
%% 登陆抽奖表	
%% lucky_draw ==> ets_luckydraw 	
-record(ets_luckydraw, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      goods_id = 0,                           %% 物品id	
      days = 0,                               %% 连续登陆天数	
      times = 0,                              %% 可抽奖次数	
      timestamp = 0,                          %% 天时间戳	
      goodslist                               %% 奖励物品列表	
    }).	
	
%% 目标引导记录表	
%% target_lead ==> ets_targetlead 	
-record(ets_targetlead, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      pet = 0,                                %% 灵兽引导	
      mount = 0,                              %% 坐骑引导	
      save_html = 0,                          %% 收藏主页	
      guild = 0,                              %% 氏族引导	
      magic = 0,                              %% 幻化引导	
      light = 0,                              %% 轻功引导	
      carry = 0,                              %% 运镖引导	
      suit1 = 0,                              %% 装备1引导	
      train = 0,                              %% 试炼引导	
      suit2 = 0,                              %% 装备2引导	
      fst = 0,                                %% 封神台引导	
      td = 0,                                 %% 镇妖台引导	
      business = 0,                           %% 跑商引导	
      peach = 0,                              %% 蟠桃引导	
      weapon = 0,                             %% 神器	
      arena = 0,                              %% 竞技场	
      fs_era = 0,                             %% 封神纪元	
      mount_arena = 0                         %% 斗兽	
    }).	
	
%% 玩家成就系统的统计数据	
%% achieve_statistics ==> ets_ach_stats 	
-record(ets_ach_stats, {	
      id = 0,                                 %% 自增id	
      pid = 0,                                %% 玩家id	
      trc = 0,                                %% 完成日常任务次数	
      tg = 0,                                 %% 完成氏族任务次数	
      tfb = 0,                                %% 完成副本任务次数	
      tcul = 0,                               %% 完成修为任务次数	
      tca = 0,                                %% 完成运镖任务次数	
      tbus = 0,                               %% 完成跑商任务次数	
      tfst = 0,                               %% 完成封神贴任务	
      tcyc = 0,                               %% 完成循环任务次数	
      trm = 0,                                %% 杀击怪物次数	
      trb = <<"[0,0,0,0,0,0]">>,              %% 杀击boss次数[火凤，千年老龟，烈焰麒麟兽，灵狐，裂地斧魔，千年猴妖]	
      trbc = <<"[0,0,0]">>,                   %% 成功劫镖和劫商次数记录	
      trbus = 0,                              %% 成功跑商次数	
      trfst = <<"[0,0,0]">>,                  %% 封神台通关次数[12，21，45]层	
      trar = 0,                               %% 场战杀敌次数	
      trf = 0,                                %% 氏族战运旗次数	
      trstd = <<"[0,0,0]">>,                  %% 单人镇妖台杀怪物次数[千年毒尸，龙骨甲兽，食腐树妖]	
      trmtd = <<"[0,0,0]">>,                  %% 多人镇妖台杀怪物次数[千年毒尸，龙骨甲兽，食腐树妖]	
      trfbb = <<"[0,0,0,0]">>,                %% 杀击副本boss次数[雷公，狐小小，河伯，蚩尤]	
      trsixfb = <<"[0,0,0]">>,                %% 击杀怪物次数[穷奇巨兽，赤尾狐，瑶池圣母]	
      trzxt = <<"[0,0,0]">>,                  %% 诛仙台通关次数[12，21，30]层	
      trsm = 0,                               %% 神魔乱斗参与击败哈迪斯的次数	
      trtrain = 0,                            %% 击败试炼之祖的次数	
      trjl = 0,                               %% 击败蛮荒巨龙的次数	
      trds = 0,                               %% 击败千年毒尸的次数	
      trgg = 0,                               %% 击杀共工次数	
      ygcul = 0,                              %% 远古修为消耗值	
      fsb = <<"[0,0,0]">>,                    %% 诛邪次数统计[百年，千年，万年]	
      fssh = 0,                               %% 商城购买道具次数	
      fsc = <<"[0,0]">>,                      %% 物品合成和分解次数统计[石头合成，装备分解]	
      fssa = <<"[0,0]">>,                     %% 市场挂售和购买次数统计[市场挂售，市场购买]	
      fslg = 0,                               %% 离线挂机时间统计	
      infl = 0,                               %% 记录玩家送花的朵数	
      inlv = 0,                               %% 完成仙侣情缘次数	
      inlved = 0,                             %% 仙侣情缘中被邀请过次数	
      infai = 0,                              %% 庄园收获次数	
      infao = 0                               %% 庄园偷取次数	
    }).	
	
%% 玩家最近完成的成就记录	
%% log_ach_finish ==> ets_log_ach_f 	
-record(ets_log_ach_f, {	
      id = 0,                                 %% 自增Id	
      pid = 0,                                %% 玩家Id	
      ach_num = 0,                            %% 就成Id	
      time = 0                                %% 完成时间	
    }).	
	
%% 登陆奖励（新）	
%% login_award ==> ets_login_award 	
-record(ets_login_award, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      days = 0,                               %% 连续登陆天数	
      time = 0,                               %% 时间戳	
      un_charge,                              %% 未充值物品列表	
      charge,                                 %% 充值物品列表	
      charge_mark = 0                         %% 充值物品标记	
    }).	
	
%% 每日在线奖励物品表	
%% base_daily_gift ==> ets_base_daily_gift 	
-record(ets_base_daily_gift, {	
      id,                                     %% 自增ID	
      goods_id = 0,                           %% 物品ID	
      amount = 0                              %% 数量	
    }).	
	
%% 塔奖励表 	
%% base_tower_award ==> ets_tower_award 	
-record(ets_tower_award, {	
      id,                                     %% 层数	
      exp = 0,                                %% 经验	
      spt = 0,                                %% 灵力	
      honor = 0,                              %% 荣誉	
      time = 0,                               %% 时间（分钟）	
      type = 0                                %% 类型1封神台，2诛仙台	
    }).	
	
%% 装备附魔基础属性表	
%% base_magic ==> ets_base_magic 	
-record(ets_base_magic, {	
      id,                                     %% 自增id	
      step = 1,                               %% 物品等级1(1~29)2(30~39),3(40~49),4(50~59),5(60~69),6(70~79),7(80~89),8(90~99),	
      pack = 1,                               %% 包裹	
      prop = "",                              %% 性属	
      ratio = 0.000,                          %% 随机概率	
      max_value = 0,                          %% 最大值	
      min_value = 0                           %% 最小值	
    }).	
	
%% 循环任务刷经验倍数	
%% cycle_flush ==> ets_cycle_flush 	
-record(ets_cycle_flush, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      mult = 0,                               %% 倍数	
      timestamp = 0                           %% 时间戳	
    }).	
	
%% 跨服战场玩家表	
%% war_player ==> ets_war_player 	
-record(ets_war_player, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      nickname,                               %% 玩家名字	
      realm = 0,                              %% 阵营	
      career = 0,                             %% 职业	
      level = 0,                              %% 玩家等级	
      sex = 0,                                %% 玩家性别	
      platform = <<"0">>,                     %% 平台	
      sn = 0,                                 %% 服务器id	
      times = 0,                              %% 第几届	
      sign_up = 0,                            %% 是否报名（1报名0否）	
      timestamp = 0,                          %% 报名时间		
      transfer = 0,                           %% 是否转让（0否）	
      lv = 0,                                 %% 级别	
      invite = 0,                             %% 邀请次数	
      is_invite = 0,                          %% 是否被邀请的（0否）	
      double_hit = 0,                         %% 连击数	
      title = 0,                              %% 称号	
      max_hit = 0,                            %% 最大连击	
      kill = 0,                               %% 击杀数	
      die = 0,                                %% 死亡次数	
      point = 0,                              %%  积分	
      drug = 0,                               %% 领取药品标记	
      att = 0,                                %% 战斗力	
      att_flag = 0                            %% 攻击战旗次数	
    }).	
	
%% 跨服战场队伍表	
%% war_team ==> ets_war_team 	
-record(ets_war_team, {	
      id,                                     %% 	
      sn = 0,                                 %% 所在服	
      platform = <<"0">>,                     %% 平台	
      name = <<"''">>,                        %% 服务器名称		
      team,                                   %% 队伍列表[{玩家id，玩家名字，玩家部落}]		
      lv = 0,                                 %%  级别	
      times = 0,                              %% 第几届	
      point = 0,                              %% 积分	
      total = 0,                              %% 总积分	
      syn = 0                                 %% 玩家数据同步标记(1同步，0未同步)	
    }).	
	
%% 对战分组	
%% war_vs ==> ets_war_vs 	
-record(ets_war_vs, {	
      id,                                     %% 	
      sn_a = 0,                               %% 服务器a	
      platform_a = <<"0">>,                   %% 平台	
      name_a = <<"0">>,                       %% 服务器a	
      sn_b = 0,                               %% 服务器b	
      platform_b = <<"0">>,                   %% 平台	
      name_b = <<"0">>,                       %% 服务器b	
      times = 0,                              %% 第几届	
      lv = 0,                                 %% 级别	
      round = 0,                              %% 轮次	
      res_a = 0,                              %% 比分	
      res_b = 0,                              %% 比分	
      timestamp = 0                           %% 开始时间	
    }).	
	
%% 封神大会状态	
%% war_state ==> ets_war_state 	
-record(ets_war_state, {	
      id,                                     %% 	
      type = 0,                               %% 0新，1旧	
      times = 0,                              %% 第几届	
      state = 0,                              %% 状态(0未完成，1完成)	
      lv = 0,                                 %% 分组	
      round = 0,                              %% 当前轮次	
      max_round = 0,                          %% 最大轮次	
      timestamp = 0                           %% 时间戳	
    }).	
	
%% 玩家评价表	
%% appraise ==> ets_appraise 	
-record(ets_appraise, {	
      id,                                     %% 主键id	
      owner_id = 0,                           %% 价评人id	
      other_id = 0,                           %% 被评价人id	
      type = 0,                               %% 1为自己的被崇拜的信息2为崇拜,3为鄙视,	
      adore_num = 0,                          %% 被崇拜次数	
      handle_num = 0,                         %% 已加魅力值对应点数(20点加一个魅力值)	
      ct = 0                                  %% 时间	
    }).	
	
%% 灵兽购买表	
%% pet_buy ==> ets_pet_buy 	
-record(ets_pet_buy, {	
      id,                                     %% 主键	
      player_id = 0,                          %% 角色id	
      goods_id = 0,                           %% 物品类型id	
      ct = 0                                  %% 购买时间	
    }).	
	
%% 灵兽分离技能	
%% pet_split_skill ==> ets_pet_split_skill 	
-record(ets_pet_split_skill, {	
      id,                                     %% 主键	
      player_id = 0,                          %% 角色id	
      pet_id = 0,                             %% 灵兽id	
      pet_skill = [],                         %% 灵兽技能[skill_idleve,step,exp],	
      ct = 0                                  %% 技能分离时间	
    }).	
	
%% base_pet_skill_effect	
%% base_pet_skill_effect ==> ets_base_pet_skill_effect 	
-record(ets_base_pet_skill_effect, {	
      id,                                     %% 自增id	
      skill_id = 0,                           %% 兽灵技能ID	
      lv = 0,                                 %% 级等	
      step = 0,                               %% 阶	
      per = 0.0000,                           %% 百分比值	
      fix = 0                                 %% 固定值	
    }).	
	
%% 氏族结盟归附情况申请表	
%% guild_union ==> guild_union 	
-record(guild_union, {	
      id,                                     %% 自增Id	
      agid = 0,                               %% A氏族Id	
      bgid = 0,                               %% B氏族Id	
      agname = "",                            %% A氏族名称	
      bgname = "",                            %% B氏族名称	
      acid = 0,                               %% A氏族族长ID	
      bcid = 0,                               %% B氏族族长ID	
      acname = "",                            %% A氏族族长名称	
      bcname = "",                            %% B氏族族长名称	
      alv = 0,                                %% A氏族等级	
      blv = 0,                                %% B氏族等级	
      amem = <<"[0,0]">>,                     %% A氏族成员情况[当前人口数，人口最大容量]	
      bmem = <<"[0,0]">>,                     %% B氏族成员情况[当前人口数，人口最大容量]	
      type = 0,                               %% 申请类型	
      apt = 0,                                %% 申请时间	
      unions = 0                              %% 当前结盟或归附的状态，0：申请中；1，2，3，4：流程中	
    }).	
	
%% vip信息表	
%% vip_info ==> ets_vip 	
-record(ets_vip, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      times = 0,                              %% 次数	
      timestamp = 0                           %% 时间戳	
    }).	
	
%% 玩家帮忙刷新任务的日志记录	
%% log_f5_gwish ==> ets_f5_gwish 	
-record(ets_f5_gwish, {	
      id = 0,                                 %% 自增Id	
      pid = 0,                                %% 玩家Id(被刷的玩家的Id)	
      hpid = 0,                               %% 帮忙刷新的玩家的Id	
      hpname = "",                            %% 帮忙刷新的玩家的名字	
      hluck = 0,                              %% 帮忙刷新的玩家的运势	
      ocolor,                                 %% 被帮忙的玩家原来的任务运势等级，N：N星	
      ncolor = 0,                             %% 被帮忙的玩家新的任务运势等级，N：N星	
      tid = 0,                                %% 任务Id	
      time = 0                                %% 帮忙时间	
    }).	
	
%% 新手礼包表	
%% novice_gift ==> ets_novice_gift 	
-record(ets_novice_gift, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      mark8 = 0,                              %% 领取标记	
      mark14 = 0,                             %% 领取标记	
      mark18 = 0,                             %% 领取标记	
      mark22 = 0,                             %% 领取标记	
      mark26 = 0,                             %% 领取标记	
      mark31 = 0,                             %% 领取标记	
      timestamp = 0                           %% 时间戳	
    }).	
	
%% 灵兽额外配置表	
%% pet_extra ==> ets_pet_extra 	
-record(ets_pet_extra, {	
      id,                                     %% 主键	
      player_id = 0,                          %% 角色id	
      skill_exp = 0,                          %% 技能经验值	
      lucky_value = 0,                        %% 幸运值	
      batt_lucky_value = 0,                   %% 战魂石幸运值	
      auto_step = 0,                          %% 自动萃取灵兽经验阶数	
      free_flush = 0,                         %% 神兽蛋购买面板免费刷新的次数,	
      batt_free_flush = 0,                    %% 战魂石免费刷新次数	
      last_time = 0                           %% 最后更新时间	
    }).	
	
%% 灵兽额外信息随机值表; 	
%% pet_extra_value ==> ets_pet_extra_value 	
-record(ets_pet_extra_value, {	
      id,                                     %% 主键	
      player_id = 0,                          %% 角色id	
      before_value = [],                      %% 批量购买随机生成前值(灵兽或技能经验丹)	
      after_value = [],                       %% 批量购买随机生成后值(灵兽或技能经验丹)	
      before_value1 = [],                     %% 神兽蛋随机生成前值(灵兽或技能经验丹)	
      after_value1 = [],                      %% 神兽蛋随机生成后值(灵兽或技能经验丹)	
      batt_before_value = [],                 %% 战斗技能批量生成前值(技能id)	
      batt_after_value = [],                  %% 战斗技能批量生成后值(技能id)	
      order = 0,                              %% 购买位置(0表示六个1-6表示是其中的第几个值),	
      ct = 0                                  %% 生成随机(灵兽或技能经验丹)时间	
    }).	
	
%% 封神大会积分奖励表	
%% war_award ==> ets_war_award 	
-record(ets_war_award, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      point = 0,                              %% 积分	
      grade = 0,                              %% 级别	
      rank = 0,                               %% 排名	
      newp = 0,                               %% 新积分	
      goods = <<"0">>,                        %% 物品	
      timestamp = 0                           %% 时间戳	
    }).	
	
%% 攻城战信息	
%% castle_rush_info ==> ets_castle_rush_info 	
-record(ets_castle_rush_info, {	
      id,                                     %% 	
      win_guild = 0,                          %% 攻城战获胜的氏族ID	
      last_win_guild = 0,                     %% 上一次攻城战的霸主	
      boss_hp = 0,                            %% 上一次攻城战龙塔得最终血量	
      king = [],                              %% 九霄霸主信息	
      king_id = 0,                            %% 城主ID	
      king_login_time = 0                     %% 城主登陆时间	
    }).	
	
%% 攻城战氏族报名记录	
%% castle_rush_join ==> ets_castle_rush_join 	
-record(ets_castle_rush_join, {	
      id,                                     %% 	
      guild_id = 0,                           %% 氏族ID	
      guild_lv = 0,                           %% 氏族等级	
      guild_num = 0,                          %% 氏族人数	
      guild_name = [],                        %% 氏族名	
      guild_chief = [],                       %% 族长	
      ctime = 0                               %% 记录时间	
    }).	
	
%% 玩家结婚及婚宴的记录表	
%% marry ==> ets_marry 	
-record(ets_marry, {	
      id,                                     %% 自增ID	
      boy_id = 0,                             %% 男方玩家ID	
      girl_id = 0,                            %% 女方玩家ID	
      do_wedding = 0,                         %% 是否已举办婚宴0未举办婚宴,1已举办,	
      marry_time = 0,                         %% 建立夫妻关系的时间	
      rec_gold = 0,                           %% 男方在婚宴中收到的贺礼(元宝)	
      rec_coin = 0,                           %% 男方在婚宴中收到的贺礼(铜币)	
      divorce = 0,                            %% 0在婚1离婚,	
      div_time = 0                            %% 离婚时间	
    }).	
	
%% wedding	
%% wedding ==> ets_wedding 	
-record(ets_wedding, {	
      id,                                     %% 	
      marry_id = 0,                           %% marry表中的自增ID	
      boy_name = "",                          %% 男方姓名	
      girl_name = "",                         %% 女方姓名	
      boy_id = 0,                             %% 男方ID	
      girl_id = 0,                            %% 女方ID	
      boy_invite = [],                        %% 男方邀请的玩家ID	
      girl_invite = [],                       %% 女方邀请的玩家ID	
      wedding_type = 0,                       %% 婚宴类型	
      wedding_num = 0,                        %% 宴婚场次	
      wedding_start = 0,                      %% 宴婚开始时间	
      book_time = 0,                          %% 何时预订	
      gold = 0,                               %% 花费元宝	
      boy_cost = 0,                           %% 男方用于增加喜帖的元宝数	
      girl_cost = 0,                          %% 女方用于增加喜帖的元宝数	
      do_wedding = 0                          %% 是否已举办0未举办,1已举办,	
    }).	
	
%% 情人节表白活动	
%% loveday ==> ets_loveday 	
-record(ets_loveday, {	
      id = 0,                                 %% 自增ID	
      pid = 0,                                %% 表白人ID	
      rid = 0,                                %% 表白对象ID	
      pname = [],                             %% 表白人名字	
      rname = [],                             %% 表白对象名字	
      content = [],                           %% 表白对象	
      votes = 0,                              %% 投票数	
      voters = []                             %% 粉丝们ID	
    }).	
	
%% 氏族联盟表	
%% guild_alliance ==> ets_g_alliance 	
-record(ets_g_alliance, {	
      id,                                     %% 自增Id	
      gid = 0,                                %% 氏族Id	
      bgid = 0,                               %% l联盟氏族的Id	
      bname = "",                             %% 联盟氏族的名字	
      brealm = 0                              %% 联盟的氏族的部落Id	
    }).	
	
%% 氏族联盟申请表	
%% guild_alliance_apply ==> ets_g_alliance_apply 	
-record(ets_g_alliance_apply, {	
      id,                                     %% 自增Id	
      agid = 0,                               %% 申请氏族Id	
      bgid = 0,                               %% 被邀请氏族Id	
      agname = "",                            %% 申请氏族名字	
      bgname = "",                            %% 被邀请氏族名字	
      alv = 0,                                %% 申请氏族等级	
      blv = 0,                                %% 被邀请氏族等级	
      arealm = 0,                             %% 申请氏族所属部落	
      brealm = 0,                             %% 被邀请氏族所属部落	
      amem = <<"[0,0]">>,                     %% 申请氏族成员情况[当前人口数，人口最大容量]	
      bmem = <<"[0,0]">>,                     %% 被邀请氏族成员情况[当前人口数，人口最大容量]	
      acid = 0,                               %% 申请氏族族长Id	
      bcid = 0,                               %% 被邀请氏族族长Id	
      acname = "",                            %% 申请氏族的族长名字	
      bcname = "",                            %% 被邀请氏族族长名字	
      time = 0                                %% 申请时间	
    }).	
	
%% 经验找回	
%% find_exp ==> ets_find_exp 	
-record(ets_find_exp, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      name = <<"0">>,                         %% 任务名	
      task_id = 0,                            %% 任务id	
      type = 0,                               %% 类型	
      timestamp = 0,                          %% 时间	
      times = 0,                              %% 次数	
      lv = 0,                                 %% 等级	
      exp = 0,                                %% 经验	
      spt = 0                                 %% 灵力	
    }).	
	
%% 坐骑	
%% mount ==> ets_mount 	
-record(ets_mount, {	
      id,                                     %% 主键	
      player_id = 0,                          %% 角色id	
      goods_id = 0,                           %% 品物类型id	
      name = "",                              %% 字名	
      level = 1,                              %% 等级	
      exp = 0,                                %% 经验	
      luck_val = 0,                           %% 幸运值	
      close = 0,                              %% 亲密度	
      step,                                   %% 阶数	
      speed = 0,                              %% 速度	
      title = "",                             %% 称号	
      color = 1,                              %% 品质(白1绿2蓝3金4紫5)	
      stren = 0,                              %%  强化等级	
      lp = 0,                                 %% 力魄	
      xp = 0,                                 %% 心魄	
      tp = 0,                                 %% 体魄	
      qp = 0,                                 %% 气魄	
      skill_1 = <<"[1,0,0,0,0,0]">>,          %% 技能[置位Id,类型,等级,品质,经验],	
      skill_2 = <<"[2,0,0,0,0,0]">>,          %% 技能[置位Id,类型,等级,品质,经验],	
      skill_3 = <<"[3,0,0,0,0,0]">>,          %% 技能[置位Id,类型,等级,品质,经验],	
      skill_4 = <<"[4,0,0,0,0,0]">>,          %% 技能[置位Id,类型,等级,品质,经验],	
      skill_5 = <<"[5,0,0,0,0,0]">>,          %% 技能[置位Id,类型,等级,品质,经验],	
      skill_6 = <<"[6,0,0,0,0,0]">>,          %% 技能[置位Id,类型,等级,品质,经验],	
      skill_7 = <<"[7,0,0,0,0,0]">>,          %% 技能[置位Id,类型,等级,品质,经验],	
      skill_8 = <<"[8,0,0,0,0,0]">>,          %% 技能[置位Id,类型,等级,品质,经验],	
      status = 0,                             %%  0休息1出战	
      icon = 0,                               %% 显示图形	
      ct = 0,                                 %% 创建时间	
      mount_val = 0,                          %% 战斗力	
      last_time = 0                           %% 幸运值清0时间	
    }).	
	
%% 坐骑技能经验槽	
%% mount_skill_exp ==> ets_mount_skill_exp 	
-record(ets_mount_skill_exp, {	
      id,                                     %% 主键	
      player_id = 1,                          %% 角色	
      total_exp = 0,                          %% 精魄经验值	
      auto_step = 1,                          %% 自动提取阶数(0不萃取 绿1蓝2,金3,紫4,红5),	
      btn_1 = 1,                              %% 激活按钮1(0未激活1激活)	
      btn_2 = 0,                              %% 激活按钮2(0未激活1激活)	
      btn_3 = 0,                              %% 激活按钮3(0未激活1激活)	
      btn_4 = 0,                              %% 激活按钮4(0未激活1激活)	
      btn_5 = 0,                              %% 激活按钮5(0未激活1激活)	
      btn4_type = 0,                          %% 第四个按钮的激活类型(0为礼券1为元宝)	
      btn5_type = 0,                          %% 第五个按钮的激活类型(0为礼券1为元宝)	
      active_type = []                        %% 坐骑拥有的类型图鉴	
    }).	
	
%% 坐骑技能精魂	
%% mount_skill_split ==> ets_mount_skill_split 	
-record(ets_mount_skill_split, {	
      id,                                     %% 主键	
      player_id = 0,                          %% 角色	
      skill_id = 0,                           %% 技能id	
      exp = 0,                                %% 经验值	
      color = 0,                              %% 颜色(灰0绿1,蓝2,金3,紫4,红5),	
      level = 0,                              %% 等级	
      type = 0                                %% 技能类型(如攻击法力),	
    }).	
	
%% 斗兽信息表	
%% mount_arena ==> ets_mount_arena 	
-record(ets_mount_arena, {	
      id = 0,                                 %% 自增ID	
      player_id = 0,                          %% 玩家ID	
      mount_id = 0,                           %% 坐骑ID	
      rank = 0,                               %% 竞技排行中的名次	
      rank_award = 0,                         %% 结算时的排名	
      player_name = "",                       %% 玩家名字	
      realm = 0,                              %% 玩家部落	
      mount_step = 0,                         %% 坐骑阶数	
      mount_name = "",                        %% 坐骑名字	
      mount_title = "",                       %% 坐骑称号	
      mount_typeid = 0,                       %% 坐骑类型ID	
      mount_color = 0,                        %% 坐骑品质(颜色)	
      mount_level = 1,                        %% 坐骑等级	
      mount_val = 0,                          %% 坐骑战斗力	
      win_times = 0,                          %% 连胜次数	
      get_ward_time = 1,                      %% 领取奖励的时间为0时表示可领取,	
      recent_win = 1                          %% 最后一次竞技的排名情况，1上升，2下降	
    }).	
	
%% 战报表	
%% mount_battle_result ==> ets_battle_result 	
-record(ets_battle_result, {	
      id = 0,                                 %% 自增ID	
      winner = 0,                             %% 胜利者ID	
      losers = 0,                             %% 失败者ID	
      rounds = 0,                             %% 战斗回合数	
      time = 0,                               %% 战斗发生时间	
      a_mount_id = 0,                         %% 坐骑a的ID	
      a_player_name = "",                     %% 坐骑a的玩家名	
      a_mount_name = "",                      %% 坐骑a的名字	
      a_mount_color = 0,                      %% 坐骑a的品质	
      a_mount_type = 0,                       %% A坐骑类型Id	
      b_mount_id = 0,                         %% 坐骑b的ID	
      b_player_name = "",                     %% 坐骑b的玩家名字	
      b_mount_name = "",                      %% 坐骑b的名字	
      b_mount_color = 0,                      %% 坐骑b的品质	
      b_mount_type = 0,                       %% B坐骑类型Id	
      init = "",                              %% 战斗初始信息	
      battle_data = []                        %% 战斗过程详细数据	
    }).	
	
%% 记录单个玩家斗兽近况和当天挑战次数	
%% mount_arena_recent ==> ets_mount_recent 	
-record(ets_mount_recent, {	
      id = 0,                                 %% 自增ID	
      player_id = 0,                          %% 玩家ID	
      cge_times = 0,                          %% 今日挑战次数	
      gold_cge_times = 0,                     %% 今日用元宝挑战的次数	
      last_cge_time = 0,                      %% 最后一次挑战的时间	
      last_cost_time = 0,                     %% 最后一次使用元宝增加挑战次数的时间	
      recent = []                             %% 最近导致排名变动的信息	
    }).	
	
%% 领取斗兽奖励日志表	
%% log_mount_award ==> ets_log_award 	
-record(ets_log_award, {	
      id = 0,                                 %% 自增ID	
      pid = 0,                                %% 玩家ID	
      mid = 0,                                %% 坐骑ID	
      cash = 0,                               %% 领取到的礼券	
      bcoin = 0,                              %% 领取到的绑定铜	
      goods_id = 0,                           %% 领到的物品类型ID	
      num = 0,                                %% 领到的物品个数	
      time = 0                                %% 领取奖励的时间	
    }).	
	
%% 市场求购记录日志表	
%% log_buy_goods ==> log_buy_goods 	
-record(log_buy_goods, {	
      id,                                     %% 自增Id	
      buyid = 0,                              %% 求购记录Id	
      buy_type = 0,                           %% 求购类型1物品；2元宝或者铜币,	
      sid = 0,                                %% 出售者Id	
      sname = "",                             %% 出售者的名字	
      bid = 0,                                %% 求购者Id	
      bname = "",                             %% 求购者名字	
      snum = 0,                               %% 出售者出售的数量	
      unprice = 0,                            %% 出售的单价	
      num = 0,                                %% 当前求购的数量	
      ptype,                                  %% 格价类型，1：元宝，2：铜币	
      goodsid = 0,                            %% 出售的物品类型Id，元宝铜钱为0	
      gid = 0,                                %% 物品Id，当是装备类型物品时，此值不为0	
      f_type = 0,                             %% 志日流向类型：1，求购商家；2求购过期下架；3有人出售；4主动取消求购	
      f_time = 0,                             %% 日志发生时间	
      continue = 0                            %% 求购的持续时间：6小时，12小时，24小时	
    }).	
	
%% 单人镇妖竞技奖励表	
%% td_single_award ==> ets_single_td_award 	
-record(ets_single_td_award, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      order = 0,                              %% 排名	
      lv = 0,                                 %% 等级	
      timestamp = 0                           %% 时间戳	
    }).	
	
%% 竞技场排行	
%% coliseum_rank ==> ets_coliseum_rank 	
-record(ets_coliseum_rank, {	
      id,                                     %% 	
      player_id = 0,                          %% 玩家ID	
      nickname = "",                          %% 玩家名字	
      lv = 0,                                 %% 等级	
      realm = 0,                              %% 部落	
      sex = 0,                                %% 性别	
      career = 0,                             %% 职业	
      battle = 0,                             %% 战斗力	
      win = 0,                                %% 竞技场连胜	
      trend = 0,                              %% 趋势	
      rank = 0,                               %% 排名	
      report = [],                            %% 战报	
      time = 0                                %% 上一次参战的时间	
    }).	
	
%% 竞技场信息	
%% coliseum_info ==> ets_coliseum_info 	
-record(ets_coliseum_info, {	
      id,                                     %% 	
      award_time = 0,                         %% 竞技场奖励结算时间	
      king_id = 0                             %% 竞技场排名第一的玩家ID	
    }).	
	
%% 记录玩家的额外字段数据	
%% player_other ==> ets_player_other 	
-record(ets_player_other, {	
      id,                                     %% 自增id	
      pid = 0,                                %% 玩家id	
      up_t = 0,                               %% buff更新时间同时可以近似表示玩家的下线时间,	
      sex_change_time = 0,                    %% 变性时间	
      ptitles = [],                           %% 玩家当前已获得的普通称号和特殊称号0：能获取；1：领取里并且时限为无穷；N：获取之后的过期时间,	
      ptitle = [],                            %% 玩家当前的称号合集	
      zxt_honor = 0,                          %% 诛仙台荣誉	
      quickbar,                               %% 快捷键	
      coliseum_time = 0,                      %% 竞技场挑战时间	
      coliseum_cold_time = 0,                 %% 竞技场挑战冷却时间	
      coliseum_surplus_time = 0,              %% 竞技场剩余挑战次数	
      coliseum_extra_time = 0,                %% 竞技场额外添加的挑战次数	
      is_avatar = 0,                          %% 竞技场是否使用替身，0否1是	
      coliseum_rank = 0,                      %% 竞技场排行	
      war_honor = <<"[0,0,0,0,0]">>,          %% 封神争霸功勋	
      couple_skill = 0                        %% 夫妻传送技能CD	
    }).	
	
%% 跨服单人竞技记录表	
%% war2_record ==> ets_war2_record 	
-record(ets_war2_record, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      nickname = <<"0">>,                     %% 玩家名字	
      career = 0,                             %% 职业	
      sex = 0,                                %% 性别	
      lv = 0,                                 %% 等级	
      batt_value = 0,                         %% 战斗力	
      platform = <<"0">>,                     %% 平台	
      sn = 0,                                 %% 服务器id	
      seed = 0,                               %% 是否种子选手（0是，1否）	
      grade = 0,                              %% 级别（1天罡，2地煞）	
      subarea = 0,                            %% 分区	
      state = 0,                              %% 状态（1、报名；2、选拔赛；3、32强；4、16强；5、8强；6、4强；7、决赛）	
      wins = 0,                               %% 胜场	
      last_win = 0,                           %% 上一场胜利时间	
      offtrack = 0,                           %% 是否出线(0否1是)	
      timestamp = 0                           %%  报名时间	
    }).	
	
%% 跨服单人淘汰赛记录表	
%% war2_elimination ==> ets_war2_elimination 	
-record(ets_war2_elimination, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      nickname = <<"0">>,                     %% 玩家名字	
      lv = 0,                                 %% 等级	
      career = 0,                             %% 职业	
      sex = 0,                                %% 性别	
      batt_value = 0,                         %% 战力	
      platform = <<"0">>,                     %% 平台	
      sn = 0,                                 %% 服务器id	
      grade = 0,                              %% 分组（1天罡，2地煞）	
      subarea = 0,                            %% 分区（1区左上，2区右上，3区左下，4区右下)	
      num = 0,                                %% 编号（1~8）	
      state = 0,                              %% 状态（1、报名；2、选拔赛；3、32强；4、16强；5、8强；6、4强；7、决赛）	
      wins = 0,                               %% 胜场	
      elimination = 0,                        %% 是否淘汰（0淘汰，1竞技）	
      popular = 0,                            %% 人气值	
      champion = 0                            %% 排名	
    }).	
	
%% 跨服单人竞技历史记录	
%% war2_history ==> ets_war2_history 	
-record(ets_war2_history, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      nickname = <<"0">>,                     %% 玩家名字	
      career = 0,                             %% 职业	
      sex = 0,                                %% 性别	
      type = 0,                               %% 类型（1个人，2冠军）	
      grade = 0,                              %% 分组（1天罡，2地煞）	
      platform = <<"0">>,                     %% 平台	
      sn = 0,                                 %% 服务器id	
      enemy = <<"0">>,                        %% 对手	
      state = 0,                              %% 场次	
      result = <<"0">>,                       %% 比分	
      times = 0,                              %% 届次	
      timestamp = 0                           %% 时间戳	
    }).	
	
%% 跨服单人竞技下注表	
%% war2_bet ==> ets_war2_bet 	
-record(ets_war2_bet, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      name = <<"0">>,                         %% 玩家名	
      type = 0,                               %% 金钱类型	
      total = 0,                              %% 金钱数目	
      state = 0,                              %% 场次	
      nickname = 0,                           %% 被下注对象的名字	
      bet_id = 0,                             %% 被下注对象的id	
      grade = 1,                              %% 被下注对象级别	
      platform = <<"0">>,                     %% 平台	
      sn = 0                                  %% 服务器	
    }).	
	
%% 封神纪元信息	
%% fs_era ==> ets_fs_era 	
-record(ets_fs_era, {	
      player_id = 0,                          %% 玩家id	
      attack = 0,                             %% 击攻	
      hp = 0,                                 %% 气血	
      mp = 0,                                 %% 法力	
      def = 0,                                %% 防御	
      anti_all = 0,                           %% 全抗	
      lv_info = "",                           %% 关卡信息	
      prize = ""                              %% 通关奖励信息	
    }).	
	
%% 跨服战报	
%% war2_pape ==> ets_war2_pape 	
-record(ets_war2_pape, {	
      id,                                     %% 	
      grade = 0,                              %% 级别	
      state = 0,                              %% 进度	
      pid_a = 0,                              %% 玩家aid	
      pid_b = 0,                              %% 玩家bid	
      round = 0,                              %% 轮次	
      winner = <<"0">>                        %% 胜者	
    }).	
	
%% 新玩家目标	
%% target ==> ets_target 	
-record(ets_target, {	
      id,                                     %% 	
      pid = 0,                                %% 玩家id	
      a_pet = 0,                              %% 拥有一个灵兽	
      out_mount = 0,                          %% 坐骑出战	
      meridian_uplv = 0,                      %% 修炼经脉	
      master = 0,                             %% 拜师或者收徒	
      lv_20 = 0,                              %% 等级20	
      friend = 0,                             %% 添加好友	
      lv_30 = 0,                              %% 等级30	
      dungeon_25 = 0,                         %% 通关25副本	
      pet_lv_5 = 0,                           %% 灵兽等级5	
      battle_value_850 = 0,                   %% 战力850	
      arena = 0,                              %% 参加战场	
      mount_step_2 = 0,                       %% 2介坐骑	
      dungeon_35 = 0,                         %% 通关35	
      mount_3 = 0,                            %% 坐骑强化3	
      lg20_one = 0,                           %% 经脉灵根20	
      pet_lv_15 = 0,                          %% 灵兽等级15	
      fst_6 = 0,                              %% 封神台通关6	
      td_20 = 0,                              %% 镇妖台20波	
      deputy_klj = 0,                         %% 神器提升到镜子	
      mount_gold = 0,                         %% 金色品质的坐骑	
      pet_a35_g30 = 0,                        %% 灵兽资质35成长30	
      dungeon_45 = 0,                         %% 通关河神殿	
      fst_14 = 0,                             %% 封神台通关14	
      deputy_green = 0,                       %% 神器提升到绿色	
      step_5 = 0,                             %% 全身装备+5	
      qi_lv4_lg40 = 0,                        %% 奇脉经脉等级4，灵根40	
      weapon_7 = 0,                           %% 法宝+7	
      dungeon_55 = 0,                         %% 通关55副本	
      zxt_14 = 0,                             %% 诛仙台14层	
      td_70 = 0,                              %% 镇妖70波	
      pet_a45_g40 = 0,                        %% 灵兽资质45成长40	
      mount_step_3 = 0,                       %% 坐骑3介	
      deputy_nws = 0,                         %% 神器女娲石	
      lg_50_all = 0,                          %% 全身经脉灵根50以上	
      step_7 = 0,                             %% 全身+7	
      deputy_snd = 0,                         %% 神器神农鼎	
      pet_a55_g50 = 0,                        %% 灵兽资质55，成长50	
      zxt_20 = 0,                             %% 诛仙台20层	
      battle_value_15000 = 0,                 %% 战力1W8	
      mount_step_4 = 0                        %% 4介坐骑	
    }).	
