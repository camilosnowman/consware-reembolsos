using System.Globalization;
using Consware.Reimbursements.Api.Models;

namespace Consware.Reimbursements.Api.Services;

/// <summary>
/// Reglas de validación de entrada de reembolsos. Se validan antes de decidir el
/// estado o persistir, para rechazar con 400 en lugar de fallar contra SQL o
/// redondear en silencio. Cubiertas por pruebas unitarias sin base de datos.
/// </summary>
internal static class ReimbursementValidation
{
    /// <summary>Tope (incluido) por debajo del cual una solicitud se aprueba automáticamente.</summary>
    public const decimal AutoApprovalLimit = 500000m;

    /// <summary>Máximo admitido por la columna decimal(18,2) de Amount.</summary>
    public const decimal SqlAmountMaximum = 9999999999999999.99m;

    /// <summary>Cantidad máxima de decimales significativos del monto.</summary>
    public const int AmountScale = 2;

    /// <summary>Longitud máxima del nombre del empleado (tras Trim), igual a nvarchar(100).</summary>
    public const int EmployeeNameMaxLength = 100;

    /// <summary>Longitud máxima de la categoría (tras Trim), igual a nvarchar(60).</summary>
    public const int CategoryMaxLength = 60;

    /// <summary>Longitud máxima de la descripción (tras Trim), igual a nvarchar(500).</summary>
    public const int DescriptionMaxLength = 500;

    /// <summary>Longitud máxima del motivo del rechazo (tras Trim), igual a nvarchar(500).</summary>
    public const int RejectionReasonMaxLength = 500;

    /// <summary>
    /// Valida el monto: positivo, dentro del rango de decimal(18,2) y con a lo sumo
    /// dos decimales significativos (0.001 y 500000.001 se rechazan, no se redondean).
    /// Devuelve el mensaje de error o null si el monto es válido.
    /// </summary>
    public static string? ValidateAmount(decimal amount)
    {
        if (amount <= 0)
        {
            return "El monto debe ser mayor que cero.";
        }

        if (amount > SqlAmountMaximum)
        {
            return $"El monto no puede superar {SqlAmountMaximum.ToString(CultureInfo.InvariantCulture)}.";
        }

        if (decimal.Round(amount, AmountScale) != amount)
        {
            return "El monto admite como máximo dos decimales.";
        }

        return null;
    }

    /// <summary>Determina si un monto ya validado se aprueba automáticamente (tope incluido).</summary>
    public static bool IsAutoApproved(decimal amount) => amount <= AutoApprovalLimit;

    /// <summary>
    /// Valida la longitud de un texto tras Trim: los límites aplican sobre el valor
    /// normalizado, por lo que "  &lt;100 caracteres&gt;  " se acepta y 101 caracteres no.
    /// </summary>
    public static bool FitsLengthAfterTrim(string? value, int maxLength) => (value?.Trim().Length ?? 0) <= maxLength;

    /// <summary>
    /// Convierte un estado en texto a un valor definido del enumerador, sin distinguir
    /// mayúsculas. Rechaza texto inválido y valores numéricos fuera del enumerador
    /// (por ejemplo 999), a diferencia de Enum.Parse.
    /// </summary>
    public static bool TryParseStatus(string? status, out ReimbursementStatus parsed)
    {
        parsed = default;

        if (string.IsNullOrWhiteSpace(status))
        {
            return false;
        }

        return Enum.TryParse(status, ignoreCase: true, out parsed) && Enum.IsDefined(parsed);
    }

    /// <summary>
    /// Re-etiqueta como UTC una fecha leída de SQL: datetime2 pierde el Kind y sin
    /// esto la serialización JSON omite el sufijo Z. No altera los ticks.
    /// </summary>
    public static DateTime AsUtc(DateTime value) => DateTime.SpecifyKind(value, DateTimeKind.Utc);

    /// <summary>Variante nullable: conserva null y re-etiqueta como UTC el valor presente.</summary>
    public static DateTime? AsUtc(DateTime? value) => value is null ? null : DateTime.SpecifyKind(value.Value, DateTimeKind.Utc);
}
