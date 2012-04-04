
INSTALL	:=      install -m 700
DIR     :=      /etc/rc.d/init.d
SRC	:=	rpzla-bind

TARGETS     :=      $(SRC:%=$(DIR)/%)

all:	install

install:        $(TARGETS)

clean:          
	@echo "You mean clobber"

clobber:
	rm -f $(TARGETS)

$(DIR)/%:   %
	$(INSTALL) $< $@
	chkconfig $(SRC) on

