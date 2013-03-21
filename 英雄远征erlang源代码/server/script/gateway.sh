#!/bin/sh
cd ../ebin
erl +P 1024000 +K true -smp disable -name sd2@127.0.0.1 -setcookie sd2 -mnesia extra_db_nodes ["'sd1@127.0.0.1'"] -boot start_sasl -config log  -s sd gateway_start -extra 127.0.0.1 5566 0