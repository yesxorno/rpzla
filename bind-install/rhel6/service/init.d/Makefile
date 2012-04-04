
INSTALL	:=      install -m 700
DIR     :=      /etc/rc.d/init.d
USER	:=	named
BASE	:=	/usr/local/var/named
RUN     :=      $(BASE)/run
DATA    :=      $(BASE)/data
SLAVES  :=      $(BASE)/slaves
SRCS	:=    \
		named

TARGETS     :=      $(SRCS:%=$(DIR)/%)

all:	install basic-dirs

install:        $(TARGETS) 

clean:          
	@echo "You mean clobber"

clobber:
	rm -f $(TARGETS)

$(DIR)/%:   %
	$(INSTALL) $< $@
	chkconfig named on

basic-dirs:	.dummy
	( mkdir -p $(RUN) ; chown $(USER) $(RUN) ; mkdir -p $(DATA) ; chown $(USER) $(DATA) ; mkdir -p $(SLAVES) ; chown $(USER) $(SLAVES) )

.dummy:
