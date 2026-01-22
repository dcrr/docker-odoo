FROM debian:stretch

SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG=C.UTF-8

# Debian repositories as of August 13, 2023
RUN sed -i -e 's/deb.debian.org/archive.debian.org/g' \
    -e 's|security.debian.org|archive.debian.org/|g' \
    -e '/stretch-updates/d' /etc/apt/sources.list

# Installing base dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    dirmngr \
    fonts-noto-cjk \
    gnupg \
    libssl1.0-dev \
    node-less \
    gcc \
    libpq-dev \
    libsasl2-dev \
    libldap2-dev \
    xz-utils \
    postgresql-client \
    postgresql-client-common \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install tini for proper signal handling
RUN curl -Lo /usr/bin/tini https://github.com/krallin/tini/releases/download/v0.19.0/tini-static-amd64 \
    && chmod +x /usr/bin/tini

# Build and install Python 3.8 from source
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        libbz2-dev \
        libreadline-dev \
        libsqlite3-dev \
        libssl-dev \
        libffi-dev \
        libncurses5-dev \
        libncursesw5-dev \
        liblzma-dev \
        tk-dev \
        uuid-dev \
        zlib1g-dev; \
    PYTHON_VERSION=3.8.16; \
    curl -fsSL "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz" -o /tmp/Python.tgz; \
    mkdir -p /tmp/python-build; \
    tar -xzf /tmp/Python.tgz -C /tmp/python-build --strip-components=1; \
    cd /tmp/python-build; \
    ./configure \
        --enable-optimizations \
        --enable-shared \
        --with-ensurepip=install \
        --prefix=/usr/local \
        LDFLAGS="-Wl,-rpath /usr/local/lib"; \
    make -j"$(nproc)"; \
    make altinstall; \
    ln -sf /usr/local/bin/python3.8 /usr/local/bin/python3; \
    ln -sf /usr/local/bin/python3.8 /usr/local/bin/python; \
    ln -sf /usr/local/bin/pip3.8 /usr/local/bin/pip3; \
    ln -sf /usr/local/bin/pip3.8 /usr/local/bin/pip; \
    python3 --version; \
    pip3 --version; \
    cd /; \
    rm -rf /tmp/python-build /tmp/Python.tgz; \
    rm -rf /var/lib/apt/lists/*

# Install wkhtmltopdf
ENV WKHTMLTOX_X64=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.stretch_amd64.deb
RUN set -x; \
    curl -o wkhtmltox.deb -sSL ${WKHTMLTOX_X64} \
    && echo '7e35a63f9db14f93ec7feeb0fce76b30c08f2057 wkhtmltox.deb' | sha1sum -c - \
    && dpkg -i wkhtmltox.deb || true \
    && apt-get update \
    && apt-get install -y --no-install-recommends -f \
    && rm -rf /var/lib/apt/lists/* wkhtmltox.deb

# Install Node.js 8.x
RUN echo "deb http://deb.nodesource.com/node_8.x stretch main" > /etc/apt/sources.list.d/nodesource.list \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && repokey='9FD3B784BC1C6FC31A8A0A1C1655A0AB68576280' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/nodejs.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update \
    && apt-get install --no-install-recommends -y nodejs \
    && npm install -g rtlcss \
    && rm -rf /var/lib/apt/lists/*

ENV ODOO_VERSION=12.0

# Install Odoo Python dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        libxml2-dev \
        libxslt1-dev \
        zlib1g-dev \
        libjpeg-dev \
        libfreetype6-dev \
    && curl -SLo /tmp/requirements.txt https://raw.githubusercontent.com/odoo/odoo/${ODOO_VERSION}/requirements.txt \
    && python3 -m pip install --upgrade pip \
    && python3 -m pip install "setuptools<58" wheel \
    && python3 -m pip install --no-cache-dir -r /tmp/requirements.txt \
    && rm -Rf /var/lib/apt/lists/* /tmp/*

# Add user and group odoo
ARG ODOO_UID=1000
ARG ODOO_GID=1000
RUN addgroup --gid ${ODOO_GID} odoo \
 && adduser --system --uid ${ODOO_UID} --gid ${ODOO_GID} --shell=/bin/bash --home=/home/odoo --gecos 'ODOO' odoo

# Set environment variables
ENV ODOO_PATH=/home/odoo
ENV ODOO_SRC=${ODOO_PATH}/src
ENV ODOO_CONF_FILE=${ODOO_PATH}/odoo.conf

WORKDIR ${ODOO_PATH}

# Create directory structure
RUN mkdir -p src config data

# Copy and configure entrypoint
COPY ./entrypoint.sh .
RUN chmod +x ./entrypoint.sh

# Copy Odoo configuration file
COPY ./odoo.conf ${ODOO_PATH}/
RUN chown ${ODOO_UID}:${ODOO_GID} ${ODOO_CONF_FILE}

# Expose ports
EXPOSE 8069 8071 8072 4000

# Use tini for proper signal handling
ENTRYPOINT ["/usr/bin/tini", "--", "./entrypoint.sh"]

CMD ["odoo"]
