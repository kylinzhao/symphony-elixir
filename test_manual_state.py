#!/usr/bin/env python3
"""等待用户在飞书界面手动设置状态，然后检查格式"""

import requests
import json
import time

APP_ID = "cli_a93b804500badbd6"
APP_SECRET = "4V2hQQH4jsOD6ZFO0a4ZPbhcsVPXrXEH"
APP_TOKEN = "J6NBbj3uEa3wlOsNxedcQWO9nPc"
TABLE_ID = "tblJyNAWMLG1TanI"
BASE_URL = "https://open.feishu.cn/open-apis"

TEST_RECORD_ID = "recajevnCU"  # 五子棋记录

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

def get_record(record_id):
    """获取记录详情"""
    token = get_access_token()
    url = f"{BASE_URL}/bitable/v1/apps/{APP_TOKEN}/tables/{TABLE_ID}/records/{record_id}"
    headers = {"Authorization": f"Bearer {token}"}
    resp = requests.get(url, headers=headers)
    data = resp.json()

    if data.get("code") == 0:
        return data.get("data", {})
    else:
        return None

def get_field_detail(field_id):
    """获取字段详情"""
    token = get_access_token()
    url = f"{BASE_URL}/bitable/v1/apps/{APP_TOKEN}/tables/{TABLE_ID}/fields/{field_id}"
    headers = {"Authorization": f"Bearer {token}"}
    resp = requests.get(url, headers=headers)
    data = resp.json()

    return data

def main():
    print("=" * 70)
    print("飞书单选字段存储格式测试")
    print("=" * 70)

    print("\n请在飞书界面中执行以下操作：")
    print(f"1. 打开表格: https://my.feishu.cn/base/{APP_TOKEN}?table={TABLE_ID}")
    print(f"2. 找到 '五子棋' 记录 (ID: {TEST_RECORD_ID})")
    print("3. 将其状态设置为 '待处理' (或任何其他状态)")
    print("\n设置完成后，按回车键继续...")
    input()

    print("\n正在读取记录...")
    record = get_record(TEST_RECORD_ID)

    if not record:
        print("获取记录失败!")
        return

    fields = record.get("fields", {})
    state_value = fields.get("状态")

    print("\n" + "=" * 70)
    print("记录详情:")
    print("=" * 70)
    print(f"\n标题: {fields.get('标题', 'N/A')}")
    print(f"\n状态字段值:")
    print(f"  原始值: {repr(state_value)}")
    print(f"  类型: {type(state_value).__name__}")

    if isinstance(state_value, list):
        print(f"  列表长度: {len(state_value)}")
        if len(state_value) > 0:
            print(f"  第一个元素:")
            first = state_value[0]
            print(f"    值: {repr(first)}")
            print(f"    类型: {type(first).__name__}")
            if isinstance(first, dict):
                print(f"    键: {list(first.keys())}")
                for k, v in first.items():
                    print(f"    {k}: {repr(v)}")
    elif isinstance(state_value, str):
        print(f"  字符串内容: {state_value}")
    elif isinstance(state_value, dict):
        print(f"  字典键: {list(state_value.keys())}")
        for k, v in state_value.items():
            print(f"  {k}: {repr(v)}")

    # 同时获取字段详情
    print("\n" + "=" * 70)
    print("获取字段详情...")
    print("=" * 70)

    field_detail = get_field_detail("fldJ8vSBnt")
    print(f"\n字段详情响应:")
    print(json.dumps(field_detail, ensure_ascii=False, indent=2))

    print("\n" + "=" * 70)
    print("结论:")
    print("=" * 70)
    print("请查看上面的输出，确定:")
    print("1. 单选字段的存储格式（字符串? 数组? 对象?）")
    print("2. API 返回的字段类型（type 值）")
    print("=" * 70)

if __name__ == "__main__":
    main()
