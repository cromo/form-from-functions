SRC = $(wildcard *.fnl)
LUA_OUT = $(SRC:.fnl=.lua)

.PHONY: all clean

all: $(LUA_OUT)

%.lua: %.fnl fennel.exe
	./fennel.exe --compile $< > $@

clean:
	rm -f $(LUA_OUT)