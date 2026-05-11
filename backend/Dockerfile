FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY Couple.slnx ./
COPY src/Couple.Api/Couple.Api.csproj src/Couple.Api/
COPY src/Couple.Domain/Couple.Domain.csproj src/Couple.Domain/
COPY src/Couple.Infrastructure/Couple.Infrastructure.csproj src/Couple.Infrastructure/
RUN dotnet restore Couple.slnx

COPY . .
RUN dotnet publish src/Couple.Api/Couple.Api.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

# curl healthcheck için; libgssapi-krb5-2 Npgsql'in soft load uyarısını susturur
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl libgssapi-krb5-2 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=30s \
  CMD curl -fsS http://localhost:8080/health/live || exit 1

ENTRYPOINT ["dotnet", "Couple.Api.dll"]
