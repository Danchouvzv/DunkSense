# High Error Rate Runbook

## Alert: HighErrorRate

**Severity:** Critical  
**Team:** Backend  
**SLA Impact:** High  

## Overview

This alert fires when the HTTP 5xx error rate exceeds 1% over a 5-minute period. This indicates potential issues with the backend services that could impact user experience and system reliability.

## Immediate Response (First 5 minutes)

### 1. Acknowledge the Alert
- [ ] Acknowledge the alert in PagerDuty/Slack
- [ ] Check if this is a known issue or planned maintenance
- [ ] Verify the alert is not a false positive

### 2. Quick Assessment
- [ ] Check Grafana dashboard: [System Overview](https://grafana.dunksense.ai/d/dunksense-overview)
- [ ] Verify error rate: `rate(http_requests_total{status_code=~"5.."}[5m])`
- [ ] Check affected endpoints: `topk(10, sum(rate(http_requests_total{status_code=~"5.."}[5m])) by (endpoint))`
- [ ] Review recent deployments in the last 30 minutes

### 3. Initial Mitigation
If error rate > 5%:
- [ ] Consider rolling back the latest deployment
- [ ] Enable circuit breakers if available
- [ ] Scale up affected services immediately

## Investigation (Next 15 minutes)

### 4. Deep Dive Analysis

#### Check Service Health
```bash
# Check service status
kubectl get pods -n dunksense
kubectl describe pod <failing-pod> -n dunksense

# Check service logs
kubectl logs -f deployment/dunksense-api -n dunksense --tail=100
```

#### Database Investigation
```bash
# Check database connections
kubectl exec -it deployment/postgres -n dunksense -- psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# Check for long-running queries
kubectl exec -it deployment/postgres -n dunksense -- psql -U postgres -c "SELECT pid, now() - pg_stat_activity.query_start AS duration, query FROM pg_stat_activity WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes';"
```

#### External Dependencies
- [ ] Check Redis connectivity: `redis-cli ping`
- [ ] Verify Kafka broker health
- [ ] Check third-party API status (auth providers, payment gateways)

### 5. Common Root Causes

#### Application Issues
- [ ] **Memory leaks**: Check memory usage patterns
- [ ] **Database connection pool exhaustion**: Monitor connection counts
- [ ] **Deadlocks**: Review database logs for deadlock errors
- [ ] **Timeout issues**: Check external service response times

#### Infrastructure Issues
- [ ] **Resource constraints**: CPU/Memory limits reached
- [ ] **Network issues**: Packet loss or high latency
- [ ] **Storage issues**: Disk space or I/O bottlenecks

#### Configuration Issues
- [ ] **Environment variables**: Verify configuration values
- [ ] **Feature flags**: Check if new features are causing issues
- [ ] **Rate limiting**: Verify rate limit configurations

## Resolution Actions

### 6. Fix Strategies

#### For Application Errors (500-503)
```bash
# Restart affected services
kubectl rollout restart deployment/dunksense-api -n dunksense

# Scale up replicas
kubectl scale deployment dunksense-api --replicas=5 -n dunksense

# Check resource limits
kubectl describe deployment dunksense-api -n dunksense
```

#### For Database Issues
```bash
# Kill long-running queries
kubectl exec -it deployment/postgres -n dunksense -- psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE (now() - pg_stat_activity.query_start) > interval '10 minutes';"

# Restart database connection pool
kubectl rollout restart deployment/pgbouncer -n dunksense
```

#### For External Service Issues
- [ ] Enable fallback mechanisms
- [ ] Implement circuit breakers
- [ ] Use cached responses where possible

### 7. Rollback Procedures

If recent deployment is suspected:
```bash
# Check deployment history
kubectl rollout history deployment/dunksense-api -n dunksense

# Rollback to previous version
kubectl rollout undo deployment/dunksense-api -n dunksense

# Verify rollback success
kubectl rollout status deployment/dunksense-api -n dunksense
```

## Monitoring and Verification

### 8. Confirm Resolution
- [ ] Error rate drops below 1%: `rate(http_requests_total{status_code=~"5.."}[5m]) < 0.01`
- [ ] Response times return to normal: `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) < 0.12`
- [ ] No new alerts triggered
- [ ] User reports of issues stopped

### 9. Key Metrics to Monitor
```promql
# Error rate by endpoint
sum(rate(http_requests_total{status_code=~"5.."}[5m])) by (endpoint)

# Response time percentiles
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# Service availability
up{job=~"dunksense-.*"}

# Database connections
database_connections_active

# Memory usage
container_memory_usage_bytes{container="dunksense-api"}
```

## Post-Incident Actions

### 10. Communication
- [ ] Update stakeholders on resolution
- [ ] Post in #incidents channel
- [ ] Update status page if customer-facing

### 11. Documentation
- [ ] Create incident report
- [ ] Update this runbook if new insights discovered
- [ ] Schedule post-mortem if incident lasted > 30 minutes

## Prevention

### 12. Long-term Improvements
- [ ] Implement better error handling and retry logic
- [ ] Add more comprehensive health checks
- [ ] Improve monitoring and alerting granularity
- [ ] Consider implementing chaos engineering practices
- [ ] Review and optimize database queries
- [ ] Implement proper circuit breakers and bulkheads

## Escalation

### When to Escalate
- Error rate remains > 5% after 15 minutes
- Multiple services affected simultaneously
- Database corruption suspected
- Security incident suspected

### Escalation Contacts
- **Engineering Manager**: @eng-manager
- **CTO**: @cto (for critical business impact)
- **Security Team**: @security (for security-related issues)
- **Infrastructure Team**: @infra (for platform issues)

## Useful Commands

```bash
# Quick error rate check
curl -s "http://prometheus:9090/api/v1/query?query=rate(http_requests_total{status_code=~\"5..\"}[5m])" | jq '.data.result[0].value[1]'

# Check recent deployments
kubectl get events --sort-by=.metadata.creationTimestamp -n dunksense | grep -i deploy

# View service logs with error filtering
kubectl logs -f deployment/dunksense-api -n dunksense | grep -i error

# Check resource usage
kubectl top pods -n dunksense
```

## Related Runbooks
- [High Latency](./high-latency.md)
- [Service Down](./service-down.md)
- [Database Issues](./db-down.md)
- [Memory Issues](./high-memory.md)

---

**Last Updated:** 2024-01-15  
**Next Review:** 2024-04-15  
**Version:** 1.0 