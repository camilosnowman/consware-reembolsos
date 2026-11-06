using Consware.Reimbursements.Api.Dtos;
using Consware.Reimbursements.Api.Models;
using Consware.Reimbursements.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Consware.Reimbursements.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ReimbursementsController : ControllerBase
{
    private readonly IReimbursementService _service;

    public ReimbursementsController(IReimbursementService service)
    {
        _service = service;
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateReimbursementDto dto)
    {
        var result = await _service.CreateAsync(dto);

        if (!result.Success)
        {
            return BadRequest(new { message = result.Message });
        }

        return CreatedAtAction(
            nameof(GetById),
            new { id = result.Value!.Id },
            result.Value);
    }

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] string? status, [FromQuery] string? employeeName)
    {
        if (!string.IsNullOrWhiteSpace(status)
            && !Enum.TryParse<ReimbursementStatus>(status, ignoreCase: true, out _))
        {
            return BadRequest(new { message = "El estado proporcionado no es válido." });
        }

        var list = await _service.GetAllAsync(status, employeeName);
        return Ok(list);
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var result = await _service.GetByIdAsync(id);

        if (!result.Success)
        {
            return StatusCode((int)StatusToHttp(result.ErrorCode), new { message = result.Message });
        }

        return Ok(result.Value);
    }

    [HttpPatch("{id:int}/approve")]
    public async Task<IActionResult> Approve(int id)
    {
        var result = await _service.ApproveAsync(id);

        if (!result.Success)
        {
            return StatusCode((int)StatusToHttp(result.ErrorCode), new { message = result.Message });
        }

        return Ok(result.Value);
    }

    [HttpPatch("{id:int}/reject")]
    public async Task<IActionResult> Reject(int id, [FromBody] RejectReimbursementDto dto)
    {
        var result = await _service.RejectAsync(id, dto?.Reason);

        if (!result.Success)
        {
            return StatusCode((int)StatusToHttp(result.ErrorCode), new { message = result.Message });
        }

        return Ok(result.Value);
    }

    private static System.Net.HttpStatusCode StatusToHttp(ServiceErrorCode code) =>
        code switch
        {
            ServiceErrorCode.BadRequest => System.Net.HttpStatusCode.BadRequest,
            ServiceErrorCode.NotFound => System.Net.HttpStatusCode.NotFound,
            ServiceErrorCode.Conflict => System.Net.HttpStatusCode.Conflict,
            _ => System.Net.HttpStatusCode.InternalServerError
        };
}
