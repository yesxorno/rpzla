
NAME		:=	RPZLA
export BASE	:=	$(NAME)

LIB_DIR		:=	$(PERL_DIR)/$(NAME)

all:		install

install:	\
		$(LIB_DIR)
	$(MAKE) -C Scraper $@
	$(MAKE) -C Analysis $@
	

clean:		
	@echo "You mean clobber"

clobber:
	$(MAKE) -C Scraper $@
	rm -f $(LIB_TARGETS)
	rmdir $(LIB_DIR)

$(LIB_DIR):	$(PERL_DIR)
	mkdir -p $(LIB_DIR)

