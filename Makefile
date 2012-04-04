
NAME		:=	RPZLA

all:	
	@@echo 'choose between data loggers (make logger) or web site (make web)'

logger:	
	$(MAKE) -C etc install
	$(MAKE) -C bin install

web:	.dummy
	@echo 'cd web/analyse ; vi Makefile # set CGI_DIR ; make install'

.dummy:
