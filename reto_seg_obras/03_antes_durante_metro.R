# ══════════════════════════════════════════════════════════════════════════════
# ANTES VS. DURANTE + ANISOTROPÍA + OPERATIVOS POLICIALES — Metro Línea 1
# Equipo CyberRosario — Datajam Seguridad CCB
# ══════════════════════════════════════════════════════════════════════════════

library(sf)
library(gstat)
library(dplyr)

cat("═══ ANTES VS. DURANTE + ANISOTROPÍA + OPERATIVOS POLICIALES ═══\n\n")

# ── RUTAS ─────────────────────────────────────────────────────────────────────
path_crime    <- "~/Documents/GitHub/Impact-evaluation-peace-process/datasets"
path_arrest   <- file.path(path_crime, "arrest")
path_stations <- "data/estaciones_metro_l1.geojson"

# ── 1. CARGAR HEX GRID Y RECONSTRUIR GEOMETRÍA DEL METRO ────────────────────
cat("1. Cargando hex_grid y reconstruyendo línea del Metro...\n")
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

# ── 2. CARGAR DELITOS ────────────────────────────────────────────────────────
cat("2. Cargando delitos...\n")

load_crime <- function(file, label) {
  df <- read.csv2(file, stringsAsFactors = FALSE)
  df$lat_var <- as.numeric(gsub(",", ".", df$lat_var))
  df$lon_var <- as.numeric(gsub(",", ".", df$lon_var))
  df <- df[!is.na(df$lat_var) & !is.na(df$lon_var), ]
  df <- df[df$lat_var > 4.4 & df$lat_var < 4.85 &
           df$lon_var > -74.25 & df$lon_var < -73.95, ]
  df$year <- as.integer(substr(df$date_var, 7, 10))
  pts <- st_as_sf(df, coords = c("lon_var", "lat_var"), crs = 4326)
  pts <- st_transform(pts, 3116)
  pts <- pts[st_intersects(pts, buffer_metro, sparse = FALSE)[, 1], ]
  cat("  ", label, "en buffer:", nrow(pts), "\n")
  pts$crime_type <- label
  return(pts)
}

shoplifting <- load_crime(file.path(path_crime, "larceny/shoplifting.csv"), "shoplifting")
theft       <- load_crime(file.path(path_crime, "larceny/theft.csv"), "theft")
extortion   <- load_crime(file.path(path_crime, "violent/extortion.csv"), "extortion")
assault     <- load_crime(file.path(path_crime, "violent/assault.csv"), "assault")

# ── 2b. CARGAR OPERATIVOS POLICIALES ──────────────────────────────────────────
cat("\n2b. Cargando operativos policiales (capturas, allanamientos, incautaciones)...\n")

arrests   <- load_crime(file.path(path_arrest, "arrests.csv"), "arrests")
raids     <- load_crime(file.path(path_arrest, "raids.csv"), "raids")
seizures  <- load_crime(file.path(path_arrest, "seizures.csv"), "seizures")

# ── 3. CONTAR DELITOS POR HEXÁGONO: ANTES (2018-2020) ───────────────────────
cat("3. Contando delitos ANTES (2018-2020)...\n")

count_in_hex <- function(pts, hex, col_name, year_min, year_max) {
  pts_filtered <- pts[pts$year >= year_min & pts$year <= year_max, ]
  joined <- st_join(hex["hex_id"], pts_filtered, left = TRUE)
  counts <- joined |> st_drop_geometry() |> count(hex_id, name = col_name)
  counts[[col_name]][is.na(counts[[col_name]])] <- 0
  return(counts)
}

# Periodo ANTES (2018-2020)
pre_shop <- count_in_hex(shoplifting, hex_grid, "shoplifting_pre", 2018, 2020)
pre_thft <- count_in_hex(theft, hex_grid, "theft_pre", 2018, 2020)
pre_ext  <- count_in_hex(extortion, hex_grid, "extortion_pre", 2018, 2020)
pre_aslt <- count_in_hex(assault, hex_grid, "assault_pre", 2018, 2020)

pre_arst <- count_in_hex(arrests, hex_grid, "arrests_pre", 2018, 2020)
pre_raid <- count_in_hex(raids, hex_grid, "raids_pre", 2018, 2020)
pre_seiz <- count_in_hex(seizures, hex_grid, "seizures_pre", 2018, 2020)

hex_grid <- hex_grid |>
  left_join(pre_shop, by = "hex_id") |>
  left_join(pre_thft, by = "hex_id") |>
  left_join(pre_ext, by = "hex_id") |>
  left_join(pre_aslt, by = "hex_id") |>
  left_join(pre_arst, by = "hex_id") |>
  left_join(pre_raid, by = "hex_id") |>
  left_join(pre_seiz, by = "hex_id")

# Reemplazar NA con 0
for (col in c("shoplifting_pre", "theft_pre", "extortion_pre", "assault_pre",
              "arrests_pre", "raids_pre", "seizures_pre")) {
  hex_grid[[col]][is.na(hex_grid[[col]])] <- 0
}

cat("   Conteos ANTES asignados (delitos + operativos)\n")

# ── 3b. CONTAR OPERATIVOS DURANTE (2021-2023) ────────────────────────────────
cat("3b. Contando operativos DURANTE (2021-2023)...\n")

dur_arst <- count_in_hex(arrests, hex_grid, "arrests", 2021, 2023)
dur_raid <- count_in_hex(raids, hex_grid, "raids", 2021, 2023)
dur_seiz <- count_in_hex(seizures, hex_grid, "seizures", 2021, 2023)

hex_grid <- hex_grid |>
  left_join(dur_arst, by = "hex_id") |>
  left_join(dur_raid, by = "hex_id") |>
  left_join(dur_seiz, by = "hex_id")

for (col in c("arrests", "raids", "seizures")) {
  hex_grid[[col]][is.na(hex_grid[[col]])] <- 0
}

# Variables log para operativos
hex_grid$log_arrests  <- log(hex_grid$arrests + 1)
hex_grid$log_raids    <- log(hex_grid$raids + 1)
hex_grid$log_seizures <- log(hex_grid$seizures + 1)

cat("   Capturas (durante):", sum(hex_grid$arrests), "\n")
cat("   Allanamientos (durante):", sum(hex_grid$raids), "\n")
cat("   Incautaciones (durante):", sum(hex_grid$seizures), "\n")

# ── 4. MÉTRICAS DE CAMBIO ───────────────────────────────────────────────────
cat("\n4. Calculando métricas de cambio...\n")

# Delitos: los conteos DURANTE ya están en hex_grid (shoplifting, theft, extortion, assault)
hex_grid$cambio_shoplifting <- log(hex_grid$shoplifting + 1) - log(hex_grid$shoplifting_pre + 1)
hex_grid$cambio_theft       <- log(hex_grid$theft + 1) - log(hex_grid$theft_pre + 1)
hex_grid$cambio_extortion   <- log(hex_grid$extortion + 1) - log(hex_grid$extortion_pre + 1)
hex_grid$cambio_assault     <- log(hex_grid$assault + 1) - log(hex_grid$assault_pre + 1)

# Operativos policiales: cambio antes/durante
hex_grid$cambio_arrests  <- log(hex_grid$arrests + 1) - log(hex_grid$arrests_pre + 1)
hex_grid$cambio_raids    <- log(hex_grid$raids + 1) - log(hex_grid$raids_pre + 1)
hex_grid$cambio_seizures <- log(hex_grid$seizures + 1) - log(hex_grid$seizures_pre + 1)

# Total antes y durante (delitos)
hex_grid$total_pre    <- hex_grid$shoplifting_pre + hex_grid$theft_pre +
                         hex_grid$extortion_pre + hex_grid$assault_pre
hex_grid$total_during <- hex_grid$shoplifting + hex_grid$theft +
                         hex_grid$extortion + hex_grid$assault
hex_grid$cambio_total <- (hex_grid$total_during - hex_grid$total_pre) /
                         (hex_grid$total_pre + 1)

# Total operativos antes y durante
hex_grid$total_ops_pre    <- hex_grid$arrests_pre + hex_grid$raids_pre + hex_grid$seizures_pre
hex_grid$total_ops_during <- hex_grid$arrests + hex_grid$raids + hex_grid$seizures
hex_grid$cambio_ops_total <- (hex_grid$total_ops_during - hex_grid$total_ops_pre) /
                             (hex_grid$total_ops_pre + 1)

cat("   --- Cambio en delitos ---\n")
cat("   Cambio promedio total:", round(mean(hex_grid$cambio_total), 3), "\n")
cat("   Cambio shoplifting (log-ratio):", round(mean(hex_grid$cambio_shoplifting), 3), "\n")
cat("   Cambio theft (log-ratio):", round(mean(hex_grid$cambio_theft), 3), "\n")
cat("   Cambio extortion (log-ratio):", round(mean(hex_grid$cambio_extortion), 3), "\n")
cat("   Cambio assault (log-ratio):", round(mean(hex_grid$cambio_assault), 3), "\n")
cat("   --- Cambio en operativos policiales ---\n")
cat("   Cambio capturas (log-ratio):", round(mean(hex_grid$cambio_arrests), 3), "\n")
cat("   Cambio allanamientos (log-ratio):", round(mean(hex_grid$cambio_raids), 3), "\n")
cat("   Cambio incautaciones (log-ratio):", round(mean(hex_grid$cambio_seizures), 3), "\n")
cat("   Cambio total operativos:", round(mean(hex_grid$cambio_ops_total), 3), "\n")

# ── 5. VARIOGRAMAS ANTES VS. DURANTE ────────────────────────────────────────
cat("\n5. Variogramas antes vs. durante...\n")

hex_pts <- st_centroid(hex_grid)
hex_pts$log_shoplifting_pre <- log(hex_pts$shoplifting_pre + 1)
hex_pts$log_theft_pre       <- log(hex_pts$theft_pre + 1)

# Variograma ANTES: hurto personas (el más frecuente)
v_antes <- variogram(log_theft_pre ~ 1, data = hex_pts, cutoff = 2500, width = 125)
m_antes <- tryCatch(
  fit.variogram(v_antes, vgm(psill = 0.5, model = "Sph", range = 800, nugget = 0.1)),
  warning = function(w) {
    cat("   AVISO variograma ANTES:", w$message, "\n")
    fit.variogram(v_antes, vgm(psill = 0.5, model = "Sph", range = 800, nugget = 0.1))
  }
)

# Variograma DURANTE (ya existe log_theft en hex_pts)
v_durante <- variogram(log_theft ~ 1, data = hex_pts, cutoff = 2500, width = 125)
m_durante <- fit.variogram(v_durante, vgm(psill = 0.5, model = "Sph", range = 800, nugget = 0.1))

cat("   Hurto personas ANTES  — range:", round(m_antes$range[2]), "m | sill:", round(sum(m_antes$psill), 3), "\n")
cat("   Hurto personas DURANTE — range:", round(m_durante$range[2]), "m | sill:", round(sum(m_durante$psill), 3), "\n")

# Variograma del CAMBIO
v_cambio <- variogram(cambio_theft ~ 1, data = hex_pts, cutoff = 2500, width = 125)
m_cambio <- tryCatch(
  fit.variogram(v_cambio, vgm(psill = 0.3, model = "Sph", range = 800, nugget = 0.05)),
  warning = function(w) {
    fit.variogram(v_cambio, vgm(psill = 0.3, model = "Sph", range = 800, nugget = 0.05))
  }
)

cat("   Cambio hurto personas — range:", round(m_cambio$range[2]), "m | sill:", round(sum(m_cambio$psill), 3), "\n")

# Plot comparativo antes vs durante
dir.create("output", showWarnings = FALSE)

tryCatch({
  png("output/variograma_antes_durante.png", width = 1200, height = 500, res = 120)
  par(mfrow = c(1, 3))

  # Solo plotear si el variograma tiene varianza > 0
  if (sum(m_antes$psill) > 0.001) {
    plot(v_antes, model = m_antes, main = "Hurto Personas ANTES (2018-2020)",
         xlab = "Distancia (m)", ylab = "Semivarianza")
  } else {
    plot(v_antes, main = "Hurto Personas ANTES (2018-2020)\n(sill ≈ 0, sin estructura espacial)",
         xlab = "Distancia (m)", ylab = "Semivarianza")
  }

  plot(v_durante, model = m_durante, main = "Hurto Personas DURANTE (2021-2023)",
       xlab = "Distancia (m)", ylab = "Semivarianza")

  if (sum(m_cambio$psill) > 0.001) {
    plot(v_cambio, model = m_cambio, main = "CAMBIO (log-ratio)",
         xlab = "Distancia (m)", ylab = "Semivarianza")
  } else {
    plot(v_cambio, main = "CAMBIO (log-ratio)\n(sill ≈ 0)",
         xlab = "Distancia (m)", ylab = "Semivarianza")
  }

  par(mfrow = c(1, 1))
  dev.off()
  cat("   Guardado: output/variograma_antes_durante.png\n")
}, error = function(e) {
  try(dev.off(), silent = TRUE)
  cat("   Error en plot variograma antes/durante:", e$message, "\n")
})

# ── 6. ANISOTROPÍA ──────────────────────────────────────────────────────────
cat("\n6. Análisis de anisotropía...\n")

# Determinar orientación del Metro L1
# Estación 1 (SW) → Estación 16 (NE)
p1 <- coords_3116[1, 1:2]   # primera estación
p16 <- coords_3116[nrow(coords_3116), 1:2]  # última estación
dx <- p16[1] - p1[1]
dy <- p16[2] - p1[2]
angulo_metro <- atan2(dx, dy) * 180 / pi  # ángulo desde norte (gstat convención)
if (angulo_metro < 0) angulo_metro <- angulo_metro + 180
cat("   Ángulo del Metro L1 (desde N, sentido horario):", round(angulo_metro, 1), "°\n")

# Variogramas direccionales para hurto personas (durante)
# 4 direcciones: paralelo al metro, perpendicular, y 2 diagonales
angulos <- c(angulo_metro, angulo_metro + 45, angulo_metro + 90, angulo_metro + 135)
angulos <- angulos %% 180  # mantener en [0, 180)

v_dir <- variogram(log_theft ~ 1, data = hex_pts,
                    alpha = angulos, tol.hor = 22.5,
                    cutoff = 2500, width = 125)

# Ajustar modelo a cada dirección
cat("   Variogramas direccionales:\n")
dir_labels <- c("Paralelo", "Diagonal 1", "Perpendicular", "Diagonal 2")
dir_results <- list()
for (i in seq_along(angulos)) {
  v_i <- v_dir[v_dir$dir.hor == i, ]
  if (nrow(v_i) > 3) {
    m_i <- tryCatch(
      fit.variogram(v_i, vgm(psill = 0.5, model = "Sph", range = 800, nugget = 0.1)),
      error = function(e) NULL
    )
    if (!is.null(m_i)) {
      cat("     ", dir_labels[i], "(", round(angulos[i], 1), "°) — range:",
          round(m_i$range[2]), "m | sill:", round(sum(m_i$psill), 3), "\n")
      dir_results[[dir_labels[i]]] <- m_i
    }
  }
}

# Plot de anisotropía
tryCatch({
  png("output/variograma_anisotropia.png", width = 900, height = 700, res = 120)
  plot(v_dir, main = "Variogramas direccionales — Hurto Personas (2021-2023)",
       xlab = "Distancia (m)", ylab = "Semivarianza",
       sub = sprintf("Ángulo Metro: %.0f° | Paralelo vs. Perpendicular", angulo_metro))
  dev.off()
  cat("   Guardado: output/variograma_anisotropia.png\n")
}, error = function(e) {
  try(dev.off(), silent = TRUE)
  cat("   Error en plot anisotropía:", e$message, "\n")
})

# Anisotropía para cambio (antes/durante)
v_dir_cambio <- variogram(cambio_theft ~ 1, data = hex_pts,
                           alpha = angulos, tol.hor = 22.5,
                           cutoff = 2500, width = 125)

tryCatch({
  png("output/variograma_anisotropia_cambio.png", width = 900, height = 700, res = 120)
  plot(v_dir_cambio, main = "Variogramas direccionales — CAMBIO Hurto Personas",
       xlab = "Distancia (m)", ylab = "Semivarianza",
       sub = sprintf("Ángulo Metro: %.0f° | Paralelo vs. Perpendicular", angulo_metro))
  dev.off()
  cat("   Guardado: output/variograma_anisotropia_cambio.png\n")
}, error = function(e) {
  try(dev.off(), silent = TRUE)
  cat("   Error en plot anisotropía cambio:", e$message, "\n")
})

# ── 7. GUARDAR ──────────────────────────────────────────────────────────────
cat("\n7. Guardando hex_grid actualizado...\n")
saveRDS(hex_grid, "data/hex_grid_metro.rds")
cat("   Nuevas columnas delitos: shoplifting_pre, theft_pre, extortion_pre, assault_pre\n")
cat("   Nuevas columnas cambio: cambio_shoplifting, cambio_theft, cambio_extortion, cambio_assault\n")
cat("   Nuevas columnas totales: total_pre, total_during, cambio_total\n")
cat("   Nuevas columnas operativos: arrests, raids, seizures (durante)\n")
cat("   Nuevas columnas operativos: arrests_pre, raids_pre, seizures_pre (antes)\n")
cat("   Nuevas columnas operativos: log_arrests, log_raids, log_seizures\n")
cat("   Nuevas columnas operativos: cambio_arrests, cambio_raids, cambio_seizures\n")
cat("   Nuevas columnas operativos: total_ops_pre, total_ops_during, cambio_ops_total\n")

# Liberar memoria
rm(shoplifting, theft, extortion, assault, arrests, raids, seizures)
rm(pre_shop, pre_thft, pre_ext, pre_aslt, pre_arst, pre_raid, pre_seiz)
rm(dur_arst, dur_raid, dur_seiz)
gc(verbose = FALSE)

cat("\n═══ ANTES/DURANTE + ANISOTROPÍA + OPERATIVOS COMPLETADO ═══\n")
