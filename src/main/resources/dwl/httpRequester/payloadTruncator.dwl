%dw 2.0

fun getSizeInBytes(value) =
    sizeOf(write(value, "application/json", {indent: false}) as Binary)

fun truncateIfOversized(payload, maxBytes = 10240) =
    if (getSizeInBytes(payload) > maxBytes)
      "[TRUNCATED - " ++ (getSizeInBytes(payload) as String) ++ " bytes]"
    else
      payload