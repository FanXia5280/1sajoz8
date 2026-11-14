# -*- coding: utf-8 -*-
"""ScarLog IPA 推 Gitee 云更新（复用 CarDash 的 Gitee 压平+回读机制）。

目标（Gitee cardash 仓，与 CarDash 同仓、不同文件互不干扰）：
  - IPA 存 scar/ScarLog.ipa
  - 清单存 scar-ios-update.json（{version,url,size,md5,notes}）

用法（在 d:\\IPA备份 根目录跑）：
  python scar-ios\\tools\\upload_release.py --ipa "D:\\IPA备份\\_work\\ipa1.0.6\\ScarLog-unsigned.ipa" --ios-version 1.0.6 --notes "说明"
"""
import argparse
import hashlib
import io
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.request

_HERE = os.path.dirname(os.path.abspath(__file__))
_IPA = os.path.abspath(os.path.join(_HERE, '..', '..'))
GIT = os.path.join(_IPA, '_env', 'git', 'cmd', 'git.exe')
WORK = os.path.join(_IPA, '_work', 'gitee-cardash')
if not os.path.exists(GIT):
    GIT = 'git'


def read_cfg():
    p = os.path.join(_IPA, '_env', 'gitee.txt')
    cfg = {}
    for line in io.open(p, encoding='utf-8'):
        line = line.strip()
        if '=' in line:
            k, v = line.split('=', 1)
            cfg[k.strip()] = v.strip()
    return cfg


def md5_of(path):
    h = hashlib.md5()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(65536), b''):
            h.update(chunk)
    return h.hexdigest()


def run(args, check=True):
    r = subprocess.run(args, capture_output=True, text=True)
    if check and r.returncode != 0:
        print('[X] 命令失败:', ' '.join(args))
        print((r.stdout or '')[-500:], (r.stderr or '')[-500:])
        sys.exit(1)
    return r


def fetch_remote(base, token):
    req = urllib.request.Request(base + '/raw/master/scar-ios-update.json',
                                 headers={'Authorization': 'Bearer ' + token,
                                          'User-Agent': 'scarlog-release',
                                          'Cache-Control': 'no-cache'})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read().decode('utf-8'))
    except Exception as e:
        print('  [warn] 远端回读失败: %s' % e)
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ipa', required=True)
    ap.add_argument('--ios-version', required=True)
    ap.add_argument('--notes', default='')
    args = ap.parse_args()

    cfg = read_cfg()
    token = cfg.get('TOKEN', '')
    owner = cfg.get('OWNER', '')
    repo = cfg.get('REPO', '')
    base = 'https://gitee.com/%s/%s' % (owner, repo)

    if not os.path.isdir(WORK):
        print('[X] 工作区不存在: %s（先 clone Gitee 仓）' % WORK)
        sys.exit(1)

    ipa_name = 'ScarLog.ipa'
    sub_dir = os.path.join(WORK, 'scar')
    os.makedirs(sub_dir, exist_ok=True)
    shutil.copy(args.ipa, os.path.join(sub_dir, ipa_name))
    print('[OK] IPA -> scar/%s' % ipa_name)

    data = {
        'version': args.ios_version,
        'url': '%s/raw/master/scar/%s' % (base, ipa_name),
        'size': os.path.getsize(args.ipa),
        'md5': md5_of(args.ipa),
        'notes': args.notes,
    }
    with io.open(os.path.join(WORK, 'scar-ios-update.json'), 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print('[OK] scar-ios-update.json 写入', json.dumps(data, ensure_ascii=False))

    # 压平历史 + force push（Gitee 1GB 限制，同 CarDash）
    run([GIT, '-C', WORK, 'branch', '-D', 'slim'], check=False)
    run([GIT, '-C', WORK, 'checkout', '--orphan', 'slim'])
    run([GIT, '-C', WORK, 'add', '-A'])
    run([GIT, '-C', WORK, '-c', 'user.email=scarlog@local', '-c', 'user.name=scarlog',
         'commit', '-m', 'release ScarLog %s' % args.ios_version])
    run([GIT, '-C', WORK, 'branch', '-D', 'master'], check=False)
    run([GIT, '-C', WORK, 'branch', '-m', 'slim', 'master'])
    run([GIT, '-C', WORK, 'push', '-f', 'origin', 'master'])
    print('[OK] 已推送到 Gitee（历史已压平）')

    # 回读自检
    print('回读远端校验 ...')
    remote = fetch_remote(base, token)
    if remote is None or str(remote.get('version')) != str(args.ios_version):
        print('  [..] 第一次回读不一致，等 6 秒再读（Gitee CDN 缓存）')
        time.sleep(6)
        remote = fetch_remote(base, token)
    if remote is None:
        print('[X] 远端回读失败 —— 去 Gitee 网页确认后才算发布完成')
        sys.exit(2)
    print('    远端 scar-ios-update.json: %s' % json.dumps(remote, ensure_ascii=False)[:240])
    if str(remote.get('version')) != str(args.ios_version):
        print('[X] 远端版本不一致（CDN 缓存？等几秒重跑）')
        sys.exit(2)
    print('[OK] 远端已就绪，ScarLog App 下次启动自动检测到新版本。')


if __name__ == '__main__':
    main()
