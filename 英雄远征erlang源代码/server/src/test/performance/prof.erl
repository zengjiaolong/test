%%%---------------------------------------------
%%% @Module  : prof
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.05.03
%%% @Description: 性能测试工具
%%%---------------------------------------------
-module(prof).
-compile(export_all).

%%性能测试
%%Fun:函数
%%Loop:执行次数
run(Fun, Loop) -> 
    statistics(wall_clock),
    for(1, Loop, Fun),
    {_, T1} = statistics(wall_clock),
    io:format("~p loops, using time: ~pms~n", [Loop, T1]),
    ok.

for(Max, Max , Fun) ->
    Fun();
for(I, Max, Fun) -> 
    Fun(), for(I + 1, Max, Fun).
        
    
