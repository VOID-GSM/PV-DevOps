import json
import os
import re
import urllib.request
from datetime import datetime, timezone

import boto3

_ssm = boto3.client("ssm")
_webhook_url = None

BOT_NAME = "PV 모니터링"
RED, GREEN, GREY, ORANGE, BLUE = 0xE74C3C, 0x2ECC71, 0x95A5A6, 0xF39C12, 0x3498DB

def _bool(ok_text, fail_text):
    return lambda v: fail_text if v < 1 else ok_text

METRICS = {
    "CPUUtilization": ("CPU 사용률", lambda v: f"{v:.1f}%", True),
    "CPUCreditBalance": ("CPU 크레딧", lambda v: f"{v:.0f}", True),
    "StatusCheckFailed_System": ("하드웨어 상태", lambda v: "실패" if v >= 1 else "정상", False),
    "StatusCheckFailed_Instance": ("OS 상태", lambda v: "실패" if v >= 1 else "정상", False),
    "Success": ("접속 확인", _bool("성공", "실패"), False),
}

AUTO_ACTIONS = {
    ":recover": "🔧 다른 물리 서버로 자동 복구를 시작했어요.",
    ":reboot": "🔄 서버를 자동으로 재부팅했어요.",
}

def _webhook():
    global _webhook_url
    if _webhook_url is None:
        param = _ssm.get_parameter(Name=os.environ["WEBHOOK_PARAM"], WithDecryption=True)
        _webhook_url = param["Parameter"]["Value"]
    return _webhook_url

def _iso(text):
    try:
        return datetime.strptime(text[:19], "%Y-%m-%dT%H:%M:%S").replace(tzinfo=timezone.utc).isoformat()
    except (TypeError, ValueError):
        return None

def _latest_value(reason):
    m = re.search(r"\[(-?[\d.]+) \(", reason or "")
    return float(m.group(1)) if m else None

def _from_alarm(data):
    new, old = data.get("NewStateValue"), data.get("OldStateValue")

    # 알람을 만든 직후의 '데이터 없음 → 정상'은 복구가 아니므로 보내지 않음
    if new == "OK" and old != "ALARM":
        return None

    trigger = data.get("Trigger") or {}
    metric = trigger.get("MetricName", "")
    label, fmt, show_threshold = METRICS.get(metric, (metric or "지표", lambda v: f"{v:g}", True))
    title = data.get("AlarmDescription") or data.get("AlarmName", "알람")
    value = _latest_value(data.get("NewStateReason"))

    fields = [{"name": label, "value": fmt(value) if value is not None else "데이터 없음", "inline": True}]
    if show_threshold and "Threshold" in trigger:
        fields.append({"name": "기준", "value": fmt(float(trigger["Threshold"])), "inline": True})

    embed = {"fields": fields, "timestamp": _iso(data.get("StateChangeTime"))}
    if new == "ALARM":
        actions = data.get("AlarmActions") or []
        notes = [msg for key, msg in AUTO_ACTIONS.items() if any(key in a for a in actions)]
        embed.update(title=f"🔴 장애 | {title}", description="\n".join(notes), color=RED)
    elif new == "OK":
        embed.update(title=f"🟢 복구 | {title}", color=GREEN)
    else:
        embed.update(title=f"⚪ 데이터 없음 | {title}", color=GREY)
    return embed


def _from_budget(message):
    info = dict(re.findall(r"^([A-Za-z ]+): (.+)$", message, re.M))
    kind = "예상" if info.get("Alert Type") == "FORECASTED" else "실제"
    amount = info.get("ACTUAL Amount") or info.get("FORECASTED Amount") or "-"
    return {
        "title": f"💸 예산 알림 | {info.get('Budget Name', '-')}",
        "description": f"이번 달 {kind} 비용이 알림 기준을 넘었어요.",
        "color": ORANGE,
        "fields": [
            {"name": f"{kind} 금액", "value": amount, "inline": True},
            {"name": "알림 기준", "value": info.get("Alert Threshold", "-"), "inline": True},
            {"name": "월 예산", "value": info.get("Budgeted Amount", "-"), "inline": True},
        ],
    }


def _from_event(data):
    detail = data.get("detail") or {}
    if data.get("source") == "aws.backup":
        title = "⚠️ 백업 실패"
    else:
        title = f"⚠️ {data.get('detail-type', 'AWS 이벤트')}"
    lines = [f"상태: {detail.get('state', '-')}"]
    if detail.get("statusMessage"):
        lines.append(str(detail["statusMessage"]))
    return {"title": title, "description": "\n".join(lines)[:2000], "color": ORANGE, "timestamp": _iso(data.get("time"))}


def _embed(message):
    try:
        data = json.loads(message)
    except ValueError:
        data = None

    if isinstance(data, dict):
        if "AlarmName" in data:  # CloudWatch 알람
            return _from_alarm(data)
        if "detail-type" in data:  # EventBridge 이벤트 (백업 실패 등)
            return _from_event(data)
        if "title" in data:  # 직접 만든 형식
            extra = {k: v for k, v in data.items() if k not in ("title", "description")}
            return {
                "title": str(data["title"]),
                "description": str(data.get("description", ""))[:2000],
                "color": RED,
                "fields": [{"name": k, "value": str(v)[:1000]} for k, v in extra.items()],
            }

    if "Budget" in message[:300]:  # AWS Budgets
        return _from_budget(message)
    return {"title": "📢 AWS 알림", "description": message[:2000], "color": BLUE}


def handler(event, context):
    for record in event["Records"]:
        embed = _embed(record["Sns"]["Message"])
        if embed is None:
            continue
        embed = {k: v for k, v in embed.items() if v not in (None, "")}
        body = json.dumps({"username": BOT_NAME, "embeds": [embed]}).encode()
        req = urllib.request.Request(
            _webhook(),
            data=body,
            headers={"Content-Type": "application/json", "User-Agent": "pv-alarm-notifier"},
        )
        urllib.request.urlopen(req, timeout=5)