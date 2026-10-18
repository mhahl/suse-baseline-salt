{% from "overstate/grype/map.jinja" import grype with context %}
# overstate.grype/install.sls — install the pinned Grype release from GitHub.
# No distro package exists on Tumbleweed or Fedora, so the binary lives at
# /usr/local/bin/grype. Fetched over TLS with a pinned sha256 per arch —
# that pair (version pin + source_hash) is the supply chain control.
# When bumping overstate:grype:version, refresh both hashes from the
# release checksums.txt:
# https://github.com/anchore/grype/releases/download/<version>/grype_<stripped>_checksums.txt
{% set _arch = 'amd64' if grains.get('cpuarch', 'x86_64') == 'x86_64' else 'arm64' if grains.get('cpuarch', '') == 'aarch64' else grains.get('cpuarch', 'amd64') %}
{% set _ver = grype.version | string %}
{% set _stripped = _ver[1:] if _ver.startswith('v') else _ver %}
{% set _hashes = grype.hashes %}
grype_install_dir:
  file.directory:
    - name: /usr/local/bin
    - mode: 755

grype_binary:
  archive.extracted:
    - name: /usr/local/bin/
    - source: https://github.com/anchore/grype/releases/download/{{ grype.version }}/grype_{{ _stripped }}_linux_{{ _arch }}.tar.gz
    - source_hash: {{ _hashes.get(_arch, _hashes['amd64']) }}
    - archive_format: tar
    - enforce_toplevel: False
    - overwrite: True
    - unless: /usr/local/bin/grype version 2>/dev/null | grep -Fq {{ _stripped }}
    - require:
      - file: grype_install_dir

grype_binary_perms:
  cmd.run:
    - name: chmod 0755 /usr/local/bin/grype
    - onchanges:
      - archive: grype_binary
