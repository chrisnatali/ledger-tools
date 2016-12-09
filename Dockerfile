# Debian image with ledger installed
FROM debian:jessie
MAINTAINER Christian Natali

# install ledger dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    autopoint \
    texinfo python-dev \
    zlib1g-dev \
    libbz2-dev \
    libgmp3-dev \
    gettext \
    libmpfr-dev \
    libboost-date-time-dev \
    libboost-filesystem-dev \
    libboost-graph-dev \
    libboost-iostreams-dev \
    libboost-python-dev \
    libboost-regex-dev \
    libboost-test-dev

# install ledger from source and cleanup afterward
ADD https://github.com/ledger/ledger/archive/v3.1.1.tar.gz /tmp
RUN cd /tmp && \
      tar -xzf v3.1.1.tar.gz && \
      cd ledger-3.1.1 && \
      ./acprep update && \
      make check && \
      make install
#      make install && \
#      cd .. && \
#      rm -rf ledger-3.1.1 && \
#      rm -f v3.1.1.tar.gz
#
