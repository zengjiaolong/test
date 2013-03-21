-module(robot_others).

-compile(export_all).
-include("common.hrl").
-include("record.hrl").

handle(PlayerId, Socket) -> 
 	Cmds = [40010], %%, 28002, 28003, 28006, 28007, 28002, 28002, 28002],
 	Cmd = lists:nth(random:uniform(length(Cmds)), Cmds),
%% io:format("~s_~p: ~p~n", [misc:time_format(now()), ?MODULE, [Cmd, PlayerId, Socket]]),	
	handle_action(Cmd, PlayerId, Socket),
	ok.

handle_action(40010, _PlayerId, Socket) ->
    Data = <<0:16, 0:16, 0:16>>,
	gen_tcp:send(Socket,robot:pack(40010, Data)),
	ok;
 
handle_action(28002, _PlayerId, Socket) ->
%% 	io:format("handle_action open box", []),
	HoleType = random:uniform(3),
	OpenType = random:uniform(3),
    Data = <<HoleType:16, OpenType:16>>,	
	gen_tcp:send(Socket,robot:pack(28002, Data)),
	ok;

handle_action(28003, _PlayerId, Socket) ->
%% 	io:format("handle_action get  box warehouse", []),
    Data = <<>>,	
	gen_tcp:send(Socket,robot:pack(28003, Data)),
	ok;
handle_action(28006, _PlayerId, Socket) ->
%% 	io:format("handle_action discard the goods", []),
    Data = <<>>,	
	gen_tcp:send(Socket,robot:pack(28006, Data)),
	ok;
handle_action(28007, _PlayerId, Socket) ->
%% 	io:format("handle_action goods from box to bag", []),
    Data = <<>>,	
	gen_tcp:send(Socket,robot:pack(28007, Data)),
	ok;

handle_action(_Cmd, _PlayerId, _Socket) ->
	ok.