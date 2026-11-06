namespace Consware.Reimbursements.Api.Dtos;

public record CreateReimbursementDto(string EmployeeName, decimal Amount, string Category, string Description);

public record RejectReimbursementDto(string? Reason);

public record ReimbursementResponseDto(
    int Id,
    string EmployeeName,
    decimal Amount,
    string Category,
    string Description,
    string Status,
    string? RejectionReason,
    DateTime CreatedAtUtc,
    DateTime? DecidedAtUtc);
