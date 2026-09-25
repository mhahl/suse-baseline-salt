{# NetBird mesh-VPN client from the official NetBird RPM repository
   (install + daemon, no network join — `netbird up` needs an SSO login
   or a setup key, so joining stays manual).
   Repo facts (per https://docs.netbird.io/get-started/install/linux):
   baseurl https://pkgs.netbird.io/yum/ with gpgcheck=1 (key:
   .../yum/repodata/repomd.xml.key, fingerprint AA9C 09AA 9DEA 2F58
   112B 40DF DFFE AB2F D267 A61F, dev@netbird.io). Disabling removes
   the repo and stops the daemon but keeps already-installed packages,
   like the croniter providers in baseline.schedule.
   zypper prompts to trust a new/rotated signing key interactively and
   fails non-interactive refreshes until it is trusted, so both states
   below pass gpgautoimport (zypper's own --gpg-auto-import-keys):
   same trust level as a manual rpm --import, verified against Salt's
   zypper module (mod_repo/refresh_db honor it, and pkg.installed
   forwards it to the resolve_capabilities refresh). #}
{% set cfg = salt['pillar.get']('baseline:netbird', {}) %}
{% set enabled = cfg.get('enabled', True) %}
{% set repo_name = cfg.get('repo_name', 'netbird') %}
{% set repo_url = cfg.get('repo_url', 'https://pkgs.netbird.io/yum/') %}
{% set packages = cfg.get('packages', ['netbird']) %}
{% set enable_service = cfg.get('enable_service', True) %}

{% if enabled %}
netbird_repo:
  pkgrepo.managed:
    - name: {{ repo_name }}
    - humanname: NetBird
    - baseurl: {{ repo_url }}
    - enabled: True
    - refresh: True
    - gpgcheck: 1
    - gpgautoimport: True

netbird_client:
  pkg.installed:
    - pkgs:
{% for pkg in packages %}
      - {{ pkg }}
{% endfor %}
    - fromrepo: {{ repo_name }}
    - gpgautoimport: True
    - require:
      - pkgrepo: netbird_repo

{% if enable_service %}
netbird_service:
  service.running:
    - name: netbird
    - enable: True
    - require:
      - pkg: netbird_client
{% else %}
netbird_service:
  service.disabled:
    - name: netbird
{% endif %}
{% else %}
netbird_repo:
  pkgrepo.absent:
    - name: {{ repo_name }}

netbird_service:
  service.dead:
    - name: netbird
    - enable: False
{% endif %}
