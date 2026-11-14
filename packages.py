#!/usr/bin/python3
"""Install the packages listed in packages.yaml, and remove ones taken out of it. Called by install.sh --packages.

  packages.py linux   [--adopt] [--yes]   apt repos + packages, github/script installs, update/post hooks
  packages.py windows [--adopt] [--yes]   winget ids on the Windows host (run from WSL)

Removal: each machine records what this installer installed (linux: ~/.local/state/dotfiles/linux.json,
windows: %LOCALAPPDATA%\\dotfiles\\windows.installed, shared with install.ps1). A recorded package that is no longer
in packages.yaml is uninstalled after a y/N prompt (--yes skips it). Packages already on the machine are not
recorded, so they are never removed, unless --adopt records everything in packages.yaml that is installed now.
Core packages in PROTECTED are never removed. Keys are documented at the top of packages.yaml.
"""
import glob, io, json, os, platform, shlex, subprocess, sys, tarfile, urllib.request, zipfile

import yaml

DOT = os.path.dirname(os.path.abspath(__file__))
HOME = os.path.expanduser('~')
BIN = os.path.join(HOME, '.local', 'bin')
STATE = os.path.join(os.environ.get('XDG_STATE_HOME', os.path.join(HOME, '.local', 'state')), 'dotfiles')
SUDO = [] if os.geteuid() == 0 else ['sudo']
# The installer, the shell and the repo itself depend on these
PROTECTED = {'git', 'curl', 'ca-certificates', 'gnupg', 'gpg', 'openssl', 'python3', 'python3-yaml', 'zsh', 'sudo',
             'Git.Git'}
ADOPT = '--adopt' in sys.argv
YES = '--yes' in sys.argv
failed = []


def log(msg): print(f'\033[36m==>\033[0m {msg}', flush=True)
def warn(msg): print(f'\033[33m!!\033[0m {msg}', file=sys.stderr, flush=True)
def sh(cmd): return subprocess.run(['bash', '-c', cmd]).returncode == 0
def quiet(cmd, **kw): return subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, **kw).returncode == 0


def doc():
    with open(os.path.join(DOT, 'packages.yaml')) as f:
        return yaml.safe_load(f)


def load(section):
    key = 'name' if section == 'linux' else 'id'
    return [{key: i} if isinstance(i, str) else i for i in doc().get(section) or []]


def confirm(what, names):
    print(f'\n{what} no longer in packages.yaml: {", ".join(sorted(names))}')
    if YES:
        return True
    try:
        with open('/dev/tty', 'r+') as tty:
            tty.write('Uninstall them? [y/N] ')
            tty.flush()
            return tty.readline().strip().lower() in ('y', 'yes')
    except OSError:
        warn('no terminal to ask; not uninstalling (re-run interactively, or pass --yes)')
        return False


def is_wsl():
    try:
        return 'microsoft' in open('/proc/version').read().lower()
    except OSError:
        return False


def wanted(p):
    when = p.get('when')
    if when == 'wsl':
        return is_wsl()
    if when == 'desktop':  # WSLg sets DISPLAY too, but WSL gets the Windows app instead
        return not is_wsl() and any(os.environ.get(v) for v in ('XDG_CURRENT_DESKTOP', 'DISPLAY', 'WAYLAND_DISPLAY'))
    return True


def kind(p):
    return 'github' if 'github' in p else 'script' if 'script' in p else 'apt'


def skip(p):
    test = p.get('skip_if')
    if test is None and kind(p) != 'apt':
        test = f'command -v {shlex.quote(p["name"])}'
    return bool(test) and quiet(['bash', '-c', test])


# `tools:` under a language entry: how that language's own installer checks, installs and removes a tool.
# {n}: tool name (go: module path), {b}: its command (go: last path part), {v}: version ('' if none)
GO, UV, GEM, REHASH = '/usr/local/go/bin/go', '~/.local/bin/uv', '~/.rbenv/shims/gem', '~/.rbenv/bin/rbenv rehash'
TOOLKITS = {
    'go': dict(check='test -x ~/go/bin/{b}', install=GO + ' install {n}@{v}', uninstall='rm -f ~/go/bin/{b}',
               default='latest'),
    'pyenv': dict(check=UV + " tool list | grep -q '^{n} '", install=UV + ' tool install {qs}',
                  uninstall=UV + ' tool uninstall {n}'),  # uv: one isolated env per tool, command in ~/.local/bin
    'rbenv': dict(check=GEM + " list -i '^{n}$' {gv}", install=GEM + ' install --no-document {n} {gv} && ' + REHASH,
                  uninstall=GEM + ' uninstall -a -x {n} && ' + REHASH),  # into the global Ruby
}


def tools(p):
    """(record id, check, install, uninstall) for each tool of language entry p."""
    kit = TOOLKITS.get(p['name'])
    if 'tools' in p and not kit:
        warn(f"{p['name']}: tools: is only supported under {', '.join(TOOLKITS)}")
    out = []
    for t in (p.get('tools') or []) if kit else []:
        t = {'name': t} if isinstance(t, str) else t
        n, v = t['name'], str(t.get('version', kit.get('default', '')))
        f = dict(n=n, b=n.rstrip('/').rsplit('/', 1)[-1], v=v, qs=shlex.quote(n + v),
                 gv=f'-v {shlex.quote(v)}' if v else '')
        out.append((f"{p['name']}:{n}", *(kit[k].format(**f) for k in ('check', 'install', 'uninstall'))))
    return out


def dpkg_installed():
    out = subprocess.run(['dpkg-query', '-W', '-f', '${Package} ${Status}\n'], capture_output=True, text=True).stdout
    return {l.split()[0] for l in out.splitlines() if l.endswith(' installed')}


def add_repo(r, arch, codename):
    keyring = f'/usr/share/keyrings/{r["name"]}-archive-keyring.gpg'
    key = urllib.request.urlopen(r['key']).read()
    subprocess.run(SUDO + ['gpg', '--dearmor', '--yes', '-o', keyring], input=key, check=True)
    line = f'deb [arch={arch} signed-by={keyring}] {r["url"]} {r.get("suite", codename)} {r.get("components", "main")}\n'
    subprocess.run(SUDO + ['tee', f'/etc/apt/sources.list.d/{r["name"]}.list'], input=line.encode(),
                   stdout=subprocess.DEVNULL, check=True)


def fill(s, tag, arch):
    m = platform.machine()
    return s.format(tag=tag, version=tag.lstrip('v'), arch=arch, m=m, xarch='x86_64' if arch == 'amd64' else arch)


def github_install(p, arch):
    latest = urllib.request.urlopen(f'https://github.com/{p["github"]}/releases/latest').geturl()
    tag = latest.rstrip('/').rsplit('/', 1)[1]
    url = f'https://github.com/{p["github"]}/releases/download/{tag}/{fill(p["asset"], tag, arch)}'
    member = fill(p.get('file', p['name']), tag, arch)
    blob = urllib.request.urlopen(url).read()
    # one named file only from an archive: no path traversal
    if not p['asset'].endswith(('.tar.gz', '.tgz', '.tar.xz', '.tar.bz2', '.zip')):
        data = blob  # the asset is the binary itself
    elif zipfile.is_zipfile(io.BytesIO(blob)):
        data = zipfile.ZipFile(io.BytesIO(blob)).read(member)
    else:
        data = tarfile.open(fileobj=io.BytesIO(blob)).extractfile(member).read()
    dest = os.path.join(BIN, p['name'])
    with open(dest, 'wb') as f:
        f.write(data)
    os.chmod(dest, 0o755)


def linux():
    arch = subprocess.run(['dpkg', '--print-architecture'], capture_output=True, text=True).stdout.strip()
    codename = subprocess.run(['bash', '-c', '. /etc/os-release && echo "$VERSION_CODENAME"'],
                              capture_output=True, text=True).stdout.strip()
    every = load('linux')
    pkgs = [p for p in every if wanted(p)]
    path = os.path.join(STATE, 'linux.json')
    record = json.load(open(path)) if os.path.exists(path) else {}

    for p in pkgs:
        if 'repo' in p:
            try:
                add_repo(p['repo'], arch, codename)
            except Exception as e:
                warn(f'apt repo {p["repo"]["name"]}: {e}')

    log('apt packages (packages.yaml)')
    subprocess.run(SUDO + ['apt-get', 'update', '-qq'])
    before = dpkg_installed()
    apt = []
    for p in pkgs:
        if kind(p) != 'apt' or skip(p):
            continue
        if quiet(['apt-cache', 'show', p['name']]):
            apt.append(p['name'])
        else:
            warn(f'apt: {p["name"]} not available here, skipping')
    if subprocess.run(SUDO + ['env', 'DEBIAN_FRONTEND=noninteractive', 'apt-get', 'install', '-y', '-qq'] + apt).returncode:
        failed.append('apt packages')
    after = dpkg_installed()

    for p in pkgs:
        name, k = p['name'], kind(p)
        mine = name in record
        try:
            if k == 'apt':
                mine = mine or (name in after and (ADOPT or name not in before))
            elif skip(p):
                mine = mine or ADOPT
                if 'update' in p and not sh(p['update']):
                    warn(f'{name}: update failed')
            else:
                log(name)
                if k == 'github':
                    github_install(p, arch)
                elif not sh(p['script']):
                    raise RuntimeError('install script failed')
                mine = True
            if 'post' in p and not sh(p['post']):
                warn(f'{name}: post step failed')
        except Exception as e:
            warn(f'{name}: {e}')
            failed.append(name)
            continue  # no language, no tools
        if mine:  # keep how to uninstall it, since its entry is gone once it's removed from packages.yaml
            record[name] = {'kind': k, 'uninstall': p.get('uninstall')}
        for tid, check, install, uninstall in tools(p):
            if quiet(['bash', '-c', check]):
                mine = tid in record or ADOPT
            else:
                log(tid)
                mine = sh(install)
                if not mine:
                    warn(f'{tid}: install failed')
                    failed.append(tid)
            if mine:
                record[tid] = {'kind': 'tool', 'uninstall': uninstall, 'check': check}

    names = {p['name'] for p in every} | {t[0] for p in every for t in tools(p)}
    # tools first: their uninstall needs the language, which may be going too
    gone = sorted((n for n in record if n not in names), key=lambda n: record[n]['kind'] != 'tool')
    for n in [n for n in gone if n in PROTECTED]:
        warn(f'{n}: core package, not uninstalling')
        del record[n]
    gone = [n for n in gone if n not in PROTECTED]
    if gone and confirm('Linux packages', gone):
        apt_gone = [n for n in gone if record[n]['kind'] == 'apt' and not record[n]['uninstall']]
        if apt_gone:
            log('apt remove ' + ' '.join(apt_gone))
            if subprocess.run(SUDO + ['apt-get', 'remove', '-y', '-qq'] + apt_gone).returncode == 0:
                for n in apt_gone:
                    del record[n]
                if (doc().get('settings') or {}).get('autoremove', True):
                    subprocess.run(SUDO + ['apt-get', 'autoremove', '-y', '-qq'])
            else:
                failed.append('apt remove')
        for n in [n for n in gone if n in record]:
            r = record[n]
            log(f'uninstall {n}')
            if r['kind'] == 'tool':  # gone already counts as removed
                ok = sh(r['uninstall']) or not quiet(['bash', '-c', r['check']])
            elif r['uninstall']:
                ok = sh(r['uninstall'])
            elif r['kind'] == 'github':
                if os.path.exists(os.path.join(BIN, n)):
                    os.remove(os.path.join(BIN, n))
                ok = True
            else:
                warn(f'{n}: no uninstall step in packages.yaml; remove it by hand')
                ok = True  # stop tracking it either way
            if ok:
                del record[n]
            else:
                failed.append(f'uninstall {n}')

    os.makedirs(STATE, exist_ok=True)
    with open(path, 'w') as f:
        json.dump(record, f, indent=1, sort_keys=True)


def font_installed(prefix):
    dirs = ['/mnt/c/Windows/Fonts'] + glob.glob('/mnt/c/Users/*/AppData/Local/Microsoft/Windows/Fonts')
    return any(f.lower().startswith(prefix.lower()) for d in dirs if os.path.isdir(d) for f in os.listdir(d))


def winget(*args):
    return ['winget.exe', *args, '-e', '--accept-source-agreements']


def windows():
    appdata = subprocess.run(['cmd.exe', '/c', 'echo %LOCALAPPDATA%'], capture_output=True, text=True,
                             cwd='/mnt/c').stdout.strip()
    path = os.path.join(subprocess.run(['wslpath', appdata], capture_output=True, text=True).stdout.strip(),
                        'dotfiles', 'windows.installed')
    record = set(open(path).read().split()) if os.path.exists(path) else set()
    every = load('windows')

    for p in every:
        pid = p['id']
        if ('font' in p and font_installed(p['font'])) or quiet(winget('list', '--id', pid), cwd='/mnt/c'):
            if ADOPT:
                record.add(pid)
            continue
        log(f'{pid} (Windows)')
        if subprocess.run(winget('install', '--id', pid, '--accept-package-agreements'), cwd='/mnt/c').returncode:
            warn(f'{pid} install failed; install it by hand')
            failed.append(pid)
        else:
            record.add(pid)

    gone = [i for i in record if i not in {p['id'] for p in every}]
    record -= {i for i in gone if i in PROTECTED}
    gone = [i for i in gone if i not in PROTECTED]
    if gone and confirm('Windows apps', gone):
        for pid in gone:
            log(f'winget uninstall {pid}')
            if subprocess.run(winget('uninstall', '--id', pid), cwd='/mnt/c').returncode == 0:
                record.discard(pid)
            else:
                failed.append(f'uninstall {pid}')

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        f.write(''.join(f'{i}\n' for i in sorted(record)))


if __name__ == '__main__':
    {'linux': linux, 'windows': windows}[sys.argv[1]]()
    if failed:
        warn('failed: ' + ', '.join(failed))
