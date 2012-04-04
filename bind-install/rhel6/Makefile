
NAME            :=      BIND-BUILD

all:	bind service
	@echo You can also make etc, rpz and zone-data.  Careful

bind:	.dummy
	$(MAKE) -C bind all

service:	.dummy
	$(MAKE) -C service install

etc:	.dummy
	$(MAKE) -C etc install

rpz:	.dummy
	$(MAKE) -C rpz install

zone-data:	.dummy
	$(MAKE) -C zone-data install

.dummy:
