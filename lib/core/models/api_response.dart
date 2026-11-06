class ApiResponse<T> {
  final bool success;
  final int statusCode;
  final String message;
  final T? data;
  final String? errorCode;

  ApiResponse({
    required this.success,
    required this.statusCode,
    required this.message,
    this.data,
    this.errorCode,
  });

  factory ApiResponse.success({
    required String message,
    T? data,
    int statusCode = 200,
  }) {
    return ApiResponse(
      success: true,
      statusCode: statusCode,
      message: message,
      data: data,
    );
  }

  factory ApiResponse.error({
    required String message,
    String? errorCode,
    int statusCode = 400,
    T? data,
  }) {
    return ApiResponse(
      success: false,
      statusCode: statusCode,
      message: message,
      errorCode: errorCode,
      data: data,
    );
  }
}
