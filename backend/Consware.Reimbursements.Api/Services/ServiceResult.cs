namespace Consware.Reimbursements.Api.Services;

public enum ServiceErrorCode
{
    None,
    BadRequest,
    NotFound,
    Conflict
}

public class ServiceResult<T>
{
    public bool Success { get; init; }
    public T? Value { get; init; }
    public ServiceErrorCode ErrorCode { get; init; }
    public string? Message { get; init; }

    public static ServiceResult<T> Ok(T value) => new() { Success = true, Value = value, ErrorCode = ServiceErrorCode.None };
    public static ServiceResult<T> Fail(ServiceErrorCode code, string message) => new() { Success = false, ErrorCode = code, Message = message };
}
