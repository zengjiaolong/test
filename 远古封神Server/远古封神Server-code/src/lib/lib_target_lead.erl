%% Author: Administrator
%% Created: 2011-6-22
%% Description: TODO: Add description to lib_target_lead
-module(lib_target_lead).

%%
%% Include files
%%

-include("common.hrl").
-include("record.hrl").

-compile(export_all).
%%
%% API Functions
%%
init_target_lead(PlayerId)->
	case db_agent:select_target_lead(PlayerId) of
		[]->
			{_,Id}=db_agent:insert_target_lead(PlayerId),
			Data  = [Id,PlayerId,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
			TargetLead=pack_ets(Data),
			update_target_lead(TargetLead); 
		TargetData->
			TargetLead=pack_ets(TargetData),
			update_target_lead(TargetLead)
	end.
%%8,12,15,20,25,30,31,32,33,34,35,36,36
%% 1->pet;
%% 		2->mount;
%% 		3->save_html;
%% 		4->guild;
%% 		5->magic;
%% 		6->light;
%% 		7->carry;
%% 		8->suit1;
%% 		9->train;
%% 		10->suit2;
%% 		11->fst;
%% 		12->td;
%% 		13->business;
%% 		14->error
target_lead_info(PlayerId)-> 
	case select_target_lead(PlayerId) of
		[]->
			[{8,1,1},{12,1,2},{15,1,3},{20,1,4},{30,1,5},{31,1,6},{32,1,7},{33,1,8},{40,1,13},{34,1,9},{34,1,12},{35,1,10},{33,1,11},{30,1,14},{25,1,15},{35,1,16}];
		[TL]->
			[{8,TL#ets_targetlead.pet,1},{12,TL#ets_targetlead.mount,2},{15,TL#ets_targetlead.save_html,3},
			 {20,TL#ets_targetlead.guild,4},{30,TL#ets_targetlead.light,5},{31,TL#ets_targetlead.carry,6},
			 {32,TL#ets_targetlead.suit1,7},{33,TL#ets_targetlead.train,8},{40,TL#ets_targetlead.weapon,13},
			 {34,TL#ets_targetlead.suit2,9},{34,TL#ets_targetlead.business,12},{35,TL#ets_targetlead.fst,10},
			 {33,TL#ets_targetlead.td,11},{30,TL#ets_targetlead.arena,14},{25,TL#ets_targetlead.fs_era,15},
			 {35,TL#ets_targetlead.mount_arena,16}
			]
	end.

%%1领取成功，2数据异常，3等级不符合，4背包已满
update_targetlead(PlayerStatus,Rank)->
	case select_target_lead(PlayerStatus#player.id) of
		[]->{PlayerStatus,2,Rank}; 
		[TL] ->
			case lv_to_type(Rank) of
				error->{PlayerStatus,3,Rank};
				Type->
				case PlayerStatus#player.lv >= to_lv(Type) of
					false->{PlayerStatus,3,Rank};
					true->
						case Type of
							pet->
								NewPlayer = PlayerStatus,
								NewTL = TL#ets_targetlead{pet=1};
							mount->
								NewPlayer = PlayerStatus,
								NewTL = TL#ets_targetlead{mount=1};
							save_html->
								case TL#ets_targetlead.save_html > 0 of
									true->NewPlayer=PlayerStatus;
									false->
										NewPlayer = lib_target_gift:add_cash(PlayerStatus,100)
								end,
								NewTL = TL#ets_targetlead{save_html=1};
							guild->
								NewPlayer = PlayerStatus,
								NewTL = TL#ets_targetlead{guild=1};
							magic->
								NewPlayer = PlayerStatus,
								NewTL = TL#ets_targetlead{magic=1};
							light->
								NewPlayer = PlayerStatus,
								NewTL = TL#ets_targetlead{light=1};
							carry->
								NewPlayer = PlayerStatus,
								NewTL = TL#ets_targetlead{carry=1};
							suit1->
								NewPlayer = PlayerStatus,
								NewTL = TL#ets_targetlead{suit1=1};
							train->
								NewPlayer = PlayerStatus,
								NewTL = TL#ets_targetlead{train=1};
							suit2->
								NewPlayer = PlayerStatus,
								NewTL = TL#ets_targetlead{suit2=1};
							fst->
								NewPlayer = PlayerStatus,
								NewTL = TL#ets_targetlead{fst=1};
							td->
								NewPlayer = PlayerStatus,
								NewTL = TL#ets_targetlead{td=1};
							business->
								NewPlayer = PlayerStatus,
								NewTL = TL#ets_targetlead{business=1};
							peach->
								NewPlayer = PlayerStatus,
								NewTL = TL#ets_targetlead{peach=1};
							weapon->
								NewPlayer = PlayerStatus,
								NewTL = TL#ets_targetlead{weapon=1};
							arena->
								NewPlayer = PlayerStatus,
								NewTL = TL#ets_targetlead{arena=1};
							fs_era->
								NewPlayer = PlayerStatus,
								NewTL = TL#ets_targetlead{fs_era=1};
							mount_arena->
								NewPlayer = PlayerStatus,
								NewTL = TL#ets_targetlead{mount_arena=1};
							_->
								NewPlayer = PlayerStatus,
								NewTL=TL
						end,
						if NewTL =/=TL ->
							   Goods = goods(Type,PlayerStatus#player.career),
							   case gen_server:call(PlayerStatus#player.other#player_other.pid_goods,{'cell_num'})< length(Goods) of
								   true->{NewPlayer,4,Rank};
								   false->
									   give_goods(Goods,PlayerStatus),
									   update_target_lead(NewTL),
									   db_agent:update_target_lead(NewPlayer#player.id,Type),
									   {NewPlayer,1,Rank}
							   end;
						   true->{NewPlayer,3,Rank}
						end
				end
			end
	end.

give_goods([],_)->ok;
give_goods([Goods|GoodsBag],PlayerStatus)->
	{GoodsId,Num} = Goods,
	catch gen_server:call(PlayerStatus#player.other#player_other.pid_goods, 
								 {'give_goods', PlayerStatus,GoodsId,Num,2}),
	give_goods(GoodsBag,PlayerStatus).

%%
%% Local Functions
%%
pack_ets(Data)->
	[Id,PlayerId,Pet,Mount,SaveHtml,Guild,Magic,Light,Carry,Suit1,Train,Suit2,Fst,Td,Business,Peach,Weapon,Arena,FsEra,MountArena]=Data,
	#ets_targetlead{
					id=Id,
					pid=PlayerId,
					pet = Pet,
					mount=Mount,
					save_html=SaveHtml,
					guild=Guild,
					magic=Magic,
					light=Light,
					carry=Carry,
					suit1=Suit1,
					train=Train,
					suit2=Suit2,
					fst=Fst,
					td=Td,
					business=Business,
					peach=Peach ,
					weapon = Weapon,
					arena = Arena,
					fs_era=FsEra,
					mount_arena=MountArena
					}.

update_target_lead(TargetLead)->
	ets:insert(?ETS_TARGETLEAD, TargetLead).
select_target_lead(PlayerId)->
	ets:lookup(?ETS_TARGETLEAD,PlayerId).
delete_target_lead(PlayerId)->
	ets:delete(?ETS_TARGETLEAD,PlayerId).

lv_to_type(Lv)->
	case Lv of
		1->pet;
		2->mount;
		3->save_html;
		4->guild;
		5->light;
		6->carry;
		7->suit1;
		8->train;
		9->suit2;
		10->fst;
		11->td;
		12->business;
		13->weapon;
		14->arena;
		15->fs_era;
		16->mount_arena;
		_13->error
	end.

to_lv(Type)->
	case Type of
		pet->8;
		mount ->12;
		save_html->15;
		guild->20;
		light->30;
		carry->31;
		suit1->32;
		train->33;
		suit2->34;
		fst->35;
		td->33;
		business->34;
		weapon->40;
		arena->30;
		fs_era->25;
		mount_arena->35;
		_->0
	end.

goods(Target,Career)->
	case Target of
		pet->[{24000,5},{24400,1}];
		mount ->[{23203,1},{23303,1}];
		save_html->[];
		guild->[{28201,5},{23005,20}];
		magic->[{28043,1},{21020,1}];
		light->[{28201,5},{24104,1}];
		carry->[{22000,1},{24000,5}];
		suit1->
			case Career of
				1->[{21022,1},{11902,1}];
				2->[{21022,1},{12902,1}];
				3->[{21022,1},{13902,1}];
				4->[{21022,1},{14902,1}];
				5->[{21022,1},{15902,1}]
			end;
		train->[{23006,1},{23107,1}];
		suit2->
			case Career of
				1->[{21200,1},{11904,1}];
				2->[{21200,1},{12904,1}];
				3->[{21200,1},{13904,1}];
				4->[{21200,1},{14904,1}];
				5->[{21200,1},{15904,1}]
			end;
		fst->[{23205,1},{23305,1}];
		td->[{21100,1},{21200,1}];
		business->[{28406,2},{28407,1}];
		weapon ->[{32000,1},{32026,1}];
		arena ->[{23200,1},{23300,1}];
		fs_era ->[{23006,1},{23107,1}];
		mount_arena->[{24820,1},{28024,1}];
		_->[]
	end.
offline(PlayerId)->
	delete_target_lead(PlayerId).