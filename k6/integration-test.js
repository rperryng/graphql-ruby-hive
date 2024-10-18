import { check, fail } from "k6";
import http from "k6/http";
import { textSummary } from "https://jslib.k6.io/k6-summary/0.0.1/index.js";
import { githubComment } from "https://raw.githubusercontent.com/dotansimha/k6-github-pr-comment/master/lib.js";

const REGRESSION_THRESHOLD = 1;
const REQUEST_COUNT = 1000;

export const options = {
  scenarios: {
    hiveEnabled: {
      executor: "shared-iterations",
      vus: 5,
      iterations: 1000,
      maxDuration: "1s",
      env: { GQL_API_PORT: "9291", HIVE_ENABLED: "true" },
    },
    hiveDisabled: {
      executor: "shared-iterations",
      vus: 5,
      iterations: 1000,
      maxDuration: "1s",
      startTime: "1s",
      env: { GQL_API_PORT: "9292", HIVE_ENABLED: "false" },
    },
  },
  thresholds: {
    "http_req_duration{hive:enabled}": [
      {
        threshold: "p(95)<25",
        abortOnFail: true,
      },
    ],
    "http_req_duration{hive:disabled}": [
      {
        threshold: "p(95)<25",
        abortOnFail: true,
      },
    ],
    checks: [
      {
        threshold: "rate===1",
        abortOnFail: true,
      },
    ],
  },
};

const QUERY = /* GraphQL */ `
  query GetPost {
    post(id: 1) {
      title
      myId: id
    }
  }
`;
export function setup() {
  const response = http.post("http://localhost:8888/reset");
  const { count } = JSON.parse(response.body);
  check(count, {
    "usage-api starts with 0 operations": (count) => count === 0,
  });
}

export default function () {
  const payload = JSON.stringify({
    query: QUERY,
    operationName: "GetPost",
  });
  const params = {
    headers: {
      "Content-Type": "application/json",
    },
    tags: { hive: __ENV.HIVE_ENABLED === "true" ? "enabled" : "disabled" },
  };

  const res = http.post(
    `http://localhost:${__ENV.GQL_API_PORT}/graphql`,
    payload,
    params,
  );
  check(res, {
    "response body is GraphQL": (res) => res.body.includes("data"),
  });
  check(res, {
    "response body is not a GraphQL error": (res) =>
      !res.body.includes("errors"),
  });
  return res;
}

function sleep(seconds) {
  return new Promise((resolve) => setTimeout(resolve, seconds * 1000));
}

export async function teardown(data) {
  let count = 0;
  for (let i = 0; i < 10; i++) {
    const res = http.get("http://localhost:8888/count");
    count = JSON.parse(res.body).count;
    console.log(`📊 Total operations: ${count}`);
    if (count === REQUEST_COUNT) {
      break;
    }
    await sleep(1);
  }
  check(count, {
    "usage-api received correct number of operations": (count) =>
      count === REQUEST_COUNT,
  });
  const response = http.post("http://localhost:8888/reset");
  const { count: newCount } = JSON.parse(response.body);
  check(newCount, {
    "usage-api is reset": (c) => c === 0,
  });
  return data;
}
