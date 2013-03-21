%%%--------------------------------------
%%% @Module  : pt_40
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 氏族消息的解包和组包
%%%--------------------------------------
-module(pt_40).
-export([read/2, write/2]).
-include("common.hrl").
-include("record.hrl").
-include("guild_info.hrl").

-define(SEPARATOR_STRING, "|").


%%%=========================================================================
%%% 解包函数
%%%=========================================================================

%% -----------------------------------------------------------------
%% 创建氏族
%% -----------------------------------------------------------------
read(40001, <<BuildCoin:32, Bin/binary>>) ->
    {GuildName, _} = pt:read_string(Bin),
    {ok, [GuildName, BuildCoin]};

%% -----------------------------------------------------------------
%% 解散氏族
%% -----------------------------------------------------------------
read(40002, <<GuildId:32>>) ->
    {ok, [GuildId]};

%% -----------------------------------------------------------------
%% 申请加入
%% -----------------------------------------------------------------
read(40004, <<GuildId:32>>) ->
    {ok, [GuildId]};

%% -----------------------------------------------------------------
%% 审批加入
%% -----------------------------------------------------------------
read(40005, <<HandleResult:16, Len:16, Bin/binary>>) ->
 	F = fun(_, {TB, Result}) ->
 				<<PlayerId:32, NewTB/binary>> = TB,
				{PlayerName, RestTB} = pt:read_string(NewTB),
 				{ok, {RestTB, [{PlayerId, PlayerName}|Result]}}
		end,
	{ok, {_, ApplyList}} = util:for_new(1, Len, F, {Bin, []}),
	{ok, [HandleResult, ApplyList]};
%% -----------------------------------------------------------------
%% 邀请加入
%% -----------------------------------------------------------------
read(40006, <<Bin/binary>>) ->
    {PlayerName, _} = pt:read_string(Bin),
    {ok, [PlayerName]};

%% -----------------------------------------------------------------
%% 邀请回应
%% -----------------------------------------------------------------
read(40007, <<GuildId:32, ResponseResult:16>>) ->
    {ok, [GuildId, ResponseResult]};

%% -----------------------------------------------------------------
%% 开除帮众
%% -----------------------------------------------------------------
read(40008, <<PlayerId:32>>) ->
    {ok, [PlayerId]};

%% -----------------------------------------------------------------
%% 退出氏族
%% -----------------------------------------------------------------
read(40009, _R) ->
    {ok, []};

%% -----------------------------------------------------------------
%% 氏族列表
%% -----------------------------------------------------------------
read(40010, <<Realm:16, Page:16, Type:8, Bin/binary>>) ->
	{GuildName, Bin1} = pt:read_string(Bin),
	{ChiefName, _} = pt:read_string(Bin1),
    {ok, [Realm, Type, Page, GuildName, ChiefName]};

%% -----------------------------------------------------------------
%% 成员列表
%% -----------------------------------------------------------------
read(40011, <<GuildId:32>>) ->
    {ok, [GuildId]};

%% -----------------------------------------------------------------
%% 申请列表
%% -----------------------------------------------------------------
read(40012, <<GuildId:32>>) ->
    {ok, [GuildId]};

%% -----------------------------------------------------------------
%% 邀请列表
%% -----------------------------------------------------------------
read(40013, _R) ->
    {ok, []};

%% -----------------------------------------------------------------
%% 氏族信息
%% -----------------------------------------------------------------
read(40014, <<GuildId:32>>) ->
    {ok, [GuildId]};

%% -----------------------------------------------------------------
%% 修改氏族公告
%% -----------------------------------------------------------------
read(40016, <<GuildId:32, Bin/binary>>) ->
    {Announce, _} = pt:read_string(Bin),
    {ok, [GuildId, Announce]};

%% -----------------------------------------------------------------
%% 禅让族长
%% -----------------------------------------------------------------
read(40018, <<PlayerId:32>>) ->
    {ok, [PlayerId]};

%% -----------------------------------------------------------------
%% 捐献氏族金
%% -----------------------------------------------------------------
read(40019, <<GuildId:32, Type:8>>) ->
    {ok, [GuildId, Type]};

%% -----------------------------------------------------------------
%% 氏族升级
%% -----------------------------------------------------------------
read(40020, <<GuildId:32>>) ->
	{ok, [GuildId]};

%% -----------------------------------------------------------------
%% 辞去官职
%% -----------------------------------------------------------------
read(40022, <<GuildId:32>>) ->
    {ok, [GuildId]};

%% -----------------------------------------------------------------
%% 成员职务设置
%% -----------------------------------------------------------------
read(40028,<<GuildId:32, PlayerId:32,Post:16, DepartId:16, Bin/binary>>) ->
	case Post of
		1 ->%%设置长老
			{GuildTitle, _} = pt:read_string(Bin),
			{ok, [GuildId, PlayerId, Post, DepartId, GuildTitle,[]]};
		3 ->%% 设置弟子
			case DepartId of
				0 ->%%普通弟子
					{GuildTitle, _} = pt:read_string(Bin),
					{ok, [GuildId, PlayerId, Post, DepartId, GuildTitle,[]]};
				_ ->		%%堂内弟子		
					{GuildTitle, Bin1} = pt:read_string(Bin),
					{DepartName, _} = pt:read_string(Bin1),
					{ok, [GuildId, PlayerId, Post, DepartId, GuildTitle,[DepartName]]}
			end;
		_ ->	%%设置堂主
			{GuildTitle, Bin1} = pt:read_string(Bin),
					{DepartName, _} = pt:read_string(Bin1),
					{ok, [GuildId, PlayerId, Post, DepartId, GuildTitle,[DepartName]]}
	end;

%% -----------------------------------------------------------------
%% 修改堂名
%% -----------------------------------------------------------------
read(40029,<<GuildId:32, DepartId:16, Bin/binary>>) ->
	{DepartName, Bin1} = pt:read_string(Bin),
	{DepartsNames, _} = pt:read_string(Bin1),
	{ok, [GuildId, DepartId, DepartName, DepartsNames]};

%% -----------------------------------------------------------------
%% 氏族中简单获取好友列表
%% -----------------------------------------------------------------
read(40030, _R) ->
	{ok, []};
%% -----------------------------------------------------------------
%% 获取氏族技能信息
%% -----------------------------------------------------------------
read(40031, <<GuildId:32>>) ->
	{ok, [GuildId]};
%% -----------------------------------------------------------------
%% 氏族技能升级
%% -----------------------------------------------------------------
read(40032, <<GuildId:32, SkillId:32, Level:32>>) ->
	{ok, [GuildId, SkillId, Level]};
%% -----------------------------------------------------------------
%% 回氏族领地
%% -----------------------------------------------------------------
read(40033, _R) ->
	{ok, []};
%% -----------------------------------------------------------------
%% 离开氏族领地
%% -----------------------------------------------------------------
read(40034, _R) ->
	{ok, []};
%% -----------------------------------------------------------------
%% 获取氏族仓库当前物品总数
%% -----------------------------------------------------------------
read(40050, <<GuildId:32>>) ->
	{ok, [GuildId]};

%% -----------------------------------------------------------------
%% 获取氏族仓库物品列表
%% -----------------------------------------------------------------
read(40051, <<GuildId:32>>) ->
	{ok, [GuildId]};

%% -----------------------------------------------------------------
%% 取出氏族仓库物品
%% -----------------------------------------------------------------
read(40052, <<GuildId:32, GoodsId:32>>) ->
	{ok, [GuildId, GoodsId]};

%% -----------------------------------------------------------------
%% 放入氏族仓库物品
%% -----------------------------------------------------------------
read(40053, <<GuildId:32, GoodsId:32, GoodsTypeId:16, GoodsNum:16>>) ->
	{ok, [GuildId, GoodsId, GoodsTypeId, GoodsNum]};

%% -----------------------------------------------------------------
%% 获取物品详细信息(仅在氏族模块用)
%% -----------------------------------------------------------------
read(40054, <<GuildId:32, GoodsId:32>>) ->
	{ok, [GuildId, GoodsId]};

%% -----------------------------------------------------------------
%% 40017 召唤氏族boss
%% -----------------------------------------------------------------
read(40017, <<Type:8>>) ->
	{ok, [Type]};

%% -----------------------------------------------------------------
%% 40025 领取福利
%% -----------------------------------------------------------------
read(40025, _R) ->
	{ok, []};

%% -----------------------------------------------------------------
%% 40026  获取氏族高级技能信息
%% -----------------------------------------------------------------
read(40026, <<GuildId:32>>) ->
	{ok, [GuildId]};

%% -----------------------------------------------------------------
%% 40027  高级技能升级 
%% -----------------------------------------------------------------
read(40027, <<GuildId:32, HSkillId:32, HKLevel:32>>) ->
	{ok, [GuildId, HSkillId, HKLevel]};

%% -----------------------------------------------------------------
%% 氏族改名
%% -----------------------------------------------------------------
read(40056, <<GuildId:32, Bin/binary>>) ->
    {NewGuildName, _} = pt:read_string(Bin),
	io:format("GuildId, NewGuildName is ~p/~p~n",[GuildId, NewGuildName]),
	io:format("GuildId, NewGuildName is ~p/~p~n",[GuildId, tool:to_list(NewGuildName)]),
    {ok, [GuildId, NewGuildName]};

%% -----------------------------------------------------------------
%% 40057  氏族兼并/归附申请
%% -----------------------------------------------------------------
read(40057, <<TarGId:32,Type:8>>) ->
	{ok, [TarGId, Type]};

%% -----------------------------------------------------------------
%% 40058  取消氏族兼并/归附申请
%% -----------------------------------------------------------------
read(40058, <<TarGId:32>>) ->
	{ok, [TarGId]};

%% -----------------------------------------------------------------
%% 40059  拒绝氏族兼并/归附申请
%% -----------------------------------------------------------------
read(40059, <<TarGId:32>>) ->
	{ok, [TarGId]};

%% -----------------------------------------------------------------
%% 40060  同意氏族兼并/归附申请
%% -----------------------------------------------------------------
read(40060, <<TarGId:32, Type:8>>) ->
	{ok, [TarGId, Type]};

%% -----------------------------------------------------------------
%% 40061  氏族联合请求(返回40063或者40062)
%% -----------------------------------------------------------------
read(40061, _R) ->
	{ok, []};

%% -----------------------------------------------------------------
%% 40064  兼并/依附氏族族长提交成员列表
%% -----------------------------------------------------------------
read(40064, <<Handle:8, Len:16, Bin/binary>>) ->
	F = fun(_, {TB, Result}) ->
				<<PlayerId:32, NewTB/binary>> = TB,
				{PlayerName, RestTB} = pt:read_string(NewTB),
 				{ok, {RestTB, [{PlayerId, PlayerName}|Result]}}
		end,
	{ok, {_, SubmitList}} = util:for_new(1, Len, F, {Bin, []}),
	{ok, [Handle, SubmitList]};

%% -----------------------------------------------------------------
%% 40066  氏族祝福个人信息
%% -----------------------------------------------------------------
read(40066, _R) ->
	{ok, []};

%% -----------------------------------------------------------------
%% 40067  获取氏族祝福任务
%% -----------------------------------------------------------------
read(40067, _R) ->
	{ok, []};

%% -----------------------------------------------------------------
%% 40068  刷新氏族祝福任务
%% -----------------------------------------------------------------
read(40068, _R) ->
	{ok, []};

%% -----------------------------------------------------------------
%% 40069  接受当前任务
%% -----------------------------------------------------------------
read(40069, _R) ->
	{ok, []};

%% -----------------------------------------------------------------
%% 40070  放弃当前任务
%% -----------------------------------------------------------------
read(40070, _R) ->
	{ok, []};

%% -----------------------------------------------------------------
%% 40072  氏族祝福成员运势
%% -----------------------------------------------------------------
read(40072, _R) ->
	{ok, []};

%% -----------------------------------------------------------------
%% 40073  帮他人刷新运势
%% -----------------------------------------------------------------
read(40073, <<PId:32>>) ->
	{ok, [PId]};

%% -----------------------------------------------------------------
%% 40075  邀请别人帮忙刷任务运势
%% -----------------------------------------------------------------
read(40075, <<DPId:32>>) ->
	{ok, [DPId]};

%% -----------------------------------------------------------------
%% 40077  领取奖励
%% -----------------------------------------------------------------
read(40077, _R) ->
	{ok, []};

%% -----------------------------------------------------------------
%% 40078  刷新时间
%% -----------------------------------------------------------------
read(40078, _R) ->
	{ok, []};

%% -----------------------------------------------------------------
%% 40079  发送群聊消息
%% -----------------------------------------------------------------
read(40079, <<Color:32,Bin/binary>>) ->
	{Msg, _} = pt:read_string(Bin),
    {ok, [Color, Msg]};

%% -----------------------------------------------------------------
%% 40080 发送群聊消息
%% -----------------------------------------------------------------
read(40080, _R) ->
	{ok, []};

%% -----------------------------------------------------------------
%% 40084 族员答应传送求援PK
%% -----------------------------------------------------------------
read(40084, <<Type:8, OSceneId:32, OX:32, OY:32>>) ->
	{ok, [Type, OSceneId, OX, OY]};

%% -----------------------------------------------------------------
%% 40085 族长召唤
%% -----------------------------------------------------------------
read(40085, _R) ->
	{ok, []};

%% -----------------------------------------------------------------
%% 40086 成员回应族长召唤
%% -----------------------------------------------------------------
read(40086, _R) ->
	{ok, []};

%% -----------------------------------------------------------------
%% 40088 发出氏族联盟申请
%% -----------------------------------------------------------------
read(40088, <<TarGid:32>>) ->
	{ok, [TarGid]};

%% -----------------------------------------------------------------
%% 40089 取消氏族联盟申请
%% -----------------------------------------------------------------
read(40089, <<TarGid:32>>) ->
	{ok, [TarGid]};

%% -----------------------------------------------------------------
%% 40090 同意氏族联盟申请
%% -----------------------------------------------------------------
read(40090, <<TarGid:32>>) ->
	{ok, [TarGid]};

%% -----------------------------------------------------------------
%% 40091 拒绝氏族联盟申请
%% -----------------------------------------------------------------
read(40091, <<TarGid:32>>) ->
	{ok, [TarGid]};

%% -----------------------------------------------------------------
%% 40092 中止氏族联盟关系
%% -----------------------------------------------------------------
read(40092, <<TarGid:32>>) ->
	{ok, [TarGid]};

%% -----------------------------------------------------------------
%% 40093 获取指定的氏族的氏族信息
%% -----------------------------------------------------------------
read(40093, <<GuildId:32>>) ->
    {ok, [GuildId]};
%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
read(Cmd, _R) ->
	?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {error, no_match}.

%%%=========================================================================
%%% 组包函数
%%%=========================================================================


%% -----------------------------------------------------------------
%% 加入氏族通知（加入者）
%% 通知类型：1
%% 通知内容：加入角色ID，加入角色名，氏族ID，氏族名
%% -----------------------------------------------------------------
write(40000, [1, PlayerId, PlayerName, GuildId,  GuildName]) ->
    PlayerIdList  = integer_to_list(PlayerId),
    GuildIdList   = integer_to_list(GuildId),
    MsgContentBin = tool:to_binary([PlayerIdList, ?SEPARATOR_STRING, PlayerName, ?SEPARATOR_STRING, GuildIdList, ?SEPARATOR_STRING, GuildName]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<1:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 氏族邀请通知（被邀请人收到）
%% 通知类型：2
%% 通知内容：氏族ID，氏族名
%% -----------------------------------------------------------------
write(40000, [2, GuildId, GuildName, RecommanderId, RecommanderName]) ->
    GuildIdList   = integer_to_list(GuildId),
	RecommanderIdList = integer_to_list(RecommanderId),
    MsgContentBin = tool:to_binary([GuildIdList, ?SEPARATOR_STRING, GuildName, ?SEPARATOR_STRING, RecommanderIdList, ?SEPARATOR_STRING, RecommanderName]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<2:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 踢出氏族通知（被提出者）
%% 通知类型：3
%% 通知内容：被踢角色ID，被踢角色名，氏族ID，氏族名
%% -----------------------------------------------------------------
write(40000, [3, PlayerId, PlayerName, GuildId, GuildName]) ->
    PlayerIdList  = integer_to_list(PlayerId),
    GuildIdList   = integer_to_list(GuildId),
    MsgContentBin = tool:to_binary([PlayerIdList, ?SEPARATOR_STRING, PlayerName, ?SEPARATOR_STRING, GuildIdList, ?SEPARATOR_STRING, GuildName]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<3:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};


%% -----------------------------------------------------------------
%% 氏族成员职位变化通告（仅发职位变化的那个成员）
%% 通知类型：4
%% 通知内容：角色ID，角色名称，职位名称
%% -----------------------------------------------------------------
write(40000, [4, PlayerId, PlayerName, NewPosition, PositionName]) ->
	PlayerIdList = integer_to_list(PlayerId),
	NewPositionList = integer_to_list(NewPosition),
    MsgContentBin   = tool:to_binary([PlayerIdList, ?SEPARATOR_STRING, PlayerName, ?SEPARATOR_STRING, NewPositionList, ?SEPARATOR_STRING, PositionName]),
    MsgContentLen   = byte_size(MsgContentBin),
    Data = <<4:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};
%% -----------------------------------------------------------------
%% 族长禅让通知（氏族全体成员）
%% 通知类型：5
%% 通知内容：旧族长ID, 旧族长名称，新族长ID，新族长名称
%% -----------------------------------------------------------------
write(40000, [5, PlayerId, PlayerName, NewChiefId, NewChiefName]) ->
    PlayerIdList    = integer_to_list(PlayerId),
    NewChiefIdList  = integer_to_list(NewChiefId),
    MsgContentBin   = tool:to_binary([PlayerIdList, ?SEPARATOR_STRING, PlayerName, ?SEPARATOR_STRING, NewChiefIdList, ?SEPARATOR_STRING, NewChiefName]),
    MsgContentLen   = byte_size(MsgContentBin),
    Data = <<5:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};


%% -----------------------------------------------------------------
%% 氏族升级通知（氏族全体成员）
%% 通知类型：6
%% 通知内容：氏族ID, 氏族名称，原等级，现等级
%% -----------------------------------------------------------------
write(40000, [6, GuildId, GuildName, OldLevel, NewLevel]) ->
    GuildIdList     = integer_to_list(GuildId),
    OldLevelList    = integer_to_list(OldLevel),
    NewLevelList    = integer_to_list(NewLevel),
    MsgContentBin   = tool:to_binary([GuildIdList, ?SEPARATOR_STRING, GuildName, ?SEPARATOR_STRING, OldLevelList, ?SEPARATOR_STRING, NewLevelList]),
    MsgContentLen   = byte_size(MsgContentBin),
    Data = <<6:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 拒绝邀请通知（仅发给邀请人）
%% 通知类型：7
%% 通知内容：角色ID，角色名称
%% -----------------------------------------------------------------
write(40000, [7, PlayerId, PlayerName]) ->
    PlayerIdList  = integer_to_list(PlayerId),
    MsgContentBin = tool:to_binary([PlayerIdList, ?SEPARATOR_STRING, PlayerName]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<7:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};



%% -----------------------------------------------------------------
%% 审批拒绝通知（仅发送给申请人）
%% 通知类型：8
%% 通知内容：氏族ID，氏族名称
%% -----------------------------------------------------------------
write(40000, [8, GuildId, GuildName]) ->
    GuildIdList   = integer_to_list(GuildId),
    MsgContentBin = tool:to_binary([GuildIdList, ?SEPARATOR_STRING, GuildName]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<8:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 头衔授予通知（授予者）
%% 通知类型：9
%% 通知内容：角色ID，角色名称，头衔
%% -----------------------------------------------------------------
write(40000, [9, PlayerId, PlayerName, Title]) ->
    PlayerIdList  = integer_to_list(PlayerId),
    MsgContentBin = tool:to_binary([PlayerIdList, ?SEPARATOR_STRING, PlayerName, ?SEPARATOR_STRING, Title]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<9:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 技能升级通知（氏族全体成员）
%% 通知类型：10
%% 通知内容：氏族名字，技能Id，技能名字，新等级
%% -----------------------------------------------------------------
write(40000, [10, GuildName, SkillId, SkillName, NewLevel]) ->
	SkillIdList = integer_to_list(SkillId),
	NewLevelList = integer_to_list(NewLevel),
	MsgContentBin = tool:to_binary([GuildName, ?SEPARATOR_STRING, SkillIdList, ?SEPARATOR_STRING, SkillName, ?SEPARATOR_STRING, NewLevelList]),
	MsgContentLen = byte_size(MsgContentBin),
	Data = <<10:16, MsgContentLen:16, MsgContentBin/binary>>,
	{ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 解散氏族通知（全体成员）
%% 通知类型：11
%% 通知内容：氏族ID， 氏族名称
%% -----------------------------------------------------------------
write(40000, [11, GuildId, PlayerName, GuildName]) ->
    GuildIdList   = integer_to_list(GuildId),
    MsgContentBin = tool:to_binary([GuildIdList, ?SEPARATOR_STRING, GuildName, ?SEPARATOR_STRING, PlayerName]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<11:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 氏族高级技能升级通知（除族长之外的全体在线成员）
%% 通知类型：12
%% 通知内容：技能ID，新等级
%% -----------------------------------------------------------------
write(40000, [12, HSkillId, NewHKLevel]) ->
	HSkillIdStr = integer_to_list(HSkillId),
	NewHKLevelStr = integer_to_list(NewHKLevel),
	MsgContentBin = tool:to_binary([HSkillIdStr, ?SEPARATOR_STRING, NewHKLevelStr]),
    MsgContentLen = byte_size(MsgContentBin),
	Data = <<12:16, MsgContentLen:16, MsgContentBin/binary>>,
	 {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 氏族高级技能升级通知（除族长之外的全体在线成员）
%% 通知类型：13
%% 通知内容：成员名字，技能令数目
%% -----------------------------------------------------------------
write(40000, [13, SkillsTos, PlayerName]) ->
	SkillsTosStr = integer_to_list(SkillsTos),
	MsgContentBin = tool:to_binary([PlayerName, ?SEPARATOR_STRING, SkillsTosStr]),
	MsgContentLen = byte_size(MsgContentBin),
	Data = <<13:16, MsgContentLen:16, MsgContentBin/binary>>,
	{ok, pt:pack(40000, Data)};
	
%% -----------------------------------------------------------------
%% 氏族运镖求救通告（全体成员）
%% 通知类型：14
%% 通知内容：Type通告类型
%% -----------------------------------------------------------------
write(40000, [14, Type]) ->
	TypeStr = integer_to_list(Type),
	MsgContentBin = tool:to_binary([TypeStr]),
	MsgContentLen = byte_size(MsgContentBin),
	Data = <<14:16, MsgContentLen:16, MsgContentBin/binary>>,
	{ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 氏族里成员使用弹劾令通告（全体成员）
%% 通知类型：15
%% 通知内容：新的族长ID, 新的族长名字， 原来的族长ID, 原来的族长名字
%% -----------------------------------------------------------------
write(40000, [15, PlayerId, PlayerName, ChiefId, ChiefName]) ->
	PlayerIdList = integer_to_list(PlayerId),
    ChiefIdList = integer_to_list(ChiefId),
    MsgContentBin = tool:to_binary([PlayerIdList, ?SEPARATOR_STRING, PlayerName, ?SEPARATOR_STRING, ChiefIdList, ?SEPARATOR_STRING, ChiefName]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<15:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 创建氏族
%% -----------------------------------------------------------------
write(40001, [Code, GuildId]) ->
    Data = <<Code:16, GuildId:32>>,
    {ok, pt:pack(40001, Data)};

%% -----------------------------------------------------------------
%% 解散氏族
%% -----------------------------------------------------------------
write(40002, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(40002, Data)};

%% -----------------------------------------------------------------
%% 申请加入
%% -----------------------------------------------------------------
write(40004, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(40004, Data)};

%% -----------------------------------------------------------------
%% 审批加入
%% -----------------------------------------------------------------
write(40005, [Result, Num]) ->
	Data = <<Result:16, Num:16>>,
	{ok, pt:pack(40005, Data)};
%% -----------------------------------------------------------------
%% 邀请加入
%% -----------------------------------------------------------------
write(40006, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(40006, Data)};

%% -----------------------------------------------------------------
%% 邀请回应
%% -----------------------------------------------------------------
write(40007, [Code, ResponseResult, GuildId, GuildName, GuildPosition]) ->
    GuildNameLen = byte_size(GuildName),
    Data = <<Code:16, ResponseResult:16, GuildId:32, GuildNameLen:16, GuildName/binary, GuildPosition:16>>,
    {ok, pt:pack(40007, Data)};

%% -----------------------------------------------------------------
%% 踢出氏族
%% -----------------------------------------------------------------
write(40008, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(40008, Data)};

%% -----------------------------------------------------------------
%% 退出氏族
%% -----------------------------------------------------------------
write(40009, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(40009, Data)};

%% -----------------------------------------------------------------
%% 氏族列表
%% -----------------------------------------------------------------
write(40010, [Total, NewPage, Records]) ->
	{Len, DataBin} = handle_guild_info_page(0, Records, []),
    Data = <<Total:16, NewPage:16, Len:16, DataBin/binary>>,
    {ok, pt:pack(40010, Data)};

%% -----------------------------------------------------------------
%% 成员列表
%% -----------------------------------------------------------------
write(40011, [Level, Len, Records]) ->
    Data = <<Level:16, Len:16, Records/binary>>,
    {ok, pt:pack(40011, Data)};

%% -----------------------------------------------------------------
%% 申请列表
%% -----------------------------------------------------------------
write(40012, [Len, Bin]) ->
    Data = <<Len:16, Bin/binary>>,
    {ok, pt:pack(40012, Data)};

%% -----------------------------------------------------------------
%% 邀请列表
%% -----------------------------------------------------------------
%% write(40013, [Len, Records]) ->
write(40013, [GuildInvites]) ->
	GuildInviteList = lists:map(fun pack_guild_invite_data/1, GuildInvites),
    Len = length(GuildInviteList),
	Records = tool:to_binary(GuildInviteList),
	Data = <<Len:16, Records/binary>>,
    {ok, pt:pack(40013, Data)};

%% -----------------------------------------------------------------
%% 氏族信息
%% -----------------------------------------------------------------
write(40014, [Result, Data]) ->
	case Result of
		1 ->
			{GuildId, Name, Announce, Realm, Level, Exp, NeedExp, MemberNum, 
			 MemberCapacity, ChiefId, ChiefName, Funds, UpGradeNeedTime,
			 DepartNames, LogsLen, Logs, Alliances} = Data,
			{NameLen, NameBin} = lib_guild_inner:string_to_binary_and_len(Name),
			{AnnounceLen, AnnounceBin} = lib_guild_inner:string_to_binary_and_len(Announce),
			{ChiefNameLen, ChiefNameBin} = lib_guild_inner:string_to_binary_and_len(ChiefName),
			{DepartNamesLen, DepartNamesBin} = lib_guild_inner:string_to_binary_and_len(DepartNames),
			{AllLen, AlliancesBin} = handle_40014_alliances(0, Alliances, []),
%% 			?DEBUG("AllLen:~p, Alliances:~p", [AllLen, Alliances]),
			DataBin = <<Result:16, GuildId:32, NameLen:16, NameBin/binary, AnnounceLen:16,AnnounceBin/binary,
					Realm:16, Level:32, Exp:32, NeedExp:32, MemberNum:32, 
					MemberCapacity:32, ChiefId:32, ChiefNameLen:16, ChiefNameBin/binary,
					Funds:32, UpGradeNeedTime:32, DepartNamesLen:16,
					DepartNamesBin/binary, LogsLen:16, Logs/binary, AllLen:16, AlliancesBin/binary>>;
		_ ->
			InfoBin = <<>>,
			DataBin = <<Result:16, InfoBin/binary>>
	end,
    {ok, pt:pack(40014, DataBin)};

%% -----------------------------------------------------------------
%% 修改氏族公告
%% -----------------------------------------------------------------
write(40016, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(40016, Data)};

%% -----------------------------------------------------------------
%% 禅让族长
%% -----------------------------------------------------------------
write(40018, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(40018, Data)};

%% -----------------------------------------------------------------
%% 捐献氏族金
%% -----------------------------------------------------------------
write(40019, [Code, MoneyLeft]) ->
    Data = <<Code:16, MoneyLeft:32>>,
    {ok, pt:pack(40019, Data)};


%% -----------------------------------------------------------------
%% 氏族升级
%% -----------------------------------------------------------------
write(40020, [Result, NewExp, NeedTime, StartTime]) ->
	Data = <<Result:16, NewExp:32, NeedTime:32, StartTime:32>>,
	{ok, pt:pack(40020, Data)};

%% -----------------------------------------------------------------
%% 辞去官职
%% -----------------------------------------------------------------
write(40022, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(40022, Data)};


%% -----------------------------------------------------------------
%% 领取日福利
%% -----------------------------------------------------------------
write(40023, [Code, Num, MoneyLeft]) ->
    Data = <<Code:16, Num:32, MoneyLeft:32>>,
    {ok, pt:pack(40023, Data)};

%% -----------------------------------------------------------------
%% 成员职务设置
%% -----------------------------------------------------------------
write(40028, [Result]) ->
	Data = <<Result:16>>,
	{ok, pt:pack(40028, Data)};

%% -----------------------------------------------------------------
%% 修改堂名
%% -----------------------------------------------------------------
write(40029, [Result]) ->
	Data = <<Result:16>>,
	{ok, pt:pack(40029, Data)};

%% -----------------------------------------------------------------
%% 获取好友列表
%% -----------------------------------------------------------------
write(40030, [[]]) ->
	Len = 0,
	LBin = <<>>,
	Data = <<Len:16, LBin/binary>>,
	{ok, pt:pack(40030, Data)};

write(40030, [L]) ->
	Len = length(L),
	F = fun([NickName, Level, IsOnline]) ->
				NLen = byte_size(NickName),
				<<NLen:16, NickName/binary, Level:32, IsOnline:16>>
		end,
	LBin = tool:to_binary([F(X) || X <- L, X /= []]),
	Data = <<Len:16, LBin/binary>>,
	{ok, pt:pack(40030, Data)};
	
%% -----------------------------------------------------------------
%% 获取氏族技能信息
%% -----------------------------------------------------------------
write(40031, [Skills, Len, Datas]) ->
	Data = <<Skills:32, Len:16, Datas/binary>>,
	{ok, pt:pack(40031, Data)};
%% -----------------------------------------------------------------
%% 氏族技能升级
%% -----------------------------------------------------------------
write(40032, [Result]) ->
	Data = <<Result:16>>,
	{ok, pt:pack(40032, Data)};
%% -----------------------------------------------------------------
%% 回氏族领地
%% -----------------------------------------------------------------
write(40033, [Result, RemainTime]) ->
	Data = <<Result:8, RemainTime:32>>,
	{ok, pt:pack(40033, Data)};

%% -----------------------------------------------------------------
%% 获取氏族仓库当前物品总数
%% -----------------------------------------------------------------
write(40050, [StorageLimit]) ->
	Data = <<StorageLimit:16>>,
	{ok, pt:pack(40050, Data)};

%% -----------------------------------------------------------------
%% 获取氏族仓库物品列表
%% -----------------------------------------------------------------
write(40051, [Capacity, GuildGoodsList]) ->
	Result = lists:map(fun handle_each_warehouse_goods/1, GuildGoodsList),
	Len = length(Result),
	ResultBin = tool:to_binary(Result),
	Data = <<Capacity:16, Len:16, ResultBin/binary>>,
	{ok, pt:pack(40051, Data)};

%% -----------------------------------------------------------------
%% 取出氏族仓库物品
%% -----------------------------------------------------------------
write(40052, [Result, GoodsId]) ->
	Data = <<Result:16, GoodsId:32>>,
	{ok, pt:pack(40052, Data)};

%% -----------------------------------------------------------------
%% 放入氏族仓库物品
%% -----------------------------------------------------------------
write(40053, [Result, GoodsId, GoodsTypeId, GoodsNum]) ->
	Data = <<Result:16, GoodsId:32, GoodsTypeId:16, GoodsNum:16>>,
	{ok, pt:pack(40053, Data)};

%% -----------------------------------------------------------------
%% 获取物品详细信息(仅在氏族模块用)
%% -----------------------------------------------------------------
write(40054, [Result, Info]) ->
	Data = handle_warehouse_goods(Result, Info),
	DataBin = <<Result:16, Data/binary>>,
	{ok, pt:pack(40054, DataBin)};

%% -----------------------------------------------------------------
%% 氏族仓库物品变更通知
%% -----------------------------------------------------------------
write(40055, [ActionType, GoodsId]) ->
	DataBin = <<ActionType:16, GoodsId>>,
	{ok, pt:pack(40055, DataBin)};

%% -----------------------------------------------------------------
%% 40017 召唤氏族boss
%% -----------------------------------------------------------------
write(40017, [Result]) ->
	DataBin = <<Result:8>>,
	{ok, pt:pack(40017, DataBin)};

%% -----------------------------------------------------------------
%% 40025 领取福利
%% -----------------------------------------------------------------
write(40025, [Result]) ->
	DataBin = <<Result:8>>,
	{ok, pt:pack(40025, DataBin)};

%% -----------------------------------------------------------------
%% 40026  获取氏族高级技能信息
%% -----------------------------------------------------------------
write(40026, [KillsTo, HSksList]) ->
	Records = list_to_binary(HSksList),
	Len = length(HSksList),
	DataBin = <<KillsTo:32, Len:16, Records/binary>>,
	{ok, pt:pack(40026, DataBin)};

%% -----------------------------------------------------------------
%% 40027  高级技能升级 
%% -----------------------------------------------------------------
write(40027, [Result]) ->
	DataBin = <<Result:16>>,
	{ok, pt:pack(40027, DataBin)};


%% -----------------------------------------------------------------
%% 40056  氏族改名
%% -----------------------------------------------------------------
write(40056, [Result, GuildId]) ->
	DataBin = <<Result:8, GuildId:32>>,
	{ok, pt:pack(40056, DataBin)};

%% -----------------------------------------------------------------
%% 40057  氏族兼并/归附申请
%% -----------------------------------------------------------------
write(40057, [Result]) ->
	DataBin = <<Result:8>>,
	{ok, pt:pack(40057, DataBin)};

%% -----------------------------------------------------------------
%% 40058  取消氏族兼并/归附申请
%% -----------------------------------------------------------------
write(40058, [Result]) ->
	DataBin = <<Result:8>>,
	{ok, pt:pack(40058, DataBin)};

%% -----------------------------------------------------------------
%% 40059  拒绝氏族兼并/归附申请
%% -----------------------------------------------------------------
write(40059, [Result]) ->
	DataBin = <<Result:8>>,
	{ok, pt:pack(40059, DataBin)};

%% -----------------------------------------------------------------
%% 40060  同意氏族兼并/归附申请
%% -----------------------------------------------------------------
write(40060, [Result]) ->
	DataBin = <<Result:8>>,
	{ok, pt:pack(40060, DataBin)};

%% -----------------------------------------------------------------
%% 40062  氏族兼并/归附列表
%% -----------------------------------------------------------------
write(40062, [Result]) ->
	{AList,BList, SAllianceList, RAllianceList} = Result,
%% 	?DEBUG("Result:~p", [Result]),
	{AL,A} = handle_union_lists_40062(a, AList, [], 0),
	{BL,B} = handle_union_lists_40062(b, BList, [], 0),
	{ALen, ABin} = handle_alliances_40062(s, SAllianceList, A, AL),
	{BLen, BBin} = handle_alliances_40062(r, RAllianceList, B, BL),
	DataBin = <<ALen:16, ABin/binary, BLen:16, BBin/binary>>,
	{ok, pt:pack(40062, DataBin)};

%% -----------------------------------------------------------------
%% 40063  兼并/依附氏族成员列表
%% -----------------------------------------------------------------
write(40063, [Result]) ->
	{UnionType, UnionState, ReMNum, Members} = Result,
	{Num, Bin} = handle_union_lists_40063(Members, [], 0),
	DataBin = <<UnionType:8, UnionState:8, ReMNum:16, Num:16, Bin/binary>>,
	{ok, pt:pack(40063, DataBin)};

%% -----------------------------------------------------------------
%% 40064  兼并/依附氏族族长提交成员列表
%% -----------------------------------------------------------------
write(40064, [Result]) ->
	{Reurn, Limit, Len} = Result,
	DataBin = <<Reurn:8, Limit:16, Len:16>>,
	{ok, pt:pack(40064, DataBin)};

%% -----------------------------------------------------------------
%% 40065  兼并/依附后氏族信息更新
%% -----------------------------------------------------------------
write(40065, [GuildId, GName, GPost, GQTime, GTitle, DepartName, DepartId]) ->
%% 	?DEBUG("GuildId:~p, GName:~p, GPost:~p, GQTime:~p, GTitle:~p, DepartName:~p, DepartId:~p", [GuildId, GName, GPost, GQTime, GTitle, DepartName, DepartId]),
	{GNameLen, GNameBin} = lib_guild_inner:string_to_binary_and_len(GName),
	{DepartNameLen, DepartNameBin} = lib_guild_inner:string_to_binary_and_len(DepartName),
	{GTitleLen, GTitleBin} = lib_guild_inner:string_to_binary_and_len(GTitle),
	DataBin = <<GuildId:32, GNameLen:16, GNameBin/binary, GPost:16, GQTime:32,GTitleLen:16, GTitleBin/binary, 
				DepartNameLen:16,DepartNameBin/binary,DepartId:32>>,
	{ok, pt:pack(40065, DataBin)};

%% -----------------------------------------------------------------
%% 40066  氏族祝福个人信息
%% -----------------------------------------------------------------
write(40066, [Result]) ->
	{TId, Luck, TColor, TState, ReTime, TCount, Logs} = Result,
	{LogLen, LogBin} = handle_f5gwish(Logs, [], 0),
	DataBin = <<TId:32, TColor:16, TCount:16, Luck:16, TState:16, ReTime:32, LogLen:16, LogBin/binary>>,
	{ok, pt:pack(40066, DataBin)};

%% -----------------------------------------------------------------
%% 40067  获取氏族祝福任务
%% -----------------------------------------------------------------
write(40067, [Result]) ->
	{Type, TId} = Result,
	DataBin = <<Type:16, TId:32>>,
	{ok, pt:pack(40067, DataBin)};

%% -----------------------------------------------------------------
%% 40068  刷新氏族祝福任务
%% -----------------------------------------------------------------
write(40068, [Result]) ->
	{Type, TId, TColor} = Result,
	DataBin = <<Type:16, TId:32, TColor:16>>,
	{ok, pt:pack(40068, DataBin)};

%% -----------------------------------------------------------------
%% 40069  接受当前任务
%% ----------------------------------------------------------------- 
write(40069, [Result]) ->
	DataBin = <<Result:16>>,
	{ok, pt:pack(40069, DataBin)};

%% -----------------------------------------------------------------
%% 40070  放弃当前任务
%% -----------------------------------------------------------------
write(40070, [Result]) ->
	DataBin = <<Result:16>>,
	{ok, pt:pack(40070, DataBin)};

%% -----------------------------------------------------------------
%% 40071  完成当前任务通知
%% -----------------------------------------------------------------
write(40071, [Result]) ->
	DataBin = <<Result:32>>,
	{ok, pt:pack(40071, DataBin)};

%% -----------------------------------------------------------------
%% 40072  氏族祝福成员运势
%% -----------------------------------------------------------------
write(40072, [Result]) ->
	{Help, List} = Result,
	{Len, Bin} = guild_gwish_40072(List, [], 0),
%% 	?DEBUG("Help:~p, len:~p", [Help, Len]),
	DataBin = <<Help:16, Len:16, Bin/binary>>,
	{ok, pt:pack(40072, DataBin)};

%% -----------------------------------------------------------------
%% 40073  帮他人刷新运势
%% -----------------------------------------------------------------
write(40073, [Result]) ->
	{Type, NTLuck, MName} = Result,
	{MNameLen, MNameBin} = lib_guild_inner:string_to_binary_and_len(MName),
	DataBin = <<Type:16, NTLuck:16, MNameLen:16, MNameBin/binary>>,
	{ok, pt:pack(40073, DataBin)};
	
%% -----------------------------------------------------------------
%% 40074  被他人刷新运势通知
%% -----------------------------------------------------------------
write(40074, [Data]) ->
	{TColor, SPName} = Data,
	{SPNameLen, SPNameBin} = lib_guild_inner:string_to_binary_and_len(SPName),
	DataBin = <<TColor:16, SPNameLen:16, SPNameBin/binary>>,
	{ok, pt:pack(40074, DataBin)};

%% -----------------------------------------------------------------
%% 40075  邀请别人帮忙刷任务运势
%% -----------------------------------------------------------------
write(40075, [Result]) ->
	DataBin = <<Result:16>>,
	{ok, pt:pack(40075, DataBin)};

%% -----------------------------------------------------------------
%% 40076  被邀请人收到需要帮忙刷任务运势(被找的那个玩家收到通知)
%% -----------------------------------------------------------------
write(40076, [Result]) ->
	{SPId, SPName} = Result,
	{SPNameLen, SPNameBin} = lib_guild_inner:string_to_binary_and_len(SPName),
	DataBin = <<SPId:32, SPNameLen:16, SPNameBin/binary>>,
	{ok, pt:pack(40076, DataBin)};

%% -----------------------------------------------------------------
%% 40077  领取奖励
%% -----------------------------------------------------------------
write(40077, [Result]) ->
	{Type, Goods} = Result,
	DataBin = <<Type:16, Goods:32>>,
	{ok, pt:pack(40077, DataBin)};

%% -----------------------------------------------------------------
%% 40078  刷新时间
%% -----------------------------------------------------------------
write(40078, [Result]) ->
	{Type, Gold} = Result,
	DataBin = <<Type:16, Gold:32>>,
	{ok, pt:pack(40078, DataBin)};

%% -----------------------------------------------------------------
%% 40079  氏族新消息通知
%% -----------------------------------------------------------------
write(40079,[PlayerId, Carre, Sex, Vip, Name, Color, Content]) ->
	NBin = tool:to_binary(Name),
	NLen = byte_size(NBin),
	Bin = tool:to_binary(Content),
    Len = byte_size(Bin),
	Data = <<PlayerId:32, Carre:8, Sex:8, Vip:8, NLen:16, NBin/binary, Color:32, Len:16, Bin/binary>>,
	{ok, pt:pack(40079, Data)};

%% -----------------------------------------------------------------
%% 40080  氏族群聊面板
%% -----------------------------------------------------------------
write(40080,[Result,Notice, MemberList]) ->
	case Result of
		0 ->Len = 0,
			Bin = <<>>,
			NLen = 0,
			NBin = <<>>,
			Data = <<Result:8, Len:16, Bin/binary, NLen:16, NBin/binary>>,
            {ok, pt:pack(40080, Data)};
	    _ ->
             F = fun(M) ->
					 NBin = tool:to_binary(M#ets_guild_member.player_name),
					 NLen = byte_size(NBin),
					 PlayerId = M#ets_guild_member.player_id,
					 Career = M#ets_guild_member.career,
					 Sex = M#ets_guild_member.sex,
					 Job = M#ets_guild_member.guild_position,
					 Vip = M#ets_guild_member.vip,
					 IsOnline = M#ets_guild_member.online_flag,
					 Lv = M#ets_guild_member.lv,
					 <<PlayerId:32, Career:8,Sex:8, NLen:16, NBin/binary, Job:8, Vip:8, IsOnline:8, Lv:8>>
				 end,
			 NBin = tool:to_binary([F(M) || M <- MemberList]),
			 NLen = length(MemberList),
			 Bin = tool:to_binary(Notice),
			 Len = byte_size(Bin),
			 Data = <<Result:8, Len:16, Bin/binary, NLen:16, NBin/binary >>,
             {ok, pt:pack(40080, Data)}
	end;	

%% -----------------------------------------------------------------
%% 40081  氏族群聊面板成员在线状态
%% -----------------------------------------------------------------
write(40081,[PlayerId,IsOnline]) ->
	Data = <<PlayerId:32,IsOnline:8>>,
	{ok, pt:pack(40081, Data)};

%% -----------------------------------------------------------------
%% 40082  氏族群聊面板成员在线状态
%% -----------------------------------------------------------------
write(40082,[PlayerName]) ->
	NBin = tool:to_binary(PlayerName),
	NLen = byte_size(NBin),
	Data = <<NLen:16, NBin/binary>>,
	{ok, pt:pack(40082, Data)};
%% -----------------------------------------------------------------
%% 40083  族员PK被打求救
%% -----------------------------------------------------------------
write(40083, [AerRealm, AerGuildName, AerName, OSceneId, OX, OY, DerName]) ->
	{AGNLen, AGNBin} = lib_guild_inner:string_to_binary_and_len(AerGuildName),
	{ANLen, ANBin} = lib_guild_inner:string_to_binary_and_len(AerName),
	{DNLen, DNBin} = lib_guild_inner:string_to_binary_and_len(DerName),
	Data = <<AerRealm:8, AGNLen:16, AGNBin/binary, ANLen:16, ANBin/binary, 
			 OSceneId:32, OX:32, OY:32,DNLen:16, DNBin/binary>>,
	{ok, pt:pack(40083, Data)};

%% -----------------------------------------------------------------
%% 40084 族员答应传送求援PK
%% -----------------------------------------------------------------
write(40084, [Result]) ->
	Data = <<Result:8>>,
	{ok, pt:pack(40084, Data)};

%% -----------------------------------------------------------------
%% 40085 族长召唤
%% -----------------------------------------------------------------
write(40085, [Reply]) ->
	?DEBUG("Reply:~p", [Reply]),
	Data = <<Reply:8>>,
	{ok, pt:pack(40085, Data)};

%% -----------------------------------------------------------------
%% 40086 成员回应族长召唤
%% -----------------------------------------------------------------
write(40086, [Reply]) ->
	Data = <<Reply:8>>,
	{ok, pt:pack(40086, Data)};

%% -----------------------------------------------------------------
%% 40087 族长召唤向族员广播
%% -----------------------------------------------------------------
write(40087, []) ->
	Data = <<>>,
	{ok, pt:pack(40087, Data)};
%% -----------------------------------------------------------------
%% 40088 发出氏族联盟申请
%% -----------------------------------------------------------------
write(40088, [Result]) ->
	Data = <<Result:8>>,
	{ok, pt:pack(40088, Data)};

%% -----------------------------------------------------------------
%% 40089 取消氏族联盟申请
%% -----------------------------------------------------------------
write(40089, [Result]) ->
	Data = <<Result:8>>,
	{ok, pt:pack(40089, Data)};

%% -----------------------------------------------------------------
%% 40090 同意氏族联盟申请
%% -----------------------------------------------------------------
write(40090, [Result]) ->
	Data = <<Result:8>>,
	{ok, pt:pack(40090, Data)};

%% -----------------------------------------------------------------
%% 40091 拒绝氏族联盟申请
%% -----------------------------------------------------------------
write(40091, [Result]) ->
	Data = <<Result:8>>,
	{ok, pt:pack(40091, Data)};

%% -----------------------------------------------------------------
%% 40092 中止氏族联盟关系
%% -----------------------------------------------------------------
write(40092, [Result]) ->
	Data = <<Result:8>>,
	{ok, pt:pack(40092, Data)};


%% -----------------------------------------------------------------
%% 40093 获取指定的氏族的氏族信息
%% -----------------------------------------------------------------
write(40093, [Result]) ->
	{GuildId, GuildName, Announce, Realm, Level, Exp, MemberNum, MemberCapacity, ChiefId, ChiefName, Funds} = Result,
	{GuildNameLen, GuildNameBin} = lib_guild_inner:string_to_binary_and_len(GuildName),
	{AnnounceLen, AnnounceBin} = lib_guild_inner:string_to_binary_and_len(Announce),
	{ChiefNameLen, ChiefNameBin} = lib_guild_inner:string_to_binary_and_len(ChiefName),
	Data =
		<<GuildId:32, GuildNameLen:16, GuildNameBin/binary, AnnounceLen:16, AnnounceBin/binary, Realm:16, Level:32, Exp:32,
		   MemberNum:32, MemberCapacity:32, ChiefId:32, ChiefNameLen:16, ChiefNameBin/binary, Funds:32>>,
	{ok, pt:pack(40093, Data)};

%% -----------------------------------------------------------------
%% 40094 主动更新客户端氏族的联盟信息
%% -----------------------------------------------------------------
write(40094, [Result]) ->
	{Len, Bin} = handle_40014_alliances(0, Result, []),
	Data = <<Len:16, Bin/binary>>,
	{ok, pt:pack(40094, Data)};

%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.

pack_guild_invite_data(GuildInviteElem) ->
	{GuildId, GuildName, ChiefId, ChiefName, MemberNum, MemberCapacity, 
	 NewLevel, Realm, Announce, InviteTime, RecommanderName} = GuildInviteElem,
	
	{GuildNameLen, GuildNameBin} = lib_guild_inner:string_to_binary_and_len(GuildName),
	{ChiefNameLen, ChiefNameBin} = lib_guild_inner:string_to_binary_and_len(ChiefName),
	{AnnounceLen, AnnounceBin} = lib_guild_inner:string_to_binary_and_len(Announce),
	{RecommanderNameLen, RecommanderNameBin} = lib_guild_inner:string_to_binary_and_len(RecommanderName),
	
	 <<GuildId:32, GuildNameLen:16, GuildNameBin/binary, ChiefId:32, ChiefNameLen:16, ChiefNameBin/binary, 
	   MemberNum:32, MemberCapacity:32, NewLevel:32, Realm:16, AnnounceLen:16, AnnounceBin/binary,
	   InviteTime:32, RecommanderNameLen:16, RecommanderNameBin/binary>>.


handle_each_warehouse_goods(WarehouseGoods) ->
	{GoodsId, GoodsTypeId, Num} = WarehouseGoods,
	<<GoodsId:32, GoodsTypeId:16, Num:16>>.

handle_warehouse_goods(Result, Info) ->
	case Result of
		1 -> 
			{GoodsInfo, SuitNum, AttributeList} = Info,
			pt_15:get_goods_info(GoodsInfo, SuitNum, AttributeList);
		_ ->
			pt_15:get_goods_info({}, 0, [])
	end.


handle_union_lists_40062(a,[],Result,Num) ->
	{Num, Result};
handle_union_lists_40062(a, [Elem|Rest], Result, Num) ->
	#guild_union{bgid = BGId,
				 bgname = BGName,
				 bcname = BCname,
				 bmem = [BGMem,BGMLimit],
				 blv = BGLv,
				 type = Type} = Elem,
	{BGNLen, BGNameBin} = lib_guild_inner:string_to_binary_and_len(BGName),
	{BGCNLen, BGCNameBin} = lib_guild_inner:string_to_binary_and_len(BCname),
	Bin = <<BGId:32, BGNLen:16, BGNameBin/binary, BGCNLen:16, BGCNameBin/binary, BGLv:32, BGMem:32, BGMLimit:32, Type:8>>,
	handle_union_lists_40062(a, Rest, [Bin|Result], Num+1);
handle_union_lists_40062(b,[],Result,Num) ->
	{Num, tool:to_binary(Result)};
handle_union_lists_40062(b, [Elem|Rest], Result, Num) ->
	#guild_union{agid = AGId,
				 agname = AGName,
				 acname = ACname,
				 amem = [AGMem,AGMLimit],
				 alv = AGLv,
				 type = Type} = Elem,
	{AGNLen, AGNameBin} = lib_guild_inner:string_to_binary_and_len(AGName),
	{AGCNLen, AGCNameBin} = lib_guild_inner:string_to_binary_and_len(ACname),
	Bin = <<AGId:32, AGNLen:16, AGNameBin/binary, AGCNLen:16, AGCNameBin/binary, AGLv:32, AGMem:32, AGMLimit:32, Type:8>>,
	handle_union_lists_40062(a, Rest, [Bin|Result], Num+1).

handle_alliances_40062(_Type, [], Result, Num) ->
	{Num, tool:to_binary(Result)};
handle_alliances_40062(Type, [Elem|SAllianceList], Result, Num) ->
	#ets_g_alliance_apply{agid = SourId,
						  bgid = DestId,
						  agname = SourName,
						  bgname = DestName,
						  acname = SourCName,
						  bcname = DestCName,
						  amem = [SourMem, SourMLimit],
						  bmem = [DestMem, DestMLimit],
						  alv = SourLv,
						  blv = DestLv} = Elem,
	case Type of
		s ->
			{SGNLen, SGNameBin} = lib_guild_inner:string_to_binary_and_len(DestName),
			{SGCNLen, SGCNameBin} = lib_guild_inner:string_to_binary_and_len(DestCName),
			Bin = <<DestId:32, SGNLen:16, SGNameBin/binary, SGCNLen:16, SGCNameBin/binary, DestLv:32, DestMem:32, DestMLimit:32, 3:8>>;
		r ->
			{RGNLen, RGNameBin} = lib_guild_inner:string_to_binary_and_len(SourName),
			{RGCNLen, RGCNameBin} = lib_guild_inner:string_to_binary_and_len(SourCName),
			Bin = <<SourId:32, RGNLen:16, RGNameBin/binary, RGCNLen:16, RGCNameBin/binary, SourLv:32, SourMem:32, SourMLimit:32, 3:8>>
	end,
	handle_alliances_40062(Type, SAllianceList, [Bin|Result], Num+1).


handle_union_lists_40063([], Result, Num) ->
	{Num, tool:to_binary(Result)};
handle_union_lists_40063([Member|Rest], Result, Num) ->
	#ets_guild_member{player_id = MId,
					  player_name = MName,
					  lv = Lv,
					  career = Career,
					  guild_position = Post,
					  donate_total = Donate,
					  donate_funds = Funds,
					  last_login_time = LastLogin,
					  guild_depart_name = DepartmentName,
					  vip = Vip} = Member,
	{DepartmentNameLen, DepartmentNameBin} = lib_guild_inner:string_to_binary_and_len(DepartmentName),
	{MLen, MNameBin} = lib_guild_inner:string_to_binary_and_len(MName),
	Bin = <<MId:32, MLen:16, MNameBin/binary, Lv:16, Career:16, Post:16, 
			DepartmentNameLen:16, DepartmentNameBin/binary, Donate:32, Funds:32, LastLogin:32, Vip:8>>,
	handle_union_lists_40063(Rest, [Bin|Result], Num+1).

handle_f5gwish([], Result, Num) ->
	{Num, tool:to_binary(Result)};
handle_f5gwish([Log|RLog], Result, Num) ->
	#ets_f5_gwish{hpname = HPName,
				  hluck = HLuck,
				  ncolor = NColor,
				  tid = TId} = Log,
	{HPNameLen, HPNameBin} = lib_guild_inner:string_to_binary_and_len(HPName),
	Data = <<HPNameLen:16, HPNameBin/binary, HLuck:16, NColor:16, TId:32>>,
	handle_f5gwish(RLog, [Data|Result], Num+1).
	
guild_gwish_40072([], Result, Num) ->
	{Num, tool:to_binary(Result)};
guild_gwish_40072([MGWish|Rest], Result, Num) ->
	#mem_gwish{pid = PId,
			   pname = PName,
			   sex = Sex,
			   career = Career,
			   luck = Luck,
			   tid = TId,
			   t_color = TColor,
			   help = Help,
			   bhelp = BHelp} = MGWish,
	{PNameLen, PNameBin} = lib_guild_inner:string_to_binary_and_len(PName),
%% 	?DEBUG("PId:~p, Sex:~p, Career:~p, Luck:~p, TId:~p, TColor:~p, Help:~p, BHelp:~p",[PId, Sex, Career, Luck, TId, TColor, Help, BHelp]),
	Elem = <<PId:32, PNameLen:16, PNameBin/binary, Sex:8, Career:16, Luck:16, TId:32, TColor:16, Help:16, BHelp:16>>,
	guild_gwish_40072(Rest, [Elem|Result], Num+1).

handle_guild_info_page(Num, [], Result) ->
	{Num, tool:to_binary(Result)};
handle_guild_info_page(Num, [Record|Records], Result) ->
	{GuildId, GuildName, Announce, Realm, Level, Exp, MemberNum, MemberCapacity, ChiefId, ChiefName, Funds} = Record,
	{GuildNameLen, GuildNameBin} = lib_guild_inner:string_to_binary_and_len(GuildName),
	{AnnounceLen, AnnounceBin} = lib_guild_inner:string_to_binary_and_len(Announce),
	{ChiefNameLen, ChiefNameBin} = lib_guild_inner:string_to_binary_and_len(ChiefName),
	NResult =
		[<<GuildId:32, GuildNameLen:16, GuildNameBin/binary, AnnounceLen:16, AnnounceBin/binary, Realm:16, Level:32, Exp:32,
		   MemberNum:32, MemberCapacity:32, ChiefId:32, ChiefNameLen:16, ChiefNameBin/binary, Funds:32>>|Result],
	handle_guild_info_page(Num+1, Records, NResult).

handle_40014_alliances(Num, [], Result) ->
	{Num, tool:to_binary(Result)};
handle_40014_alliances(Num, [{Realm, Id, Name}|Alliances], Result) ->
	{Len, NameBin} = lib_guild_inner:string_to_binary_and_len(Name),
	Data = <<Realm:8, Id:32, Len:16, NameBin/binary>>,
	handle_40014_alliances(Num+1, Alliances, [Data|Result]).
