# -*- coding: utf-8 -*-
"""ScarLog IPA 取包（复用 CarDash fetch_ipa 的 atom 查 tag + gh-proxy 加速下载）。

用法（在 d:\\IPA备份 根目录跑）：
  python scar-ios\\tools\\fetch_ipa.py --check                     # 只看最新 tag
  python scar-ios\\tools\\fetch_ipa.py --wait --baseline build-N --ver 1.0.6
  python scar-ios\\tools\\fetch_ipa.py --tag build-N --ver 1.0.6
"""
import argparse
import os
import re
import sys
import time
import urllib.request

try:
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
except Exception:
    pass

PROXY = 'https://gh-proxy.com/'
ASSET = 'ScarLog-unsigned.ipa'
SLUG = 'FanXia5280/1sajoz8'
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
UA = {'User-Agent': 'scarlog-fetch-ipa'}


def say(msg):
    print(msg)
    try:
        sys.stdout.flush()
    except Exception:
        pass


def remote_tags(tries=3):
    url = 'https://github.com/%s/releases.atom' % SLUG
    last = '未知'
    for k in range(1, tries + 1):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=8) as r:
                text = r.read().decode('utf-8', 'replace')
            tags = re.findall(r'/releases/tag/(build-\d+)', text)
            if tags:
                return sorted(set(tags), key=lambda t: int(t.split('-')[1]))
            last = 'feed 里没有 build-N tag'
        except Exception as e:
            last = str(e)
        if k < tries:
            say('  [warn] 取 tag 第 %d/%d 次失败：%s —— 重试' % (k, tries, last))
            time.sleep(1.5 * k)
    say('  [warn] 取 tag 失败（%s）：%s' % (url, last))
    return []


def _download_once(url, dest, use_proxy=True):
    if use_proxy:
        url = PROXY + url
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    tmp = dest + '.part'
    t0 = time.time()
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=60) as r, open(tmp, 'wb') as f:
        total = int(r.headers.get('Content-Length') or 0)
        got, mark = 0, -10
        while True:
            chunk = r.read(262144)
            if not chunk:
                break
            f.write(chunk)
            got += len(chunk)
            if total:
                pct = got * 100 // total
                if pct >= mark + 10:
                    mark = pct
                    say('  ...%d%%  %.1fMB  %.2fMB/s'
                        % (pct, got / 1048576.0, got / 1048576.0 / max(time.time() - t0, 1e-6)))
    os.replace(tmp, dest)
    dt = max(time.time() - t0, 1e-6)
    size_mb = os.path.getsize(dest) / 1048576.0
    say('[OK] %s  %.2fMB  用时 %.1fs  %.2fMB/s' % (dest, size_mb, dt, size_mb / dt))
    return dest


def download(url, dest, use_proxy=True, tries=4):
    last = None
    for k in range(tries):
        try:
            return _download_once(url, dest, use_proxy)
        except Exception as e:
            last = e
            say('  [warn] 下载中断（第 %d/%d 次）: %s' % (k + 1, tries, e))
            if k + 1 < tries:
                time.sleep(2 + k * 2)
    raise last


def main():
    ap = argparse.ArgumentParser(description='取 ScarLog IPA（atom 查 tag + gh-proxy 下载）')
    ap.add_argument('--wait', action='store_true')
    ap.add_argument('--baseline', default=None)
    ap.add_argument('--tag', default=None)
    ap.add_argument('--ver', default=None)
    ap.add_argument('--out', default=None)
    ap.add_argument('--interval', type=int, default=25)
    ap.add_argument('--timeout', type=int, default=2400)
    ap.add_argument('--check', action='store_true')
    args = ap.parse_args()

    tags = remote_tags()
    if tags:
        say('仓库 %s，当前最新 tag：%s' % (SLUG, tags[-1]))

    if args.tag:
        tag = args.tag
    elif args.wait:
        base = args.baseline or (tags[-1] if tags else None)
        if base is None:
            say('[X] 拿不到 tag，也没有 --baseline —— 加 --baseline build-N')
            return 1
        say('等新包中：每 %d 秒查一次 releases.atom（基线 %s）' % (args.interval, base))
        t0, tag, rounds = time.time(), None, 0
        while time.time() - t0 < args.timeout:
            time.sleep(args.interval)
            rounds += 1
            cur = remote_tags()
            if cur and cur[-1] != base:
                tag = cur[-1]
                say('★ 新包出来了：%s（第 %d 轮，等了 %ds）—— 开始下载 …'
                    % (tag, rounds, int(time.time() - t0)))
                break
            say('  [%s] 第 %d 轮：最新还是 %s —— 继续等（已等 %ds）'
                % (time.strftime('%H:%M:%S'), rounds,
                   (cur[-1] if cur else '取不到'), int(time.time() - t0)))
        if tag is None:
            say('[X] 等超时 —— 去 Actions 页面看卡在哪步')
            return 2
    elif not tags:
        say('[X] 拿不到 tag（atom 失败）—— 检查直连 github.com')
        return 1
    else:
        tag = tags[-1]

    url = 'https://github.com/%s/releases/download/%s/%s' % (SLUG, tag, ASSET)
    say('包：%s' % url)
    say('加速链：%s%s' % (PROXY, url))
    if args.check:
        return 0

    folder = 'ipa' + (args.ver or tag)
    dest = args.out or os.path.join(ROOT, '_work', folder, ASSET)
    try:
        download(url, dest)
    except Exception as e:
        say('[X] 下载失败（%s）：%s' % (url, e))
        return 3
    return 0


if __name__ == '__main__':
    sys.exit(main())
