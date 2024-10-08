TOOLCHAIN := $(DEVKITARM)
COMPARE ?= 0

ifeq (compare,$(MAKECMDGOALS))
  COMPARE := 1
endif

# Default make rule
all: rom

# don't use dkP's base_tools anymore
# because the redefinition of $(CC) conflicts
# with when we want to use $(CC) to preprocess files
# thus, manually create the variables for the bin
# files, or use arm-none-eabi binaries on the system
# if dkP is not installed on this system

ifneq (,$(TOOLCHAIN))
ifneq ($(wildcard $(TOOLCHAIN)/bin),)
export PATH := $(TOOLCHAIN)/bin:$(PATH)
endif
endif

PREFIX := arm-none-eabi-
OBJCOPY := $(PREFIX)objcopy
OBJDUMP := $(PREFIX)objdump
AS := $(PREFIX)as

LD := $(PREFIX)ld

# note: the makefile must be set up so MODERNCC is never called
# if MODERN=0
MODERNCC := $(PREFIX)gcc
PATH_MODERNCC := PATH="$(PATH)" $(MODERNCC)

ifeq ($(OS),Windows_NT)
EXE := .exe
else
EXE :=
endif

TITLE       := POKEMON EMER
GAME_CODE   := BPEE
MAKER_CODE  := 01
REVISION    := 0
MODERN      ?= 0

# `File name`.gba ('_modern' will be appended to the modern builds)
FILE_NAME := pokeemerald
BUILD_DIR := build

# Builds the ROM using a modern compiler
MODERN      ?= 0
# Compares the ROM to a checksum of the original - only makes sense using when non-modern
COMPARE     ?= 0

ifeq (modern,$(MAKECMDGOALS))
  MODERN := 1
endif
ifeq (compare,$(MAKECMDGOALS))
  COMPARE := 1
endif

# Default make rule
all: rom

# Toolchain selection
TOOLCHAIN := $(DEVKITARM)
# don't use dkP's base_tools anymore
# because the redefinition of $(CC) conflicts
# with when we want to use $(CC) to preprocess files
# thus, manually create the variables for the bin
# files, or use arm-none-eabi binaries on the system
# if dkP is not installed on this system
ifneq (,$(TOOLCHAIN))
  ifneq ($(wildcard $(TOOLCHAIN)/bin),)
    export PATH := $(TOOLCHAIN)/bin:$(PATH)
  endif
endif

PREFIX := arm-none-eabi-
OBJCOPY := $(PREFIX)objcopy
OBJDUMP := $(PREFIX)objdump
AS := $(PREFIX)as
LD := $(PREFIX)ld

EXE :=
ifeq ($(OS),Windows_NT)
  EXE := .exe
endif

# use arm-none-eabi-cpp for macOS
# as macOS's default compiler is clang
# and clang's preprocessor will warn on \u
# when preprocessing asm files, expecting a unicode literal
# we can't unconditionally use arm-none-eabi-cpp
# as installations which install binutils-arm-none-eabi
# don't come with it
ifneq ($(MODERN),1)
  ifeq ($(shell uname -s),Darwin)
    CPP := $(PREFIX)cpp
  else
    CPP := $(CC) -E
  endif
else
  CPP := $(PREFIX)cpp
endif

ROM_NAME := $(FILE_NAME).gba
OBJ_DIR_NAME := $(BUILD_DIR)/emerald
MODERN_ROM_NAME := $(FILE_NAME)_modern.gba
MODERN_OBJ_DIR_NAME := $(BUILD_DIR)/modern

ELF_NAME := $(ROM_NAME:.gba=.elf)
MAP_NAME := $(ROM_NAME:.gba=.map)
MODERN_ELF_NAME := $(MODERN_ROM_NAME:.gba=.elf)
MODERN_MAP_NAME := $(MODERN_ROM_NAME:.gba=.map)

SHELL := bash -o pipefail

ELF = $(ROM:.gba=.elf)
MAP = $(ROM:.gba=.map)
SYM = $(ROM:.gba=.sym)

# Commonly used directories
C_SUBDIR = src
GFLIB_SUBDIR = gflib
ASM_SUBDIR = asm
DATA_SRC_SUBDIR = src/data
DATA_ASM_SUBDIR = data
SONG_SUBDIR = sound/songs
MID_SUBDIR = sound/songs/midi
SAMPLE_SUBDIR = sound/direct_sound_samples
CRY_SUBDIR = sound/direct_sound_samples/cries

C_BUILDDIR = $(OBJ_DIR)/$(C_SUBDIR)
GFLIB_BUILDDIR = $(OBJ_DIR)/$(GFLIB_SUBDIR)
ASM_BUILDDIR = $(OBJ_DIR)/$(ASM_SUBDIR)
DATA_ASM_BUILDDIR = $(OBJ_DIR)/$(DATA_ASM_SUBDIR)
SONG_BUILDDIR = $(OBJ_DIR)/$(SONG_SUBDIR)
MID_BUILDDIR = $(OBJ_DIR)/$(MID_SUBDIR)

SHELL := /bin/bash -o pipefail

# Set flags for tools
ASFLAGS := -mcpu=arm7tdmi --defsym MODERN=$(MODERN)

INCLUDE_DIRS := include
INCLUDE_CPP_ARGS := $(INCLUDE_DIRS:%=-iquote %)
INCLUDE_SCANINC_ARGS := $(INCLUDE_DIRS:%=-I %)

O_LEVEL ?= 2
CPPFLAGS := $(INCLUDE_CPP_ARGS) -iquote $(GFLIB_SUBDIR) -Wno-trigraphs -DMODERN=$(MODERN)
ifeq ($(MODERN),0)
  CPPFLAGS += -I tools/agbcc/include -I tools/agbcc -nostdinc -undef
  CC1 := tools/agbcc/bin/agbcc$(EXE)
  override CFLAGS += -mthumb-interwork -Wimplicit -Wparentheses -Werror -O$(O_LEVEL) -fhex-asm -g
  LIBPATH := -L ../../tools/agbcc/lib
  LIB := $(LIBPATH) -lgcc -lc -L../../libagbsyscall -lagbsyscall
else
  # Note: The makefile must be set up to not call these if modern == 0
  MODERNCC := $(PREFIX)gcc
  PATH_MODERNCC := PATH="$(PATH)" $(MODERNCC)
  CC1 := $(shell $(PATH_MODERNCC) --print-prog-name=cc1) -quiet
  override CFLAGS += -mthumb -mthumb-interwork -O$(O_LEVEL) -mabi=apcs-gnu -mtune=arm7tdmi -march=armv4t -fno-toplevel-reorder -Wno-pointer-to-int-cast
  LIBPATH := -L "$(dir $(shell $(PATH_MODERNCC) -mthumb -print-file-name=libgcc.a))" -L "$(dir $(shell $(PATH_MODERNCC) -mthumb -print-file-name=libnosys.a))" -L "$(dir $(shell $(PATH_MODERNCC) -mthumb -print-file-name=libc.a))"
  LIB := $(LIBPATH) -lc -lnosys -lgcc -L../../libagbsyscall -lagbsyscall
endif
# Enable debug info if set
ifeq ($(DINFO),1)
  override CFLAGS += -g
endif

LDFLAGS = -Map ../../$(MAP)

# Variable filled out in other make files
AUTO_GEN_TARGETS :=
include make_tools.mk

SHA1 := $(shell { command -v sha1sum || command -v shasum; } 2>/dev/null) -c
GFX       := $(TOOLS_DIR)/gbagfx/gbagfx$(EXE)
AIF       := $(TOOLS_DIR)/aif2pcm/aif2pcm$(EXE)
MID       := $(TOOLS_DIR)/mid2agb/mid2agb$(EXE)
SCANINC   := $(TOOLS_DIR)/scaninc/scaninc$(EXE)
PREPROC   := $(TOOLS_DIR)/preproc/preproc$(EXE)
RAMSCRGEN := $(TOOLS_DIR)/ramscrgen/ramscrgen$(EXE)
FIX       := $(TOOLS_DIR)/gbafix/gbafix$(EXE)
MAPJSON   := $(TOOLS_DIR)/mapjson/mapjson$(EXE)
JSONPROC  := $(TOOLS_DIR)/jsonproc/jsonproc$(EXE)

PERL := perl

MAKEFLAGS += --no-print-directory

# Clear the default suffixes
.SUFFIXES:
# Don't delete intermediate files
.SECONDARY:
# Delete files that weren't built properly
.DELETE_ON_ERROR:
# Secondary expansion is required for dependency variables in object rules.
.SECONDEXPANSION:

.PHONY: all rom clean compare tidy mostlyclean libagbsyscall modern tidymodern tidynonmodern

infoshell = $(foreach line, $(shell $1 | sed "s/ /__SPACE__/g"), $(info $(subst __SPACE__, ,$(line))))

# Build tools when building the rom
# Disable dependency scanning for clean/tidy/tools
# Use a separate minimal makefile for speed
# Since we don't need to reload most of this makefile
ifeq (,$(filter-out all rom compare modern libagbsyscall syms,$(MAKECMDGOALS)))
$(call infoshell, $(MAKE) -f make_tools.mk)
$(call infoshell, $(MAKE) generated)
else
NODEP ?= 1
endif

# check if we need to scan dependencies based on the rule
ifeq (,$(MAKECMDGOALS))
  SCAN_DEPS ?= 1
else
  # clean, tidy, tools, mostlyclean, clean-tools, $(TOOLDIRS), tidymodern, tidynonmodern don't even build the ROM
  # libagbsyscall does its own thing
  ifeq (,$(filter-out clean tidy tools mostlyclean clean-tools $(TOOLDIRS) tidymodern tidynonmodern libagbsyscall,$(MAKECMDGOALS)))
    SCAN_DEPS ?= 0
  else
    SCAN_DEPS ?= 1
  endif
endif

ifeq ($(SETUP_PREREQS),1)
  # If set on: Default target or a rule requiring a scan
  # Forcibly execute `make tools` since we need them for what we are doing.
  $(call infoshell, $(MAKE) -f make_tools.mk)
  # Oh and also generate mapjson sources before we use `SCANINC`.
  $(call infoshell, $(MAKE) generated)
endif

# Collect sources
C_SRCS_IN := $(wildcard $(C_SUBDIR)/*.c $(C_SUBDIR)/*/*.c $(C_SUBDIR)/*/*/*.c)
C_SRCS := $(foreach src,$(C_SRCS_IN),$(if $(findstring .inc.c,$(src)),,$(src)))
C_OBJS := $(patsubst $(C_SUBDIR)/%.c,$(C_BUILDDIR)/%.o,$(C_SRCS))

GFLIB_SRCS := $(wildcard $(GFLIB_SUBDIR)/*.c)
GFLIB_OBJS := $(patsubst $(GFLIB_SUBDIR)/%.c,$(GFLIB_BUILDDIR)/%.o,$(GFLIB_SRCS))

C_ASM_SRCS := $(wildcard $(C_SUBDIR)/*.s $(C_SUBDIR)/*/*.s $(C_SUBDIR)/*/*/*.s)
C_ASM_OBJS := $(patsubst $(C_SUBDIR)/%.s,$(C_BUILDDIR)/%.o,$(C_ASM_SRCS))

ASM_SRCS := $(wildcard $(ASM_SUBDIR)/*.s)
ASM_OBJS := $(patsubst $(ASM_SUBDIR)/%.s,$(ASM_BUILDDIR)/%.o,$(ASM_SRCS))

# get all the data/*.s files EXCEPT the ones with specific rules
REGULAR_DATA_ASM_SRCS := $(filter-out $(DATA_ASM_SUBDIR)/maps.s $(DATA_ASM_SUBDIR)/map_events.s, $(wildcard $(DATA_ASM_SUBDIR)/*.s))

DATA_ASM_SRCS := $(wildcard $(DATA_ASM_SUBDIR)/*.s)
DATA_ASM_OBJS := $(patsubst $(DATA_ASM_SUBDIR)/%.s,$(DATA_ASM_BUILDDIR)/%.o,$(DATA_ASM_SRCS))

SONG_SRCS := $(wildcard $(SONG_SUBDIR)/*.s)
SONG_OBJS := $(patsubst $(SONG_SUBDIR)/%.s,$(SONG_BUILDDIR)/%.o,$(SONG_SRCS))

MID_SRCS := $(wildcard $(MID_SUBDIR)/*.mid)
MID_OBJS := $(patsubst $(MID_SUBDIR)/%.mid,$(MID_BUILDDIR)/%.o,$(MID_SRCS))

OBJS     := $(C_OBJS) $(GFLIB_OBJS) $(C_ASM_OBJS) $(ASM_OBJS) $(DATA_ASM_OBJS) $(SONG_OBJS) $(MID_OBJS)
OBJS_REL := $(patsubst $(OBJ_DIR)/%,%,$(OBJS))

SUBDIRS  := $(sort $(dir $(OBJS)))
$(shell mkdir -p $(SUBDIRS))

syms: $(SYM)

rom: $(ROM)
ifeq ($(COMPARE),1)
	@$(SHA1) rom.sha1
endif

syms: $(SYM)

clean: tidy clean-tools clean-generated clean-assets
	@$(MAKE) clean -C libagbsyscall

mostlyclean: tidynonmodern tidymodern
	find sound -iname '*.bin' -exec rm {} +
	rm -f $(MID_SUBDIR)/*.s
	rm -f $(DATA_ASM_SUBDIR)/layouts/layouts.inc $(DATA_ASM_SUBDIR)/layouts/layouts_table.inc
	rm -f $(DATA_ASM_SUBDIR)/maps/connections.inc $(DATA_ASM_SUBDIR)/maps/events.inc $(DATA_ASM_SUBDIR)/maps/groups.inc $(DATA_ASM_SUBDIR)/maps/headers.inc
	find sound -iname '*.bin' -exec rm {} +
	find . \( -iname '*.1bpp' -o -iname '*.4bpp' -o -iname '*.8bpp' -o -iname '*.gbapal' -o -iname '*.lz' -o -iname '*.rl' -o -iname '*.latfont' -o -iname '*.hwjpnfont' -o -iname '*.fwjpnfont' \) -exec rm {} +
	find $(DATA_ASM_SUBDIR)/maps \( -iname 'connections.inc' -o -iname 'events.inc' -o -iname 'header.inc' \) -exec rm {} +

tidy: tidynonmodern tidymodern

tidynonmodern:
	rm -f $(ROM_NAME) $(ELF_NAME) $(MAP_NAME)
	rm -rf $(OBJ_DIR_NAME)

tidymodern:
	rm -f $(MODERN_ROM_NAME) $(MODERN_ELF_NAME) $(MODERN_MAP_NAME)
	rm -rf $(MODERN_OBJ_DIR_NAME)

# Other rules
include graphics_file_rules.mk
include map_data_rules.mk
include spritesheet_rules.mk
include json_data_rules.mk
include songs.mk

generated: $(AUTO_GEN_TARGETS)

%.s: ;
%.png: ;
%.pal: ;
%.aif: ;

%.1bpp: %.png  ; $(GFX) $< $@
%.4bpp: %.png  ; $(GFX) $< $@
%.8bpp: %.png  ; $(GFX) $< $@
%.gbapal: %.pal ; $(GFX) $< $@
%.gbapal: %.png ; $(GFX) $< $@
%.lz: % ; $(GFX) $< $@
%.rl: % ; $(GFX) $< $@
$(CRY_SUBDIR)/%.bin: $(CRY_SUBDIR)/%.aif ; $(AIF) $< $@ --compress
sound/%.bin: sound/%.aif ; $(AIF) $< $@

# NOTE: Tools must have been built prior (FIXME)
generated: tools $(AUTO_GEN_TARGETS)
clean-generated:
	-rm -f $(AUTO_GEN_TARGETS)

ifeq ($(MODERN),0)
$(C_BUILDDIR)/libc.o: CC1 := $(TOOLS_DIR)/agbcc/bin/old_agbcc$(EXE)
$(C_BUILDDIR)/libc.o: CFLAGS := -O2
$(C_BUILDDIR)/siirtc.o: CFLAGS := -mthumb-interwork
$(C_BUILDDIR)/agb_flash.o: CFLAGS := -O -mthumb-interwork
$(C_BUILDDIR)/agb_flash_1m.o: CFLAGS := -O -mthumb-interwork
$(C_BUILDDIR)/agb_flash_mx.o: CFLAGS := -O -mthumb-interwork

$(C_BUILDDIR)/m4a.o: CC1 := $(TOOLS_DIR)/agbcc/bin/old_agbcc$(EXE)

$(C_BUILDDIR)/record_mixing.o: CFLAGS += -ffreestanding
$(C_BUILDDIR)/librfu_intr.o: CC1 := $(TOOLS_DIR)/agbcc/bin/agbcc_arm$(EXE)
$(C_BUILDDIR)/librfu_intr.o: CFLAGS := -O2 -mthumb-interwork -quiet
else
$(C_BUILDDIR)/librfu_intr.o: CFLAGS := -mthumb-interwork -O2 -mabi=apcs-gnu -mtune=arm7tdmi -march=armv4t -fno-toplevel-reorder -Wno-pointer-to-int-cast
$(C_BUILDDIR)/berry_crush.o: override CFLAGS += -Wno-address-of-packed-member
endif

# Dependency rules (for the *.c & *.s sources to .o files)
# Have to be explicit or else missing files won't be reported.

# As a side effect, they're evaluated immediately instead of when the rule is invoked.
# It doesn't look like $(shell) can be deferred so there might not be a better way (Icedude_907: there is soon).

ifeq ($(SCAN_DEPS),1)
ifeq ($(NODEP),1)
$(C_BUILDDIR)/%.o: $(C_SUBDIR)/%.c
ifeq (,$(KEEP_TEMPS))
	@echo "$(CC1) <flags> -o $@ $<"
	@$(CPP) $(CPPFLAGS) $< | $(PREPROC) -i $< charmap.txt | $(CC1) $(CFLAGS) -o - - | cat - <(echo -e ".text\n\t.align\t2, 0") | $(AS) $(ASFLAGS) -o $@ -
else
	@$(CPP) $(CPPFLAGS) $< -o $(C_BUILDDIR)/$*.i
	@$(PREPROC) $(C_BUILDDIR)/$*.i charmap.txt | $(CC1) $(CFLAGS) -o $(C_BUILDDIR)/$*.s
	@echo -e ".text\n\t.align\t2, 0\n" >> $(C_BUILDDIR)/$*.s
	$(AS) $(ASFLAGS) -o $@ $(C_BUILDDIR)/$*.s
endif
else
define C_DEP
$1: $2 $$(shell $(SCANINC) -I include -I $(TOOLS_DIR)/agbcc/include -I gflib $2)
ifeq (,$$(KEEP_TEMPS))
	@echo "$$(CC1) <flags> -o $$@ $$<"
	@$$(CPP) $$(CPPFLAGS) $$< | $$(PREPROC) -i $$< charmap.txt | $$(CC1) $$(CFLAGS) -o - - | cat - <(echo -e ".text\n\t.align\t2, 0") | $$(AS) $$(ASFLAGS) -o $$@ -
else
	@$$(CPP) $$(CPPFLAGS) $$< -o $$(C_BUILDDIR)/$3.i
	@$$(PREPROC) $$(C_BUILDDIR)/$3.i charmap.txt | $$(CC1) $$(CFLAGS) -o $$(C_BUILDDIR)/$3.s
	@echo -e ".text\n\t.align\t2, 0\n" >> $$(C_BUILDDIR)/$3.s
	$$(AS) $$(ASFLAGS) -o $$@ $$(C_BUILDDIR)/$3.s
endif
endef
# Internal implementation details.
# $1: Output file without extension, $2 input file, $3 temp path (if keeping)
define C_DEP_IMPL
$1.o: $2
ifeq (,$(KEEP_TEMPS))
	@echo "$(CC1) <flags> -o $@ $<"
	@$(CPP) $(CPPFLAGS) $< | $(PREPROC) -i $< charmap.txt | $(CC1) $(CFLAGS) -o - - | cat - <(echo -e ".text\n\t.align\t2, 0") | $(AS) $(ASFLAGS) -o $@ -
else
	@$(CPP) $(CPPFLAGS) $< -o $(GFLIB_BUILDDIR)/$*.i
	@$(PREPROC) $(GFLIB_BUILDDIR)/$*.i charmap.txt | $(CC1) $(CFLAGS) -o $(GFLIB_BUILDDIR)/$*.s
	@echo -e ".text\n\t.align\t2, 0\n" >> $(GFLIB_BUILDDIR)/$*.s
	$(AS) $(ASFLAGS) -o $@ $(GFLIB_BUILDDIR)/$*.s
endif
else
define GFLIB_DEP
$1: $2 $$(shell $(SCANINC) -I include -I $(TOOLS_DIR)/agbcc/include -I gflib $2)
ifeq (,$$(KEEP_TEMPS))
	@echo "$$(CC1) <flags> -o $$@ $$<"
	@$$(CPP) $$(CPPFLAGS) $$< | $$(PREPROC) -i $$< charmap.txt | $$(CC1) $$(CFLAGS) -o - - | cat - <(echo -e ".text\n\t.align\t2, 0") | $$(AS) $$(ASFLAGS) -o $$@ -
else
	@$$(CPP) $$(CPPFLAGS) $$< -o $3.i
	@$$(PREPROC) $3.i charmap.txt | $$(CC1) $$(CFLAGS) -o $3.s
	@echo -e ".text\n\t.align\t2, 0\n" >> $3.s
	$$(AS) $$(ASFLAGS) -o $$@ $3.s
endif
$(call C_SCANINC,$1,$2)
endef
# Calls SCANINC to find dependencies
define C_SCANINC
ifneq ($(NODEP),1)
$1.o: $2 $$(shell $(SCANINC) $(INCLUDE_SCANINC_ARGS) -I tools/agbcc/include -I gflib $2)
endif
endef

# Create generic rules if no dependency scanning, else create the real rules
ifeq ($(NODEP),1)
$(eval $(call C_DEP,$(C_BUILDDIR)/%,$(C_SUBDIR)/%.c))
$(eval $(call C_DEP,$(GFLIB_BUILDDIR)/%,$(GFLIB_SUBDIR)/%.c))
else
$(foreach src,$(C_SRCS),$(eval $(call C_DEP,$(OBJ_DIR)/$(basename $(src)),$(src))))
$(foreach src,$(GFLIB_SRCS),$(eval $(call C_DEP,$(OBJ_DIR)/$(basename $(src)),$(src))))
endif

ifeq ($(NODEP),1)
$(C_BUILDDIR)/%.o: $(C_SUBDIR)/%.s
	$(PREPROC) $< charmap.txt | $(CPP) -I include - | $(PREPROC) -i $$< charmap.txt | $(AS) $(ASFLAGS) -o $@
else
define SRC_ASM_DATA_DEP
$1: $2 $$(shell $(SCANINC) -I include -I "" $2)
	$$(PREPROC) $$< charmap.txt | $$(CPP) -I include - | $$(PREPROC) -ie $$< charmap.txt | $$(AS) $$(ASFLAGS) -o $$@
endef
$(foreach src, $(C_ASM_SRCS), $(eval $(call SRC_ASM_DATA_DEP,$(patsubst $(C_SUBDIR)/%.s,$(C_BUILDDIR)/%.o, $(src)),$(src))))
endif

ifeq ($(NODEP),1)
$(ASM_BUILDDIR)/%.o: $(ASM_SUBDIR)/%.s
	$(AS) $(ASFLAGS) -o $@ $<
else
define ASM_DEP
$1.o: $2
	$$(AS) $$(ASFLAGS) -o $$@ $$<
$(call ASM_SCANINC,$1,$2)
endef
# As above but first doing a preprocessor pass
define ASM_DEP_PREPROC
$1.o: $2
	$$(PREPROC) $$< charmap.txt | $$(CPP) $(INCLUDE_SCANINC_ARGS) - | $$(AS) $$(ASFLAGS) -o $$@
$(call ASM_SCANINC,$1,$2)
endef

define ASM_SCANINC
ifneq ($(NODEP),1)
$1.o: $2 $$(shell $(SCANINC) $(INCLUDE_SCANINC_ARGS) -I "" $2)
endif
endef

# Dummy rules or real rules
ifeq ($(NODEP),1)
$(DATA_ASM_BUILDDIR)/%.o: $(DATA_ASM_SUBDIR)/%.s
	$(PREPROC) $< charmap.txt | $(CPP) -I include - | $(PREPROC) -ie $$< charmap.txt | $(AS) $(ASFLAGS) -o $@
else
$(foreach src, $(ASM_SRCS), $(eval $(call ASM_DEP,$(src:%.s=$(OBJ_DIR)/%),$(src))))
$(foreach src, $(C_ASM_SRCS), $(eval $(call ASM_DEP_PREPROC,$(src:%.s=$(OBJ_DIR)/%),$(src))))
$(foreach src, $(REGULAR_DATA_ASM_SRCS), $(eval $(call ASM_DEP_PREPROC,$(src:%.s=$(OBJ_DIR)/%),$(src))))
endif

# Additional rules
$(SONG_BUILDDIR)/%.o: $(SONG_SUBDIR)/%.s
	$(AS) $(ASFLAGS) -I sound -o $@ $<

$(OBJ_DIR)/sym_bss.ld: sym_bss.txt
	$(RAMSCRGEN) .bss $< ENGLISH > $@

$(OBJ_DIR)/sym_common.ld: sym_common.txt $(C_OBJS) $(wildcard common_syms/*.txt)
	$(RAMSCRGEN) COMMON $< ENGLISH -c $(C_BUILDDIR),common_syms > $@

$(OBJ_DIR)/sym_ewram.ld: sym_ewram.txt
	$(RAMSCRGEN) ewram_data $< ENGLISH > $@

# Linker script
ifeq ($(MODERN),0)
LD_SCRIPT := ld_script.ld
LD_SCRIPT_DEPS := $(OBJ_DIR)/sym_bss.ld $(OBJ_DIR)/sym_common.ld $(OBJ_DIR)/sym_ewram.ld
else
LD_SCRIPT := ld_script_modern.ld
LD_SCRIPT_DEPS :=
endif

$(OBJ_DIR)/ld_script.ld: $(LD_SCRIPT) $(LD_SCRIPT_DEPS)
	sed "s#tools/#tools/#g" $(LD_SCRIPT) > $(OBJ_DIR)/ld_script.ld

# Final rules

libagbsyscall:
	@$(MAKE) -C libagbsyscall TOOLCHAIN=$(TOOLCHAIN) MODERN=$(MODERN)

# Elf from object files
$(ELF): $(OBJ_DIR)/ld_script.ld $(OBJS) libagbsyscall
	@echo "cd $(OBJ_DIR) && $(LD) $(LDFLAGS) -T ld_script.ld -o ../../$@ <objects> <lib>"
	@cd $(OBJ_DIR) && $(LD) $(LDFLAGS) -T ld_script.ld --print-memory-usage -o ../../$@ $(OBJS_REL) $(LIB) | cat
	$(FIX) $@ -t"$(TITLE)" -c$(GAME_CODE) -m$(MAKER_CODE) -r$(REVISION) --silent

# Builds the rom from the elf file
$(ROM): $(ELF)
	$(OBJCOPY) -O binary $< $@
	$(FIX) $@ -p --silent

# Symbol file (`make syms`)
$(SYM): $(ELF)
	$(OBJDUMP) -t $< | sort -u | grep -E "^0[2389]" | $(PERL) -p -e 's/^(\w{8}) (\w).{6} \S+\t(\w{8}) (\S+)$$/\1 \2 \3 \4/g' > $@
