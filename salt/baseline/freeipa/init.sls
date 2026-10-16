{# FreeIPA client from the OBS security:idm project (install only).
   Domain enrollment (ipa-client-install) is intentionally out of scope:
   joining needs interactive admin credentials, so it stays manual.
   Repo metadata (verified against the published .repo file):
   baseurl https://download.opensuse.org/repositories/security:/idm/openSUSE_Tumbleweed/
   with gpgcheck=1 (key: .../repodata/repomd.xml.key, currently the
   shared "security OBS Project" key). Disabling removes the repo but
   keeps already-installed packages, like the croniter providers in
   baseline.schedule.
   On Tumbleweed, zypper prompts to trust rotated keys, so both states
   pass gpgautoimport (zypper's --gpg-auto-import-keys). Fedora installs
   from base repos and does not use those zypper options. #}
{% set _family = grains.get('os_family', '') %}
{% set cfg = salt['pillar.get']('baseline:freeipa', {}) %}
{% set enabled = cfg.get('enabled', True) %}
{% set repo_name = cfg.get('repo_name', 'security:idm') %}
{% set repo_url = cfg.get('repo_url', 'https://download.opensuse.org/repositories/security:/idm/openSUSE_Tumbleweed/') %}
{% set packages = cfg.get('packages', ['freeipa-client']) %}

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
{% elif _family == 'Suse' %}
freeipa_obs_repo:
  pkgrepo.absent:
    - name: {{ repo_name }}
{% endif %}
