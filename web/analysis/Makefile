
CGI_DIR		:=	/var/www/html/rpzla

CGI_SRCS	:=	\
			rpzla.cgi

CGI_TARGETS	:=	$(CGI_SRCS:%=$(CGI_DIR)/%)

INSTALL		:=	install -m 755

# ------------------------
# Targets
# ------------------------

all:		install

install:	$(CGI_DIR) $(CGI_TARGETS)
	cp ../../etc/rpzla.conf $(CGI_DIR)
	cp -r Mojolicious public $(CGI_DIR)

clobber:
	rm -f $(CGI_TARGETS)
	rm -rf $(CGI_BIN)/Mojolicious
	rm -rf $(CGI_BIN)/public

$(CGI_DIR):
	mkdir $(CGI_DIR)

$(CGI_DIR)/%.cgi:	%.cgi
	$(INSTALL) $< $@
