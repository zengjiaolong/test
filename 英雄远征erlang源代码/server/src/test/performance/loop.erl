%%%---------------------------------------------
%%% @Module  : loop
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.05.08
%%% @Description: 测试循环性能
%%% @Resule  : F2 比 F1 快20毫秒 不到10000基本可以忽略不计
%%%---------------------------------------------
-module(loop).
-compile(export_all).




do_loop([], _Data) -> ok;
do_loop([[_S] | T], Data) ->
    do_loop(T, Data).

do_loop2([], _Data, _X) -> ok;
do_loop2([[S] | T], Data, X) when S == X ->
    do_loop2(T, Data, X);
do_loop2([[_S] | T], Data, X) ->
    do_loop2(T, Data, X).

test() ->
    F1 = fun() ->
        L = [[1],[2],[3],[4],[5],[6],[7],[8],[9],[10]],
        do_loop2(L, <<16:16>>, [8]) 
    end,
    F2 = fun() ->
        L = [[1],[2],[3],[4],[5],[6],[7],[8],[9],[10]],
        do_loop(lists:delete([8], L), <<16:16>>) 
    end,
    prof:run(F1, 100000),
    prof:run(F2, 100000).
