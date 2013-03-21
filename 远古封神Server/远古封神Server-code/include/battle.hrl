%% 战斗

%% 战斗所需的属性
-record(battle_state, {
    id,
    name = [],
    scene,                      %% 所属场景
    lv, 
    career = 0,
    hp, 
    hp_lim,
    mp, 
    mp_lim, 
    att_max,
    att_min,
    def,                        %% 防御值
    x,                          %% 默认出生X
    y,                          %% 默认出生y
    att_area,                   %% 攻击范围  
    pid = undefined,            %% 玩家进程
    battle_status = [],         %% BUFF效果
    sign = 0,                   %% 标示是怪还是人 1:怪， 2：人
    hit = 0,
    dodge = 0,
    crit = 0,
    hurt_add = 0,               %% 附加加伤害
    pk_mode = 0,
    realm = 0,
    guild_id = 0,
	type = 0,
    pid_team = undefined,
    status = 0,                  %% 状态 
    evil = 0,
	realm_honor = 0,				%% 部落荣誉 
	leader = 0,
	relation = [],
	goods_buf_cd = [],				% 物品buf对应的冷却时间
	deputy_skill = [], 				%神器技能
	deputy_passive_skill = [], 		%神器被动技能
	deputy_prof_lv = 0,				%神器技能熟练度
	g_alliance = []					%% 联盟中的氏族Id		 
}).