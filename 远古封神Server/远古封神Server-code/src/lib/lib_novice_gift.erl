%% Author: Administrator
%% Created: 2011-10-18
%% Description: TODO: Add description to lib_novice_gift
-module(lib_novice_gift).


%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
%%
%% Exported Functions
%%
-compile(export_all).
%%
%% API Functions
%%
init_novice_gift(PlayerId,Lv)->
	case db_agent:select_novice_gift(PlayerId) of
		[]->
			if Lv=:=1->
				   NowTime = util:unixtime(),
				   {_,Id} = db_agent:init_novice_gift(PlayerId,NowTime),
				   Data=[Id,PlayerId,0,0,0,0,0,0,NowTime],
				   Gift =list_to_tuple([ets_novice_gift|Data]),
				   update_novice_gift(Gift),
				   ok;
			   true->skip
			end;
		Data->
			Gift =list_to_tuple([ets_novice_gift|Data]),
			update_novice_gift(Gift),
			ok
	
	end.

check_novice_gift(PlayerId,Lv,Career)->
	case select_novice_gift(PlayerId) of
		[]->
			[0,0,[]];
		[Gift]->
			GiftInfo = [{9,Gift#ets_novice_gift.mark8},{14,Gift#ets_novice_gift.mark14},
						{18,Gift#ets_novice_gift.mark18},{22,Gift#ets_novice_gift.mark22},
						{26,Gift#ets_novice_gift.mark26},{31,Gift#ets_novice_gift.mark31}],
			{NewLv,Mark} =  check_lv(GiftInfo,Lv,{0,0}),
			Goods = gift(NewLv,Career),
			[NewLv,Mark,Goods]
	end.
check_lv([],_Lv,Info)->Info;
check_lv([Gift|GiftInfo],Lv,Info)->
	{NewLv,Mark} = Gift,
	if Mark =:=1->
		   check_lv(GiftInfo,Lv,Info);
	   true->
		   {NewLv,Mark}
	end.

%%领取礼包（1成功，2数据异常，3等级不足，不能领取，4该等级的物品已经领取，5背包空间不足，不能领取，6系统繁忙，请稍后重试
get_novice_gift(PlayerStatus,Lv)->
	case lists:member(Lv,[9,14,18,22,26,31]) of
		false->{error,2,[]};
		true->
			if PlayerStatus#player.lv < Lv->{error,3,[]}; 
			   true->
				   case select_novice_gift(PlayerStatus#player.id) of
					   []->{error,2,[]};
					   [Gift]->
						   case get_mark(Gift,Lv) =:= 0 of
							   false->{error,4,[]};
							   true->
								   GoodsBag = gift(Lv,PlayerStatus#player.career),
								   case gen_server:call(PlayerStatus#player.other#player_other.pid_goods,{'cell_num'})< length(GoodsBag) of
									   true->{error,5,[]};
									   false->
										   case give_goods(GoodsBag,PlayerStatus) of
											   ok->
												   update_gift(PlayerStatus#player.id,Gift,Lv),
												   {ok,1,equ_list(Lv,PlayerStatus#player.career)};
											   error->{error,6,[]}
										   end
								   end
						   end
				   end
			end
	end.

give_goods([],_PlayerStatus)->ok;
give_goods([{GoodsId,Num}|GoodsBag],PlayerStatus)->
	case ( catch gen_server:call(PlayerStatus#player.other#player_other.pid_goods, 
								 {'give_goods', PlayerStatus,GoodsId, Num,2})) of
		ok ->give_goods(GoodsBag,PlayerStatus);
		_->error
	end.
			
get_mark(Gift,Lv)->
	case Lv of
		9->Gift#ets_novice_gift.mark8;
		14->Gift#ets_novice_gift.mark14;
		18->Gift#ets_novice_gift.mark18;
		22->Gift#ets_novice_gift.mark22;
		26->Gift#ets_novice_gift.mark26;
		31->Gift#ets_novice_gift.mark31
	end.

update_gift(PlayerId,Gift,Lv)->
	{NewGift,Mark} = 
		case Lv of
			9->{Gift#ets_novice_gift{mark8=1},mark8};
			14->{Gift#ets_novice_gift{mark14=1},mark14};
			18->{Gift#ets_novice_gift{mark18=1},mark18};
			22->{Gift#ets_novice_gift{mark22=1},mark22};
			26->{Gift#ets_novice_gift{mark26=1},mark26};
			31->{Gift#ets_novice_gift{mark31=1},mark31}
		end,
	update_novice_gift(NewGift),
	db_agent:update_novice_gift([{Mark,1}],[{pid,PlayerId}]).

offline(PlayerId)->
	delete_novice_gift(PlayerId).
%%
%% Local Functions
%%
update_novice_gift(Gift)->
	ets:insert(?ETS_NOVICE_GIFT, Gift).
select_novice_gift(PlayerId)->
	ets:lookup(?ETS_NOVICE_GIFT, PlayerId).
delete_novice_gift(PlayerId)->
	ets:delete(?ETS_NOVICE_GIFT, PlayerId).

%% case Career of
%% 			1 -> 1;			%玄武--战士
%%          	2 -> 2;			%白虎--刺客
%%          	3 -> 3;			%青龙--弓手
%%         	4 -> 4;     	%朱雀--牧师
%%         	_ -> 5     		%麒麟--武尊
%%     	end,
equ_list(Lv,Career)->
	case Lv of
		9->
			case Career of
				1->[10003,11112,23300];
				2->[10003,12112,23300];
				3->[10003,13112,23300];
				4->[10003,14112,23300];
				5->[10003,15112,23300]
			end;
		14->
			case Career of
				1->[11119,11120,11121,11122];
				2->[12119,12120,12121,12122];
				3->[13119,13120,13121,13122];
				4->[14119,14120,14121,14122];
				5->[15119,15120,15121,15122]
			end;
		18->
			case Career of
				1->[11123,11124,10008];
				2->[12123,12124,10008];
				3->[13123,13124,10008];
				4->[14123,14124,10008];
				5->[15123,15124,10008]
			end;
		22->[23005,23002,28201,28200];
		26->[23005,23002,28201,24000];
		31->[23006,23106,23005,23002];
		_->[]
	end.

gift(Lv,Career)->
	case Lv of
		9->
			case Career of
				1->[{23300,1},{10003,1},{11112,1}];
				2->[{23300,1},{10003,1},{12112,1}];
				3->[{23300,1},{10003,1},{13112,1}];
				4->[{23300,1},{10003,1},{14112,1}];
				5->[{23300,1},{10003,1},{15112,1}]
			end;
		14->
			case Career of
				1->[{11119,1},{11120,1},{11121,1},{11122,1}];
				2->[{12119,1},{12120,1},{12121,1},{12122,1}];
				3->[{13119,1},{13120,1},{13121,1},{13122,1}];
				4->[{14119,1},{14120,1},{14121,1},{14122,1}];
				5->[{15119,1},{15120,1},{15121,1},{15122,1}]
			end;
		18->
			case Career of
				1->[{11123,1},{11124,1},{10008,1}];
				2->[{12123,1},{12124,1},{10008,1}];
				3->[{13123,1},{13124,1},{10008,1}];
				4->[{14123,1},{14124,1},{10008,1}];
				5->[{15123,1},{15124,1},{10008,1}]
			end;
		22->[{23005,20},{23002,20},{28201,5},{28200,1}];
		26->[{23005,20},{23002,20},{28201,5},{24000,5}];
		31->[{23006,1},{23106,1},{23005,20},{23002,20}];
		_->[]
	end.
		 