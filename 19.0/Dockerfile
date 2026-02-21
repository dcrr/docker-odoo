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
        python3-magic \
        python3-num2words \
        python3-odf \
        python3-pdfminer \
        python3-venv \
        python3-pip \
        python3-phonenumbers \
        python3-pyldap \
        python3-qrcode \
        python3-renderpm \
        python3-setuptools \
        python3-slugify \
        python3-vobject \
        python3-watchdog \
        python3-xlrd \
        python3-xlwt \
        postgresql-client \
        wkhtmltopdf \
        tini \
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

ENV ODOO_VERSION=19.0

# COPY requirements.txt /tmp/requirements.txt

# RUN grep -v "^psycopg2" /tmp/requirements.txt > /tmp/requirements-filtered.txt \
#     && python3 -m pip install --break-system-packages --no-cache-dir -r /tmp/requirements-filtered.txt \
#     && python3 -m pip install --break-system-packages --no-cache-dir "psycopg2-binary>=2.9" \
#     && rm -Rf /var/lib/apt/lists/* /tmp/*


RUN curl -SLo /tmp/requirements.txt \
        https://raw.githubusercontent.com/odoo/odoo/${ODOO_VERSION}/requirements.txt 


RUN grep -v "^cbor2\|^psycopg2" /tmp/requirements.txt > /tmp/requirements-filtered.txt \
    && python3 -m pip install --break-system-packages --no-cache-dir -r /tmp/requirements-filtered.txt \
    && python3 -m pip install --break-system-packages --no-cache-dir "cbor2>=5.5.0" \
    && python3 -m pip install --break-system-packages --no-cache-dir "psycopg2-binary>=2.9" \
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
ENTRYPOINT ["./entrypoint.sh"]

CMD ["odoo"]
