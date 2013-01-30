
# You MUST set these paths if they matter (depends on what you are installing)

# Where is the analysis web site ???
CGI_DIR		:=	/var/www/html/rpzla

# Where should perl libraries be installed
PERL_DIR	:=	/var/www/html/rpzla

# The rest just works ...

NAME		:=	RPZLA

all:    
	@@echo 'Edit this Makefile and set CGI_DIR and PERL_DIR; then ...'
	@@echo 'choose between data loggers (make bind or make apache)'
	@@echo 'or web site (make web)'
	@@echo 'then choose to make etc if you want the config overwritten'

# Smash the config
etc:
	$(MAKE) -C etc install

# Logger executables
logger:	
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
