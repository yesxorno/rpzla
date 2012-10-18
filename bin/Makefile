
INSTALL		:=	install -m 755
BIN_DIR		:=	/usr/local/bin

BIN_SRCS	:=	\
			rpzla-apache		\
			rpzla-bind		\
			rpzla-report-mail.pl	\
			rpzla-report-text.pl

BIN_TARGETS	:=	$(BIN_SRCS:%=$(BIN_DIR)/%)

# ------------------------
# Targets
# ------------------------

all:		install

install:	$(BIN_TARGETS)

clean:		
	@echo "You mean clobber"

clobber:
	rm -f $(BIN_TARGETS)

$(BIN_DIR)/%:	%
	$(INSTALL) $< $@
