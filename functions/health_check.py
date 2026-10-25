# 5분마다 URL을 호출해 성공 여부를 CloudWatch 지표(Success = 1 또는 0)로 기록
# 장애/복구 판단은 CloudWatch 알람이 함 (연속 실패 → 장애 알림, 회복 → 복구 알림)
import urllib.error
import urllib.request
import boto3

_cw = boto3.client("cloudwatch")

def _is_up(url):
    # 응답이 왔고 5xx가 아니면 정상 = 서버가 살아서 응답했다는 뜻 (401·404도 정상으로 봄)
    # CloudFront 뒤의 서버가 죽으면 502/504, 응답이 없으면 타임아웃 → 실패
    req = urllib.request.Request(url, headers={"User-Agent": "pv-health-check"})
    try:
        with urllib.request.urlopen(req, timeout=10) as res:
            return res.status < 500
    except urllib.error.HTTPError as e:
        return e.code < 500
    except Exception:  # 타임아웃, DNS 실패, 연결 거부
        return False

def handler(event, context):
    results = {name: _is_up(url) for name, url in event["targets"].items()}
    _cw.put_metric_data(
        Namespace=event["namespace"],
        MetricData=[
            {
                "MetricName": "Success",
                "Dimensions": [{"Name": "Target", "Value": name}],
                "Value": 1 if ok else 0,
                "Unit": "Count",
            }
            for name, ok in results.items()
        ],
    )
    return results