FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /app

# Copiar solo el csproj y restaurar dependencias (mejor cache de Docker)
COPY *.csproj ./
RUN dotnet restore

# Copiar el resto del código y publicar
COPY . ./
RUN dotnet publish -c Release -o out --no-restore

# Imagen de runtime (más ligera)
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /app/out ./
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "UniserviceAPI.dll"]
