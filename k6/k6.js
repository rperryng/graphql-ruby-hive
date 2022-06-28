import { check } from "k6";
import http from "k6/http";
import { textSummary } from "https://jslib.k6.io/k6-summary/0.0.1/index.js";
import { githubComment } from "https://raw.githubusercontent.com/dotansimha/k6-github-pr-comment/master/lib.js";

export const options = {
  discardResponseBodies: true,
  scenarios: {
    hiveEnabled: {
      executor: "shared-iterations",
      vus: 120,
      iterations: 500,
      maxDuration: "30s",
      env: { GQL_API_PORT: "9292", HIVE_ENABLED: "true" },
    },
    hiveDisabled: {
      executor: "shared-iterations",
      vus: 120,
      iterations: 500,
      maxDuration: "30s",
      startTime: "30s",
      env: { GQL_API_PORT: "9291", HIVE_ENABLED: "false" },
    },
  },
  thresholds: {
    "http_req_duration{hive:enabled}": ["avg<4500"],
    "http_req_duration{hive:disabled}": ["avg<4500"],
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

  return http.post(
    `http://localhost:${__ENV.GQL_API_PORT}/graphql`,
    payload,
    params
  );
}

export function handleSummary(data) {
  console.log(JSON.stringify(data, null, 2));
  if (__ENV.GITHUB_TOKEN) {
    // githubComment(data, {
    //   token: __ENV.GITHUB_TOKEN,
    //   commit: __ENV.GITHUB_SHA,
    //   pr: __ENV.GITHUB_PR,
    //   org: "charlypoly",
    //   repo: "graphql-ruby-hive",
    //   renderTitle({ passes }) {
    //     return passes ? "✅ Benchmark Results" : "❌ Benchmark Failed";
    //   },
    //   renderMessage({ passes, checks, thresholds }) {
    //     const result = [];
    //     if (thresholds.failures) {
    //       result.push(
    //         `**Performance regression detected**: it seems like your Pull Request adds some extra latency to GraphQL Yoga`
    //       );
    //     }
    //     if (checks.failures) {
    //       result.push("**Failed assertions detected**");
    //     }
    //     if (!passes) {
    //       result.push(
    //         `> If the performance regression is expected, please increase the failing threshold.`
    //       );
    //     }
    //     return result.join("\n");
    //   },
    // });
  }
  return {
    stdout: textSummary(data, { indent: " ", enableColors: true }),
  };
}
