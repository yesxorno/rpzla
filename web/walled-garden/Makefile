
CGI_DIR		:=	/var/www/html/dns-blacklist

CGI_SRCS	:=	\
			warning.cgi

CGI_TARGETS	:=	$(CGI_SRCS:%=$(CGI_DIR)/%)

INSTALL		:=	install -m 755

# ------------------------
# Targets
# ------------------------

all:		install

install:	$(CGI_DIR) $(CGI_TARGETS)
	cp -r public $(CGI_DIR)

clobber:
	rm -f $(CGI_TARGETS)
	rm -rf $(CGI_BIN)/public

$(CGI_DIR):
	mkdir $(CGI_DIR)

$(CGI_DIR)/%.cgi:	%.cgi
	$(INSTALL) $< $@
