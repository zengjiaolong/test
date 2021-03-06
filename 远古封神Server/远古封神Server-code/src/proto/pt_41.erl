%%%--------------------------------------
%%% @Module  : pt_41
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 灵兽消息的解包和组包
%%%--------------------------------------
-module(pt_41).
-include("common.hrl").
-include("record.hrl").
-export([read/2, write/2]).
-export([pack_pet_skill/1]).


%%%=========================================================================
%%% 解包函数
%%%=========================================================================

%% -----------------------------------------------------------------
%% 灵兽生成
%% -----------------------------------------------------------------
read(41001, <<Goods_Id:32, Rune_Id:32>>) ->
    {ok, [Goods_Id, Rune_Id]};

%% -----------------------------------------------------------------
%% 灵兽放生
%% -----------------------------------------------------------------
read(41002, <<PetId:32>>) ->
    {ok, [PetId]};

%% -----------------------------------------------------------------
%% 灵兽改名
%% -----------------------------------------------------------------
read(41003, <<PetId:32, Bin/binary>>) ->
    {PetName, _} = pt:read_string(Bin),
    {ok, [PetId, PetName]};

%% -----------------------------------------------------------------
%% 灵兽状态切换
%% -----------------------------------------------------------------
read(41004, <<PetId:32,Status:16>>) ->
    {ok, [PetId,Status]};

%% -----------------------------------------------------------------
%% 资质提升,Auto_purch是否自动购买灵兽资质符(1自动购买，0不自动购买)
%% -----------------------------------------------------------------
read(41005,<<PetId:32,Apt_type:32,P_type:32,Auto_purch:8>>) ->
	{ok,[PetId,Apt_type,P_type,Auto_purch]};

%% -----------------------------------------------------------------
%% 灵兽喂养
%% -----------------------------------------------------------------
read(41006, <<PetId:32, Food_type:32, GoodsNum:16 >>) ->
    {ok, [PetId, Food_type, GoodsNum]};


%% -----------------------------------------------------------------
%% 获取灵兽信息
%% -----------------------------------------------------------------
read(41007, <<PetId:32>>) ->
    {ok, [PetId]};

%% -----------------------------------------------------------------
%% 获取灵兽列表
%% -----------------------------------------------------------------
read(41008, <<PlayerId:32>>) ->
    {ok, [PlayerId]};

%% -----------------------------------------------------------------
%% 灵兽加点
%% -----------------------------------------------------------------
read(41009,<<PetId:32,Forza:32,Agile:32,Wit:32,Physique:32>>) ->
	{ok,[PetId,Forza,Agile,Wit,Physique]};


%% ----------------------------------------------------------------
%% 取快乐值和经验值
%% ----------------------------------------------------------------
read(41010,<<PetId:32>>) ->
	{ok,[PetId]};

%% -----------------------------------------------------------------
%% 灵兽秘笈升级
%% -----------------------------------------------------------------
read(41011,<<PetId:32,Goods_id:32>>) ->
	{ok,[PetId,Goods_id]};

%% -----------------------------------------------------------------
%% 灵兽道具查询
%% -----------------------------------------------------------------
read(41012,<<Goods_id:32>>) ->
	{ok,[Goods_id]};
 
%% -----------------------------------------------------------------
%% 灵兽洗点
%% -----------------------------------------------------------------
read(41013,<<PetId:32>>) ->
	{ok,[PetId]};

%% -----------------------------------------------------------------
%% 灵兽技能遗忘
%% -----------------------------------------------------------------
read(41014,<<PetId:32,Position:16>>) ->
	{ok,[PetId,Position]};

%% -----------------------------------------------------------------
%% 成长值提升,Auto_purch是否自动购买灵兽资质符(1自动购买，0不自动购买)
%% -----------------------------------------------------------------
read(41015,<<PetId:32,Grow_type:32,P_type:32,Auto_purch:8>>) ->
	{ok,[PetId,Grow_type,P_type,0,Auto_purch]};

%% -----------------------------------------------------------------
%% 开始灵兽训练
%% -----------------------------------------------------------------
read(41016,<<PetId:32,GoodsNum:16,MoneyType:8,Auto:8>>)->
	{ok,[PetId,GoodsNum,MoneyType,Auto]};

%% -----------------------------------------------------------------
%% 停止灵兽训练
%% -----------------------------------------------------------------
read(41017,<<PetId:32>>)->
	{ok,[PetId]};

%% -----------------------------------------------------------------
%% 判断灵兽是否可以化形
%% add by zkj
%% -----------------------------------------------------------------
read(41018,<<PetId:32>>)->
	{ok,[PetId]};

%% -----------------------------------------------------------------
%% 灵兽化形
%% add by zkj
%% -----------------------------------------------------------------
read(41019,<<PetId:32>>)->
	{ok,[PetId]};

%% -----------------------------------------------------------------
%% 购买化形果实
%% add by zkj
%% -----------------------------------------------------------------
read(41020,_r)->
	{ok,[_r]};

%% -----------------------------------------------------------------
%% 灵兽融合
%% add by zkj
%% -----------------------------------------------------------------
read(41021,<<PetId1:32, PetId2:32>>)->
	{ok,[PetId1, PetId2]};

%% -----------------------------------------------------------------
%% 灵兽融合预览
%% add by zkj
%% -----------------------------------------------------------------
read(41022,<<PetId1:32, PetId2:32>>)->
	{ok,[PetId1, PetId2]};

%% -----------------------------------------------------------------
%% 获取某个玩家的灵兽信息
%% -----------------------------------------------------------------
read(41023,<<PetId:32>>) ->
	{ok,[PetId]};

%% -----------------------------------------------------------------
%% 灵兽信息技能分离
%% -----------------------------------------------------------------
read(41024,<<PetId:32>>) ->
	{ok,[PetId]};

%% -----------------------------------------------------------------
%% 灵兽信息技能列表
%% -----------------------------------------------------------------
read(41025,_) ->
	{ok,[]};


%% -----------------------------------------------------------------
%% 灵兽一键合成所有闲置技能
%% -----------------------------------------------------------------
read(41026,_) ->
	{ok,[]};


%%技能合成或升级,分离
read(41027,<<PetId:32,Type:8,Oper:8,Bin/binary>>) ->
	{Skill1,Bin1} = pt:read_string(Bin),
	{Skill2, _} = pt:read_string(Bin1),
	NewSkill1 = tool:to_binary(Skill1),
	NewSkill2 = tool:to_binary(Skill2),
    {ok,[PetId,Type,Oper,NewSkill1,NewSkill2]};

%% -----------------------------------------------------------------
%% 灵兽购买面板
%% -----------------------------------------------------------------
read(41029,_) ->
	{ok,[]};

%% -----------------------------------------------------------------
%% 灵兽购买面板刷新
%% -----------------------------------------------------------------
read(41030,_) ->
	{ok,[]};


%% -----------------------------------------------------------------
%% 灵兽批量操作type 1为技能批量分离，2为灵兽放生
%% -----------------------------------------------------------------
read(41031,<<Type:8>>) ->
	{ok,[Type]};

%% ----------------------------------------------------------------
%% 出战灵兽技能经验自动增长
%% ----------------------------------------------------------------
read(41032,<<PetId:32>>) ->
	{ok,[PetId]};

%% ----------------------------------------------------------------
%% 设置灵兽自动萃取的阶数
%% ----------------------------------------------------------------
read(41034,<<Auto_Step:8>>) ->
	{ok,[Auto_Step]};


%% ----------------------------------------------------------------
%% 随机批量购买面板列表
%% ----------------------------------------------------------------
read(41035,_) ->
	{ok,[]};

%% ----------------------------------------------------------------
%% 随机批量购买面板购买动作Order为顺序号，为0是购买所有,单个购买顺序号1-6
%% ----------------------------------------------------------------
read(41036,<<Order:8>>) ->
	{ok,[Order]};

%% ----------------------------------------------------------------
%% 查询玩家的幸运值和经验槽经验值
%% ----------------------------------------------------------------
read(41037,_) ->
	{ok,[]};

%% ----------------------------------------------------------------
%% 通过经验槽经验值提升技能等级
%% ----------------------------------------------------------------
read(41039,<<PetId:32,Bin/binary>>) ->
	{Skill1,_Bin1} = pt:read_string(Bin),
	NewSkill1 = tool:to_binary(Skill1),
    {ok,[PetId,NewSkill1]};

%% ----------------------------------------------------------------
%% 灵兽一键萃取所有闲置技能
%% ----------------------------------------------------------------
read(41040,_) ->
	{ok,[]};

%% ----------------------------------------------------------------
%% 灵兽化形类型id
%% ----------------------------------------------------------------
read(41041,<<PetTypeId:32>>) ->
	{ok,[PetTypeId]};


%% -----------------------------------------------------------------
%% 灵兽神兽蛋预览
%% -----------------------------------------------------------------
read(41042,_) ->
	{ok,[]};
 
%% -----------------------------------------------------------------
%% Type 1神兽蛋获取技能,2神兽蛋萃取经验
%% -----------------------------------------------------------------
read(41043,<<Type:8>>) ->
	{ok,[Type]};

%% -----------------------------------------------------------------
%% 1神兽蛋面板免费刷新,2批量购买面板免费刷新,2批量购买面板批量元宝刷新
%% -----------------------------------------------------------------
read(41044,<<Type:8,Order:8>>) ->
	{ok,[Type,Order]};

%% -----------------------------------------------------------------
%%战魂石预览
%% -----------------------------------------------------------------
read(41046,<<Gid:32>>) ->
	{ok,[Gid]};
 
%% ----------------------------------------------------------------
%%查看战斗技能批量刷新面板	
%% ----------------------------------------------------------------
read(41047,<<Gid:32>>) ->
	{ok,[Gid]};

%% ----------------------------------------------------------------
%%战斗技能刷新Type 1为战魂石免费刷新　2为战魂石元宝刷新　3为战魂石批量刷新
%% ----------------------------------------------------------------
read(41048,<<Gid:32,Type:8>>) ->
	{ok,[Gid,Type]};

%% ----------------------------------------------------------------
%%战斗技能取技能 Order 0为忆魂石页面,1-12为战斗技能批量刷新面板)
%% ----------------------------------------------------------------
read(41049,<<Gid:32,Order:8>>) ->
	{ok,[Gid,Order]};

%% ----------------------------------------------------------------
%%战斗技能书 %%战斗技能 Type 1技能书学习 2删除技能书
%% ----------------------------------------------------------------
read(41050,<<PetId:32,Gid:32,Type:8>>) ->
	{ok,[Gid,PetId,Type]};

%% ----------------------------------------------------------------
%%战斗技能遗忘
%% ----------------------------------------------------------------
read(41051,<<PetId:32,SkillId:32>>) ->
	{ok,[PetId,SkillId]};

%% ----------------------------------------------------------------
%%战斗技能封印
%% ----------------------------------------------------------------
read(41052,<<PetId:32,SkillId:32>>) ->
	{ok,[PetId,SkillId]};


%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
read(_Cmd, _R) ->
    {error, no_match}.


%%%=========================================================================
%%% 组包函数
%%%=========================================================================

%% -----------------------------------------------------------------
%% 灵兽通知
%% -----------------------------------------------------------------
write(41000, [MsgType]) ->
    Data = <<MsgType:16>>,
    {ok, pt:pack(41000, Data)};

%% -----------------------------------------------------------------
%% 灵兽生成
%% -----------------------------------------------------------------
write(41001, [Code, Coin, Bcoin, PetId, GoodsTypeId, PetName]) ->
	NameBin=tool:to_binary(PetName),
    PetNameLen = byte_size(NameBin),
    Data = <<Code:16, Coin:32, Bcoin:32, PetId:32, GoodsTypeId:32, PetNameLen:16, NameBin/binary>>,
    {ok, pt:pack(41001, Data)};

%% -----------------------------------------------------------------
%% 灵兽放生
%% -----------------------------------------------------------------
write(41002, [Code, PetId]) ->
    Data = <<Code:16, PetId:32>>,
    {ok, pt:pack(41002, Data)};

%% -----------------------------------------------------------------
%% 灵兽改名
%% -----------------------------------------------------------------
write(41003, [Code,PetId,PetName]) ->
	BinName = tool:to_binary(PetName),
	Len = byte_size(BinName),
    Data = <<Code:16,PetId:32,Len:16,BinName/binary>>,
    {ok, pt:pack(41003, Data)};

%% -----------------------------------------------------------------
%% 灵兽状态切换
%% -----------------------------------------------------------------
write(41004, [Code,PetId,Status]) ->
    Data = <<Code:16,PetId:32,Status:16>>,
    {ok, pt:pack(41004, Data)};

%% -----------------------------------------------------------------
%% 资质提升
%% -----------------------------------------------------------------
write(41005,[Code,PetId,Aptitude,Rest_Apt,Rest_P,RP,Coin]) ->
	Data = <<Code:16,PetId:32,Aptitude:32,Rest_Apt:32,Rest_P:32,RP:16,Coin:32>>,
	{ok,pt:pack(41005,Data)};

%% -----------------------------------------------------------------
%% 灵兽喂养
%% -----------------------------------------------------------------
write(41006, [Code, PetId, Happy,RestNum]) ->
    Data = <<Code:16, PetId:32, Happy:32,RestNum:32>>,
    {ok, pt:pack(41006, Data)};


%% -----------------------------------------------------------------
%% 获取灵兽信息
%% -----------------------------------------------------------------
write(41007, [Status,Pet]) ->
	NowTime = util:unixtime(),
	Bin = parse_pet_info(Status,NowTime,Pet),
	Bin2= <<1:16,Bin/binary>>,
    {ok, pt:pack(41007, Bin2)};

%% -----------------------------------------------------------------
%% 获取灵兽列表
%% -----------------------------------------------------------------
write(41008, [Res,Status,PetRecordList]) ->
	ListNum = length(PetRecordList),
	NowTime = util:unixtime(),
	ListBin = tool:to_binary(lists:map(fun(Pet)-> parse_pet_info(Status,NowTime,Pet) end,PetRecordList)),
    Data = <<Res:16, ListNum:16, ListBin/binary>>,
    {ok, pt:pack(41008, Data)};

%% -----------------------------------------------------------------
%% 灵兽属性加点
%% -----------------------------------------------------------------
write(41009,[Code,PetId,Forza,Agile,Wit,Physique,Point,Pet_hp,Pet_att,Pet_hit,Pet_mp]) ->
	Data = <<Code:16,PetId:32,Forza:32,Agile:32,Wit:32,Physique:32,Point:32,Pet_hp:32,Pet_att:32,Pet_hit:32,Pet_mp:32>>,
   	{ok, pt:pack(41009, Data)};

%% -----------------------------------------------------------------
%% 返回快乐值和经验值
%% -----------------------------------------------------------------
write(41010,[Code,PetId,Happy,Exp,Level,MaxExp,Name,Goods_id,Pet]) ->
	BinName = tool:to_binary(Name),
	Len = byte_size(BinName),
	[Skill,BattSkill] = 
		case Pet of
			[] -> [pack_pet_skill([]),pack_pet_batt_skill([])];
			_ -> [pack_pet_skill(Pet),pack_pet_batt_skill(Pet)]
		end,
	Data = <<Code:16,PetId:32,Happy:32,Exp:32,Level:32,MaxExp:32,Len:16,BinName/binary,Goods_id:32,Skill/binary,BattSkill/binary>>,
	{ok,pt:pack(41010,Data)};

%% ----------------------------------------------------------------
%% 灵兽秘籍升级
%% ----------------------------------------------------------------
write(41011,[Code,PetId,Level,Happy,Exp,MaxExp,Point]) ->
	Data = <<Code:16,PetId:32,Level:32,Happy:32,Exp:32,MaxExp:32,Point:32>>,
	{ok,pt:pack(41011,Data)};

%% -----------------------------------------------------------------
%% 灵兽道具查询
%% -----------------------------------------------------------------
write(41012,[Code,Goods_id,Num]) ->
	Data = <<Code:16,Goods_id:32,Num:32>>,
	{ok,pt:pack(41012,Data)};

%% -----------------------------------------------------------------
%% 灵兽洗点
%% -----------------------------------------------------------------
write(41013,[Result,PetId,Point]) ->
	Data= <<Result:16,PetId:32,Point:16>>,
	{ok,pt:pack(41013,Data)};

%% -----------------------------------------------------------------
%% 灵兽技能遗忘
%% -----------------------------------------------------------------
write(41014,[Result])->
	{ok,pt:pack(41014,<<Result:16>>)};

%% -----------------------------------------------------------------
%% 成长值提升
%% -----------------------------------------------------------------
write(41015,[Code,PetId,Grow,Rest_Grow,Rest_P,Point]) ->
	Data = <<Code:16,PetId:32,Grow:32,Rest_Grow:32,Rest_P:32,Point:32>>,
	{ok,pt:pack(41015,Data)};

%% -----------------------------------------------------------------
%% 开始灵兽训练
%% -----------------------------------------------------------------
write(41016,[Result,PetId,Status])->
	Data = <<Result:16,PetId:32,Status:8>>,
	{ok,pt:pack(41016,Data)};

%% -----------------------------------------------------------------
%% 结束灵兽训练
%% -----------------------------------------------------------------
write(41017,[Result,PetId,Status,GoodsId,Num,MoneyType,Money])->
	Data = <<Result:16,PetId:32,Status:8,GoodsId:32,Num:16,MoneyType:16,Money:32>>,
	{ok,pt:pack(41017,Data)};

%% -----------------------------------------------------------------
%% 判断灵兽是否可以化形
%% -----------------------------------------------------------------
write(41018,[Result])->
	{ok,pt:pack(41018,<<Result:16>>)};

%% -----------------------------------------------------------------
%% 灵兽化形
%% -----------------------------------------------------------------
write(41019,[Result])->
	{ok,pt:pack(41019,<<Result:16>>)};

%% -----------------------------------------------------------------
%% 购买化形果实
%% -----------------------------------------------------------------
write(41020,Result)->
	{ok,pt:pack(41020,<<Result:16>>)};

%% -----------------------------------------------------------------
%% 灵兽融合
%% -----------------------------------------------------------------
write(41021,Result)->
	[Code, Petid] = Result,
	{ok,pt:pack(41021,<<Code:16, Petid:32>>)};

%% -----------------------------------------------------------------
%% 灵兽融合预览
%% -----------------------------------------------------------------
write(41022,Result)->
	[Code, Petid,Player_id,Goods_id,Name,Rename_count, 
						   Level,Exp,Exp_limit,Happy,Point, 
						   Forza,Wit,Agile,Physique,Aptitude, 
						   Grow,Status,Pet,Time,R,C,TrainTime,Chenge] = Result,
	[Skill,BattSkill] = 
		case Pet of
			[] -> [pack_pet_skill([]),pack_pet_batt_skill([])];
			_ -> [pack_pet_skill(Pet),pack_pet_batt_skill(Pet)]
		end,
	Name_len = byte_size(Name),
	{ok,pt:pack(41022,<<Code:16, Petid:32,Player_id:32,Goods_id:32,Name_len:16,Name/binary,Rename_count:16, 
						   Level:16,Exp:32,Exp_limit:32,Happy:32,Point:16, 
						   Forza:32,Wit:32,Agile:32,Physique:32,Aptitude:32, 
						   Grow:32,Status:16,Skill/binary,Time:32,R:16,C:32,TrainTime:32,Chenge:32,BattSkill/binary>>)};


%% -----------------------------------------------------------------
%% 获取某个玩家的灵兽信息
%% -----------------------------------------------------------------
write(41023,[Result])->
	[Success, Goods_id, Name, Level, Point, Forza, Wit, Agile, Physique, Aptitude, Grow, Pet, Chenge] = Result,
	[Skill,BattSkill] = 
		case Pet of
			[] -> [pack_pet_skill([]),pack_pet_batt_skill([])];
			_ -> [pack_pet_skill(Pet),pack_pet_batt_skill(Pet)]
		end,
	Name_len = byte_size(Name),
	{ok,pt:pack(41023,<<Success:16, Goods_id:32, Name_len:16,Name/binary, Level:16, Point:16, Forza:32, Wit:32, Agile:32, Physique:32, Aptitude:32, Grow:32, Skill/binary, Chenge:32,BattSkill/binary>>)};


%% -----------------------------------------------------------------
%% 灵兽技能分离
%% -----------------------------------------------------------------
write(41024,Result)->
	{ok,pt:pack(41024,<<Result:8>>)};

%% -----------------------------------------------------------------
%% 分离技能列表
%% -----------------------------------------------------------------
write(41025,Result)->
	case Result of
			[] -> 
				Data = <<0:16, <<>>/binary>>;
			_ ->
				Len = length(Result),
				F = fun(Ets_pet_split_skill) ->
							[SkillId, SkillLevel, SkillStep, SkillExp] = util:string_to_term(tool:to_list(Ets_pet_split_skill#ets_pet_split_skill.pet_skill)),
							NextSkillExp = data_pet:get_pet_skill_exp(SkillLevel+1, SkillStep),
							[Skill_Value,Skill_Fix_Value] = data_pet:get_skill_value(Ets_pet_split_skill#ets_pet_split_skill.pet_skill),
							<<SkillId:32, SkillLevel:8, SkillStep:8,SkillExp:32,NextSkillExp:32,Skill_Value:32,Skill_Fix_Value:32>>
					end,
				RB = tool:to_binary([F(Ets_pet_split_skill) || Ets_pet_split_skill <- Result]),
				Data = <<Len:16, RB/binary>>
	end,
	{ok,pt:pack(41025,Data)};


%% -----------------------------------------------------------------
%% 灵兽一键合成所有闲置技能
%% -----------------------------------------------------------------
write(41026,Result)->
	{ok,pt:pack(41026,<<Result:8>>)};
	
%% -----------------------------------------------------------------
%% 技能合成或升级,分离
%% -----------------------------------------------------------------
write(41027,[Code,Desc])->
	BinDesc = tool:to_binary(Desc),
	BinDesc_len = byte_size(BinDesc),
	{ok,pt:pack(41027,<<Code:8,BinDesc_len:16,BinDesc/binary>>)};
	

%% -----------------------------------------------------------------
%% 灵兽购买面板
%% -----------------------------------------------------------------
write(41029,Result)->
	case Result of
			[] -> 
				Data = <<0:16, <<>>/binary, 0:32>>;
			_ ->
				Now = util:unixtime(),
				Len = length(Result),
				[_,Ct] = lists:nth(1, Result),
				F = fun(Goods_id) ->
							<<Goods_id:32>>
					end,
				RB = tool:to_binary([F(Goods_id) || [Goods_id,_] <- Result]),
				%%48小时倒计时
				Data = <<Len:16, RB/binary, (48*60*60-(Now-Ct)):32>>
	end,
	{ok,pt:pack(41029,Data)};

%% -----------------------------------------------------------------
%% 灵兽购买面板刷新
%% -----------------------------------------------------------------
write(41030,[Code,Gold]) ->
	{ok,pt:pack(41030,<<Code:8,Gold:32>>)};

%% -----------------------------------------------------------------
%%灵兽批量操作type 1为技能批量分离，2为灵兽放生
%% -----------------------------------------------------------------
write(41031,Code) ->
	{ok,pt:pack(41031,<<Code:8>>)};

%% -----------------------------------------------------------------
%%黄金蛋使用后产生新灵兽效果
%% -----------------------------------------------------------------
write(41033,PetTypeId) ->
	{ok,pt:pack(41033,<<PetTypeId:32>>)};

%% -----------------------------------------------------------------
%%设置灵兽自动萃取的阶数
%% -----------------------------------------------------------------
write(41034,Code) ->
	{ok,pt:pack(41034,<<Code:8>>)};

%% -----------------------------------------------------------------
%% 灵兽购买面板
%% -----------------------------------------------------------------
write(41035,[Result,FreeFlushTimes,TotalFreeFlushTimes])->
	Len = length(Result),
	F = fun(PetTypeId,Skill_Id,Num) ->
				<<PetTypeId:32,Skill_Id:32,Num:32>>
		end,
	RB = tool:to_binary([F(PetTypeId,Skill_Id,Num) || [PetTypeId,Skill_Id,Num] <- Result]),
	Data = <<FreeFlushTimes:8,TotalFreeFlushTimes:8,Len:16, RB/binary>>,
	{ok,pt:pack(41035,Data)};

%% -----------------------------------------------------------------
%%随机批量购买面板购买动作Order为顺序号，为0是购买所有,单个购买顺序号1-6
%% -----------------------------------------------------------------
write(41036,Code) ->
	{ok,pt:pack(41036,<<Code:8>>)};

%% -----------------------------------------------------------------
%%查询玩家的幸运值和经验槽经验值
%% -----------------------------------------------------------------
write(41037,[Lucky_Value,Skill_Exp,Auto_step]) ->
	{ok,pt:pack(41037,<<Lucky_Value:32,Skill_Exp:32,Auto_step:8>>)};

%% -----------------------------------------------------------------
%%查询玩家的幸运值和经验槽经验值
%% -----------------------------------------------------------------
write(41038,[Lucky_Value,Skill_Exp]) ->
	{ok,pt:pack(41038,<<Lucky_Value:32,Skill_Exp:32>>)};

%% -----------------------------------------------------------------
%%通过经验槽经验值提升技能等级
%% -----------------------------------------------------------------
write(41039,Code) ->
	{ok,pt:pack(41039,<<Code:8>>)};

%% ----------------------------------------------------------------
%% 灵兽一键萃取所有闲置技能
%% ----------------------------------------------------------------
write(41040,Code) ->
	{ok,pt:pack(41040,<<Code:8>>)};

%% ----------------------------------------------------------------
%% 灵兽化形类型id
%% ----------------------------------------------------------------
write(41041,PetTypeId) ->
	{ok,pt:pack(41041,<<PetTypeId:32>>)};


%% -----------------------------------------------------------------
%% 灵兽神兽蛋预览
%% -----------------------------------------------------------------
write(41042,[Lucky_value,Skill_Id,Step,Free_flush2,FREE_FLUSE_TIMES]) ->
	{ok,pt:pack(41042,<<Lucky_value:32,Skill_Id:32,Step:8,Free_flush2:8,FREE_FLUSE_TIMES:8>>)};

%% -----------------------------------------------------------------
%% %% Type 1神兽蛋获取技能,2神兽蛋萃取经验
%% -----------------------------------------------------------------
write(41043,[Code,Lucky_value,Skill_Id,Step,Free_flush2,FREE_FLUSE_TIMES]) ->
	{ok,pt:pack(41043,<<Code:8,Lucky_value:32,Skill_Id:32,Step:8,Free_flush2:8,FREE_FLUSE_TIMES:8>>)};
 
%% -----------------------------------------------------------------
%% 1神兽蛋面板免费刷新,2批量购买面板免费刷新
%% -----------------------------------------------------------------
write(41044,Code) ->
	{ok,pt:pack(41044,<<Code:8>>)};


%% -----------------------------------------------------------------
%% 灵兽训练完成通知客户端
%% -----------------------------------------------------------------
write(41045,PetId) ->
	{ok,pt:pack(41045,<<PetId:32>>)};

%% -----------------------------------------------------------------
%% 灵兽神兽蛋预览
%% -----------------------------------------------------------------
write(41046,[Result,Lucky_value,Skill_Id,Free_flush]) ->
	{ok,pt:pack(41046,<<Result:8,Lucky_value:32,Skill_Id:32,Free_flush:8>>)};

%% -----------------------------------------------------------------
%%查看战斗技能批量刷新面板	
%% -----------------------------------------------------------------
write(41047,[Code,Batt_lucky_value,Result])->
	Len = length(Result),
	F = fun(Skill_Id) ->
				<<Skill_Id:32>>
		end,
	RB = tool:to_binary([F(Skill_Id) || [Skill_Id] <- Result]),
	Data = <<Code:8,Batt_lucky_value:32,Len:16, RB/binary>>,
	{ok,pt:pack(41047,Data)};

%% -----------------------------------------------------------------
%% 战斗技能刷新
%% -----------------------------------------------------------------
write(41048,Data) ->
	[Code,Type,Batt_lucky_value,Batt_free_flush,AfterValueList]  = Data,
	Len = length(AfterValueList),
	F = fun(Skill_Id) ->
				<<Skill_Id:32>>
		end,
	RB = tool:to_binary([F(Skill_Id) || [Skill_Id] <- AfterValueList]),
	{ok,pt:pack(41048,<<Code:8,Type:8,Batt_lucky_value:32,Batt_free_flush:8,Len:16, RB/binary>>)};


%% -----------------------------------------------------------------
%% 战斗技能取技能
%% -----------------------------------------------------------------
write(41049,Code) ->
	{ok,pt:pack(41049,<<Code:8>>)};

%% ----------------------------------------------------------------
%%战斗技能 Type 1技能书学习 2删除技能书
%% ----------------------------------------------------------------
write(41050,Code) ->
	{ok,pt:pack(41050,<<Code:8>>)};


%% ----------------------------------------------------------------
%%战斗技能遗忘
%% ----------------------------------------------------------------
write(41051,Code) ->
	{ok,pt:pack(41051,<<Code:8>>)};

%% ----------------------------------------------------------------
%%战斗技能封印
%% ----------------------------------------------------------------
write(41052,Code) ->
	{ok,pt:pack(41052,<<Code:8>>)};

%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.

parse_pet_info(PlayerStatus,NowTime,Pet1) ->
	if
		is_record(Pet1,ets_pet) ->
			{ok,Pet} = lib_pet:lib_train_finish(PlayerStatus,PlayerStatus#player.other#player_other.pid_send,PlayerStatus#player.other#player_other.pid_goods,Pet1),
			[R1,C]= data_pet:get_upgrade_aptitude(Pet#ets_pet.aptitude),
			{_NewPlayerStatus,_,VipAward} = lib_vip:get_vip_award(pet,PlayerStatus),
			R= round(R1 + VipAward*100),
			E = data_pet:get_upgrade_exp(Pet#ets_pet.level), 
			Pet_id= Pet#ets_pet.id,
			Player_id = Pet#ets_pet.player_id,
			Goods_id = Pet#ets_pet.goods_id,
			Name = tool:to_binary(Pet#ets_pet.name),
			Rename_count = Pet#ets_pet.rename_count,
			Level = Pet#ets_pet.level,
			Exp = Pet#ets_pet.exp,
			Exp_limit =  E,
			Happy = Pet#ets_pet.happy,
			Point = Pet#ets_pet.point,
			Forza = Pet#ets_pet.forza, 
			Wit = Pet#ets_pet.wit,
			Agile = Pet#ets_pet.agile,
			Physique = Pet#ets_pet.physique,
			Aptitude = Pet#ets_pet.aptitude,
			Grow = Pet#ets_pet.grow,
			Status = Pet#ets_pet.status,
			Skill = pack_pet_skill(Pet1),
			Time = Pet#ets_pet.time,
			Ratio = R,
			Cost =  C,
			if Pet#ets_pet.train_end > 0 ->
				  TrainTime = Pet#ets_pet.train_end-NowTime;
			  true->TrainTime=Pet#ets_pet.train_end
			  end,
			Chenge = Pet#ets_pet.chenge,
			BattSkill = pack_pet_batt_skill(Pet); 
		true ->
			Pet_id= 0,
			Player_id = 0,
			Goods_id = 0,
			Name = <<>>,
			Rename_count = 0,
			Level = 0,
			Exp = 0,
			Exp_limit =  0,
			Happy = 0,
			Point = 0,
			Forza = 0, 
			Wit = 0,
			Agile = 0,
			Physique = 0,
			Aptitude = 0,
			Grow = 0,
			Status =0,
			Skill = pack_pet_skill([]),
			Time = 0,
			Ratio = 0,
			Cost =  0,
			TrainTime=0,
			Chenge = 0,
			BattSkill = pack_pet_skill([]) 
			
	end,
	Name_len = byte_size(Name),
	Data_vaule = <<Pet_id:32,Player_id:32,Goods_id:32,Name_len:16,Name/binary,Rename_count:16,	Level:16,Exp:32,
				   Exp_limit:32,Happy:32,Point:16,Forza:32,Wit:32,Agile:32,Physique:32,Aptitude:32,Grow:32,Status:16,
				   Skill/binary,Time:32,Ratio:16,Cost:32,TrainTime:32, Chenge:32,BattSkill/binary>>,
	Data_vaule.


%%灵兽所有技能信息，技能效果
pack_pet_skill(Pet) ->
		case Pet of
			[] -> 
				 <<0:16, <<>>/binary>>;
			_ ->
				Skill_List = [Pet#ets_pet.skill_1,Pet#ets_pet.skill_2,Pet#ets_pet.skill_3,Pet#ets_pet.skill_4,Pet#ets_pet.skill_5,Pet#ets_pet.skill_6],
				F = fun(PetSkill) ->
							[SkillId, SkillLevel, SkillStep, SkillExp] = util:string_to_term(tool:to_list(PetSkill)),
							NextSkillExp = data_pet:get_pet_skill_exp(SkillLevel+1, SkillStep),
							[Skill_Value,Skill_Fix_Value] = data_pet:get_skill_value(PetSkill),
							<<SkillId:32, SkillLevel:8, SkillStep:8,SkillExp:32,NextSkillExp:32,Skill_Value:32,Skill_Fix_Value:32>>
					end,
				RB = tool:to_binary([F(PetSkill) || PetSkill <- Skill_List]),
				<<6:16, RB/binary>>
		end.
	
%%灵兽所有战斗技能信息
pack_pet_batt_skill(Pet) ->
	case Pet of
			[] -> 
				 <<0:16, <<>>/binary>>;
			_ ->
				Batt_skill = util:string_to_term(tool:to_list(Pet#ets_pet.batt_skill)),
				if Batt_skill == undefined ->
					   BattSkillList = [];
				   true ->
					   BattSkillList = Batt_skill
				end,
				Len = length(BattSkillList),
				F = fun(SkillId) ->
							<<SkillId:32>>
					end,
				RB = tool:to_binary([F(SkillId) || SkillId <- BattSkillList]),
				<<Len:16, RB/binary>>
		end.




	