
INSTALL		:=	install -m 600
ETC_DIR		:=	/etc/rpzla

ETC_SRCS	:=	\
			rpzla.conf

ETC_TARGETS	:=	$(ETC_SRCS:%=$(ETC_DIR)/%)

# ------------------------
# Targets
# ------------------------

all:		install

install:	$(ETC_TARGETS)

clean:		
	@echo "You mean clobber"

clobber:
	rm -f $(ETC_TARGETS)

$(ETC_DIR)/%:	%
	test -d $(ETC_DIR) || mkdir $(ETC_DIR)
	$(INSTALL) $< $@
