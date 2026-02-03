#!/bin/bash

ip=$(curl -s ifconfig.me)
echo "{\"ip\":\"${ip}\"}"

