#!/usr/bin/env python3
"""调试飞书字段响应"""

import requests
import json

APP_ID = "cli_a93b804500badbd6"
APP_SECRET = "4V2hQQH4jsOD6ZFO0a4ZPbhcsVPXrXEH"
APP_TOKEN = "J6NBbj3uEa3wlOsNxedcQWO9nPc"
TABLE_ID = "tblJyNAWMLG1TanI"
BASE_URL = "https://open.feishu.cn/open-apis"

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

def main():
    token = get_access_token()
    field_id = "fldJ8vSBnt"
    url = f"{BASE_URL}/bitable/v1/apps/{APP_TOKEN}/tables/{TABLE_ID}/fields/{field_id}"
    headers = {"Authorization": f"Bearer {token}"}
    resp = requests.get(url, headers=headers)

    print(f"Status Code: {resp.status_code}")
    print(f"Content-Type: {resp.headers.get('Content-Type')}")
    print(f"\nRaw Response:")
    print(resp.text[:2000])

if __name__ == "__main__":
    main()
