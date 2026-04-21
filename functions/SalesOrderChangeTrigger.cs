using System.Text.Json;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Extensions.Sql;
using Microsoft.Extensions.Logging;
using SendGrid;
using SendGrid.Helpers.Mail;

namespace SqlMirrorAlert;

/// <summary>
/// Azure Functions SQL Trigger — SalesLT.SalesOrderHeader の変更をイベント駆動で検知し、
/// SendGrid 経由でメール通知を送信します。
/// </summary>
public class SalesOrderChangeTrigger
{
    private readonly ILogger<SalesOrderChangeTrigger> _logger;

    public SalesOrderChangeTrigger(ILogger<SalesOrderChangeTrigger> logger)
    {
        _logger = logger;
    }

    [Function(nameof(SalesOrderChangeTrigger))]
    public async Task Run(
        [SqlTrigger("[SalesLT].[SalesOrderHeader]", "SqlConnectionString")]
        IReadOnlyList<SqlChange<SalesOrderHeader>> changes)
    {
        _logger.LogInformation("SQL Trigger fired: {Count} change(s) detected", changes.Count);

        foreach (var change in changes)
        {
            _logger.LogInformation(
                "  Operation={Operation}, SalesOrderID={Id}, OrderDate={OrderDate}, CustomerID={CustomerId}",
                change.Operation,
                change.Item.SalesOrderID,
                change.Item.OrderDate,
                change.Item.CustomerID);
        }

        // SendGrid でメール通知
        var apiKey = Environment.GetEnvironmentVariable("SendGridApiKey");
        var emailTo = Environment.GetEnvironmentVariable("AlertEmailTo");
        var emailFrom = Environment.GetEnvironmentVariable("AlertEmailFrom");

        if (string.IsNullOrEmpty(apiKey) || string.IsNullOrEmpty(emailTo))
        {
            _logger.LogWarning("SendGrid API key or recipient email not configured. Skipping email.");
            return;
        }

        var client = new SendGridClient(apiKey);

        var subject = $"[SQL Mirror Alert] {changes.Count} change(s) detected in SalesOrderHeader";
        var body = FormatChanges(changes);

        var msg = MailHelper.CreateSingleEmail(
            new EmailAddress(emailFrom ?? "noreply@example.com"),
            new EmailAddress(emailTo),
            subject,
            body,
            body);

        var response = await client.SendEmailAsync(msg);

        if (response.IsSuccessStatusCode)
            _logger.LogInformation("Email sent to {To}", emailTo);
        else
            _logger.LogError("Failed to send email: {StatusCode}", response.StatusCode);
    }

    private static string FormatChanges(IReadOnlyList<SqlChange<SalesOrderHeader>> changes)
    {
        var lines = new List<string>
        {
            $"Detected {changes.Count} change(s) in [SalesLT].[SalesOrderHeader]:",
            ""
        };

        foreach (var change in changes)
        {
            lines.Add($"- {change.Operation}: SalesOrderID={change.Item.SalesOrderID}, " +
                       $"CustomerID={change.Item.CustomerID}, " +
                       $"OrderDate={change.Item.OrderDate:yyyy-MM-dd HH:mm:ss}, " +
                       $"SubTotal={change.Item.SubTotal:C}");
        }

        lines.Add("");
        lines.Add($"Timestamp (UTC): {DateTime.UtcNow:yyyy-MM-dd HH:mm:ss}");

        return string.Join(Environment.NewLine, lines);
    }
}

/// <summary>
/// SalesLT.SalesOrderHeader のカラムに対応する POCO
/// </summary>
public class SalesOrderHeader
{
    public int SalesOrderID { get; set; }
    public byte RevisionNumber { get; set; }
    public DateTime OrderDate { get; set; }
    public DateTime DueDate { get; set; }
    public DateTime? ShipDate { get; set; }
    public byte Status { get; set; }
    public bool OnlineOrderFlag { get; set; }
    public string? SalesOrderNumber { get; set; }
    public string? PurchaseOrderNumber { get; set; }
    public string? AccountNumber { get; set; }
    public int CustomerID { get; set; }
    public int? ShipToAddressID { get; set; }
    public int? BillToAddressID { get; set; }
    public string? ShipMethod { get; set; }
    public string? CreditCardApprovalCode { get; set; }
    public decimal SubTotal { get; set; }
    public decimal TaxAmt { get; set; }
    public decimal Freight { get; set; }
    public decimal TotalDue { get; set; }
    public string? Comment { get; set; }
    public Guid rowguid { get; set; }
    public DateTime ModifiedDate { get; set; }
}
