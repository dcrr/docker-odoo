FROM debian:stretch

SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG C.UTF-8

# Debian repositories as of August 13, 2023
RUN sed -i -e 's/deb.debian.org/archive.debian.org/g' \
    -e 's|security.debian.org|archive.debian.org/|g' \
    -e '/stretch-updates/d' /etc/apt/sources.list


# Installing some dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    dirmngr \
    fonts-noto-cjk \
    gnupg \
    libssl1.0-dev \
    node-less \
    python3-pip \
    python3-pyldap \
    python3-qrcode \
    python3-renderpm \
    python3-setuptools \
    python3-slugify \
    python3-vobject \
    python3-watchdog \
    python3-xlrd \
    xz-utils \
    postgresql-client \
    postgresql-client-common \
    git

ENV WKHTMLTOX_X64 https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.stretch_amd64.deb
RUN set -x; \
    curl -o wkhtmltox.deb -sSL  ${WKHTMLTOX_X64} \
    && echo '7e35a63f9db14f93ec7feeb0fce76b30c08f2057 wkhtmltox.deb' | sha1sum -c - \
    && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
    && rm -rf /var/lib/apt/lists/* wkhtmltox.deb

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

# install psutil and pyldap dependencies
RUN apt-get update && apt-get install --no-install-recommends -y \
    gcc \
    libpq-dev \
    python3-dev \
    python3-venv \
    python3-wheel \
    libsasl2-dev \
    libldap2-dev \
    libssl-dev


ENV ODOO_VERSION=12.0
# download odoo requirements.txt file and install python dependencies
RUN curl -SLo /tmp/requirements.txt https://raw.githubusercontent.com/odoo/odoo/${ODOO_VERSION}/requirements.txt \
   && pip3 install --no-cache-dir --ignore-installed -r /tmp/requirements.txt \
   && apt-get -y autoremove \
   && rm -Rf /var/lib/apt/lists/* /tmp/*


# Add user and group odoo
# allow setting ODOO uid/gid at build time
ARG ODOO_UID=1000
ARG ODOO_GID=1000
# Add user and group odoo with specific uid/gid
RUN addgroup --gid ${ODOO_GID} odoo \
 && adduser --system --uid ${ODOO_UID} --gid ${ODOO_GID} --shell=/bin/bash --home=/home/odoo --gecos 'ODOO' odoo

# Set environment variable with root path
ENV ODOO_PATH /home/odoo

WORKDIR ${ODOO_PATH}

# creating the directory structure for the Odoo installation
RUN mkdir -p src \
    && mkdir -p config \
    && mkdir -p data

# Set environment variable with src path
ENV ODOO_SRC ${ODOO_PATH}/src

# Copy entrypoint script
COPY ./entrypoint.sh .

# Copy Odoo configuration file
COPY ./odoo.conf ${ODOO_PATH}

# Set the default config file
ENV ODOO_CONF_FILE ${ODOO_PATH}/odoo.conf
RUN chown ${ODOO_UID}:${ODOO_GID} ${ODOO_CONF_FILE}

# Expose odoo services
EXPOSE 8069 8071 8072
# Expose the debug port
EXPOSE 4000

ENTRYPOINT ["./entrypoint.sh"]


CMD ["odoo"]
