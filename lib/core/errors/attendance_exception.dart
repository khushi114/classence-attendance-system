// Typed exceptions for the attendance system backend.

/// Base class for all attendance system exceptions.
class AttendanceSystemException implements Exception {
  final String message;
  final String code;

  AttendanceSystemException(this.message, this.code);

  @override
  String toString() => '$code: $message';
}

/// Session has passed its end time.
class SessionExpiredException extends AttendanceSystemException {
  SessionExpiredException([String? sessionId])
    : super(
        'Session ${sessionId ?? ''} has expired. Ask your faculty to start a new one.',
        'SESSION_EXPIRED',
      );
}

/// Session is not currently active (faculty hasn't started or has ended it).
class InvalidSessionException extends AttendanceSystemException {
  InvalidSessionException([String? detail])
    : super(
        detail ?? 'No active session found for this class.',
        'INVALID_SESSION',
      );
}

/// Student already marked attendance for this session.
class DuplicateAttendanceException extends AttendanceSystemException {
  DuplicateAttendanceException()
    : super(
        'You have already marked attendance for this session.',
        'DUPLICATE_ATTENDANCE',
      );
}

/// One or more verification steps failed.
class VerificationFailedException extends AttendanceSystemException {
  final List<String> failedSteps;

  VerificationFailedException(this.failedSteps)
    : super(
        'Verification failed: ${failedSteps.join(', ')}',
        'VERIFICATION_FAILED',
      );
}

/// User does not have the required role for this operation.
class UnauthorizedRoleException extends AttendanceSystemException {
  UnauthorizedRoleException(String requiredRole)
    : super(
        'This action requires the "$requiredRole" role.',
        'UNAUTHORIZED_ROLE',
      );
}

/// Student is not enrolled in this class.
class NotEnrolledException extends AttendanceSystemException {
  NotEnrolledException()
    : super('You are not enrolled in this class.', 'NOT_ENROLLED');
}

/// Faculty tried to start a session but one is already active.
class ActiveSessionExistsException extends AttendanceSystemException {
  ActiveSessionExistsException()
    : super(
        'An active session already exists for this class. End it before starting a new one.',
        'ACTIVE_SESSION_EXISTS',
      );
}
