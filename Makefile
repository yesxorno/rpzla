
NAME		:=	RPZLA

all:	
	@@echo 'choose between data loggers (make logger) or web site (make web)'

logger:	
	$(MAKE) -C etc install
	$(MAKE) -C bin install

bind:	logger
	$(MAKE) -C init.d/sys-v bind

apache:	logger
	$(MAKE) -C init.d/sys-v apache

web:	.dummy
	@echo 'cd web/analyse ; vi Makefile # set CGI_DIR ; make install'

.dummy:
