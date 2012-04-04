
INSTALL	:=      install -m 600

RPZ_DIR         :=      /usr/local/var/named

RPZ_SRCS        :=     \
			rpz-data-local.env.dtu.dk.zone	\
			rpz.spamhaus.org.zone

RPZ_TARGETS     :=      $(RPZ_SRCS:%=$(RPZ_DIR)/%)

# ------------------------
#  # Targets
# ------------------------

all:	install

install:        $(RPZ_TARGETS)

clean:          
	@echo "You mean clobber"

clobber:
	rm -f $(RPZ_TARGETS) $(CONF_TARGETS)

$(RPZ_DIR)/%:   %
	$(INSTALL) $< $@
