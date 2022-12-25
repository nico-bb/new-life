@echo off
odin run src -out:bin/new-life.exe -debug -strict-style -vet -collection:lib=./lib
@echo on