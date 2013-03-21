%% Author: lzz
%% Created: 2010-11-29
%% Description: 敏感词处理
-module(lib_words_ver).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").


-export([words_ver/1, words_filter/1, words_ver_name/1]).

%%
%% API Functions
%%
%% -----------------------------------------------------------------
%% 敏感词处理
%% -----------------------------------------------------------------

words_filter(Words_for_filter) -> 
	Words_List = data_words:get_words_verlist(),
	binary:bin_to_list(lists:foldl(fun(Kword, Words_for_filter0)->
										   re:replace(Words_for_filter0,Kword,"*",[global,caseless,{return, binary}])
								   end,
								   Words_for_filter,Words_List)).

words_ver(Words_for_ver) ->
	Words_List = data_words:get_words_verlist(),
	words_ver_i(Words_List , Words_for_ver).
	
words_ver_i([],_Words_for_ver) -> 
	true;

words_ver_i([W|L], Words_for_ver) ->
    case re:run(Words_for_ver, W, [caseless]) of
    	nomatch -> words_ver_i(L , Words_for_ver);
    	_-> false
    end.

words_ver_name(Words_for_ver) ->
	Words_List = data_words:get_words_verlist_name(),
	words_ver_i_name(Words_List, Words_for_ver).
	
words_ver_i_name([], _Words_for_ver) -> 
    true;

words_ver_i_name([W|L], Words_for_ver) ->
    case re:run(Words_for_ver, W, [caseless]) of
    	nomatch -> words_ver_i_name(L, Words_for_ver);
    	_-> false
    end.