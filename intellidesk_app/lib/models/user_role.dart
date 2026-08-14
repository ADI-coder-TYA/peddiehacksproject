enum UserRole {
  student,
  admin,
  auditor;

  String get label {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.admin:
        return 'Administrator';
      case UserRole.auditor:
        return 'Auditor';
    }
  }

  String get code {
    switch (this) {
      case UserRole.student:
        return 'STUDENT';
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.auditor:
        return 'AUDITOR';
    }
  }

  bool get isStudent => this == UserRole.student;
  bool get isAdmin => this == UserRole.admin;
  bool get isAuditor => this == UserRole.auditor;

  static UserRole fromString(String? role) {
    if (role == null) return UserRole.student;
    switch (role.toUpperCase()) {
      case 'ADMIN':
      case 'ADMINISTRATOR':
        return UserRole.admin;
      case 'AUDITOR':
        return UserRole.auditor;
      case 'STUDENT':
      default:
        return UserRole.student;
    }
  }
}
