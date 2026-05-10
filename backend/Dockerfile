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
COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:8080/health/live || exit 1

ENTRYPOINT ["dotnet", "Couple.Api.dll"]
