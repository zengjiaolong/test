
%%%---------------------------------------
%%% @Module  : data_skill
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010-08-20 10:46:47
%%% @Description:  自动生成
%%%---------------------------------------
-module(data_skill).
-export([get/2, get_ids/1]).
-include("record.hrl").
get_ids(1) ->
	[101101,101102,101201,102101,102301,103101,103301,104301,105101,105301,106101];
get_ids(2) ->
	[301101,301102,301201,302301,302501,303101,303301,304101,305101,305501,306101];
get_ids(3) ->
	[201101,201102,201201,202101,202301,203101,203301,204101,205301,205401,206101].

				get(101101, Lv) ->

					#ets_skill{ 
						id=101101, 
						name = <<"基本刀法">>, 
						desc = <<"初入江湖的基本刀法，只能用来教训一下地痞混混">>,
						career = 1,
						type = 1,
						obj = 2,
						mod = 1,
						area = 0,
						cd = 800,
						lastime = 0,
						attime = 1,
						attarea = 0,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,1},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 20}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,3},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 40}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,5},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 60}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,8},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 81}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,11},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 102}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,15},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 123}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,20},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 144}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,26},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 165}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,33},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 186}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,41},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 207}
									];
					
								true ->
									[]
							end
						};

				get(101102, Lv) ->

					#ets_skill{ 
						id=101102, 
						name = <<"凌风斩">>, 
						desc = <<"双手挥起宝刀大力劈向对手，造成一定伤害">>,
						career = 1,
						type = 1,
						obj = 2,
						mod = 1,
						area = 0,
						cd = 4000,
						lastime = 0,
						attime = 1,
						attarea = 0,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,9},{coin,1000},{skill1,101101,3},{skill2,0,0}]}, {mp_out, 18}, {att, 1.05}, {hurt_add, 60}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,11},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 21}, {att, 1.07}, {hurt_add, 70}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,13},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 24}, {att, 1.09}, {hurt_add, 80}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,16},{coin,0},{skill1,0,0},{skill2,0,0}]}, {mp_out, 27}, {att, 1.11}, {hurt_add, 90}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,19},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 30}, {att, 1.13}, {hurt_add, 100}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,23},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 33}, {att, 1.15}, {hurt_add, 110}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,28},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 36}, {att, 1.17}, {hurt_add, 120}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,34},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 39}, {att, 1.19}, {hurt_add, 130}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,41},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 42}, {att, 1.21}, {hurt_add, 140}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,49},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 45}, {att, 1.25}, {hurt_add, 150}
									];
					
								true ->
									[]
							end
						};

				get(101201, Lv) ->

					#ets_skill{ 
						id=101201, 
						name = <<"天罡护体">>, 
						desc = <<"昆仑的健体之术，永久增加人的生命上限">>,
						career = 1,
						type = 2,
						obj = 1,
						mod = 1,
						area = 0,
						cd = 0,
						lastime = 0,
						attime = 0,
						attarea = 0,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,5},{coin,1000},{skill1,101101,2},{skill2,0,0}]}, {hp, 101}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,10},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {hp, 153}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,15},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {hp, 228}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,20},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {hp, 331}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,25},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {hp, 463}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,30},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {hp, 613}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,35},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {hp, 784}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,40},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {hp, 982}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,45},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {hp, 1193}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,50},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {hp, 1428}
									];
					
								true ->
									[]
							end
						};

				get(102101, Lv) ->

					#ets_skill{ 
						id=102101, 
						name = <<"一夫当关">>, 
						desc = <<"一夫当关，万夫莫开。攻击周围的所有敌人，并且吸引所有注意力">>,
						career = 1,
						type = 1,
						obj = 1,
						mod = 2,
						area = 2,
						cd = 25000,
						lastime = 0,
						attime = 1,
						attarea = 0,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,19},{coin,1000},{skill1,101102,3},{skill2,0,0}]}, {mp_out, 43}, {att, 0.7}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,21},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 46}, {att, 0.75}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,23},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 49}, {att, 0.8}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,26},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 52}, {att, 0.85}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,29},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 55}, {att, 0.9}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,33},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 58}, {att, 0.95}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,38},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 61}, {att, 1.0}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,44},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 64}, {att, 1.05}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,51},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 67}, {att, 1.1}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,59},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 70}, {att, 1.15}
									];
					
								true ->
									[]
							end
						};

				get(102301, Lv) ->

					#ets_skill{ 
						id=102301, 
						name = <<"霸王卸甲">>, 
						desc = <<"舍弃自身的防御，以获得更高的攻击，力求快速打倒敌人">>,
						career = 1,
						type = 3,
						obj = 1,
						mod = 1,
						area = 0,
						cd = 180000,
						lastime = 30000,
						attime = 1,
						attarea = 0,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,14},{coin,1000},{skill1,101101,3},{skill2,0,0}]}, {mp_out, 81}, {att, 80}, {def_add, 0.85}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,16},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 84}, {att, 153}, {def_add, 0.85}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,18},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 87}, {att, 235}, {def_add, 0.85}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,21},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 90}, {att, 325}, {def_add, 0.85}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,24},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 93}, {att, 424}, {def_add, 0.85}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,28},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 96}, {att, 532}, {def_add, 0.85}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,33},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 99}, {att, 617}, {def_add, 0.85}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,39},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 102}, {att, 702}, {def_add, 0.85}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,46},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 105}, {att, 788}, {def_add, 0.85}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,54},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 108}, {att, 873}, {def_add, 0.85}
									];
					
								true ->
									[]
							end
						};

				get(103101, Lv) ->

					#ets_skill{ 
						id=103101, 
						name = <<"我为刀俎">>, 
						desc = <<"我为刀俎，你为鱼肉。攻击敌人，造成伤害，并且降低敌人的防御">>,
						career = 1,
						type = 1,
						obj = 2,
						mod = 1,
						area = 0,
						cd = 9000,
						lastime = 5000,
						attime = 1,
						attarea = 0,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,29},{coin,1000},{skill1,102101,4},{skill2,0,0}]}, {mp_out, 34}, {hurt_add, 1.35}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,34},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 37}, {hurt_add, 1.4}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,39},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 40}, {hurt_add, 1.45}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,44},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 43}, {hurt_add, 1.5}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,49},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 46}, {hurt_add, 1.55}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,54},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 49}, {hurt_add, 1.6}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,59},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 52}, {hurt_add, 1.65}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,64},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 55}, {hurt_add, 1.7}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,69},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 58}, {hurt_add, 1.75}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,74},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 61}, {hurt_add, 1.8}
									];
					
								true ->
									[]
							end
						};

				get(103301, Lv) ->

					#ets_skill{ 
						id=103301, 
						name = <<"固若金汤">>, 
						desc = <<"以自我为中心，暂时提升自己及周围队友的防御力">>,
						career = 1,
						type = 3,
						obj = 1,
						mod = 2,
						area = 4,
						cd = 30000,
						lastime = 900000,
						attime = 1,
						attarea = 0,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,24},{coin,1000},{skill1,102301,3},{skill2,0,0}]}, {mp_out, 73}, {def_add, 116}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,29},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 76}, {def_add, 156}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,34},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 79}, {def_add, 198}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,39},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 82}, {def_add, 238}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,44},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 85}, {def_add, 277}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,49},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 88}, {def_add, 317}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,54},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 91}, {def_add, 358}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,59},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 94}, {def_add, 397}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,64},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 97}, {def_add, 472}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,69},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 100}, {def_add, 591}
									];
					
								true ->
									[]
							end
						};

				get(104301, Lv) ->

					#ets_skill{ 
						id=104301, 
						name = <<"不动如山">>, 
						desc = <<"任他支离狂悖，颠倒颇僻，我自八风不动，减少自己所受到得伤害。与人不留行不可同时存在">>,
						career = 1,
						type = 3,
						obj = 1,
						mod = 1,
						area = 0,
						cd = 60000,
						lastime = 12000,
						attime = 1,
						attarea = 0,
						limit = [105301],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,39},{coin,1000},{skill1,103301,3},{skill2,0,0}]}, {mp_out, 78}, {hurt_del, 0.9}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,43},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 81}, {hurt_del, 0.89}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,47},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 84}, {hurt_del, 0.88}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,51},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 87}, {hurt_del, 0.87}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,55},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 90}, {hurt_del, 0.86}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,60},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 93}, {hurt_del, 0.85}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,65},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 96}, {hurt_del, 0.84}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,70},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 99}, {hurt_del, 0.83}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,75},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 102}, {hurt_del, 0.82}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,80},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 105}, {hurt_del, 0.8}
									];
					
								true ->
									[]
							end
						};

				get(105101, Lv) ->

					#ets_skill{ 
						id=105101, 
						name = <<"浮光掠影">>, 
						desc = <<"宝刀像一道流光飞速斩向对手，一触即回，而后敌人才察觉已受重伤">>,
						career = 1,
						type = 1,
						obj = 2,
						mod = 1,
						area = 0,
						cd = 12000,
						lastime = 0,
						attime = 1,
						attarea = 0,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,44},{coin,1000},{skill1,103101,4},{skill2,0,0}]}, {mp_out, 50}, {att, 1.15}, {hurt_add, 135}, {hit_add, 0.3}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,49},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 53}, {att, 1.17}, {hurt_add, 145}, {hit_add, 0.3}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,54},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 56}, {att, 1.19}, {hurt_add, 155}, {hit_add, 0.3}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,59},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 59}, {att, 1.21}, {hurt_add, 165}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,64},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 62}, {att, 1.24}, {hurt_add, 175}, {hit_add, 0.3}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,69},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 65}, {att, 1.27}, {hurt_add, 185}, {hit_add, 0.3}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,74},{coin,0},{skill1,0,0},{skill2,0,0}]}, {mp_out, 68}, {att, 1.3}, {hurt_add, 195}, {hit_add, 0.3}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,79},{coin,0},{skill1,0,0},{skill2,0,0}]}, {mp_out, 71}, {att, 1.35}, {hurt_add, 205}, {hit_add, 0.3}
									];
					
								true ->
									[]
							end
						};

				get(105301, Lv) ->

					#ets_skill{ 
						id=105301, 
						name = <<"人不留行">>, 
						desc = <<"十步杀一人，千里不留行。加快自身的移动速度。与不动如山不可同时存在">>,
						career = 1,
						type = 3,
						obj = 1,
						mod = 1,
						area = 0,
						cd = 60000,
						lastime = 15000,
						attime = 1,
						attarea = 0,
						limit = [104301],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,49},{coin,1000},{skill1,102301,8},{skill2,0,0}]}, {mp_out, 84}, {add_speed, 0.2}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,54},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 87}, {add_speed, 0.21}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,59},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 90}, {add_speed, 0.22}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,64},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 93}, {add_speed, 0.23}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,69},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 96}, {add_speed, 0.24}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,74},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 99}, {add_speed, 0.26}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,79},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 102}, {add_speed, 0.28}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,84},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 105}, {add_speed, 0.3}
									];
					
								true ->
									[]
							end
						};

				get(106101, Lv) ->

					#ets_skill{ 
						id=106101, 
						name = <<"荒火燎原">>, 
						desc = <<"野火烧不尽，春风吹又生。宝刀挥洒而出，攻击周围的敌人。">>,
						career = 1,
						type = 1,
						obj = 1,
						mod = 2,
						area = 2,
						cd = 35000,
						lastime = 0,
						attime = 1,
						attarea = 0,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,59},{coin,1000},{skill1,105301,2},{skill2,105101,3}]}, {mp_out, 133}, {att, 1.4}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,66},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 136}, {att, 1.45}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,73},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 139}, {att, 1.5}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,81},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 142}, {att, 1.55}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,89},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 145}, {att, 1.6}
									];
					
								true ->
									[]
							end
						};

				get(201101, Lv) ->

					#ets_skill{ 
						id=201101, 
						name = <<"基本刺法">>, 
						desc = <<"初入江湖的基本刺法，只能用来教训一下地痞混混">>,
						career = 3,
						type = 1,
						obj = 2,
						mod = 1,
						area = 0,
						cd = 800,
						lastime = 0,
						attime = 1,
						attarea = 0,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,1},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 10}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,3},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 30}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,5},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 50}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,8},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 71}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,11},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 92}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,15},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 113}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,20},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 134}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,26},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 155}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,33},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 176}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,41},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 197}
									];
					
								true ->
									[]
							end
						};

				get(201102, Lv) ->

					#ets_skill{ 
						id=201102, 
						name = <<"幽影刺">>, 
						desc = <<"挥舞双刺，如蛇一般刺向敌人胸膛">>,
						career = 3,
						type = 1,
						obj = 2,
						mod = 1,
						area = 0,
						cd = 3000,
						lastime = 0,
						attime = 1,
						attarea = 0,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,9},{coin,1000},{skill1,201101,3},{skill2,0,0}]}, {mp_out, 13}, {att, 1.1}, {hurt_add, 50}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,11},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 15}, {att, 1.12}, {hurt_add, 60}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,13},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 17}, {att, 1.14}, {hurt_add, 65}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,16},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 19}, {att, 1.16}, {hurt_add, 70}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,19},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 21}, {att, 1.18}, {hurt_add, 75}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,23},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 23}, {att, 1.2}, {hurt_add, 80}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,28},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 25}, {att, 1.22}, {hurt_add, 85}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,34},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 27}, {att, 1.24}, {hurt_add, 90}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,41},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 29}, {att, 1.27}, {hurt_add, 95}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,49},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 31}, {att, 1.3}, {hurt_add, 100}
									];
					
								true ->
									[]
							end
						};

				get(201201, Lv) ->

					#ets_skill{ 
						id=201201, 
						name = <<"慧眼明察">>, 
						desc = <<"唐门的秘术，使人拥有杀手一般的嗅觉，轻易找出对手的破绽">>,
						career = 3,
						type = 2,
						obj = 2,
						mod = 1,
						area = 0,
						cd = 0,
						lastime = 0,
						attime = 1,
						attarea = 0,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,5},{coin,1000},{skill1,201101,2},{skill2,0,0}]}, {crit, 12}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,10},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {crit, 18}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,15},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {crit, 24}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,20},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {crit, 30}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,25},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {crit, 36}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,30},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {crit, 42}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,35},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {crit, 48}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,40},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {crit, 54}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,45},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {crit, 60}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,50},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {crit, 66}
									];
					
								true ->
									[]
							end
						};

				get(202101, Lv) ->

					#ets_skill{ 
						id=202101, 
						name = <<"流星赶月">>, 
						desc = <<"双刺上下翩飞，一前一后刺向敌人咽喉，造成2次伤害">>,
						career = 3,
						type = 1,
						obj = 2,
						mod = 1,
						area = 0,
						cd = 6000,
						lastime = 0,
						attime = 2,
						attarea = 0,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,14},{coin,1000},{skill1,201102,2},{skill2,0,0}]}, {mp_out, 20}, {att, 0.6}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,16},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 23}, {att, 0.61}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,18},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 26}, {att, 0.62}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,21},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 29}, {att, 0.63}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,24},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 32}, {att, 0.64}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,28},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 35}, {att, 0.65}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,33},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 38}, {att, 0.66}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,39},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 41}, {att, 0.67}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,46},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 44}, {att, 0.68}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,54},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 47}, {att, 0.7}
									];
					
								true ->
									[]
							end
						};

				get(202301, Lv) ->

					#ets_skill{ 
						id=202301, 
						name = <<"捕风捉影">>, 
						desc = <<"唐门奇术，大幅增加自身的命中。与镜花水月不可同时存在">>,
						career = 3,
						type = 1,
						obj = 1,
						mod = 1,
						area = 0,
						cd = 30000,
						lastime = 900000,
						attime = 1,
						attarea = 0,
						limit = [205301],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,19},{coin,1000},{skill1,201101,5},{skill2,0,0}]}, {mp_out, 27}, {hit_add, 0.08}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,21},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 29}, {hit_add, 0.09}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,23},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 31}, {hit_add, 0.1}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,26},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 33}, {hit_add, 0.11}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,29},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 35}, {hit_add, 0.12}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,33},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 37}, {hit_add, 0.13}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,38},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 39}, {hit_add, 0.14}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,44},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 41}, {hit_add, 0.15}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,51},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 43}, {hit_add, 0.17}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,59},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 45}, {hit_add, 0.2}
									];
					
								true ->
									[]
							end
						};

				get(203101, Lv) ->

					#ets_skill{ 
						id=203101, 
						name = <<"晓风残月">>, 
						desc = <<"醒时何处，奈何桥，晓风残月。唐门技艺，使人陷入中毒状态">>,
						career = 3,
						type = 1,
						obj = 2,
						mod = 1,
						area = 0,
						cd = 8000,
						lastime = 3000,
						attime = 1,
						attarea = 0,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,24},{coin,1000},{skill1,202101,3},{skill2,0,0}]}, {mp_out, 39}, {att, 1.1}, {drug, [3,1,25]}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,29},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 41}, {att, 1.11}, {drug, [3,1,30]}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,34},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 43}, {att, 1.12}, {drug, [3,1,35]}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,39},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 45}, {att, 1.13}, {drug, [3,1,40]}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,44},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 47}, {att, 1.15}, {drug, [3,1,45]}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,49},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 49}, {att, 1.17}, {drug, [3,1,50]}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,54},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 51}, {att, 1.19}, {drug, [3,1,55]}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,59},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 53}, {att, 1.21}, {drug, [3,1,60]}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,64},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 55}, {att, 1.23}, {drug, [3,1,65]}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,69},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 57}, {att, 1.25}, {drug, [3,1,70]}
									];
					
								true ->
									[]
							end
						};

				get(203301, Lv) ->

					#ets_skill{ 
						id=203301, 
						name = <<"修罗喋血">>, 
						desc = <<"以自我为中心，暂时提升自己及周围队友的暴击几率">>,
						career = 3,
						type = 3,
						obj = 1,
						mod = 2,
						area = 4,
						cd = 30000,
						lastime = 900000,
						attime = 1,
						attarea = 0,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,29},{coin,1000},{skill1,202301,4},{skill2,0,0}]}, {mp_out, 53}, {crit, 20}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,34},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 56}, {crit, 22}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,39},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 59}, {crit, 24}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,44},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 62}, {crit, 26}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,49},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 65}, {crit, 28}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,54},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 68}, {crit, 30}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,59},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 71}, {crit, 32}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,64},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 74}, {crit, 34}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,69},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 77}, {crit, 36}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,74},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 80}, {crit, 38}
									];
					
								true ->
									[]
							end
						};

				get(204101, Lv) ->

					#ets_skill{ 
						id=204101, 
						name = <<"漫天花雨">>, 
						desc = <<"无边花雨萧萧飘下，轻取性命手到擒来。唐门高级技艺，伤害周围的目标，并且出现暴击">>,
						career = 3,
						type = 1,
						obj = 2,
						mod = 2,
						area = 2,
						cd = 15000,
						lastime = 0,
						attime = 1,
						attarea = 4,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,39},{coin,1000},{skill1,202101,6},{skill2,0,0}]}, {mp_out, 59}, {att, 1.15}, {crit, 100}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,43},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 61}, {att, 1.17}, {crit, 100}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,47},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 63}, {att, 1.19}, {crit, 100}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,51},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 65}, {att, 1.21}, {crit, 100}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,55},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 67}, {att, 1.23}, {crit, 100}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,60},{coin,0},{skill1,0,0},{skill2,0,0}]}, {mp_out, 69}, {att, 1.25}, {crit, 100}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,65},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 71}, {att, 1.27}, {crit, 100}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,70},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 73}, {att, 1.29}, {crit, 100}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,75},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 75}, {att, 1.32}, {crit, 100}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,80},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 77}, {att, 1.35}, {crit, 100}
									];
					
								true ->
									[]
							end
						};

				get(205301, Lv) ->

					#ets_skill{ 
						id=205301, 
						name = <<"镜花水月">>, 
						desc = <<"镜中花，水中月。使用此招，唐门弟子可冲锋陷阵，进退自如。与捕风捉影不可同时存在">>,
						career = 3,
						type = 3,
						obj = 1,
						mod = 1,
						area = 0,
						cd = 30000,
						lastime = 900000,
						attime = 1,
						attarea = 0,
						limit = [202301],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,44},{coin,1000},{skill1,202301,6},{skill2,0,0}]}, {mp_out, 41}, {dodge, 0.08}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,49},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 43}, {dodge, 0.09}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,54},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 45}, {dodge, 0.1}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,59},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 47}, {dodge, 0.11}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,64},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 49}, {dodge, 0.12}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,69},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 51}, {dodge, 0.13}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,74},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 53}, {dodge, 0.14}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,79},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 55}, {dodge, 0.15}
									];
					
								true ->
									[]
							end
						};

				get(205401, Lv) ->

					#ets_skill{ 
						id=205401, 
						name = <<"一叶障目">>, 
						desc = <<"一叶障目，不见泰山。中招后，对手会处于失明状态，命中降低">>,
						career = 3,
						type = 1,
						obj = 2,
						mod = 1,
						area = 0,
						cd = 45000,
						lastime = 15000,
						attime = 1,
						attarea = 4,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,49},{coin,1000},{skill1,201201,7},{skill2,0,0}]}, {mp_out, 41}, {hit_del, 0.16}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,54},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 43}, {hit_del, 0.18}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,59},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 45}, {hit_del, 0.20}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,64},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 47}, {hit_del, 0.22}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,69},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 49}, {hit_del, 0.24}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,74},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 51}, {hit_del, 0.26}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,79},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 53}, {hit_del, 0.28}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,84},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 55}, {hit_del, 0.3}
									];
					
								true ->
									[]
							end
						};

				get(206101, Lv) ->

					#ets_skill{ 
						id=206101, 
						name = <<"碧落黄泉">>, 
						desc = <<"上穷碧落下黄泉，终究要相见。但是此见非彼见，是要人性命之见">>,
						career = 3,
						type = 1,
						obj = 2,
						mod = 1,
						area = 0,
						cd = 30000,
						lastime = 4000,
						attime = 1,
						attarea = 0,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,59},{coin,1000},{skill1,203101,8},{skill2,205301,3}]}, {mp_out, 73}, {att, 1.3}, {speed, 0.3}, {drug, [2,2,75]}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,66},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 78}, {att, 1.35}, {speed, 0.3}, {drug, [2,2,90]}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,73},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 83}, {att, 1.4}, {speed, 0.3}, {drug, [2,2,105]}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,81},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 88}, {att, 1.45}, {speed, 0.3}, {drug, [2,2,120]}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,89},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 93}, {att, 1.5}, {speed, 0.3}, {drug, [2,2,135]}
									];
					
								true ->
									[]
							end
						};

				get(301101, Lv) ->

					#ets_skill{ 
						id=301101, 
						name = <<"基本剑法">>, 
						desc = <<"初入江湖的基本剑法，只能用来教训一下地痞混混">>,
						career = 2,
						type = 1,
						obj = 2,
						mod = 1,
						area = 0,
						cd = 800,
						lastime = 0,
						attime = 1,
						attarea = 4,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,1},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 40}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,3},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 60}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,5},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 80}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,8},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 111}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,11},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 122}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,15},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 143}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,20},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 164}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,26},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 185}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,33},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 206}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,41},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 1}, {att, 227}
									];
					
								true ->
									[]
							end
						};

				get(301102, Lv) ->

					#ets_skill{ 
						id=301102, 
						name = <<"碎影破">>, 
						desc = <<"剑若闪电，向敌人咽喉要害狠狠刺去">>,
						career = 2,
						type = 1,
						obj = 2,
						mod = 1,
						area = 0,
						cd = 3000,
						lastime = 0,
						attime = 1,
						attarea = 4,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,9},{coin,1000},{skill1,301101,3},{skill2,0,0}]}, {mp_out, 24}, {att, 1.22}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,11},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 27}, {att, 1.24}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,13},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 30}, {att, 1.26}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,16},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 33}, {att, 1.28}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,19},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 36}, {att, 1.3}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,23},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 39}, {att, 1.32}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,28},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 42}, {att, 1.34}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,34},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 45}, {att, 1.36}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,41},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 48}, {att, 1.38}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,49},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 51}, {att, 1.4}
									];
					
								true ->
									[]
							end
						};

				get(301201, Lv) ->

					#ets_skill{ 
						id=301201, 
						name = <<"韬光养晦">>, 
						desc = <<"逍遥的心法，永久增加自身的攻击和内力">>,
						career = 2,
						type = 2,
						obj = 2,
						mod = 1,
						area = 0,
						cd = 0,
						lastime = 0,
						attime = 1,
						attarea = 0,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,5},{coin,1000},{skill1,301101,2},{skill2,0,0}]}, {att, 50}, {mp, 60}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,10},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {att, 70}, {mp, 75}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,15},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {att, 100}, {mp, 95}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,20},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {att, 140}, {mp, 120}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,25},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {att, 190}, {mp, 150}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,30},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {att, 250}, {mp, 185}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,35},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {att, 320}, {mp, 225}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,40},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {att, 400}, {mp, 275}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,45},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {att, 490}, {mp, 330}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,50},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {att, 590}, {mp, 390}
									];
					
								true ->
									[]
							end
						};

				get(302301, Lv) ->

					#ets_skill{ 
						id=302301, 
						name = <<"坐忘无我">>, 
						desc = <<"将自己的内力转化成一个护盾，化解所受到伤害">>,
						career = 2,
						type = 3,
						obj = 1,
						mod = 1,
						area = 0,
						cd = 180000,
						lastime = 60000,
						attime = 1,
						attarea = 0,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,14},{coin,1000},{skill1,301101,3},{skill2,0,0}]}, {mp_out, 60}, {shield, 120}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,16},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 73}, {shield, 146}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,18},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 81}, {shield, 163}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,21},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 98}, {shield, 196}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,24},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 121}, {shield, 243}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,28},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 148}, {shield, 296}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,33},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 166}, {shield, 333}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,39},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 192}, {shield, 386}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,46},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 231}, {shield, 463}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,54},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 293}, {shield, 586}
									];
					
								true ->
									[]
							end
						};

				get(302501, Lv) ->

					#ets_skill{ 
						id=302501, 
						name = <<"春泥护花">>, 
						desc = <<"落红本有情，春泥更护花。逍遥弟子怀柔天下，此计可以回复选中目标的生命值">>,
						career = 2,
						type = 3,
						obj = 3,
						mod = 1,
						area = 0,
						cd = 15000,
						lastime = 0,
						attime = 1,
						attarea = 4,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,19},{coin,1000},{skill1,301201,3},{skill2,0,0}]}, {mp_out, 69}, {hp, 200}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,21},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 76}, {hp, 250}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,23},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 83}, {hp, 300}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,26},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 90}, {hp, 400}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,29},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 97}, {hp, 500}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,33},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 104}, {hp, 600}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,38},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 111}, {hp, 750}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,44},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 118}, {hp, 900}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,51},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 125}, {hp, 1050}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,59},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 132}, {hp, 1200}
									];
					
								true ->
									[]
							end
						};

				get(303101, Lv) ->

					#ets_skill{ 
						id=303101, 
						name = <<"风卷残云">>, 
						desc = <<"风卷残云，剑气临空惊魂梦。对目标范围内发出半月形的剑气，群体伤害">>,
						career = 2,
						type = 1,
						obj = 2,
						mod = 2,
						area = 2,
						cd = 6000,
						lastime = 0,
						attime = 1,
						attarea = 4,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,24},{coin,1000},{skill1,301102,5},{skill2,0,0}]}, {mp_out, 47}, {att, 1.22}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,29},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 53}, {att, 1.24}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,34},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 59}, {att, 1.26}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,39},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 65}, {att, 1.28}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,44},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 71}, {att, 1.3}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,49},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 77}, {att, 1.32}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,54},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 83}, {att, 1.34}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,59},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 89}, {att, 1.36}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,64},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 95}, {att, 1.38}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,69},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 101}, {att, 1.4}
									];
					
								true ->
									[]
							end
						};

				get(303301, Lv) ->

					#ets_skill{ 
						id=303301, 
						name = <<"剑气纵横">>, 
						desc = <<"剑气惊风雨，纵横泣鬼神。出以气为兵，以剑为辅，群体增加攻击力">>,
						career = 2,
						type = 3,
						obj = 1,
						mod = 2,
						area = 4,
						cd = 30000,
						lastime = 900000,
						attime = 1,
						attarea = 0,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,29},{coin,1000},{skill1,302301,4},{skill2,0,0}]}, {mp_out, 69}, {att, 116}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,34},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 76}, {att, 156}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,39},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 83}, {att, 223}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,44},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 90}, {att, 263}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,49},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 97}, {att, 307}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,54},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 104}, {att, 347}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,59},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 111}, {att, 393}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,64},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 118}, {att, 432}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,69},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 125}, {att, 522}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,74},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 132}, {att, 651}
									];
					
								true ->
									[]
							end
						};

				get(304101, Lv) ->

					#ets_skill{ 
						id=304101, 
						name = <<"碧海潮生">>, 
						desc = <<"碧海涛起天地惊，潮生潮落尽彷徨。以自身为中心，周围所有单位受到伤害，而且移动速度降低">>,
						career = 2,
						type = 1,
						obj = 1,
						mod = 2,
						area = 2,
						cd = 10000,
						lastime = 3000,
						attime = 1,
						attarea = 0,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,39},{coin,1000},{skill1,303101,3},{skill2,0,0}]}, {mp_out, 67}, {att, 1.25}, {speed, 0.15}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,43},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 73}, {att, 1.27}, {speed, 0.15}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,47},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 79}, {att, 1.3}, {speed, 0.15}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,51},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 85}, {att, 1.33}, {speed, 0.15}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,55},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 91}, {att, 1.35}, {speed, 0.15}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,60},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 97}, {att, 1.38}, {speed, 0.15}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,65},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 103}, {att, 1.4}, {speed, 0.15}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,70},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 109}, {att, 1.43}, {speed, 0.15}
									];
					
								Lv == 9 ->
									[
									   {condition, [{lv,75},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 115}, {att, 1.46}, {speed, 0.15}
									];
					
								Lv == 10 ->
									[
									   {condition, [{lv,80},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 121}, {att, 1.5}, {speed, 0.15}
									];
					
								true ->
									[]
							end
						};

				get(305101, Lv) ->

					#ets_skill{ 
						id=305101, 
						name = <<"绕指柔">>, 
						desc = <<"相见时难别亦难。发出数道剑气，降低目标的移动速度">>,
						career = 2,
						type = 1,
						obj = 2,
						mod = 1,
						area = 0,
						cd = 15000,
						lastime = 2000,
						attime = 1,
						attarea = 4,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,49},{coin,1000},{skill1,304101,3},{skill2,0,0}]}, {mp_out, 59}, {hurt_add, 1.45}, {speed, 0.3}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,54},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 65}, {hurt_add, 1.5}, {speed, 0.3}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,59},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 71}, {hurt_add, 1.55}, {speed, 0.3}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,64},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 77}, {hurt_add, 1.6}, {speed, 0.3}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,69},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 83}, {hurt_add, 1.65}, {speed, 0.3}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,74},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 89}, {hurt_add, 1.7}, {speed, 0.3}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,79},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 95}, {hurt_add, 1.75}, {speed, 0.3}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,84},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 101}, {hurt_add, 1.8}, {speed, 0.3}
									];
					
								true ->
									[]
							end
						};

				get(305501, Lv) ->

					#ets_skill{ 
						id=305501, 
						name = <<"慈航普渡">>, 
						desc = <<"心怀天下，大爱无边。逍遥济世之术，群体回复生命值">>,
						career = 2,
						type = 3,
						obj = 1,
						mod = 2,
						area = 4,
						cd = 25000,
						lastime = 0,
						attime = 1,
						attarea = 0,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,44},{coin,1000},{skill1,302501,6},{skill2,0,0}]}, {mp_out, 90}, {hp, 220}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,49},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 99}, {hp, 298}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,54},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 108}, {hp, 361}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,59},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 117}, {hp, 433}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,64},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 126}, {hp, 534}
									];
					
								Lv == 6 ->
									[
									   {condition, [{lv,69},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 135}, {hp, 612}
									];
					
								Lv == 7 ->
									[
									   {condition, [{lv,74},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 144}, {hp, 718}
									];
					
								Lv == 8 ->
									[
									   {condition, [{lv,79},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 153}, {hp, 862}
									];
					
								true ->
									[]
							end
						};

				get(306101, Lv) ->

					#ets_skill{ 
						id=306101, 
						name = <<"六合独尊">>, 
						desc = <<"六合同归，大道逍遥。发出无数剑气，对目标范围内的敌人进行致命打击">>,
						career = 2,
						type = 1,
						obj = 2,
						mod = 2,
						area = 2,
						cd = 30000,
						lastime = 0,
						attime = 1,
						attarea = 4,
						limit = [],
						data = if
								Lv == 1 ->
									[
									   {condition, [{lv,59},{coin,1000},{skill1,305501,3},{skill2,305101,2}]}, {mp_out, 118}, {att, 1.6}
									];
					
								Lv == 2 ->
									[
									   {condition, [{lv,67},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 130}, {att, 1.65}
									];
					
								Lv == 3 ->
									[
									   {condition, [{lv,73},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 142}, {att, 1.7}
									];
					
								Lv == 4 ->
									[
									   {condition, [{lv,81},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 154}, {att, 1.75}
									];
					
								Lv == 5 ->
									[
									   {condition, [{lv,89},{coin,1000},{skill1,0,0},{skill2,0,0}]}, {mp_out, 166}, {att, 1.8}
									];
					
								true ->
									[]
							end
						};

get(_Id, _Lv) ->
    [].
        