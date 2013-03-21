%%%----------------------------------------
%%% @Module  : sd_alarm_handler
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.04.15
%%% @Description: 警报
%%%----------------------------------------

-module(sd_alarm_handler).
-behaviour(gen_event).
-include("common.hrl").

%%gen_envent callbacks.
-export([init/1, handle_event/2, handle_call/2, handle_info/2, terminate/2, code_change/3]).   

init(Args) ->   
	?DEBUG("sd_alarm_handler init : ~p.", [Args]),   
	{ok, Args}.   
  
handle_event({set_alarm, From}, _State) ->   
    ?DEBUG("sd depot clear by ~p started.", [From]),   
	{ok, _State};   
 
handle_event({clear_alarm, From}, _State) ->   
	?DEBUG("sd depot clear by ~p done.", [From]),   
	{ok, _State};   
  
handle_event(Event, State) ->   
	?DEBUG("unmatched event: ~p.", [Event]),   
	{ok, State}.   
  
handle_call(_Req, State) ->   
	{ok, State, State}.   
       
handle_info(_Info, State) ->   
	{ok, State}.   
  
terminate(_Reason, _State) ->   
	ok.   

code_change(_OldVsn, State, _Extra) ->   
    {ok, State}.   
