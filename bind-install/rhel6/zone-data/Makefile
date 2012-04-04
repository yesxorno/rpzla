
INSTALL	:=      install -m 600

ZONE_DIR         :=      /usr/local/var/named

ZONE_SRCS        :=     \
			localdomain.zone	\
			localhost.zone		\
			named.ca

ZONE_TARGETS     :=      $(ZONE_SRCS:%=$(ZONE_DIR)/%)

# ------------------------
#  # Targets
# ------------------------

all:	install

install:        $(ZONE_DIR) $(ZONE_TARGETS) 
	chown -R named /usr/local/var/named

clean:          
	@echo "You mean clobber"

clobber:
	rm -f $(ZONE_TARGETS) 

$(ZONE_DIR)/%:   %
	$(INSTALL) $< $@

$(ZONE_DIR):
	mkdir $(ZONE_DIR)

