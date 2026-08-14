enum UserRole {
  patient,
  student,
  admin,
  auditor;

  String get label {
    switch (this) {
      case UserRole.patient:
      case UserRole.student:
        return 'Patient / Member';
      case UserRole.admin:
        return 'Chief Medical Officer / Admin';
      case UserRole.auditor:
        return 'Clinical Auditor';
    }
  }

  String get code {
    switch (this) {
      case UserRole.patient:
      case UserRole.student:
        return 'PATIENT';
      case UserRole.admin:
        return 'CLINICAL_ADMIN';
      case UserRole.auditor:
        return 'AUDITOR';
    }
  }

  bool get isPatient => this == UserRole.patient || this == UserRole.student;
  bool get isStudent => isPatient;
  bool get isAdmin => this == UserRole.admin;
  bool get isAuditor => this == UserRole.auditor;

  static UserRole fromString(String? role) {
    if (role == null) return UserRole.patient;
    switch (role.toUpperCase()) {
      case 'ADMIN':
      case 'ADMINISTRATOR':
      case 'CLINICAL_ADMIN':
        return UserRole.admin;
      case 'AUDITOR':
        return UserRole.auditor;
      case 'PATIENT':
      case 'STUDENT':
      default:
        return UserRole.patient;
    }
  }
}
