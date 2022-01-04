THISDIR := $(shell pwd)
MOSDNS_VER := 3.0.0
MOSDNS_URL_BASE := https://github.com/IrineSistiana/mosdns/releases/download


MOSDNS_NAME := mosdns-linux-mipsle-softfloat
MOSDNS_URL := $(MOSDNS_URL_BASE)/v$(MOSDNS_VER)/$(MOSDNS_NAME).zip

all: download_test extra_test
	@echo "mosdns build done!"

download_test:
	( if [ ! -f $(MOSDNS_NAME).zip ]; then \
		wget -t5 --timeout=20 --no-check-certificate -O $(MOSDNS_NAME).zip $(MOSDNS_URL); \
	fi )

extra_test:
	( if [ ! -d $(MOSDNS_NAME) ]; then \
		unzip -d $(MOSDNS_NAME) $(MOSDNS_NAME).zip; \
	fi )

clean:
	rm -rf $(MOSDNS_NAME).zip $(MOSDNS_NAME)

romfs:
ifeq ($(CONFIG_FIRMWARE_INCLUDE_MOSDNS),y)
	$(ROMFSINST) -p +x $(THISDIR)/$(MOSDNS_NAME)/mosdns /usr/bin/mosdns
	$(ROMFSINST) -p +x $(THISDIR)/mosdns.sh /usr/bin/mosdns.sh
	$(ROMFSINST) $(THISDIR)/cert.pem /etc_ro/cert.pem
endif
