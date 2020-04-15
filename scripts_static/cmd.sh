#!/bin/bash
set -ex

service ssh start

python3 $(dirname $(realpath "$0"))/idle.py
