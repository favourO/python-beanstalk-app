sealed class Result<T> {
  const Result();

  R when<R>({
    required R Function(T value) success,
    required R Function(Object error, StackTrace stackTrace) failure,
  }) {
    final self = this;
    if (self is Success<T>) {
      return success(self.value);
    }
    final failed = self as Failure<T>;
    return failure(failed.error, failed.stackTrace);
  }
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}
