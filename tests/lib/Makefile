BIN = main
CXX = g++
CXXFLAGS = \
	-Wall -Wextra

LDFLAGS = \
	-L../.. \
	-lvparse \
	-lCppUTest \
	-lCppUTestExt

SOURCES = main.cpp
OBJECTS = $(patsubst %.cpp, %.o, $(SOURCES))

.PHONY: all clean

%.o: %.cpp
	@echo -- Compiling $@ --
	$(CXX) $(CXXFLAGS) -c $< -o $@
	@echo

$(BIN): $(OBJECTS)
	@echo -- Linking objects to $@ --
	$(CXX) $(OBJECTS) $(LDFLAGS) -o $(BIN)
	@echo

all: $(BIN)

clean:
	@rm -rf $(BIN) $(OBJECTS)

test: $(BIN)
	@echo -- Running test suite --
	LD_LIBRARY_PATH=../.. ./main -v -c
