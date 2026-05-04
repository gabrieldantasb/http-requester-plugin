%dw 2.0

fun buildConfig(
    url,
    method = 'GET',
    body = null,
    headers = {},
    queryParams = {},
    correlationId = null,
    sendCorrelationId = null,
    maxRetries = 0,
    msBetweenRetries = 0,
    retryableErrorTypes = [],
    retryableErrorCodes = [],
    maxLogSize = 10240
) =
    {
       	url: url,
        method: method,
        body: body,
        headers: headers,
        queryParams: queryParams,
        correlationId: correlationId,
        sendCorrelationId: sendCorrelationId,
        maxRetries: maxRetries,
        msBetweenRetries: msBetweenRetries,
        retryableErrorTypes: retryableErrorTypes,
        retryableErrorCodes: retryableErrorCodes,
        maxLogSize: maxLogSize
    }

fun withRetry(
    maxRetries = 0,
    msBetweenRetries = 0,
    retryableErrorTypes = [],
    retryableErrorCodes = []
) =
    {
        maxRetries: maxRetries,
        msBetweenRetries: msBetweenRetries,
        retryableErrorTypes: retryableErrorTypes,
        retryableErrorCodes: retryableErrorCodes
    }

fun withHeaders(headers = {}) =
    {
        headers: headers default {}
    }

fun withQueryParams(queryParams = {}) =
    {
        queryParams: queryParams default {}
    }

fun withCorrelation(correlationId = null, sendCorrelationId = false) =
    {
        correlationId: correlationId,
        sendCorrelationId: sendCorrelationId
    }

fun withLogging(maxLogSize = 10240) =
    {
        maxLogSize: maxLogSize
    }