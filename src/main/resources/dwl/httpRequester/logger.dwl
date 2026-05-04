%dw 2.0

import truncateIfOversized from dwl::httpRequester::payloadTruncator

fun buildRequestLog(config) =
    {
        event: "integration_request",
        correlationId: config.correlationId default null,
        method: config.method default null,
        url: config.url default null,
        headers: config.headers default {},
        queryParams: config.queryParams default {},
        body: truncateIfOversized(config.body default null, config.maxLogSize default 10240)
    }

fun buildResponseLog(statusCode, headers, body, maxLogSize = 10240) =
    {
        event: "integration_response",
        correlationId: null,
        statusCode: statusCode default null,
        headers: headers default {},
        body: truncateIfOversized(body, maxLogSize)
    }