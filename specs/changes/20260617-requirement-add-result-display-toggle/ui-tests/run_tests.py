#!/usr/bin/env python3
"""
AC-1~5 UI 自动化执行脚本 (Issue #27 result-display-toggle)

前置条件:
- hdc 已安装且在 PATH
- 模拟器 127.0.0.1:5555 已启动 (`hdc list targets` 非空)
- HAP 已 build (`hvigorw assembleHap` 成功) 并 install

执行:
  cd "D:/huawei/Demo/worktrees/issue-27"
  python3 specs/changes/20260617-requirement-add-result-display-toggle/ui-tests/run_tests.py

产物:
  - screenshot/ac{N}_{name}.png
  - dump/ac{N}_{name}.xml
  - results.json (更新)
"""

import json
import os
import subprocess
import sys
import time
from typing import List, Dict, Any, Optional

from parse_ui import (
    detect_hdc_api, parse_ui_tree, find_by_text, find_clickable_with_text,
)

BUNDLE = 'com.darkempire78.opencalculator'
ABILITY = 'EntryAbility'
TEST_DIR = os.path.dirname(os.path.abspath(__file__))
SCREENSHOT_DIR = os.path.join(TEST_DIR, 'screenshot')
DUMP_DIR = os.path.join(TEST_DIR, 'dump')
RESULTS_FILE = os.path.join(TEST_DIR, 'results.json')
PORT = '127.0.0.1:5555'


def hdc_shell(args: List[str]) -> subprocess.CompletedProcess:
    return subprocess.run(['hdc', '-t', PORT, 'shell'] + args,
                          capture_output=True, text=True)


def hdc_dump(hdc_api: Dict[str, str], local_path: str) -> bool:
    remote = '/data/local/tmp/_uidump.xml'
    cmd_map = {'dumpLayout': 'dumpLayout', 'dump': 'dump'}
    dump_cmd = cmd_map.get(hdc_api['dump_cmd'], 'dump')
    fmt_flag = {'json': '-j', 'xml': '-x'}.get(hdc_api['dump_format'], '-x')
    r = hdc_shell(['uitest', dump_cmd, fmt_flag, '-p', remote])
    if r.returncode != 0:
        print(f'  [FAIL] dump: {r.stderr}')
        return False
    r2 = subprocess.run(
        ['hdc', '-t', PORT, 'file', 'recv', remote, local_path],
        capture_output=True, text=True)
    return r2.returncode == 0 and os.path.exists(local_path)


def hdc_screenshot(hdc_api: Dict[str, str], local_path: str) -> bool:
    suffix = hdc_api['screenshot_suffix']
    remote = f'/data/local/tmp/_screenshot{suffix}'
    if hdc_api['screenshot_cmd'] == 'uitest_screenCap':
        hdc_shell(['uitest', 'screenCap', '-p', remote])
    else:
        hdc_shell(['snapshot_display', '-f', remote])
    r = subprocess.run(
        ['hdc', '-t', PORT, 'file', 'recv', remote, local_path],
        capture_output=True, text=True)
    return r.returncode == 0 and os.path.exists(local_path)


def hdc_click(x: int, y: int) -> None:
    hdc_shell(['uitest', 'uiInput', 'click', str(x), str(y)])
    time.sleep(0.3)


def hdc_swipe(x1: int, y1: int, x2: int, y2: int) -> None:
    hdc_shell(['uitest', 'uiInput', 'swipe', str(x1), str(y1),
               str(x2), str(y2)])
    time.sleep(0.5)


def start_app() -> None:
    hdc_shell(['aa', 'force-stop', BUNDLE])
    time.sleep(0.5)
    hdc_shell(['aa', 'start', '-a', ABILITY, '-b', BUNDLE])
    time.sleep(2.0)


def click_digit(d: str) -> None:
    """根据 CalculatorPage 布局, 数字按钮位于右侧 4 列网格 (0~9 + .)。
    屏幕 1260x2720 (Phone 典型), 数字区估算坐标 (按视觉布局)。"""
    coords = {
        '0': (900, 2000), '1': (600, 1800), '2': (900, 1800),
        '3': (1200, 1800), '4': (600, 1600), '5': (900, 1600),
        '6': (1200, 1600), '7': (600, 1400), '8': (900, 1400),
        '9': (1200, 1400), '.': (1200, 2000),
        '+': (1200, 1100), '-': (900, 1100), '*': (600, 1100),
        '/': (300, 1100), '=': (1200, 2200), 'AC': (300, 800),
    }
    x, y = coords[d]
    hdc_click(x, y)


def find_result_text(nodes: List[Dict[str, Any]]) -> Optional[str]:
    """查找结果显示区 Text 节点 (resource-id 含 'result'/'display' 或无 id 但在顶部)。"""
    candidates = [n for n in nodes
                  if 'result' in (n.get('resource_id') or '').lower()
                  or 'display' in (n.get('resource_id') or '').lower()]
    if not candidates:
        candidates = sorted([n for n in nodes if n.get('text', '').strip()],
                            key=lambda n: -n['width'] * n['height'])[:3]
    if not candidates:
        return None
    return candidates[0]['text']


def run_ac(hdc_api: Dict[str, str], ac: Dict[str, Any]) -> Dict[str, Any]:
    print(f'\n=== {ac["id"]}: {ac["description"]} ===')
    ac_id = ac['id'].lower()
    dump_path = os.path.join(DUMP_DIR, f'{ac_id}.xml')
    shot_path = os.path.join(SCREENSHOT_DIR, f'{ac_id}.png')

    hdc_dump(hdc_api, dump_path)
    hdc_screenshot(hdc_api, shot_path)

    nodes = parse_ui_tree(dump_path) if os.path.exists(dump_path) else []
    actual = find_result_text(nodes) if nodes else None
    expected = ac['expected_text']
    passed = (actual == expected) if (actual and expected) else False

    return {
        'id': ac['id'],
        'description': ac['description'],
        'expected': expected,
        'actual': actual,
        'screenshot': shot_path if os.path.exists(shot_path) else None,
        'dump': dump_path if os.path.exists(dump_path) else None,
        'status': 'passed' if passed else 'failed',
    }


def main() -> int:
    print('hdc version probe...')
    hdc_api = detect_hdc_api()
    print(f'  hdc {hdc_api["version"]} '
          f'dump={hdc_api["dump_cmd"]}({hdc_api["dump_format"]}) '
          f'screenshot={hdc_api["screenshot_cmd"]}{hdc_api["screenshot_suffix"]}')

    # 设备检查
    r = subprocess.run(['hdc', 'list', 'targets'], capture_output=True, text=True)
    targets = r.stdout.strip()
    if not targets or targets == '[Empty]':
        print('FATAL: hdc list targets empty. 启动 127.0.0.1:5555 模拟器后重试。')
        return 2
    print(f'  connected: {targets}')

    os.makedirs(SCREENSHOT_DIR, exist_ok=True)
    os.makedirs(DUMP_DIR, exist_ok=True)

    # 启动 app
    print('starting app...')
    start_app()

    # 加载已有 results.json
    with open(RESULTS_FILE, 'r', encoding='utf-8') as f:
        results = json.load(f)
    results['executed'] = True
    results['status'] = 'running'
    results['test_session'] = time.strftime('%Y-%m-%d_%H%M')

    acs = results['ac_results']
    new_acs = []

    # AC-1: 1 ÷ 2 = 显示 0.5
    print('\n[AC-1] tap 1, /, 2, =')
    click_digit('AC')
    time.sleep(0.5)
    click_digit('1')
    click_digit('/')
    click_digit('2')
    click_digit('=')
    time.sleep(1.0)
    new_acs.append(run_ac(hdc_api, acs[0]))

    # AC-2: 点击切换按钮
    print('\n[AC-2] tap toggle button')
    nodes = parse_ui_tree(
        os.path.join(DUMP_DIR, 'ac-1.xml')) if os.path.exists(
        os.path.join(DUMP_DIR, 'ac-1.xml')) else []
    toggle_candidates = [n for n in nodes if n['clickable'] and
                         ('1/2' in n['text'] or '0.5' in n['text'])]
    if toggle_candidates:
        t = toggle_candidates[0]
        hdc_click(*t['center'])
        time.sleep(0.5)
    new_acs.append(run_ac(hdc_api, acs[1]))

    # AC-3: 再次点击
    print('\n[AC-3] tap toggle button (again)')
    if toggle_candidates:
        hdc_click(*toggle_candidates[0]['center'])
        time.sleep(0.5)
    new_acs.append(run_ac(hdc_api, acs[2]))

    # AC-4: 重启 app
    print('\n[AC-4] force-stop + start, mode should be FRACTION')
    # 先切到 FRACTION
    if toggle_candidates:
        hdc_click(*toggle_candidates[0]['center'])
        time.sleep(0.5)
    # 重启
    start_app()
    new_acs.append(run_ac(hdc_api, acs[3]))

    # AC-5: 历史记录保持小数
    print('\n[AC-5] history decimal preservation')
    click_digit('AC')
    time.sleep(0.5)
    click_digit('1')
    click_digit('/')
    click_digit('3')
    click_digit('=')
    time.sleep(1.0)
    new_acs.append(run_ac(hdc_api, acs[4]))

    # 汇总
    passed = sum(1 for a in new_acs if a['status'] == 'passed')
    failed = sum(1 for a in new_acs if a['status'] == 'failed')
    results['ac_results'] = new_acs
    results['status'] = 'completed'
    results['summary'] = {
        'total_acs': len(new_acs),
        'passed': passed,
        'failed': failed,
        'blocked': 0,
        'deferred': 0,
        'pass_rate': f'{passed}/{len(new_acs)}',
    }
    with open(RESULTS_FILE, 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=2, ensure_ascii=False)

    print(f'\n=== SUMMARY: {passed}/{len(new_acs)} PASSED ===')
    return 0 if failed == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
