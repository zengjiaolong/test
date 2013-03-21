
cd ..\ebin

::werl -s mysql_to_base_data start

del *.beam

cd ..

erl -make

pause

