%%%--------------------------------------
%%% @Module  : lib_guild
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description : 氏族业务处理实现
%%%--------------------------------------
-module(lib_guild).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("guild_info.hrl").

-define(ACCUSE_MAX_TIME, 3*24*3600). 											%%弹劾不上线的最长时间
%% -define(ACCUSE_MAX_TIME, 100).%%测试用

-export([create_guild/10,
		 confirm_disband_guild/6,
		 apply_join_guild/12,
		 approve_guild_apply/4,
		 invite_join_guild/6,
		 response_invite_guild/12,
		 kickout_guild/6,
		 quit_guild/5,
		 modify_guild_announce/3,
		 demise_chief/5,
		 donate_money/2,
		 guild_upgrade/4,
		 resign_position/5,
		 modify_guild_depart_name/3,
		 guild_skills_upgrade/3,
		 get_guild_skills_info/4,
		 %%提供给外部调用的方法接口
		 validata_name/3,	%%判断字符串的大小是否合法
		 send_guild/4,
		 send_guild/5,
		 send_mail_guild_everyone/5,
		 send_guild_mail/2,
		 increase_guild_exp/6,
		 get_guild_member_info/2,
		 guild_set_and_send/3,
		 get_guild_skill_level/2,
		 get_guild_carry_info/1,
		 update_guild_carry_info/3,
		 update_guild_bandits_info/3,
		 get_guild_name/1,
		 accuse_chief/1,
		 accuse_chief_inner/4,
		 get_member_donate/2,%%获取氏族成员的氏族贡献
		 get_guild_friend/2,%%获取氏族成员列表(仅提供给庄园使用)
		 change_guildname/5,%%氏族改名
		 get_target_guild/2
		 ]).


%%
%% API Functions
%%
%% -----------------------------------------------------------------
%% 40001 创建氏族
%% -----------------------------------------------------------------
create_guild(MyGuildId, Level, Coin, BCoin, GoodsPid, PlayerId, PlayerName, Realm, Pid,
			 [GuildName, BuildCoin]) ->
	%%判断名字长度是否合法（2个字符到10个字符之间， 一个中文当两个字符算,而且不能存在非法字符）
	%%获取创建氏族的所需铜币
	CreateCoin = data_guild:get_guild_config(create_coin, []),
	case lib_words_ver:words_ver(GuildName) of 
		true ->%%文字没存在不合法字符
			case validata_name(GuildName, 2, 10) of
				true -> %%名字长度合法
					if  %%******************* 还是新手，不能创建氏族    **************************
						Realm == 100 ->
							[8, 0];
						%%******************* 测试的时候此代码将被注释    **************************
						%%你拥有了氏族
						MyGuildId /= 0 -> [2, 0];
						true ->
							case Level >= ?CREATE_GUILD_LV of 
								true ->
									case BuildCoin of
										CreateCoin -> %%使用金币建帮
											if 	%%判定铜币是否足够:（铜+绑定铜一起计算）。
												(Coin < 0) orelse (BCoin < 0) orelse  (BuildCoin < 0)  orelse (Coin+BCoin)  < BuildCoin  -> [4, 0];
												true ->
													NewGuildName = tool:to_binary(GuildName),
													Guild = lib_guild_inner:get_guild_by_name(NewGuildName),
													if
														Guild /= [] -> [6, 0];
														true ->
															case lib_guild_inner:create_guild(PlayerId, PlayerName, Realm, NewGuildName, 0, 0) of
																{ok, GuildId} ->
																	gen_server:cast(Pid, {'guild', null, PlayerId}),
																	[1, GuildId];
																_ -> error
															end
													end
											end;
										0 -> %%使用建帮令
											NewGuildName = tool:to_binary(GuildName),
											Guild = lib_guild_inner:get_guild_by_name(NewGuildName),
											if %%氏族名已存在
												Guild /= [] -> [6, 0];
												true ->
													[BaseGoodsId, CreateNum] = data_guild:get_guild_config(create_guild_card, []),
													case gen_server:call(GoodsPid, {'goods_find', PlayerId, BaseGoodsId}) of
														false -> %%建帮令信息不存在
															[10, 0];
														GoodsInfo ->
															case gen_server:call(GoodsPid, {'delete_more', GoodsInfo#goods.goods_id, CreateNum}) of
																1 ->%%扣除物品成功
																	case lib_guild_inner:create_guild(PlayerId, PlayerName, Realm, NewGuildName, 1, 2) of
																		{ok, NewGuildId} ->
																			gen_server:cast(Pid, {'guild', null, PlayerId}),
																			[1, NewGuildId];
																		_ -> error
																	end;
																_ ->%%扣除物品失败
																	error
															end
													end
											end;
										_ ->
											error
									end;
								false ->%%等级不够
									[3, 0]
							end
					end;
				false -> %%名字小于2个汉字或者大于8个汉字，出错
					[7, 0]
			end;
		false ->
			[9, 0]
	end.

%% -----------------------------------------------------------------
%% 40002 解散氏族
%% -----------------------------------------------------------------
confirm_disband_guild(PlayerId, PlayerName, PlayerGuildId, PlayerGuildName, PlayerPosition, [GuildId]) ->
    %% ?DEBUG("confirm_disband_guild: GuildId=[~p]", [GuildId]),
    Guild = lib_guild_inner:get_guild(GuildId),
  %%  NowTime = util:unixtime(),
    if % 氏族不存在
       Guild =:= [] -> 2;
       true ->
           if  % 你尚未加入任何氏族
               PlayerGuildId == 0 -> 3;
               % 你不是该氏族成员
               PlayerGuildId /= GuildId -> 4;
               % 你无权散该氏族
               PlayerPosition /= 1 -> 5;
			   Guild#ets_guild.sky_apply =:= 1 ->
				   7;%%报了名氏族战
			    Guild#ets_guild.unions =/= 0 -> %%在结盟日程中，不能解散！
					8;
               % 可以解散氏族
               true ->
                   case lib_guild_inner:confirm_disband_guild(PlayerGuildId, PlayerGuildName, PlayerId, PlayerName) of
                        ok  ->
							 %%氏族联盟数据更新处理
							lib_guild_union:update_guild_info(disband_guild, {GuildId}),
							%%删除ets中 的有关该氏族日志记录
							lib_guild_inner:delete_log_guild(PlayerGuildId),
							1;
                        _   -> 0
                   end
            end
    end.


%% -----------------------------------------------------------------
%% 40004 申请加入氏族
%% -----------------------------------------------------------------
apply_join_guild(My_id, My_nickname, My_guild_id, My_realm, My_lv, My_quit_guild_time, Pid, PlayerSex, PlayerJobs, PlayerCareer, PlayerVip, [GuildId]) ->
    %% ?DEBUG("apply_join_guild: GuildId=[~p]", [GuildId]),
    Guild = lib_guild_inner:get_guild(GuildId),	
    if  % 氏族不存在
        Guild =:= [] -> 
			[2];
        true ->
			gen_server:cast(Pid, {'guild', null, My_id}),
			#ets_guild{realm = GuildRealm,
					   member_num = GuildMemberNum} = Guild,
				%%计算氏族人数上限
			PopulationLevel = lib_guild:get_guild_skill_level(GuildId, 3),
			GuildMemberCapacity = data_guild:get_guild_config(guild_member_base,[]) + PopulationLevel * 5,
			TimeNow = util:unixtime(),
			TimeRest = TimeNow - My_quit_guild_time,
			ApplyNum = lib_guild_inner:get_guild_apply_num(GuildId),
			if  %%申请人数超上限了
				ApplyNum >= ?GUILD_APPLY_NUM_LIMIT ->
					[9];
				% 你已经加入氏族
                My_guild_id /= 0 -> 
					%% ?DEBUG("~ts",["************you have join the guild************"]),
					[3];
                % 部落不同
				My_realm == 100 -> [4];%%还是新手
                My_realm /= GuildRealm -> [4];
                % 帮众数已满
                GuildMemberNum >=  GuildMemberCapacity -> [5];
				%%等级不够
				My_lv < ?CREATE_GUILD_LV -> [7];
				%%最近有加入并退出过氏族，间隔时间太短
				TimeRest =< ?QUIT_GUILD_TIME_LIMIT -> [8];
                true ->
                    GuildApply = lib_guild_inner:get_guild_apply_by_player_id(My_id, GuildId),
                    if  % 你已经申请加入该氏族
                        GuildApply /= [] -> [6];
                        true ->
                            case lib_guild_inner:add_guild_apply(My_id, My_nickname, My_lv, PlayerSex, PlayerJobs, PlayerCareer, PlayerVip, GuildId) of
                                ok  -> 
 									[1];
                                _   -> [0]
                            end
                    end
            end
    end.


%% -----------------------------------------------------------------
%% 40005 处理审批加入氏族
%% -----------------------------------------------------------------

approve_guild_apply(OfficeGuildId, _OfficeGuildName, OfficeGuildPosition, [HandleResult, ApplyList]) ->
	ApplyListLen = length(ApplyList),
	if
		OfficeGuildId =:= 0 ->
			[3, 0];
		OfficeGuildPosition > 7 ->
			[4, 0];
		true ->
			case lib_guild_inner:get_guild(OfficeGuildId) of
				[] ->
					[5, 0];
				Guild ->
					#ets_guild{realm = GuildRealm,
							   name = GuildName,
							   member_num = MemberNum} = Guild,
					%%计算氏族人数上限
					PopulationLevel = lib_guild:get_guild_skill_level(OfficeGuildId, 3),
					MemberCapacity = data_guild:get_guild_config(guild_member_base,[]) + PopulationLevel * 5,
					
					case HandleResult of
						0 ->%%批量拒绝
							lib_guild_inner:refuse_join_guild_inner(OfficeGuildId, GuildName, ApplyList),
							[1, 0];
						1 ->
							RestNum = MemberCapacity - MemberNum,
							case RestNum >= ApplyListLen of
								false ->%位子不够
									[2, RestNum];
								true ->%%哇塞，位子居然够哦
									{ResultNum, SendList} = lib_guild_inner:reply_apply_guild_each(0, [], OfficeGuildId, GuildName, GuildRealm, ApplyList),
									GuildNew = Guild#ets_guild{member_num = MemberNum + ResultNum},
									lib_guild_inner:update_guild(GuildNew),
									%%氏族联盟数据更新处理
									lib_guild_union:update_guild_info(upmem, {GuildNew#ets_guild.id, GuildNew#ets_guild.member_num, MemberCapacity}),
									spawn(lib_guild_inner, handle_msg_to_player_each, [SendList]),
									[1, 0]
							end;
						_ ->
							[0, 0]
					end
			end
	end.
		
%% -----------------------------------------------------------------
%% 40006 邀请加入氏族
%% -----------------------------------------------------------------
invite_join_guild(MyPlayerId, My_guild_id, My_realm, My_nickname, My_guild_position, [PlayerName]) ->
    if   % 你没有加入任何氏族
         My_guild_id == 0 -> [2, 0];
         % 你无权邀请(族长和长老，堂主可以)
         My_guild_position > 7 -> [3, 0];
         true ->
             PlayerInfo = lib_guild_inner:get_player_guild_info_by_name(PlayerName),
             Guild = lib_guild_inner:get_guild(My_guild_id),
             if  % 对方玩家不存在
                 PlayerInfo =:= [] -> [4, 0];
                 % 氏族数据缺失
                 Guild =:= []  ->
                     [0, 0];
                 true ->
                     [PlayerId, PlayerRealm, PlayerGuildId, _PlayerGuildName, 
					  _PlayerGuildPosition, PlayerLv, PlayerQuitGuildTime,
					  _PlayerSex, _PlayerJobs, _PlayerLastLoginTime, _PlayerOnlineFlag,
					  _PlayerCareer, _PlayerCulture, _PlayerDepartMentId] = PlayerInfo,
					 #ets_guild{member_num = GuildMemberNum} = Guild,
					 %%计算氏族人数上限
					 PopulationLevel = lib_guild:get_guild_skill_level(My_guild_id, 3),
					 GuildMemberCapacity = data_guild:get_guild_config(guild_member_base,[]) + PopulationLevel * 5,
					 
					 TimeNow = util:unixtime(),
					 TimeRest = TimeNow - PlayerQuitGuildTime,					 
                     if  % 对方已经拥有氏族
                         PlayerGuildId =/= 0 -> [5, 0];
                         % 部落不同
                         PlayerRealm =/= My_realm -> [6, 0];
						 %%对方等级不够
						 PlayerLv < ?CREATE_GUILD_LV -> [9, 0];
						 %%最近有加入并退出过氏族，间隔时间太短
						 TimeRest =< 43200 -> [10, 0];
                         % 帮众数已满
                         GuildMemberNum >=  GuildMemberCapacity -> [7, 0];
                         true ->
                             GuildInvite = lib_guild_inner:get_guild_invite_by_player_id(PlayerId, My_guild_id),
                             if  % 已邀请过
                                 GuildInvite =/= [] -> [8, 0];
                                 % 可以邀请
                                 true ->
                                     case lib_guild_inner:add_guild_invite(PlayerId, MyPlayerId, My_guild_id, My_nickname) of
                                         ok  -> [1, PlayerId];
                                         _   -> [0, 0]
                                     end
                             end
                     end
             end
    end.

%% -----------------------------------------------------------------
%% 40007 回应氏族邀请
%% -----------------------------------------------------------------
response_invite_guild(My_id, My_guild_id, My_nickname, PlayerSex, PlayerJobs, PlayerLevel, 
					  PlayerLastLoginTime, PlayerOnlineFlag, PlayerCareer, PlayerCulture,
					  PlayerVip,
					  [GuildId, ResponseResult]) ->
	Guild = lib_guild_inner:get_guild(GuildId),
	if  % 氏族不存在
		Guild =:= [] -> error;
		true ->
			#ets_guild{name = GuildName, 
					   member_num = GuildMemberNum} = Guild,
			%%计算氏族人数上限
			PopulationLevel = lib_guild:get_guild_skill_level(GuildId, 3),
			GuildMemberCapacity = data_guild:get_guild_config(guild_member_base,[]) + PopulationLevel * 5,
			
			case lib_guild_inner:get_guild_invite_by_player_id(My_id, GuildId) of
				[] ->
					[3, <<>>, 0, 0, <<>>];
				GuildInvite ->
					RecommonderId = GuildInvite#ets_guild_invite.recommander_id,
					RecommanderName = GuildInvite#ets_guild_invite.recommander_name,
					case ResponseResult of
						0 ->%%拒绝邀请
							case lib_guild_inner:remove_guild_invite(My_id, GuildId) of
								ok -> [1, <<>>, 0, 0, RecommanderName];
								_  -> [0, <<>>, 0, 0, <<>>]
							end;
						1 ->
							if
								My_guild_id =/= 0 ->
									[4, <<>>, 0, 0, <<>>];
								GuildMemberNum >= GuildMemberCapacity ->
									[5, <<>>, 0, 0, <<>>];
								true ->
									DefaultPostion = data_guild:get_guild_config(default_position, []),
									%%添加氏族成员，并且同时删除氏族申请和氏族邀请的所有相关数据
									case lib_guild_inner:add_guild_member(My_id, My_nickname, GuildId, GuildName, DefaultPostion,
																		  PlayerSex, PlayerJobs, PlayerLevel, PlayerLastLoginTime, 
																		  PlayerOnlineFlag, PlayerCareer, PlayerCulture, PlayerVip) of
										ok ->
											% 更新缓存
											GuildNew = Guild#ets_guild{member_num = GuildMemberNum+1},
											lib_guild_inner:update_guild(GuildNew),
											%%氏族联盟数据更新处理
											lib_guild_union:update_guild_info(upmem, {GuildNew#ets_guild.id, GuildNew#ets_guild.member_num, GuildMemberCapacity}),
											%%添加成员加入氏族日志
%% 											lib_guild_inner:jion_guild_log(My_nickname, GuildId, GuildName),
											erlang:spawn(lib_guild_inner, jion_guild_log, [My_nickname, GuildId, GuildName]),
											[1, tool:to_binary(GuildName), DefaultPostion, RecommonderId, RecommanderName];
										_  -> [0, <<>>, 0, 0, <<>>]
									end
							end;
						_ ->
							[0, <<>>, 0, 0, <<>>]
					end
			end
	end.
							
				
%% -----------------------------------------------------------------
%% 40008 开除帮众
%% -----------------------------------------------------------------
kickout_guild(PlayerId, MyPlayerName, GuildId, My_guild_position, My_guild_depart_id, [KickOutPlayerId]) ->
    if   % 你没有加入任何氏族
         GuildId == 0 -> [2, <<>>];
         % 你没有踢出权限(族长,长老和堂主可以踢出)
         My_guild_position > 7 -> [3, <<>>];
         % 不能踢出自己
         KickOutPlayerId == PlayerId -> [4, <<>>];
         true ->
             PlayerInfo = lib_guild_inner:get_player_guild_info(KickOutPlayerId),
             Guild      = lib_guild_inner:get_guild(GuildId),
             if  % 对方玩家不存在
                 PlayerInfo =:= [] -> [5, <<>>];
                 % 氏族数据缺失
                 Guild =:= []  ->
                     [0, <<>>];
                 true ->
                     [PlayerNickname, _PlayerRealm, PlayerGuildId, _PlayerGuildName, 
					  PlayerGuildPosition, _PlayerLv, _PlayerQuitGuildTime,
					  _PlayerSex, _PlayerJobs, _PlayerLastLoginTime, _PlayerOnlineFlag, 
					  _PlayerCareer, _PlayerCulture, PlayerDepartMentId, _PlayerVip] = PlayerInfo,
					 #ets_guild{deputy_chief1_id = DeputyChiefId1,
								deputy_chief2_id = DeputyChiefId2,
								member_num = MemberNum,
								deputy_chief_num = DeputyChiefNum} = Guild,
                     if  % 对方没有氏族
                         PlayerGuildId == 0 -> [6, <<>>];
                         % 对方不是本帮成员
                         PlayerGuildId /= GuildId -> [7, <<>>];
                         % 对方职位不在你之下
                         PlayerGuildPosition =< My_guild_position -> [8, <<>>];
						 %%长老只能踢堂内弟子和一般弟子
%% 						 %%你的权限不足,堂主只能踢本堂的弟子或者一般弟子
						 (My_guild_position >= 2) andalso (PlayerGuildPosition < 8) -> 
							 [3, <<>>];
						 My_guild_position >= 4 andalso PlayerGuildPosition >= 8
						   andalso (My_guild_depart_id  =/= PlayerDepartMentId 
								   andalso PlayerDepartMentId =/= 5)  ->
							 [9, <<>>];
                         % 可以踢出
                         true ->
                             case lib_guild_inner:remove_guild_member(0, KickOutPlayerId, GuildId, 
																	  DeputyChiefId1, DeputyChiefId2) of
                                 [ok, MemberType] ->
									 %%计算氏族人数上限
									 PopulationLevel = lib_guild:get_guild_skill_level(GuildId, 3),
									 MemberCapacity = data_guild:get_guild_config(guild_member_base,[]) + PopulationLevel * 5,
                                         % 更新缓存 
                                         case MemberType of 
                                             0 ->
                                                 GuildNew = Guild#ets_guild{member_num = MemberNum-1},
												 %%氏族联盟数据更新处理
												 lib_guild_union:update_guild_info(upmem, {GuildNew#ets_guild.id, GuildNew#ets_guild.member_num, MemberCapacity}),
                                                 lib_guild_inner:update_guild(GuildNew);
                                             1 ->
                                                 GuildNew = Guild#ets_guild{member_num         = MemberNum-1,
                                                                            deputy_chief_num   = DeputyChiefNum -1,
                                                                            deputy_chief1_id   = 0,
                                                                            deputy_chief1_name = <<>>},
												 %%氏族联盟数据更新处理
												 lib_guild_union:update_guild_info(upmem, {GuildNew#ets_guild.id, GuildNew#ets_guild.member_num, MemberCapacity}),
                                                 lib_guild_inner:update_guild(GuildNew);
                                             2 ->
                                                 GuildNew = Guild#ets_guild{member_num         = MemberNum-1,
                                                                            deputy_chief_num   = DeputyChiefNum -1,
                                                                            deputy_chief2_id   = 0,
                                                                            deputy_chief2_name = <<>>},
												 %%氏族联盟数据更新处理
												 lib_guild_union:update_guild_info(upmem, {GuildNew#ets_guild.id, GuildNew#ets_guild.member_num, MemberCapacity}),
                                                 lib_guild_inner:update_guild(GuildNew)
                                         end,
										 %%添加成员被踢出氏族的日志
%% 										 lib_guild_inner:kickout_guild_log(Guild, MyPlayerName, PlayerNickname),
										 erlang:spawn(lib_guild_inner, kickout_guild_log, [Guild, MyPlayerName, PlayerNickname]),
                                         [1, PlayerNickname];
                                 _  ->
                                        [0, <<>>]
                             end
                     end
             end
    end.


%% -----------------------------------------------------------------
%% 40009 退出氏族
%% -----------------------------------------------------------------
quit_guild(PlayerId, PlayerNickName, GuildId, GuildPosition, [QuitTime]) ->
    Guild  = lib_guild_inner:get_guild(GuildId),
    if  % 氏族不存在
        Guild =:= [] -> 2;
        true ->
			#ets_guild{deputy_chief1_id = DeputyChiefId1,
					   deputy_chief2_id = DeputyChiefId2,
					   member_num = MemberNum,
					   deputy_chief_num = DeputyChiefNum} = Guild,
			if  % 你尚未加入任何氏族
                GuildId =:= 0 -> 3;
                % 你拥有职位不能直接退出
                GuildPosition < 12 -> 4;
                % 可以退出氏族
                true ->
                    case lib_guild_inner:remove_guild_member(QuitTime, PlayerId, GuildId,
													    DeputyChiefId1, DeputyChiefId2) of
                        [ok, MemberType] ->
							%%计算氏族人数上限
							PopulationLevel = lib_guild:get_guild_skill_level(GuildId, 3),
							MemberCapacity = data_guild:get_guild_config(guild_member_base,[]) + PopulationLevel * 5,
                            % 更新缓存
                            case MemberType of 
                                0 ->
                                    GuildNew = Guild#ets_guild{member_num = MemberNum-1},
                                    lib_guild_inner:update_guild(GuildNew),
									%%氏族联盟数据更新处理
									lib_guild_union:update_guild_info(upmem, {GuildNew#ets_guild.id, GuildNew#ets_guild.member_num, MemberCapacity}),
									lib_guild_inner:quit_guild_log(PlayerNickName, Guild);
                                1 ->
                                    GuildNew = Guild#ets_guild{member_num         = MemberNum-1,
                                                               deputy_chief_num   = DeputyChiefNum -1,
                                                               deputy_chief1_id   = 0,
                                                               deputy_chief1_name = <<>>},
                                    lib_guild_inner:update_guild(GuildNew),
									%%氏族联盟数据更新处理
									lib_guild_union:update_guild_info(upmem, {GuildNew#ets_guild.id, GuildNew#ets_guild.member_num, MemberCapacity}),
									lib_guild_inner:quit_guild_log(PlayerNickName, Guild);
                                2 ->
                                    GuildNew = Guild#ets_guild{member_num         = MemberNum-1,
                                                               deputy_chief_num   = DeputyChiefNum -1,
                                                               deputy_chief2_id   = 0,
                                                               deputy_chief2_name = <<>>},
                                    lib_guild_inner:update_guild(GuildNew),
									%%氏族联盟数据更新处理
									lib_guild_union:update_guild_info(upmem, {GuildNew#ets_guild.id, GuildNew#ets_guild.member_num, MemberCapacity}),
									lib_guild_inner:quit_guild_log(PlayerNickName, Guild)
                            end,
							1;
                         _ -> 0
                    end
            end
    end.

%% -----------------------------------------------------------------
%% 40016 修改氏族公告
%% -----------------------------------------------------------------
modify_guild_announce(My_guild_id, My_guild_position, [GuildId, Announce]) ->
    Guild = lib_guild_inner:get_guild(GuildId),
    if  % 氏族不存在
        Guild =:= [] -> [2];
        true ->
			case validata_name(Announce, 0, 200) of
				true ->%%中文字符少于100个（包括标点符号）
					case lib_words_ver:words_ver(Announce) of
						true ->
							if
								% 你没有加入任何氏族
								My_guild_id == 0 -> [3];
								% 你不是该氏族成员
								My_guild_id /= GuildId -> [4];
								% 你无权修改(族长和副族长可以)
								My_guild_position > 2 -> [5];
								% 可以修改
								true ->
									case lib_guild_inner:modify_guild_announce(GuildId, Announce) of
										ok  ->
											% 更新缓存
											AnnounceBin = tool:to_binary(Announce),
											GuildNew = Guild#ets_guild{announce = AnnounceBin},
											lib_guild_inner:update_guild(GuildNew),
											[1];
										_   -> [0]
									end
							end;
						false ->%%公告内容非法
							[7]
					end;
				false ->%%名字太长
					[6]
			end
	end.


%% -----------------------------------------------------------------
%% 40018 禅让族长
%% -----------------------------------------------------------------
demise_chief(My_id, My_nickname, My_guild_id, My_guild_position, [PlayerId]) ->
    if   % 你没有加入任何氏族
         My_guild_id == 0 -> [2, <<>>];
         % 你不是族长
         My_guild_position /= 1 -> [3, <<>>];
         % 不能禅让给自己
         PlayerId == My_id  -> [4, <<>>];
         true ->
             PlayerInfo = lib_guild_inner:get_player_guild_info(PlayerId),
             Guild      = lib_guild_inner:get_guild(My_guild_id),
             if  % 对方玩家不存在
                 PlayerInfo =:= [] -> [5, <<>>];
                 % 氏族数据缺失
                 Guild =:= []  ->
                     [0, <<>>];
                 true ->
                     [PlayerNickname, _PlayerRealm, PlayerGuildId, _PlayerGuildName, 
					  _PlayerGuildPosition, _PlayerLv, _PlayerQuitGuildTime,
					  _PlayerSex, _PlayerJobs, _PlayerLastLoginTime,
					  _PlayerOnlineFlag, _PlayerCareer, _PlayerCulture, _PlayerDepartMentId, _PlayerVip] = PlayerInfo,
                     [DeputyChiefId1, DeputyChiefId2] = 
						 [Guild#ets_guild.deputy_chief1_id, Guild#ets_guild.deputy_chief2_id],
                     if  % 对方没有氏族
                         PlayerGuildId == 0 -> [6, <<>>];
                         % 对方不是本帮成员
                         PlayerGuildId /= My_guild_id -> [7, <<>>];
%%                          % 对方不是副族长
%%                          PlayerGuildPosition /= 2 -> [8, <<>>];
						 Guild#ets_guild.unions =/= 0 ->%%在结盟流程中，不可以禅让！
							 [9, <<>>];
                         % 可以禅让
                         true ->
                             case lib_guild_inner:demise_chief(My_id, My_nickname, PlayerId, PlayerNickname, 
														 My_guild_id, DeputyChiefId1, DeputyChiefId2) of
                                 [ok, MemberType] ->
                                     case MemberType of 
                                         0 ->
											 GuildNew = Guild#ets_guild{chief_id           = PlayerId,
                                                                        chief_name         = PlayerNickname},
											 lib_guild_inner:update_guild(GuildNew),
											 %%氏族联盟数据更新处理
											 lib_guild_union:update_guild_info(demise_guild, {GuildNew#ets_guild.id, GuildNew#ets_guild.chief_id, GuildNew#ets_guild.chief_name}),
											 lib_guild_inner:demise_chief_log(My_nickname, tool:to_list(PlayerNickname), GuildNew);
                                         1 ->
                                             GuildNew = Guild#ets_guild{chief_id           = PlayerId,
                                                                        chief_name         = PlayerNickname,
                                                                        deputy_chief1_id   = 0,
                                                                        deputy_chief1_name = <<>>,
																		deputy_chief_num = Guild#ets_guild.deputy_chief_num - 1},
                                             lib_guild_inner:update_guild(GuildNew),
											 %%氏族联盟数据更新处理
											 lib_guild_union:update_guild_info(demise_guild, {GuildNew#ets_guild.id, GuildNew#ets_guild.chief_id, GuildNew#ets_guild.chief_name}),
											 lib_guild_inner:demise_chief_log(My_nickname, tool:to_list(PlayerNickname), GuildNew);
                                         2 ->
                                             GuildNew = Guild#ets_guild{chief_id           = PlayerId,
                                                                        chief_name         = PlayerNickname,
                                                                        deputy_chief2_id   = 0,
                                                                        deputy_chief2_name = <<>>,
																		deputy_chief_num = Guild#ets_guild.deputy_chief_num - 1},
                                             lib_guild_inner:update_guild(GuildNew),
											 %%氏族联盟数据更新处理
											 lib_guild_union:update_guild_info(demise_guild, {GuildNew#ets_guild.id, GuildNew#ets_guild.chief_id, GuildNew#ets_guild.chief_name}),
											 lib_guild_inner:demise_chief_log(My_nickname, tool:to_list(PlayerNickname), GuildNew)
                                     end,
                                     [1, PlayerNickname];
                                  _ -> [0, <<>>]
                             end
                     end
             end
    end.

%% -----------------------------------------------------------------
%% 40019 捐献钱币
%% -----------------------------------------------------------------
donate_money(Status, [GuildId, Num]) ->
	#player{nickname = PlayerName,
			coin = Coin,
			bcoin = BCoin,
			guild_id = MyGuildId} = Status,
    if   % 你没有加入任何氏族
         MyGuildId == 0 -> [3, Status];
         % 你不是该氏族成员
         MyGuildId /= GuildId -> [4, Status];
         % 你没有这么多钱或者技能令
         (Num < 0) orelse (Coin < 0) orelse (BCoin < 0) orelse (Coin + BCoin) < Num  -> [5, Status];
         true ->
             Guild = lib_guild_inner:get_guild(GuildId),
             if  % 氏族不存在
                 Guild =:= [] -> [2, Status];
                 true ->
                     case lib_guild_inner:donate_money(Status, GuildId, Num) of
                         {ok, NewStatus}  ->
                             % 更新缓存
                             GuildNew = Guild#ets_guild{funds = Guild#ets_guild.funds+Num},
                             lib_guild_inner:update_guild(GuildNew),
							 lib_guild_inner:donate_money_log(PlayerName, GuildNew, Num),
                             [1, NewStatus];
                         _   -> [0, Status]
                     end
             end             
   end.


%% -----------------------------------------------------------------
%% 氏族升级请求
%% -----------------------------------------------------------------
guild_upgrade(My_guild_id, _My_lv, GuildPosition, [GuildId]) ->
	if %%你没有加入任何氏族
		My_guild_id == 0 -> [2, 0, 0, 0];
		%%你不是该氏族成员
		My_guild_id /= GuildId -> [3, 0, 0, 0];
		%%没权限
		GuildPosition >= 2 -> [8, 0, 0, 0];
		true ->
			Guild = lib_guild_inner:get_guild(GuildId),
			if 	%%氏族数据缺失
				Guild =:= [] -> [4, 0, 0, 0];			
				true ->		
					#ets_guild{name = GuildName, 
							   level = Level,
							   upgrade_last_time = UpGradeTime,
							   funds = NowFunds,
							   exp = NowExp} = Guild,
					case UpGradeTime =:= 0 of
						true ->
							GuildLevelLimit = data_guild:get_guild_config(guild_level_limit, []),
							[NeedFunds, NeedExp, NeedTime, _AddSkills] = data_guild:get_guild_upgrade_info(Level + 1),
							if 	%%氏族资金不足
								NeedFunds > NowFunds ->
									[6, 0, 0, 0];
								%%氏族经验不足，系统出错
								NeedExp > NowExp ->
									[7, 0, 0, 0];
								Level >= GuildLevelLimit ->
									[9, 0, 0, 0];%%等级满了
								true ->
									NewExp = 0,%%扣经验
									NewFunds = NowFunds - NeedFunds,
									NewUpGradeTime = util:unixtime(),
									%%更新氏族数据库信息
									lib_guild_inner:update_guild_upgrade(GuildId, NewFunds, NewExp, NewUpGradeTime),
									%%插入氏族升级记录
									UpgradeEndTime = NewUpGradeTime + NeedTime,
									UpGradeList = 
										#ets_guild_upgrade_status{guild_id = GuildId,
																  guild_name = GuildName,
																  current_level = Level,
																  upgrade_succeed_time = UpgradeEndTime},
									lib_guild_inner:insert_into_ets_guild_upgrade(UpGradeList),
									%%更新氏族信息
									NewGuild = Guild#ets_guild{funds = NewFunds,
															    exp = NewExp,
															    upgrade_last_time = NewUpGradeTime},
									lib_guild_inner:update_guild(NewGuild),
									[1, NowExp, NeedTime, NewUpGradeTime]
							end;
						false ->
							[5, 0, 0, 0]
					end
			end
	end.


%% -----------------------------------------------------------------
%% 40022 辞去官职
%% -----------------------------------------------------------------
resign_position(My_id, My_nickname, My_guild_id, My_guild_position, [GuildId]) ->
    %% ?DEBUG(" **** mod_guild:resign_position: GuildId=[~p]  **** ", [GuildId]),
    DefaultPosition = data_guild:get_guild_config(default_position, []),
    if   % 你没有加入任何氏族
         My_guild_id == 0 -> [2, My_guild_position];
         % 你不是该氏族成员
         My_guild_id /= GuildId -> [3, My_guild_position];
         % 你没有官职
         My_guild_position   >= 12 -> [4, My_guild_position];
         % 族长不能辞去官职
         My_guild_position =:= 1 -> [5, My_guild_position];
         true ->
             Guild   = lib_guild_inner:get_guild(GuildId),
             if  % 氏族不存在
                 Guild =:= []  ->
                     ?ERROR_MSG("** resign_position: guild not found, id=[~p] **", [My_guild_id]),
                     [6, My_guild_position];
                 true ->
                     [DeputyChielfId1, DeputyChielfId2, DeputyChiefNum] = 
						 [Guild#ets_guild.deputy_chief1_id, Guild#ets_guild.deputy_chief2_id, Guild#ets_guild.deputy_chief_num],
                     case lib_guild_inner:resign_position(My_id, My_nickname, My_guild_id, My_guild_position, 
													DefaultPosition, DeputyChielfId1, DeputyChielfId2) of
						 1 ->
							 GuildNew = Guild#ets_guild{deputy_chief_num   = DeputyChiefNum-1,
														deputy_chief1_id   = 0,
														deputy_chief1_name = <<>>},
							 lib_guild_inner:update_guild(GuildNew);
						 2 ->
							 GuildNew = Guild#ets_guild{deputy_chief_num   = DeputyChiefNum-1,
														deputy_chief2_id   = 0,
														deputy_chief2_name = <<>>},
							 lib_guild_inner:update_guild(GuildNew);
						 _ ->
							 void
					 end,
					 [1, DefaultPosition]
			 end
	end.


%% -----------------------------------------------------------------
%% 40029 修改氏族堂堂名
%% -----------------------------------------------------------------
modify_guild_depart_name(My_guild_id, My_guild_position, 
						 [GuildId, DepartId, DepartNameNew, DepartsNamesStr]) ->
	DepartsNameLen = length(string:tokens(DepartsNamesStr, ",")),
	DepartsNames = tool:to_binary(DepartsNamesStr),
	Guild = lib_guild_inner:get_guild(GuildId),
	if%%氏族不存在
		Guild =:= [] -> [2];
		DepartsNameLen =/= 4 ->%%堂名数量长度有误
			[0];
		DepartId =< 0 orelse DepartId >= 5 ->%%堂Id出错
			[0];
		true ->
			 if %%你没有加入任何氏族
				 My_guild_id =:= 0 -> [3];
				 %%你不是本帮成员
				 My_guild_id /= GuildId -> [4];
				 %%你不是族长
				 My_guild_position >= 2 -> [5];
				 %%可以修改
				 true ->
					 case validata_name(DepartNameNew, 6, 6) of 
						 true ->
							 case lib_words_ver:words_ver(DepartNameNew) of
								 true ->
									 DepartName = tool:to_binary(DepartNameNew),
									 case lib_guild_inner:modify_guild_depart_name(GuildId, DepartId, DepartName, DepartsNames) of
										 ok ->
											 %%更新缓存
											 %%更新氏族缓存
											 GuildNew = Guild#ets_guild{depart_names = DepartsNames},
											 lib_guild_inner:update_guild(GuildNew),
											 %%更新氏族成员缓存
											 GuildMems = lib_guild_inner:get_guild_member_by_guildid_and_departid(GuildId, DepartId),
											 lists:foreach(fun(Mem) -> 
																   MemNew = Mem#ets_guild_member{guild_depart_name = DepartName},
																   lib_guild_inner:update_guild_member(MemNew),
																   modify_guild_depart_name_player(Mem#ets_guild_member.player_id, DepartId, DepartName)
														   end, GuildMems),
											 [1];
										 _ -> [0]
									 end;
								 false ->
									 [7]
							 end;
						 false ->
							 [6]
					 end
			 end
	end.


%% -----------------------------------------------------------------
%% 获取氏族技能信息
%% -----------------------------------------------------------------
get_guild_skills_info(My_guild_id, _My_guild_position, PidSend, [GuildId]) ->
	[ReturnSkills, ReturnRecords] = 
	if %%你没有加入任何氏族
		My_guild_id == 0 -> 
			[0, []];
		%%你不是该氏族成员
		My_guild_id /= GuildId -> 
			[0, []];
		true ->
			Guild = lib_guild_inner:get_guild(GuildId),
			if %%氏族数据缺失
				Guild =:= [] -> 
					[0, []];
				true ->
					Records = lib_guild_inner:get_guild_skills_attribute(Guild#ets_guild.id),
					case length(Records) =:= 3 of
						true ->
							Skills = Guild#ets_guild.skills,
							RecordsResult = lists:map(fun(X) -> 
															  lib_guild_inner:handle_guild_skills_info(X)
													  end, Records),		
							[Skills, RecordsResult];
						false ->
							[0, []]
					end
			end
	end,
	Data = list_to_binary(ReturnRecords),
	Len = length(ReturnRecords),
	{ok, BinData} = pt_40:write(40031, [ReturnSkills, Len, Data]),
	lib_send:send_to_sid(PidSend, BinData).


%% -----------------------------------------------------------------
%% 40032氏族技能升级
%% -----------------------------------------------------------------
guild_skills_upgrade(My_guild_id, My_guild_position, [GuildId, SkillId, Level]) ->
	if %%你没有加入任何氏族
		My_guild_id == 0 -> [2, Level];
		%%你不是该氏族成员
		My_guild_id /= GuildId -> [2, Level];
		My_guild_position /= 1 -> [3, Level];
		true ->
			Guild = lib_guild_inner:get_guild(GuildId),
			if %%氏族数据出错
				Guild =:= [] -> 
					error;
				true ->
					GuildSkillList = lib_guild_inner:get_ets_guild_skill_attribute_one(GuildId, SkillId),
					if GuildSkillList =:= [] -> 
						   error;
					   true ->
						   [GuildSkill] = GuildSkillList,
						   SkillLevelOld = GuildSkill#ets_guild_skills_attribute.skill_level,
						   [LevelBase, LevelLimit, FundsBase] = data_guild:get_guild_skill_upgrade_info(SkillId),
						   {LevelBaseA, LevelBaseB} = LevelBase,
						   NeedLevel = (SkillLevelOld+1) * LevelBaseA + LevelBaseB,
						   NeedFunds = (SkillLevelOld+1) * FundsBase,
						   if 
							   SkillLevelOld >= LevelLimit ->
								   [4, Level];%%升级满了
							   Guild#ets_guild.skills =< 0 ->%%技能点不足
								   [6, Level];
							   NeedFunds > Guild#ets_guild.funds ->
								   [7, Level];%%氏族资金不足
							   NeedLevel =< Guild#ets_guild.level 
								 andalso NeedFunds =< Guild#ets_guild.funds ->
								   case SkillId of
									   1 ->%%氏族仓库
										   if %%判断是否已经到了升级上限
											   GuildSkill#ets_guild_skills_attribute.skill_level < LevelLimit ->
												   %%更新氏族技能属性信息
												   SkillLevelNew =  SkillLevelOld + 1,
												   lib_guild_inner:guild_skills_level_upgrade(GuildId, SkillId, SkillLevelNew),
												   GuildSkillNew = GuildSkill#ets_guild_skills_attribute{skill_level = SkillLevelNew},
												   %%更新氏族技能缓存
												   lib_guild_inner:update_guild_skill_attribute(GuildSkillNew),
												   %%更新氏族信息
												   StorageLimitNew = Guild#ets_guild.level * 25,
												   SkillsNew = Guild#ets_guild.skills - 1,
												   ValueList = [{storage_limit, StorageLimitNew},
																{skills, SkillsNew},
																{funds, Guild#ets_guild.funds - NeedFunds}],
												   WhereList = [{id, GuildId}],
												   lib_guild_inner:update_guild_by_skills(ValueList, WhereList),
												   %%更新氏族数据库技能点数
												   GuildNew = Guild#ets_guild{storage_limit = StorageLimitNew,
																			  skills = SkillsNew,
																			  funds = Guild#ets_guild.funds - NeedFunds},
												   %%更新氏族缓存
												   lib_guild_inner:update_guild(GuildNew),
												   [1, SkillLevelNew];
											   true ->%%升级满了
												   [4, Level]
										   end;
%% 									end;
									   2 -> %%氏族福利
										   if  %%判断是否已经到了升级上限
											   GuildSkill#ets_guild_skills_attribute.skill_level < LevelLimit ->
												   %%更新氏族技能属性信息
												   SkillLevelNew =  SkillLevelOld + 1,
												   lib_guild_inner:guild_skills_level_upgrade(GuildId, SkillId, SkillLevelNew),
												   GuildSkillNew = GuildSkill#ets_guild_skills_attribute{skill_level = SkillLevelNew},
												   %%更新氏族技能缓存
												   lib_guild_inner:update_guild_skill_attribute(GuildSkillNew),
												   %%更新氏族信息
												   SkillsNew = Guild#ets_guild.skills - 1,
												   ValueList = [{skills, SkillsNew}, {funds, Guild#ets_guild.funds - NeedFunds}],
												   WhereList = [{id, GuildId}],
												   lib_guild_inner:update_guild_by_skills(ValueList, WhereList),
												   %%更新氏族数据库技能点数
												   GuildNew = Guild#ets_guild{skills = SkillsNew,
																			  funds = Guild#ets_guild.funds - NeedFunds},
												   %%更新氏族缓存
												   lib_guild_inner:update_guild(GuildNew),
												   [1, SkillLevelNew];
											   true ->
												   [4, Level]
										   end;
%% 									end;
									   3 ->%%人口
										   if 
											   GuildSkill#ets_guild_skills_attribute.skill_level < LevelLimit ->
										   %%更新氏族技能属性信息
												   SkillLevelNew =  SkillLevelOld + 1,
												   lib_guild_inner:guild_skills_level_upgrade(GuildId, SkillId, SkillLevelNew),
												   GuildSkillNew = GuildSkill#ets_guild_skills_attribute{skill_level = SkillLevelNew},
												   %%更新氏族技能缓存
												   lib_guild_inner:update_guild_skill_attribute(GuildSkillNew),
												   %%更新氏族信息
												   MemberCapacity = SkillLevelNew * 5 + data_guild:get_guild_config(guild_member_base,[]),
												   SkillsNew = Guild#ets_guild.skills - 1,
												   ValueList = [{member_capacity, MemberCapacity},
																{skills, SkillsNew},
																{funds, Guild#ets_guild.funds - NeedFunds}],
												   WhereList = [{id, GuildId}],
												   lib_guild_inner:update_guild_by_skills(ValueList, WhereList),
												   %%更新氏族数据库技能点数
												   GuildNew = Guild#ets_guild{member_capacity = MemberCapacity,
																			  skills = SkillsNew,
																			  funds = Guild#ets_guild.funds - NeedFunds},
												   %%更新氏族缓存
												   lib_guild_inner:update_guild(GuildNew),
												   %%氏族联盟数据更新处理
												   lib_guild_union:update_guild_info(upmem, {GuildNew#ets_guild.id, GuildNew#ets_guild.member_num, MemberCapacity}),
												   [1, SkillLevelNew];
											   true ->%%升级满了
												   [4, Level]
										   end;
%% 									end
									   _ ->
										   error
								   end;
							   true ->
								   [5, Level]
						   end
					end
			end
	end.


%% ---------------------------------------------
%% 对外提供的方法函数
%% ---------------------------------------------
%% -----------------------------------------------------------------
%% 发送消息给氏族所有成员_1
%% -----------------------------------------------------------------
send_guild(Type, PlayerId, GuildId, Data) ->
	try 
		gen_server:cast(mod_guild:get_mod_guild_pid(), 
					 {apply_cast, lib_guild_inner, send_guild, [Type, PlayerId, GuildId, Data]})	
	catch
		_:_ -> []
	end.

%% -----------------------------------------------------------------
%% 发送消息给氏族所有成员_2
%% -----------------------------------------------------------------
send_guild(Type, PlayerId, GuildId, MsgType, Data) ->
	try 
		gen_server:cast(mod_guild:get_mod_guild_pid(), 
					 {apply_cast, lib_guild_inner, send_guild, [Type, PlayerId, GuildId, MsgType, Data]})	
	catch
		_:_ -> []
	end.

%% -----------------------------------------------------------------
%% 发送邮件给成员
%% -----------------------------------------------------------------
%% %%%%族长让位, 氏族技能升级，群发邮件
send_mail_guild_everyone(Type, PlayerId, GuildId, SubjectType, BaseParam) ->
	try 
		gen_server:cast(mod_guild:get_mod_guild_pid(), 
					 {apply_cast, lib_guild_inner, send_mail_guild_everyone_inner, 
					  [Type, PlayerId, GuildId, SubjectType, BaseParam]})
	catch
		_:_ -> []
	end.

%%专门用于发送帮派事件邮件方法
send_guild_mail(SubjectType, Param) ->
	try 
		gen_server:cast(mod_guild:get_mod_guild_pid(), 
					 {apply_cast, lib_guild_inner, send_mail, [SubjectType, Param]})	
	catch
		_:_ -> []
	end.


%%
%% Local Functions
%%
%% -----------------------------------------------------------------
%%判断名字长度是否合法（2个字符到10个字符之间， 一个中文当两个字符算）
%% -----------------------------------------------------------------
validata_name(Name, MinLen, MaxLen) ->
	case asn1rt:utf8_binary_to_list(list_to_binary(Name)) of
		{ok, CharList} ->
			Len = string_width(CharList),
			(Len =< MaxLen andalso Len >= MinLen);
		{error, _Reason} ->
			false
	end.
string_width(String) ->
	string_width(String, 0).
string_width([], Len) ->
	Len;
string_width([H|T], Len) ->
	case H > 255 of
		true ->%%是非英文字符
			string_width(T, Len + 2);
		false ->%%是因为字符或者数字
			string_width(T, Len + 1)
	end.
	

%% 修改角色的氏族堂堂名
modify_guild_depart_name_player(Id, DepartId, DepartName) ->
	case lib_player:get_player_pid(Id) of
		[] -> [];
		Pid -> gen_server:cast(Pid, {'SET_PLAYER', [{guild_depart_id, DepartId},{guild_depart_name, DepartName}]})
	end.

%% -----------------------------------------------------------------
%% 做帮派任务，添加帮派经验
%% -----------------------------------------------------------------
increase_guild_exp(PlayerId, GuildId, Exp, Contribute, Fundsbase,Type) ->
	Guild = lib_guild_inner:get_guild(GuildId),
	if %%氏族数据出错
		Guild =:= [] -> 
			error;
		true ->
			%%Type>0为氏族运镖任务
			if Type>0 andalso Fundsbase > 0 ->
				   AddFunds = Guild#ets_guild.level * 7500 +Fundsbase;
			   true->AddFunds=Fundsbase
			end,
			GuildLevelLimit = data_guild:get_guild_config(guild_level_limit,[]),
			case Guild#ets_guild.level > 0 andalso Guild#ets_guild.level < GuildLevelLimit of
				true ->%%氏族已经是最大等级了
					case Guild#ets_guild.upgrade_last_time =:= 0 of
						true ->
							[_Funds, NeedExp, _NeedTime, _AddSkills] = 
								data_guild:get_guild_upgrade_info(Guild#ets_guild.level+1),
							if %%对帮派经验进行大小控制
								NeedExp =< Guild#ets_guild.exp ->%%经验满了,不再增加
									NewGuild = Guild#ets_guild{funds = Guild#ets_guild.funds+AddFunds},
									db_agent:increase_guild_exp(GuildId, 0, AddFunds),
									%%更新氏族缓存
									lib_guild_inner:update_guild(NewGuild);
								NeedExp =< (Guild#ets_guild.exp + Exp)  ->%%做了这任务，经验就满了
									NewGuild = Guild#ets_guild{exp = NeedExp,
															   funds = Guild#ets_guild.funds+AddFunds},
									db_agent:increase_guild_exp(GuildId, NeedExp - Guild#ets_guild.exp, AddFunds),
									%%更新氏族缓存
									lib_guild_inner:update_guild(NewGuild);
								true ->
									NewGuild = Guild#ets_guild{exp = Guild#ets_guild.exp + Exp,
															   funds = Guild#ets_guild.funds+AddFunds},
									db_agent:increase_guild_exp(GuildId, Exp, AddFunds),
									%%更新氏族缓存
									lib_guild_inner:update_guild(NewGuild)
							end;
						false ->%%正在升级，所以经验不加
							NewGuild = Guild#ets_guild{funds = Guild#ets_guild.funds+AddFunds},
							db_agent:increase_guild_exp(GuildId, 0, AddFunds),
							%%更新氏族缓存
							lib_guild_inner:update_guild(NewGuild)
					end;
				false ->%%已经是最高级了，不再增加经验
					NewGuild = Guild#ets_guild{funds = Guild#ets_guild.funds+AddFunds},
					db_agent:increase_guild_exp(GuildId, 0, AddFunds),
					%%更新氏族缓存
					lib_guild_inner:update_guild(NewGuild)
			end,
			%%更新氏族贡献
			lib_guild_inner:money_add_donation(PlayerId, Contribute, 0, GuildId)
	end.
%% -----------------------------------------------------------------
%% 获取氏族成员的个人贡献和等级
%% -----------------------------------------------------------------
get_guild_member_info(GuildId, PlayerId) ->
	try
		gen_server:call(mod_guild:get_mod_guild_pid(), 
						{'get_guild_member_info', [GuildId, PlayerId]})
	catch
		_:_ ->
			{0, 0}
	end.


guild_set_and_send(Type,Param, Status) ->
	case Type of
		guild_new_member ->%% 氏族新成员加入
			cast_guild_new_member(Param, Status);
		guild_invite_join ->%% 氏族邀请加入
			cast_guild_invite_join(Param, Status);
		guild_kickout ->%%氏族成员被踢出
			cast_guild_kickout(Param, Status);
		guild_demise_chief ->%% 氏族族长禅让
			cast_guild_demise_chief(Param, Status);
		guild_accuse_chief -> %%弹劾族长
			cast_guild_accuse_chief(Param, Status);
		confirm_disband_guild ->%% 氏族解散
			cast_confirm_disband_guild(Param, Status);
		guild_skill_upgrade -> %%氏族技能升级
			cast_guild_skill_upgrade(Param, Status);
		guild_upgrade ->%% 氏族升级
			cast_guild_upgrade(Param, Status);
		guild_reject_invite -> %% 氏族拒绝邀请
			cast_guild_reject_invite(Param, Status);
		guild_reject_apply -> %% 氏族拒绝申请
			cast_guild_reject_apply(Param, Status);
%% 		guild_give_title -> %% 氏族头衔授予(暂时没用到)
%% 			cast_guild_give_title(Param, Status);
		guild_set_position ->%% 氏族职位改变
			cast_guild_set_position(Param, Status);
		guild_wareshoue_goods ->%%氏族仓库物品变化
			case_guild_wareshoue_goods(Param, Status);
		upgrade_h_skill ->%%氏族高级技能升级通知
			case_guild_upgrade_h_skill(Param, Status);
		add_guild_reputation ->%%增加氏族技能令的通知
			case_add_guild_reputation(Param, Status);
		guild_carry_help ->%%氏族运镖求救通告
			case_guild_carry_help(Param, Status);
		pk_call_guildhelp ->%%氏族成员被打，去救援
			lib_guild_call:cast_receive_pkhelp(Param, Status);
		chief_convence ->%%族长召唤
			lib_guild_call:cast_receive_convence(Param, Status);
		notice_sky_player ->%%通知参加神岛空战的的所有成员
			lib_skyrush:cast_notice_sky_player(Param, Status);
	_ ->%%其他情况，出错
		Status
	end.

cast_guild_new_member(Param, Status) ->
	[PlayerId, PlayerName, GuildId, GuildName, GuildPosition] = Param,
	case PlayerId == Status#player.id  of
		true  ->% 自己加入
			%%获取角色氏族功勋
			{GAlliance, _GFeats, _GuildSkills} = lib_guild_weal:get_guild_h_skills_info(GuildId, Status#player.id),
			% 保存状态
			Status1 = Status#player{guild_id = GuildId,
									guild_name = tool:to_binary(GuildName),
									guild_position = GuildPosition,
									guild_depart_id = 5,
									other = Status#player.other#player_other{guild_feats = 0,	%%氏族功勋变回0
																			 g_alliance = GAlliance}	%%联盟中的氏族Id
								   },
																			
			mod_player:save_online_diff(Status,Status1),
            % 发送通知
            {ok, Bin} = pt_40:write(40000, [1, PlayerId, PlayerName, GuildId, GuildName]),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin),
			%%做加入氏族的成就统计
			lib_achieve:check_achieve_finish(Status#player.other#player_other.pid_send, Status#player.id, 604, [1]),
			case Status#player.lv >= 35 of
				true ->%%加氏族
					lib_guild_wish:join_guild(Status1#player.id, Status1#player.nickname, Status1#player.sex, Status1#player.career, Status1#player.guild_id);
				false ->
					skip
			end,
            Status1;
		false ->% 其他人加入
            % 发送通知
            {ok, Bin} = pt_40:write(40000, [1, PlayerId, PlayerName, GuildId, GuildName]),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin),
            Status
	end.
cast_guild_invite_join(Param, Status) ->
	[GuildId, GuildName, RecommanderId, RecommanderName] = Param,
	{ok, Bin} = pt_40:write(40000, [2, GuildId, GuildName, RecommanderId, RecommanderName]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin),
	Status.
cast_guild_kickout(Param, Status) ->
	[PlayerId, PlayerName, GuildId, GuildName] = Param,
	case PlayerId == Status#player.id  of
		true  ->% 自己被踢出
            % 保存状态
			Status1 = Status#player{guild_id       = 0,
									guild_name     = <<>>,
									guild_position = 0,
									guild_depart_id = 0,
									guild_depart_name = <<>>,
									guild_title = <<>>,
									quit_guild_time = 0,
									other = Status#player.other#player_other{guild_feats = 0,	%%氏族功勋变回0
																			 g_alliance = []	%%联盟中的氏族Id清空
																			}
								   },
            mod_player:save_online_diff(Status,Status1),
			%%处理帮派任务
%% 			lib_task:abnegate_guild_task(Status),
			gen_server:cast(Status#player.other#player_other.pid_task,{'guild_task_del',Status}),
			%%处理氏族祝福数据
			lib_guild_wish:leave_guild(Status#player.id),
			% 发送通知
            {ok, Bin} = pt_40:write(40000, [3, PlayerId, PlayerName, GuildId, GuildName]),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin),
            Status1;
        % 其他人被踢出
		false ->
            % 发送通知
            {ok, Bin} = pt_40:write(40000, [3, PlayerId, PlayerName, GuildId, GuildName]),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin),
			Status
	end.
cast_guild_demise_chief(Param, Status) ->
	[OldChiefId, OldChiefName, NewChiefId, NewChiefName] = Param,
	case NewChiefId == Status#player.id  of
		true  ->% 自己是新族长
            % 保存状态
			Status1 = Status#player{guild_position = 1, guild_depart_id = 5, guild_depart_name = <<>>},
            mod_player:save_online_diff(Status,Status1),
            % 发送通知
            {ok, Bin} = pt_40:write(40000, [5, OldChiefId, OldChiefName, NewChiefId, NewChiefName]),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin),
			Status1;
		false ->% 其他人是新族长
            % 发送通知
            {ok, Bin} = pt_40:write(40000, [5, OldChiefId, OldChiefName, NewChiefId, NewChiefName]),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin),
			Status
	end.
cast_guild_accuse_chief(Param, Status) ->
	[PlayerId, PlayerName, ChiefId, ChiefName] = Param,
	% 发送通知
	{ok, Bin} = pt_40:write(40000, [15, PlayerId, PlayerName, ChiefId, ChiefName]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin),
	Status.

cast_confirm_disband_guild(Param, Status) ->
	[GuildId, PlayerName, GuildName] = Param,
	Status1 = Status#player{guild_id = 0,
							guild_name = <<>>,
							guild_position = 0,
							quit_guild_time = 0,
							guild_title = <<>>,
							guild_depart_name = <<>>,
							guild_depart_id = 0,
							other = Status#player.other#player_other{guild_feats = 0,	%%氏族功勋变回0
																	 g_alliance = []	%%联盟中的氏族Id清空
																	}},
	mod_player:save_online_diff(Status,Status1),
	%%氏族任务处理
	gen_server:cast(Status#player.other#player_other.pid_task, {'guild_task_del',Status1}),
	%%处理氏族祝福数据
	lib_guild_wish:leave_guild(Status#player.id),
    {ok, Bin} = pt_40:write(40000, [11, GuildId, PlayerName, GuildName]),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin),
	Status1.

cast_guild_skill_upgrade(Param, Status) ->
	[GuildName, SkillId, SkillName, NewLevel] = Param,
	{ok, Bin} = pt_40:write(40000, [10, GuildName, SkillId, SkillName, NewLevel]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin),
	Status.
cast_guild_upgrade(Param, Status) ->
	[GuildId, GuildName, OldLevel, NewLevel] = Param,
	{ok, Bin} = pt_40:write(40000, [6, GuildId, GuildName, OldLevel, NewLevel]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin),
	Status.
cast_guild_reject_invite(Param, Status) ->
	[PlayerId, PlayerName] = Param,
	{ok, Bin} = pt_40:write(40000, [7, PlayerId, PlayerName]),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin),
	Status.
cast_guild_reject_apply(Param, Status) ->
	[GuildId, GuildName] = Param,
	{ok, Bin} = pt_40:write(40000, [8, GuildId, GuildName]),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin),
	Status.
%(暂时没用到)
%% cast_guild_give_title(Param, Status) ->
%% 	[PlayerId, PlayerName, Title] = Param,
%% 	{ok, Bin} = pt_40:write(40000, [9, PlayerId, PlayerName, Title]),
%% 	lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin),
%% 	Status.
cast_guild_set_position(Param, Status) ->
	[Type, PlayerId, PlayerName, NewPosition, GuildTitle,
	 DepartId, DepartName, PositionName] = Param,
	case Type of
		1 ->
			Status1 = Status#player{guild_position = NewPosition,
									guild_title = GuildTitle,
									guild_depart_id = DepartId,
									guild_depart_name = DepartName},
			mod_player:save_online_diff(Status,Status1),
			% 发送通知
			{ok, Bin} = pt_40:write(40000, [4, PlayerId, PlayerName, NewPosition, PositionName]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin),
			Status1;
		2 ->
			Status1 = Status#player{guild_title = GuildTitle},
			mod_player:save_online_diff(Status,Status1),
			Status1
	end.

case_guild_wareshoue_goods(Param, Status) ->
	[ActionType, GoodsId] = Param,
	{ok, Bin} = pt_40:write(40055, [ActionType, GoodsId]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin),
	Status.

case_guild_upgrade_h_skill(Param, Status) ->
	[_GuildName, HSkillId, NewHKLevel, _GuildId] = Param,
	{ok, Bin} = pt_40:write(40000, [12, HSkillId, NewHKLevel]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin),

%% 	HSkName = data_guild:get_skills_names(HSkillId),
	HSKillOld = Status#player.other#player_other.guild_h_skills,
	{HSKillAdd, _Funds, _RepuNeed} = data_guild:get_guild_h_skill_base(HSkillId, NewHKLevel),
	%%获取对应的技能提升福利
	HSKillAddRe = lib_guild_weal:make_h_skills(HSKillOld, HSKillAdd, HSkillId),
	%%替换并更新技能福利record[13氏族攻击，14氏族防御，15氏族气血，16氏族法力，17氏族命中，18氏族闪躲，19氏族暴击]#guild_h_skill{}
	NewStatus1 = Status#player{other = Status#player.other#player_other{guild_h_skills = HSKillAddRe}},
	NewStatus = lib_player:count_player_attribute(NewStatus1),
	lib_player:send_player_attribute(NewStatus, 1),
	NewStatus.

%%增加氏族技能令通知
case_add_guild_reputation(Param, Status) ->
	[GuildName, PlayerName] = Param,
	{ok, Bin} = pt_40:write(40000, [13, GuildName, PlayerName]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin),
	Status.
	
%%氏族运镖求救通告
case_guild_carry_help(Param, Status) ->
	[Type] = Param,
	{ok, Bin} = pt_40:write(40000, [14, Type]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin),
	Status.
	
%%获取氏族技能等级
get_guild_skill_level(GuildId, SkillId) ->
	Pattern = #ets_guild_skills_attribute{guild_id = GuildId, skill_id = SkillId, _ = '_'},
	case ets:match_object(?ETS_GUILD_SKILLS_ATTRIBUTE, Pattern) of
		[] ->
			0;
		[GuildSkillAttribute] ->
			GuildSkillAttribute#ets_guild_skills_attribute.skill_level
	end.
	

%%获取氏族运镖相关信息
get_guild_carry_info(GuildId)->
	case lib_guild_inner:get_guild(GuildId) of
		[]->[0,{}];
		Guild->
			[1,{Guild#ets_guild.level,
				Guild#ets_guild.funds,
				Guild#ets_guild.carry,
				Guild#ets_guild.bandits,
				Guild#ets_guild.chief_id,
				Guild#ets_guild.deputy_chief1_id,
				Guild#ets_guild.deputy_chief2_id}]
	end.

%%更新运镖信息
update_guild_carry_info(GuildId, PidSend, Type)->
	NoewTime = util:unixtime(),
	case lib_guild_inner:get_guild(GuildId) of
		[]->
			skip;
		Guild->
				case Type of
					sub ->
						Funds = lib_task:get_guild_carry_base_coin(guild,Guild#ets_guild.level) ,
						Msg= io_lib:format("氏族运镖扣除氏族手续费： ~p铜钱", [Funds]),
						{ok,MyBin} = pt_15:write(15055,[Msg]),
						lib_send:send_to_sid(PidSend, MyBin),
						NewCoin = Guild#ets_guild.funds -Funds;
					add->
						Funds =  lib_task:get_guild_carry_base_coin(guild,Guild#ets_guild.level) ,
						NewCoin = Guild#ets_guild.funds+Funds
				end,
				NewGuild = Guild#ets_guild{carry = NoewTime,funds=NewCoin},
				lib_guild_inner:update_guild(NewGuild),
				ValueList = [{carry, NoewTime},
							{funds, Funds, Type}],
				FieldList = [{id, Guild#ets_guild.id}],
				db_agent:update_guild_carry_info(ValueList,FieldList)
	end.

%%更新劫镖信息
update_guild_bandits_info(PlayerId,CarryGuildLv,BanditsGuildId)->
	NoewTime = util:unixtime(),
	case lib_guild_inner:get_guild(BanditsGuildId) of
		[]->skip;
		BanditsGuild->
				Coin = round(lib_task:get_guild_carry_base_coin(guild,CarryGuildLv) *0.8),
				NewCoin = Coin+BanditsGuild#ets_guild.funds,
				NewGuild = BanditsGuild#ets_guild{bandits = NoewTime,funds=NewCoin},
				lib_guild_inner:update_guild(NewGuild),
				ValueList = [{bandits, NoewTime},
							{funds, Coin, add}],
				FieldList = [{id, BanditsGuild#ets_guild.id}],
				db_agent:update_guild_carry_info(ValueList,FieldList),
				mod_guild:increase_guild_exp(PlayerId, BanditsGuild#ets_guild.id, 
											 0,round(Coin/10),0,0)
	end.
%%由氏族id获取氏族名字
get_guild_name(GuildId) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
							 {apply_call, lib_guild_inner, lib_get_guild_name, 
							  [GuildId]})	of
			error -> 
				"";
			Data ->
				Data
		end
	catch 
		_:_ ->
			""
	end.
%%使用弹劾令弹劾族长
accuse_chief(PlayerStatus) ->
	%%检查是否能够进行一些在空战时不能执行的操作
	CheckEnter = lib_skyrush:check_sky_doornot(),
	case CheckEnter of
		false ->
			case PlayerStatus#player.guild_position =:= 1 of
				true ->%%族长
					{36, PlayerStatus};
				false ->
					case mod_guild:accuse_chief(PlayerStatus#player.id, PlayerStatus#player.nickname,
												 PlayerStatus#player.guild_id, PlayerStatus#player.guild_position) of
						{ok, Result} ->
							case Result of
								1 ->
									NewPlayerStatus = PlayerStatus#player{guild_position = 1, 
																				  guild_depart_id = 5, 
																				  guild_depart_name = <<>>},
									{1, NewPlayerStatus};
								_ ->
									{Result, PlayerStatus}
							end;
					_Error ->
						{0, PlayerStatus}
					end
			end;
		true ->%%氏族战期间不能弹劾
			{37, PlayerStatus}
	end.
%%内部处理弹劾族长的处理
accuse_chief_inner(PlayerId, PlayerName, GuildId, _GPosit) ->
	case lib_guild_inner:get_guild(GuildId) of
		[] ->
			{ok, 0};
		Guild ->
			#ets_guild{name = GuildName,
					   chief_id = ChiefId,
					   chief_name = ChiefName,
					   deputy_chief1_id = DeputyChiefId1,
					   deputy_chief2_id = DeputyChiefId2} = Guild,
			case lib_player:is_online(ChiefId) of
				true ->
					{ok, 38};
				false ->
					LastLoginT = db_agent:get_player_lastt_login(ChiefId),
					NowTime = util:unixtime(),
					case (NowTime - LastLoginT) > ?ACCUSE_MAX_TIME of
						true ->%%超过时间限制了，可以弹劾
							case lib_guild_inner:demise_chief(ChiefId, ChiefName, PlayerId, PlayerName, 
															  GuildId, DeputyChiefId1, DeputyChiefId2) of
								[ok, MemberType] ->
									case MemberType of 
										0 ->
											GuildNew = Guild#ets_guild{chief_id           = PlayerId,
																	   chief_name         = PlayerName},
											lib_guild_inner:update_guild(GuildNew),
											accuse_chief_log(PlayerName, tool:to_list(ChiefName), GuildNew);
										1 ->
											GuildNew = Guild#ets_guild{chief_id           = PlayerId,
																	   chief_name         = PlayerName,
																	   deputy_chief1_id   = 0,
																	   deputy_chief1_name = <<>>,
																	   deputy_chief_num = Guild#ets_guild.deputy_chief_num - 1},
											lib_guild_inner:update_guild(GuildNew),
											accuse_chief_log(PlayerName, tool:to_list(ChiefName), GuildNew);
										2 ->
											GuildNew = Guild#ets_guild{chief_id           = PlayerId,
																	   chief_name         = PlayerName,
																	   deputy_chief2_id   = 0,
																	   deputy_chief2_name = <<>>,
																	   deputy_chief_num = Guild#ets_guild.deputy_chief_num - 1},
											lib_guild_inner:update_guild(GuildNew),
											accuse_chief_log(PlayerName, tool:to_list(ChiefName), GuildNew)
									end,
									%%处理氏族弹劾后的操作
									spawn(fun() ->handle_accuse_info(PlayerId, PlayerName, ChiefId, ChiefName, GuildId, GuildName) end),
									{ok, 1};
								_ ->
									{ok, 0}
							end;
						false ->
							{ok, 38}
					end
			end
	end.

%% -----------------------------------------------------------------
%% 添加氏族%%使用弹劾令弹劾族长日志
%% -----------------------------------------------------------------
accuse_chief_log(PlayerName1, PlayerName2, Guild) ->
	#ets_guild{name = GuildName,
			   id = GuildId} = Guild,
	CreateTime = util:unixtime(),
	Content = lists:concat([PlayerName1, ?ACCUSE_CHIEF_ONE, PlayerName2, ?ACCUSE_CHIEF_TWO]),
	
	Log_guild = #ets_log_guild{
					guild_id = GuildId, 
					guild_name = GuildName, 
					time = CreateTime, 
					content	= Content	   
					},
	case db_agent:guild_log_insert(Log_guild) of
		{mongo, Ret} ->
			GuildLogEts = Log_guild#ets_log_guild{id = Ret},
			lib_guild_inner:update_guild_log(GuildLogEts);
		1 ->
			GuildLog = db_agent:guild_log_select_create(GuildId, GuildName),
			if GuildLog =:= [] ->
				   ?ERROR_MSG("create_guild: guild id is null, name=[~s]", [GuildName]),
				   skip;
			   true ->
				   GuildLogEts = list_to_tuple([ets_log_guild] ++ GuildLog),
				   lib_guild_inner:update_guild_log(GuildLogEts)
			end;
		_Other ->
			noaction
	end.

handle_accuse_info(PlayerId, PlayerName, ChiefId, ChiefName, GuildId, GuildName) ->
	% 通知氏族成员
	lib_guild_inner:send_guild(0, PlayerId, GuildId, 
						 guild_accuse_chief, [PlayerId, PlayerName, ChiefId, ChiefName]),
	%向整个氏族成员发送信件
	lib_guild_inner:send_mail_guild_everyone_inner(1, PlayerId, GuildId, guild_accuse_chief,
									   [PlayerName, ChiefName, GuildName]).

%%获取氏族成员列表(仅提供给庄园使用)
get_guild_friend(GuildId, PlayerId) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
							 {apply_call, lib_guild_inner, get_guild_friend, [GuildId, PlayerId]})	of
			error -> 
				 [];
			 Data -> 
				 Data
		end			
	catch
		_:_Reason -> 
			[]
	end.
get_member_donate(GuildId, PlayerId) ->
	case GuildId of
		0 ->
			0;
		_ ->
			try 
				case gen_server:call(mod_guild:get_mod_guild_pid(), 
									  {apply_call, lib_guild_inner, get_member_donate, 
									   [PlayerId]}) of
					error -> 
						0;
					Data -> 
						Data
				end			
			catch
				_:_Reason -> 
					0
			end
	end.

%%氏族改名
change_guildname(PlayerId,GoodsPid,PlayerGuildId,GuildId,NewGuildName) ->
	case lib_words_ver:words_ver(NewGuildName) of 
		true ->%%文字没存在不合法字符
			if 
				PlayerGuildId == 0 ->
				   2;
			   PlayerGuildId =/= GuildId ->
				   3;
			   true ->
				   GuildName = tool:to_binary(NewGuildName),
				   GuildInfo = lib_guild_inner:get_guild_by_name(GuildName),
				   if
					   GuildInfo =/= [] -> 
						   4;
					   true ->
						   case gen_server:call(GoodsPid, {'goods_find', PlayerId, 28304}) of
							   false -> %%天地令不存在
								   0;
							   GoodsInfo ->
								   case gen_server:call(GoodsPid, {'delete_more', GoodsInfo#goods.goods_id, 1}) of
									   1 ->%%扣除物品成功
										   case lib_guild_inner:change_guildname(GuildId,GuildName) of
											   {ok, Res} ->
												   Res;
											   _ -> 
												   error
										   end;
									   _ ->%%扣除物品失败
										   error
								   end
						   end
				   end
			end;
		false ->
			5
	end.
	
%% -----------------------------------------------------------------
%% 40093 获取指定的氏族的氏族信息
%% -----------------------------------------------------------------
get_target_guild(PidSend, GuildId) ->
	case lib_guild_inner:get_guild(GuildId) of
		[] ->%%找不到这个氏族信息 
			skip;
		Guild ->
			#ets_guild{id = GuildId,
					   name = GuildName,
					   chief_id = ChiefId,
					   chief_name = ChiefName,
					   member_num = MemberNum,
					   level = Level,
					   realm = Realm,
					   announce = Announce,
					   exp = Exp,
					   funds = Funds} = Guild,
			%%计算氏族人数上限
			PopulationLevel = lib_guild:get_guild_skill_level(GuildId, 3),
			MemberCapacity = data_guild:get_guild_config(guild_member_base,[]) + PopulationLevel * 5,
			Result = 
				{GuildId, GuildName, Announce, Realm, Level, Exp, MemberNum, MemberCapacity, ChiefId, ChiefName, Funds},
			{ok, BinData40093} = pt_40:write(40093, [Result]),
			lib_send:send_to_sid(PidSend, BinData40093)
	end.
	