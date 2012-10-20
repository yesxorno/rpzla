
NAME		:=	Scraper
INSTALL		:=	install -m 644
LIB_DIR		:=	$(PERL_DIR)/$(BASE)/$(NAME)
LIB_SRCS	:=	$(shell ls *.pm *.pod)

LIB_TARGETS	:=	$(LIB_SRCS:%=$(LIB_DIR)/%)

all:		install

install:	\
		$(LIB_DIR)		\
		$(LIB_TARGETS)

clean:		
	@echo "You mean clobber"

clobber:	
	rm -f $(LIB_TARGETS)
	rmdir $(LIB_DIR)

$(LIB_DIR):	$(PERL_DIR)
	mkdir -p $(LIB_DIR)

$(LIB_DIR)/%:	%
	$(INSTALL) $< $@
