# SSH daemon hardening (baseline.ssh).
#
# Writes a drop-in to /etc/ssh/sshd_config.d/ that locks down
# authentication, crypto, forwarding, timeouts, and auditing.
# Modern OpenSSH reads drop-ins before the main config file, so the
# "first obtained" rule makes these values authoritative.
#
# Disabling the module (baseline:ssh:enabled: false in pillar) removes
# the drop-in and reloads sshd to lift the restrictions.
#
# The sshd configuration is validated (sshd -t) before every reload,
# and reload preserves active sessions (SIGHUP vs restart).
{% set enabled = salt['pillar.get']('baseline:ssh:enabled', True) %}
{% set _family = grains.get('os_family', '') %}
{# FreeBSD has no `root` group (it is `wheel`), and its base sshd_config
   ships no Include for sshd_config.d (Tumbleweed/Fedora do) — so on
   FreeBSD the Include is added additively to /etc/ssh/sshd_config and
   the drop-in dir is created (makedirs). Content stays identical. #}
{% set _group = 'wheel' if _family == 'FreeBSD' else 'root' %}

{% if enabled %}
{% if _family == 'FreeBSD' %}
sshd_config_include:
  file.blockreplace:
    - name: /etc/ssh/sshd_config
    - marker_start: "# BEGIN baseline managed sshd include"
    - marker_end: "# END baseline"
    - content: 'Include /etc/ssh/sshd_config.d/*.conf'
    - prepend_if_not_found: True
    - user: root
    - group: wheel
    - mode: '0644'
{% endif %}
sshd_config_dropin:
  file.managed:
    - name: /etc/ssh/sshd_config.d/01-baseline-sshd.conf
    - makedirs: True
    - contents: |
        # Managed by baseline.ssh — remove the drop-in or set
        # baseline:ssh:enabled: false in pillar to disable.
        #
        # EDNS: "first obtained value wins" in OpenSSH, so this
        # drop-in (lexically first) is authoritative over later
        # drop-ins and the main sshd_config.

        # ── Authentication ─────────────────────────────────────────
        # Password/keyboard-interactive auth disabled.  Users authenticate
        # with SSH keys (distributed by FreeIPA via sss_ssh_authorizedkeys)
        # or Kerberos tickets (GSSAPI with renewable TGTs).
        PasswordAuthentication no
        KbdInteractiveAuthentication no
        ChallengeResponseAuthentication no

        # FreeIPA / SSSD integration: IPA-published SSH keys + Kerberos SSO
        GSSAPIAuthentication yes
        GSSAPIKeyExchange yes
        GSSAPICleanupCredentials yes
        AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys
        AuthorizedKeysCommandUser nobody

        # Sufficient: a user needs a public key OR a valid GSSAPI
        # credential.  Change to "publickey,gssapi-with-mic" (comma,
        # not space) to require BOTH.
        AuthenticationMethods publickey gssapi-with-mic

        # ── Access ─────────────────────────────────────────────────
        # No root SSH at all.  Elevation is via FreeIPA HBAC sudo.
        PermitRootLogin no

        # ── Rate-limiting ──────────────────────────────────────────
        MaxAuthTries 3
        MaxSessions 4
        LoginGraceTime 30
        MaxStartups 5:30:30

        # ── Timeouts ───────────────────────────────────────────────
        # Application-level keepalive (not TCP) so orphaned sessions
        # are eventually cleaned up.  Users with long-running workflows
        # can override per-host in their ~/.ssh/config.
        ClientAliveInterval 300
        ClientAliveCountMax 2

        # ── Forwarding ─────────────────────────────────────────────
        # All forwarding disabled globally.  Enable selectively per
        # group/user via Match blocks in a later drop-in.
        AllowTcpForwarding no
        AllowAgentForwarding no
        X11Forwarding no
        PermitTunnel no
        PermitUserEnvironment no

        # ── Audit ──────────────────────────────────────────────────
        # VERBOSE logs the key fingerprint on every login — essential
        # for tracing which key was used after an incident.
        LogLevel VERBOSE
        SyslogFacility AUTH

        # ── Crypto — modern subset ─────────────────────────────────
        # Ed25519 host keys preferred; RSA-SHA2 as a compat fallback.
        # No ECDSA or DSA (NIST curves have documented NSA involvement
        # in parameter selection; DSA is deprecated).
        HostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-512-cert-v01@openssh.com

        # Key exchange: Curve25519 (safe, non-NIST) + post-quantum
        # hybrid sntrup761x25519 (OpenSSH 8.5+, included in both
        # openSUSE Tumbleweed and Fedora as of late 2024).
        # On OpenSSH >= 9.9 (Fedora 43+, Tumbleweed rolling),
        # prepend "mlkem768x25519-sha256," for IETF ML-KEM (FIPS 203).
        KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org

        # Ciphers: AEAD only.  ChaCha20-Poly1305 preferred (no packet
        # length oracle); AES-GCM as a hardware-accelerated fallback
        # on systems with AES-NI.
        Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com

        # MACs: Encrypt-then-MAC only (hmac-*-etm).  When an AEAD
        # cipher is negotiated the MACs list is not consulted, but
        # this ensures defence-in-depth if a non-AEAD cipher is ever
        # added.
        MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
    - user: root
    - group: {{ _group }}
    - mode: '0644'
{% if _family == 'FreeBSD' %}
    - require:
      - file: sshd_config_include
{% endif %}

sshd_validate:
  cmd.run:
    - name: sshd -t
    - onchanges:
      - file: sshd_config_dropin
{% if _family == 'FreeBSD' %}
      - file: sshd_config_include
{% endif %}
    - failhard: True
    - order: 1

sshd_reload:
  module.run:
    - name: service.reload
    - m_name: sshd
    - onchanges:
      - file: sshd_config_dropin
{% if _family == 'FreeBSD' %}
      - file: sshd_config_include
{% endif %}
    - require:
      - cmd: sshd_validate

sshd_service:
  service.running:
    - name: sshd
    - enable: True
{% if _family == 'FreeBSD' %}
    - require:
      - file: sshd_config_include
{% endif %}

{% else %}
{% if _family == 'FreeBSD' %}
sshd_config_include:
  file.blockreplace:
    - name: /etc/ssh/sshd_config
    - marker_start: "# BEGIN baseline managed sshd include"
    - marker_end: "# END baseline"
    - content: ""
{% endif %}
sshd_config_dropin:
  file.absent:
    - name: /etc/ssh/sshd_config.d/01-baseline-sshd.conf

sshd_reload:
  module.run:
    - name: service.reload
    - m_name: sshd
    - onchanges:
      - file: sshd_config_dropin
{% if _family == 'FreeBSD' %}
      - file: sshd_config_include
{% endif %}
{% endif %}