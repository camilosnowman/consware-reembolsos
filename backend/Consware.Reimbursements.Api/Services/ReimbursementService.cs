using Consware.Reimbursements.Api.Data;
using Consware.Reimbursements.Api.Dtos;
using Consware.Reimbursements.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Consware.Reimbursements.Api.Services;

public class ReimbursementService : IReimbursementService
{
    private const decimal AutoApprovalLimit = 500000m;

    private readonly AppDbContext _context;

    public ReimbursementService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<ServiceResult<ReimbursementResponseDto>> CreateAsync(CreateReimbursementDto dto)
    {
        if (dto.EmployeeName is null || string.IsNullOrWhiteSpace(dto.EmployeeName))
        {
            return ServiceResult<ReimbursementResponseDto>.Fail(ServiceErrorCode.BadRequest, "El nombre del empleado es obligatorio.");
        }

        if (string.IsNullOrWhiteSpace(dto.Category))
        {
            return ServiceResult<ReimbursementResponseDto>.Fail(ServiceErrorCode.BadRequest, "La categor\u00eda es obligatoria.");
        }

        if (string.IsNullOrWhiteSpace(dto.Description))
        {
            return ServiceResult<ReimbursementResponseDto>.Fail(ServiceErrorCode.BadRequest, "La descripci\u00f3n es obligatoria.");
        }

        if (dto.Amount <= 0)
        {
            return ServiceResult<ReimbursementResponseDto>.Fail(ServiceErrorCode.BadRequest, "El monto debe ser mayor que cero.");
        }

        var entity = new ReimbursementRequest
        {
            EmployeeName = dto.EmployeeName.Trim(),
            Amount = dto.Amount,
            Category = dto.Category.Trim(),
            Description = dto.Description.Trim(),
            Status = dto.Amount <= AutoApprovalLimit ? ReimbursementStatus.Approved : ReimbursementStatus.Pending,
            CreatedAtUtc = DateTime.UtcNow,
            DecidedAtUtc = dto.Amount <= AutoApprovalLimit ? DateTime.UtcNow : null
        };

        _context.ReimbursementRequests.Add(entity);
        await _context.SaveChangesAsync();

        return ServiceResult<ReimbursementResponseDto>.Ok(ToDto(entity));
    }

    public async Task<IEnumerable<ReimbursementResponseDto>> GetAllAsync(string? status, string? employeeName)
    {
        var query = _context.ReimbursementRequests.AsQueryable();

        if (!string.IsNullOrWhiteSpace(status))
        {
            var parsedStatus = Enum.Parse<ReimbursementStatus>(status, ignoreCase: true);
            query = query.Where(r => r.Status == parsedStatus);
        }

        if (!string.IsNullOrWhiteSpace(employeeName))
        {
            query = query.Where(r => r.EmployeeName.Contains(employeeName));
        }

        var list = await query
            .OrderByDescending(r => r.CreatedAtUtc)
            .ToListAsync();

        return list.Select(ToDto);
    }

    public async Task<ServiceResult<ReimbursementResponseDto>> GetByIdAsync(int id)
    {
        var entity = await _context.ReimbursementRequests.FindAsync(id);

        if (entity is null)
        {
            return ServiceResult<ReimbursementResponseDto>.Fail(ServiceErrorCode.NotFound, "No se encontr\u00f3 la solicitud de reembolso.");
        }

        return ServiceResult<ReimbursementResponseDto>.Ok(ToDto(entity));
    }

    public async Task<ServiceResult<ReimbursementResponseDto>> ApproveAsync(int id)
    {
        var entity = await _context.ReimbursementRequests.FindAsync(id);

        if (entity is null)
        {
            return ServiceResult<ReimbursementResponseDto>.Fail(ServiceErrorCode.NotFound, "No se encontr\u00f3 la solicitud de reembolso.");
        }

        if (entity.Status != ReimbursementStatus.Pending)
        {
            return ServiceResult<ReimbursementResponseDto>.Fail(ServiceErrorCode.Conflict, "La solicitud ya fue decidida y no puede modificarse.");
        }

        entity.Status = ReimbursementStatus.Approved;
        entity.DecidedAtUtc = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return ServiceResult<ReimbursementResponseDto>.Ok(ToDto(entity));
    }

    public async Task<ServiceResult<ReimbursementResponseDto>> RejectAsync(int id, string? reason)
    {
        if (string.IsNullOrWhiteSpace(reason))
        {
            return ServiceResult<ReimbursementResponseDto>.Fail(ServiceErrorCode.BadRequest, "Debe indicar el motivo del rechazo.");
        }

        var entity = await _context.ReimbursementRequests.FindAsync(id);

        if (entity is null)
        {
            return ServiceResult<ReimbursementResponseDto>.Fail(ServiceErrorCode.NotFound, "No se encontr\u00f3 la solicitud de reembolso.");
        }

        if (entity.Status != ReimbursementStatus.Pending)
        {
            return ServiceResult<ReimbursementResponseDto>.Fail(ServiceErrorCode.Conflict, "La solicitud ya fue decidida y no puede modificarse.");
        }

        entity.Status = ReimbursementStatus.Rejected;
        entity.RejectionReason = reason.Trim();
        entity.DecidedAtUtc = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return ServiceResult<ReimbursementResponseDto>.Ok(ToDto(entity));
    }

    private static ReimbursementResponseDto ToDto(ReimbursementRequest entity) =>
        new(
            entity.Id,
            entity.EmployeeName,
            entity.Amount,
            entity.Category,
            entity.Description,
            entity.Status.ToString(),
            entity.RejectionReason,
            entity.CreatedAtUtc,
            entity.DecidedAtUtc);
}
