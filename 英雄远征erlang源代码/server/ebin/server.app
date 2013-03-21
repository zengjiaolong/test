%% auther: xyao   
%% email: jiexiaowen@gmail.com   
%% date: 2010.04.09
  
{   
    application, server,
    [   
        {description, "This is sd game server."},   
        {vsn, "1.0a"},   
        {modules,
		[
			sd
		]},   
        {registered, [sd_server_sup]},   
        {applications, [kernel, stdlib, sasl]},   
        {mod, {sd_server_app, []}},   
        {start_phases, []}   
    ]   
}.    
 
%% File end.  
