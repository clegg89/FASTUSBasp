#
# makefile
# clegg, 2017-10-06 21:15
#

ifdef VERBOSE
	SILENT :=
else
	SILENT := @
endif

USE_LIBOPENCM3 ?= 1
USE_NANO ?= 1
USE_SEMIHOST ?= 0
USE_NOHOST ?= 0
USE_NOSTARTFILES ?= 1

SHELL := /bin/bash

SUFFIX ?= out

subtract = $(shell echo $$(( $(1) - $(2) )))

PREV_MAKEFILE := $(word $(call subtract,$(words $(MAKEFILE_LIST)),1),$(MAKEFILE_LIST))

ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PROJ_DIR := $(abspath $(dir $(PREV_MAKEFILE)))

OUTPUT_DIR := $(ROOT_DIR)/build/$(PROJECT)

TARGET := $(OUTPUT_DIR)/$(PROJECT).$(SUFFIX)

PREFIX ?= arm-none-eabi

CC := $(PREFIX)-gcc
CXX := $(PREFIX)-g++

OPENCM3_DIR = $(ROOT_DIR)/libopencm3

ifeq ($(USE_LIBOPENCM3),1)
	INCLUDE_DIRS += $(OPENCM3_DIR)/include
	LIB_DIRS += $(OPENCM3_DIR)/lib
	DEFINES += STM32F1
	LIBS += opencm3_stm32f1
endif

OBJ = $(addprefix $(OUTPUT_DIR)/,$(subst .S,.o, $(subst .c,.o, $(subst .cpp,.o, $(SRC)))))

ifndef LDSCRIPT
	ifneq ($(USE_LIBOPENCM3),1)
		LIB_DIRS += $(OPENCM3_DIR)/lib
	endif
	LDSCRIPT = $(OPENCM3_DIR)/lib/stm32/f1/stm32f103x8.ld
endif

ifeq ($(USE_NANO),1)
	SPECS += --specs=nano.specs
endif
ifeq ($(USE_SEMIHOST),1)
	SPECS += --specs=rdimon.specs
endif
ifeq ($(USE_NOHOST),1)
	SPECS += --specs=nosys.specs
endif

ifeq ($(USE_NOSTARTFILES),1)
	NOSTART = -nostartfiles
else
	NOSTART =
endif

## FLAGS
#
# Flags are seperated in a similar fashion to GCC documentation

# Use C99 syntax
C_LANG_OPTIONS := -std=gnu99

# No RTTI, no Exceptions, allow C++11
CXX_LANG_OPTIONS := -fno-rtti -fno-exceptions -std=c++11 -Weffc++

# None
WARNING_OPTIONS := -Wall -Wextra -Wshadow -Wredundant-decls -Wundef

# Debugging on
DEBUGGING_OPTIONS := -g

# Optimize for size, create sections for data and code to optimize at linking
OPTIMIZATION_OPTIONS := -Os -ffunction-sections -fdata-sections

## Preprocesor Options

# Defines
DEFINE_OPTIONS = $(foreach def,$(DEFINES), -D$(def))

# Generate dependency files
DEPENDENCY_OPTIONS = -MMD -MP -MF $(@:%.o=%.d) -MT $@

# None
ASM_OPTIONS :=

# Generate map file
LINKER_OPTIONS = -static $(NOSTART) $(SPECS) -Wl,-Map,$(addsuffix .map,$(basename $@)),--cref,--gc-sections -T$(LDSCRIPT)

# Include directories
DIRECTORY_OPTIONS = $(foreach directory,$(INCLUDE_DIRS), -I$(directory))

# No common sections
CODE_GEN_OPTIONS := -fno-common

FP_FLAGS	?= -msoft-float
ARM_OPTIONS := -mthumb -mcpu=cortex-m3 $(FP_FLAGS) -mlittle-endian

CPPFLAGS = $(DEFINE_OPTIONS) $(DEPENDENCY_OPTIONS) $(DIRECTORY_OPTIONS)
ASFLAGS = $(ASM_OPTIONS) $(WARNING_OPTIONS) $(DEBUGGING_OPTIONS) $(OPTIMIZATION_OPTIONS) $(CODE_GEN_OPTIONS) $(ARM_OPTIONS)
CFLAGS = $(C_LANG_OPTIONS) $(WARNING_OPTIONS) $(DEBUGGING_OPTIONS) $(OPTIMIZATION_OPTIONS) $(CODE_GEN_OPTIONS) $(ARM_OPTIONS)
CXXFLAGS = $(CXX_LANG_OPTIONS) $(WARNING_OPTIONS) $(DEBUGGING_OPTIONS) $(OPTIMIZATION_OPTIONS) $(CODE_GEN_OPTIONS) $(ARM_OPTIONS)
LDFLAGS = $(ARM_OPTIONS) $(foreach directory,$(LIB_DIRS), -L$(directory)) $(LINKER_OPTIONS)
LDLIBS =  $(foreach lib,$(LIBS), -l$(lib))

.PHONY : all clean

all: $(TARGET)

$(TARGET): $(OBJ)
	@mkdir -p $(@D)
	@echo "Linking $(@F)"
	$(SILENT)$(CXX) $(LDFLAGS) -o $@ $^ $(LDLIBS)

$(OUTPUT_DIR)/%.o : $(PROJ_DIR)/%.cpp
	@mkdir -p $(@D)
	@echo "Compiling $(@F)"
	@-$(CXX) -E $< $(CPPFLAGS) $(CXXFLAGS) -o $(OUTPUT_DIR)/$*.i > /dev/null 2>&1
	@-$(CXX) -S $< $(CPPFLAGS) $(CXXFLAGS) -o $(OUTPUT_DIR)/$*.lst > /dev/null 2>&1
	$(SILENT)$(CXX) -c $(CPPFLAGS) $(CXXFLAGS) -o $@ $<

$(OUTPUT_DIR)/%.o : $(PROJ_DIR)/%.c
	@mkdir -p $(@D)
	@echo "Compiling $(@F)"
	@-$(CC) -E $< $(CPPFLAGS) $(CFLAGS) -o $(OUTPUT_DIR)/$*.i > /dev/null 2>&1
	@-$(CC) -S $< $(CPPFLAGS) $(CFLAGS) -o $(OUTPUT_DIR)/$*.lst > /dev/null 2>&1
	$(SILENT)$(CC) -c $(CPPFLAGS) $(CFLAGS) -o $@ $<

clean:
	@echo "Clean $(PROJECT)"
	$(SILENT)$(RM) -rf $(OUTPUT_DIR)/*

# vim:ft=make
#
