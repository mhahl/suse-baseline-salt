{# FreeIPA client from the OBS security:idm project (install + opt-in join).
   Domain enrollment via ipa-client-install with a service-account
   principal + password (encrypted pillar — GPG/sops/Vault — never
   plaintext). Disabled by default: install-only when join.enabled is
   False. Join is idempotent (skipped when /etc/ipa/default.conf
   exists); re-joining requires manual `ipa-client-install --uninstall`.
   Passes --no-ntp by default so systemd-timesyncd stays the only NTP
   client. Secrets go via env (IPA_JOIN_PASSWORD) with hide_output +
   quiet logs, never in the state name.
   Repo metadata (verified against the published .repo file):
   baseurl https://download.opensuse.org/repositories/security:/idm/openSUSE_Tumbleweed/
   with gpgcheck=1 (key: .../repodata/repomd.xml.key, currently the
   shared "security OBS Project" key). Disabling removes the repo but
   keeps already-installed packages, like the croniter providers in
   baseline.schedule.
   On Tumbleweed, zypper prompts to trust rotated keys, so both states
   pass gpgautoimport (zypper's --gpg-auto-import-keys). Fedora installs
   from base repos and does not use those zypper options.
   FreeBSD: NOT supported by this baseline (no client enrollment; the
   identity story there is local accounts — see README). Skipped, not
   failed, so highstate stays green on FreeBSD hosts. #}
{% set _family = grains.get('os_family', '') %}
{% if _family == 'FreeBSD' %}
freebsd_freeipa_skipped:
  test.skip_sls:
    - name: baseline.freeipa unsupported on FreeBSD; skipped
{% else %}
{% set cfg = salt['pillar.get']('baseline:freeipa', {}) %}
{% set enabled = cfg.get('enabled', True) %}
{% set repo_name = cfg.get('repo_name', 'security:idm') %}
{% set repo_url = cfg.get('repo_url', 'https://download.opensuse.org/repositories/security:/idm/openSUSE_Tumbleweed/') %}
{% set packages = cfg.get('packages', ['freeipa-client']) %}
{% set join_cfg = cfg.get('join', {}) %}
{% set join_enabled = join_cfg.get('enabled', False) %}
{% set domain = join_cfg.get('domain', '') %}
{% set realm = join_cfg.get('realm', '') or (domain.upper() if domain else '') %}
{% set server = join_cfg.get('server', '') %}
{% set principal = join_cfg.get('principal', '') %}
{% set password = join_cfg.get('password', '') %}
{% set mkhomedir = join_cfg.get('mkhomedir', True) %}
{% set no_ntp = join_cfg.get('no_ntp', True) %}
{% set extra_args = join_cfg.get('extra_args', '') %}

{% if enabled %}
{% if _family == 'Suse' %}
freeipa_obs_repo:
  pkgrepo.managed:
    - name: {{ repo_name }}
    - humanname: FreeIPA (OBS security:idm)
    - baseurl: {{ repo_url }}
    - enabled: True
    - refresh: True
    - gpgkey: {{ repo_url }}repodata/repomd.xml.key
    - gpgcheck: 1
    - gpgautoimport: True
{% endif %}

freeipa_client:
  pkg.installed:
    - pkgs:
{% for pkg in packages %}
      - {{ pkg }}
{% endfor %}
{% if _family == 'Suse' %}
    - fromrepo: {{ repo_name }}
    - gpgautoimport: True
    - require:
      - pkgrepo: freeipa_obs_repo
{% endif %}

{% if join_enabled %}
{% if not domain or not principal or not password %}
freeipa_join_missing_creds:
  test.fail_without_changes:
    - name: baseline:freeipa:join needs domain, principal and password when join.enabled is True (store password in encrypted pillar)
{% else %}
freeipa_join:
  cmd.run:
    - name: ipa-client-install --unattended --domain={{ domain }} --realm={{ realm }}{% if server %} --server={{ server }}{% endif %} --principal={{ principal }} --password="$IPA_JOIN_PASSWORD"{% if mkhomedir %} --mkhomedir{% else %} --no-mkhomedir{% endif %}{% if no_ntp %} --no-ntp{% endif %}{% if extra_args %} {{ extra_args }}{% endif %}
    - env:
      - IPA_JOIN_PASSWORD: {{ password }}
    - unless: test -f /etc/ipa/default.conf
    - onlyif: command -v ipa-client-install >/dev/null 2>&1
    - hide_output: True
    - output_loglevel: quiet
    - timeout: 600
    - require:
      - pkg: freeipa_client
{% endif %}
{% endif %}
{% elif _family == 'Suse' %}
freeipa_obs_repo:
  pkgrepo.absent:
    - name: {{ repo_name }}
{% endif %}
{% endif %}
