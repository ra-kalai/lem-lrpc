PKG_CONFIG = $(CROSS_COMPILE)pkg-config
INSTALL    = install

lmoddir    = $(shell $(PKG_CONFIG) --variable=INSTALL_LMOD lem)

llibs = lem/lrpc.lua

ifdef V
E=@\#
Q=
else
E=@echo
Q=@
endif

.PHONY: all install

usage:
	@echo type make install ?

$(DESTDIR)$(lmoddir)/%: %
	$E '  INSTALL $@'
	$Q$(INSTALL) -d $(dir $@)
	$Q$(INSTALL) -m 644 $< $@

install: \
	$(llibs:%=$(DESTDIR)$(lmoddir)/%)
