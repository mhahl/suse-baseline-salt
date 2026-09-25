{# FreeIPA client from the OBS security:idm project (install only).
   Domain enrollment (ipa-client-install) is intentionally out of scope:
   joining needs interactive admin credentials, so it stays manual.
   Repo metadata (verified against the published .repo file):
   baseurl https://download.opensuse.org/repositories/security:/idm/openSUSE_Tumbleweed/
   with gpgcheck=1 (key: .../repodata/repomd.xml.key, currently the
   shared "security OBS Project" key). Disabling removes the repo but
   keeps already-installed packages, like the croniter providers in
   baseline.schedule.
   zypper prompts to trust a new/rotated signing key interactively and
   fails non-interactive refreshes until it is trusted, so both states
   below pass gpgautoimport (zypper's own --gpg-auto-import-keys):
   same trust level as a manual rpm --import, verified against Salt's
   zypper module (mod_repo/refresh_db honor it, and pkg.installed
   forwards it to the resolve_capabilities refresh). #}
{% set cfg = salt['pillar.get']('baseline:freeipa', {}) %}
{% set enabled = cfg.get('enabled', True) %}
{% set repo_name = cfg.get('repo_name', 'security:idm') %}
{% set repo_url = cfg.get('repo_url', 'https://download.opensuse.org/repositories/security:/idm/openSUSE_Tumbleweed/') %}
{% set packages = cfg.get('packages', ['freeipa-client']) %}

{% if enabled %}
freeipa_obs_repo:
  pkgrepo.managed:
    - name: {{ repo_name }}
    - humanname: FreeIPA (OBS security:idm)
    - baseurl: {{ repo_url }}
    - enabled: True
    - refresh: True
    - gpgcheck: 1
    - gpgautoimport: True

freeipa_client:
  pkg.installed:
    - pkgs:
{% for pkg in packages %}
      - {{ pkg }}
{% endfor %}
    - fromrepo: {{ repo_name }}
    - gpgautoimport: True
    - require:
      - pkgrepo: freeipa_obs_repo
{% else %}
freeipa_obs_repo:
  pkgrepo.absent:
    - name: {{ repo_name }}
{% endif %}
