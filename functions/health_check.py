# 5분마다 URL을 호출해 성공 여부를 CloudWatch 지표(Success = 1 또는 0)로 기록
# 장애/복구 판단은 CloudWatch 알람이 함 (연속 실패 → 장애 알림, 회복 → 복구 알림)
import urllib.request
import boto3

_cw = boto3.client("cloudwatch")

def _is_up(url):
    # 2xx만 정상. 사용자 입장에서 아래는 모두 장애다
    # 503: Actuator DOWN(DB 연결 실패 등) / 502·504: 서버 다운
    # 403: 오리진 검증 헤더 불일치(CloudFront와 서버의 값이 어긋남) / 404: 헬스체크 경로 없음
    req = urllib.request.Request(url, headers={"User-Agent": "pv-health-check"})
    try:
        with urllib.request.urlopen(req, timeout=10) as res:
            return 200 <= res.status < 300
    except Exception:  # HTTPError(4xx·5xx), 타임아웃, DNS 실패, 연결 거부
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