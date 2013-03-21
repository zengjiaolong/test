%%%--------------------------------------
%%% @Module  : pt_40
%%% @Author  : shebiao
%%% @Email   : shebiao@jieyou.com
%%% @Created : 2010.06.12
%%% @Description: 帮派消息的解包和组包
%%%--------------------------------------
-module(pt_40).
-export([read/2, write/2]).

-define(SEPARATOR_STRING, "|").

%%%=========================================================================
%%% 解包函数
%%%=========================================================================

%% -----------------------------------------------------------------
%% 创建帮派
%% -----------------------------------------------------------------
read(40001, <<Bin/binary>>) ->
    {GuildName, Bin1} = pt:read_string(Bin),
    {GuildTenet, _} = pt:read_string(Bin1),
    {ok, [GuildName, GuildTenet]};

%% -----------------------------------------------------------------
%% 解散帮派
%% -----------------------------------------------------------------
read(40002, <<GuildId:32>>) ->
    {ok, [GuildId]};

%% -----------------------------------------------------------------
%% 解散确认
%% -----------------------------------------------------------------
read(40003, <<GuildID:32, ConfirmResult:16>>) ->
    {ok, [GuildID, ConfirmResult]};

%% -----------------------------------------------------------------
%% 申请加入
%% -----------------------------------------------------------------
read(40004, <<GuildId:32>>) ->
    {ok, [GuildId]};

%% -----------------------------------------------------------------
%% 审批加入
%% -----------------------------------------------------------------
read(40005, <<PlayerId:32, HandleResult:16>>) ->
    {ok, [PlayerId, HandleResult]};

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
%% 踢出帮派
%% -----------------------------------------------------------------
read(40008, <<PlayerId:32>>) ->
    {ok, [PlayerId]};

%% -----------------------------------------------------------------
%% 退出帮派
%% -----------------------------------------------------------------
read(40009, <<GuildId:32>>) ->
    {ok, [GuildId]};

%% -----------------------------------------------------------------
%% 帮派列表
%% -----------------------------------------------------------------
read(40010, <<PageSize:16, PageNo:16>>) ->
    {ok, [PageSize, PageNo]};

%% -----------------------------------------------------------------
%% 成员列表
%% -----------------------------------------------------------------
read(40011, <<GuildId:32, PageSize:16, PageNo:16>>) ->
    {ok, [GuildId, PageSize, PageNo]};

%% -----------------------------------------------------------------
%% 申请列表
%% -----------------------------------------------------------------
read(40012, <<GuildId:32, PageSize:16, PageNo:16>>) ->
    {ok, [GuildId, PageSize, PageNo]};

%% -----------------------------------------------------------------
%% 邀请列表
%% -----------------------------------------------------------------
read(40013, <<PlayerId:32, PageSize:16, PageNo:16>>) ->
    {ok, [PlayerId, PageSize, PageNo]};

%% -----------------------------------------------------------------
%% 帮派信息
%% -----------------------------------------------------------------
read(40014, <<PlayerId:32>>) ->
    {ok, [PlayerId]};

%% -----------------------------------------------------------------
%% 修改帮派宗旨
%% -----------------------------------------------------------------
read(40015, <<GuildId:32, Bin/binary>>) ->
    {Tenet, _} = pt:read_string(Bin),
    {ok, [GuildId, Tenet]};

%% -----------------------------------------------------------------
%% 修改帮派公告
%% -----------------------------------------------------------------
read(40016, <<GuildId:32, Bin/binary>>) ->
    {Announce, _} = pt:read_string(Bin),
    {ok, [GuildId, Announce]};

%% -----------------------------------------------------------------
%% 职位设置
%% -----------------------------------------------------------------
read(40017, <<PlayerId:32, GuildPosition:16>>) ->
    {ok, [PlayerId, GuildPosition]};

%% -----------------------------------------------------------------
%% 禅让帮主
%% -----------------------------------------------------------------
read(40018, <<PlayerId:32>>) ->
    {ok, [PlayerId]};

%% -----------------------------------------------------------------
%% 捐献帮派金
%% -----------------------------------------------------------------
read(40019, <<GuildId:32, Num:32>>) ->
    {ok, [GuildId, Num]};

%% -----------------------------------------------------------------
%% 捐献建设卡
%% -----------------------------------------------------------------
read(40020, <<GuildId:32, Num:32>>) ->
    {ok, [GuildId, Num]};

%% -----------------------------------------------------------------
%% 获取捐献列表
%% -----------------------------------------------------------------
read(40021, <<GuildId:32, PageSize:16, PageNo:16>>) ->
    {ok, [GuildId, PageSize, PageNo]};

%% -----------------------------------------------------------------
%% 辞去官职
%% -----------------------------------------------------------------
read(40022, <<GuildId:32>>) ->
    {ok, [GuildId]};

%% -----------------------------------------------------------------
%% 领取日福利
%% -----------------------------------------------------------------
read(40023, <<GuildId:32>>) ->
    {ok, [GuildId]};

%% -----------------------------------------------------------------
%% 获取成员信息
%% -----------------------------------------------------------------
read(40024, <<GuildId:32, PlayerId:32>>) ->
    {ok, [GuildId,PlayerId]};

%% -----------------------------------------------------------------
%% 授予头衔
%% -----------------------------------------------------------------
read(40025, <<GuildId:32, PlayerId:32, Bin/binary>>) ->
    {Title, _} = pt:read_string(Bin),
    {ok, [GuildId, PlayerId, Title]};

%% -----------------------------------------------------------------
%% 修改个人备注
%% -----------------------------------------------------------------
read(40026, <<GuildId:32, Bin/binary>>) ->
    {Remark, _} = pt:read_string(Bin),
    {ok, [GuildId, Remark]};

%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
read(_Cmd, _R) ->
    {error, no_match}.

%%%=========================================================================
%%% 组包函数
%%%=========================================================================

%% -----------------------------------------------------------------
%% 解散帮派通知（帮派群发）
%% 通知类型：0
%% 通知内容：帮派ID， 帮派名称
%% -----------------------------------------------------------------
write(40000, [0, GuildId, GuildName]) ->
    GuildIdList   = integer_to_list(GuildId),
    MsgContentBin = list_to_binary([GuildIdList, ?SEPARATOR_STRING, GuildName]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<0:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 加入帮派通知（帮派群发）
%% 通知类型：1
%% 通知内容：加入角色ID，加入角色名，帮派ID，帮派名
%% -----------------------------------------------------------------
write(40000, [1, PlayerId, PlayerName, GuildId, GuildName]) ->
    PlayerIdList  = integer_to_list(PlayerId),
    GuildIdList   = integer_to_list(GuildId),
    MsgContentBin = list_to_binary([PlayerIdList, ?SEPARATOR_STRING, PlayerName, ?SEPARATOR_STRING, GuildIdList, ?SEPARATOR_STRING, GuildName]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<1:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 帮派邀请通知（被邀请人收到）
%% 通知类型：2
%% 通知内容：帮派ID，帮派名
%% -----------------------------------------------------------------
write(40000, [2, GuildId, GuildName]) ->
    GuildIdList   = integer_to_list(GuildId),
    MsgContentBin = list_to_binary([GuildIdList, ?SEPARATOR_STRING, GuildName]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<2:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 踢出帮派通知（帮派群发）
%% 通知类型：3
%% 通知内容：被踢角色ID，被踢角色名，帮派ID，帮派名
%% -----------------------------------------------------------------
write(40000, [3, PlayerId, PlayerName, GuildId, GuildName]) ->
    PlayerIdList  = integer_to_list(PlayerId),
    GuildIdList   = integer_to_list(GuildId),
    MsgContentBin = list_to_binary([PlayerIdList, ?SEPARATOR_STRING, PlayerName, ?SEPARATOR_STRING, GuildIdList, ?SEPARATOR_STRING, GuildName]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<3:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};


%% -----------------------------------------------------------------
%% 退出帮派通知（帮派群发）
%% 通知类型：4
%% 通知内容：退出角色ID，退出角色名，帮派ID，帮派名
%% -----------------------------------------------------------------
write(40000, [4, PlayerId, PlayerName, GuildId, GuildName]) ->
    PlayerIdList  = integer_to_list(PlayerId),
    GuildIdList   = integer_to_list(GuildId),
    MsgContentBin = list_to_binary([PlayerIdList, ?SEPARATOR_STRING, PlayerName, ?SEPARATOR_STRING, GuildIdList, ?SEPARATOR_STRING, GuildName]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<4:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 升职通知（帮派群发）
%% 通知类型：5
%% 通知内容：角色ID, 角色名称，旧职位，新职位
%% -----------------------------------------------------------------
write(40000, [5, PlayerId, PlayerName, OldPosition, NewPosition]) ->
    PlayerIdList    = integer_to_list(PlayerId),
    OldPositionList = integer_to_list(OldPosition),
    NewPositionList = integer_to_list(NewPosition),
    MsgContentBin   = list_to_binary([PlayerIdList, ?SEPARATOR_STRING, PlayerName, ?SEPARATOR_STRING, OldPositionList, ?SEPARATOR_STRING, NewPositionList]),
    MsgContentLen   = byte_size(MsgContentBin),
    Data = <<5:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 降职通知（被降职人收到）
%% 通知类型：6
%% 通知内容：角色ID, 角色名称，旧职位，新职位
%% -----------------------------------------------------------------
write(40000, [6, PlayerId, PlayerName, OldPosition, NewPosition]) ->
    PlayerIdList    = integer_to_list(PlayerId),
    OldPositionList = integer_to_list(OldPosition),
    NewPositionList = integer_to_list(NewPosition),
    MsgContentBin   = list_to_binary([PlayerIdList, ?SEPARATOR_STRING, PlayerName, ?SEPARATOR_STRING, OldPositionList, ?SEPARATOR_STRING, NewPositionList]),
    MsgContentLen   = byte_size(MsgContentBin),
    Data = <<6:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 帮主禅让通知（帮派群发）
%% 通知类型：7
%% 通知内容：旧帮主ID, 旧帮主名称，新帮主ID，新帮主名称
%% -----------------------------------------------------------------
write(40000, [7, PlayerId, PlayerName, NewChiefId, NewChiefName]) ->
    PlayerIdList    = integer_to_list(PlayerId),
    NewChiefIdList  = integer_to_list(NewChiefId),
    MsgContentBin   = list_to_binary([PlayerIdList, ?SEPARATOR_STRING, PlayerName, ?SEPARATOR_STRING, NewChiefIdList, ?SEPARATOR_STRING, NewChiefName]),
    MsgContentLen   = byte_size(MsgContentBin),
    Data = <<7:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 辞去官职通知（帮主副帮主收到）
%% 通知类型：8
%% 通知内容：角色ID, 角色名称，原职位，新职位
%% -----------------------------------------------------------------
write(40000, [8, PlayerId, PlayerName, OldPosition, NewPosition]) ->
    PlayerIdList    = integer_to_list(PlayerId),
    OldPositionList = integer_to_list(OldPosition),
    NewPositionList = integer_to_list(NewPosition),
    MsgContentBin   = list_to_binary([PlayerIdList, ?SEPARATOR_STRING, PlayerName, ?SEPARATOR_STRING, OldPositionList, ?SEPARATOR_STRING, NewPositionList]),
    MsgContentLen   = byte_size(MsgContentBin),
    Data = <<8:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 正式解散通知（帮派群发）
%% 通知类型：9
%% 通知内容：帮派ID, 帮派名称
%% -----------------------------------------------------------------
write(40000, [9, GuildId, GuildName]) ->
    GuildIdList   = integer_to_list(GuildId),
    MsgContentBin = list_to_binary([GuildIdList, ?SEPARATOR_STRING, GuildName]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<9:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 取消解散通知（帮派群发）
%% 通知类型：10
%% 通知内容：帮派ID, 帮派名称
%% -----------------------------------------------------------------
write(40000, [10, GuildId, GuildName]) ->
    GuildIdList   = integer_to_list(GuildId),
    MsgContentBin = list_to_binary([GuildIdList, ?SEPARATOR_STRING, GuildName]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<10:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 帮派升级通知（帮派群发）
%% 通知类型：11
%% 通知内容：帮派ID, 帮派名称，原等级，现等级
%% -----------------------------------------------------------------
write(40000, [11, GuildId, GuildName, OldLevel, NewLevel]) ->
    GuildIdList     = integer_to_list(GuildId),
    OldLevelList    = integer_to_list(OldLevel),
    NewLevelList    = integer_to_list(NewLevel),
    MsgContentBin   = list_to_binary([GuildIdList, ?SEPARATOR_STRING, GuildName, ?SEPARATOR_STRING, OldLevelList, ?SEPARATOR_STRING, NewLevelList]),
    MsgContentLen   = byte_size(MsgContentBin),
    Data = <<11:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 帮派降级通知（帮派群发）
%% 通知类型：12
%% 通知内容：帮派ID, 帮派名称，原等级，现等级
%% -----------------------------------------------------------------
write(40000, [12, GuildId, GuildName, OldLevel, NewLevel]) ->
    GuildIdList   = integer_to_list(GuildId),
    OldLevelList  = integer_to_list(OldLevel),
    NewLevelList  = integer_to_list(NewLevel),
    MsgContentBin = list_to_binary([GuildIdList, ?SEPARATOR_STRING, GuildName, ?SEPARATOR_STRING, OldLevelList, ?SEPARATOR_STRING, NewLevelList]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<12:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 捐献钱币通知（帮派群发）
%% 通知类型：13
%% 通知内容：角色ID, 角色名称，捐献数量
%% -----------------------------------------------------------------
write(40000, [13, PlayerId, PlayerName, Num]) ->
    PlayerIdList  = integer_to_list(PlayerId),
    NumList       = integer_to_list(Num),
    MsgContentBin = list_to_binary([PlayerIdList, ?SEPARATOR_STRING, PlayerName, ?SEPARATOR_STRING, NumList]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<13:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 捐献建设卡通知（帮派群发）
%% 通知类型：14
%% 通知内容：角色ID, 角色名称，捐献数量
%% -----------------------------------------------------------------
write(40000, [14, PlayerId, PlayerName, Num]) ->
    PlayerIdList  = integer_to_list(PlayerId),
    NumList       =  integer_to_list(Num),
    MsgContentBin = list_to_binary([PlayerIdList, ?SEPARATOR_STRING, PlayerName, ?SEPARATOR_STRING, NumList]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<14:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 申请加入（长老以上群发）
%% 通知类型：15
%% 通知内容：角色ID，角色名称
%% -----------------------------------------------------------------
write(40000, [15, PlayerId, PlayerName]) ->
    PlayerIdList  = integer_to_list(PlayerId),
    MsgContentBin = list_to_binary([PlayerIdList, ?SEPARATOR_STRING, PlayerName]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<15:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 拒绝邀请通知（仅发送给帮主副帮主）
%% 通知类型：16
%% 通知内容：角色ID，角色名称
%% -----------------------------------------------------------------
write(40000, [16, PlayerId, PlayerName]) ->
    PlayerIdList  = integer_to_list(PlayerId),
    MsgContentBin = list_to_binary([PlayerIdList, ?SEPARATOR_STRING, PlayerName]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<16:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 掉级解散通知（帮派群发）
%% 通知类型：17
%% 通知内容：帮派ID，帮派名称
%% -----------------------------------------------------------------
write(40000, [17, GuildId, GuildName]) ->
    GuildIdList   = integer_to_list(GuildId),
    MsgContentBin = list_to_binary([GuildIdList, ?SEPARATOR_STRING, GuildName]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<17:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 审批拒绝通知（仅发送给申请人）
%% 通知类型：18
%% 通知内容：帮派ID，帮派名称
%% -----------------------------------------------------------------
write(40000, [18, GuildId, GuildName]) ->
    GuildIdList   = integer_to_list(GuildId),
    MsgContentBin = list_to_binary([GuildIdList, ?SEPARATOR_STRING, GuildName]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<18:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 头衔授予通知（帮派群发）
%% 通知类型：19
%% 通知内容：角色ID，角色名称
%% -----------------------------------------------------------------
write(40000, [19, PlayerId, PlayerName, Title]) ->
    PlayerIdList  = integer_to_list(PlayerId),
    MsgContentBin = list_to_binary([PlayerIdList, ?SEPARATOR_STRING, PlayerName, ?SEPARATOR_STRING, Title]),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<19:16, MsgContentLen:16, MsgContentBin/binary>>,
    {ok, pt:pack(40000, Data)};

%% -----------------------------------------------------------------
%% 创建帮派
%% -----------------------------------------------------------------
write(40001, [Code, GuildId, GuildName, GuildPosition, MoneyLeft]) ->
    GuildNameLen = byte_size(GuildName),
    Data = <<Code:16, GuildId:32, GuildNameLen:16, GuildName/binary, GuildPosition:16, MoneyLeft:32>>,
    {ok, pt:pack(40001, Data)};

%% -----------------------------------------------------------------
%% 解散帮派
%% -----------------------------------------------------------------
write(40002, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(40002, Data)};

%% -----------------------------------------------------------------
%% 解散确认
%% -----------------------------------------------------------------
write(40003, [Code, GuildId, GuildName, ConfirmResult]) ->
    GuildNameLen = byte_size(GuildName),
    Data = <<Code:16, GuildId:32, GuildNameLen:16, GuildName/binary, ConfirmResult:16>>,
    {ok, pt:pack(40003, Data)};

%% -----------------------------------------------------------------
%% 申请加入
%% -----------------------------------------------------------------
write(40004, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(40004, Data)};

%% -----------------------------------------------------------------
%% 审批加入
%% -----------------------------------------------------------------
write(40005, Code) ->
    Data = <<Code:16>>,
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
%% 踢出帮派
%% -----------------------------------------------------------------
write(40008, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(40008, Data)};

%% -----------------------------------------------------------------
%% 退出帮派
%% -----------------------------------------------------------------
write(40009, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(40009, Data)};

%% -----------------------------------------------------------------
%% 门派列表
%% -----------------------------------------------------------------
write(40010, [Code, PageTotal, PageNo, RecordNum, Records]) ->
    Data = <<Code:16, PageTotal:16, PageNo:16, RecordNum:16, Records/binary>>,
    {ok, pt:pack(40010, Data)};

%% -----------------------------------------------------------------
%% 成员列表
%% -----------------------------------------------------------------
write(40011, [Code, PageTotal, PageNo, RecordNum, Records]) ->
    Data = <<Code:16, PageTotal:16, PageNo:16, RecordNum:16, Records/binary>>,
    {ok, pt:pack(40011, Data)};

%% -----------------------------------------------------------------
%% 申请列表
%% -----------------------------------------------------------------
write(40012, [Code, PageTotal, PageNo, RecordNum, Records]) ->
    Data = <<Code:16, PageTotal:16, PageNo:16, RecordNum:16, Records/binary>>,
    {ok, pt:pack(40012, Data)};

%% -----------------------------------------------------------------
%% 邀请列表
%% -----------------------------------------------------------------
write(40013, [Code, PageTotal, PageNo, RecordNum, Records]) ->
    Data = <<Code:16, PageTotal:16, PageNo:16, RecordNum:16, Records/binary>>,
    {ok, pt:pack(40013, Data)};

%% -----------------------------------------------------------------
%% 帮派信息
%% -----------------------------------------------------------------
write(40014, [Code, Bin]) ->
    Data = <<Code:16, Bin/binary>>,
    {ok, pt:pack(40014, Data)};

%% -----------------------------------------------------------------
%% 修改帮派宗旨
%% -----------------------------------------------------------------
write(40015, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(40015, Data)};

%% -----------------------------------------------------------------
%% 修改帮派公告
%% -----------------------------------------------------------------
write(40016, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(40016, Data)};

%% -----------------------------------------------------------------
%% 职位设置
%% -----------------------------------------------------------------
write(40017, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(40017, Data)};

%% -----------------------------------------------------------------
%% 禅让帮主
%% -----------------------------------------------------------------
write(40018, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(40018, Data)};

%% -----------------------------------------------------------------
%% 捐献帮派金
%% -----------------------------------------------------------------
write(40019, [Code, MoneyLeft]) ->
    Data = <<Code:16, MoneyLeft:32>>,
    {ok, pt:pack(40019, Data)};

%% -----------------------------------------------------------------
%% 捐献建设卡
%% -----------------------------------------------------------------
write(40020, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(40020, Data)};


%% -----------------------------------------------------------------
%% 获取捐献列表
%% -----------------------------------------------------------------
write(40021, [Code, PageTotal, PageNo, RecordNum, Records]) ->
    Data = <<Code:16, PageTotal:16, PageNo:16, RecordNum:16, Records/binary>>,
    {ok, pt:pack(40021, Data)};

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
%% 获取成员信息
%% -----------------------------------------------------------------
write(40024, [Code, Bin]) ->
    Data = <<Code:16, Bin/binary>>,
    {ok, pt:pack(40024, Data)};

%% -----------------------------------------------------------------
%% 授予头衔
%% -----------------------------------------------------------------
write(40025, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(40025, Data)};

%% -----------------------------------------------------------------
%% 修改个人备注
%% -----------------------------------------------------------------
write(40026, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(40026, Data)};


%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
write(_Cmd, _R) ->
    {ok, pt:pack(0, <<>>)}.