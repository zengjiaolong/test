%% Author: Richard Jones
%% Modified: bisonwu
%% Description: Takes a serialized php object and turns it into an erlang data structure

-module(php_parser).

%%
%% Include files
%%

%%
%% Exported Functions 
%%
-export([unserialize/1]).
-export([serialize_map/1,serialize_map/2]).

%%
%% API Functions
%%

%% @spec serialize_map/1
%% @doc serialize for key-value list
serialize_map(KeyValueList) when is_list(KeyValueList)->
	serialize_map(KeyValueList,{"i","d"}).

%% @spec serialize_map/2
%% @doc serialize for key-value list
%%      result eg:"a:2:{i:7;d:1277086515;i:8;d:1277086522;}"
serialize_map(KeyValueList,{KeyType,ValType}) when is_list(KeyValueList)->
	%% eg:[{7,1277086515},{8,1277086522}]
	
	Len = length(KeyValueList),
	Items = lists:foldr(fun(X, Items) ->
					{Key,Val} = X,
					lists:concat([KeyType,":",Key,";",ValType,":",Val,";",Items])
			end, "", KeyValueList),
	lists:concat(["a:",Len,":{",Items,"}"]).


%% @spec unserialize/1
%% Usage:  {Result, Leftover} = php_parser:unserialize(…)
unserialize(S) when is_binary(S)    -> unserialize(binary_to_list(S));
unserialize(S) when is_list(S)      -> takeval(S, 1).

% Internal stuff

takeval(Str, Num) ->
	{Parsed, Remains} = takeval(Str, Num, []),
	{ lists:reverse(Parsed), Remains }.

takeval([$} | Leftover], 0, Acc)    -> {Acc, Leftover};
takeval(Str, 0, Acc)                -> {Acc, Str};
takeval([], 0, Acc)                 -> Acc;

takeval(Str, Num, Acc) ->
	{Val, Rest} = phpval(Str),
	%Lots of tracing if you enable this:
	%io:format("\nState\n Str: ~s\n Num: ~w\n Acc:~w\n", [Str,Num,Acc]),
	%io:format("-Val: ~w\n-Rest: ~s\n\n",[Val, Rest]),
	takeval(Rest, Num-1, [Val | Acc]).

%
% Parse induvidual php values.
% a "phpval" here is T:val; where T is the type code for int, object, array etc..
%

% Simple ones:
phpval([])                      -> [];
phpval([ $} | Rest ])           -> phpval(Rest);    % skip }
phpval([$N,$;|Rest])            -> {null, Rest};    % null
phpval([$b,$:,$1,$; | Rest])    -> {true, Rest};    % true
phpval([$b,$:,$0,$; | Rest])    -> {false, Rest};   % false

% r seems to be a recursive reference to something, represented as an int.
phpval([$r, $: | Rest]) ->
	{RefNum, [$; | Rest1]} = string:to_integer(Rest),
	{{php_ref, RefNum}, Rest1};

% int
phpval([$i, $: | Rest])->
	{Num, [$; | Rest1]} = string:to_integer(Rest),
	{Num, Rest1};

% double / float
% NB: php floats can be ints, and string:to_float doesn’t like that.
phpval(_X=[$d, $: | Rest]) ->
	{Num, [$; | Rest1]} = case string:to_float(Rest) of
							  {error, no_float} -> string:to_integer(Rest);
							  {N,R} -> {N,R}
						  end,
	{Num, Rest1};

% string
phpval([$s, $: | Rest]) ->
	{Len, [$: | Rest1]} =string:to_integer(Rest),
	S = list_to_binary(string:sub_string(Rest1, 2, Len+1)),
	{S, lists:nthtail(Len+3, Rest1)};

% array
phpval([$a, $: | Rest]) ->
	{NumEntries, [$:, ${ | Rest1]} =string:to_integer(Rest),
	{Array, Rest2} = takeval(Rest1, NumEntries*2),
	{arraytidy(Array), Rest2};

% object O:4:\"User\":53:{
phpval([$O, $: | Rest]) ->
	{ClassnameLen, [$: | Rest1]} =string:to_integer(Rest),
	% Rest1: "classname":NumEnt:{..
	Classname = string:sub_string(Rest1, 2, ClassnameLen+1),
	Rest1b = lists:nthtail(ClassnameLen+3, Rest1),
	{NumEntries, [$:, ${ | Rest2]} = string:to_integer(Rest1b),
	{Classvals, Rest3} = takeval(Rest2, NumEntries*2),
	{{class, Classname, arraytidy(Classvals)}, Rest3}.

%%
%% Helpers:
%%

% convert [ k1,v1,k2,v2,k3,v3 ] into [ {k1,v2}, {k2,v2}, {k3,v3} ]
arraytidy(L) ->
	lists:reverse(lists:foldl(fun arraytidy/2, [], L)).

arraytidy(El, [{key___partial, K} | L]) -> [{atomize(K), El} | L];

arraytidy(El, L) -> [{key___partial, El} | L].

%% Make properties or keys into atoms
atomize(K) when is_binary(K) ->
	atomize(binary_to_list(K));
atomize(K) when is_list(K) ->
	list_to_atom(string:to_lower(K));
atomize(K) -> K.
