%% auther: xyao   
%% email: jiexiaowen@gmail.com   
%% date: 2010.04.09
  
{   
    application, gateway,
    [   
        {description, "This is sd game gateway."},   
        {vsn, "1.0a"},   
        {modules,
		[
			sd
		]},   
        {registered, [sd_gateway_sup]},   
        {applications, [kernel, stdlib, sasl]},   
        {mod, {sd_gateway_app, []}},   
        {start_phases, []}   
    ]   
}.    
 
%% File end.  
