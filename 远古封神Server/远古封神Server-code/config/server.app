{
    application, server,
    [
        {description, "This is game server."},
        {vsn, "1.0a"},
        {modules, [yg]},
        {registered, [yg_server_sup]},
        {applications, [kernel, stdlib, sasl]},
        {mod, {yg_server_app, []}},
        {env,[{platform,"duowan"},{server_num,1},{card_key,"dwYgfscardKey"},{opening,1309773600}]},
        {start_phases, []}
    ]
}.

%% File end.
