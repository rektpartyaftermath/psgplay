# SPDX-License-Identifier: GPL-2.0
#
# Do "make help" for targets and options.

CFLAGS += -g -O2 -Wall -Iinclude -D_GNU_SOURCE

LIBS += -lm

ifeq "$(S)" "1"
S_CFLAGS += -fsanitize=address -fsanitize=leak -fsanitize=undefined	\
	  -fsanitize-address-use-after-scope -fstack-check
endif

ifeq "$(ALSA)" "1"
HAVE_CFLAGS += -DHAVE_ALSA
LIBS += -lasound
endif

DEP_CFLAGS += $(CFLAGS) $(BASIC_CFLAGS)
ALL_CFLAGS += $(DEP_CFLAGS) $(HAVE_CFLAGS) $(S_CFLAGS)

PSGPLAY := psgplay

.PHONY: all
all: $(PSGPLAY)

include lib/Makefile
include system/Makefile

LIBPSGPLAY_HIDDEN_SRC :=						\
	$(ATARI_SRC)							\
	$(ICE_SRC)							\
	$(INTERNAL_SRC)							\
	$(M68K_SRC)

LIBPSGPLAY_PUBLIC_SRC :=						\
	$(PSGPLAY_SRC)

PSGPLAY_SRC :=								\
	$(DISASSEMBLE_SRC) 						\
	$(OUT_SRC)							\
	$(SYSTEM_UNIX_SRC)						\
	$(TEXT_SRC)							\
	$(UNICODE_SRC)							\
	$(VT_SRC)

LIBPSGPLAY_HIDDEN_OBJ = $(patsubst %.c, %.o, $(LIBPSGPLAY_HIDDEN_SRC))
LIBPSGPLAY_PUBLIC_OBJ = $(patsubst %.c, %.o, $(LIBPSGPLAY_PUBLIC_SRC))
LIBPSGPLAY_OBJ = $(LIBPSGPLAY_HIDDEN_OBJ) $(LIBPSGPLAY_PUBLIC_OBJ)

PSGPLAY_OBJ = $(patsubst %.c, %.o, $(PSGPLAY_SRC))

$(LIBPSGPLAY_STATIC): $(LIBPSGPLAY_OBJ)
	$(QUIET_AR)$(AR) rcs $@ $^

$(LIBPSGPLAY_SHARED): $(LIBPSGPLAY_OBJ)
	$(QUIET_CC)$(CC) -shared -o $@ $^

$(PSGPLAY): $(PSGPLAY_OBJ) $(LIBPSGPLAY_STATIC)
	$(QUIET_LINK)$(CC) $(ALL_CFLAGS) -o $@ $^ $(LIBS)

$(LIBPSGPLAY_HIDDEN_OBJ): %.o : %.c
	$(QUIET_CC)$(CC) $(ALL_CFLAGS) -fvisibility=hidden -c -o $@ $<

$(LIBPSGPLAY_PUBLIC_OBJ): %.o : %.c
	$(QUIET_CC)$(CC) $(ALL_CFLAGS) -c -o $@ $<

$(PSGPLAY_OBJ): %.o : %.c
	$(QUIET_CC)$(CC) $(ALL_CFLAGS) -c -o $@ $<

.PHONY: clean
clean:
	$(QUIET_RM)$(RM) -f */*.o* */*/*.o* include/tos/tos.h		\
		$(PSGPLAY) PSGPLAY.* GPATH GRTAGS GTAGS 		\
		$(LIBPSGPLAY_STATIC) $(LIBPSGPLAY_SHARED)		\
		$(M68K_GEN_H) $(M68K_GEN_C) $(VER) $(M68KMAKE)

.PHONY: gtags
gtags:
	gtags

.PHONY: help
help:
	@echo "Targets:"
	@echo "  all            - compile PSG play (default)"
	@echo "  PSGPLAY.TOS    - compile PSG play for Atari ST"
	@echo "  clean          - remove generated files"
	@echo
	@echo "Options:"
	@echo "  V              - set to 1 to compile verbosely"
	@echo "  S              - set to 1 for sanitation checks"
	@echo "  ALSA           - set to 1 to support ALSA for Linux"
	@echo "  CROSS_COMPILE  - set m68k cross compiler to use for Atari ST code"
	@echo
	@echo "Example:"
	@echo "  make ALSA=1 CROSS_COMPILE=m68k-unknown-linux-gnu-"

V             = @
Q             = $(V:1=)
QUIET_AR      = $(Q:@=@echo    '  AR      '$@;)
QUIET_AS      = $(Q:@=@echo    '  AS      '$@;)
QUIET_CC      = $(Q:@=@echo    '  CC      '$@;)
QUIET_GEN     = $(Q:@=@echo    '  GEN     '$@;)
QUIET_LINK    = $(Q:@=@echo    '  LD      '$@;)
QUIET_TEST    = $(Q:@=@echo    '  TEST    '$@;)
QUIET_RM      = $(Q:@=@echo    '  RM      '$@;)

BASIC_CFLAGS += -Wp,-MD,$(@D)/$(@F).d -MT $(@D)/$(@F)

ifneq "$(MAKECMDGOALS)" "clean"
    DEP_FILES := $(shell find . -name '*'.d -printf '%P\n' | sort)
    $(if $(DEP_FILES),$(eval include $(DEP_FILES)))
endif
