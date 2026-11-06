using Consware.Reimbursements.Api.Data;
using Consware.Reimbursements.Api.Dtos;
using Consware.Reimbursements.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Consware.Reimbursements.Api.Services;

public class ReimbursementService : IReimbursementService
{
    private readonly AppDbContext _context;

    public ReimbursementService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<ServiceResult<ReimbursementResponseDto>> CreateAsync(CreateReimbursementDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.EmployeeName))
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

        // Longitudes validadas tras Trim: el exceso se rechaza con 400, no con 500 por SQL.
        if (!ReimbursementValidation.FitsLengthAfterTrim(dto.EmployeeName, ReimbursementValidation.EmployeeNameMaxLength))
        {
            return ServiceResult<ReimbursementResponseDto>.Fail(ServiceErrorCode.BadRequest, $"El nombre del empleado no puede superar {ReimbursementValidation.EmployeeNameMaxLength} caracteres.");
        }

        if (!ReimbursementValidation.FitsLengthAfterTrim(dto.Category, ReimbursementValidation.CategoryMaxLength))
        {
            return ServiceResult<ReimbursementResponseDto>.Fail(ServiceErrorCode.BadRequest, $"La categor\u00eda no puede superar {ReimbursementValidation.CategoryMaxLength} caracteres.");
        }

        if (!ReimbursementValidation.FitsLengthAfterTrim(dto.Description, ReimbursementValidation.DescriptionMaxLength))
        {
            return ServiceResult<ReimbursementResponseDto>.Fail(ServiceErrorCode.BadRequest, $"La descripci\u00f3n no puede superar {ReimbursementValidation.DescriptionMaxLength} caracteres.");
        }

        // El monto se valida antes de decidir el estado y de persistir: ni redondeo silencioso ni error de SQL.
        var amountError = ReimbursementValidation.ValidateAmount(dto.Amount);
        if (amountError is not null)
        {
            return ServiceResult<ReimbursementResponseDto>.Fail(ServiceErrorCode.BadRequest, amountError);
        }

        var autoApproved = ReimbursementValidation.IsAutoApproved(dto.Amount);
        var createdAtUtc = DateTime.UtcNow;

        var entity = new ReimbursementRequest
        {
            EmployeeName = dto.EmployeeName.Trim(),
            Amount = dto.Amount,
            Category = dto.Category.Trim(),
            Description = dto.Description.Trim(),
            Status = autoApproved ? ReimbursementStatus.Approved : ReimbursementStatus.Pending,
            CreatedAtUtc = createdAtUtc,
            DecidedAtUtc = autoApproved ? createdAtUtc : null
        };

        _context.ReimbursementRequests.Add(entity);
        await _context.SaveChangesAsync();

        return ServiceResult<ReimbursementResponseDto>.Ok(ToDto(entity));
    }

    public async Task<ServiceResult<IEnumerable<ReimbursementResponseDto>>> GetAllAsync(string? status, string? employeeName)
    {
        ReimbursementStatus? statusFilter = null;

        // Estados no definidos (texto inv\u00e1lido o num\u00e9ricos como 999) se rechazan con 400.
        if (!string.IsNullOrWhiteSpace(status))
        {
            if (!ReimbursementValidation.TryParseStatus(status, out var parsedStatus))
            {
                return ServiceResult<IEnumerable<ReimbursementResponseDto>>.Fail(ServiceErrorCode.BadRequest, "El estado proporcionado no es v\u00e1lido.");
            }

            statusFilter = parsedStatus;
        }

        var query = _context.ReimbursementRequests.AsNoTracking();

        if (statusFilter.HasValue)
        {
            query = query.Where(r => r.Status == statusFilter.Value);
        }

        if (!string.IsNullOrWhiteSpace(employeeName))
        {
            query = query.Where(r => r.EmployeeName.Contains(employeeName));
        }

        var list = await query
            .OrderByDescending(r => r.CreatedAtUtc)
            .ToListAsync();

        return ServiceResult<IEnumerable<ReimbursementResponseDto>>.Ok(list.Select(ToDto));
    }

    public async Task<ServiceResult<ReimbursementResponseDto>> GetByIdAsync(int id)
    {
        var entity = await _context.ReimbursementRequests
            .AsNoTracking()
            .FirstOrDefaultAsync(r => r.Id == id);

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

        if (!ReimbursementValidation.FitsLengthAfterTrim(reason, ReimbursementValidation.RejectionReasonMaxLength))
        {
            return ServiceResult<ReimbursementResponseDto>.Fail(ServiceErrorCode.BadRequest, $"El motivo del rechazo no puede superar {ReimbursementValidation.RejectionReasonMaxLength} caracteres.");
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
            // datetime2 pierde el Kind al leer de SQL; se re-etiqueta como UTC para
            // que la serializaci\u00f3n incluya el sufijo Z en CreatedAtUtc y DecidedAtUtc.
            ReimbursementValidation.AsUtc(entity.CreatedAtUtc),
            ReimbursementValidation.AsUtc(entity.DecidedAtUtc));
}
