# ══════════════════════════════════════════════════════════════════════════════
# CO-KRIGING PIPELINE — Reto 2: Seguridad y Obras Públicas
# Equipo CyberRosario — Datajam Seguridad CCB
# ══════════════════════════════════════════════════════════════════════════════

library(sf)
library(gstat)
library(dplyr)
library(readxl)
library(tidyr)

cat("═══ CO-KRIGING PIPELINE ═══\n\n")

# ── RUTAS ─────────────────────────────────────────────────────────────────────
path_crime    <- "~/Documents/GitHub/Impact-evaluation-peace-process/datasets"
path_datajam  <- "~/Documents/FastAnalytics/Proyectos/datajam_seguridad_ccb"
path_epv      <- file.path(path_datajam, "EPV_Encuesta de Percepción y Victimización/2025",
                           "Base Encuesta de Percepción Victimización 2025 anonimizada.xlsx")
path_stations <- "data/estaciones_metro_l1.geojson"

# ── 1. LEER ESTACIONES Y CREAR LÍNEA DEL METRO ──────────────────────────────
cat("1. Leyendo estaciones del Metro L1...\n")
est <- st_read(path_stations, quiet = TRUE)
st_crs(est) <- 6247
est_3116 <- st_transform(est, 3116)
centroids_3116 <- st_centroid(est_3116)

orden <- order(as.integer(est$NUMERO))
coords_3116 <- st_coordinates(centroids_3116[orden, ])
metro_line <- st_sfc(st_linestring(coords_3116[, 1:2]), crs = 3116)

# Buffer de 1.5km para tener margen
buffer_metro <- st_buffer(metro_line, 1500)
cat("   Buffer 1.5km creado\n")

# ── 2. CREAR GRILLA HEXAGONAL 200m ──────────────────────────────────────────
cat("2. Creando grilla hexagonal 200m...\n")
hex_grid <- st_make_grid(buffer_metro, cellsize = 200, square = FALSE)
hex_grid <- st_sf(hex_id = seq_along(hex_grid), geometry = hex_grid)
st_crs(hex_grid) <- 3116

# Quedarse solo con hexágonos que intersectan el buffer
hex_grid <- hex_grid[st_intersects(hex_grid, buffer_metro, sparse = FALSE)[, 1], ]
hex_grid$hex_id <- seq_len(nrow(hex_grid))

# Centroides para el variograma
hex_grid$centroid_x <- st_coordinates(st_centroid(hex_grid))[, 1]
hex_grid$centroid_y <- st_coordinates(st_centroid(hex_grid))[, 2]

# Distancia de cada hexágono a la línea del metro
hex_grid$dist_metro <- as.numeric(st_distance(st_centroid(hex_grid), metro_line))

cat("   Hexágonos creados:", nrow(hex_grid), "\n")

# ── 3. CARGAR DELITOS Y ASIGNAR A HEXÁGONOS ─────────────────────────────────
cat("3. Cargando delitos...\n")

load_crime <- function(file, label) {
  df <- read.csv2(file, stringsAsFactors = FALSE)  # sep=";", dec=","
  df$lat_var <- as.numeric(gsub(",", ".", df$lat_var))
  df$lon_var <- as.numeric(gsub(",", ".", df$lon_var))
  # Filtrar Bogotá por bounding box aproximado
  df <- df[!is.na(df$lat_var) & !is.na(df$lon_var), ]
  df <- df[df$lat_var > 4.4 & df$lat_var < 4.85 &
           df$lon_var > -74.25 & df$lon_var < -73.95, ]
  # Extraer año
  df$year <- as.integer(substr(df$date_var, 7, 10))
  pts <- st_as_sf(df, coords = c("lon_var", "lat_var"), crs = 4326)
  pts <- st_transform(pts, 3116)
  # Filtrar a buffer del metro
  pts <- pts[st_intersects(pts, buffer_metro, sparse = FALSE)[, 1], ]
  cat("  ", label, "en buffer:", nrow(pts), "\n")
  pts$crime_type <- label
  return(pts)
}

shoplifting <- load_crime(file.path(path_crime, "larceny/shoplifting.csv"), "shoplifting")
theft       <- load_crime(file.path(path_crime, "larceny/theft.csv"), "theft")
extortion   <- load_crime(file.path(path_crime, "violent/extortion.csv"), "extortion")
assault     <- load_crime(file.path(path_crime, "violent/assault.csv"), "assault")

# Contar delitos por hexágono — periodo DURANTE obra (2021-2023)
count_in_hex <- function(pts, hex, col_name, year_min = 2021, year_max = 2023) {
  pts_filtered <- pts[pts$year >= year_min & pts$year <= year_max, ]
  joined <- st_join(hex["hex_id"], pts_filtered, left = TRUE)
  counts <- joined |> st_drop_geometry() |> count(hex_id, name = col_name)
  counts[[col_name]][is.na(counts[[col_name]])] <- 0
  return(counts)
}

cat("   Contando delitos por hexágono (2021-2023)...\n")
c1 <- count_in_hex(shoplifting, hex_grid, "shoplifting")
c2 <- count_in_hex(theft, hex_grid, "theft")
c3 <- count_in_hex(extortion, hex_grid, "extortion")
c4 <- count_in_hex(assault, hex_grid, "assault")

hex_grid <- hex_grid |>
  left_join(c1, by = "hex_id") |>
  left_join(c2, by = "hex_id") |>
  left_join(c3, by = "hex_id") |>
  left_join(c4, by = "hex_id")

# Reemplazar NA con 0
hex_grid$shoplifting[is.na(hex_grid$shoplifting)] <- 0
hex_grid$theft[is.na(hex_grid$theft)] <- 0
hex_grid$extortion[is.na(hex_grid$extortion)] <- 0
hex_grid$assault[is.na(hex_grid$assault)] <- 0

# Transformación log
hex_grid$log_shoplifting <- log(hex_grid$shoplifting + 1)
hex_grid$log_theft       <- log(hex_grid$theft + 1)
hex_grid$log_extortion   <- log(hex_grid$extortion + 1)
hex_grid$log_assault     <- log(hex_grid$assault + 1)

cat("   Delitos asignados a hexágonos\n")

# Liberar memoria
rm(shoplifting, theft, extortion, assault, c1, c2, c3, c4)
gc(verbose = FALSE)

# ── 4. CARGAR EPV 2025 (PERCEPCIÓN) ─────────────────────────────────────────
cat("4. Cargando EPV 2025...\n")
epv <- read_xlsx(path_epv)
cat("   EPV 2025 filas:", nrow(epv), "cols:", ncol(epv), "\n")

# Identificar columnas GPS y percepción
gps_lat_col <- grep("gps.*lat|latitude|lat_gps", names(epv), ignore.case = TRUE, value = TRUE)
gps_lon_col <- grep("gps.*lon|longitude|lon_gps", names(epv), ignore.case = TRUE, value = TRUE)
cat("   Columnas GPS encontradas:", gps_lat_col, "|", gps_lon_col, "\n")

# P102_1: escala 1-5 (1=Muy inseguro, 5=Muy seguro)
perc_col <- "P102_1"
cat("   Variable percepción: P102_1 (escala 1-5)\n")

if (length(gps_lat_col) > 0 & length(gps_lon_col) > 0) {
  epv_clean <- epv |>
    mutate(
      lat = as.numeric(.data[[gps_lat_col[1]]]),
      lon = as.numeric(.data[[gps_lon_col[1]]])
    ) |>
    filter(!is.na(lat) & !is.na(lon) & lat > 4.4 & lat < 4.85 & lon > -74.25 & lon < -73.95)

  # Convertir percepción a numérico
  if (length(perc_col) > 0) {
    epv_clean$percepcion <- as.numeric(epv_clean[[perc_col[1]]])
    epv_clean <- epv_clean |> filter(!is.na(percepcion))
  }

  epv_sf <- st_as_sf(epv_clean, coords = c("lon", "lat"), crs = 4326)
  epv_sf <- st_transform(epv_sf, 3116)

  # Filtrar a buffer del metro
  epv_sf <- epv_sf[st_intersects(epv_sf, buffer_metro, sparse = FALSE)[, 1], ]
  cat("   EPV en buffer del metro:", nrow(epv_sf), "puntos\n")

  # Promediar percepción por hexágono
  if (length(perc_col) > 0) {
    joined_epv <- st_join(hex_grid["hex_id"], epv_sf["percepcion"], left = FALSE)
    perc_avg <- joined_epv |> st_drop_geometry() |>
      group_by(hex_id) |>
      summarise(percepcion = mean(percepcion, na.rm = TRUE), n_encuestas = n())

    hex_grid <- hex_grid |> left_join(perc_avg, by = "hex_id")
    cat("   Hexágonos con percepción:", sum(!is.na(hex_grid$percepcion)), "\n")
  }

  rm(epv_clean, epv_sf, joined_epv, perc_avg)
} else {
  cat("   ALERTA: No se encontraron columnas GPS en EPV 2025\n")
}
rm(epv)
gc(verbose = FALSE)

# ── 5. RESUMEN DE VARIABLES DISPONIBLES ──────────────────────────────────────
cat("\n5. Resumen de variables en la grilla hexagonal:\n")
cat("   Hexágonos totales:", nrow(hex_grid), "\n")
cat("   log_shoplifting — rango:", round(range(hex_grid$log_shoplifting), 2), "\n")
cat("   log_theft       — rango:", round(range(hex_grid$log_theft), 2), "\n")
cat("   log_extortion   — rango:", round(range(hex_grid$log_extortion), 2), "\n")
cat("   log_assault     — rango:", round(range(hex_grid$log_assault), 2), "\n")
cat("   dist_metro      — rango:", round(range(hex_grid$dist_metro)), "m\n")
if ("percepcion" %in% names(hex_grid)) {
  cat("   percepcion      — rango:", round(range(hex_grid$percepcion, na.rm = TRUE), 2),
      "| n =", sum(!is.na(hex_grid$percepcion)), "\n")
}

# ── 6. NORMALIZAR DIST_METRO ─────────────────────────────────────────────────
# Escalar a 0-1 para que sea comparable con log-counts
hex_grid$dist_metro_norm <- hex_grid$dist_metro / max(hex_grid$dist_metro)

# ── 7. VARIOGRAMAS Y CO-KRIGING ──────────────────────────────────────────────
cat("\n7. Calculando variogramas y co-kriging...\n")

# Usar centroides como puntos para gstat
hex_pts <- st_centroid(hex_grid)

# ── FUNCIÓN: probar una combinación de variables ──
test_cokriging <- function(hex_pts, var_names, var_labels, max_dist = 2500,
                           n_lags = 20, model_type = "Sph") {

  cat("\n── Probando combinación:", paste(var_labels, collapse = " + "), "──\n")

  # Filtrar hexágonos con datos completos para todas las variables
  data_complete <- hex_pts
  for (v in var_names) {
    data_complete <- data_complete[!is.na(data_complete[[v]]), ]
  }
  cat("   Puntos con datos completos:", nrow(data_complete), "\n")

  if (nrow(data_complete) < 30) {
    cat("   SKIP: insuficientes puntos\n")
    return(NULL)
  }

  # Crear objeto gstat
  g <- NULL
  for (i in seq_along(var_names)) {
    formula_i <- as.formula(paste(var_names[i], "~ 1"))
    if (is.null(g)) {
      g <- gstat(id = var_labels[i], formula = formula_i, data = data_complete)
    } else {
      g <- gstat(g, id = var_labels[i], formula = formula_i, data = data_complete)
    }
  }

  # Variograma experimental (auto + cruzados)
  v_exp <- variogram(g, cutoff = max_dist, width = max_dist / n_lags)

  # Estimar parámetros iniciales del variograma a partir de los datos
  # Usar varianza muestral como psill inicial, y 1/3 del cutoff como range
  avg_var <- mean(sapply(var_names, function(v) var(data_complete[[v]], na.rm = TRUE)))
  init_range <- max_dist * 0.4
  init_nugget <- avg_var * 0.1

  v_model <- vgm(psill = avg_var * 0.9, model = model_type,
                  range = init_range, nugget = init_nugget)

  # Ajustar modelo LMC con fit.ranges=TRUE para que ajuste el alcance
  v_fit <- tryCatch(
    fit.lmc(v_exp, g, model = v_model, correct.diagonal = 1.01,
            fit.ranges = TRUE),
    error = function(e) {
      cat("   Error ajustando LMC:", e$message, "\n")
      return(NULL)
    }
  )

  if (is.null(v_fit)) return(NULL)

  # Reportar parámetros del variograma
  cat("   Modelo ajustado:\n")
  for (lab in var_labels) {
    vm <- v_fit$model[[lab]]
    if (!is.null(vm)) {
      cat("     ", lab, "— nugget:", round(vm$psill[1], 3),
          "| sill:", round(sum(vm$psill), 3),
          "| range:", round(vm$range[2]), "m\n")
    }
  }

  return(list(
    gstat_obj = v_fit,
    variogram_exp = v_exp,
    data = data_complete,
    vars = var_names,
    labels = var_labels
  ))
}

# ── COMBINACIONES A PROBAR ──
cat("\n══ COMPARACIÓN DE COMBINACIONES ══\n")

results <- list()

# Combo 1: Solo delitos (3 tipos)
results[["crimes_3"]] <- test_cokriging(
  hex_pts,
  var_names  = c("log_shoplifting", "log_theft", "log_extortion"),
  var_labels = c("HurtoComercio", "HurtoPersonas", "Extorsion")
)

# Combo 2: Delitos + distancia al metro
results[["crimes_dist"]] <- test_cokriging(
  hex_pts,
  var_names  = c("log_shoplifting", "log_theft", "log_extortion", "dist_metro_norm"),
  var_labels = c("HurtoComercio", "HurtoPersonas", "Extorsion", "DistMetro")
)

# Combo 3: Delitos principales + assault
results[["crimes_4"]] <- test_cokriging(
  hex_pts,
  var_names  = c("log_shoplifting", "log_theft", "log_extortion", "log_assault"),
  var_labels = c("HurtoComercio", "HurtoPersonas", "Extorsion", "Lesiones")
)

# Combo 4: Si hay percepción, incluirla
if ("percepcion" %in% names(hex_pts) && sum(!is.na(hex_pts$percepcion)) >= 30) {

  results[["perc_crimes2"]] <- test_cokriging(
    hex_pts,
    var_names  = c("percepcion", "log_shoplifting", "log_extortion"),
    var_labels = c("Percepcion", "HurtoComercio", "Extorsion")
  )

  results[["perc_crimes_dist"]] <- test_cokriging(
    hex_pts,
    var_names  = c("percepcion", "log_shoplifting", "log_extortion", "dist_metro_norm"),
    var_labels = c("Percepcion", "HurtoComercio", "Extorsion", "DistMetro")
  )

  results[["perc_theft_dist"]] <- test_cokriging(
    hex_pts,
    var_names  = c("percepcion", "log_theft", "log_extortion", "dist_metro_norm"),
    var_labels = c("Percepcion", "HurtoPersonas", "Extorsion", "DistMetro")
  )
}

# ── RESUMEN FINAL ──
cat("\n\n══ RESUMEN DE MODELOS ══\n")
for (name in names(results)) {
  r <- results[[name]]
  if (!is.null(r)) {
    cat("\n", name, ":", paste(r$labels, collapse = " + "), "\n")
    for (lab in r$labels) {
      vm <- r$gstat_obj$model[[lab]]
      if (!is.null(vm)) {
        cat("   ", lab, "→ range:", round(vm$range[2]), "m | sill:",
            round(sum(vm$psill), 3), "\n")
      }
    }
  }
}

# ── 8. PLOTS DE VARIOGRAMAS ───────────────────────────────────────────────────
cat("\n8. Generando plots de variogramas...\n")

dir.create("output", showWarnings = FALSE)

for (name in names(results)) {
  r <- results[[name]]
  if (!is.null(r)) {
    fname <- paste0("output/variograma_", name, ".png")
    png(fname, width = 900, height = 700, res = 120)
    p <- plot(r$variogram_exp, model = r$gstat_obj$model,
              main = paste("Co-variogramas:", paste(r$labels, collapse = " + ")))
    print(p)
    dev.off()
    cat("   Guardado:", fname, "\n")
  }
}

# ── 9. GUARDAR RESULTADOS ────────────────────────────────────────────────────
cat("\n9. Guardando resultados...\n")
saveRDS(hex_grid, "data/hex_grid_metro.rds")
saveRDS(results, "data/cokriging_results.rds")
cat("   Guardados: data/hex_grid_metro.rds, data/cokriging_results.rds\n")
cat("\n═══ PIPELINE COMPLETADO ═══\n")
