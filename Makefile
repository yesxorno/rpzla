
NAME		:=	RPZLA

all:    
	@@echo 'choose between data loggers (make bind or make apache)'
	@@echo 'or web site (make web)'
	@@echo 'then choose to make etc if you want the config overwritten'

# Smash the config
etc:
	$(MAKE) -C etc install

# Logger libraries
lib:
	$(MAKE) -C lib install

# Logger executables
logger:	lib
	$(MAKE) -C bin install

# And their sys-v service scripts
bind:	logger
	$(MAKE) -C init.d/sys-v bind

apache:	logger
	$(MAKE) -C init.d/sys-v apache

# Web is its own thing
web:	.dummy
	@echo 'cd web/analyse ; vi Makefile # set CGI_DIR ; make install'

.dummy:
