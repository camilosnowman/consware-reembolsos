using Consware.Reimbursements.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Consware.Reimbursements.Api.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<ReimbursementRequest> ReimbursementRequests => Set<ReimbursementRequest>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<ReimbursementRequest>(entity =>
        {
            entity.ToTable("ReimbursementRequests");

            entity.HasKey(e => e.Id);

            entity.Property(e => e.Id)
                .UseIdentityColumn();

            entity.Property(e => e.EmployeeName)
                .IsRequired()
                .HasMaxLength(100);

            entity.Property(e => e.Amount)
                .HasColumnType("decimal(18,2)")
                .HasPrecision(18, 2);

            entity.Property(e => e.Category)
                .IsRequired()
                .HasMaxLength(60);

            entity.Property(e => e.Description)
                .IsRequired()
                .HasMaxLength(500);

            entity.Property(e => e.Status)
                .IsRequired()
                .HasConversion<string>()
                .HasColumnType("varchar(16)");

            entity.Property(e => e.RejectionReason)
                .HasMaxLength(500);

            entity.Property(e => e.CreatedAtUtc)
                .HasColumnType("datetime2");

            entity.Property(e => e.DecidedAtUtc)
                .HasColumnType("datetime2");

            entity.HasIndex(e => e.Status);

            entity.HasIndex(e => e.EmployeeName);
        });
    }
}
