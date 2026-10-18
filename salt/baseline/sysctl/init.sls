# Kernel sysctl hardening (baseline.sysctl).
#
# Writes /etc/sysctl.d/99-baseline.conf with opinionated kernel and
# network-security defaults, then applies them via sysctl --system.
#
# Covering:
#   Memory security  — ASLR, dmesg restriction, SUID core dumps, SysRq
#   Network          — ICMP redirects, source routing, IP spoofing,
#                      SYN flood cookies, martian logging, forwarding
#   IPv6             — same redirect/forwarding/source-route controls
#
# Disabling (baseline:sysctl:enabled: false) removes the file and
# reloads sysctl, reverting to system defaults.

{% set enabled = salt['pillar.get']('baseline:sysctl:enabled', True) %}

{% if enabled %}
baseline_sysctl_config:
  file.managed:
    - name: /etc/sysctl.d/99-baseline.conf
    - contents: |
        # Managed by baseline.sysctl — set enabled: false in pillar
        # under baseline:sysctl to remove this file.
        #
        # ── Memory / Information disclosure ───────────────────────────
        # Restrict access to kernel addresses in /proc/kcore.  Level 2
        # requires CAP_SYS_PTRACE for all reads, preventing ASLR bypass
        # via /proc/<pid>/ maps.
        kernel.kptr_restrict = 2

        # Only root can read kernel log (dmesg).  Prevents unprivileged
        # info gathering from kernel ring buffer.
        kernel.dmesg_restrict = 1

        # Full ASLR (randomise brk, mmap, stack, VDSO).  Level 2
        # randomises all memory regions including brk.  Already the
        # default on both Tumbleweed and Fedora; enforced here to guard
        # against accidental or future-default downgrades.
        kernel.randomize_va_space = 2

        # Disable Magic SysRq entirely.  Prevents console-level
        # tampering (immediate reboot, crash-dump triggers) from
        # anyone at the physical console or BMC.
        kernel.sysrq = 0

        # Never dump core from SUID / SGID programs.  Prevents secret
        # material (private keys, passwords in memory) from leaking
        # into core dumps readable by unprivileged users.
        fs.suid_dumpable = 0

        # ── Network — ICMP redirects ──────────────────────────────────
        # Ignore ICMP redirect messages (common MITM vector on shared
        # networks).  Applied to all interfaces.
        net.ipv4.conf.all.accept_redirects = 0
        net.ipv4.conf.default.accept_redirects = 0
        net.ipv4.conf.all.send_redirects = 0
        net.ipv4.conf.default.send_redirects = 0
        net.ipv6.conf.all.accept_redirects = 0
        net.ipv6.conf.default.accept_redirects = 0

        # ── Network — Source routing ──────────────────────────────────
        # Discard packets with source-routing header options.  Prevents
        # traffic being forced through an attacker-chosen path.
        net.ipv4.conf.all.accept_source_route = 0
        net.ipv4.conf.default.accept_source_route = 0
        net.ipv6.conf.all.accept_source_route = 0
        net.ipv6.conf.default.accept_source_route = 0

        # ── Network — IP spoofing ─────────────────────────────────────
        # Reverse-path filtering (Unicast RPF).  Drops packets arriving
        # on an interface whose source address is reachable via a
        # different interface.  Primary defence against IP spoofing.
        net.ipv4.conf.all.rp_filter = 1
        net.ipv4.conf.default.rp_filter = 1

        # ── Network — SYN flood ───────────────────────────────────────
        # Enable SYN cookies when the SYN backlog fills.  Default on
        # both distros; enforced here to survive config changes or
        # policy resets.
        net.ipv4.tcp_syncookies = 1

        # ── Network — Martian logging ─────────────────────────────────
        # Log packets with impossible source addresses (e.g. private
        # IPs arriving on external interfaces) to the kernel log for
        # threat detection.
        net.ipv4.conf.all.log_martians = 1
        net.ipv4.conf.default.log_martians = 1

        # ── Network — IP forwarding ───────────────────────────────────
        # Disable IP forwarding.  The baseline never routes — this
        # prevents the host from being used as an unintended gateway.
        # Enable only on routers / NAT hosts via a pillar override or
        # a separate config in /etc/sysctl.d/.
        net.ipv4.ip_forward = 0
        net.ipv6.conf.all.forwarding = 0
        net.ipv6.conf.default.forwarding = 0
    - user: root
    - group: root
    - mode: '0644'

baseline_sysctl_apply:
  cmd.run:
    - name: sysctl --system
    - onchanges:
      - file: baseline_sysctl_config
    - order: 1

{% else %}
baseline_sysctl_config:
  file.absent:
    - name: /etc/sysctl.d/99-baseline.conf

baseline_sysctl_apply:
  cmd.run:
    - name: sysctl --system
    - onchanges:
      - file: baseline_sysctl_config
{% endif %}