# Odoo Docker

## Docker image for Odoo

This image allows you _**to mount the necessary directories to maintain Odoo's configuration, source code and data such as `sessions`and `filestore` on the host, and run it from the container**_. When you create the container, the Odoo source code is downloaded from its official repository to one of the mounted directories.

## Instructions

#### Create a Docker subnet

```
$ docker network create --subnet=172.19.0.0/16 network_name
```

#### Create a Postgresql Container

Create the postgres container that Odoo will use. 

Navigate to the directory where you prefer to keep the container data and follow the steps below:

1. Create the `data` and `share` folders, which will be used to keep the data persistent and in case you need to share any file from the host with the container.

2. From a terminal, located in the same directory, create the container by running the following command:

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

Navigate to the directory where you prefer to keep the container data and follow the steps below:

1. Create the `src`, `config`, and `data` folders and leave them empty.
2. Create your `docker-compose.yml` file. You can use the `docker-compose.example.yml` template, replacing the IP address and subnet name with the ones you created.
3. Create your `.env` file. You can use the `.env.example.yml` template, replacing the `DB_HOST` value with the name of the created Postgres container, `DB_USER` with the database user, and `DB_PASSWORD` with the password for that same user.
4. Create the container from a terminal by running the following command:
    
    ```
    $ docker compose up
    ```
    The official Odoo repository will be cloned to the `src` folder created in step 1.

5. Finally, to access Odoo, open http://localhost:8069 in your browser.
