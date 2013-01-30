
NAME		:=	RPZLA
export BASE	:=	$(NAME)

LIB_DIR		:=	$(PERL_DIR)/$(NAME)

all:
	@@echo choose analysis or scraper, different libs for different things

scraper:	$(LIB_DIR)
	$(MAKE) -C Scraper install

analysis:	$(LIB_DIR)
	$(MAKE) -C Analysis install
	

clean:		
	@echo "You mean clobber"

clobber:
	$(MAKE) -C Scraper $@
	$(MAKE) -C Analysis $@
	rm -f $(LIB_TARGETS)
	rmdir $(LIB_DIR)

$(LIB_DIR):	$(PERL_DIR)
	mkdir -p $(LIB_DIR)

