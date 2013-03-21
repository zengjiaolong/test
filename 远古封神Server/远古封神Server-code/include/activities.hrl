%% ============================
%% 活动专用hrl
%% ============================

-define(ANNIVERSARY_TIME_STAMP, 15000). %%15秒的周期性刷新数据
-define(ANNIVERSARY_MON_IDS, [40971, 40972, 40973, 40974, 40975]).		%%开发部怪物的bossIDs
-define(ROBOT_MON_COORD, {48, 99}).					%%开发部怪物的boss刷新坐标

-define(ANNIVERSARY, ets_anniversary_bless).	%%周年活动ets

%%周年活动玩家祈祷ets数据
-record(ets_anniversary_bless, 
		{pid = 0,		%%玩家Id
		 pname = "",	%%玩家名字
		 gid = 0,		%%玩家祈祷所得的物品Id
		 time = 0,		%%祈福的时间
		 content = ""	%%祝福内容
		 }).
-define(LANTERN_RIDDLES_LIMIT, 5).		%%一天可以猜灯谜的次数

-record(quizzes, {pid = 0,	%%玩家Id
				  pname = "",	%%玩家名字
				  a = 1,	%%第一位数值(最高位)
				  b = 1,	%%第二位数值(中间那个)
				  c = 3,	%%第三位数值(最低位)
				  state = 0	%%猜中的的数值的个数，0：一个也没猜中，1：猜中一个，2：猜中两个，3：猜中三个，全中！
				 }).
-define(ETS_QUIZZES, ets_quizzes).	%%大竞猜活动ets

-define(PRIZE_NUM, 500000).				%%	奖池的初始化奖金