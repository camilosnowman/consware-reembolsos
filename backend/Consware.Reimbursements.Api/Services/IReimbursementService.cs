using Consware.Reimbursements.Api.Dtos;
using Consware.Reimbursements.Api.Models;

namespace Consware.Reimbursements.Api.Services;

public interface IReimbursementService
{
    Task<ServiceResult<ReimbursementResponseDto>> CreateAsync(CreateReimbursementDto dto);
    Task<ServiceResult<IEnumerable<ReimbursementResponseDto>>> GetAllAsync(string? status, string? employeeName);
    Task<ServiceResult<ReimbursementResponseDto>> GetByIdAsync(int id);
    Task<ServiceResult<ReimbursementResponseDto>> ApproveAsync(int id);
    Task<ServiceResult<ReimbursementResponseDto>> RejectAsync(int id, string? reason);
}
