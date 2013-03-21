cd ../config
erl +P 1024000 -smp disable -pa ../ebin -name ygzj_game3@127.0.0.1 -setcookie ygzj -boot start_sasl -config run_3  -s yg server_start 
