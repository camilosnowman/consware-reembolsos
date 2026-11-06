using Consware.Reimbursements.Api.Data;
using Consware.Reimbursements.Api.Services;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
    });

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddScoped<IReimbursementService, ReimbursementService>();

builder.Services.AddCors(options =>
{
    options.AddPolicy("AngularLocal", policy =>
        policy.WithOrigins("http://localhost:4200", "http://localhost:4201", "http://localhost:4202")
              .AllowAnyHeader()
              .AllowAnyMethod());
});

// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors("AngularLocal");

app.UseAuthorization();

app.MapControllers();

app.Run();
