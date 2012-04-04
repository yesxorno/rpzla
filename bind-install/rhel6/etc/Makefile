
INSTALL	:=      install -m 600

ETC_DIR         :=      /usr/local/etc

ETC_SRCS        :=     \
			named.conf

ETC_TARGETS     :=      $(ETC_SRCS:%=$(ETC_DIR)/%)

# ------------------------
#  # Targets
# ------------------------

all:	install

install:        $(ETC_TARGETS)

clean:          
	@echo "You mean clobber"

clobber:
	rm -f $(ETC_TARGETS) $(CONF_TARGETS)

$(ETC_DIR)/%:   %
	$(INSTALL) $< $@
