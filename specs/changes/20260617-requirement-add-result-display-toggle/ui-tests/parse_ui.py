#!/usr/bin/env python3
"""
UI 树解析工具 (与 harmonyos-ui-test skill 对齐)
- 自动检测 hdc 3.x (JSON dumpLayout) 或 hdc 2.x (XML dump)
- 提供 find_by_text / find_clickable_with_text 等常用查询

模拟器可用时由 run_tests.py 调用, 也可单独用作 debug 工具。
"""

import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from typing import List, Dict, Any, Optional, Tuple


def detect_hdc_api() -> Dict[str, str]:
    """检测 hdc 版本与可用 UI 测试命令。"""
    r = subprocess.run(['hdc', 'version'], capture_output=True, text=True)
    ver = r.stdout.strip()
    help_out = subprocess.run(['hdc', 'shell', 'uitest', 'help'],
                              capture_output=True, text=True).stdout
    cfg = {'version': ver, 'dump_cmd': None, 'dump_format': None,
           'screenshot_cmd': None, 'screenshot_suffix': None}
    if 'dumpLayout' in help_out:
        cfg['dump_cmd'] = 'dumpLayout'
        cfg['dump_format'] = 'json'
    elif 'dump' in help_out:
        cfg['dump_cmd'] = 'dump'
        cfg['dump_format'] = 'xml'
    if 'screenCap' in help_out:
        cfg['screenshot_cmd'] = 'uitest_screenCap'
        cfg['screenshot_suffix'] = '.png'
    else:
        r2 = subprocess.run(['hdc', 'shell', 'snapshot_display', '-h'],
                            capture_output=True, text=True)
        if r2.returncode == 0:
            cfg['screenshot_cmd'] = 'snapshot_display'
            cfg['screenshot_suffix'] = '.jpeg'
    if not cfg['dump_cmd'] or not cfg['screenshot_cmd']:
        raise RuntimeError(f'Unsupported hdc version: {ver}')
    return cfg


def parse_ui_tree(filepath: str) -> List[Dict[str, Any]]:
    """解析 UI 树 dump 文件, 自动适配 JSON (3.x) / XML (2.x)。"""
    with open(filepath, 'rb') as f:
        raw = f.read().decode('utf-8')
    if raw.strip().startswith('{'):
        return _parse_json_tree(raw)
    return _parse_xml_tree(filepath)


def _parse_json_tree(raw: str) -> List[Dict[str, Any]]:
    data = json.loads(raw)
    nodes: List[Dict[str, Any]] = []

    def walk(node: Dict[str, Any]) -> None:
        a = node.get('attributes', {})
        b = a.get('bounds', '')
        m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', b)
        if m:
            l, t, r, btm = map(int, m.groups())
            cx, cy = (l + r) // 2, (t + btm) // 2
        else:
            l = t = r = btm = cx = cy = 0
        nodes.append({
            'text': a.get('text', ''),
            'description': a.get('description', ''),
            'class': a.get('type', ''),
            'resource_id': a.get('id', ''),
            'clickable': a.get('clickable', '') == 'true',
            'checked': a.get('checked', '') == 'true',
            'enabled': a.get('enabled', '') == 'true',
            'bounds': (l, t, r, btm),
            'center': (cx, cy),
            'width': r - l, 'height': btm - t,
        })
        for c in node.get('children', []):
            walk(c)

    walk(data)
    return nodes


def _parse_xml_tree(path: str) -> List[Dict[str, Any]]:
    tree = ET.parse(path)
    nodes: List[Dict[str, Any]] = []
    for elem in tree.iter():
        b = elem.get('bounds', '')
        m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', b)
        if not m:
            continue
        l, t, r, btm = map(int, m.groups())
        nodes.append({
            'text': elem.get('text', ''),
            'class': elem.get('class', ''),
            'resource_id': elem.get('resource-id', ''),
            'clickable': elem.get('clickable', 'false') == 'true',
            'checked': elem.get('checked', 'false') == 'true',
            'enabled': elem.get('enabled', 'false') == 'true',
            'bounds': (l, t, r, btm),
            'center': ((l + r) // 2, (t + btm) // 2),
            'width': r - l, 'height': btm - t,
        })
    return nodes


def find_by_text(nodes: List[Dict[str, Any]], text: str,
                 exact: bool = True) -> List[Dict[str, Any]]:
    if exact:
        return [n for n in nodes if n['text'] == text]
    return [n for n in nodes if text in n['text']]


def find_clickable_with_text(nodes: List[Dict[str, Any]],
                             text: str) -> List[Dict[str, Any]]:
    return [n for n in nodes
            if n['clickable'] and text in (n['text'] or '')]


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('Usage: parse_ui.py <dump_file> [search_text]')
        sys.exit(1)
    nodes = parse_ui_tree(sys.argv[1])
    print(f'# parsed {len(nodes)} nodes')
    if len(sys.argv) > 2:
        target = sys.argv[2]
        hits = find_by_text(nodes, target, exact=False)
        print(f'# {len(hits)} hits for "{target}":')
        for n in hits[:5]:
            print(f'  text={n["text"]!r} center={n["center"]} '
                  f'class={n["class"]} id={n["resource_id"]}')
    else:
        clickables = [n for n in nodes if n['clickable']]
        print(f'# {len(clickables)} clickable nodes:')
        for n in clickables[:10]:
            print(f'  text={n["text"]!r} center={n["center"]} '
                  f'class={n["class"]}')
