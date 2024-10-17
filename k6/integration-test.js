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
    "http_req_duration{hive:enabled}": ["p(95)<15"],
    "http_req_duration{hive:disabled}": ["p(95)<15"],
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

function checkCount(count) {}
export function teardown(data) {
  let count;
  const res = http.get("http://localhost:8888/count");
  count = JSON.parse(res.body).count;
  console.log(`📊 Total operations: ${count}`);
  check(count, {
    "usage-api received 1000 operations": (count) => count === REQUEST_COUNT,
  });
  const response = http.post("http://localhost:8888/reset");
  const { count: newCount } = JSON.parse(response.body);
  check(newCount, {
    "usage-api is reset": (c) => c === 0,
  });
  return data;
}

export function handleSummary(data) {
  postGithubComment(data);

  return {
    stdout: textSummary(data, { indent: " ", enableColors: true }),
  };
}

function postGithubComment(data) {
  if (!__ENV.GITHUB_TOKEN) {
    return;
  }

  const checks = data.metrics.checks;
  const didPass = checks.failed === 0;

  githubComment(data, {
    token: __ENV.GITHUB_TOKEN,
    commit: __ENV.GITHUB_SHA,
    pr: __ENV.GITHUB_PR,
    org: "charlypoly",
    repo: "graphql-ruby-hive",
    renderTitle: () =>
      didPass ? "✅ Integration Test Passed" : "❌ Integration Test Failed",
    renderMessage: () =>
      didPass
        ? ""
        : "The integration test failed. Please check the action logs for more information.",
  });
}
