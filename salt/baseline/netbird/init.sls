{# NetBird mesh-VPN client from the official NetBird RPM repository
   (install + daemon, opt-in network join via setup key).
   Repo facts (per https://docs.netbird.io/get-started/install/linux):
   baseurl https://pkgs.netbird.io/yum/ with gpgcheck=1 (key:
   .../yum/repodata/repomd.xml.key, fingerprint AA9C 09AA 9DEA 2F58
   112B 40DF DFFE AB2F D267 A61F, dev@netbird.io). Disabling removes
   the repo and stops the daemon but keeps already-installed packages,
   like the croniter providers in baseline.schedule.
   On Tumbleweed, zypper needs gpgautoimport for non-interactive repo
   refreshes. Fedora uses the repo's gpgkey and repo_gpgcheck instead.
   Join is opt-in via baseline:netbird:join:enabled + setup_key (store
   the key in encrypted pillar — GPG/sops/Vault — never plaintext).
   The key is passed via env (NB_SETUP_KEY) with hide_output + quiet
   logs so it never appears in the state name or Overstate job output.
   Idempotent: skipped when `netbird status` already reports connected. #}
{% set _family = grains.get('os_family', '') %}
{% set cfg = salt['pillar.get']('baseline:netbird', {}) %}
{% set enabled = cfg.get('enabled', True) %}
{% set repo_name = cfg.get('repo_name', 'netbird') %}
{% set repo_url = cfg.get('repo_url', 'https://pkgs.netbird.io/yum/') %}
{% set packages = cfg.get('packages', ['netbird']) %}
{% set enable_service = cfg.get('enable_service', True) %}
{% set join_cfg = cfg.get('join', {}) %}
{% set join_enabled = join_cfg.get('enabled', False) %}
{% set setup_key = join_cfg.get('setup_key', '') %}
{% set join_hostname = join_cfg.get('hostname', '') %}
{% set management_url = join_cfg.get('management_url', '') %}
{% set extra_args = join_cfg.get('extra_args', '') %}

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

{% if join_enabled %}
{% if not setup_key %}
netbird_join_missing_key:
  test.fail_without_changes:
    - name: baseline:netbird:join:setup_key is required when join.enabled is True (store in encrypted pillar)
{% else %}
netbird_join:
  cmd.run:
    - name: netbird up --setup-key "$NB_SETUP_KEY"{% if join_hostname %} --hostname {{ join_hostname }}{% endif %}{% if management_url %} --management-url {{ management_url }}{% endif %}{% if extra_args %} {{ extra_args }}{% endif %}
    - env:
      - NB_SETUP_KEY: {{ setup_key }}
    - unless: netbird status 2>/dev/null | grep -qi connected
    - onlyif: command -v netbird >/dev/null 2>&1
    - hide_output: True
    - output_loglevel: quiet
    - timeout: 300
    - require:
      - pkg: netbird_client
{% if enable_service %}
      - service: netbird_service
{% endif %}
{% endif %}
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
