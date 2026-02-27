# ══════════════════════════════════════════════════════════════════════════════
# CAPA 3: TEJIDO EMPRESARIAL — Metro Línea 1
# Equipo CyberRosario — Datajam Seguridad CCB
# ══════════════════════════════════════════════════════════════════════════════

library(sf)
library(dplyr)
library(readxl)
library(osmdata)
library(stringdist)

cat("═══ CAPA 3: TEJIDO EMPRESARIAL ═══\n\n")

# ── RUTAS ─────────────────────────────────────────────────────────────────────
path_datajam  <- "~/Documents/FastAnalytics/Proyectos/datajam_seguridad_ccb"
path_rm24     <- file.path(path_datajam,
                           "Base Registro Mercantil 2024/Base total activas 2024 - anonimizada.xlsx")
path_rm25     <- file.path(path_datajam,
                           "Base Registro Mercantil 2025/Base Registro Mercantil 2025_2.xlsx")
path_stations <- "data/estaciones_metro_l1.geojson"

# ── 1. CARGAR HEX GRID Y RECONSTRUIR GEOMETRÍA DEL METRO ────────────────────
cat("1. Cargando hex_grid y reconstruyendo buffer del Metro...\n")
hex_grid <- readRDS("data/hex_grid_metro.rds")
cat("   Hexágonos:", nrow(hex_grid), "\n")

est <- st_read(path_stations, quiet = TRUE)
st_crs(est) <- 6247
est_3116 <- st_transform(est, 3116)
centroids_3116 <- st_centroid(est_3116)
orden <- order(as.integer(est$NUMERO))
coords_3116 <- st_coordinates(centroids_3116[orden, ])
metro_line <- st_sfc(st_linestring(coords_3116[, 1:2]), crs = 3116)
buffer_metro <- st_buffer(metro_line, 1500)

# ── 2. OBTENER LÍMITES DE LOCALIDADES DESDE OSM ─────────────────────────────
cat("2. Descargando límites de localidades desde OSM...\n")

# Bbox del buffer en WGS84
buffer_wgs <- st_transform(buffer_metro, 4326)
bb <- st_bbox(buffer_wgs)

localidades_osm <- tryCatch({
  q <- opq(bbox = as.numeric(bb)) |>
    add_osm_feature(key = "boundary", value = "administrative") |>
    add_osm_feature(key = "admin_level", value = "8")
  result <- osmdata_sf(q)

  locs <- result$osm_multipolygons
  if (!is.null(locs) && nrow(locs) > 0) {
    # Limpiar nombres: "Localidad Kennedy" → "KENNEDY"
    locs$loc_name <- toupper(gsub("^Localidad\\s+", "", locs$name))
    locs <- locs[, c("loc_name", "geometry")]
    locs <- st_transform(locs, 3116)
    cat("   Localidades descargadas:", nrow(locs), "\n")
    cat("   Nombres:", paste(locs$loc_name, collapse = ", "), "\n")
    locs
  } else {
    NULL
  }
}, error = function(e) {
  cat("   Error descargando localidades:", e$message, "\n")
  NULL
})

if (is.null(localidades_osm)) {
  stop("No se pudieron obtener límites de localidades desde OSM. Verifica conexión a internet.")
}

# Intersectar localidades con buffer del metro
localidades_metro <- localidades_osm[st_intersects(localidades_osm, buffer_metro,
                                                    sparse = FALSE)[, 1], ]
cat("   Localidades que intersectan el buffer:", nrow(localidades_metro), "\n")
cat("   →", paste(localidades_metro$loc_name, collapse = ", "), "\n")

# ── 3. ASIGNAR LOCALIDAD A CADA HEXÁGONO ────────────────────────────────────
cat("3. Asignando localidad a cada hexágono...\n")

hex_centroids <- st_centroid(hex_grid)
hex_loc_join <- st_join(hex_centroids["hex_id"], localidades_metro["loc_name"], left = TRUE)
hex_loc <- hex_loc_join |> st_drop_geometry()

# Algunos hexágonos pueden quedar sin localidad (frontera)
cat("   Hexágonos con localidad:", sum(!is.na(hex_loc$loc_name)), "/", nrow(hex_loc), "\n")

# ── 4. CARGAR REGISTRO MERCANTIL 2024 ───────────────────────────────────────
cat("4. Cargando Registro Mercantil 2024...\n")

# Localidades del corredor Metro (nombres como aparecen en el RM)
localidades_metro_rm <- c("Bosa", "Kennedy", "Puente Aranda", "Antonio Nari",
                          "Los Martires", "Santa Fe", "Teusaquillo",
                          "Chapinero", "Barrios Unidos", "Fontibon",
                          "Candelaria", "Tunjuelito", "Rafael Uribe")

cols_rm24 <- c("LocalidadComercial", "BarrioComercialGoerreferenciada",
               "FechaMatricula", "FechaRenova", "UltimoAñoRenovado",
               "TamañoEmpresa", "CiiuPrincipal", "SECTOR_ECONOMICO",
               "Genero", "Activos", "PersonalOcupado", "EstadoMatrícula")

rm24 <- read_xlsx(path_rm24)
cat("   RM 2024 total:", nrow(rm24), "filas\n")

# Filtrar por localidades del corredor
rm24$loc_upper <- toupper(rm24$LocalidadComercial)
rm24_metro <- rm24[grepl(paste(toupper(localidades_metro_rm), collapse = "|"),
                         rm24$loc_upper, ignore.case = TRUE), ]
cat("   RM 2024 filtrado (localidades Metro):", nrow(rm24_metro), "\n")

# Extraer código de localidad del campo (e.g., "08 Kennedy" → "KENNEDY")
rm24_metro$loc_clean <- toupper(gsub("^[0-9]+\\s+", "", rm24_metro$LocalidadComercial))

# ── 5. CARGAR REGISTRO MERCANTIL 2025 ───────────────────────────────────────
cat("5. Cargando Registro Mercantil 2025...\n")

rm25 <- read_xlsx(path_rm25)
cat("   RM 2025 total:", nrow(rm25), "filas\n")

rm25$loc_upper <- toupper(rm25$LocalidadComercial)
rm25_metro <- rm25[grepl(paste(toupper(localidades_metro_rm), collapse = "|"),
                         rm25$loc_upper, ignore.case = TRUE), ]
cat("   RM 2025 filtrado (localidades Metro):", nrow(rm25_metro), "\n")

rm25_metro$loc_clean <- toupper(gsub("^[0-9]+\\s+", "", rm25_metro$LocalidadComercial))

# Liberar los dataframes completos
rm(rm24, rm25)
gc(verbose = FALSE)

# ── 6. MATCHING LOCALIDADES RM ↔ OSM ────────────────────────────────────────
cat("6. Matching localidades RM ↔ OSM...\n")

# Normalizar nombres para matching
normalize_loc <- function(x) {
  x <- toupper(x)
  x <- gsub("[^A-Z ]", "", x)
  x <- trimws(x)
  x
}

locs_osm_names <- normalize_loc(localidades_metro$loc_name)
locs_rm_names  <- unique(normalize_loc(rm24_metro$loc_clean))

# Fuzzy matching
match_table <- data.frame(rm_name = locs_rm_names, stringsAsFactors = FALSE)
match_table$osm_name <- NA
for (i in seq_len(nrow(match_table))) {
  dists <- stringdist(match_table$rm_name[i], locs_osm_names, method = "jw")
  best <- which.min(dists)
  if (dists[best] < 0.3) {  # umbral de similitud
    match_table$osm_name[i] <- localidades_metro$loc_name[best]
  }
}

cat("   Matching localidades:\n")
for (i in seq_len(nrow(match_table))) {
  cat("     RM:", match_table$rm_name[i], "→ OSM:",
      ifelse(is.na(match_table$osm_name[i]), "SIN MATCH", match_table$osm_name[i]), "\n")
}

# Asignar nombre OSM a RM
rm24_metro$loc_osm <- match_table$osm_name[match(normalize_loc(rm24_metro$loc_clean),
                                                   match_table$rm_name)]
rm25_metro$loc_osm <- match_table$osm_name[match(normalize_loc(rm25_metro$loc_clean),
                                                   match_table$rm_name)]

cat("   RM 2024 con match:", sum(!is.na(rm24_metro$loc_osm)), "/", nrow(rm24_metro), "\n")
cat("   RM 2025 con match:", sum(!is.na(rm25_metro$loc_osm)), "/", nrow(rm25_metro), "\n")

# ── 7. MÉTRICAS EMPRESARIALES POR LOCALIDAD ─────────────────────────────────
cat("7. Calculando métricas empresariales por localidad...\n")

# 7a. Conteo y estructura empresarial 2024
emp_stats_24 <- rm24_metro |>
  filter(!is.na(loc_osm)) |>
  group_by(loc_osm) |>
  summarise(
    n_empresas_2024 = n(),
    pct_micro = mean(grepl("Micro", TamañoEmpresa, ignore.case = TRUE), na.rm = TRUE),
    pct_pequena = mean(grepl("Peque", TamañoEmpresa, ignore.case = TRUE), na.rm = TRUE),
    pct_mediana = mean(grepl("Mediana", TamañoEmpresa, ignore.case = TRUE), na.rm = TRUE),
    pct_grande = mean(grepl("Grande", TamañoEmpresa, ignore.case = TRUE), na.rm = TRUE),
    pct_mipyme = pct_micro + pct_pequena + pct_mediana,
    n_sectores = n_distinct(SECTOR_ECONOMICO, na.rm = TRUE),
    activos_median = median(as.numeric(Activos), na.rm = TRUE),
    pct_mujer = mean(grepl("Femenino|Mujer", Genero, ignore.case = TRUE), na.rm = TRUE),
    .groups = "drop"
  )

# 7b. Conteo 2025
emp_stats_25 <- rm25_metro |>
  filter(!is.na(loc_osm)) |>
  group_by(loc_osm) |>
  summarise(
    n_empresas_2025 = n(),
    .groups = "drop"
  )

# 7c. Empresas nuevas (matrícula >= 2021 = abiertas durante obra)
rm24_metro$año_matricula <- as.integer(substr(as.character(rm24_metro$FechaMatricula), 1, 4))
# Si FechaMatricula es Date, extraer año directamente
if (inherits(rm24_metro$FechaMatricula, "POSIXct") || inherits(rm24_metro$FechaMatricula, "Date")) {
  rm24_metro$año_matricula <- as.integer(format(rm24_metro$FechaMatricula, "%Y"))
}

emp_nuevas <- rm24_metro |>
  filter(!is.na(loc_osm), !is.na(año_matricula)) |>
  group_by(loc_osm) |>
  summarise(
    empresas_nuevas = sum(año_matricula >= 2021, na.rm = TRUE),
    pct_nuevas = mean(año_matricula >= 2021, na.rm = TRUE),
    .groups = "drop"
  )

# 7d. Juntar todo
emp_loc <- emp_stats_24 |>
  left_join(emp_stats_25, by = "loc_osm") |>
  left_join(emp_nuevas, by = "loc_osm")

# Tasa de cambio (proxy de cierre/apertura)
emp_loc$cambio_empresas <- (emp_loc$n_empresas_2025 - emp_loc$n_empresas_2024) /
                            emp_loc$n_empresas_2024

cat("   Métricas por localidad:\n")
for (i in seq_len(nrow(emp_loc))) {
  cat("     ", emp_loc$loc_osm[i], "— emp2024:", emp_loc$n_empresas_2024[i],
      "| emp2025:", emp_loc$n_empresas_2025[i],
      "| cambio:", round(emp_loc$cambio_empresas[i] * 100, 1), "%",
      "| mipyme:", round(emp_loc$pct_mipyme[i] * 100), "%\n")
}

# ── 8. ANÁLISIS POR SECTOR ECONÓMICO ────────────────────────────────────────
cat("\n8. Análisis por sector económico...\n")

sector_stats <- rm24_metro |>
  filter(!is.na(loc_osm), !is.na(SECTOR_ECONOMICO)) |>
  count(SECTOR_ECONOMICO, name = "n") |>
  arrange(desc(n)) |>
  head(15)

cat("   Top 15 sectores en corredor Metro:\n")
for (i in seq_len(nrow(sector_stats))) {
  cat("     ", sector_stats$n[i], "—", sector_stats$SECTOR_ECONOMICO[i], "\n")
}

# ── 9. ASIGNAR MÉTRICAS A HEXÁGONOS ─────────────────────────────────────────
cat("\n9. Asignando métricas empresariales a hexágonos...\n")

# Unir hex_loc (hex_id → loc_name) con emp_loc (loc_osm → métricas)
hex_emp <- hex_loc |>
  left_join(emp_loc, by = c("loc_name" = "loc_osm"))

# Calcular densidad: empresas por hectárea de la localidad dentro del buffer
# Área de cada localidad dentro del buffer
locs_in_buffer <- st_intersection(localidades_metro, buffer_metro)
locs_in_buffer$area_ha <- as.numeric(st_area(locs_in_buffer)) / 10000

loc_areas <- locs_in_buffer |>
  st_drop_geometry() |>
  select(loc_name, area_ha)

hex_emp <- hex_emp |>
  left_join(loc_areas, by = c("loc_name" = "loc_name"))

# Densidad empresarial (empresas / hectárea dentro del buffer de la localidad)
hex_emp$densidad_empresas <- hex_emp$n_empresas_2024 / hex_emp$area_ha

# Seleccionar columnas para unir a hex_grid
cols_join <- c("hex_id", "n_empresas_2024", "n_empresas_2025", "pct_mipyme",
               "n_sectores", "empresas_nuevas", "pct_nuevas",
               "cambio_empresas", "densidad_empresas", "activos_median", "pct_mujer")

hex_emp_join <- hex_emp[, cols_join[cols_join %in% names(hex_emp)]]

# Eliminar columnas viejas si ya existen en hex_grid
for (col in names(hex_emp_join)) {
  if (col != "hex_id" && col %in% names(hex_grid)) {
    hex_grid[[col]] <- NULL
  }
}

hex_grid <- hex_grid |>
  left_join(hex_emp_join, by = "hex_id")

cat("   Hexágonos con datos empresariales:", sum(!is.na(hex_grid$n_empresas_2024)), "\n")

# ── 10. GRÁFICOS ────────────────────────────────────────────────────────────
cat("\n10. Generando gráficos...\n")
dir.create("output", showWarnings = FALSE)

# Empresas por distancia al metro
hex_df <- hex_grid |> st_drop_geometry()
hex_df$dist_bin <- cut(hex_df$dist_metro,
                       breaks = seq(0, 1500, by = 250),
                       labels = paste0(seq(0, 1250, by = 250), "-",
                                      seq(250, 1500, by = 250), "m"))

dist_summary <- hex_df |>
  filter(!is.na(dist_bin) & !is.na(densidad_empresas)) |>
  group_by(dist_bin) |>
  summarise(
    densidad_media = mean(densidad_empresas, na.rm = TRUE),
    pct_mipyme_media = mean(pct_mipyme, na.rm = TRUE),
    .groups = "drop"
  )

png("output/empresas_por_distancia.png", width = 900, height = 500, res = 120)
par(mfrow = c(1, 2), mar = c(5, 4, 3, 1))
barplot(dist_summary$densidad_media, names.arg = dist_summary$dist_bin,
        col = "#2196F3", main = "Densidad empresarial por distancia al Metro",
        xlab = "Distancia", ylab = "Empresas / hectárea", las = 2, cex.names = 0.8)
barplot(dist_summary$pct_mipyme_media * 100, names.arg = dist_summary$dist_bin,
        col = "#FF9800", main = "% MiPymes por distancia al Metro",
        xlab = "Distancia", ylab = "% MiPymes", las = 2, cex.names = 0.8,
        ylim = c(0, 100))
par(mfrow = c(1, 1))
dev.off()
cat("   Guardado: output/empresas_por_distancia.png\n")

# Sector económico
png("output/empresas_por_sector.png", width = 900, height = 600, res = 120)
par(mar = c(5, 12, 3, 1))
barplot(rev(sector_stats$n), names.arg = rev(sector_stats$SECTOR_ECONOMICO),
        horiz = TRUE, col = "#4CAF50", las = 1, cex.names = 0.7,
        main = "Top 15 sectores económicos en corredor Metro L1",
        xlab = "Número de empresas")
par(mar = c(5, 4, 4, 2))
dev.off()
cat("   Guardado: output/empresas_por_sector.png\n")

# ── 11. GUARDAR ─────────────────────────────────────────────────────────────
cat("\n11. Guardando hex_grid actualizado...\n")
saveRDS(hex_grid, "data/hex_grid_metro.rds")
cat("   Nuevas columnas empresariales añadidas al hex_grid\n")

# Guardar localidades como referencia
saveRDS(localidades_metro, "data/localidades_metro.rds")
cat("   Guardado: data/localidades_metro.rds\n")

# Liberar memoria
rm(rm24_metro, rm25_metro, hex_emp, emp_loc)
gc(verbose = FALSE)

cat("\n═══ CAPA 3: TEJIDO EMPRESARIAL COMPLETADO ═══\n")
