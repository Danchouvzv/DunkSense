import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');

// Test configuration
export const options = {
  stages: [
    { duration: '2m', target: 100 }, // Ramp up to 100 users
    { duration: '5m', target: 100 }, // Stay at 100 users
    { duration: '2m', target: 200 }, // Ramp up to 200 users
    { duration: '5m', target: 200 }, // Stay at 200 users
    { duration: '2m', target: 0 },   // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<120'], // 95% of requests must complete below 120ms
    http_req_failed: ['rate<0.01'],   // Error rate must be below 1%
    errors: ['rate<0.01'],            // Custom error rate
  },
  ext: {
    loadimpact: {
      distribution: {
        'amazon:us:ashburn': { loadZone: 'amazon:us:ashburn', percent: 50 },
        'amazon:ie:dublin': { loadZone: 'amazon:ie:dublin', percent: 50 },
      },
    },
  },
};

// Base URL configuration
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const API_BASE = `${BASE_URL}/api/v1`;

// Test data
const testUsers = [
  { email: 'user1@test.com', password: 'testpass123' },
  { email: 'user2@test.com', password: 'testpass123' },
  { email: 'user3@test.com', password: 'testpass123' },
];

let authToken = '';

// Setup function - runs once before all tests
export function setup() {
  console.log('Setting up load test...');
  
  // Health check
  const healthResponse = http.get(`${BASE_URL}/health`);
  check(healthResponse, {
    'health check status is 200': (r) => r.status === 200,
  });
  
  return { baseUrl: BASE_URL };
}

// Main test function
export default function (data) {
  const user = testUsers[Math.floor(Math.random() * testUsers.length)];
  
  // Test 1: Authentication
  testAuthentication(user);
  
  // Test 2: Jump metrics CRUD
  testJumpMetrics();
  
  // Test 3: User statistics
  testUserStatistics();
  
  // Test 4: Analytics endpoints
  testAnalytics();
  
  sleep(1); // Think time between iterations
}

function testAuthentication(user) {
  const loginPayload = JSON.stringify({
    email: user.email,
    password: user.password,
  });
  
  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };
  
  const response = http.post(`${API_BASE}/auth/login`, loginPayload, params);
  
  const success = check(response, {
    'login status is 200': (r) => r.status === 200,
    'login response has token': (r) => r.json('token') !== undefined,
  });
  
  if (success && response.json('token')) {
    authToken = response.json('token');
  }
  
  errorRate.add(!success);
  responseTime.add(response.timings.duration);
}

function testJumpMetrics() {
  if (!authToken) return;
  
  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${authToken}`,
  };
  
  // Create jump metric
  const jumpData = {
    height: 75.5 + Math.random() * 20, // Random height between 75-95cm
    flight_time: 0.6 + Math.random() * 0.3, // Random flight time
    contact_time: 0.2 + Math.random() * 0.1,
    takeoff_velocity: 3.0 + Math.random() * 1.0,
    landing_force: 1000 + Math.random() * 500,
    symmetry_score: 0.7 + Math.random() * 0.3,
    technique_score: 0.7 + Math.random() * 0.3,
    timestamp: new Date().toISOString(),
  };
  
  const createResponse = http.post(
    `${API_BASE}/jumps`,
    JSON.stringify(jumpData),
    { headers }
  );
  
  const createSuccess = check(createResponse, {
    'create jump status is 201': (r) => r.status === 201,
    'create jump response has id': (r) => r.json('id') !== undefined,
  });
  
  errorRate.add(!createSuccess);
  responseTime.add(createResponse.timings.duration);
  
  // Get jump metrics
  const getResponse = http.get(`${API_BASE}/jumps`, { headers });
  
  const getSuccess = check(getResponse, {
    'get jumps status is 200': (r) => r.status === 200,
    'get jumps response is array': (r) => Array.isArray(r.json()),
  });
  
  errorRate.add(!getSuccess);
  responseTime.add(getResponse.timings.duration);
  
  // Update jump metric if we have an ID
  if (createSuccess && createResponse.json('id')) {
    const jumpId = createResponse.json('id');
    const updateData = {
      ...jumpData,
      height: jumpData.height + 1, // Slightly increase height
    };
    
    const updateResponse = http.put(
      `${API_BASE}/jumps/${jumpId}`,
      JSON.stringify(updateData),
      { headers }
    );
    
    const updateSuccess = check(updateResponse, {
      'update jump status is 200': (r) => r.status === 200,
    });
    
    errorRate.add(!updateSuccess);
    responseTime.add(updateResponse.timings.duration);
  }
}

function testUserStatistics() {
  if (!authToken) return;
  
  const headers = {
    'Authorization': `Bearer ${authToken}`,
  };
  
  // Get user stats
  const userId = 'test-user-' + Math.floor(Math.random() * 1000);
  const statsResponse = http.get(
    `${API_BASE}/users/${userId}/stats?from=2024-01-01&to=2024-12-31`,
    { headers }
  );
  
  const statsSuccess = check(statsResponse, {
    'get user stats status is 200': (r) => r.status === 200,
    'get user stats has data': (r) => r.json() !== null,
  });
  
  errorRate.add(!statsSuccess);
  responseTime.add(statsResponse.timings.duration);
  
  // Get personal best
  const bestResponse = http.get(
    `${API_BASE}/users/${userId}/personal-best`,
    { headers }
  );
  
  const bestSuccess = check(bestResponse, {
    'get personal best status is 200 or 404': (r) => r.status === 200 || r.status === 404,
  });
  
  errorRate.add(!bestSuccess);
  responseTime.add(bestResponse.timings.duration);
}

function testAnalytics() {
  if (!authToken) return;
  
  const headers = {
    'Authorization': `Bearer ${authToken}`,
  };
  
  // Test analytics endpoints
  const analyticsEndpoints = [
    `${API_BASE}/analytics/daily`,
    `${API_BASE}/analytics/weekly`,
    `${API_BASE}/analytics/monthly`,
  ];
  
  analyticsEndpoints.forEach((endpoint) => {
    const response = http.get(endpoint, { headers });
    
    const success = check(response, {
      [`${endpoint} status is 200`]: (r) => r.status === 200,
    });
    
    errorRate.add(!success);
    responseTime.add(response.timings.duration);
  });
}

// Teardown function - runs once after all tests
export function teardown(data) {
  console.log('Tearing down load test...');
  
  // Final health check
  const healthResponse = http.get(`${data.baseUrl}/health`);
  check(healthResponse, {
    'final health check status is 200': (r) => r.status === 200,
  });
}

// Test scenarios for different load patterns
export const scenarios = {
  // Constant load
  constant_load: {
    executor: 'constant-vus',
    vus: 50,
    duration: '5m',
    tags: { test_type: 'constant' },
  },
  
  // Spike test
  spike_test: {
    executor: 'ramping-vus',
    startVUs: 0,
    stages: [
      { duration: '10s', target: 100 },
      { duration: '1m', target: 100 },
      { duration: '10s', target: 1000 }, // Spike
      { duration: '1m', target: 1000 },
      { duration: '10s', target: 100 },
      { duration: '1m', target: 100 },
      { duration: '10s', target: 0 },
    ],
    tags: { test_type: 'spike' },
  },
  
  // Stress test
  stress_test: {
    executor: 'ramping-vus',
    startVUs: 0,
    stages: [
      { duration: '2m', target: 100 },
      { duration: '5m', target: 100 },
      { duration: '2m', target: 200 },
      { duration: '5m', target: 200 },
      { duration: '2m', target: 300 },
      { duration: '5m', target: 300 },
      { duration: '2m', target: 0 },
    ],
    tags: { test_type: 'stress' },
  },
};

// Custom summary for better reporting
export function handleSummary(data) {
  return {
    'load-test-summary.json': JSON.stringify(data, null, 2),
    'load-test-summary.html': generateHTMLReport(data),
  };
}

function generateHTMLReport(data) {
  const template = `
<!DOCTYPE html>
<html>
<head>
    <title>DunkSense Load Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .metric { margin: 10px 0; padding: 10px; border: 1px solid #ddd; }
        .pass { background-color: #d4edda; }
        .fail { background-color: #f8d7da; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>DunkSense Load Test Report</h1>
    <h2>Test Summary</h2>
    <p>Generated: ${new Date().toISOString()}</p>
    
    <h2>Key Metrics</h2>
    <div class="metric ${data.metrics.http_req_duration.values.p95 < 120 ? 'pass' : 'fail'}">
        <strong>95th Percentile Response Time:</strong> ${data.metrics.http_req_duration.values.p95.toFixed(2)}ms
        (Threshold: <120ms)
    </div>
    
    <div class="metric ${data.metrics.http_req_failed.values.rate < 0.01 ? 'pass' : 'fail'}">
        <strong>Error Rate:</strong> ${(data.metrics.http_req_failed.values.rate * 100).toFixed(2)}%
        (Threshold: <1%)
    </div>
    
    <h2>Detailed Metrics</h2>
    <table>
        <tr><th>Metric</th><th>Value</th></tr>
        <tr><td>Total Requests</td><td>${data.metrics.http_reqs.values.count}</td></tr>
        <tr><td>Average Response Time</td><td>${data.metrics.http_req_duration.values.avg.toFixed(2)}ms</td></tr>
        <tr><td>Max Response Time</td><td>${data.metrics.http_req_duration.values.max.toFixed(2)}ms</td></tr>
        <tr><td>Requests/Second</td><td>${data.metrics.http_reqs.values.rate.toFixed(2)}</td></tr>
    </table>
</body>
</html>
  `;
  
  return template;
} 