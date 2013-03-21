%%%-----------------------------------
%%% @Module  : util
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 公共函数
%%%-----------------------------------
-module(util).
-include("common.hrl").
-include("record.hrl").
-compile(export_all).

%% 在List中的每两个元素之间插入一个分隔符
implode(_S, [])->
	[<<>>];
implode(S, L) when is_list(L) ->
    implode(S, L, []).
implode(_S, [H], NList) ->
    lists:reverse([thing_to_list(H) | NList]);
implode(S, [H | T], NList) ->
    L = [thing_to_list(H) | NList],
    implode(S, T, [S | L]).

%% 字符->列
explode(S, B)->
    re:split(B, S, [{return, list}]).
explode(S, B, int) ->
    [list_to_integer(Str) || Str <- explode(S, B), length(Str) > 0].

thing_to_list(X) when is_integer(X) -> integer_to_list(X);
thing_to_list(X) when is_float(X)   -> float_to_list(X);
thing_to_list(X) when is_atom(X)    -> atom_to_list(X);
thing_to_list(X) when is_binary(X)  -> binary_to_list(X);
thing_to_list(X) when is_list(X)    -> X.

%% 日志记录函数
log(T, F, A, Mod, Line) ->
    {ok, Fl} = file:open("logs/error_log.txt", [write, append]),
    Format = list_to_binary("#" ++ T ++" ~s[~w:~w] " ++ F ++ "\r\n~n"),
    {{Y, M, D},{H, I, S}} = erlang:localtime(),
    Date = list_to_binary([integer_to_list(Y),"-", integer_to_list(M), "-", integer_to_list(D), " ", integer_to_list(H), ":", integer_to_list(I), ":", integer_to_list(S)]),
    io:format(Fl, unicode:characters_to_list(Format), [Date, Mod, Line] ++ A),
    file:close(Fl).    

%% 取得当前的unix时间戳
unixtime() ->
    {MegaSecs, Secs, _MicroSecs} = erlang:now(),
 	MegaSecs * 1000000 + Secs.

longunixtime() ->
	{MegaSecs, Secs, MicroSecs} = erlang:now(),
    (MegaSecs * 1000000000000 + Secs * 1000000 + MicroSecs) div 1000.

%% 转换成HEX格式的md5
md5(S) ->
    lists:flatten([io_lib:format("~2.16.0b",[N]) || N <- binary_to_list(erlang:md5(S))]).

%% 产生一个介于Min到Max之间的随机整数
rand(Same, Same) -> Same;
rand(Min, Max) ->
    M = Min - 1,
	if
		Max - M =< 0 ->
			0;
		true ->
    		%% 如果没有种子，将从核心服务器中去获取一个种子，以保证不同进程都可取得不同的种子
    		case get("rand_seed") of
        		undefined ->
            		RandSeed = mod_rand:get_seed(),
            		random:seed(RandSeed),
            		put("rand_seed", RandSeed);
        		_ -> skip
    		end,
    		%% random:seed(erlang:now()),
			random:uniform(Max - M) + M
	end.

%%随机从集合中选出指定个数的元素length(List) >= Num
%%[1,2,3,4,5,6,7,8,9]中选出三个不同的数字[1,2,4]
get_random_list(List,Num) ->
	ListSize = length(List),
	F = fun(N,List1) ->
				Random = rand(1,(ListSize-N+1)),
				Elem = lists:nth(Random, List1),
				List2 = lists:delete(Elem, List1),
				List2
		end,
	Result = lists:foldl(F, List, lists:seq(1, Num)),
	List -- Result.

%% 随机生成N字节的字符串
random_string(N) -> 
	random_seed(), random_string(N, []).

random_string(0, D) -> 
	D;
random_string(N, D) ->
	random_string(N-1, [random:uniform(26)-1+$a|D]).

random_seed() ->
	{_,_,X} = erlang:now(),
	{H,M,S} = time(),
	H1 = H * X rem 32767,
	M1 = M * X rem 32767,
	S1 = S * X rem 32767,
	put(random_seed, {H1,M1,S1}).

%%从列表[{a,7},{b,8},{c,90},{d,100}],a为7%概率,中根据概率选出指定数目不重复的元素列表
%%注意Num不能大于lenth(List)
get_random_list_probability(List,Num) ->
	Len = length(List),
	if Num >= Len ->
		[];
		true ->
			F = fun(Elem,ProbabilityValue) ->
						lists:duplicate(ProbabilityValue, Elem)
				end,	
			Result1 = lists:flatten([F(Elem,ProbabilityValue) || {Elem,ProbabilityValue} <- List]),
			ProbabilityList = lists:reverse(lists:sort([ProbabilityValue || {_Elem,ProbabilityValue} <- List])),
			MaxProbabilityValue = lists:sum([lists:nth(N, ProbabilityList) || N <- lists:seq(1, Num)]),
			NewNum = 
				case Num of
					1 -> 1;
					Len -> Len;
					_ ->
						Num+MaxProbabilityValue-length(List)+2
				end,
			Result2 = get_random_list(Result1, NewNum),
			Result3 = lists:usort(Result2),
			Result4 = get_random_list(Result3,Num),
			Result4
	end.

%% 向上取整
ceil(N) ->
    T = trunc(N),
    case N == T of
        true  -> T;
        false -> 1 + T
    end.

%% 向下取整
floor(X) ->
    T = trunc(X),
    case (X < T) of
        true -> T - 1;
        _ -> T
    end.

 sleep(T) ->
    receive
    after T -> ok
    end.

 sleep(T, F) ->
    receive
    after T -> F()
    end.

get_list([], _) ->
    [];
get_list(X, F) ->
    F(X).

%% for循环
for(Max, Max, F) ->
    F(Max);
for(I, Max, F)   ->
    F(I),
    for(I+1, Max, F).

%% 带返回状态的for循环
%% @return {ok, State}
for(Max, Min, _F, State) when Min<Max -> 
	{ok, State};
for(Max, Max, F, State) ->
	F(Max, State);

for(I, Max, F, State)   -> 
	{ok, NewState} = F(I, State), 
	for(I+1, Max, F, NewState).


for_new(Min, Max, _F, State) when (Min > Max) -> 
	{ok, State};
for_new(Min, Max, F, State) -> 
	{ok, NewState} = F(Min, State), 
	for_new(Min+1, Max, F, NewState).


%% term序列化，term转换为string格式，e.g., [{a},1] => "[{a},1]"
term_to_string(Term) ->
    binary_to_list(list_to_binary(io_lib:format("~p", [Term]))).

%% term序列化，term转换为bitstring格式，e.g., [{a},1] => <<"[{a},1]">>
term_to_bitstring(Term) ->
    erlang:list_to_bitstring(io_lib:format("~p", [Term])).

%% term反序列化，string转换为term，e.g., "[{a},1]"  => [{a},1]
string_to_term(String) ->
    case erl_scan:string(String++".") of
        {ok, Tokens, _} ->
            case erl_parse:parse_term(Tokens) of
                {ok, Term} -> Term;
                _Err -> undefined
            end;
        _Error ->
            undefined
    end.

%%将列表转换为string [a,b,c] -> "a,b,c"
list_to_string(List) ->
	case List == [] orelse List == "" of
		true -> "";
		false ->
			F = fun(E) ->
						tool:to_list(E)++","
				end,
			L1 = [F(E)||E <- List] ,
			L2 = lists:concat(L1),
			string:substr(L2,1,length(L2)-1)
	end.

%% term反序列化，bitstring转换为term，e.g., <<"[{a},1]">>  => [{a},1]
bitstring_to_term(undefined) -> undefined;
bitstring_to_term(BitString) ->
    string_to_term(binary_to_list(BitString)).


%% 时间函数
%% -----------------------------------------------------------------
%% 根据1970年以来的秒数获得日期
%% -----------------------------------------------------------------
seconds_to_localtime(Seconds) ->
    DateTime = calendar:gregorian_seconds_to_datetime(Seconds+?DIFF_SECONDS_0000_1900),
    calendar:universal_time_to_local_time(DateTime).

%% -----------------------------------------------------------------
%% 判断是否同一天
%% -----------------------------------------------------------------
is_same_date(Seconds1, Seconds2) ->
	NDay = (Seconds1 + 8 * 3600) div 86400,
	ODay = (Seconds2 + 8 * 3600) div 86400,
	NDay =:= ODay.
%%     {{Year1, Month1, Day1}, _Time1} = seconds_to_localtime(Seconds1),
%%     {{Year2, Month2, Day2}, _Time2} = seconds_to_localtime(Seconds2),
%%     if ((Year1 == Year2) andalso (Month1 == Month2) andalso (Day1 == Day2)) -> true;
%%         true -> false
%%     end.

%% -----------------------------------------------------------------
%% 判断是否同一星期
%% -----------------------------------------------------------------
is_same_week(Seconds1, Seconds2) ->
    {{Year1, Month1, Day1}, Time1} = seconds_to_localtime(Seconds1),
    % 星期几
    Week1  = calendar:day_of_the_week(Year1, Month1, Day1),
    % 从午夜到现在的秒数
    Diff1  = calendar:time_to_seconds(Time1),
    Monday = Seconds1 - Diff1 - (Week1-1)*?ONE_DAY_SECONDS,
    Sunday = Seconds1 + (?ONE_DAY_SECONDS-Diff1) + (7-Week1)*?ONE_DAY_SECONDS,
    if ((Seconds2 >= Monday) and (Seconds2 < Sunday)) -> true;
        true -> false
    end.

%% -----------------------------------------------------------------
%% 获取当天0点和第二天0点
%% -----------------------------------------------------------------
get_midnight_seconds(Seconds) ->
    {{_Year, _Month, _Day}, Time} = seconds_to_localtime(Seconds),
    % 从午夜到现在的秒数
    Diff   = calendar:time_to_seconds(Time),
    % 获取当天0点
    Today  = Seconds - Diff,
    % 获取第二天0点
    NextDay = Seconds + (?ONE_DAY_SECONDS-Diff),
    {Today, NextDay}.

%% 获取下一天开始的时间
get_next_day_seconds(Now) ->
	{{_Year, _Month, _Day}, Time} = util:seconds_to_localtime(Now),
    % 从午夜到现在的秒数
   	Diff = calendar:time_to_seconds(Time),
	Now + (?ONE_DAY_SECONDS - Diff).

%% -----------------------------------------------------------------
%% 计算相差的天数
%% -----------------------------------------------------------------
get_diff_days(Seconds1, Seconds2) ->
    {{Year1, Month1, Day1}, _} = seconds_to_localtime(Seconds1),
    {{Year2, Month2, Day2}, _} = seconds_to_localtime(Seconds2),
    Days1 = calendar:date_to_gregorian_days(Year1, Month1, Day1),
    Days2 = calendar:date_to_gregorian_days(Year2, Month2, Day2),
    DiffDays=abs(Days2-Days1),
    DiffDays + 1.

%% 获取从午夜到现在的秒数
get_today_current_second() ->
	{_, Time} = calendar:now_to_local_time(now()),
	calendar:time_to_seconds(Time).

%%判断今天星期几
get_date() ->
	calendar:day_of_the_week(date()).

%%获取上一周的开始时间和结束时间
get_pre_week_duringtime() ->
	OrealTime =  calendar:datetime_to_gregorian_seconds({{1970,1,1}, {0,0,0}}),
	{Year,Month,Day} = date(),
	CurrentTime = calendar:datetime_to_gregorian_seconds({{Year,Month,Day}, {0,0,0}})-OrealTime-8*60*60,%%从1970开始时间值
	WeekDay = calendar:day_of_the_week(Year,Month,Day),
	Day1 = 
	case WeekDay of %%上周的时间
		1 -> 7;
		2 -> 7+1;
		3 -> 7+2;
		4 -> 7+3;
		5 -> 7+4;
		6 -> 7+5;
		7 -> 7+6
	end,
	StartTime = CurrentTime - Day1*24*60*60,
	EndTime = StartTime+7*24*60*60,
	{StartTime,EndTime}.
	
%%获取本周的开始时间和结束时间
get_this_week_duringtime() ->
	OrealTime =  calendar:datetime_to_gregorian_seconds({{1970,1,1}, {0,0,0}}),
	{Year,Month,Day} = date(),
	CurrentTime = calendar:datetime_to_gregorian_seconds({{Year,Month,Day}, {0,0,0}})-OrealTime-8*60*60,%%从1970开始时间值
	WeekDay = calendar:day_of_the_week(Year,Month,Day),
	Day1 = 
	case WeekDay of %%上周的时间
		1 -> 0;
		2 -> 1;
		3 -> 2;
		4 -> 3;
		5 -> 4;
		6 -> 5;
		7 -> 6
	end,
	StartTime = CurrentTime - Day1*24*60*60,
	EndTime = StartTime+7*24*60*60,
	{StartTime,EndTime}.


%%以e=2.718281828459L为底的对数
lnx(X) ->
	math:log10(X) / math:log10(?E).

check_same_day(Timestamp)->
	NDay = (util:unixtime()+8*3600) div 86400,
	ODay = (Timestamp+8*3600) div 86400,
	NDay=:=ODay.

%%对list进行去重，排序
%%Replicat 0不去重，1去重
%%Sort 0不排序，1排序
filter_list(List,Replicat,Sort) ->
	if Replicat == 0 andalso Sort == 0 ->
		   List;
	   true ->
		   if Replicat == 1 andalso Sort == 1 ->
				  lists:usort(List);
			  true ->
				   if Sort == 1 ->
						  lists:sort(List);
					  true ->
						  lists:reverse(filter_replicat(List,[]))
				   end
		   end
	end.

%%list去重
filter_replicat([],List) ->
	List;
filter_replicat([H|Rest],List) ->
	Bool = lists:member(H, List),
	List1 = 
	if Bool == true ->
		   [[]|List];
	   true ->
		   [H|List]
	end,
	List2 = lists:filter(fun(T)-> T =/= [] end, List1),
	filter_replicat(Rest,List2).

%%找出俩list的公共部分
get_same_part(List1,List2)->
	F=fun(Id)->
			  lists:member(Id,List2)
	  end,
	lists:filter(F, List1).

%%将列表中的某一元素用新元素代替
replace_list_emement(List,Order,NewElement) ->
	if
		Order == 1 ->
			[_H | _Rest] = List,
			[NewElement | _Rest];
		Order == length(List) ->
			NewList = lists:reverse(List),
			[_H | _Rest] = NewList,
			NewList1 = [NewElement | _Rest],
			lists:reverse(NewList1);
		true ->
			{List1,List2} = lists:split(Order-1, List),
			[_H | _Rest] = List2,
			NewResult = [NewElement | _Rest],
			lists:append(List1,NewResult)
	end.

%%查找列表中是否有元素在别一列表中
find_repeat_elem(List1,List2) ->
	F =  fun(Elem) ->
				case lists:keyfind(Elem, 1, List2) of
					false -> [];
					_ -> Elem	
				end
		 end,
	Result = [F(Elem) || Elem <- List1],
	lists:filter(fun(X) -> X =/= [] end, Result).

%% 概率命中
%% @return true | false
rand_test(Rate) ->
    R = round(Rate * 100),
    case rand(1, 10000) of
        N when N =< R ->
            true;
        _ ->
            false
    end.

%%随机打乱列表顺序
random_list(List) ->
	if List == [] ->
		   [];
	   true ->
		   Len = length(List),
		   OrderList = lists:seq(1, Len),
		   F = fun(_Elem,[OrderList1,Result]) ->
					   [NewElem] = util:get_random_list(OrderList1,1),
					   NewOrderList = lists:delete(NewElem, OrderList1),
					   [NewOrderList,[lists:nth(NewElem, List) | Result]]
			   end,
		   [_,NewResult] =  lists:foldl(F,[OrderList,[]], List),
		   NewResult
	end.

%%查找元素在列表中的位置
get_elem_pos(Elem,List) ->
	get_elem_pos(Elem,List,0,1).

get_elem_pos(Elem,[H|Rest],_HasFind,Pos) ->
	if H == Elem -> 
		   get_elem_pos(Elem,[],1,Pos);
	   true ->
		   get_elem_pos(Elem,Rest,0,Pos+1)
	end;
get_elem_pos(_Elem,[],HasFind,Pos) ->
	if HasFind == 0 ->
		   0;
	   true ->
		   Pos
	end.

%%重载资源配置
reload(Type,Data)-> 
	lists:map(fun(N)->rpc:call(N,application,set_env,[server,Type,Data]) end,nodes()).


escape_uri(S) when is_list(S) ->
    escape_uri(unicode:characters_to_binary(S));
escape_uri(<<C:8, Cs/binary>>) when C >= $a, C =< $z ->
    [C] ++ escape_uri(Cs);
escape_uri(<<C:8, Cs/binary>>) when C >= $A, C =< $Z ->
    [C] ++ escape_uri(Cs);
escape_uri(<<C:8, Cs/binary>>) when C >= $0, C =< $9 ->
    [C] ++ escape_uri(Cs);
escape_uri(<<C:8, Cs/binary>>) when C == $. ->
    [C] ++ escape_uri(Cs);
escape_uri(<<C:8, Cs/binary>>) when C == $- ->
    [C] ++ escape_uri(Cs);
escape_uri(<<C:8, Cs/binary>>) when C == $_ ->
    [C] ++ escape_uri(Cs);
escape_uri(<<C:8, Cs/binary>>) ->
    escape_byte(C) ++ escape_uri(Cs);
escape_uri(<<>>) ->
    "".

escape_byte(C) ->
    "%" ++ hex_octet(C).

hex_octet(N) when N =< 9 ->
    [$0 + N];
hex_octet(N) when N > 15 ->
    hex_octet(N bsr 4) ++ hex_octet(N band 15);
hex_octet(N) ->
    [N - 10 + $a].

%%urlencode
url_encode([H|T]) ->
    if
        H >= $a, $z >= H ->
            [H|url_encode(T)];
        H >= $A, $Z >= H ->
            [H|url_encode(T)];
        H >= $0, $9 >= H ->
            [H|url_encode(T)];
        H == $_; H == $.; H == $-; H == $/; H == $: -> % FIXME: more..
            [H|url_encode(T)];
        true ->
            case integer_to_hex(H) of
                [X, Y] ->
                    [$%, X, Y | url_encode(T)];
                [X] ->
                    [$%, $0, X | url_encode(T)]
            end
     end;	
url_encode([]) ->
    [].

integer_to_hex(I) ->
    case catch erlang:integer_to_list(I, 16) of
        {'EXIT', _} ->
            old_integer_to_hex(I);
        Int ->
            Int
    end.
old_integer_to_hex(I) when I<10 ->
    integer_to_list(I);
old_integer_to_hex(I) when I<16 ->
    [I-10+$A];
old_integer_to_hex(I) when I>=16 ->
    N = trunc(I/16),
    old_integer_to_hex(N) ++ old_integer_to_hex(I rem 16).
