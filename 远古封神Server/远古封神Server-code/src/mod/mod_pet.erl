%%%------------------------------------
%%% @Module  : mod_pet
%%% @Author  : ygzj
%%% @Created : 2010.10.19
%%% @Description: 灵兽处理
%%%------------------------------------
-module(mod_pet).
-include("common.hrl").
-include("record.hrl").
-compile(export_all).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
%%刷新购买面板的元宝消费
-define(Flush_Need_Gold,50).
%%默认的闲置技能分离最大的格子数
-define(PET_MAX_GRID,12).
%%拥有灵兽最大值
-define(MaxPetCount,7).

get_max_pet_count() ->
	?MaxPetCount.

init([ProcessName, Worker_id]) ->
    process_flag(trap_exit, true),	
	misc:register(global, ProcessName, self()),
	if 
		Worker_id =:= 0 ->
			misc:write_monitor_pid(self(), mod_pet, {}),
			misc:write_system_info(self(), mod_pet, {});
		true->
			 misc:write_monitor_pid(self(), mod_pet_child, {Worker_id})
	end,
    {ok, []}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.
handle_cast(_MSg,State)->
	 {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()).

code_change(_OldVsn, State, _Extra)->
    {ok, State}.
%%=========================================================================
%% 业务处理函数
%%=========================================================================
get_pet_max_grid() ->
	?PET_MAX_GRID.

%%生成灵兽
give_pet(Status,[Goods_id,Rune_id]) ->
	Now = util:unixtime(),
	GoodsTypeInfo = goods_util:get_goods_type(Goods_id),
	PetTypeInfo = lib_pet:get_base_pet(Goods_id),
	PetCount = lib_pet:get_pet_count(Status#player.id),
	HaveRune = lib_goods:goods_find(Status#player.id,Rune_id),
	%%有时间限制的灵兽类型id
	PetBuyGoodsList = [Goods_id1 || [Goods_id1,_Ct]<- lib_pet:pet_buy_list(Status#player.id)],
	CanNotBuy = lists:member(Goods_id, PetBuyGoodsList),
	case is_record(GoodsTypeInfo,ets_base_goods) of
		false ->
			%%物品信息不存在
			[2,0,0,<<>>,Status];
		true ->
			if
				is_record(PetTypeInfo,ets_base_pet) =:= false ->
					%%灵兽信息不存在
					[3,0,0,<<>>,Status];
				Status#player.lv < GoodsTypeInfo#ets_base_goods.level ->				
					%%等级不够
					[4,0,0,<<>>,Status];
				(Status#player.bcoin + Status#player.coin) < GoodsTypeInfo#ets_base_goods.price ->
					%%铜币不足
					[5,0,0,<<>>,Status];
				PetCount >= ?MaxPetCount ->
					%%灵兽数已满
					[6,0,0,<<>>,Status];
				Rune_id > 0 andalso Rune_id =/= 24300 andalso Rune_id =/= 24301 andalso Rune_id =/= 24302 andalso Rune_id =/= 24303->
					%%物品类型错误
					[7,0,0,<<>>,Status];
				Rune_id > 0 andalso HaveRune =:= false ->
					%%没有召唤卡
					[8,0,0,<<>>,Status];
				Rune_id == 0 andalso CanNotBuy == true ->
					%%现在不能购买此灵兽或刷新后再购买
					[9,0,0,<<>>,Status];
				true ->
					Status1 = lib_goods:cost_money(Status, GoodsTypeInfo#ets_base_goods.price, coin,4102),
					gen_server:cast(Status1#player.other#player_other.pid, {'SET_PLAYER', Status1}),						
					Aptitude = get_pet_aptitude(Rune_id),
					case (catch(lib_pet:give_pet(Status1#player.id,PetTypeInfo,Aptitude,1))) of
						{ok,PetId,Name,Grow} ->
							if
								Rune_id > 0 ->
									gen_server:call(Status1#player.other#player_other.pid_goods,{'delete_more',Rune_id,1}),
									spawn(fun()->catch(db_agent:log_get_pet(Status#player.id,PetId,Rune_id,Aptitude,Grow,Now)) end);
								true ->
									skip
							end,
							NameColor = data_agent:get_realm_color(Status#player.realm),
							if Aptitude >=55 andalso Rune_id=:=24303->
								   %%恭喜！【xxx】使用仙灵召唤卡获得50+资质的极品灵兽
									Msg = io_lib:format("恭喜！玩家[<a href='event:1,~p, ~s, ~p,~p'><font color='~s'><u>~s</u></font></a>]使用仙灵召唤卡获得~p资质的超级灵兽！！",[Status#player.id,Status#player.nickname,Status#player.career,Status#player.sex,NameColor,Status#player.nickname,Aptitude]),
									lib_chat:broadcast_sys_msg(2,Msg);
								Aptitude >=50 ->
								    %%恭喜！【xxx】使用钻石转换卡获得50+资质的极品灵兽
									Msg = io_lib:format("恭喜！玩家[<a href='event:1,~p, ~s, ~p,~p'><font color='~s'><u>~s</u></font></a>]使用钻石召唤卡获得~p资质的极品灵兽！！",[Status#player.id,Status#player.nickname,Status#player.career,Status#player.sex,NameColor,Status#player.nickname,Aptitude]),
									lib_chat:broadcast_sys_msg(2,Msg);
							   true->skip
							end,
							if
								Rune_id == 0 ->
									lib_pet:add_pet_buy(Status1#player.id,Goods_id,Now);
								true ->
									skip
							end,
							[1,PetId,Goods_id,Name,Status1];
						_Error ->
							[0,0,0,<<>>,Status1]
					end
			end			
	end.

%%随机生成灵兽资质
get_pet_aptitude(Rune_id) ->
	Ratio = util:rand(1,10000),
	%%不用卡召唤
	case Rune_id of
		0 ->
			if
				Ratio =< 8500 ->
					util:rand(20,25);
				true ->
					util:rand(26,30)
			end;
		%%高级召唤卡
		24300 ->
			if
				Ratio =< 8000 ->
					util:rand(30,35);
				true ->
					util:rand(36,39)
			end;
		%%白金召唤卡
		24301 ->
			if
				Ratio =< 7500 ->
					util:rand(35,40);
				Ratio =< 9500 ->
					util:rand(41,45);
				true ->
					util:rand(46,49)
			end;
		%%钻石召唤卡
		24302 ->
			if
				Ratio =< 7000 ->
					util:rand(40,45);
				Ratio =< 9000 ->
					util:rand(46,50);
				Ratio =< 9900 ->
					util:rand(51,55);
				true ->
					util:rand(56,59)
			end;
		%%24303
		24303 ->
			if Ratio =< 9000 ->
				   util:rand(55,59);
			   Ratio =< 9950 ->
				   util:rand(60,64);
			   true->
				   util:rand(65,69)
			end;
		_-> 20
	end.
					
			
%% -----------------------------------------------------------------
%% 灵兽放生Type 0为自己放生，1为整合放生,2为萃取
%% -----------------------------------------------------------------
free_pet(Status, [PetId,Type]) ->
	case Status#player.realm of 
		100->
			{4,[]};%%新手不能放生灵兽
		_->
			%%这里应该从ets_pet 获取数据
    		Pet = lib_pet:get_pet(PetId),
		    if  % 灵兽不存在 2
        		Pet =:= []  -> 
					{2,[]};
		        true ->
        		    if  % 该灵兽不归你所有
                		Pet#ets_pet.player_id =/= Status#player.id -> 
							{3,[]};
						%% 出战状态先收回
						Pet#ets_pet.status =:= 1 ->
							pp_pet:handle(41004, Status, [PetId,0]),
							case lib_pet:free_pet(PetId) of
        		                ok  -> 
									spawn(fun()->catch(
													   db_agent:free_pet_log(
														 Status#player.id,Pet#ets_pet.goods_id,Pet#ets_pet.level,Pet#ets_pet.aptitude,
														 Pet#ets_pet.grow,Pet#ets_pet.skill_1,Pet#ets_pet.skill_2,Pet#ets_pet.skill_3,
														 Pet#ets_pet.skill_4,Pet#ets_pet.skill_5,Pet#ets_pet.skill_6,util:unixtime(),Type
																			))
										  end),
									{1,Pet};
                		        _   -> {0,[]}
		                    end;
						%%灵兽在训练
						Pet#ets_pet.status =:= 2 ->
							{5,[]};
        		        true ->
                		    case lib_pet:free_pet(PetId) of
                        		ok  ->
									%%重新计算角色属性
									if Pet#ets_pet.status=:= 1->
										   pet_attribute_effect(Status,Pet);
									   true->skip
									end,
									spawn(fun()->catch(
													   db_agent:free_pet_log(
														 Status#player.id,Pet#ets_pet.goods_id,Pet#ets_pet.level,Pet#ets_pet.aptitude,
														 Pet#ets_pet.grow,Pet#ets_pet.skill_1,Pet#ets_pet.skill_2,Pet#ets_pet.skill_3,
														 Pet#ets_pet.skill_4,Pet#ets_pet.skill_5,Pet#ets_pet.skill_6,util:unixtime(),Type
																			))end),
									{1,Pet};
                        		_   -> 
									{0,[]}
		                    end
        	    end
			end
    end.

%% -----------------------------------------------------------------
%% 灵兽改名
%% -----------------------------------------------------------------
rename_pet(Status, [PetId, PetName]) ->
	%%敏感词检测
	case lib_words_ver:words_ver(PetName) of
		true ->
    		Pet = lib_pet:get_pet(PetId),
		    if  % 灵兽不存在 2
		        Pet =:= []  -> 
					{fail,2};
        		true ->
		            NewName = tool:to_binary(PetName),
        		    if  % 该灵兽不归你所有 3
                		Pet#ets_pet.player_id  =/= Status#player.id -> 
							{fail,3};
		                % 新旧名称相同
        		        Pet#ets_pet.name =:= NewName ->
							{fail,4};
                		true ->                  
		                    case lib_pet:rename_pet(Pet, NewName) of
        		                 ok  -> {ok};
                		         _   -> {fail,0}

    	                	end                    
	    	        end
				end;
		false->
			{fail,5}
    end.

%% -------------------------------------------------------------------
%% 灵兽属性加点
%% -------------------------------------------------------------------
mod_pet_attribute(Status,[PetId,Forza,Agile,Wit,Physique]) ->
	Pet = lib_pet:get_pet(PetId),
	if
		Pet =:= [] -> 
			{fail,2};%%灵兽不存在
		Pet#ets_pet.player_id =/= Status#player.id ->
			{fail,3};%%灵兽不归你所有
		(Forza+Agile+Wit+Physique) > (Pet#ets_pet.forza + Pet#ets_pet.agile + Pet#ets_pet.wit + Pet#ets_pet.physique + Pet#ets_pet.point) ->
			{fail,4};%%属性点不足
		Pet#ets_pet.point =< 0  ->
			{fail,5};%%属性点错误
		true ->
			case lib_pet:mod_pet_attribute(Pet,Forza,Agile,Wit,Physique) of
				{ok,PetNew} ->
					[Pet_hp,Pet_att,Pet_hit,Pet_mp]= lib_pet:add_point_tips(PetNew,Pet,Status),
					%%重新计算角色属性
					pet_attribute_effect(Status,PetNew),
					{ok,PetNew,[Pet_hp,Pet_att,Pet_hit,Pet_mp]};
				_ -> {fail,0}
			end
	end.

%% -------------------------------------------------------------------
%% 灵兽属性洗点
%% -------------------------------------------------------------------
mod_clear_attribute(Status,[PetId]) ->
	Pet = lib_pet:get_pet(PetId),
	if
		Pet =:= [] -> 
			{fail,2};%%灵兽不存在
		Pet#ets_pet.player_id =/= Status#player.id ->
			{fail,3};%%灵兽不归你所有
		true ->
			case lib_pet:mod_clear_attribute(Status,Pet) of
				{ok,PetNew} ->
					%%重新计算角色属性
					pet_attribute_effect(Status,PetNew),
					{ok,PetNew};
				{fail,Result} -> 
					{fail,Result}
			end
	end.

%% ---------------------------------------------------------------
%% 状态切换前操作
%% ---------------------------------------------------------------
before_change_status(Status) ->
	Pet = lib_pet:get_out_pet(Status#player.id),
	if
		is_record(Pet,ets_pet) =:= true ->
			rest_pet(Status,Pet);
		true ->
			skip
	end.

%% ----------------------------------------------------------------
%% 灵兽状态改变
%% ----------------------------------------------------------------
change_status(Status,[PetId,PetStatus]) ->
	Pet = lib_pet:get_pet(PetId),
	case PetStatus of
		0 -> rest_pet(Status,Pet);
		1 -> out_pet(Status,Pet);
		_ -> {fail,0}
	end.
%% -----------------------------------------------------------------
%% 灵兽出战 状态1
%% -----------------------------------------------------------------
out_pet(Status, Pet) ->
    if  % 灵兽不存在
        Pet =:= []  -> 
			{fail,2};
        true ->         
            if  % 该灵兽不归你所有 3
                Pet#ets_pet.player_id =/= Status#player.id -> {fail,3};
                % 灵兽已经出战 4
                Pet#ets_pet.status =:= 1 -> {fail,4};
				%灵兽训练中7
				Pet#ets_pet.status =:= 2 -> {fail,7};
                % happy值为0 5
                %Pet#ets_pet.happy =:= 0 -> {fail,5};
                true ->         
                     PetNew = lib_pet:out_pet(Pet),
					 lib_task:event(pet, null, Status),
					 %%属性加点对角色属性加成影响
					 pet_attribute_effect(Status,PetNew),
                     {ok,PetNew}
            end
    end.

%% -----------------------------------------------------------------
%% 灵兽休息 状态2
%% -----------------------------------------------------------------
rest_pet(Status, Pet) ->
    if  % 灵兽不存在 2
        Pet =:= []  ->
			{fail,2,Pet};
        true ->           
            if  % 该灵兽不归你所有 3
                Pet#ets_pet.player_id =/= Status#player.id -> {fail,3,Pet};
                % 灵兽已经休息 6
                Pet#ets_pet.status =:= 0 -> {fail,6,Pet};
				% 灵兽训练中7
				Pet#ets_pet.status =:= 2 ->{fail,7,Pet};
                true ->
                    PetNew = lib_pet:rest_pet(Pet),
					%%属性加点对角色属性加成影响
					pet_attribute_effect(Status,PetNew),
					{ok,PetNew}
            end
    end.

%% -----------------------------------------------------------------
%% 灵兽资质提升
%% -----------------------------------------------------------------
upgrade_aptitude(Status,[PetId,AptType,PType,Auto_purch]) ->
	case check_upgrade_aptitude(Status,PetId,AptType,PType,Auto_purch) of
		{ok,NewPlayerStatus,PetInfo,Rule,AptNum,GoldCost} ->
			case (catch lib_pet:upgrade_aptitude(NewPlayerStatus,PetInfo,AptType,PType,Rule,AptNum,GoldCost)) of
				{ok,NewStatus,Pet,Res} ->
					%%返回资质符个数
					{ok,Rest_Apt} = get_goods_info(Status,24400),
					%%返回资质保护符个数
					{ok,Rest_P} = get_goods_info(Status,24401),
					%%属性加点对角色属性加成影响
					pet_attribute_effect(NewStatus,Pet),
					[RP,Coin] = data_pet:get_upgrade_aptitude(Pet#ets_pet.aptitude),
					{NewPlayerStatus1,_,VipAward} = lib_vip:get_vip_award(pet,NewStatus),
					NewRp = round(RP + VipAward*100),
					if PetInfo#ets_pet.aptitude =/= Pet#ets_pet.aptitude ->
						   %%成就系统统计接口
						   if Pet#ets_pet.aptitude>=55 ->
								  lib_achieve:check_achieve_finish(Status#player.other#player_other.pid_send,
																   Pet#ets_pet.player_id, 516, [55]);
							  Pet#ets_pet.aptitude>=30 ->
								  lib_achieve:check_achieve_finish(Status#player.other#player_other.pid_send,
																   Pet#ets_pet.player_id, 515, [30]);
							   true->skip
						   end,
						   case Pet#ets_pet.aptitude >=60 andalso Pet#ets_pet.aptitude > PetInfo#ets_pet.aptitude of
							   true->sys_broadcast(Status,Pet,apt);
							   false->skip
							end;
					   true->skip
					end,
					{ok,NewPlayerStatus1,Pet,Res,Rest_Apt,Rest_P,NewRp,Coin};
				_Error ->
					{fail,0}
			end;
		{fail,Res} ->
			{fail,Res}
	end.


%% -----------------------------------------------------------------
%% 灵兽成长值提升
%% -----------------------------------------------------------------
upgrade_grow(Status,[PetId,GrowType,PType,Lucky,Auto_purch]) ->
	case check_upgrade_grow(Status,PetId,GrowType,PType,Lucky,Auto_purch) of
		{ok,NewPlayerStatus,PetInfo,Rule,GrowNum,GrowCost} ->
			case (catch lib_pet:upgrade_grow(NewPlayerStatus,PetInfo,GrowType,PType,Rule,Lucky,GrowNum,GrowCost)) of
				{ok,NewStatus,Pet,Res,OldGrow} ->
					%%返回成长丹个数
					{ok,Rest_Grow} = get_goods_info(Status,24400),
					%%返回成长保护丹符个数
					{ok,Rest_P} = get_goods_info(Status,24401),
					%%属性加点对角色属性加成影响
					pet_attribute_effect(NewStatus,Pet),
					[RP,_] = data_pet:grow_up(Pet#ets_pet.grow),
					case Pet#ets_pet.grow >=40 andalso Pet#ets_pet.grow >OldGrow of
						true->sys_broadcast(Status,Pet,grow);
						false->skip
					end,
					case lists:member(Pet#ets_pet.grow,[30,40,50,60])andalso Pet#ets_pet.grow >OldGrow of
						true->
							%%您的灵兽成长已达到XX，可以使用灵兽洗点符获得灵兽低成长升级时损失的属性。若灵兽未升级则无需使用。
							Msg= io_lib:format("您的灵兽成长已达到 ~p，可以使用灵兽洗点符获得灵兽低成长升级时损失的属性点。",[Pet#ets_pet.grow]),
							{ok,MyBin} = pt_15:write(15055,[Msg]),
							lib_send:send_to_sid(Status#player.other#player_other.pid_send,MyBin),
							PetColor = data_pet:get_pet_color(Pet#ets_pet.aptitude),
							{ok,BinData1} = pt_12:write(12031,[Pet#ets_pet.status,Status#player.id,Pet#ets_pet.id,Pet#ets_pet.name,PetColor,Pet#ets_pet.goods_id,Pet#ets_pet.grow,Pet#ets_pet.aptitude]),
							mod_scene_agent:send_to_area_scene(Status#player.scene,Status#player.x, Status#player.y, BinData1),
							%%成就系统统计接口
							if
								Pet#ets_pet.grow >= 60 ->
									lib_achieve:check_achieve_finish(Status#player.other#player_other.pid_send,
																	 Pet#ets_pet.player_id, 519, [60]);
								Pet#ets_pet.grow >= 50 ->
									lib_achieve:check_achieve_finish(Status#player.other#player_other.pid_send,
																	 Pet#ets_pet.player_id, 518, [50]);
								Pet#ets_pet.grow >= 40 ->
									lib_achieve:check_achieve_finish(Status#player.other#player_other.pid_send,
																	 Pet#ets_pet.player_id, 517, [40]);
								true ->
									skip
							end,
							ok;
						false->skip
					end,
					{ok,Status,Pet,Res,Rest_Grow,Rest_P,RP};
				{fail,Error} ->
					{fail,Error}
			end;
		{fail,Res} ->
			{fail,Res}
	end.


%% -----------------------------------------------------------------
%% 开始灵兽训练
%% -----------------------------------------------------------------
pet_train_start(Status,[PetId,GoodsNum,MoneyType,Auto])->
	case check_pet_train(Status,PetId,GoodsNum,MoneyType,Auto) of
		{fail,Error}->{fail,Error};
		{ok,Pet,TrainTime,TrainMoney}->
			case lib_pet:lib_train_start(Status,Pet,GoodsNum,MoneyType,Auto,TrainTime,TrainMoney) of
				{ok,NewStatus,NewPet}->
					pet_attribute_effect(NewStatus,NewPet),
					{ok,NewStatus,NewPet};
				{fail,Error2}->{fail,Error2}
			end
	end.


%% -----------------------------------------------------------------
%% 停止灵兽训练
%% -----------------------------------------------------------------
pet_train_stop(Status,[PetId])->
	case check_stop_train(Status,PetId) of
		{fail,Error}->{fail,Error};
		{ok,Pet}->
			lib_pet:lib_train_stop(Status,Pet)
	end.
%% -----------------------------------------------------------------
%%系统广播
%% -----------------------------------------------------------------
sys_broadcast(PS,Pet,Type)->
	NameColor = data_agent:get_realm_color(PS#player.realm),
	case Type of
		apt->
			%%不可思议，【国】玩家【玩家名】将心爱的灵兽【灵兽名】的资质提升到60！
			Msg = io_lib:format("不可思议，<font color='~s'>[~s]</font>玩家[<a href='event:1,~p, ~s, ~p,~p'><font color='~s'><u>~s</u></font></a>]将心爱的灵兽【~s】的资质提升到~p!!!",[NameColor,get_realm_name_by_id(PS#player.realm),PS#player.id,PS#player.nickname,PS#player.career,PS#player.sex,NameColor,PS#player.nickname,Pet#ets_pet.name,Pet#ets_pet.aptitude]),
			lib_chat:broadcast_sys_msg(2,Msg);
		grow->
			if Pet#ets_pet.grow=:=40->
				   %%恭喜【玩家名】将心爱的灵兽【灵兽名】成长值提升到40！
				   Msg = io_lib:format("恭喜[<a href='event:1,~p, ~s, ~p,~p'><font color='~s'><u>~s</u></font></a>]将心爱的灵兽【~s】成长值提升到~p!!!",[PS#player.id,PS#player.nickname,PS#player.career,PS#player.sex,NameColor,PS#player.nickname,Pet#ets_pet.name,Pet#ets_pet.grow]),
				   lib_chat:broadcast_sys_msg(2,Msg);
			   Pet#ets_pet.grow < 50 ->
				   skip;
			   Pet#ets_pet.grow <60 ->
				   %%鸿运降临！【玩家名】成功将心爱的灵兽【灵兽名】成长值提升到 N！
				    Msg = io_lib:format("鸿运降临！[<a href='event:1,~p, ~s, ~p,~p'><font color='~s'><u>~s</u></font></a>]将心爱的灵兽【~s】成长值提升到~p!!!",[PS#player.id,PS#player.nickname,PS#player.career,PS#player.sex,NameColor,PS#player.nickname,Pet#ets_pet.name,Pet#ets_pet.grow]),
					lib_chat:broadcast_sys_msg(2,Msg);
			   true->
				   %%天哪！【玩家名】神话般地将心爱的灵兽【灵兽名】成长值提升到60！！！
				   Msg = io_lib:format("天哪！[<a href='event:1,~p, ~s, ~p,~p'><font color='~s'><u>~s</u></font></a>]神话般地将心爱的灵兽【~s】成长值提升到~p!!!",[PS#player.id,PS#player.nickname,PS#player.career,PS#player.sex,NameColor,PS#player.nickname,Pet#ets_pet.name,Pet#ets_pet.grow]),
				   lib_chat:broadcast_sys_msg(2,Msg)
			end
			   
	end.
%% -----------------------------------------------------------------
%%根据id获取部落名称
%% -----------------------------------------------------------------
get_realm_name_by_id(Id)->
	case Id of
		1->"女娲";
		2->"神农";
		_->"伏羲"
	end.	
%% -----------------------------------------------------------------
%%检查资质
%% -----------------------------------------------------------------
check_upgrade_aptitude(Status,PetId,AptType,PType,Auto_purch) ->
	GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, AptType),
	Pet = lib_pet:get_pet(PetId),
	{ok,AptNum} = get_goods_info(Status,AptType),
	if
		PType > 0 ->
			{ok,PNum}= get_goods_info(Status,PType);
		true ->
			PNum =0
	end,
	Rule = data_pet:get_upgrade_aptitude(Pet#ets_pet.aptitude),
	[Rp,C] = Rule,
	case is_record(Pet,ets_pet) of
		true->
			if
				Pet#ets_pet.player_id =/= Status#player.id ->
					{fail,3}; %%灵兽不归你所有		
				Auto_purch == 0 andalso AptNum =:= 0 ->
					{fail,4}; %%物品信息不存在
				PType > 0 andalso PNum =:= 0 ->
					{fail,4};
				Rule =:= [0,0] ->
					{fail,5}; %%资质已到上限
				Status#player.coin + Status#player.bcoin < C ->
					{fail,6}; %%铜币不足
				Auto_purch == 1 andalso AptNum =:= 0 andalso Status#player.gold < GoodsTypeInfo#ets_base_goods.price ->
					{fail,8}; %%元宝不足
				AptType =/= 24400 ->
					{fail,7}; %%物品类型错误
				PType > 0 andalso PType =/= 24401 ->
					{fail,7};
				true ->
					if
						Pet#ets_pet.chenge =:= 0 andalso Pet#ets_pet.aptitude  >= 70 -> %%尚未化形并且资质已经达到70
							{fail,5};
						Pet#ets_pet.chenge >= 1  andalso Pet#ets_pet.chenge =/= 2 andalso  Pet#ets_pet.aptitude >= 80 -> %%第一次化形并且资质已经达到80
							{fail,5};
						Pet#ets_pet.chenge == 2  andalso Pet#ets_pet.aptitude >= 100 -> %%第二次化形并且资质已经达到100
							{fail,5};
						true ->
							{NewPlayerStatus,_,_VipAward} = lib_vip:get_vip_award(pet,Status),
							NewRp = round(Rp),
							{ok,NewPlayerStatus,Pet,[NewRp,C],AptNum,GoodsTypeInfo#ets_base_goods.price}
					end
			end;
		_->{fail,2} %%宠物信息不存在
	end.
%% -----------------------------------------------------------------
%%检查成长提示
%% -----------------------------------------------------------------
check_upgrade_grow(Status,PetId,GrowType,PType,Lucky,Auto_purch) ->
	GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, GrowType),
	Pet = lib_pet:get_pet(PetId),
	{ok,GrowNum} = get_goods_info(Status,GrowType),
	if
		PType > 0 ->
			{ok,PNum}= get_goods_info(Status,PType);
		true ->
			PNum =0
	end,
	Rule = data_pet:grow_up(Pet#ets_pet.grow),
	[Rp,Save] = Rule,
	case is_record(Pet,ets_pet) of
		true->
			if
				Pet#ets_pet.player_id =/= Status#player.id ->
					{fail,3}; %%灵兽不归你所有		
				Auto_purch == 0 andalso GrowNum =:= 0 ->
					{fail,4}; %%物品信息不存在
				PType > 0 andalso PNum =:= 0 ->
					{fail,4};
				Auto_purch == 1 andalso GrowNum =:= 0 andalso Status#player.gold < GoodsTypeInfo#ets_base_goods.price ->
					{fail,9}; %%元宝不足
				Rule =:= [0,0] ->
					{fail,5}; %%成长值已到上限
				Pet#ets_pet.chenge =/= 2 andalso Pet#ets_pet.grow >= 60->
					{fail,5}; %%成长值已到上限
				Pet#ets_pet.chenge == 2 andalso Pet#ets_pet.grow >= 80->
					{fail,5}; %%成长值已到上限
				GrowType =/= 24104 ->
					{fail,6}; %%物品类型错误
				PType > 0 andalso PType =/= 24105 ->
					{fail,6};
				Lucky > 5->
					{fail,7};
				true ->
					{ok,Status,Pet,[Rp,Save],GrowNum,GoodsTypeInfo#ets_base_goods.price}
			end;
		_->{fail,2}%%宠物信息不存在
	end.
%% -----------------------------------------------------------------
%%检查是否可训练（1成功，2灵兽信息不存在3灵兽不归你所有	，4灵兽正在训练中，5灵兽口粮不足，
%%6使用铜币训练灵兽口粮不能超过5个，7使用铜币训练不能选择自动升级，8训练所需的铜币不足，9训练所需的元宝不足，10参数错误
%% -----------------------------------------------------------------
check_pet_train(PlayerStatus,PetId,GoodsIdNum,MoneyType,AutoUp)->
	Pet = lib_pet:get_pet(PetId),
	case is_record(Pet,ets_pet) of
		true->
			{ok,FoodsNum} = get_goods_info(PlayerStatus,24000),
			TrainTime = data_pet:get_train_time(Pet#ets_pet.level,GoodsIdNum),
			if Pet#ets_pet.player_id =/= PlayerStatus#player.id ->
				   {fail,3}; %%灵兽不归你所有	
			   Pet#ets_pet.status=:=2->
				   {fail,4};%%正在训练中
			   FoodsNum<GoodsIdNum->
				   {fail,5};%%口粮数量不足
			   true->
				   case check_train_money(PlayerStatus,MoneyType,TrainTime,AutoUp,GoodsIdNum) of
					   {fail,Error}->{fail,Error};
					   {ok,TrainMoney}->{ok,Pet,TrainTime,TrainMoney}
				   end
			end;
		false->{fail,2}
	end.
%% -----------------------------------------------------------------
%%检查训练金钱
%% -----------------------------------------------------------------
check_train_money(PlayerStatus,MoneyType,TrainTime,AutoUp,GoodsIdNum)->
	case MoneyType of
		2->
			if  GoodsIdNum >3 ->{fail,6};
				AutoUp >0->{fail,7};
				true->
					TrainMoney=data_pet:get_train_money(MoneyType,TrainTime),
					case goods_util:is_enough_money(PlayerStatus,TrainMoney,coinonly) of
						false->{fail,8};
						true->{ok,TrainMoney}
					end
				end;
		1->
			TrainMoney=data_pet:get_train_money(MoneyType,TrainTime),
			case goods_util:is_enough_money(PlayerStatus,TrainMoney,gold) of
				false->{fail,9};
				true->{ok,TrainMoney}
			end;
		_->{fail,10}
	end.

%% -----------------------------------------------------------------
%%停止灵兽训练检查、
%% -----------------------------------------------------------------
check_stop_train(PlayerStatus,PetId)->
	Pet = lib_pet:get_pet(PetId),
	case is_record(Pet,ets_pet) of
		true->
			if Pet#ets_pet.player_id =/= PlayerStatus#player.id ->
				   {fail,3}; %%灵兽不归你所有	
			   Pet#ets_pet.status=/=2->
				   {fail,4};
			   true->
				   {ok,Pet}
			end;
		false->
			{fail,2}
	end.

%% -----------------------------------------------------------------
%% 灵兽喂养
%% -----------------------------------------------------------------
feed_pet(Status, [Pet, Food_type, GoodsUseNum]) ->
	case check_feed_pet(Status,Pet,Food_type,GoodsUseNum) of
		{ok,Status1} ->
			case (catch lib_pet:feed_pet(Status1,Pet,Food_type,GoodsUseNum)) of
				{ok,PetNew} ->
					%%剩余的灵兽口粮数
					{ok,RestNum} = get_goods_info(Status,Food_type),
					{ok,PetNew,RestNum};
				_Error  ->
					{fail,0}
			end;
		{fail,Res} ->
			{fail,Res}
	end.

%% -----------------------------------------------------------------
%% 灵兽自动喂养
%% -----------------------------------------------------------------
auto_feed_pet(PlayerStatus,Pet)->
	case Pet#ets_pet.happy < 1000 of
		true->
			case (catch feed_pet(PlayerStatus, [Pet, 24000, 1])) of
				{ok,NewPet,_RestNum} ->auto_feed_pet(PlayerStatus,NewPet);
				_->Pet
			end;
		false->Pet
	end.

check_feed_pet(Status,Pet,Food_type,GoodsUseNum) ->
	{ok,Food_num} = get_goods_info(Status,Food_type),
	if
		is_record(Pet,ets_pet) =:= false ->
			%%灵兽不存在
			{fail,2};
		Food_num =:= 0 ->
			%%物品不存在
			{fail,3};
		Pet#ets_pet.player_id =/= Status#player.id ->
			%%灵兽不归你所有
			{fail,4};
		Pet#ets_pet.happy >= 1000 ->
			%%快乐值已满
			{fail,5};
		Food_type =/= 24000 ->
			%%物品类型不正确
			{fail,7};
		Food_num < GoodsUseNum ->
			%%数量错误 
			{fail,8};
		true ->
			{ok,Status}
	end.
		
%% ----------------------------------------------------------------
%% 获取灵兽快乐值和经验值
%% ----------------------------------------------------------------
timer_trigger(Status,PetId) ->
	Pet = lib_pet:get_pet(PetId),
	MaxLevel = Status#player.lv,
	case(is_record(Pet,ets_pet)) of
		true ->
			Now = util:unixtime(),
			if
				%%数据校验错误不增长
				Now > (Pet#ets_pet.time + 60 + 5) orelse (Now < Pet#ets_pet.time + 60 -5)   ->
					lib_pet:update_time(Pet,Now),
					MaxExp = data_pet:get_upgrade_exp(Pet#ets_pet.level),
					if Pet#ets_pet.happy =< 0 ->
						   pet_attribute_effect(Status,Pet);
					   true ->
						   skip
					end,
					{ok,Pet#ets_pet.happy,Pet#ets_pet.exp,Pet#ets_pet.level,MaxExp,Pet#ets_pet.name,Pet#ets_pet.goods_id,Pet};
				%%快乐值为0自动收回
%%				Pet#ets_pet.happy =< 0 ->
%% 					RestPet = lib_pet:rest_pet(Pet),
%% 					{fail,RestPet};
					%%取消属性加成
%% 					pet_attribute_effect(Status,Pet),
%% 					MaxExp = data_pet:get_upgrade_exp(Pet#ets_pet.level),
%% 					{ok,Pet#ets_pet.happy,Pet#ets_pet.exp,Pet#ets_pet.level,MaxExp,Pet#ets_pet.name,Pet#ets_pet.goods_id,Pet};
				%%正常增长
				true ->
					%%灵兽经验加成buff
					Mult = Status#player.other#player_other.goods_buff#goods_cur_buff.pet_mult,
					MultExp = Status#player.other#player_other.goods_buff#goods_cur_buff.pet_mult_exp,
					[_,_,_,WarMult|_] = Status#player.other#player_other.war_honor_value,
					if MultExp > Mult ->
						   Mult1 = MultExp+WarMult;
					   true ->
						   Mult1 = Mult+WarMult
					end,
					PetNew1 = lib_pet:upgrade_pet(Status#player.other#player_other.pid_send,Pet,MaxLevel,Now,Mult1),
					%%VIP灵兽喂养
					{_,Auto,_} = lib_vip:get_vip_award(pet,Status),
					PetNew2 = case Auto of
								  false->PetNew1;
								  true->
									  case PetNew1#ets_pet.happy < 200 of
										  true->
									 		 auto_feed_pet(Status,PetNew1);
										  false->PetNew1
									  end
							  end,
					%%VIP自动升级
					PetNew = case Auto of
								 false->PetNew2;
								 true->
									case upgrade_by_using(Status,[PetNew2,24100]) of
								 		{ok,_,PetNew3}->PetNew3;
								 		{fail,_}->PetNew2
								 	end
							end,
					NewMaxExp = data_pet:get_upgrade_exp(PetNew#ets_pet.level),
					if PetNew2#ets_pet.happy =< 0 ->
						   pet_attribute_effect(Status,PetNew2);
					   true ->
						   skip
					end,
					{ok,PetNew#ets_pet.happy,PetNew#ets_pet.exp,PetNew#ets_pet.level,NewMaxExp,PetNew#ets_pet.name,PetNew#ets_pet.goods_id,PetNew}
			end;
		false ->
			{fail}
	end.
  
%% -----------------------------------------------------------------
%% 灵兽通过秘笈升级
%% -----------------------------------------------------------------
upgrade_by_using(Status,[Pet,Goods_id]) ->
	case is_record(Pet,ets_pet) of
		true ->
			MaxExp = data_pet:get_upgrade_exp(Pet#ets_pet.level),
			if
%% 				Pet#ets_pet.level < 15 ->
%% 					{fail,3};
				Pet#ets_pet.exp < MaxExp ->
					{fail,4};
				true ->
					case lib_pet:upgrade_by_using(Status,Pet,Goods_id) of
						{ok,PetNew} ->
								pet_attribute_effect(Status,PetNew),
								{ok,Status,PetNew};
						{fail,R} ->
								{fail,R}
					end
			end;
		_->{fail,2}
	end.

%%
%% 灵兽技能学习检查(通过技能)
%%
check_learn_skill(PlayerId,SkillId)->
	PetSplitSkillListLenth = length(lib_pet:get_all_split_skill(PlayerId)),
	if
		PetSplitSkillListLenth >= ?PET_MAX_GRID -> 
			{fail,1};
		true ->
			{ok,SkillId}
	end.
%% 	Pet = lib_pet:get_out_pet(PlayerId),
%% 	if
%% 		is_record(Pet ,ets_pet) =:= true ->
%% 			[SkillId1, _, _, _] = util:string_to_term(tool:to_list(Pet#ets_pet.skill_1)),
%% 			[SkillId2, _, _, _] = util:string_to_term(tool:to_list(Pet#ets_pet.skill_2)),
%% 			[SkillId3, _, _, _] = util:string_to_term(tool:to_list(Pet#ets_pet.skill_3)),
%% 			[SkillId4, _, _, _] = util:string_to_term(tool:to_list(Pet#ets_pet.skill_4)),
%% 			[SkillId5, _, _, _] = util:string_to_term(tool:to_list(Pet#ets_pet.skill_5)),
%% 			Skill_Ckeck = lists:member(SkillId,[SkillId1,SkillId2,SkillId3,SkillId4,SkillId5]),
%% 			if
%% 				Skill_Ckeck =:= false ->
%% 					{Skill ,Sid}=
%% 					if
%% 						SkillId1 =:= 0 ->
%% 							if
%% 								Pet#ets_pet.aptitude >= 20 ->
%% 									{skill_1,SkillId};
%% 								true ->
%% 									{fail,4}
%% 							end;
%% 						SkillId2 =:= 0 ->
%% 							if
%% 								Pet#ets_pet.aptitude >=35 ->
%% 									if Pet#ets_pet.level >=10->
%% 										{skill_2,SkillId};
%% 									   true->
%% 										   {fail,5}
%% 									end;
%% 								true ->
%% 									{fail,4}
%% 							end;
%% 						SkillId3 =:= 0 ->
%% 							if
%% 								Pet#ets_pet.aptitude >= 45 ->
%% 									if Pet#ets_pet.level >=15 ->
%% 										{skill_3,SkillId};
%% 									   true->
%% 										   {fail,5}
%% 									end;
%% 								true ->
%% 									{fail,4}
%% 							end;
%% 						SkillId4 =:= 0 ->
%% 							if
%% 								Pet#ets_pet.aptitude >=55 ->
%% 									if Pet#ets_pet.level >=20 ->
%% 										{skill_4,SkillId};
%% 									   true->
%% 										   {fail,5}
%% 									end;
%% 								true ->
%% 									{fail,4}%%资质不够
%% 							end;
%% 						SkillId5 =:= 0 -> 
%% 							if
%% 								Pet#ets_pet.chenge =/= 0 andalso Pet#ets_pet.aptitude >= 65 ->
%% 										{skill_5,SkillId};
%% 								true ->
%% 									{fail,6}%%未化形并且资质不到65
%% 							end;
%% 						true ->
%% 							{fail,1}
%% 					end,
%% 					if
%% 						Skill =/= fail ->
%% 							{ok,Pet,Skill,Sid};
%% 						true ->
%% 							%%技能已满
%% 							{fail,Sid}
%% 					end;
%% 				true ->
%% 					%%技能已学习
%% 					{fail,2}
%% 			end;
%% 		true ->
%% 			%%没有宠物在出战
%% 			{fail,3}
%% 	end.

%% ----------------------------------------------------------------
%% 灵兽技能遗忘
%% ----------------------------------------------------------------
mod_forget_skill(PlayerStatus,[PetId,Position])->
	case goods_util:is_enough_money(PlayerStatus,100,gold) of
		false->{error,4};
		true->
			Pet = lib_pet:get_pet(PlayerStatus#player.id,PetId),
			 if  % 灵兽不存在 2
				 Pet =:= []  -> {error,2};
				 true ->
					 if  % 该灵兽不归你所有
						 Pet#ets_pet.player_id =/= PlayerStatus#player.id -> {error,3};
						 true->
							 case lib_pet:get_skill_position(Position) of
								 {error,_}->{error,5};
								 {ok,Skill}->
									 Result = case Skill of
										 skill_1 ->
											 if Pet#ets_pet.skill_1 =:= 0 ->error;
												true->ok
											 end;
										 skill_2 -> 
											 if Pet#ets_pet.skill_2 =:= 0 ->error;
												true->ok
											 end;
										 skill_3 -> 
											 if Pet#ets_pet.skill_3 =:= 0 ->error;
												true->ok
											 end;
										skill_5 -> 
											 if Pet#ets_pet.skill_5 =:= 0 ->error;
												true->ok
											 end;
										 _ -> if Pet#ets_pet.skill_4 =:= 0 ->error;
												true->ok
											 end
									 end,
									 case Result of
										 ok->
									 		PetNew = lib_pet:forget_skill(PlayerStatus,Pet,Skill),
									 		NewPlayerStatus = lib_goods:cost_money(PlayerStatus,100,gold,4103),
									 		pet_attribute_effect(NewPlayerStatus,PetNew),
									 		{ok,NewPlayerStatus};
										 error->{error,5}
									 end
							 end
					 end
			 end
	end.
%% ----------------------------------------------------------------
%% 更新角色灵兽附加属性效果
%% ----------------------------------------------------------------
pet_attribute_effect(PlayerStatus,PetNew) ->
	%%更新人物信息
	if
		is_record(PetNew,ets_pet) ->
			if PetNew#ets_pet.status == 1 andalso PetNew#ets_pet.happy > 0 ->
					PetAttribute= lib_pet:get_pet_attribute(PetNew),
					PetSkillMultAttribute = lib_pet:get_pet_skill_effect(PetNew),
					PlayerStatus2 = PlayerStatus#player{other = PlayerStatus#player.other#player_other{pet_attribute=PetAttribute,pet_skill_mult_attribute = PetSkillMultAttribute}},
					PlayerStatus3 = lib_player:count_player_attribute(PlayerStatus2);
				true ->
					PetAttribute = [0,0,0,0],
					PetSkillMultAttribute = [[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0]],
					PlayerStatus2 = PlayerStatus#player{other = PlayerStatus#player.other#player_other{pet_attribute=PetAttribute,pet_skill_mult_attribute = PetSkillMultAttribute}},
					PlayerStatus3 = lib_player:count_player_attribute(PlayerStatus2)
			end,
			gen_server:cast(PlayerStatus3#player.other#player_other.pid,{'SET_PLAYER',PlayerStatus3}),
			lib_player:send_player_attribute(PlayerStatus3,2);
		true ->
			skip
	end.

%% ----------------------------------------------------------------
%% 获取灵兽道具信息
%% ----------------------------------------------------------------
get_goods_info(Status,Goods_id) ->
%% 	GoodsList = goods_util:get_goods(Goods_id,Status#player.id),
%% 	F = fun(Goods,Num) ->
%% 				Goods#goods.num + Num
%% 		end,
%% 	Total = lists:foldl(F,0,GoodsList),
	Total = goods_util:get_goods_num(Status#player.id, Goods_id,4),
	{ok,Total}.
	
	
%% -----------------------------------------------------------------
%% 获取灵兽信息
%% -----------------------------------------------------------------
get_pet_info(_Status, [PetId]) ->
   lib_pet:get_pet_info(PetId).

%% -----------------------------------------------------------------
%% 获取灵兽列表
%% -----------------------------------------------------------------
get_pet_list(_Status, [PlayerId]) ->
    Pet_List = lib_pet:get_pet_list(PlayerId),
	if
		length(Pet_List) > 0 ->
			[1,Pet_List];
		true ->
			[0,[]]
	end.

%%背包使用化形卡检查
judge_pet_chenge(PlayerStatus) ->
	Pet = lib_pet:get_out_pet(PlayerStatus#player.id),
	if  
		Pet =:= []  orelse is_record(Pet,ets_pet) =:= false -> %%灵兽没有出战 
			{fail,11};
		Pet#ets_pet.goods_id==24616->
			{fail,72};
		true ->
			Chenge = Pet#ets_pet.chenge,
			%%第一次化形条件
			if Chenge == 0 ->
				   if
					   Pet#ets_pet.level < 25-> %%灵兽等级小于25级
						   {fail,43};
					   Pet#ets_pet.aptitude < 55 -> %%灵兽资质小于55
						   {fail,44};
					   true ->
						   {ok,Pet}
				   end;
			   Chenge >= 1 andalso  Chenge =/= 2->%%灵兽已第一次化形
				   if
					   Pet#ets_pet.aptitude < 80 -> %%灵兽资质小于80
						   {fail,69};
					   Pet#ets_pet.grow < 60 -> %%成长小于60
						   {fail,70};
					   true ->
						   {ok,Pet}
				   end;
			   Chenge == 2 ->%%灵兽已化形
				   {fail,45};
			   true ->
				   {ok,Pet}
			end
	end.



%%分离技能
split_skill(PlayerStatus,[PetId]) ->
	case chack_split_skill(PlayerStatus,PetId) of
		{fail,Res} ->
			Res;
		{ok,Pet} ->
			lib_pet:split_skill(Pet) 
	end.

%%检查灵兽技能分离条件
chack_split_skill(PlayerStatus,PetId) ->
	Pet = lib_pet:get_pet_info(PetId),
	PetSplitSkillListLenth = length(lib_pet:get_all_split_skill(PlayerStatus#player.id)),
	if  % 灵兽不存在 2
        Pet =:= []  ->
			{fail,2};
        true ->           
            if  %% 该灵兽不归你所有 3
                Pet#ets_pet.player_id =/= PlayerStatus#player.id ->
					{fail,3};
                %% 休息状态灵兽才能分离技能
                Pet#ets_pet.status =/= 0 -> 
					{fail,4};
				%% 灵兽没有可分离技能
                Pet#ets_pet.skill_1 == <<"[0,0,0,0]">> andalso Pet#ets_pet.skill_2 == <<"[0,0,0,0]">> andalso Pet#ets_pet.skill_3 == <<"[0,0,0,0]">> andalso Pet#ets_pet.skill_4 == <<"[0,0,0,0]">> andalso Pet#ets_pet.skill_5 == <<"[0,0,0,0]">>	 andalso Pet#ets_pet.skill_6 == <<"[0,0,0,0]">>																													  -> 
					{fail,5};
				%% 超过最大分离技能格数
				PetSplitSkillListLenth >= ?PET_MAX_GRID ->
					{fail,6};
                true ->
					{ok,Pet}
            end
	end.


%%灵兽分离技能列表
get_all_split_skill(PlayerId) ->
	lib_pet:get_all_split_skill(PlayerId).

%%灵兽一键合成所有闲置技能
merge_all_split_skill(PlayerId) ->
	lib_pet:merge_all_split_skill(PlayerId).

%%技能合成或升级,分离 Oper(1为技能合并预览，2为正式技能合并)
drag_skill(PlayerId,PetId,Type,Oper,Skill1,Skill2) ->
	case check_drag_skill(PlayerId,PetId,Type,Skill1,Skill2) of
		{fail,Res} ->
			[Res,<<>>];
		{ok} ->
			lib_pet:drag_skill(PlayerId,PetId,Type,Oper,Skill1,Skill2)
	end.

%%检查拖动条件(Type 1为分离技能(从上面拉到下面),2灵兽学习技能或升级(从下面拉到上面),3为左右拖动)
check_drag_skill(PlayerId,PetId,Type,Skill1,Skill2) ->
	Pet = lib_pet:get_pet_info(PetId),
	MaxLevel = lib_pet:get_max_pet_level(PlayerId),
	[_Skill_Id1,Level1,Step1,SkillExp1]  = 
		if
			Skill1 == <<>> -> 
				[0,0,0,0];  
			true -> 
				util:string_to_term(tool:to_list(Skill1))
		end,
	[_Skill_Id2,Level2,Step2,SkillExp2] = 
		if
			Skill2 == <<>> -> 
				[0,0,0,0];
			true ->
				 util:string_to_term(tool:to_list(Skill2))
		end,
	if  
		Step1 < Step2 ->
			StepSkillExp1 = data_pet:get_step_exp(Step1),
			NewExp = SkillExp2+SkillExp1+StepSkillExp1,
			[NewLevel2,_,_] = lib_pet:update_skill_level(Level2,Step2,NewExp);
		true ->
			StepSkillExp2 = data_pet:get_step_exp(Step2),
			NewExp = SkillExp1+SkillExp2+StepSkillExp2,
			[NewLevel2,_,_] = lib_pet:update_skill_level(Level1,Step1,NewExp)
	end,
	if
		MaxLevel =/=0 andalso NewLevel2 > (MaxLevel+10) ->
			{fail,6};%%灵兽技能不能高于灵兽等级10级以上
		Type == 1 andalso Pet == [] -> %%没有指定主灵兽
			{fail,2};
		Type == 1 andalso Skill1 == <<>> -> %%需要指定灵兽主技能
			{fail,3};
		Type == 2 andalso Pet == [] -> %%没有指定主灵兽
			{fail,2};
		Type == 2 andalso Skill1 == <<>> -> %%需要指定灵兽闲置技能
			{fail,4};
		Type == 3 andalso PetId =/= 0 andalso Pet == [] ->
			{fail,2};
		Type == 3 andalso PetId =/= 0 andalso Skill1 == <<>> andalso Skill2 == <<>> -> 
			{fail,3};
		Type == 3 andalso PetId == 0 andalso Skill1 == <<>> andalso Skill2 == <<>> -> 
			{fail,4};
		true ->
			{ok}
	end.
		

%%灵兽购买面板
pet_buy_list(Player_Id) ->
	lib_pet:pet_buy_list(Player_Id).

%%刷新灵兽购买面板
flush_pet_buy_list(Status) ->
	if
		Status#player.gold < ?Flush_Need_Gold ->
			%%元宝不足
			[2,Status#player.gold];
		true ->
			Status1 = lib_goods:cost_money(Status, ?Flush_Need_Gold, gold, 4105),
			gen_server:cast(Status1#player.other#player_other.pid, {'SET_PLAYER', Status1}),		
			lib_pet:flush_pet_buy_list(Status1#player.id),
			[1,Status1#player.gold]
	end.

%%采集灵兽怪
collect_pet(Status, Mon) ->
	GoodsList = goods_util:get_goods_list_type_subtype(Status#player.id,4,30,17),
	PetCount = lib_pet:get_pet_count(Status#player.id),
	if
	    GoodsList == [] ->
			2; %%没有捕兽索
		PetCount >= ?MaxPetCount ->
			4; %%灵兽已满
		true ->
			NameColor = data_agent:get_realm_color(Status#player.realm),
			NewGoodsList = lists:reverse(goods_util:sort(GoodsList, goods_id)),
			GoodsInfo = lists:nth(1, NewGoodsList),
			gen_server:call(Status#player.other#player_other.pid_goods,{'delete_more',GoodsInfo#goods.goods_id,1}),
			Aptitude = get_pet_aptitude(0),
			Step = data_pet:get_grab_pet_step(GoodsInfo#goods.goods_id),
			case Step of
				0 -> SkillId = 0;
				_-> SkillId = data_pet:get_grab_pet_skill_id()
			end,
			PetTypeInfo = lib_pet:get_base_pet(data_pet:get_pet_type_by_montypeid(Mon#ets_mon.mid)),
			PetTypeInfo1 = PetTypeInfo#ets_base_pet{skill = SkillId},
			case lib_pet:give_pet(Status#player.id,PetTypeInfo1,Aptitude,Step) of
				{ok,_,_,_} -> 
					if
						Step == 4 ->
							Msg1 = io_lib:format("【<font color='~s'>~s</font>】心灵手巧，抓到的灵兽竟然带有<font color='#FEDB4F'>【~p阶~s】</font>！",[NameColor,Status#player.nickname,Step,data_pet:get_skill_name(SkillId)]),
							spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg1)end);
						Step == 5 ->
							Msg1 = io_lib:format("【<font color='~s'>~s</font>】竟与掌有<font color='#FEDB4F'>【~p阶~s】</font>的至尊圣兽达成契约，天意如此啊！",[NameColor,Status#player.nickname,Step,data_pet:get_skill_name(SkillId)]),
							spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg1)end);
						true ->
							skip
					end,
					{ok, BinData} = pt_41:write(41033, PetTypeInfo1#ets_base_pet.goods_id),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					10; %%改成返回物品类型
				{fail,_,_} -> 
					3
			end			
	end.

%%黄金蛋产生灵兽(生成一个随机的技能，等级为1,阶数为Step,经验为0)
egg_pet(Status, Step) ->
	Aptitude = get_pet_aptitude(0),
	PetTypeInfo = lib_pet:get_base_pet(data_pet:get_random_pet_type()),
	SkillId = data_pet:get_grab_pet_skill_id(),
	PetTypeInfo1 = PetTypeInfo#ets_base_pet{skill = SkillId},
	case (catch(lib_pet:give_pet(Status#player.id,PetTypeInfo1,Aptitude,Step))) of
		{ok,PetId,_Name,_Grow} ->
			Msg = io_lib:format("只见蛋壳一裂，一只神兽傻呼呼地向你走来！",[]),
			{ok, BinData1} = pt_11:write(11080, 2, Msg),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData1),
			{ok, BinData2} = pt_41:write(41033, PetTypeInfo1#ets_base_pet.goods_id),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData2),
			NameColor = data_agent:get_realm_color(Status#player.realm),
			if
				Step == 4 ->
					Msg1 = io_lib:format("【<font color='~s'>~s</font>】含辛茹苦，终于孵出带有<font color='#FEDB4F'>【~p阶~s】</font>的灵兽！",[NameColor,Status#player.nickname,Step,data_pet:get_skill_name(SkillId)]),
					spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg1)end);
				Step == 5 ->
					%%活动送神兽蛋
					lib_act_interf:get_god_pet(Status#player.other#player_other.pid, Status#player.nickname, 1, data_pet:get_skill_name(SkillId)),
					Msg1 = io_lib:format("【<font color='~s'>~s</font>】十年一剑，感动上苍，终于受到带有<font color='#FEDB4F'>【~p阶~s】</font>至尊圣兽的亲睐！",[NameColor,Status#player.nickname,Step,data_pet:get_skill_name(SkillId)]),
					spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg1)end);
				true ->
					skip
			end,
			%%添加幸运值
			Ets_Pet_Extra = lib_pet:get_pet_extra(Status#player.id),
			Ets_Pet_Extra1 = Ets_Pet_Extra#ets_pet_extra{lucky_value = Ets_Pet_Extra#ets_pet_extra.lucky_value+5},
			lib_pet:update_pet_extra(Ets_Pet_Extra1),
			%%设置了自动萃取
			lib_pet:auto_fetch_pet_exp(Status,PetId,Step);
		_Error ->
			skip
	end.		
		

%%判断灵兽栏已满
check_pet_is_full(PlayerId) ->
	PetCount = lib_pet:get_pet_count(PlayerId),
	if
		PetCount >= ?MaxPetCount ->
			true; %%灵兽已满
		true ->
			false %%灵兽未满
	end.

%%灵兽批量操作type 1为技能批量分离，2为灵兽放生
batch_oper(PlayerId,Type) ->
	lib_pet:batch_oper(PlayerId,Type).

%%出战灵兽技能经验自动增长
add_pet_skill_exp_auto(PlayerStatus,PetId) ->
	%%是否用极品灵兽经验丹
	MultExp = PlayerStatus#player.other#player_other.goods_buff#goods_cur_buff.pet_mult_exp,
	Now = util:unixtime(),
	Lasttimer = get(lasttimer),
	if Lasttimer == undefined ->
			put(lasttimer,(Now)),
			Lasttimer1 = 0;
		true ->
			Lasttimer1 = Lasttimer
	end,
	if
		Now - Lasttimer1 >= 5*60 ->%%5分钟加一次技能经验
			Pet = lib_pet:get_pet_info(PetId),
			if
				Pet =/= [] ->
					SkillList = [{1,Pet#ets_pet.skill_1},{2,Pet#ets_pet.skill_2},{3,Pet#ets_pet.skill_3},{4,Pet#ets_pet.skill_4},{5,Pet#ets_pet.skill_5},{6,Pet#ets_pet.skill_6}],
					NewPet = loop_add_pet_skill_exp(SkillList,Pet,MultExp),
					lib_pet:update_pet(NewPet),
					lib_pet:save_pet(NewPet),
					pet_attribute_effect(PlayerStatus,NewPet);
				true ->
					skip
			end;
		true ->
			skip
	end.

loop_add_pet_skill_exp([],Pet,_MultExp) ->
	Pet;
loop_add_pet_skill_exp([H | Rest],Pet,MultExp) ->
	Lv = Pet#ets_pet.level,
	{Skill_Order,Skill} = H,
	[Skill_Id,Level,Step,SkillExp] = util:string_to_term(tool:to_list(Skill)),
	if
		Skill_Id =/= 0 ->
			NewExp = SkillExp+15*MultExp,%%每次加1点
			[NewLevel1,NewStep1,NewExp1] = lib_pet:update_skill_level(Level,Step,NewExp),
			if
				NewLevel1 > Lv +10 ->
					loop_add_pet_skill_exp(Rest,Pet,MultExp);
				true ->
					NewSkill = util:term_to_string([Skill_Id,NewLevel1,NewStep1,NewExp1]),
					case Skill_Order of
						1 ->
							NewPet = Pet#ets_pet{skill_1 = tool:to_binary(NewSkill)};
						2 ->
							NewPet = Pet#ets_pet{skill_2 = tool:to_binary(NewSkill)};
						3 ->
							NewPet = Pet#ets_pet{skill_3 = tool:to_binary(NewSkill)};
						4 ->
							NewPet = Pet#ets_pet{skill_4 = tool:to_binary(NewSkill)};
						5 ->
							NewPet = Pet#ets_pet{skill_5 = tool:to_binary(NewSkill)};
						6 ->
							NewPet = Pet#ets_pet{skill_6 = tool:to_binary(NewSkill)}
					end,
					loop_add_pet_skill_exp(Rest,NewPet,MultExp)
			end;			
		true ->
			loop_add_pet_skill_exp(Rest,Pet,MultExp)
	end.

%%设置灵兽自动萃取的阶数
set_auto_step(Player_Id,Auto_Step) ->
	lib_pet:set_auto_step(Player_Id,Auto_Step).

%%随机批量购买面板列表
get_random_pet_buy_list(Player_Id) ->
	lib_pet:get_random_pet_buy_list(Player_Id).

%%随机批量购买面板购买动作Order为顺序号，为0是购买所有,单个购买顺序号1-6
buy_random_pet(PlayerStatus,Order) ->
	lib_pet:buy_random_pet(PlayerStatus,Order).

%%查询玩家的幸运值和经验槽经验值
query_lucky_exp(Player_Id) ->
	lib_pet:query_lucky_exp(Player_Id).

%%通过经验槽经验值提升技能等级
update_skill_level_by_exp(PlayerStatus,PetId,Skill) ->
	case check_update_skill_level(PlayerStatus#player.id,PetId,Skill) of
		{fail,Res} ->
			Res;
		{ok,Pet,Skill} ->
			lib_pet:update_skill_level_by_exp(PlayerStatus,Pet,Skill)
	end.
	
%%通过经验槽经验值提升技能等级
check_update_skill_level(PlayerId,PetId,Skill) ->
	Ets_Pet_Extra = lib_pet:get_pet_extra(PlayerId),
	TotalSkillExp = Ets_Pet_Extra#ets_pet_extra.skill_exp,
	Pet = lib_pet:get_pet_info(PetId),
	MaxLevel = lib_pet:get_max_pet_level(PlayerId),
	Skill_Order = lib_pet:find_pet_skill(Pet,Skill),
	[Skill_Id,Level,Step,SkillExp]  = 
		if
			Skill == <<>> -> 
				[0,0,0,0];  
			true -> 
				util:string_to_term(tool:to_list(Skill))
		end,
	NexpLevelExp = data_pet:get_pet_skill_exp(Level+1,Step),
	if
		Pet == [] -> %%没有指定主灵兽
			{fail,2};
		MaxLevel =/=0 andalso Level >= (MaxLevel+10) ->
			{fail,4};%%灵兽技能不能高于灵兽等级10级以上
		Skill_Id == 0 -> %%需要指定灵兽主技能
			{fail,3};
		Skill_Order == 0 -> %%需要指定灵兽主技能
			{fail,3};
		TotalSkillExp + SkillExp < NexpLevelExp ->
			{fail,5};
		Level >= 60 ->
			{fail,6}; 
		true ->
			{ok,Pet,Skill}
	end.

use_random_exp_dan(PlayerStatus,GoodsTypeId,GoodsNum) ->
	if 
		GoodsTypeId =/= 24107 ->
			skip;
		true ->
			lib_pet:use_random_exp_dan(PlayerStatus,GoodsTypeId,GoodsNum),
			gen_server:cast(PlayerStatus#player.other#player_other.pid_goods,{'delete_more',GoodsTypeId,GoodsNum})
	end.

%%灵兽一键萃取所有闲置技能
fetch_all_split_skill(PlayerStatus) ->
	lib_pet:fetch_all_split_skill(PlayerStatus).

%% -----------------------------------------------------------------
%%灵兽神兽蛋预览
%% -----------------------------------------------------------------
egg_view(PlayerId) ->
	lib_pet:egg_view(PlayerId).

%% -----------------------------------------------------------------
%% Type 1神兽蛋获取技能,2神兽蛋萃取经验
%% -----------------------------------------------------------------
fetch_egg_skill(Status,Type) ->
	EggNum = goods_util:get_goods_num(Status#player.id, 24800,4),
	PetSplitSkillListLenth = length(lib_pet:get_all_split_skill(Status#player.id)),
	Ets_Pet_Extra = lib_pet:get_pet_extra(Status#player.id),
	Ets_pet_extra_value = lib_pet:get_pet_extra_value(Status#player.id),
	AfterValueList1 = util:string_to_term(tool:to_list(Ets_pet_extra_value#ets_pet_extra_value.after_value1)),
	[New_PetTypeId,New_Skill_Id,New_Step] = 
	if AfterValueList1 == [] ->
		   [0,0,0];
	   true ->
		   [PetTypeId,Skill_Id,Step] = lists:flatten(AfterValueList1),
		   [PetTypeId,Skill_Id,Step]
	end,
	if EggNum =< 0 ->
		  {fail,2,Ets_Pet_Extra};%%背包没有神兽蛋
	   New_PetTypeId == 0 andalso New_Skill_Id == 0  andalso New_Step == 0 ->
		  {fail,2,Ets_Pet_Extra};%%背包没有神兽蛋
	   Type =/= 1 andalso Type =/= 2 ->
		  {fail,6,Ets_Pet_Extra};%%类型不对
       Type == 1 andalso New_PetTypeId =/= 0  andalso PetSplitSkillListLenth >= ?PET_MAX_GRID ->
		  {fail,3,Ets_Pet_Extra};%% 超过最大分离技能格数
	  true ->
		  lib_pet:fetch_egg_skill(Status,EggNum,Ets_Pet_Extra,Type)
	end.
	
%% -----------------------------------------------------------------
%% 1神兽蛋面板免费刷新,2批量购买面板免费刷新,3批量购买面板批量元宝刷新
%% -----------------------------------------------------------------
free_flush(Status,Type,Order) ->
	EggNum = goods_util:get_goods_num(Status#player.id, 24800,4),
	MaxFlushTimes = lib_pet:get_max_free_flush(),
	Ets_Pet_Extra = lib_pet:get_pet_extra(Status#player.id),
	FlushCost = lib_pet:get_flush_cost(),
	%%NullCellNum = length(gen_server:call(Status#player.other#player_other.pid_goods,{'null_cell'})), 
	%%神兽蛋免费刷新要有神兽蛋存在，批量购买免费刷新不需要神兽蛋
	if Type == 1 andalso EggNum =< 0 ->
		  {fail,2};%%背包没有神兽蛋
	  Type =/= 1 andalso Type =/= 2 andalso Type =/= 3->
		  {fail,4};%%类型不对
      Ets_Pet_Extra#ets_pet_extra.free_flush > MaxFlushTimes ->
		  {fail,3};%%没有免费刷新次数 
	  Type == 2 andalso (Order < 1 orelse  Order > 6)->
		  {fail,5};%%免费刷新位置不对
	  Type == 1 andalso Order =/= 0 ->
		  {fail,5};%%免费刷新位置不对
	  Ets_Pet_Extra#ets_pet_extra.free_flush >= MaxFlushTimes andalso Status#player.gold < FlushCost ->
		  {fail,6};%%刷新元宝不够
	  %%Type ==  1 andalso  NullCellNum < 1 ->
		 %% {fail,7};%%背包空间不足
	  Type == 3 andalso Status#player.gold < 56 ->
		   {fail,6};%%刷新元宝不够
	  true ->
		  if 
			  %%先判断是批量元宝刷新，再判断免费刷新(先用完免费刷新次数，再用单次元宝刷新)
			  Type == 3 ->
				 lib_pet:free_flush(Status,Ets_Pet_Extra,Order,Type,56);			  
			  MaxFlushTimes - Ets_Pet_Extra#ets_pet_extra.free_flush > 0->
				 %%免费刷新
				 lib_pet:free_flush(Status,Ets_Pet_Extra,Order,Type,0);
			 true ->
				 %%元宝刷新
				 lib_pet:free_flush(Status,Ets_Pet_Extra,Order,Type,FlushCost)
		  end
	end.


%%  战魂石预览
batt_stone_view(PlayerId,Gid) ->
	GoodsInfo = goods_util:get_goods(Gid),
	if is_record(GoodsInfo,goods) == false -> 
		   [2,0,0,0];
	   GoodsInfo#goods.player_id =/= PlayerId ->
		   [3,0,0,0];
	   true ->
		   lib_pet:batt_stone_view(PlayerId)
	end.
	
%%查看战斗技能批量刷新面板	
get_batch_batt_skill_list(PlayerId,Gid) ->
	GoodsInfo = goods_util:get_goods(Gid),
	if is_record(GoodsInfo,goods) == false -> 
		   [2,0,[]];
	   GoodsInfo#goods.player_id =/= PlayerId ->
		   [3,0,[]];
	   true ->
		   lib_pet:get_batch_batt_skill_list(PlayerId)
	end.
	

%%随机批量购买面板购买动作Order为顺序号，为0是购买所有,单个购买顺序号1-6
fetch_batch_batt_skill(PlayerStatus,Order) ->
	lib_pet:fetch_batch_batt_skill(PlayerStatus,Order).	

%%战斗技能刷新 Type 1为战魂石免费刷新　2为战魂石元宝刷新　3为战魂石批量刷新 4为灵水刷新单个技能 5为灵水批量刷新技能
fluse_batt_skill(Status,Gid,Type) ->
	Ets_Pet_Extra = lib_pet:get_pet_extra(Status#player.id),
	if  Type == 1 -> Cost = 0;
		Type == 2 -> Cost = 15;
		Type == 3 -> Cost = 160;
		Type == 4 -> Cost = 0;
		Type == 5 -> Cost = 0;
		true -> Cost = 0
	end,		
	%%灵水数量
	GoodsNum = goods_util:get_goods_num(Status#player.id, 24025,4),
	if Type == 4 -> NeedGoodsNum = 1;
	   Type == 5 -> NeedGoodsNum = 12;
	   true ->
		   NeedGoodsNum = 0
	end,
	GoodsInfo = goods_util:get_goods(Gid),
	%%NullCellNum = length(gen_server:call(Status#player.other#player_other.pid_goods,{'null_cell'})), 
	if is_record(GoodsInfo,goods) == false -> 
		   [2,Type,0,0,[]];%%物品不存在
	   GoodsInfo#goods.player_id =/= Status#player.id ->
		   [3,Type,0,0,[]];%%物品不归你所有
	   Type == 1 andalso Ets_Pet_Extra#ets_pet_extra.batt_free_flush > 0->
		   [4,Type,0,0,[]];%%类型不对
	    is_integer(Type) == false orelse (Type < 1 orelse Type > 5) ->
		   [5,Type,0,0,[]];%%类型不对
		Status#player.gold < Cost ->
		   [6,Type,0,0,[]];%%类型不对
		GoodsNum < NeedGoodsNum ->
		   [7,Type,0,0,[]];%%灵水数量不够
		%%NullCellNum < 1 ->
		   %%[8,Type,0,0,[]];%%背包空间不够
		true ->
		   lib_pet:fluse_batt_skill(Status,GoodsInfo,Ets_Pet_Extra,Type,Cost,NeedGoodsNum)
	end.
	
%%战斗技能取技能	 Order 0为忆魂石页面,1-12为战斗技能批量刷新面板
batt_skill_fetch(Status,Gid,Order) ->
	Ets_pet_extra_value = lib_pet:get_pet_extra_value(Status#player.id),
	GoodsInfo = goods_util:get_goods(Gid),
	if is_record(GoodsInfo,goods) == false -> 
		   2;%%物品不存在
	   GoodsInfo#goods.player_id =/= Status#player.id ->
		   3;%%物品不归你所有
	   is_record(Ets_pet_extra_value,ets_pet_extra_value) == false ->
		   4;%%没有对应技能
	   is_integer(Order) == false orelse Order < 0 orelse Order > 12 ->
		   6;%%技能书位置错误
		true ->
			AfterValueList1 = util:string_to_term(tool:to_list(Ets_pet_extra_value#ets_pet_extra_value.batt_after_value)),
			if AfterValueList1 == [] orelse AfterValueList1 == undefined ->
				   4;
			   length(AfterValueList1) < Order ->
				   6;
			   true ->
				   lib_pet:batt_skill_fetch(Status,GoodsInfo,Ets_pet_extra_value,Order)
			end
	end.


	
%%战斗技能书 Type 1技能书学习 
learn_batt_skill(Status,Gid,PetId) ->
	GoodsInfo = goods_util:get_goods(Gid),
	Pet = lib_pet:get_pet(PetId),
	if is_record(GoodsInfo,goods) == false -> 
		   [2,Status];%%物品不存在
	   GoodsInfo#goods.player_id =/= Status#player.id ->
		   [3,Status];%%物品不归你所有
	   GoodsInfo#goods.type =/= 30 orelse GoodsInfo#goods.subtype =/= 23 ->
		   [4,Status];%%物品不归你所有
	   is_record(Pet,ets_pet) == false ->
		   [5,Status];%%灵兽不存在
		Pet#ets_pet.player_id =/= Status#player.id ->
		   [6,Status];%%灵兽不归你所有
		(Status#player.bcoin+Status#player.coin) < 1000->
		   [12,Status];%%铜币不足
		true ->
			MaxBattSkillNum = data_pet:get_batt_skill_num(Pet#ets_pet.aptitude),
			Batt_skill1 = util:string_to_term(tool:to_list(Pet#ets_pet.batt_skill)),
			if Batt_skill1 == undefined ->
				   Batt_skill = [];
			   true ->
				   Batt_skill = Batt_skill1
			end,
			BattSkillTypeList = data_pet:get_pet_batt_skill_type(Batt_skill),
			[NewBattSkillType] = data_pet:get_pet_batt_skill_type([GoodsInfo#goods.goods_id]),
			IsStudyType = lists:member(NewBattSkillType, BattSkillTypeList),
			IsStudySkill = lists:member(GoodsInfo#goods.goods_id, BattSkillTypeList),
			AllTypeSkillIdList = data_pet:get_pet_batt_skill_type_skillIds(GoodsInfo#goods.goods_id),
			LvSize = length(AllTypeSkillIdList),
			if IsStudyType == true -> %%已经学习过此种类型的技能
			   	   if IsStudySkill == true ->
						  [9,Status];
					  true ->
						  HasStudySkillId = data_pet:get_pet_batt_skill_id(NewBattSkillType,Batt_skill),
						  NextSkillId = data_pet:get_next_pet_batt_skill(HasStudySkillId),
						  if NextSkillId == 0 ->%%已经是最高等级
								 [11,Status];
							 LvSize == 4 -> %%只有高级和顶级技能
								 Lv1 = data_pet:get_get_all_batt_skill_lv(HasStudySkillId),
								 Lv2 = data_pet:get_get_all_batt_skill_lv(GoodsInfo#goods.goods_id),
								 DiffLv = Lv2 - Lv1,
								 if DiffLv == 2 andalso Lv1 == 1 ->%%相关两级
										[14,Status];
									DiffLv == 2 andalso Lv1 == 2 ->%%相关两级
										[15,Status];
									DiffLv == 3 andalso Lv1 == 1 ->%%相关三级
										[14,Status];
									DiffLv < 1 ->%%比已学同类型等级低
										[16,Status];
									true ->
										lib_pet:learn_batt_skill(Status,GoodsInfo,Pet,2,Batt_skill,HasStudySkillId)
								 end;
							 NextSkillId == 0 orelse GoodsInfo#goods.goods_id == HasStudySkillId ->%%已经是最高等级
								 [11,Status];							 
							 true ->%%升级技能
								 lib_pet:learn_batt_skill(Status,GoodsInfo,Pet,2,Batt_skill,HasStudySkillId)
						  end
				   end;
			   true ->
				   if length(Batt_skill) >= MaxBattSkillNum ->
						  [10,Status];
					  true ->%%学习新技能
						  Lv2 = data_pet:get_get_all_batt_skill_lv(GoodsInfo#goods.goods_id),
						  if LvSize == 4 andalso Lv2 > 1 ->
								 [13,Status];
							 LvSize == 2 andalso Lv2 > 3 ->
								 [15,Status];
							 true ->
								 lib_pet:learn_batt_skill(Status,GoodsInfo,Pet,1,Batt_skill,0)
						  end
				   end
			end
	end.

%%战斗技能书 删除技能书
del_batt_skill(Status,Gid) ->
	GoodsInfo = goods_util:get_goods(Gid),
	if is_record(GoodsInfo,goods) == false -> 
		   [2,Status];%%物品不存在
	   GoodsInfo#goods.player_id =/= Status#player.id ->
		   [3,Status];%%物品不归你所有
	   GoodsInfo#goods.type =/= 30 orelse GoodsInfo#goods.subtype =/= 23 ->
		   [4,Status];%%物品不归你所有
		true ->
			lib_pet:del_batt_skill(Status,GoodsInfo)
	end.

%%战斗技能遗忘
forget_batt_skill(PlayerId,PetId,SkillId) ->
	Pet = lib_pet:get_pet(PetId),
	if is_record(Pet,ets_pet) == false ->
		   2;%%灵兽不存在
		Pet#ets_pet.player_id =/= PlayerId ->
		   3;%%灵兽不归你所有
		true ->
			Batt_skill = util:string_to_term(tool:to_list(Pet#ets_pet.batt_skill)),
			IsStudySkill = lists:member(SkillId, Batt_skill),
			if IsStudySkill ==  false ->
				   4;%%灵兽技能不存在
			   true ->
				   lib_pet:forget_batt_skill(Pet,Batt_skill,SkillId)
			end
	end.
	
%%战斗技能封印	
transfer_batt_skill(Status,PetId,SkillId) ->
	Pet = lib_pet:get_pet(PetId),
	Lv = data_pet:get_get_all_batt_skill_lv(SkillId), 
	if is_record(Pet,ets_pet) == false ->
		   2;%%灵兽不存在
		Pet#ets_pet.player_id =/= Status#player.id ->
		   3;%%灵兽不归你所有
		Lv < 1 orelse Lv > 4 ->
		   4;%%灵兽技能不存在   
	   true ->
			Batt_skill = util:string_to_term(tool:to_list(Pet#ets_pet.batt_skill)),
			IsStudySkill = lists:member(SkillId, Batt_skill),
			StoneType = 
				case Lv of
					1 -> 24120;%%初级封印石
					2 -> 24121;%%中级封印石
					3 -> 24122;%%高级封印石
					4 -> 24123 %%顶级封印石
				end,
			{ok,StoneNum} = get_goods_info(Status,StoneType),
			if IsStudySkill ==  false ->
				   4;%%灵兽技能不存在
			   StoneNum < 1 ->
				   5;%%封印石不存在
			   true ->
				   lib_pet:transfer_batt_skill(Status,Pet,Batt_skill,SkillId,StoneType)
			end
	end.
	
	
	
	
	
	
	
	
	
	
	
		