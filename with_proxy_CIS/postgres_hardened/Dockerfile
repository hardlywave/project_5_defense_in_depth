FROM postgres:16

RUN apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ansible \
	&& rm -rf /var/lib/apt/lists/*

COPY postgres_hardened/hardening/ /opt/postgres_hardening/

RUN ansible-playbook /opt/postgres_hardening/playbook.yml
