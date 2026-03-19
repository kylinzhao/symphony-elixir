#!/usr/bin/env python3
"""测试用选项名称更新状态（像优先级字段一样）"""

import requests
import json
import time

APP_ID = "cli_a93b804500badbd6"
APP_SECRET = "4V2hQQH4jsOD6ZFO0a4ZPbhcsVPXrXEH"
APP_TOKEN = "J6NBbj3uEa3wlOsNxedcQWO9nPc"
TABLE_ID = "tblJyNAWMLG1TanI"
BASE_URL = "https://open.feishu.cn/open-apis"

TEST_RECORD_ID = "recajevnCU"  # 五子棋

def get_access_token():
    """获取 tenant_access_token"""
    url = f"{BASE_URL}/auth/v3/tenant_access_token/internal"
    body = {
        "app_id": APP_ID,
        "app_secret": APP_SECRET
    }
    resp = requests.post(url, json=body)
    data = resp.json()
    if data.get("code") == 0:
        return data.get("tenant_access_token")
    else:
        raise Exception(f"Failed to get token: {data}")

def update_with_option_name(record_id, state_name):
    """使用选项名称更新状态（像优先级一样）"""
    token = get_access_token()
    url = f"{BASE_URL}/bitable/v1/apps/{APP_TOKEN}/tables/{TABLE_ID}/records/{record_id}"
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

    body = {
        "fields": {
            "状态": state_name  # 使用选项名称，而不是选项 ID
        }
    }

    print(f"\n更新请求 (使用选项名称):")
    print(json.dumps(body, ensure_ascii=False, indent=2))

    resp = requests.put(url, headers=headers, json=body)
    result = resp.json()

    print(f"\n响应: code={result.get('code')}, msg={result.get('msg')}")
    if result.get("code") == 0:
        record = result.get("data", {}).get("record", {})
        state = record.get("fields", {}).get("状态")
        print(f"更新后的状态值: {repr(state)}")

    return result

def get_record(record_id):
    """获取记录"""
    token = get_access_token()
    url = f"{BASE_URL}/bitable/v1/apps/{APP_TOKEN}/tables/{TABLE_ID}/records/{record_id}"
    headers = {"Authorization": f"Bearer {token}"}
    resp = requests.get(url, headers=headers)
    data = resp.json()

    if data.get("code") == 0:
        return data.get("data", {})
    return None

def main():
    print("=" * 70)
    print("测试用选项名称更新状态（参考优先级字段的存储方式）")
    print("=" * 70)

    # 优先级字段存储的是名称 'P1'，不是 ID
    # 让我们试试用名称更新状态

    test_states = ["待处理", "需求评估中", "设计中", "已完成"]

    for state_name in test_states:
        print(f"\n{'=' * 70}")
        print(f"测试状态: {state_name}")
        print("=" * 70)

        result = update_with_option_name(TEST_RECORD_ID, state_name)

        if result.get("code") == 0:
            print("✓ 更新成功!")

            time.sleep(1)

            # 检查结果
            record = get_record(TEST_RECORD_ID)
            if record:
                fields = record.get("fields", {})
                state_value = fields.get("状态")

                print(f"\n读取到的状态值: {repr(state_value)}")

                if isinstance(state_value, str):
                    if state_value == state_name:
                        print(f"✓ 状态正确存储为名称: {state_value}")
                    elif state_value.startswith("opt"):
                        print(f"✗ 状态存储为 ID: {state_value}")
                    else:
                        print(f"? 状态值: {state_value}")

            time.sleep(1)
        else:
            print(f"✗ 更新失败: {result.get('msg')}")
            error = result.get("error", {})
            if error:
                print(f"  错误详情: {error.get('message', '')}")

            # 如果失败，停止测试
            break

if __name__ == "__main__":
    main()
