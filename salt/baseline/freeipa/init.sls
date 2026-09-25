{# FreeIPA client from the OBS security:idm project (install only).
   Domain enrollment (ipa-client-install) is intentionally out of scope:
   joining needs interactive admin credentials, so it stays manual.
   Repo metadata (verified against the published .repo file):
   baseurl https://download.opensuse.org/repositories/security:/idm/openSUSE_Tumbleweed/
   with gpgcheck=1 (key: .../repodata/repomd.xml.key). Disabling removes
   the repo but keeps already-installed packages, like the croniter
   providers in baseline.schedule.
   zypper prompts to trust a new/rotated signing key interactively and
   fails non-interactive refreshes until it is trusted, so the key is
   pre-imported below (idempotent via the gpg-pubkey check; repo_keyid
   must track the repo's current signing key). #}
{% set cfg = salt['pillar.get']('baseline:freeipa', {}) %}
{% set enabled = cfg.get('enabled', True) %}
{% set repo_name = cfg.get('repo_name', 'security:idm') %}
{% set repo_url = cfg.get('repo_url', 'https://download.opensuse.org/repositories/security:/idm/openSUSE_Tumbleweed/') %}
{% set repo_keyid = cfg.get('repo_keyid', '6dd785ca') %}
{% set repo_key_url = repo_url.rstrip('/') + '/repodata/repomd.xml.key' %}
{% set packages = cfg.get('packages', ['freeipa-client']) %}

{% if enabled %}
freeipa_repo_key:
  cmd.run:
    - name: rpm --import {{ repo_key_url }}
    - unless: rpm -q gpg-pubkey-{{ repo_keyid }}

freeipa_obs_repo:
  pkgrepo.managed:
    - name: {{ repo_name }}
    - humanname: FreeIPA (OBS security:idm)
    - baseurl: {{ repo_url }}
    - enabled: True
    - refresh: True
    - gpgcheck: 1
    - require:
      - cmd: freeipa_repo_key

freeipa_client:
  pkg.installed:
    - pkgs:
{% for pkg in packages %}
      - {{ pkg }}
{% endfor %}
    - fromrepo: {{ repo_name }}
    - require:
      - pkgrepo: freeipa_obs_repo
{% else %}
freeipa_obs_repo:
  pkgrepo.absent:
    - name: {{ repo_name }}
{% endif %}
