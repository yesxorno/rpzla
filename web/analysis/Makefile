
CGI_DIR		:=	/var/www/html/rpzla

LIB_DIR		:=	../../lib/

export CGI_DIR	:=	$(CGI_DIR)

CGI_SRCS	:=	\
			rpzla.cgi

CGI_TARGETS	:=	$(CGI_SRCS:%=$(CGI_DIR)/%)

TEMPLATE_DIR	:=	./templates

INSTALL		:=	install -m 755

# ------------------------
# Targets
# ------------------------

all:		install templates analysis

install:	$(CGI_DIR) $(CGI_TARGETS)
	cp -r Mojolicious public $(CGI_DIR)
	@echo "use make install-config if you wish to do that"

templates: .dummy
	$(MAKE) -C $(TEMPLATE_DIR)

analysis:
	$(MAKE) -C $(LIB_DIR) $@

install-config:
	cp ../../etc/rpzla.conf $(CGI_DIR)

clobber:
	rm -f $(CGI_TARGETS)
	rm -rf $(CGI_BIN)/Mojolicious
	rm -rf $(CGI_BIN)/public

$(CGI_DIR):
	mkdir $(CGI_DIR)

$(CGI_DIR)/%.cgi:	%.cgi
	$(INSTALL) $< $@

.dummy:
