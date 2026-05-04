# http-requester-plugin

A reusable MuleSoft **mule-plugin** that provides a single parametrized sub-flow for making outbound HTTP requests with built-in retry logic, structured logging, and oversized-payload protection. Consumer applications add it as a Maven dependency and drive every request entirely through one Mule variable — no extra configuration required.

---

## Table of Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Install this plugin](#install-this-plugin)
- [Installation](#installation)
- [Usage](#usage)
  - [Invoking the sub-flow](#invoking-the-sub-flow)
  - [Building the config object](#building-the-config-object)
  - [Config reference](#config-reference)
- [Features](#features)
  - [Retry logic](#retry-logic)
  - [Non-retryable error handling](#non-retryable-error-handling)
  - [Structured logging](#structured-logging)
  - [Payload truncation](#payload-truncation)
- [DataWeave modules](#dataweave-modules)
- [Project structure](#project-structure)
- [Error types](#error-types)
- [Contributing](#contributing)

---

## Overview

`http-requester-plugin` wraps the MuleSoft HTTP connector inside a reusable sub-flow that handles concerns every outbound integration shares:

- Configurable retry with per-error-type and per-HTTP-status-code retry rules
- Clean separation between retryable and non-retryable failures
- Structured JSON logs on request, response, and each error
- Automatic payload truncation before logging to protect log storage

All behaviour is controlled by a single variable (`vars.httpRequestPluginConfig`) built with the provided DataWeave helper functions.

---

## Requirements

| Dependency | Version |
|---|---|
| Mule Runtime | 4.11.2 |
| Java | 17 |
| mule-http-connector | 1.10.3 |
| MUnit (test) | 3.3.0 |

---

## Install this plugin

To install and use this plugin from your Anypoint organization, make sure both points below are configured.

1. Update `project.groupId` in `pom.xml` to the consumer Anypoint organization ID.

Example:

```xml
<groupId>YOUR_ORG_ID</groupId>
```

2. Add a Connected App server entry in your Maven `settings.xml` with Exchange permissions.

Use this format:

```xml
<server>
  <id>anypoint-exchange-YOUR_ORG_ID</id>
  <username>~~~Client~~~</username>
  <password>clientId~?~clientSecret</password>
</server>
```

The `<id>` value in `settings.xml` must match the repository id pattern used in `pom.xml`: `anypoint-exchange-${project.groupId}`.

---

## Installation

Add the plugin as a Maven dependency in your application's `pom.xml`:

```xml
<dependency>
    <groupId>com.mycompany</groupId>
    <artifactId>http-requester-plugin</artifactId>
    <version>1.0.0-SNAPSHOT</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

Import the sub-flow in your Mule XML:

```xml
<import file="http-requester-plugin.xml" />
```

---

## Usage

### Invoking the sub-flow

Set `vars.httpRequestPluginConfig` to the config object, then call the sub-flow by reference:

```xml
<set-variable
  variableName="httpRequestPluginConfig"
  value="#[dwl::httpRequester::configBuilder::buildConfig(
    method = 'POST',
    url = 'https://api.example.com/orders',
    body = payload
  ) ++ dwl::httpRequester::configBuilder::withRetry(
    maxRetries = 3,
    msBetweenRetries = 2000,
    retryableErrorCodes = ['503', '429']
  )]" />

<flow-ref name="http-request-plugin" />
```

After the sub-flow returns, `payload` and `attributes` contain the HTTP response exactly as the connector sets them.

### Building the config object

All helper functions live in `dwl::httpRequester::configBuilder`. They are designed to be merged with the DataWeave `++` operator so you only include the sections you need:

```dataweave
dwl::httpRequester::configBuilder::buildConfig(
    method = 'GET',
    url = 'https://api.example.com/products'
)
++ dwl::httpRequester::configBuilder::withCorrelation(
    correlationId = correlationId,
    sendCorrelationId = true
)
++ dwl::httpRequester::configBuilder::withLogging(
    maxLogSize = 20480
)
```

### Config reference

| Field | Type | Default | Description |
|---|---|---|---|
| `method` | String | `"GET"` | HTTP method (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`, etc.) |
| `url` | String | `null` | Full request URL including protocol, host, path, and any inline query string |
| `body` | Any | `null` | Request body — passed as-is to the HTTP connector |
| `headers` | Object | `{}` | Map of request headers |
| `queryParams` | Object | `{}` | Map of query parameters appended to the URL |
| `correlationId` | String | `null` | Correlation ID forwarded on the request |
| `sendCorrelationId` | Boolean | `null` | `true` → `ALWAYS`, `false` → `NEVER`, `null` → `AUTO` |
| `maxRetries` | Number | `0` | Maximum number of retry attempts (0 = no retries) |
| `msBetweenRetries` | Number | `0` | Milliseconds to wait between retry attempts |
| `retryableErrorTypes` | Array\<String\> | `[]` | Mule error types that should trigger a retry (e.g. `["HTTP:TIMEOUT", "HTTP:CONNECTIVITY"]`) |
| `retryableErrorCodes` | Array\<String\> | `[]` | HTTP status codes that should trigger a retry (e.g. `["429", "503"]`) |
| `maxLogSize` | Number | `10240` | Maximum payload size in bytes before truncation in logs (default 10 KB) |

---

## Features

### Retry logic

The sub-flow wraps the HTTP request in a `until-successful` scope. On each failed attempt, the error is classified as either retryable or non-retryable using two independent rules evaluated with OR logic:

- **By error type** — checks `retryableErrorTypes` against the Mule error type (`NAMESPACE:IDENTIFIER`)
- **By HTTP status code** — null-safe check against `retryableErrorCodes` using `error.errorMessage.attributes.statusCode`

Retryable errors are propagated back into the retry scope so `until-successful` attempts the next retry. The retry logger records each failed attempt at `ERROR` level.

### Non-retryable error handling

When an error is **not** retryable the sub-flow uses the retry-escape pattern:

1. `on-error-continue` swallows the error inside the `try`, making `until-successful` treat the iteration as successful and stop retrying immediately.
2. The error object is stored in `vars.pluginNonRetryableError`.
3. After the retry scope, a `choice` checks for this variable and re-raises the error as `APP:HTTP_NON_RETRYABLE`, giving the calling flow a clean, meaningful error type to handle.

### Structured logging

Three structured JSON log entries are emitted automatically on every invocation:

| Event | Level | Category | When |
|---|---|---|---|
| `integration_request` | INFO | `com.company.integration.request` | Before the HTTP call |
| `integration_error_retryable` | ERROR | `com.company.integration.error` | On each retryable failure |
| `integration_error_non_retryable` | ERROR | `com.company.integration.error` | On a non-retryable failure |
| `integration_response` | INFO | `com.company.integration.response` | After a successful HTTP call |

Every log entry includes `correlationId` and `errorType` (formatted as `NAMESPACE:IDENTIFIER`).

### Payload truncation

Request and response bodies are serialized to JSON and their byte size is checked before they appear in logs. If a body exceeds `maxLogSize` it is replaced with the string:

```
[TRUNCATED - {n} bytes]
```

This protects log storage from large payloads without affecting the actual HTTP request or response.

---

## DataWeave modules

All modules are located under `src/main/resources/dwl/httpRequester/`.

| Module | Functions | Purpose |
|---|---|---|
| `configBuilder` | `buildConfig()`, `withRetry()`, `withHeaders()`, `withQueryParams()`, `withCorrelation()`, `withLogging()` | Build and compose the plugin config object |
| `errorFilter` | `isRetryable()`, `isRetryableByType()`, `isRetryableByCode()` | Classify errors as retryable or non-retryable |
| `logger` | `buildRequestLog()`, `buildResponseLog()` | Build structured log payloads; delegates truncation to `payloadTruncator` |
| `payloadTruncator` | `truncateIfOversized()`, `getSizeInBytes()` | Serialize values to JSON and truncate if over the configured byte limit |

---

## Project structure

```
http-requester-plugin/
├── src/
│   ├── main/
│   │   ├── mule/
│   │   │   └── http-requester-plugin.xml       # Global HTTP config + sub-flow
│   │   └── resources/
│   │       └── dwl/httpRequester/
│   │           ├── configBuilder.dwl
│   │           ├── errorFilter.dwl
│   │           ├── logger.dwl
│   │           └── payloadTruncator.dwl
│   └── test/
│       ├── munit/                              # MUnit test suites (future)
│       └── resources/
├── mule-artifact.json
└── pom.xml
```

---

## Error types

| Error type | Raised when |
|---|---|
| `APP:HTTP_NON_RETRYABLE` | The HTTP request failed with an error not covered by `retryableErrorTypes` or `retryableErrorCodes`, or all retries were exhausted on a non-retryable failure |

---

## Contributing

1. Update `groupId` in `pom.xml` from `com.mycompany` to your organisation's group ID before publishing to Anypoint Exchange.
2. MUnit test suite location: `src/test/munit/http-requester-plugin-test.xml` (not yet created).
3. Use the DataWeave `++` operator to add new config sections via `configBuilder` without breaking existing callers.
