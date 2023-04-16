#!/bin/sh
main() {
  ./kiosk-install-ibus.sh
  ./kiosk-install-chromium.sh
  ./kiosk-setup-service.sh
}

main