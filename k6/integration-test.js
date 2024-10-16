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
  // Ensure usage counter is at 0
  const response = http.post("http://localhost:8888/reset");
  const { count } = JSON.parse(response.body);
  check(count, {
    "usage-api starts with 0 operations": (count) => count === 0,
  });
  return { count };
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
}

export function teardown(_data) {
  const res = http.get("http://localhost:8888/count");
  const count = JSON.parse(res.body).count;
  console.log(`📊 Total operations: ${count}`);
  check(count, {
    "usage-api received 200 operations": (count) => count === REQUEST_COUNT,
  });
}

export function handleSummary(data) {
  const overhead = getOverheadPercentage(data);
  const didPass = check(overhead, {
    "overhead is less than 1%": (p) => p >= REGRESSION_THRESHOLD,
  });

  postGithubComment(didPass);

  console.log(`⏰ Overhead percentage: ${overhead.toFixed(2)}%`);

  if (!didPass) {
    fail("❌❌ Performance regression detected ❌❌");
  }

  return {
    stdout: textSummary(data, { indent: " ", enableColors: true }),
  };
}

function postGithubComment(didPass) {
  if (!__ENV.GITHUB_TOKEN) {
    return;
  }

  githubComment(data, {
    token: __ENV.GITHUB_TOKEN,
    commit: __ENV.GITHUB_SHA,
    pr: __ENV.GITHUB_PR,
    org: "charlypoly",
    repo: "graphql-ruby-hive",
    renderTitle: () => {
      return didPass ? "✅ Benchmark Results" : "❌ Benchmark Failed";
    },
    renderMessage: () => {
      const result = [];
      if (didPass) {
        result.push(
          "**Performance regression detected**: it seems like your Pull Request adds some extra latency to GraphQL Hive operations processing",
        );
      } else {
        result.push("Overhead < 5%");
      }
      return result.join("\n");
    },
  });
}

function getOverheadPercentage(data) {
  const enabledMetric = data.metrics["http_req_duration{hive:enabled}"];
  const disabledMetric = data.metrics["http_req_duration{hive:disabled}"];

  if (enabledMetric && disabledMetric) {
    const withHive = enabledMetric.values["avg"];
    const withoutHive = disabledMetric.values["avg"];
    return 100 - (withHive * 100.0) / withoutHive;
  } else {
    throw new Error("Could not calculate overhead. Missing metrics.");
  }
}
