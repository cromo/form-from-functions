SRC = $(wildcard *.fnl) $(wildcard lib/*.fnl) $(wildcard lib/*/*.fnl) $(wildcard src/*.fnl)
LUA_OUT = $(SRC:.fnl=.lua)
TEST = $(wildcard test/*.fnl)

.PHONY: all clean test

all: $(LUA_OUT)

%.lua: %.fnl fennel.exe
	./fennel.exe --compile $< > $@

clean:
	rm -f $(LUA_OUT)

# Mark unpack as global because it's global in LuaJIT (which is what LOVR uses)
# but not in Lua 5.4 (which is what the tests use).
test:
	./fennel.exe --globals unpack third-party/knife-test.fnl $(TEST)