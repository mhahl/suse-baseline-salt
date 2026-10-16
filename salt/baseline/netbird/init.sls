{# NetBird mesh-VPN client from the official NetBird RPM repository
   (install + daemon, no network join — `netbird up` needs an SSO login
   or a setup key, so joining stays manual).
   Repo facts (per https://docs.netbird.io/get-started/install/linux):
   baseurl https://pkgs.netbird.io/yum/ with gpgcheck=1 (key:
   .../yum/repodata/repomd.xml.key, fingerprint AA9C 09AA 9DEA 2F58
   112B 40DF DFFE AB2F D267 A61F, dev@netbird.io). Disabling removes
   the repo and stops the daemon but keeps already-installed packages,
   like the croniter providers in baseline.schedule.
   On Tumbleweed, zypper needs gpgautoimport for non-interactive repo
   refreshes. Fedora uses the repo's gpgkey and repo_gpgcheck instead. #}
{% set _family = grains.get('os_family', '') %}
{% set cfg = salt['pillar.get']('baseline:netbird', {}) %}
{% set enabled = cfg.get('enabled', True) %}
{% set repo_name = cfg.get('repo_name', 'netbird') %}
{% set repo_url = cfg.get('repo_url', 'https://pkgs.netbird.io/yum/') %}
{% set packages = cfg.get('packages', ['netbird']) %}
{% set enable_service = cfg.get('enable_service', True) %}

{% if enabled %}
{% if _family == 'Suse' %}
netbird_repo:
  pkgrepo.managed:
    - name: {{ repo_name }}
    - humanname: NetBird
    - baseurl: {{ repo_url }}
    - enabled: True
    - refresh: True
    - gpgkey: {{ repo_url }}repodata/repomd.xml.key
    - gpgcheck: 1
    - gpgautoimport: True
{% elif _family == 'RedHat' %}
netbird_repo:
  pkgrepo.managed:
    - name: {{ repo_name }}
    - humanname: NetBird
    - baseurl: {{ repo_url }}
    - enabled: True
    - refresh: True
    - gpgkey: {{ repo_url }}repodata/repomd.xml.key
    - gpgcheck: 1
    - repo_gpgcheck: 1
{% endif %}

netbird_client:
  pkg.installed:
    - pkgs:
{% for pkg in packages %}
      - {{ pkg }}
{% endfor %}
    - fromrepo: {{ repo_name }}
{% if _family == 'Suse' %}
    - gpgautoimport: True
{% endif %}
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
