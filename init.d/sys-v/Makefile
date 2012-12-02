
INSTALL		:=	install -m 755
INIT_DIR	:=	/etc/rc.d/init.d
TURN_ON		:=	chkconfig

# ------------------------
# Targets
# ------------------------

all:
	@echo 'Specify which logger you want: bind or apache'

bind:	turn-on install-bind

apache:	turn-on install-apache

turn-on:	.dummy
	@echo Checking for $(TURN_ON) 
	@which $(TURN_ON) >/dev/null || exit 1

install-bind:	$(INIT_DIR)/rpzla-bind

install-apache:	$(INIT_DIR)/rpzla-apache

clean:		
	@echo "You mean clobber"

clobber:
	rm -f $(INIT_DIR)/rpzla-bind $(INIT_DIR)/rpzla-apache

$(INIT_DIR)/%:  %
	$(INSTALL) $< $@
	$(TURN_ON) $< on


.dummy:
