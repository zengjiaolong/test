%%%--------------------------------------
%%% @Module  : pp_account
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description:用户账户管理
%%%--------------------------------------
-module(pp_account).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").
-compile(export_all).

%%登陆验证
handle(10000, [], Data) ->
	Ret =
    	try is_bad_pass(Data) of
        	true ->  true;
        	_ -> 
				case config:get_strict_md5(server) of
					1 -> false;
					_ -> true
				end
    	catch
        	_:_ -> false
    	end,
	case Ret of
		true ->
			[Sn, Accid, Accname, _Tstamp, _Ts] = Data,
			L = lib_account:get_role_list(Sn, Accid, Accname),
            {true, L};	
		_ -> false
	end;

%% 获取角色列表 此协议暂时没调用
handle(10002, Socket, [Accid, Accname]) when is_integer(Accid), is_list(Accname) ->
    L = lib_account:get_role_list(Accid, Accname),
    {ok, BinData} = pt_10:write(10002, L),
    lib_send:send_one(Socket, BinData);

%% ！注意 创建角色已转交Php处理，一般情况下不再触发，勿修改代码。
%% 创建角色 
handle(10003, Socket, [Accid, Accname, Sn, Realm, Career, Sex, Name]) when is_integer(Accid), is_list(Accname), is_integer(Sn),is_list(Name)->
	L = lib_account:get_role_list(Sn, Accid, Accname),
	case length(L) >= 1 of 
		true ->
            {ok, BinData} = pt_10:write(10003, [6,0]),  %% 用户已经创建角色
            lib_send:send_one(Socket, BinData);	
		false ->
    		case validate_name([Sn, Name]) of  %% 角色名合法性检测
       			{false, Msg} ->
            			{ok, BinData} = pt_10:write(10003, [Msg, 0]),
            			lib_send:send_one(Socket, BinData);
        		true ->
            		case lib_account:create_role(Accid, Accname, Sn, Name, Realm, Career, Sex, user) of
                		{true, RoleId} ->
                    		%%创建角色成功
                    		{ok, BinData} = pt_10:write(10003, [1, RoleId]),
                    		lib_send:send_one(Socket, BinData);
                		false ->
                    		%%角色创建失败
                    		{ok, BinData} = pt_10:write(10003, [0, 0]),
                    		lib_send:send_one(Socket, BinData)
            		end
    		end
	end,
	ok;

%% 删除角色 
handle(10005, Socket, [Pid, Accid]) ->
    case lib_account:delete_role(Pid, Accid) of
        true ->
            {ok, BinData} = pt_10:write(10005, 1),
            lib_send:send_one(Socket, BinData);
        false ->
            {ok, BinData} = pt_10:write(10005, 0),
            lib_send:send_one(Socket, BinData)
    end;

%%心跳包
handle(10006, Socket, _R) ->
    {ok, BinData} = pt_10:write(10006, []),
    lib_send:send_one(Socket, BinData);

%%子socket返回状态
handle(10008,Socket,[Code,N]) ->
	{ok,BinData} = pt_10:write(10008,[Code,N]),
	lib_send:send_one(Socket,BinData);

%% 按照accid创建一个角色，或自动分配一个角色
handle(10010, _Socket, [Sn, Accid])->
	get_player_id(Sn, Accid);

handle(10020, _Socket, _R) ->
    lib_account:getin_createpage();

handle(_Cmd, _Socket, _Data) ->
    {error, "handle_account no match"}.

%%根据accid取id。
get_player_id(Sn, Accid)->
	PlayerInfo = 
		case Accid =:= 0 of
			true -> [];
			false -> db_agent:get_id_by_accid(Accid,Sn)
		end,
    case PlayerInfo of
        [Id, Nickname]->
			{true, Accid, Id,  Nickname};
        []->
			Ret = misc:get_http_content(config:get_guest_account_url(server)),
			if Ret =:= "" andalso Sn /= 9999  ->
				   	{true, 0, 0,  <<>>};
			   Sn == 9999 ->
					Realm = 100,
					Career = 1 ,
            		Sex =1,
					Name = tool:to_binary(lists:concat(["GUEST-",Accid])),
					Result = 
            		case lib_account:create_role(Accid, Name, Sn, Name, Realm, Career, Sex, guest) of
                		{true, RoleId} ->
							{true, Accid, RoleId, Name};
                		false ->
							{true, 0, 0,  <<>>}
            		end,
					Result;
			   true ->
				   try
				   	[New_Accid, Name] = string:tokens(Ret, "/"),
					NewAccid = tool:to_integer(New_Accid),
            		Realm = 100, %%util:rand(1,3),
            		Career = util:rand(1,5),
            		Sex = util:rand(1,2),
					Result = 
            		case lib_account:create_role(NewAccid, Name, Sn, Name, Realm, Career, Sex, guest) of
                		{true, RoleId} ->
							{true, NewAccid, RoleId, Name};
                		false ->
							{true, 0, 0,  <<>>}
            		end,
					Result
				  catch
						_:_ -> {true, 0, 0,  <<>>}
				  end
			   end
    end.

%%通行证验证
is_bad_pass([_Sn, Accid, Accname, Tstamp, Ts]) ->	
	Now = util:unixtime(),
	Platform = config:get_platform_name(),
	if
		Now - Tstamp > 86400 andalso Platform /= "dev" -> 
			false;
		true ->
		    Md5 = integer_to_list(Accid) ++ Accname ++ integer_to_list(Tstamp) ++ ?TICKET,
		    Hex = util:md5(Md5),
		    Hex == Ts
	end.

%% 角色名合法性检测
validate_name([Sn, Name]) ->
    validate_name(len, [Sn, Name]).

%% 角色名合法性检测:长度
validate_name(len, [Sn, Name]) ->
    case asn1rt:utf8_binary_to_list(list_to_binary(Name)) of
        {ok, CharList} ->
            Len = string_width(CharList),   
            case Len < 11 andalso Len > 1 of
                true ->
					case name_ver(CharList) of
						true ->
                    		validate_name(existed, [Sn,Name]);
						_ ->
							{false, 4}
					end;
                false ->
                    %%角色名称长度为1~5个汉字
                    {false, 5}
			end;
        {error, _Reason} ->
            %%非法字符
            {false, 4}
    end; 

%%判断角色名是否已经存在
%%Name:角色名
validate_name(existed, [_Sn, Name]) ->
    case lib_player:is_exists_name(Name) of
        true ->
            %角色名称已经被使用
            {false, 3};    
        false ->
            validate_name(sen_words, Name)
    end;

%%是否包含敏感词
%%Name:角色名
validate_name(sen_words, Name) ->
    case lib_words_ver:words_ver_name(Name) of
        true ->
			true;  
        false ->
            %包含敏感词
            {false, 8} 
    end;

validate_name(_, _Name) ->
    {false, 2}.

%% 字符宽度，1汉字=2单位长度，1数字字母=1单位长度
string_width(String) ->
    string_width(String, 0).
string_width([], Len) ->
    Len;
string_width([H | T], Len) ->
    case H > 255 of
        true ->
            string_width(T, Len + 2);
        false ->
            string_width(T, Len + 1)
    end.

name_ver(Names_for) ->
	Sumxx = lists:foldl(fun(Name_Char, Sum)->
									if
										Name_Char =:= 8226 orelse Name_Char < 48 orelse (Name_Char > 57 andalso Name_Char < 65) orelse (Name_Char > 90 andalso Name_Char < 95) orelse (Name_Char > 122 andalso Name_Char < 130) ->
											Sum + 1;
										true -> Sum + 0
									end
								end,
							0, Names_for),
	if 
		Sumxx =:= 0 ->
			true;
		true ->
			false
	end.
