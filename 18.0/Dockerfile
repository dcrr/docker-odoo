FROM debian:bookworm
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG=C.UTF-8

# Retrieve the target architecture to install the correct wkhtmltopdf package
ARG TARGETARCH

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dirmngr \
        fonts-noto-cjk \
        git \
        gnupg \
        libssl-dev \
        node-less \
        npm \
        python3-dev \
        python3-venv \
        postgresql-client \
        wkhtmltopdf \
        xz-utils \
        build-essential \
        libxml2-dev \
        libxslt1-dev \
        zlib1g-dev \
        libjpeg-dev \
        libfreetype6-dev \
        libsasl2-dev \
        libldap2-dev \
    && rm -rf /var/lib/apt/lists/*

# Install rtlcss (on Debian buster)
RUN npm install -g rtlcss

ENV ODOO_VERSION=18.0

# Add user and group odoo
ARG ODOO_UID=1000
ARG ODOO_GID=1000
RUN addgroup --gid ${ODOO_GID} odoo \
 && adduser --system --uid ${ODOO_UID} --gid ${ODOO_GID} --shell=/bin/bash --home=/home/odoo --gecos 'ODOO' odoo

# Set environment variables
ENV ODOO_PATH=/home/odoo
ENV ODOO_SRC=${ODOO_PATH}/src
ENV ODOO_CONF_FILE=${ODOO_PATH}/config/odoo.conf
ENV VENV_PATH=${ODOO_PATH}/config/venv

WORKDIR ${ODOO_PATH}

# Create directory structure
RUN mkdir -p src config data .local/bin \
    && chown -R ${ODOO_UID}:${ODOO_GID} ${ODOO_PATH}

# Copy and configure entrypoint
COPY ./requirements.txt .
RUN chmod +x ./requirements.txt

# Copy and configure entrypoint
COPY ./entrypoint.sh .
RUN chmod +x ./entrypoint.sh

# Copy Odoo configuration file
COPY ./odoo.conf ${ODOO_CONF_FILE}
RUN chown ${ODOO_UID}:${ODOO_GID} ${ODOO_CONF_FILE}

# Expose ports
EXPOSE 8069 8071 8072 4000

USER odoo

ENTRYPOINT ["./entrypoint.sh"]

CMD ["odoo"]
