#!/bin/bash

# Make sur ewe have the latest code installed
curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/install.sh | sudo bash

# Navigate to the correct directory
cd /srv/lxc-compose/library

# For each base image:
# Alpine 3.19
cd cd /srv/lxc-compose/library/alpine/3.19

# Debian 11
cd cd /srv/lxc-compose/library/debian/11

# Debian 12
cd cd /srv/lxc-compose/library/debian/12

# Ubuntu 22.04
cd cd /srv/lxc-compose/library/ubuntu/22.04

# Ubuntu 24.04
cd cd /srv/lxc-compose/library/ubuntu/24.04

# Ubuntu Minimal 22.04
cd cd /srv/lxc-compose/library/ubuntu-minimal/22.04

# Ubuntu Minimal 24.04
cd cd /srv/lxc-compose/library/ubuntu-minimal/24.04