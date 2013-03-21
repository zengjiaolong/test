%% Author: lzz
%% Created: 2010-12-15
%% Description: 传送
-module(data_deliver).

%%
%% Include files
%%


%%
%% Exported Functions
%%
-compile(export_all).

%% API Functions
%%
%%	get_delivers(Tar_scid)
%% 获取传送相关数据 Tar_scid:目的地场景ID


get_delivers(Tar_scid) ->
	case Tar_scid of
		200 -> {20,2000,[51,170]};
		250 -> {20,2000,[51,166]};
		280 -> {20,2000,[55,163]};
		300 -> {20,2000,[102,162]};
		_ -> {error,0,[0,0]}
	end.
