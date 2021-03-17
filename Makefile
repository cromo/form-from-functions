SRC = $(wildcard *.fnl)
LUA_OUT = $(SRC:.fnl=.lua)
TEST = $(wildcard test/*.fnl)

.PHONY: all clean test

all: $(LUA_OUT)

%.lua: %.fnl fennel.exe
	./fennel.exe --compile $< > $@

clean:
	rm -f $(LUA_OUT)

test:
	./fennel.exe third-party/knife-test.fnl $(TEST)