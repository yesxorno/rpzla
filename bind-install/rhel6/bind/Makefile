
VERSION		:=	9.9.0
BIND_SOURCE	:= 	bind-$(VERSION).tar.gz
SOURCE_ROOT	:=	bind-$(VERSION)

PREFIX		:=	/usr/local
# Simplistic target definition
NAMED		:=	$(PREFIX)/sbin/named

# We wish to generate the rndc.key
RNDC_KEY	:=	$(PREFIX)/etc/rndc.key
RNDC_GEN	:=	$(PREFIX)/sbin/rndc-confgen

# ------------------------
#  # Targets
# ------------------------

all:		$(NAMED) $(RNDC_KEY)

$(RNDC_KEY):	$(RNDC_GEN)
	$(RNDC_GEN) -a

$(NAMED):	$(SOURCE_ROOT)
	( cd $(SOURCE_ROOT) && ./configure --prefix=$(PREFIX) )
	$(MAKE) -C $(SOURCE_ROOT) all test install
	( cd $(SOURCE_ROOT) && ./bin/tests/system/ifconfig.sh up )
	$(MAKE) -C $(SOURCE_ROOT) test 
	$(MAKE) -C $(SOURCE_ROOT) install

$(SOURCE_ROOT):	$(BIND_SOURCE)
	tar xzf $(BIND_SOURCE)

$(BIND_SOURCE):	
	wget ftp://ftp.isc.org/isc/bind9/$(VERSION)/$(BIND_SOURCE)

