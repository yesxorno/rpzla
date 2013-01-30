
PERL_BASE	:=	/usr/share/perl5
# PERL_BASE	:=	/usr/lib/perl5/vendor_perl
export PERL_DIR	:=	$(PERL_BASE)

all:
	@@echo choose analysis or scraper, different libs for different things

scraper:
	$(MAKE) -C RPZLA scraper

analysis:
	$(MAKE) -C RPZLA analysis

clobber:
	$(MAKE) -C RPZLA $@
