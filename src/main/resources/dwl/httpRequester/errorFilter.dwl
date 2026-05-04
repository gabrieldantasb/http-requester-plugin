%dw 2.0

fun isRetryableByType(err, retryableErrorTypes = []) =
    (retryableErrorTypes default []) contains (
      ((err.errorType.namespace default "") as String)
      ++ ":"
      ++ ((err.errorType.identifier default "") as String)
    )

fun isRetryableByCode(err, retryableErrorCodes = []) =
    (err.errorMessage.attributes.statusCode default null) != null
    and (
      ((retryableErrorCodes default []) map (($ default "") as String))
      contains ((err.errorMessage.attributes.statusCode default "") as String)
    )

fun isRetryable(err, retryableErrorTypes = [], retryableErrorCodes = []) =
    isRetryableByType(err, retryableErrorTypes) or isRetryableByCode(err, retryableErrorCodes)