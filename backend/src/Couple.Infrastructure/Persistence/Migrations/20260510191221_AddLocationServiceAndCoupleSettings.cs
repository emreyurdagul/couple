using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Couple.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddLocationServiceAndCoupleSettings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "CoupleSettings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CoupleId = table.Column<Guid>(type: "uuid", nullable: false),
                    LocationSharingEnabled = table.Column<bool>(type: "boolean", nullable: false),
                    TogetherDistanceMeters = table.Column<int>(type: "integer", nullable: false),
                    LocationHistoryRetentionDays = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CoupleSettings", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "DailyTogetherSummaries",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CoupleId = table.Column<Guid>(type: "uuid", nullable: false),
                    Date = table.Column<DateOnly>(type: "date", nullable: false),
                    TogetherMinutes = table.Column<int>(type: "integer", nullable: false),
                    FirstTogetherAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    LastTogetherAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    ComputedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DailyTogetherSummaries", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_CoupleSettings_CoupleId",
                table: "CoupleSettings",
                column: "CoupleId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DailyTogetherSummaries_CoupleId_Date",
                table: "DailyTogetherSummaries",
                columns: new[] { "CoupleId", "Date" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CoupleSettings");

            migrationBuilder.DropTable(
                name: "DailyTogetherSummaries");
        }
    }
}
