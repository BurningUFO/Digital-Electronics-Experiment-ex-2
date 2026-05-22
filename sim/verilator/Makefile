TOP := game_console_top
BUILD_DIR := build/verilator
OBJ_DIR := $(BUILD_DIR)/obj_dir
BIN := $(OBJ_DIR)/V$(TOP)

THREADS ?= 4

VERILOG_SOURCES := $(abspath $(shell find src -name '*.v' | sort))
CPP_SOURCES := $(abspath sim/verilator/sdl_main.cpp)

VERILATOR_FLAGS := \
	-Wall \
	-O3 \
	--x-assign fast \
	--x-initial fast \
	--noassert \
	-DSIM_FAST_VGA \
	-DSIM_SHORT_BLANK \
	--Wno-fatal \
	-Wno-TIMESCALEMOD \
	-Wno-DECLFILENAME \
	-Wno-WIDTH \
	-Wno-CASEINCOMPLETE \
	-Wno-UNOPTFLAT \
	--threads $(THREADS) \
	--top-module $(TOP)

SDL_CFLAGS := $(shell sdl2-config --cflags)
SDL_LIBS := $(shell sdl2-config --libs)

CFLAGS_COMMON := $(SDL_CFLAGS) -std=c++17 -O3 -march=native -flto -DNDEBUG -DSIM_SHORT_BLANK
LDFLAGS_COMMON := $(SDL_LIBS) -flto -pthread

.PHONY: all run run-tank run-slot1 run-slot2 run-slot3 run-slot4 frames lint clean

all: $(BIN)

# --- Full build (all slots) ---
$(BIN): $(VERILOG_SOURCES) $(CPP_SOURCES)
	mkdir -p $(BUILD_DIR)
	verilator $(VERILATOR_FLAGS) --cc --exe --build \
		-Mdir $(OBJ_DIR) \
		-CFLAGS "$(CFLAGS_COMMON)" \
		-LDFLAGS "$(LDFLAGS_COMMON)" \
		$(VERILOG_SOURCES) $(CPP_SOURCES)

run: $(BIN)
	$(BIN)

frames: $(BIN)
	$(BIN) --frames 120

# --- Per-slot isolated builds ---
define SLOT_RULES
BUILD_$(1) := build/verilator-$(1)
OBJ_$(1) := $$(BUILD_$(1))/obj_dir
BIN_$(1) := $$(OBJ_$(1))/V$(TOP)

$$(BIN_$(1)): $(VERILOG_SOURCES) $(CPP_SOURCES)
	mkdir -p $$(BUILD_$(1))
	verilator $(VERILATOR_FLAGS) -D$(2) --cc --exe --build \
		-Mdir $$(OBJ_$(1)) \
		-CFLAGS "$(CFLAGS_COMMON)" \
		-LDFLAGS "$(LDFLAGS_COMMON)" \
		$(VERILOG_SOURCES) $(CPP_SOURCES)

run-$(1): $$(BIN_$(1))
	$$(BIN_$(1))
endef

$(eval $(call SLOT_RULES,tank,SIM_TANK_ONLY))
$(eval $(call SLOT_RULES,slot1,SIM_SLOT1_ONLY))
$(eval $(call SLOT_RULES,slot2,SIM_SLOT2_ONLY))
$(eval $(call SLOT_RULES,slot3,SIM_SLOT3_ONLY))
$(eval $(call SLOT_RULES,slot4,SIM_SLOT4_ONLY))

# --- Utilities ---
lint:
	verilator $(VERILATOR_FLAGS) --lint-only $(VERILOG_SOURCES)

clean:
	rm -rf build/verilator build/verilator-tank build/verilator-slot1 \
	       build/verilator-slot2 build/verilator-slot3 build/verilator-slot4
