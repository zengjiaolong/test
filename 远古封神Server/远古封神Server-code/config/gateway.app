{   
    application, gateway,
    [   
        {description, "This is game gateway."},   
        {vsn, "1.0a"},   
        {modules, [yg] },   
        {registered, [yg_gateway_sup]},   
        {applications, [kernel, stdlib, sasl]},   
        {mod, {yg_gateway_app, []}},   
        {start_phases, []}   
    ]   
}.    
 
%% File end.  
