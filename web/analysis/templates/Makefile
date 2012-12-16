

TPL_DIR		:=	$(CGI_DIR)/templates

TPL_SRCS	:=	$(shell ls *.ep)

TPL_TARGETS	:=	$(TPL_SRCS:%=$(TPL_DIR)/%)

INSTALL		:=	install -m 644

# ------------------------
# Targets
# ------------------------

all:		install

install:	$(TPL_DIR) $(TPL_TARGETS)

clobber:
	rm -f $(TPL_TARGETS)
	rmdri $(TPL_DIR)

templates:
	$(MAKE) -C $(TEMPLATE_DIR)

$(TPL_DIR):
	mkdir $(TPL_DIR)

$(TPL_DIR)/%.ep:	%.ep
	$(INSTALL) $< $@
