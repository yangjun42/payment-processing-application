import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: Number(__ENV.VUS || 5),
  duration: __ENV.DURATION || '30s',
  thresholds: {
    http_req_failed: ['rate<0.05'],
    http_req_duration: ['p(95)<1000'],
  },
};

const baseUrl = __ENV.BASE_URL || 'http://localhost:8080';

export default function () {
  const reference = `K6-${__VU}-${__ITER}`;
  const idempotencyKey = `k6-${__VU}-${__ITER}`;
  const create = http.post(
    `${baseUrl}/payments`,
    JSON.stringify({
      amount: 15.25,
      currency: 'EUR',
      reference,
      idempotencyKey,
    }),
    { headers: { 'Content-Type': 'application/json' } },
  );

  check(create, {
    'payment accepted': (response) => response.status === 202,
    'payment id returned': (response) => Boolean(response.json('paymentId')),
  });

  const paymentId = create.json('paymentId');
  if (!paymentId) {
    return;
  }

  sleep(1);
  const status = http.get(`${baseUrl}/payments/${paymentId}`);
  check(status, {
    'status endpoint ok': (response) => response.status === 200,
    'state returned': (response) => Boolean(response.json('state')),
  });
}
