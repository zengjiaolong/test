cd ../config
set LogFile=\"../logs/app_run1.log\"
erl +P 1024000 -smp disable -pa ../ebin -name ygzj_gateway@127.0.0.1 -setcookie ygzj -boot start_sasl -config gateway -kernel error_logger {file,"%LogFile%"}  -s yg gateway_start
