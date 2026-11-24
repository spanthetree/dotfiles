#!/usr/bin/python3
"""Install the packages listed in packages.yaml, and remove ones taken out of it. Called by linux/install.sh.

  packages.py linux   [--adopt] [--yes]   apt repos + packages, github/script installs, update/post hooks
  packages.py windows [--adopt] [--yes]   winget ids on the Windows host (run from WSL)
  packages.py linux|windows --purge [--yes]   uninstall everything this installer recorded (install.cmd --uninstall)
  packages.py linux --cosmic | --no-cosmic   choose (or drop) the opt-in COSMIC desktop on this machine (when: cosmic)
  packages.py linux --hyprland | --no-hyprland   the same for the Hyprland desktop setup (when: hyprland)

Removal: each machine records what this installer installed (linux: ~/.local/state/dotfiles/linux.json,
windows: %LOCALAPPDATA%\\dotfiles\\windows.installed, shared with install.ps1). A recorded package that is no longer
in packages.yaml is uninstalled after a y/N prompt (--yes skips it). Packages already on the machine are not
recorded, so they are never removed, unless --adopt records everything in packages.yaml that is installed now.
Core packages in PROTECTED are never removed. Keys are documented at the top of packages.yaml.
"""
import atexit, glob, io, json, os, platform, shlex, subprocess, sys, tarfile, threading, time, urllib.request, zipfile

import yaml

DOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # the repo
os.environ['DOT'] = DOT  # for packages.yaml's scripts (e.g. a file from this repo)
HOME = os.path.expanduser('~')
BIN = os.path.join(HOME, '.local', 'bin')
STATE = os.path.join(os.environ.get('XDG_STATE_HOME', os.path.join(HOME, '.local', 'state')), 'dotfiles')
SUDO = [] if os.geteuid() == 0 else ['sudo']
# The installer, the shell and the repo itself depend on these
PROTECTED = {'git', 'curl', 'ca-certificates', 'gnupg', 'gpg', 'openssl', 'python3', 'python3-yaml', 'zsh', 'sudo',
             'Git.Git'}
ADOPT = '--adopt' in sys.argv
YES = '--yes' in sys.argv
PURGE = '--purge' in sys.argv  # as if packages.yaml were empty
# Opt-in desktops (when: cosmic, when: hyprland): chosen per machine with --cosmic / --hyprland, kept in the state dir
# until --no-cosmic / --no-hyprland. Their entries (and apt repos) are only used while chosen; dropping the choice
# offers to uninstall what they installed.
OPT_IN = ('cosmic', 'hyprland')
failed = []


# Terminal look (install-fx.sh's): one spinner line shows what's running; finished steps print ✓/✗ above it
FX = sys.stdout.isatty() and not os.environ.get('NO_FX') and os.environ.get('TERM', 'dumb') != 'dumb'
PINK, CYAN, YELL, DIM = (f'\033[38;2;{c}m' for c in ('255;126;219', '54;249;246', '254;222;93', '169;155;189'))
RST = '\033[0m'
LOCK = threading.Lock()
SPIN = {'text': '', 't0': 0.0}


def spinner():  # background thread: redraws the spinner line
    i = 0
    while True:
        time.sleep(0.08)
        i += 1
        with LOCK:
            if SPIN['text']:
                w = os.get_terminal_size().columns - 12
                print(f'\r\033[2K  {PINK}{"⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"[i % 10]}{RST} {SPIN["text"][:w]} '
                      f'{DIM}{int(time.time() - SPIN["t0"])}s{RST}', end='', flush=True)


def status(text):  # set the spinner line ('' hides it); its clock restarts
    with LOCK:
        SPIN.update(text=text, t0=time.time())
        if FX and not text:
            print('\r\033[2K', end='', flush=True)


def say(line, err=False):  # a permanent line, above the spinner
    with LOCK:
        print(('\r\033[2K' if FX else '') + line, file=sys.stderr if err else sys.stdout, flush=True)


def log(msg): say(f'  {CYAN}›{RST} {msg}')
def warn(msg): say(f'  {YELL}▲{RST} {msg}', err=True)


def done(label, ok=True):  # ✓/✗ for a step started with status(label)
    secs = int(time.time() - SPIN['t0'])
    say(f'  {CYAN + "✓" if ok else YELL + "✗"}{RST} {label}' + (f' {DIM}{secs}s{RST}' if secs else ''))


def run(label, cmd, interactive=False, **kw):
    """Run cmd (a list, or a bash string) as one step: spinner, then ✓/✗; output only if it fails. True if it worked.
    interactive: no spinner, the terminal stays attached, so prompts it can't avoid (sudo) are seen and answered."""
    if isinstance(cmd, str):
        cmd = ['bash', '-c', cmd]
    if not FX:
        log(label)
        return subprocess.run(cmd, **kw).returncode == 0
    prev = SPIN['text']
    if interactive:
        status('')
        log(label)
        ok = subprocess.run(cmd, **kw).returncode == 0
        done(label, ok)
        status(prev)
        return ok
    status(label)
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, **kw)
    done(label, r.returncode == 0)
    if r.returncode:
        for line in r.stdout.decode(errors='replace').splitlines()[-20:]:
            say(f'    {DIM}{line}{RST}')
    status(prev)
    return r.returncode == 0


def quiet(cmd, **kw): return subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, **kw).returncode == 0


def doc():
    with open(os.path.join(DOT, 'packages.yaml')) as f:
        return yaml.safe_load(f)


def load(section):
    key = 'name' if section == 'linux' else 'id'
    return [{key: i} if isinstance(i, str) else i for i in doc().get(section) or []]


def confirm(what, names, detail=''):
    status('')
    print(f'\n{what} no longer in packages.yaml (or for a desktop no longer chosen): {", ".join(sorted(names))}')
    if detail:
        print(detail)
    if YES:
        return True
    try:
        # separate read and write handles: text-mode 'r+' on a tty raises "not seekable" (an OSError)
        with open('/dev/tty', 'w') as out, open('/dev/tty') as inp:
            out.write('Uninstall them? [y/N] ')
            out.flush()
            return inp.readline().strip().lower() in ('y', 'yes')
    except OSError:
        warn('no terminal to ask; not uninstalling (re-run interactively, or pass --yes)')
        return False


# ---- apt removal safety. An apt package this installer recorded can still be one the system needs (e.g. a library
# listed for a tool, that the desktop also depends on). `apt-get remove` takes everything that depends on what it
# removes with it: dropping three libxcb libraries once removed the whole desktop. So: a package is only removed when
# apt would remove nothing else with it; one still needed is handed back to apt (marked automatic) and stays. The
# final removal is simulated again and refused if it would take more than planned, or anything essential.
NEVER_REMOVE = ('ubuntu-desktop', 'ubuntu-desktop-minimal', 'ubuntu-minimal', 'ubuntu-standard', 'gdm3', 'sddm',
                'cosmic-session', 'cosmic-comp', 'cosmic-greeter', 'gnome-shell', 'gnome-session', 'xwayland',
                'xserver-xorg-core', 'libgtk-3-0t64', 'libgtk-4-1', 'systemd', 'sudo', 'apt', 'dpkg', 'libc6')


def apt_sim(args):  # the packages `apt-get <args> -s` would remove (None: apt refused)
    r = subprocess.run(['apt-get', '-s', '-qq'] + args, capture_output=True, text=True,
                       env=dict(os.environ, LC_ALL='C'))
    if r.returncode != 0:
        return None
    return {l.split()[1] for l in r.stdout.splitlines() if l.startswith('Remv ')}


def apt_manual():  # packages marked as installed by hand (not as some other package's dependency)
    return set(subprocess.run(['apt-mark', 'showmanual'], capture_output=True, text=True).stdout.split())


def apt_critical(names):  # the ones that must never go: essential, required/important priority, or the desktop
    bad = {n for n in names if n.split(':')[0] in NEVER_REMOVE}
    if names:
        out = subprocess.run(['dpkg-query', '-W', '-f', '${Package} ${Essential} ${Priority}\n'] + sorted(names),
                             capture_output=True, text=True).stdout
        for l in out.splitlines():
            f = l.split()
            if len(f) >= 3 and (f[1] == 'yes' or f[2] in ('required', 'important')):
                bad.add(f[0])
    return bad


def apt_plan(names):
    """Split apt packages to uninstall into (removable, kept): removable when apt would remove nothing but packages
    from this list along with it; kept ones are still needed by something else."""
    names = set(names)
    removable = set()
    for n in sorted(names):
        sim = apt_sim(['remove', n])
        if sim is not None and {s.split(':')[0] for s in sim} <= names and not apt_critical(sim):
            removable.add(n)
    return removable, names - removable


def apt_remove_safely(names, autoremove):
    """Remove exactly `names` (already planned), refusing if apt would take anything more. Then, with autoremove,
    only the dependencies this removal itself left unneeded (never other leftovers). True if it worked."""
    before = apt_sim(['autoremove']) or set()
    sim = apt_sim(['remove'] + sorted(names))
    if sim is None or {s.split(':')[0] for s in sim} - set(names) or apt_critical(sim):
        warn('apt would remove more than planned (' + ', '.join(sorted(sim or [])) + '); nothing removed')
        return False
    if not run('apt remove ' + ' '.join(sorted(names)), SUDO + ['apt-get', 'remove', '-y', '-qq'] + sorted(names)):
        return False
    if autoremove:
        freed = (apt_sim(['autoremove']) or set()) - before
        if freed and not apt_critical(freed):
            pkgs = sorted(f.split(':')[0] for f in freed)
            sim = apt_sim(['remove'] + pkgs)
            if sim is not None and {s.split(':')[0] for s in sim} <= set(pkgs) and not apt_critical(sim):
                run(f'apt: {len(pkgs)} dependencies they left', SUDO + ['apt-get', 'remove', '-y', '-qq'] + pkgs)
    return True


def is_wsl():
    try:
        return 'microsoft' in open('/proc/version').read().lower()
    except OSError:
        return False


def chosen(name):
    return os.path.exists(os.path.join(STATE, f'desktop-{name}'))


def choose():  # --cosmic / --no-cosmic: record the choice (before anything reads it). --purge forgets them
    for name in OPT_IN:
        f = os.path.join(STATE, f'desktop-{name}')
        if PURGE:
            if os.path.exists(f):
                os.remove(f)
        elif f'--{name}' in sys.argv:
            os.makedirs(STATE, exist_ok=True)
            open(f, 'w').close()
        elif f'--no-{name}' in sys.argv and os.path.exists(f):
            os.remove(f)


def desktop():  # WSLg sets DISPLAY too, but WSL gets the Windows app instead
    return not is_wsl() and any(os.environ.get(v) for v in ('XDG_CURRENT_DESKTOP', 'DISPLAY', 'WAYLAND_DISPLAY'))


def wanted(p):
    when = p.get('when')
    if when == 'wsl':
        return is_wsl()
    if when == 'desktop':
        return desktop()
    if when in OPT_IN:
        return desktop() and chosen(when)
    if when == 'in-hyprland':  # the Hyprland layer: skipped (kept, not uninstalled) in other desktops
        return desktop() and (in_hyprland() or chosen('hyprland'))
    return True


def in_hyprland():  # a run from inside a Hyprland session (install.sh drops a dead instance's signature first)
    return 'Hyprland' in os.environ.get('XDG_CURRENT_DESKTOP', '') or bool(os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'))


def dropped(p):  # an opt-in desktop's entry while that desktop isn't chosen: as if not in packages.yaml
    return p.get('when') in OPT_IN and not chosen(p['when'])


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
KREW = '~/.krew/bin/kubectl-krew'
TOOLKITS = {
    'krew': dict(check=KREW + ' list 2>/dev/null | grep -qx {n}', install=KREW + ' install {n}',
                 uninstall=KREW + ' uninstall {n}'),  # kubectl plugins, in ~/.krew (piped, `krew list` prints names)
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


def other_source(r):
    """An apt source file, not ours, that already has r's URL (e.g. from add-apt-repository), or None."""
    ours = f'/etc/apt/sources.list.d/{r["name"]}.list'
    url = r['url'].rstrip('/')
    for f in ['/etc/apt/sources.list'] + sorted(glob.glob('/etc/apt/sources.list.d/*.list') +
                                                glob.glob('/etc/apt/sources.list.d/*.sources')):
        try:
            if f != ours and any(url in l and not l.lstrip().startswith('#') for l in open(f)):
                return f
        except OSError:
            pass
    return None


def add_repo(r, arch, codename):
    # apt refuses to read any source when one URL has two different keys (Signed-By): use the one already there
    other = other_source(r)
    if other:
        drop_repo(r['name'])  # ours from an earlier run, if any
        log(f'apt repo {r["name"]}: {other} already has {r["url"]}; using that one')
        return
    keyring = f'/usr/share/keyrings/{r["name"]}-archive-keyring.gpg'
    key = urllib.request.urlopen(r['key']).read()
    subprocess.run(SUDO + ['gpg', '--dearmor', '--yes', '-o', keyring], input=key, check=True)
    line = f'deb [arch={arch} signed-by={keyring}] {r["url"]} {r.get("suite", codename)} {r.get("components", "main")}\n'
    subprocess.run(SUDO + ['tee', f'/etc/apt/sources.list.d/{r["name"]}.list'], input=line.encode(),
                   stdout=subprocess.DEVNULL, check=True)


def fill(s, tag, arch):
    m = platform.machine()
    return s.format(tag=tag, version=tag.lstrip('v'), arch=arch, m=m, xarch='x86_64' if arch == 'amd64' else arch)


def latest_tag(p):  # the releases/latest redirect, not the API: no rate limit
    return urllib.request.urlopen(f'https://github.com/{p["github"]}/releases/latest').geturl().rstrip('/').rsplit('/', 1)[1]


def github_install(p, arch, tag):
    url = f'https://github.com/{p["github"]}/releases/download/{tag}/{fill(p["asset"], tag, arch)}'
    member = fill(p.get('file', p['name']), tag, arch)
    blob = urllib.request.urlopen(url).read()
    # named files only from an archive, each written to BIN under its own name: no path traversal
    if not p['asset'].endswith(('.tar.gz', '.tgz', '.tar.xz', '.tar.bz2', '.zip')):
        files = {p['name']: blob}  # the asset is the binary itself
    else:
        members = {p['name']: member} | {extra_name(e): fill(e, tag, arch) for e in p.get('extra') or []}
        if zipfile.is_zipfile(io.BytesIO(blob)):
            z = zipfile.ZipFile(io.BytesIO(blob))
            files = {n: z.read(m) for n, m in members.items()}
        else:
            t = tarfile.open(fileobj=io.BytesIO(blob))
            files = {n: t.extractfile(m).read() for n, m in members.items()}
    for n, data in files.items():
        dest = os.path.join(BIN, n)
        with open(dest, 'wb') as f:
            f.write(data)
        os.chmod(dest, 0o755)


def extra_name(path):  # an `extra:` file's name in BIN: its last path part
    return path.rstrip('/').rsplit('/', 1)[-1]


def drop_repo(name):
    files = [f'/usr/share/keyrings/{name}-archive-keyring.gpg', f'/etc/apt/sources.list.d/{name}.list']
    if any(os.path.exists(f) for f in files):
        run(f'apt repo {name} removed', SUDO + ['rm', '-f'] + files)


def linux():
    arch = subprocess.run(['dpkg', '--print-architecture'], capture_output=True, text=True).stdout.strip()
    codename = subprocess.run(['bash', '-c', '. /etc/os-release && echo "$VERSION_CODENAME"'],
                              capture_output=True, text=True).stdout.strip()
    every = [] if PURGE else load('linux')
    pkgs = [p for p in every if wanted(p)]
    path = os.path.join(STATE, 'linux.json')
    record = json.load(open(path)) if os.path.exists(path) else {}
    before, apt = None, []

    def save():  # at exit, also on Ctrl-C, so what this run installed can still be uninstalled
        if before is not None and apt:  # apt installs the loop below may not have reached
            now = dpkg_installed()
            for p in pkgs:
                if p['name'] in apt and p['name'] in now and p['name'] not in before:
                    record.setdefault(p['name'], {'kind': 'apt', 'uninstall': p.get('uninstall')})
        os.makedirs(STATE, exist_ok=True)
        with open(path, 'w') as f:
            json.dump(record, f, indent=1, sort_keys=True)
    atexit.register(save)

    for p in pkgs:
        if 'repo' in p:
            try:
                add_repo(p['repo'], arch, codename)
            except Exception as e:
                warn(f'apt repo {p["repo"]["name"]}: {e}')

    if pkgs:
        run('apt update', SUDO + ['apt-get', 'update', '-qq'])
    before = dpkg_installed()
    apt = []
    for i, p in enumerate(pkgs, 1):
        status(f'checking apt packages {i}/{len(pkgs)}  {p["name"]}')
        if kind(p) != 'apt' or skip(p):
            continue
        # already installed: leave it out. `apt-get install` on it would mark it as installed by hand, and a library
        # present only as another package's dependency would then look like ours (apt upgrade keeps it current)
        if p['name'] in before:
            continue
        if quiet(['apt-cache', 'show', p['name']]):
            apt.append(p['name'])
        else:
            warn(f'apt: {p["name"]} not available here, skipping')
    if apt and not run(f'apt packages ({len(apt)})', SUDO + ['env', 'DEBIAN_FRONTEND=noninteractive', 'apt-get', 'install', '-y', '-qq'] + apt):
        failed.append('apt packages')
    if pkgs and (doc().get('settings') or {}).get('upgrade', False):
        if not run('apt upgrade', SUDO + ['env', 'DEBIAN_FRONTEND=noninteractive', 'apt-get', 'upgrade', '-y', '-qq']):
            failed.append('apt upgrade')
    after = dpkg_installed()
    # apt packages count as this installer's only when installed by hand (apt-mark showmanual): one present only as a
    # dependency of something else (a library the desktop needs) is never ours, so never ours to remove
    manual = apt_manual()
    for n in [n for n, r in record.items() if r['kind'] == 'apt' and n in after and n not in manual]:
        warn(f'{n}: installed as a dependency of other packages; no longer tracked as installed by dotfiles')
        del record[n]

    for i, p in enumerate(pkgs, 1):
        name, k = p['name'], kind(p)
        mine = name in record
        tag = None
        status(f'checking {i}/{len(pkgs)}  {name}')
        try:
            if k == 'apt':
                mine = mine or (name in after and name in manual and (ADOPT or name not in before))
            elif skip(p):
                mine = mine or ADOPT
                if 'update' in p and not run(f'{name} update', p['update'], p.get('interactive', False)):
                    warn(f'{name}: update failed')
                # our GitHub binaries: fetch again when a newer release is out (not one installed some other way)
                if k == 'github' and os.path.exists(os.path.join(BIN, name)):
                    tag = latest_tag(p)
                    if (record.get(name) or {}).get('tag') != tag:
                        status(f'{name} {tag}')
                        github_install(p, arch, tag)
                        done(f'{name} {tag}')
                        mine = True
            else:
                if k == 'github':
                    tag = latest_tag(p)
                    status(f'{name} {tag}')
                    github_install(p, arch, tag)
                    done(f'{name} {tag}')
                elif not run(name, p['script'], p.get('interactive', False)):
                    raise RuntimeError('install script failed')
                mine = True
            if 'post' in p and not run(f'{name} setup', p['post'], p.get('interactive', False)):
                warn(f'{name}: post step failed')
        except Exception as e:
            warn(f'{name}: {e}')
            failed.append(name)
            continue  # no language, no tools
        if mine:  # keep how to uninstall it, since its entry is gone once it's removed from packages.yaml
            record[name] = {'kind': k, 'uninstall': p.get('uninstall')}
            if p.get('interactive'):
                record[name]['interactive'] = True
            if tag:
                record[name]['tag'] = tag
            if k == 'github' and p.get('extra'):
                record[name]['extra'] = [extra_name(e) for e in p['extra']]
            if 'repo' in p:  # its apt source goes when it does
                record[name]['repo'] = p['repo']['name']
        for tid, check, install, uninstall in tools(p):
            if quiet(['bash', '-c', check]):
                mine = tid in record or ADOPT
            else:
                mine = run(tid, install)
                if not mine:
                    warn(f'{tid}: install failed')
                    failed.append(tid)
            if mine:
                record[tid] = {'kind': 'tool', 'uninstall': uninstall, 'check': check}

    kept = [p for p in every if not dropped(p)]
    names = {p['name'] for p in kept} | {t[0] for p in kept for t in tools(p)}
    # tools first: their uninstall needs the language, which may be going too. Then the rest in the reverse of
    # packages.yaml's order, so what builds on an entry goes before it (hyprbars' uninstall needs hyprpm, which goes
    # with hyprland-desktop above it). Names no longer in packages.yaml go first.
    pos = {p['name']: i for i, p in enumerate(load('linux'))}
    gone = sorted((n for n in record if n not in names),
                  key=lambda n: (record[n]['kind'] != 'tool', -pos.get(n, len(pos))))
    for n in [n for n in gone if n in PROTECTED]:
        warn(f'{n}: core package, not uninstalling')
        del record[n]
    gone = [n for n in gone if n not in PROTECTED]
    # apt packages: only those apt can remove without taking anything else (apt_plan); the rest stay as dependencies
    installed = dpkg_installed()
    apt_all = [n for n in gone if record[n]['kind'] == 'apt' and not record[n]['uninstall']]
    for n in [n for n in apt_all if n not in installed]:  # already gone (removed some other way)
        del record[n]
    apt_all = [n for n in apt_all if n in installed]
    apt_gone, apt_kept = apt_plan(apt_all) if apt_all else (set(), set())
    gone = [n for n in gone if n in record and n not in apt_kept]
    for n in sorted(apt_kept):
        warn(f'{n}: other installed packages need it; kept, as an ordinary dependency (no longer tracked)')
        quiet(SUDO + ['apt-mark', 'auto', n])
        del record[n]
    if gone and confirm('Linux packages', gone):
        removed_repos = {n: record[n].get('repo') for n in gone}
        if apt_gone:
            if apt_remove_safely(apt_gone, (doc().get('settings') or {}).get('autoremove', True)):
                for n in apt_gone:
                    del record[n]
            else:
                failed.append('apt remove')
        for n in [n for n in gone if n in record]:
            r = record[n]
            if r['kind'] == 'tool':  # gone already counts as removed
                ok = run(f'uninstall {n}', r['uninstall']) or not quiet(['bash', '-c', r['check']])
            elif r['uninstall']:
                ok = run(f'uninstall {n}', r['uninstall'], r.get('interactive', False))
            elif r['kind'] == 'github':
                for f in [n] + r.get('extra', []):
                    if os.path.exists(os.path.join(BIN, f)):
                        os.remove(os.path.join(BIN, f))
                log(f'uninstall {n}')
                ok = True
            else:
                warn(f'{n}: no uninstall step in packages.yaml; remove it by hand')
                ok = True  # stop tracking it either way
            if ok:
                del record[n]
            else:
                failed.append(f'uninstall {n}')
        # their apt sources, unless an entry still in packages.yaml uses the same one
        kept_repos = {p['repo']['name'] for p in kept if 'repo' in p}
        for n in gone:
            repo = removed_repos.get(n)
            if repo and n not in record and repo not in kept_repos:
                drop_repo(repo)

    # the apt repos it added: all with --purge, an opt-in desktop's once it's dropped
    for r in [p['repo'] for p in load('linux') if 'repo' in p and (PURGE or dropped(p))]:
        drop_repo(r['name'])


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

    def save():  # at exit, also on Ctrl-C
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w') as f:
            f.write(''.join(f'{i}\n' for i in sorted(record)))
    atexit.register(save)
    every = [] if PURGE else load('windows')

    for i, p in enumerate(every, 1):
        pid = p['id']
        status(f'checking Windows apps {i}/{len(every)}  {pid}')
        if ('font' in p and font_installed(p['font'])) or quiet(winget('list', '--id', pid), cwd='/mnt/c'):
            if ADOPT:
                record.add(pid)
            continue
        if not run(f'{pid} (Windows)', winget('install', '--id', pid, '--accept-package-agreements'), cwd='/mnt/c'):
            warn(f'{pid} install failed; install it by hand')
            failed.append(pid)
        else:
            record.add(pid)

    gone = [i for i in record if i not in {p['id'] for p in every}]
    record -= {i for i in gone if i in PROTECTED}
    gone = [i for i in gone if i not in PROTECTED]
    if gone and confirm('Windows apps', gone):
        for pid in gone:
            if run(f'winget uninstall {pid}', winget('uninstall', '--id', pid), cwd='/mnt/c'):
                record.discard(pid)
            else:
                failed.append(f'uninstall {pid}')


if __name__ == '__main__':
    if FX:
        threading.Thread(target=spinner, daemon=True).start()
    choose()
    {'linux': linux, 'windows': windows}[sys.argv[1]]()
    status('')
    if failed:
        warn('failed: ' + ', '.join(failed))
