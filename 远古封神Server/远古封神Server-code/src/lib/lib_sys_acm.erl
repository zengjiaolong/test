%% Author: lzz
%% Created: 2010-12-18
%% Description: 系统公告处理
-module(lib_sys_acm).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").


-export([init_sys_acm/0, cancel_sys_acm/0,more_sys_acm/0,del_sys_acm/0,broadcast_acm/1]).


-define(MIN_ACM_IVL,           30).  %% 最小播送间隔（单位，秒）
%% -define(MIN_ACM_IVL,           3).  %% 最小播送间隔（单位，秒）测试

%%
%% API Functions
%% 重载入系统公告
more_sys_acm() ->
	Pid = mod_rank:get_mod_rank_pid(),
	gen_server:cast(Pid, {'MORE_SYS_ACM'}).

%% 删除系统公告定时器
del_sys_acm() ->
	Pid = mod_rank:get_mod_rank_pid(),
	gen_server:cast(Pid, {'CANCLE_SYS_ACM'}).

%% 播报某条消息
broadcast_acm(Id) ->	
	Pid = mod_rank:get_mod_rank_pid(),
	gen_server:cast(Pid,{'BROADCAST_ACM',Id}).
%%
%% -----------------------------------------------------------------
%% 系统公告处理
%% -----------------------------------------------------------------
%% 初始化系统公告
%% 内部函数
init_sys_acm() ->
	misc:cancel_timer(acm_init_timer),
	Acm_init_timer = erlang:send_after(60 * 1000, self(), {sys_acm}),
	put(acm_init_timer, Acm_init_timer).

%% 初始化系统公告
%% 取消
cancel_sys_acm() ->
	case get(acm_timer_group) of
		undefined ->
			skip;
		Group ->
			F = fun(Ref) ->
						erlang:cancel_timer(Ref)
				end,
			lists:foreach(F, Group),
			put(acm_timer_group,undefined)
	end,
	misc:cancel_timer(acm_init_timer).