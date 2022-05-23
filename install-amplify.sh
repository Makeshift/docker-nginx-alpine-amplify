#!/usr/bin/expect

set timeout -1

spawn /install-source.sh

expect "Enter your API key: "
send "<CHANGEAPIKEY>\r"
expect "Please select your OS family:"
send "3\r"
expect "Continue (y/n)?"
send "y\r"

expect eof
catch wait result
