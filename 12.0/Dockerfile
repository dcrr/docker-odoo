FROM debian:stretch
LABEL org.opencontainers.image.authors="dianacarolinarojas@gmail.com"

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG C.UTF-8

# Installing some dependencies
RUN set -x; \
        apt-get update \
        && apt-get install -y --no-install-recommends \
            ca-certificates \
            curl \
            dirmngr \
            fonts-noto-cjk \
            gnupg \
            libssl1.0-dev \
            node-less \
            python3-setuptools \
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
            # install wheel dependencies
            gcc \
            libpq-dev \
            python3-dev \
            python3-venv \
            python3-wheel \
            # install pyldap dependencies
            libsasl2-dev \
            libldap2-dev \
            git \
            # install latest postgresql-client
            postgresql-client \
			postgresql-client-common

# Installing wkhtmltopdf
RUN set -x; \
        curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.stretch_amd64.deb \
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

ENV ODOO_VERSION=12.0

# Add user and group odoo
RUN adduser --system --quiet --shell=/bin/bash --home=/home/odoo --gecos 'ODOO' --group odoo

# download odoo requirements.txt file and install python dependencies
RUN curl -SLo /tmp/requirements.txt https://raw.githubusercontent.com/odoo/odoo/${ODOO_VERSION}/requirements.txt \
   && pip3 install --no-cache-dir --ignore-installed -r /tmp/requirements.txt \
   && apt-get -y autoremove \
   && rm -Rf /var/lib/apt/lists/* /tmp/*

# Set environment variable with root path
ENV ODOO_PATH /home/odoo

# creating the directory structure for the Odoo installation
RUN mkdir -p ${ODOO_PATH}/src \
    && mkdir -p ${ODOO_PATH}/config \
    && mkdir -p ${ODOO_PATH}/data

# Set environment variable with src path
ENV ODOO_SRC ${ODOO_PATH}/src

RUN chown -R odoo ${ODOO_SRC} \
    && chown -R odoo ${ODOO_PATH}/config \
    && chown -R odoo ${ODOO_PATH}/data

# Copy Odoo configuration file
COPY ./odoo.conf ${ODOO_PATH}
# Set the default config file
ENV ODOO_CONF_FILE ${ODOO_PATH}/odoo.conf
RUN chown odoo ${ODOO_CONF_FILE}

# Copy entrypoint script
COPY ./entrypoint.sh /
RUN chmod 777 /entrypoint.sh 

# Expose odoo services
EXPOSE 8069 8071 8072
# Expose the debug port
EXPOSE 4000

ENTRYPOINT ["/entrypoint.sh"]

# Setting the default user when running the container
USER odoo

CMD ["odoo"]