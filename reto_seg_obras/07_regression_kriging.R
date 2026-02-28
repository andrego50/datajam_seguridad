# ══════════════════════════════════════════════════════════════════════════════
# REGRESSION KRIGING — Metro Línea 1
# Combina regresión OLS (tendencia) + kriging de residuos (estructura espacial)
# Equipo CyberRosario — Datajam Seguridad CCB
# ══════════════════════════════════════════════════════════════════════════════

library(sf)
library(gstat)
library(dplyr)
library(terra)
library(raster)
library(leaflet)
library(htmlwidgets)

cat("═══ REGRESSION KRIGING ═══\n\n")

# ── 1. CARGAR DATOS ──────────────────────────────────────────────────────────
cat("1. Cargando datos...\n")
hex_grid <- readRDS("data/hex_grid_metro.rds")
cat("   Hexágonos:", nrow(hex_grid), "\n")
cat("   Columnas:", ncol(hex_grid), "\n")

est <- st_read("data/estaciones_metro_l1.geojson", quiet = TRUE)
st_crs(est) <- 6247
est_wgs <- st_transform(est, 4326)
coords_est <- st_coordinates(st_centroid(est_wgs))
orden <- order(as.integer(est$NUMERO))
metro_line_wgs <- st_sfc(st_linestring(coords_est[orden, 1:2]), crs = 4326)

# Reconstruir buffer
est_3116 <- st_transform(est, 3116)
centroids_3116 <- st_centroid(est_3116)
coords_3116 <- st_coordinates(centroids_3116[orden, ])
metro_line <- st_sfc(st_linestring(coords_3116[, 1:2]), crs = 3116)
buffer_metro <- st_buffer(metro_line, 1500)

# ── 2. PREPARAR VARIABLE DEPENDIENTE Y PREDICTORES ──────────────────────────
cat("\n2. Preparando variables para regresión...\n")

# Variable dependiente
if ("pred_percepcion" %in% names(hex_grid) &&
    sum(!is.na(hex_grid$pred_percepcion)) > 50) {
  hex_grid$y <- hex_grid$pred_percepcion
  y_label <- "Percepción co-kriging"
} else if ("percepcion" %in% names(hex_grid) &&
           sum(!is.na(hex_grid$percepcion)) > 30) {
  hex_grid$y <- hex_grid$percepcion
  y_label <- "Percepción directa"
} else {
  hex_grid$y <- hex_grid$log_theft
  y_label <- "Hurto personas (log)"
}
cat("   Variable dependiente:", y_label, "\n")

# Distancia al metro en km
hex_grid$dist_metro_km <- hex_grid$dist_metro / 1000

# Seleccionar predictores disponibles
predictores <- c()
pred_labels <- c()

add_pred <- function(var, label) {
  if (var %in% names(hex_grid) && sum(!is.na(hex_grid[[var]])) > 100) {
    predictores <<- c(predictores, var)
    pred_labels <<- c(pred_labels, label)
  }
}

add_pred("dist_metro_km", "Distancia al Metro (km)")
add_pred("cambio_total", "Cambio total delitos")
add_pred("log_raids", "Allanamientos (log)")
add_pred("log_arrests", "Capturas (log)")
add_pred("log_seizures", "Incautaciones (log)")
add_pred("cambio_ops_total", "Cambio operativos policiales")
add_pred("pct_mipyme", "% MiPymes")
add_pred("densidad_empresas", "Densidad empresarial")
add_pred("pct_verde", "% Área verde")
add_pred("n_edificios", "N edificios")
add_pred("uso_comercial", "Uso comercial (0/1)")
add_pred("longitud_vias_m", "Longitud vías (m)")

cat("   Predictores (", length(predictores), "):\n")
for (i in seq_along(predictores)) {
  cat("     ", predictores[i], "—", pred_labels[i], "\n")
}

# ── 3. PASO 1: REGRESIÓN OLS (TENDENCIA) ─────────────────────────────────────
cat("\n3. Paso 1: Regresión OLS (tendencia)...\n")

formula_str <- paste("y ~", paste(predictores, collapse = " + "))
formula_reg <- as.formula(formula_str)
cat("   Fórmula:", formula_str, "\n")

# Centroides para geoestadística
hex_pts <- st_centroid(hex_grid)

# Filtrar datos completos
cols_modelo <- c("y", predictores)
hex_pts_complete <- hex_pts[complete.cases(st_drop_geometry(hex_pts[, cols_modelo])), ]
cat("   Observaciones completas:", nrow(hex_pts_complete), "/", nrow(hex_pts), "\n")

# Ajustar OLS
ols <- lm(formula_reg, data = hex_pts_complete)
cat("\n   ── RESULTADOS OLS ──\n")
cat("   R² ajustado:", round(summary(ols)$adj.r.squared, 4), "\n")
cat("   AIC:", round(AIC(ols), 2), "\n\n")

# Coeficientes
coef_df <- summary(ols)$coefficients
cat("   Coeficientes:\n")
for (i in seq_len(nrow(coef_df))) {
  pval <- coef_df[i, 4]
  sig <- ifelse(pval < 0.001, "***",
         ifelse(pval < 0.01, "**",
         ifelse(pval < 0.05, "*",
         ifelse(pval < 0.1, ".", ""))))
  cat("     ", rownames(coef_df)[i], ":",
      sprintf("%+.4f", coef_df[i, 1]),
      "(p=", sprintf("%.4f", pval), ")", sig, "\n")
}

# Interpretación: signo de los coeficientes
cat("\n   ── INTERPRETACIÓN ──\n")
for (i in 2:nrow(coef_df)) {
  nombre <- rownames(coef_df)[i]
  beta <- coef_df[i, 1]
  pval <- coef_df[i, 4]
  if (pval < 0.1) {
    dir <- ifelse(beta > 0, "AUMENTA", "DISMINUYE")
    cat("   →", nombre, ":", dir, "la", y_label,
        sprintf("(β=%+.4f, p=%.4f)", beta, pval), "\n")
  }
}

# ── 4. PASO 2: VARIOGRAMA DE RESIDUOS ────────────────────────────────────────
cat("\n4. Paso 2: Variograma de residuos OLS...\n")

hex_pts_complete$residuos <- residuals(ols)
hex_pts_complete$pred_ols <- fitted(ols)

# Variograma empírico de residuos
v_res <- variogram(residuos ~ 1, data = hex_pts_complete, cutoff = 2500, width = 125)

# Ajustar modelo de variograma
v_res_fit <- fit.variogram(v_res,
  vgm(psill = var(hex_pts_complete$residuos) * 0.8,
      model = "Sph",
      range = 800,
      nugget = var(hex_pts_complete$residuos) * 0.2))

cat("   Variograma de residuos:\n")
cat("     Nugget:", round(v_res_fit$psill[1], 4), "\n")
cat("     Sill total:", round(sum(v_res_fit$psill), 4), "\n")
cat("     Range:", round(v_res_fit$range[2]), "m\n")

# Ratio nugget/sill = qué % de varianza NO tiene estructura espacial
ratio_ns <- v_res_fit$psill[1] / sum(v_res_fit$psill)
cat("     Ratio nugget/sill:", round(ratio_ns, 3),
    ifelse(ratio_ns < 0.25, "(estructura espacial fuerte en residuos)",
    ifelse(ratio_ns < 0.75, "(estructura espacial moderada en residuos)",
                            "(estructura espacial débil en residuos)")), "\n")

cat("\n   INTERPRETACIÓN: Si el ratio nugget/sill es bajo, significa que\n")
cat("   el OLS NO captura toda la variación espacial — hay patrones\n")
cat("   geográficos que los predictores no explican.\n")

# Plot variograma de residuos
dir.create("output", showWarnings = FALSE)
png("output/variograma_residuos_rk.png", width = 800, height = 500, res = 120)
plot(v_res, model = v_res_fit,
     main = "Variograma de residuos OLS",
     xlab = "Distancia (m)", ylab = "Semivarianza",
     sub = sprintf("Nugget/Sill = %.2f — %s",
                    ratio_ns,
                    ifelse(ratio_ns < 0.25, "Estructura espacial fuerte",
                    ifelse(ratio_ns < 0.75, "Moderada", "Débil"))))
dev.off()
cat("   Guardado: output/variograma_residuos_rk.png\n")

# ── 5. PASO 3: KRIGING DE RESIDUOS ──────────────────────────────────────────
cat("\n5. Paso 3: Kriging de residuos sobre grilla fina...\n")

# Crear grilla fina de 50m
grid_fine <- st_make_grid(buffer_metro, cellsize = 50, what = "centers")
grid_fine <- st_as_sf(data.frame(id = seq_along(grid_fine)), geometry = grid_fine)
st_crs(grid_fine) <- 3116
grid_fine <- grid_fine[st_intersects(grid_fine, buffer_metro, sparse = FALSE)[, 1], ]
grid_fine$id <- seq_len(nrow(grid_fine))
cat("   Puntos en grilla fina:", nrow(grid_fine), "\n")

# Kriging ordinario de los residuos
cat("   Ejecutando kriging de residuos (esto toma unos minutos)...\n")
krige_res <- krige(residuos ~ 1,
                   locations = hex_pts_complete,
                   newdata = grid_fine,
                   model = v_res_fit)
cat("   Kriging completado\n")

grid_fine$residuo_kriged <- krige_res$var1.pred
grid_fine$residuo_var    <- krige_res$var1.var

# ── 6. PASO 4: PREDICCIÓN FINAL = OLS + KRIGING RESIDUOS ────────────────────
cat("\n6. Paso 4: Combinando OLS + kriging de residuos...\n")

# Para predecir OLS en la grilla fina, necesitamos los predictores en cada punto
# Asignar valores del hexágono más cercano
grid_fine_join <- st_join(grid_fine, hex_pts_complete[, c("hex_id", predictores)],
                          join = st_nearest_feature)

# Predicción OLS en grilla fina
grid_fine$pred_ols <- predict(ols, newdata = st_drop_geometry(grid_fine_join))

# Predicción final: tendencia + residuo espacial
grid_fine$pred_rk <- grid_fine$pred_ols + grid_fine$residuo_kriged

cat("   Rango predicción OLS:", round(range(grid_fine$pred_ols, na.rm = TRUE), 3), "\n")
cat("   Rango residuo kriged:", round(range(grid_fine$residuo_kriged, na.rm = TRUE), 3), "\n")
cat("   Rango predicción final (RK):", round(range(grid_fine$pred_rk, na.rm = TRUE), 3), "\n")

# ── 7. CONVERTIR A RASTERS ──────────────────────────────────────────────────
cat("\n7. Convirtiendo a rasters...\n")

points_to_raster <- function(coords, values, res = 50, crs_code = 3116) {
  df <- data.frame(x = coords[, 1], y = coords[, 2], z = values)
  df <- df[!is.na(df$z), ]
  v <- vect(df, geom = c("x", "y"), crs = paste0("EPSG:", crs_code))
  ext_buf <- ext(v) + res
  r <- rast(ext_buf, res = res, crs = paste0("EPSG:", crs_code))
  r <- rasterize(v, r, field = "z", fun = "mean")
  r_wgs <- project(r, "EPSG:4326", method = "bilinear")
  raster(r_wgs)
}

coords_fine <- st_coordinates(grid_fine)

rl_ols      <- points_to_raster(coords_fine, grid_fine$pred_ols)
rl_residuo  <- points_to_raster(coords_fine, grid_fine$residuo_kriged)
rl_rk       <- points_to_raster(coords_fine, grid_fine$pred_rk)
rl_var      <- points_to_raster(coords_fine, grid_fine$residuo_var)

cat("   Rasters creados y reproyectados a WGS84\n")

# ── 8. MAPA COMPARATIVO ──────────────────────────────────────────────────────
cat("\n8. Generando mapa comparativo...\n")

hex_wgs <- st_transform(hex_grid, 4326)

pal_rk  <- colorNumeric("RdYlGn", values(rl_rk), na.color = "transparent")
pal_ols <- colorNumeric("RdYlGn", values(rl_ols), na.color = "transparent")
pal_res <- colorNumeric("RdBu", values(rl_residuo), na.color = "transparent", reverse = TRUE)
pal_var <- colorNumeric("Blues", values(rl_var), na.color = "transparent")

# Popups
popups <- sprintf(
  "<b>Hex #%d</b> | Dist metro: %d m<hr/>
  <b>Delitos (2021-2023):</b><br/>
  Hurto comercio: %s | Hurto personas: %s<br/>
  Extorsión: %s | Lesiones: %s<br/>
  <b>Operativos:</b> Capturas: %s | Allana: %s | Incaut: %s<br/>
  <b>Cambio delitos:</b> %s | <b>Cambio ops:</b> %s<br/>
  <b>Entorno:</b> Verde: %s%% | Edificios: %s<br/>
  <b>Empresas:</b> %s | MiPyme: %s",
  hex_wgs$hex_id, round(hex_wgs$dist_metro),
  ifelse("shoplifting" %in% names(hex_wgs), hex_wgs$shoplifting, "N/A"),
  ifelse("theft" %in% names(hex_wgs), hex_wgs$theft, "N/A"),
  ifelse("extortion" %in% names(hex_wgs), hex_wgs$extortion, "N/A"),
  ifelse("assault" %in% names(hex_wgs), hex_wgs$assault, "N/A"),
  ifelse("arrests" %in% names(hex_wgs), hex_wgs$arrests, "N/A"),
  ifelse("raids" %in% names(hex_wgs), hex_wgs$raids, "N/A"),
  ifelse("seizures" %in% names(hex_wgs), hex_wgs$seizures, "N/A"),
  ifelse("cambio_total" %in% names(hex_wgs),
         sprintf("%+.1f%%", hex_wgs$cambio_total * 100), "N/A"),
  ifelse("cambio_ops_total" %in% names(hex_wgs),
         sprintf("%+.1f%%", hex_wgs$cambio_ops_total * 100), "N/A"),
  ifelse("pct_verde" %in% names(hex_wgs),
         sprintf("%.1f", hex_wgs$pct_verde * 100), "N/A"),
  ifelse("n_edificios" %in% names(hex_wgs), hex_wgs$n_edificios, "N/A"),
  ifelse("n_empresas_2024" %in% names(hex_wgs) & !is.na(hex_wgs$n_empresas_2024),
         as.character(hex_wgs$n_empresas_2024), "N/A"),
  ifelse("pct_mipyme" %in% names(hex_wgs) & !is.na(hex_wgs$pct_mipyme),
         sprintf("%.0f%%", hex_wgs$pct_mipyme * 100), "N/A")
)

m <- leaflet() |>
  addProviderTiles(providers$CartoDB.Positron) |>

  # Capa 1: Predicción final (OLS + Kriging residuos)
  addRasterImage(rl_rk, colors = pal_rk, opacity = 0.75,
    group = "Regression Kriging (final)") |>

  # Capa 2: Solo OLS (tendencia)
  addRasterImage(rl_ols, colors = pal_ols, opacity = 0.75,
    group = "Solo OLS (tendencia)") |>

  # Capa 3: Residuo krigeado (lo que OLS NO explica)
  addRasterImage(rl_residuo, colors = pal_res, opacity = 0.75,
    group = "Residuo espacial (kriged)") |>

  # Capa 4: Incertidumbre
  addRasterImage(rl_var, colors = pal_var, opacity = 0.75,
    group = "Incertidumbre (varianza)") |>

  # Hexágonos de referencia
  addPolygons(data = hex_wgs,
    fillColor = "transparent", fillOpacity = 0,
    weight = 0.8, opacity = 0.5, color = "#666",
    popup = popups,
    group = "Grilla hexagonal (ref)") |>

  # Metro
  addPolylines(data = metro_line_wgs,
    color = "#1565C0", weight = 4, opacity = 0.9, group = "Metro L1") |>
  addCircleMarkers(lng = coords_est[, 1], lat = coords_est[, 2],
    radius = 6, color = "#D32F2F", fillColor = "#F44336",
    fillOpacity = 0.9, weight = 2,
    label = paste0(est$NOMBRE, " (#", est$NUMERO, ")"),
    group = "Estaciones") |>

  # Control de capas
  addLayersControl(
    overlayGroups = c("Regression Kriging (final)", "Solo OLS (tendencia)",
                      "Residuo espacial (kriged)", "Incertidumbre (varianza)",
                      "Grilla hexagonal (ref)", "Metro L1", "Estaciones"),
    options = layersControlOptions(collapsed = FALSE)) |>
  hideGroup("Solo OLS (tendencia)") |>
  hideGroup("Incertidumbre (varianza)") |>
  hideGroup("Grilla hexagonal (ref)") |>

  # Leyendas
  addLegend(pal = pal_rk, values = values(rl_rk),
    title = paste0(y_label, "<br/>(Regression Kriging)"),
    position = "bottomright") |>
  addLegend(pal = pal_res, values = values(rl_residuo),
    title = "Residuo espacial<br/>(azul=mejor, rojo=peor)",
    position = "bottomleft")

saveWidget(m, "mapa_regression_kriging.html", selfcontained = FALSE)
cat("   Guardado: mapa_regression_kriging.html\n")

# ── 9. GUARDAR RESULTADOS ───────────────────────────────────────────────────
cat("\n9. Guardando resultados...\n")

# Resumen del modelo
sink("output/regression_kriging_resultados.txt")
cat("══════════════════════════════════════════════════════════\n")
cat("REGRESSION KRIGING — METRO LÍNEA 1\n")
cat("Equipo CyberRosario — Datajam Seguridad CCB\n")
cat("══════════════════════════════════════════════════════════\n\n")

cat("Variable dependiente:", y_label, "\n")
cat("N observaciones:", nrow(hex_pts_complete), "\n\n")

cat("══ PASO 1: REGRESIÓN OLS (TENDENCIA) ══\n\n")
cat("Fórmula:", formula_str, "\n\n")
print(summary(ols))

cat("\n\n══ PASO 2: VARIOGRAMA DE RESIDUOS ══\n\n")
cat("Modelo:", v_res_fit$model[2], "\n")
cat("Nugget:", round(v_res_fit$psill[1], 4), "\n")
cat("Sill parcial:", round(v_res_fit$psill[2], 4), "\n")
cat("Sill total:", round(sum(v_res_fit$psill), 4), "\n")
cat("Range:", round(v_res_fit$range[2]), "m\n")
cat("Ratio nugget/sill:", round(ratio_ns, 3), "\n\n")

cat("INTERPRETACIÓN:\n")
cat("- El ratio nugget/sill indica qué proporción de la varianza\n")
cat("  de los residuos NO tiene estructura espacial (ruido puro).\n")
cat("- Ratio < 0.25: fuerte estructura espacial en los residuos\n")
cat("  → Los predictores NO capturan patrones geográficos importantes\n")
cat("- Ratio 0.25-0.75: estructura moderada\n")
cat("- Ratio > 0.75: poca estructura → OLS captura bien la variación\n\n")

cat("══ PASO 3: REGRESSION KRIGING ══\n\n")
cat("Predicción final = OLS(x) + Kriging(residuos)\n\n")
cat("Ventaja sobre SAR/SEM:\n")
cat("- Mismos coeficientes OLS (interpretación idéntica)\n")
cat("- PERO se puede visualizar dónde el modelo falla espacialmente\n")
cat("- El mapa del 'residuo krigeado' muestra zonas donde la\n")
cat("  percepción es MEJOR o PEOR de lo que los predictores predicen\n")
cat("- Azul = mejor de lo esperado, Rojo = peor de lo esperado\n\n")

cat("══ HALLAZGOS POR HIPÓTESIS ══\n\n")

# H1: distancia → delitos
if ("dist_metro_km" %in% predictores) {
  beta <- coef_df["dist_metro_km", 1]
  pval <- coef_df["dist_metro_km", 4]
  cat("H1 (distancia → inseguridad):\n")
  cat("   β =", round(beta, 4), "| p =", round(pval, 4), "\n")
  if (pval < 0.05) {
    cat("   →", ifelse(beta > 0, "A mayor distancia, MAYOR", "A mayor distancia, MENOR"),
        "percepción de inseguridad\n")
  } else {
    cat("   → No significativo al 5%\n")
  }
  cat("\n")
}

# H4: cambio antes/durante
if ("cambio_total" %in% predictores) {
  beta <- coef_df["cambio_total", 1]
  pval <- coef_df["cambio_total", 4]
  cat("H4 (cambio delitos antes/durante):\n")
  cat("   β =", round(beta, 4), "| p =", round(pval, 4), "\n")
  if (pval < 0.05) {
    cat("   → El cambio en delitos SÍ explica percepción\n")
  } else {
    cat("   → No significativo\n")
  }
  cat("\n")
}

# Operativos policiales
for (op in c("log_raids", "log_arrests", "log_seizures")) {
  if (op %in% rownames(coef_df)) {
    beta <- coef_df[op, 1]
    pval <- coef_df[op, 4]
    cat("Operativo", op, ":\n")
    cat("   β =", round(beta, 4), "| p =", round(pval, 4), "\n")
    if (pval < 0.05) {
      cat("   → Más", op, ifelse(beta < 0, "MEJORA", "EMPEORA"), "percepción\n")
    }
    cat("\n")
  }
}

# H5: MiPymes
if ("pct_mipyme" %in% rownames(coef_df)) {
  beta <- coef_df["pct_mipyme", 1]
  pval <- coef_df["pct_mipyme", 4]
  cat("H5 (MiPymes vulnerables):\n")
  cat("   β =", round(beta, 4), "| p =", round(pval, 4), "\n")
  if (pval < 0.05) {
    cat("   → Mayor % MiPymes", ifelse(beta < 0, "MEJOR", "PEOR"), "percepción\n")
  }
  cat("\n")
}

# H6: entorno
if ("pct_verde" %in% rownames(coef_df)) {
  beta <- coef_df["pct_verde", 1]
  pval <- coef_df["pct_verde", 4]
  cat("H6 (entorno verde):\n")
  cat("   β =", round(beta, 4), "| p =", round(pval, 4), "\n")
  if (pval < 0.05) {
    cat("   → Más verde", ifelse(beta > 0, "MEJORA", "EMPEORA"), "percepción\n")
  }
  cat("\n")
}

cat("\n══ RESIDUO ESPACIAL ══\n\n")
cat("El mapa del 'residuo krigeado' revela zonas donde la percepción\n")
cat("es diferente de lo que los predictores sugieren:\n")
cat("- AZUL (residuo negativo): percepción MEJOR de lo esperado\n")
cat("- ROJO (residuo positivo): percepción PEOR de lo esperado\n")
cat("Estas zonas merecen investigación adicional (factores no medidos).\n")

sink()
cat("   Guardado: output/regression_kriging_resultados.txt\n")

# Plot de coeficientes
coefs <- coef_df[-1, , drop = FALSE]  # sin intercepto
if (nrow(coefs) > 0) {
  png("output/coeficientes_rk.png", width = 900, height = 500, res = 120)
  par(mar = c(5, 14, 3, 2))
  cols_bar <- ifelse(coefs[, 4] < 0.05, "#2196F3",
              ifelse(coefs[, 4] < 0.1, "#90CAF9", "#BDBDBD"))
  bp <- barplot(rev(coefs[, 1]), names.arg = rev(rownames(coefs)),
                horiz = TRUE, las = 1, col = rev(cols_bar), cex.names = 0.75,
                main = "Coeficientes OLS — Regression Kriging",
                xlab = "Coeficiente (azul oscuro = p<0.05, claro = p<0.1)")
  abline(v = 0, lty = 2, col = "gray40")
  par(mar = c(5, 4, 4, 2))
  dev.off()
  cat("   Guardado: output/coeficientes_rk.png\n")
}

# Guardar grilla fina
saveRDS(grid_fine, "data/grid_fine_rk.rds")
cat("   Guardado: data/grid_fine_rk.rds\n")

cat("\n═══ REGRESSION KRIGING COMPLETADO ═══\n")
cat("\nArchivos generados:\n")
cat("  mapa_regression_kriging.html              — Mapa interactivo\n")
cat("  output/regression_kriging_resultados.txt  — Resultados del modelo\n")
cat("  output/variograma_residuos_rk.png         — Variograma de residuos\n")
cat("  output/coeficientes_rk.png                — Plot de coeficientes\n")
cat("\nCómo interpretar el mapa:\n")
cat("  1. 'Regression Kriging (final)' = predicción completa\n")
cat("  2. 'Solo OLS (tendencia)' = solo la parte que explican los predictores\n")
cat("  3. 'Residuo espacial' = lo que OLS NO explica (patrones ocultos)\n")
cat("     → Azul = mejor de lo esperado, Rojo = peor de lo esperado\n")
cat("  4. 'Incertidumbre' = dónde hay más/menos confianza en la predicción\n")
