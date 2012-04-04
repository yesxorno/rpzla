
INSTALL	:=      install -m 600
DIR     :=      /etc/sysconfig
SRCS	:=    \
		named

TARGETS     :=      $(SRCS:%=$(DIR)/%)

all:	install

install:        $(TARGETS)

clean:          
	@echo "You mean clobber"

clobber:
	rm -f $(TARGETS)

$(DIR)/%:   %
	$(INSTALL) $< $@

