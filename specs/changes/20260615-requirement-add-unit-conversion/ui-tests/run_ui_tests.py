#!/usr/bin/env python3
# aid-workflow 20260615: Issue #14 单位换算 UI 自动化测试
# 跑测环境要求:hdc 在 PATH 或指定路径;HarmonyOS 模拟器 127.0.0.1:5555 已运行
# 本次 re-dispatch 实际执行:hdc server 连接失败(环境问题),无法 install/启动应用
#   → 详见 apply-report.md §6.5 诚实记录
# 此脚本在 hdc 恢复后可单独执行,产出截图 + dump + results.json

"""
6 个测试场景:
  AC-UC-01: 输入"100厘米转英寸" → 截图 result=39.3700787
  AC-UC-02: 输入"30摄氏度转华氏度" → 截图 result=86
  AC-UC-06: 输入"100cm to inch" → 截图 result=39.3700787
  AC-UC-09: 输入"1米转千克" → 截图 错误提示
  AC-UC-10: 输入"1+2" → 截图 result=3(原计算,不触发 NL)
  AC-UC-13: 输入"1 kg to g" → 截图 result=1000
"""

import json
import subprocess
import sys
import time
from pathlib import Path

HDC = r"D:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe"
DEVICE = "127.0.0.1:5555"
BUNDLE = "com.darkempire78.opencalculator"
HAP_PATH = r"D:/huawei/Demo/worktrees/issue-14/opencalc/entry/build/default/outputs/default/entry-default-unsigned.hap"

OUT_DIR = Path(__file__).parent
SCREENSHOT_DIR = OUT_DIR / "screenshot"
DUMP_DIR = OUT_DIR / "dump"
RESULTS_FILE = OUT_DIR / "results.json"

TESTS = [
    {
        "id": "ac_uc_01",
        "input": "100厘米转英寸",
        "expected_result": "39.3700787",
        "description": "中文 NL: 100cm → inch"
    },
    {
        "id": "ac_uc_02",
        "input": "30摄氏度转华氏度",
        "expected_result": "86",
        "description": "中文 NL: 30°C → °F"
    },
    {
        "id": "ac_uc_06",
        "input": "100cm to inch",
        "expected_result": "39.3700787",
        "description": "英文 NL: 100cm → inch"
    },
    {
        "id": "ac_uc_09",
        "input": "1米转千克",
        "expected_result": "ERROR",
        "description": "跨类换算: m → kg 应降级为错误"
    },
    {
        "id": "ac_uc_10",
        "input": "1+2",
        "expected_result": "3",
        "description": "普通表达式: 不触发 NL"
    },
    {
        "id": "ac_uc_13",
        "input": "1 kg to g",
        "expected_result": "1000",
        "description": "英文 NL: 1kg → g"
    }
]


def hdc(*args, check=True):
    """运行 hdc 命令并返回 stdout"""
    cmd = [HDC, "-s", DEVICE] + list(args)
    result = subprocess.run(cmd, capture_output=True, text=True)
    if check and result.returncode != 0:
        raise RuntimeError(f"hdc command failed: {cmd}\n{result.stderr}")
    return result.stdout


def setup():
    """安装 HAP 并启动应用"""
    SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)
    DUMP_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Installing HAP: {HAP_PATH}")
    hdc("install", "-r", HAP_PATH)
    print(f"Starting app: {BUNDLE}")
    hdc("shell", "aa", "start", "-b", BUNDLE, "-a", "EntryAbility")
    time.sleep(3)


def teardown():
    """停止应用"""
    hdc("shell", "aa", "force-stop", BUNDLE, check=False)


def dump_ui(label):
    """导出 UI 树到 dump/<label>.json"""
    hdc("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    hdc("shell", "cat", "/sdcard/ui.xml")
    # 简化:实际应解析 ui.xml
    dump_file = DUMP_DIR / f"{label}.json"
    dump_file.write_text("{}", encoding="utf-8")


def screenshot(label):
    """截图到 screenshot/<label>.png"""
    hdc("shell", "screenshot", "/sdcard/screen.png")
    hdc("file", "recv", "/sdcard/screen.png", str(SCREENSHOT_DIR / f"{label}.png"))


def input_text(text):
    """通过 uinput 输入文本"""
    hdc("shell", "input", "text", text)


def click_equals():
    """点击等号按钮(坐标示例)"""
    hdc("shell", "input", "tap", "850", "2200")


def click_ac():
    """点击 AC 按钮"""
    hdc("shell", "input", "tap", "100", "1000")


def get_result_text():
    """读取 result 区域文字(简化:返回 placeholder)"""
    return "(parse from dump)"


def run_test(test):
    """执行单个测试"""
    print(f"\n[RUN] {test['id']}: {test['description']}")
    click_ac()
    time.sleep(0.5)
    input_text(test["input"])
    time.sleep(0.5)
    click_equals()
    time.sleep(1)
    dump_ui(test["id"])
    screenshot(test["id"])
    actual = get_result_text()
    passed = actual == test["expected_result"]
    return {
        "id": test["id"],
        "description": test["description"],
        "input": test["input"],
        "expected": test["expected_result"],
        "actual": actual,
        "passed": passed,
        "screenshot": f"screenshot/{test['id']}.png",
        "dump": f"dump/{test['id']}.json"
    }


def main():
    if not Path(HAP_PATH).exists():
        print(f"ERROR: HAP not found: {HAP_PATH}", file=sys.stderr)
        sys.exit(1)
    setup()
    results = []
    try:
        for test in TESTS:
            try:
                results.append(run_test(test))
            except Exception as e:
                results.append({
                    "id": test["id"],
                    "description": test["description"],
                    "error": str(e),
                    "passed": False
                })
    finally:
        teardown()
    RESULTS_FILE.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    passed = sum(1 for r in results if r.get("passed"))
    total = len(results)
    print(f"\n{'='*50}")
    print(f"UI 测试结果: {passed}/{total} PASS")
    print(f"详见 {RESULTS_FILE}")


if __name__ == "__main__":
    main()
