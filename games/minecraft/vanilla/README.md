# LoganMinecraftServer

Setup Server
===
  1. (Optional) Download existing server data using 
  
    ./download_server.sh -port [#] user@hostname:/path/to/source_directory

  2. Setup SSH connection. Run:

    ./setup_ssh_infra.sh -h <host> -u <user> [-i <ip>] [-d infra/ssh] [--accept-new]

  3. Copy and rename .env.template to .env and fill out with your server data.

  4. Run:

    docker compose up

   (Optional) Run docker container as proxy to seperate server run:

    docker compose -f docker-compose-pxy.yml up

Commit Rules
===
  - Do not commit sensitive data like keys, ips, etc.
  - Scripts > hardcoded shit
  - Data files will not be put in git repo (for now hard copy)

Helpful Commands
===
  - backup on demand:
    - sudo docker compose exec backups backup now

