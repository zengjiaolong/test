%%%------------------------------------
%%% @Module     : lib_statistics
%%% @Author     : lzz
%%% @Created    : 2010.12.24
%%% @Description: 综合统计函数
%%%------------------------------------
-module(lib_statistics).
-export(
   	[
		statistics_min/0	 
	]
).

%% 统计每分钟在线并写入数据库
statistics_min() ->
	Online = misc_admin:get_online_count(num),
	Rec_time = util:unixtime(),
	db_agent:add_online_min(Rec_time, Online).
