import json
import os
import urllib.request
import boto3

_ssm = boto3.client("ssm")
_webhook_url = None

RED, GREEN, GREY, ORANGE = 0xE74C3C, 0x2ECC71, 0x95A5A6, 0xF39C12

STATES = {
    "ALARM": ("🔴 장애 발생", RED),
    "OK": ("🟢 복구", GREEN),
    "INSUFFICIENT_DATA": ("⚪ 데이터 없음", GREY),
}

def _webhook():
    global _webhook_url
    if _webhook_url is None:
        param = _ssm.get_parameter(Name=os.environ["WEBHOOK_PARAM"], WithDecryption=True)
        _webhook_url = param["Parameter"]["Value"]
    return _webhook_url

def _embed(message):
    try:
        data = json.loads(message)
    except ValueError:
        data = None

    # CloudWatch 알람
    if isinstance(data, dict) and "AlarmName" in data:
        title, color = STATES.get(data.get("NewStateValue"), ("알림", GREY))
        return {
            "title": f"{title} | {data['AlarmName']}",
            "description": data.get("NewStateReason", "")[:2000],
            "color": color,
        }

    # 직접 만든 형식
    if isinstance(data, dict) and "title" in data:
        extra = {k: v for k, v in data.items() if k not in ("title", "description")}
        return {
            "title": str(data["title"]),
            "description": str(data.get("description", ""))[:2000],
            "color": RED,
            "fields": [{"name": k, "value": str(v)[:1000]} for k, v in extra.items()],
        }

    # AWS Budgets 알림
    if "Budget" in message[:300]:
        return {"title": "💸 예산 알림", "description": message[:2000], "color": ORANGE}
    return {"title": "AWS 알림", "description": message[:2000], "color": GREY}

def handler(event, context):
    for record in event["Records"]:
        body = json.dumps({"embeds": [_embed(record["Sns"]["Message"])]}).encode()
        req = urllib.request.Request(
            _webhook(),
            data=body,
            headers={"Content-Type": "application/json", "User-Agent": "pv-alarm-notifier"},
        )
        urllib.request.urlopen(req, timeout=5)