# ══════════════════════════════════════════════════════════════════════════════
# INTEGRACIÓN FINAL: REGRESIÓN ESPACIAL + MAPA — Metro Línea 1
# Equipo CyberRosario — Datajam Seguridad CCB
# ══════════════════════════════════════════════════════════════════════════════

library(sf)
library(spdep)
library(dplyr)
library(terra)
library(raster)
library(leaflet)
library(htmlwidgets)

cat("═══ INTEGRACIÓN FINAL ═══\n\n")

# ── 1. CARGAR DATOS ─────────────────────────────────────────────────────────
cat("1. Cargando hex_grid con todas las capas...\n")
hex_grid <- readRDS("data/hex_grid_metro.rds")
cat("   Hexágonos:", nrow(hex_grid), "\n")
cat("   Columnas:", ncol(hex_grid), "\n")
cat("   Variables disponibles:\n")
cat("   ", paste(names(hex_grid), collapse = ", "), "\n\n")

# Estaciones
est <- st_read("data/estaciones_metro_l1.geojson", quiet = TRUE)
st_crs(est) <- 6247
est_wgs <- st_transform(est, 4326)
coords_est <- st_coordinates(st_centroid(est_wgs))
orden <- order(as.integer(est$NUMERO))

# Reconstruir línea del metro en WGS84
metro_line_wgs <- st_sfc(st_linestring(coords_est[orden, 1:2]), crs = 4326)

# ── 2. PREPARAR DATOS PARA REGRESIÓN ────────────────────────────────────────
cat("2. Preparando datos para regresión espacial...\n")

# Variable dependiente: percepción (solo hexágonos con datos)
# Si hay pred_percepcion (co-kriging), usarla para todos los hexágonos
# Si no, usar solo los hexágonos con percepción directa

if ("pred_percepcion" %in% names(hex_grid) &&
    sum(!is.na(hex_grid$pred_percepcion)) > 50) {
  hex_grid$y_perc <- hex_grid$pred_percepcion
  cat("   Usando pred_percepcion (co-kriging) como variable dependiente\n")
} else if ("percepcion" %in% names(hex_grid) &&
           sum(!is.na(hex_grid$percepcion)) > 30) {
  hex_grid$y_perc <- hex_grid$percepcion
  cat("   Usando percepcion (directa) como variable dependiente\n")
} else {
  cat("   ALERTA: No hay suficientes datos de percepción para regresión\n")
  cat("   Se usará log_theft como variable dependiente alternativa\n")
  hex_grid$y_perc <- hex_grid$log_theft
}

# Predictores: seleccionar los disponibles
predictores <- c()
pred_labels <- c()

# Distancia al metro (siempre disponible)
if ("dist_metro" %in% names(hex_grid)) {
  hex_grid$dist_metro_km <- hex_grid$dist_metro / 1000
  predictores <- c(predictores, "dist_metro_km")
  pred_labels <- c(pred_labels, "Distancia al Metro (km)")
}

# Cambio en delitos (de 03_antes_durante_metro.R)
if ("cambio_total" %in% names(hex_grid)) {
  predictores <- c(predictores, "cambio_total")
  pred_labels <- c(pred_labels, "Cambio total delitos (antes/durante)")
}
if ("cambio_theft" %in% names(hex_grid)) {
  predictores <- c(predictores, "cambio_theft")
  pred_labels <- c(pred_labels, "Cambio hurto personas (log-ratio)")
}

# Delitos actuales
if ("log_theft" %in% names(hex_grid)) {
  predictores <- c(predictores, "log_theft")
  pred_labels <- c(pred_labels, "Hurto personas (log, 2021-2023)")
}
if ("log_shoplifting" %in% names(hex_grid)) {
  predictores <- c(predictores, "log_shoplifting")
  pred_labels <- c(pred_labels, "Hurto comercio (log, 2021-2023)")
}

# Empresas (de 04_empresas_metro.R)
if ("densidad_empresas" %in% names(hex_grid)) {
  predictores <- c(predictores, "densidad_empresas")
  pred_labels <- c(pred_labels, "Densidad empresarial")
}
if ("pct_mipyme" %in% names(hex_grid)) {
  predictores <- c(predictores, "pct_mipyme")
  pred_labels <- c(pred_labels, "% MiPymes")
}

# Entorno (de 05_entorno_metro.R)
if ("pct_verde" %in% names(hex_grid)) {
  predictores <- c(predictores, "pct_verde")
  pred_labels <- c(pred_labels, "% Área verde")
}
if ("n_edificios" %in% names(hex_grid)) {
  predictores <- c(predictores, "n_edificios")
  pred_labels <- c(pred_labels, "N edificios")
}
if ("longitud_vias_m" %in% names(hex_grid)) {
  predictores <- c(predictores, "longitud_vias_m")
  pred_labels <- c(pred_labels, "Longitud vías (m)")
}
if ("uso_comercial" %in% names(hex_grid)) {
  predictores <- c(predictores, "uso_comercial")
  pred_labels <- c(pred_labels, "Uso comercial (0/1)")
}

cat("   Predictores disponibles (", length(predictores), "):\n")
for (i in seq_along(predictores)) {
  cat("     ", predictores[i], "—", pred_labels[i], "\n")
}

# Filtrar hexágonos con datos completos
cols_modelo <- c("y_perc", predictores)
hex_complete <- hex_grid[complete.cases(st_drop_geometry(hex_grid[, cols_modelo])), ]
cat("   Hexágonos con datos completos:", nrow(hex_complete), "/", nrow(hex_grid), "\n")

# ── 3. MODELO OLS (BASELINE) ────────────────────────────────────────────────
cat("\n3. Ajustando modelo OLS (baseline)...\n")

formula_str <- paste("y_perc ~", paste(predictores, collapse = " + "))
formula_reg <- as.formula(formula_str)
cat("   Fórmula:", formula_str, "\n")

ols <- lm(formula_reg, data = hex_complete)
cat("   R² ajustado:", round(summary(ols)$adj.r.squared, 4), "\n")
cat("   AIC:", round(AIC(ols), 2), "\n\n")

# Coeficientes significativos
coef_summary <- summary(ols)$coefficients
cat("   Coeficientes:\n")
for (i in seq_len(nrow(coef_summary))) {
  sig <- ""
  pval <- coef_summary[i, 4]
  if (pval < 0.001) sig <- "***"
  else if (pval < 0.01) sig <- "**"
  else if (pval < 0.05) sig <- "*"
  else if (pval < 0.1) sig <- "."
  cat("     ", rownames(coef_summary)[i], ":",
      round(coef_summary[i, 1], 4), "(p=", round(pval, 4), ")", sig, "\n")
}

# ── 4. TEST DE MORAN I (AUTOCORRELACIÓN ESPACIAL) ───────────────────────────
cat("\n4. Test de Moran I sobre residuos OLS...\n")

# Construir vecindad espacial (Queen contiguity)
hex_complete_valid <- st_make_valid(hex_complete)
nb <- poly2nb(hex_complete_valid, queen = TRUE)

# Verificar que no haya observaciones sin vecinos
no_neighbors <- which(card(nb) == 0)
if (length(no_neighbors) > 0) {
  cat("   Eliminando", length(no_neighbors), "hexágonos sin vecinos...\n")
  hex_complete_valid <- hex_complete_valid[-no_neighbors, ]
  nb <- poly2nb(hex_complete_valid, queen = TRUE)
  # Re-ajustar OLS
  ols <- lm(formula_reg, data = hex_complete_valid)
}

lw <- nb2listw(nb, style = "W")
moran_test <- moran.test(residuals(ols), lw)
cat("   Moran I:", round(moran_test$estimate[1], 4), "\n")
cat("   p-value:", format.pval(moran_test$p.value), "\n")

if (moran_test$p.value < 0.05) {
  cat("   → HAY autocorrelación espacial significativa en residuos\n")
  cat("   → Se ajustará modelo espacial (SAR o SEM)\n")
} else {
  cat("   → No hay autocorrelación espacial significativa\n")
  cat("   → OLS es suficiente\n")
}

# ── 5. MODELOS ESPACIALES (SI HAY AUTOCORRELACIÓN) ──────────────────────────
cat("\n5. Ajustando modelos espaciales...\n")

# SAR (Spatial Lag Model)
sar <- tryCatch({
  lagsarlm(formula_reg, data = hex_complete_valid, listw = lw)
}, error = function(e) {
  cat("   Error SAR:", e$message, "\n")
  NULL
})

# SEM (Spatial Error Model)
sem <- tryCatch({
  errorsarlm(formula_reg, data = hex_complete_valid, listw = lw)
}, error = function(e) {
  cat("   Error SEM:", e$message, "\n")
  NULL
})

# Comparar modelos
cat("\n   Comparación de modelos:\n")
cat("     OLS — AIC:", round(AIC(ols), 2),
    "| R²:", round(summary(ols)$adj.r.squared, 4), "\n")

if (!is.null(sar)) {
  cat("     SAR — AIC:", round(AIC(sar), 2),
      "| rho:", round(sar$rho, 4), "\n")
}
if (!is.null(sem)) {
  cat("     SEM — AIC:", round(AIC(sem), 2),
      "| lambda:", round(sem$lambda, 4), "\n")
}

# Elegir mejor modelo
models <- list(OLS = AIC(ols))
if (!is.null(sar)) models$SAR <- AIC(sar)
if (!is.null(sem)) models$SEM <- AIC(sem)
best_model <- names(which.min(unlist(models)))
cat("   → Mejor modelo:", best_model, "(menor AIC)\n")

# ── 6. RESUMEN DE HALLAZGOS POR HIPÓTESIS ───────────────────────────────────
cat("\n6. Resumen de hallazgos por hipótesis...\n")

dir.create("output", showWarnings = FALSE)
sink("output/modelo_regresion.txt")

cat("══════════════════════════════════════════════════════════\n")
cat("MODELO DE INTEGRACIÓN — METRO LÍNEA 1\n")
cat("Equipo CyberRosario — Datajam Seguridad CCB\n")
cat("══════════════════════════════════════════════════════════\n\n")

cat("Fórmula:", formula_str, "\n")
cat("N hexágonos:", nrow(hex_complete_valid), "\n\n")

cat("── MODELO OLS ──\n")
print(summary(ols))

cat("\n── MORAN I (residuos OLS) ──\n")
cat("Moran I:", round(moran_test$estimate[1], 4), "\n")
cat("p-value:", format.pval(moran_test$p.value), "\n\n")

if (!is.null(sar)) {
  cat("── MODELO SAR (Spatial Lag) ──\n")
  print(summary(sar))
}
if (!is.null(sem)) {
  cat("\n── MODELO SEM (Spatial Error) ──\n")
  print(summary(sem))
}

cat("\n── COMPARACIÓN AIC ──\n")
for (nm in names(models)) {
  cat(nm, ":", round(models[[nm]], 2), ifelse(nm == best_model, " ← MEJOR", ""), "\n")
}

cat("\n── HALLAZGOS POR HIPÓTESIS ──\n")
cat("H1 (distancia → delitos): verificar coeficiente de dist_metro_km\n")
cat("H2 (percepción peor cerca): verificar signo de dist_metro_km en modelo\n")
cat("H3 (anisotropía): ver output de 03_antes_durante_metro.R\n")
cat("H4 (cambio antes/durante): verificar coeficiente de cambio_total/cambio_theft\n")
cat("H5 (MiPymes vulnerables): verificar coeficiente de pct_mipyme\n")
cat("H6 (entorno deteriorado): verificar coeficientes de pct_verde, n_edificios\n")

sink()
cat("   Guardado: output/modelo_regresion.txt\n")

# Plot de coeficientes
coefs <- coef_summary[-1, ]  # sin intercepto
if (nrow(coefs) > 0) {
  png("output/coeficientes_modelo.png", width = 900, height = 500, res = 120)
  par(mar = c(5, 12, 3, 2))
  cols_bar <- ifelse(coefs[, 4] < 0.05, "#2196F3", "#BDBDBD")
  bp <- barplot(rev(coefs[, 1]), names.arg = rev(rownames(coefs)),
                horiz = TRUE, las = 1, col = rev(cols_bar), cex.names = 0.8,
                main = "Coeficientes OLS — Modelo Integrado",
                xlab = "Coeficiente (azul = p < 0.05)")
  abline(v = 0, lty = 2, col = "gray40")
  par(mar = c(5, 4, 4, 2))
  dev.off()
  cat("   Guardado: output/coeficientes_modelo.png\n")
}

# ── 7. MAPA LEAFLET INTEGRADO (SUPERFICIES SUAVIZADAS) ──────────────────────
cat("\n7. Generando mapa integrado con superficies suavizadas...\n")

hex_wgs <- st_transform(hex_grid, 4326)
metro_line_wgs <- st_sfc(st_linestring(coords_est[orden, 1:2]), crs = 4326)

# Función: rasterizar variable del hex_grid a superficie suavizada
hex_to_raster <- function(hex_sf, var_name, res = 50, crs_code = 3116) {
  vals <- hex_sf[[var_name]]
  if (all(is.na(vals))) return(NULL)
  centroids <- st_centroid(hex_sf)
  coords <- st_coordinates(centroids)
  df <- data.frame(x = coords[, 1], y = coords[, 2], z = vals)
  df <- df[!is.na(df$z), ]
  if (nrow(df) < 10) return(NULL)
  v <- vect(df, geom = c("x", "y"), crs = paste0("EPSG:", crs_code))
  ext_buf <- ext(v) + res
  r <- rast(ext_buf, res = res, crs = paste0("EPSG:", crs_code))
  r <- rasterize(v, r, field = "z", fun = "mean")
  r_wgs <- project(r, "EPSG:4326", method = "bilinear")
  raster(r_wgs)
}

# Popups para hexágonos de referencia
popups <- sprintf(
  "<b>Hex #%d</b> | Dist metro: %d m<hr/>
  <b>Delitos (2021-2023):</b><br/>
  Hurto comercio: %s | Hurto personas: %s<br/>
  Extorsión: %s | Lesiones: %s<br/>
  <b>Cambio (antes/durante):</b> %s<br/>
  <b>Percepción:</b> %s<br/>
  <b>Empresas:</b> %s | MiPyme: %s<br/>
  <b>Entorno:</b> Verde: %s%% | Edificios: %s | Vías: %s m",
  hex_wgs$hex_id, round(hex_wgs$dist_metro),
  ifelse("shoplifting" %in% names(hex_wgs), hex_wgs$shoplifting, "N/A"),
  ifelse("theft" %in% names(hex_wgs), hex_wgs$theft, "N/A"),
  ifelse("extortion" %in% names(hex_wgs), hex_wgs$extortion, "N/A"),
  ifelse("assault" %in% names(hex_wgs), hex_wgs$assault, "N/A"),
  ifelse("cambio_total" %in% names(hex_wgs),
         sprintf("%+.1f%%", hex_wgs$cambio_total * 100), "N/A"),
  ifelse("pred_percepcion" %in% names(hex_wgs) & !is.na(hex_wgs$pred_percepcion),
         sprintf("%.2f", hex_wgs$pred_percepcion), "N/A"),
  ifelse("n_empresas_2024" %in% names(hex_wgs) & !is.na(hex_wgs$n_empresas_2024),
         as.character(hex_wgs$n_empresas_2024), "N/A"),
  ifelse("pct_mipyme" %in% names(hex_wgs) & !is.na(hex_wgs$pct_mipyme),
         sprintf("%.0f%%", hex_wgs$pct_mipyme * 100), "N/A"),
  ifelse("pct_verde" %in% names(hex_wgs),
         sprintf("%.1f", hex_wgs$pct_verde * 100), "N/A"),
  ifelse("n_edificios" %in% names(hex_wgs), hex_wgs$n_edificios, "N/A"),
  ifelse("longitud_vias_m" %in% names(hex_wgs),
         round(hex_wgs$longitud_vias_m), "N/A")
)

m <- leaflet() |>
  addProviderTiles(providers$CartoDB.Positron)

# --- Superficies suavizadas: co-kriging (desde grid_fine si existe) ---
grid_fine_path <- "data/grid_fine_metro.rds"
has_grid_fine <- file.exists(grid_fine_path)

if (has_grid_fine) {
  cat("   Usando grilla fina pre-calculada para kriging...\n")
  grid_fine <- readRDS(grid_fine_path)
  coords_fine <- st_coordinates(grid_fine)

  pts_to_rl <- function(coords, values, res = 50) {
    df <- data.frame(x = coords[, 1], y = coords[, 2], z = values)
    df <- df[!is.na(df$z), ]
    v <- vect(df, geom = c("x", "y"), crs = "EPSG:3116")
    r <- rast(ext(v) + res, res = res, crs = "EPSG:3116")
    r <- rasterize(v, r, field = "z", fun = "mean")
    raster(project(r, "EPSG:4326", method = "bilinear"))
  }

  if ("pred_shoplifting" %in% names(grid_fine)) {
    rl <- pts_to_rl(coords_fine, grid_fine$pred_shoplifting)
    pal <- colorNumeric("YlOrRd", values(rl), na.color = "transparent")
    m <- m |> addRasterImage(rl, colors = pal, opacity = 0.75,
      group = "Hurto Comercio (kriging)")
  }
  if ("pred_theft" %in% names(grid_fine)) {
    rl <- pts_to_rl(coords_fine, grid_fine$pred_theft)
    pal <- colorNumeric("YlOrRd", values(rl), na.color = "transparent")
    m <- m |> addRasterImage(rl, colors = pal, opacity = 0.75,
      group = "Hurto Personas (kriging)")
  }
  if ("pred_percepcion" %in% names(grid_fine)) {
    rl <- pts_to_rl(coords_fine, grid_fine$pred_percepcion)
    pal <- colorNumeric("RdYlGn", values(rl), na.color = "transparent")
    m <- m |> addRasterImage(rl, colors = pal, opacity = 0.75,
      group = "Percepción (kriging)")
  }
} else {
  cat("   Sin grilla fina — rasterizando desde hex_grid...\n")
  if ("pred_shoplifting" %in% names(hex_grid)) {
    rl <- hex_to_raster(hex_grid, "pred_shoplifting")
    if (!is.null(rl)) {
      pal <- colorNumeric("YlOrRd", values(rl), na.color = "transparent")
      m <- m |> addRasterImage(rl, colors = pal, opacity = 0.75,
        group = "Hurto Comercio (kriging)")
    }
  }
  if ("pred_theft" %in% names(hex_grid)) {
    rl <- hex_to_raster(hex_grid, "pred_theft")
    if (!is.null(rl)) {
      pal <- colorNumeric("YlOrRd", values(rl), na.color = "transparent")
      m <- m |> addRasterImage(rl, colors = pal, opacity = 0.75,
        group = "Hurto Personas (kriging)")
    }
  }
  if ("pred_percepcion" %in% names(hex_grid)) {
    rl <- hex_to_raster(hex_grid, "pred_percepcion")
    if (!is.null(rl)) {
      pal <- colorNumeric("RdYlGn", values(rl), na.color = "transparent")
      m <- m |> addRasterImage(rl, colors = pal, opacity = 0.75,
        group = "Percepción (kriging)")
    }
  }
}

# --- Superficies suavizadas: capas nuevas (rasterizadas desde hex_grid) ---
if ("cambio_total" %in% names(hex_grid)) {
  rl <- hex_to_raster(hex_grid, "cambio_total")
  if (!is.null(rl)) {
    pal <- colorNumeric("RdBu", values(rl), na.color = "transparent", reverse = TRUE)
    m <- m |> addRasterImage(rl, colors = pal, opacity = 0.75,
      group = "Cambio Delitos (antes/durante)")
  }
}

if ("densidad_empresas" %in% names(hex_grid)) {
  rl <- hex_to_raster(hex_grid, "densidad_empresas")
  if (!is.null(rl)) {
    pal <- colorNumeric("YlGnBu", values(rl), na.color = "transparent")
    m <- m |> addRasterImage(rl, colors = pal, opacity = 0.75,
      group = "Densidad Empresarial")
  }
}

if ("pct_verde" %in% names(hex_grid)) {
  rl <- hex_to_raster(hex_grid, "pct_verde")
  if (!is.null(rl)) {
    pal <- colorNumeric("Greens", values(rl), na.color = "transparent")
    m <- m |> addRasterImage(rl, colors = pal, opacity = 0.75,
      group = "Cobertura Verde")
  }
}

if ("n_edificios" %in% names(hex_grid)) {
  rl <- hex_to_raster(hex_grid, "n_edificios")
  if (!is.null(rl)) {
    pal <- colorNumeric("Oranges", values(rl), na.color = "transparent")
    m <- m |> addRasterImage(rl, colors = pal, opacity = 0.75,
      group = "Densidad Edificios")
  }
}

# --- Hexágonos de referencia (solo bordes, para consulta con popup) ---
m <- m |>
  addPolygons(data = hex_wgs,
    fillColor = "transparent", fillOpacity = 0,
    weight = 0.8, opacity = 0.5, color = "#666",
    popup = popups,
    group = "Grilla hexagonal (ref)")

# --- Infraestructura: Metro ---
m <- m |>
  addPolylines(data = metro_line_wgs,
    color = "#1565C0", weight = 4, opacity = 0.9, group = "Metro L1") |>
  addCircleMarkers(lng = coords_est[, 1], lat = coords_est[, 2],
    radius = 6, color = "#D32F2F", fillColor = "#F44336",
    fillOpacity = 0.9, weight = 2,
    label = paste0(est$NOMBRE, " (#", est$NUMERO, ")"),
    group = "Estaciones")

# --- Control de capas ---
all_groups <- c("Hurto Comercio (kriging)", "Hurto Personas (kriging)",
                "Percepción (kriging)", "Cambio Delitos (antes/durante)",
                "Densidad Empresarial", "Cobertura Verde", "Densidad Edificios",
                "Grilla hexagonal (ref)", "Metro L1", "Estaciones")

hide_groups <- all_groups[!all_groups %in% c("Hurto Comercio (kriging)",
                                              "Metro L1", "Estaciones")]

m <- m |>
  addLayersControl(overlayGroups = all_groups,
    options = layersControlOptions(collapsed = FALSE))

for (g in hide_groups) {
  m <- m |> hideGroup(g)
}

# Leyenda
if ("pred_shoplifting" %in% names(hex_grid)) {
  rl_legend <- hex_to_raster(hex_grid, "pred_shoplifting")
  if (!is.null(rl_legend)) {
    pal_legend <- colorNumeric("YlOrRd", values(rl_legend), na.color = "transparent")
    m <- m |> addLegend(pal = pal_legend, values = values(rl_legend),
      title = "Hurto comercio<br/>(log co-kriging)", position = "bottomright")
  }
}

saveWidget(m, "mapa_integrado_metro.html", selfcontained = FALSE)
cat("   Guardado: mapa_integrado_metro.html\n")

# ── 8. GUARDAR DATOS FINALES ────────────────────────────────────────────────
cat("\n8. Guardando datos finales...\n")
saveRDS(hex_grid, "data/hex_grid_metro.rds")
cat("   hex_grid final guardado\n")

cat("\n═══ INTEGRACIÓN FINAL COMPLETADA ═══\n")
cat("\nArchivos generados:\n")
cat("  output/modelo_regresion.txt     — Resumen del modelo de regresión\n")
cat("  output/coeficientes_modelo.png  — Plot de coeficientes\n")
cat("  mapa_integrado_metro.html       — Mapa interactivo con todas las capas\n")
