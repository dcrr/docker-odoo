# Odoo Docker

## Docker image for Odoo

This image allows you _**to mount the necessary directories to maintain Odoo's configuration, source code and data such as `sessions`and `filestore` on the host, and run it from the container**_. When you create the container, the Odoo source code is downloaded from its official repository to one of the mounted directories.

## Instructions

#### Create a Docker subnet
Create the Docker network where the Postgresql and Odoo containers will be located.

```
$ docker network create --subnet=172.19.0.0/16 network_name
```

#### Create a PostgreSQL Container

Create the postgres container that Odoo will use. From a terminal:

1. Navigate to the directory where you prefer to keep the container data. For example:

    ```
    $ cd /home/user_name
    ```

2. Create the root folder of your container and then inside it, the `data` and `share` folders, which will be used to persistently store data and in case you need to share any files from the host with the container.

    ```
    $ mkdir postgres
    $ cd postgres
    $ mkdir data
    $ mkdir share
    ```

3. Create the container by running the following command:

    ```
    $ docker run --name pg_container_name -e POSTGRES_USER=pg_user -e POSTGRES_PASSWORD=pg_password -p 5432:5432 --restart=always --network network_name --ip 172.19.0.2 -v ./data:/var/lib/postgresql/data -v ./share:/home/share -d postgres:12-alpine
    ```

    * `-e POSTGRES_USER=pg_user` set the environment variable with the database user. Replace `pg_user` with the corresponding user.
    * `-e POSTGRES_PASSWORD=pg_password` set the environment variable with the database user's password. Replace `pg_password` with the corresponding password.
    * `--restart=always` when the host starts, the container starts automatically.
    * `--network network_name --ip 172.19.0.2` assign it a static IP address within the created Docker subnet.
    * `-v ./data:/var/lib/postgresql/data` mount a volume to maintain persistent data.
    * `-v ./share:/home/share` mount a volume to share files from the host to the container


### Create the Odoo container

From a terminal:

1. Navigate to the directory where you prefer to keep the container data. For example:

    ```
    $ cd /home/user_name
    ```

2. Create the root folder of your container and then inside it, the `src`, `config`, and `data` folders.
    ```
    $ mkdir odoo
    $ cd odoo
    $ mkdir src
    $ mkdir config
    $ mkdir data
    ```
    __**NOTA:**__ _You must create these folders with the host user (not root) so that, when creating the container, it can download the sources and write to the filestore._

    If you want to install custom or third-party modules, add a folder inside `src`, copy the repositories or folders containing the custom modules into it. For example:

    ```
    $ cd src/
    $ mkdir extra_addons
    $ cd extra_addons
    $ cp -R /directory/custom_modules .
    ```

    And then add the `odoo.conf` file to the `config` folder with the corresponding paths in the addons_path. For example:

    ```
    addons_path=/home/odoo/data/addons/12.0,/home/odoo/src/odoo/odoo/addons,/home/odoo/src/odoo/addons,/home/odoo/src/extra_addons/custom_modules
    data_dir=/home/odoo/data
    ```

2. Create your `docker-compose.yml` file. You can use the `docker-compose.example.yml` template, replacing the IP address and subnet name with the ones you created.
3. Create your `.env` file. You can use the `.env.example.yml` template, replacing the variable values ​​with the corresponding values ​​set when creating the PostgreSQL container.
4. Create the container from a terminal by running the following command:
    
    ```
    $ docker compose up
    ```
    The official Odoo repository will be cloned to the `src` folder created in step 1.

5. To access Odoo, open http://localhost:8069 in your browser.

