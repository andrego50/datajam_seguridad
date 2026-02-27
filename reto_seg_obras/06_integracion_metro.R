# ══════════════════════════════════════════════════════════════════════════════
# INTEGRACIÓN FINAL: REGRESIÓN ESPACIAL + MAPA — Metro Línea 1
# Equipo CyberRosario — Datajam Seguridad CCB
# ══════════════════════════════════════════════════════════════════════════════

library(sf)
library(spdep)
library(dplyr)
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

# ── 7. MAPA LEAFLET INTEGRADO ───────────────────────────────────────────────
cat("\n7. Generando mapa integrado...\n")

hex_wgs <- st_transform(hex_grid, 4326)

# Paletas
make_pal <- function(vals, palette = "YlOrRd") {
  vals_clean <- vals[!is.na(vals)]
  if (length(vals_clean) == 0) return(NULL)
  colorNumeric(palette, domain = vals_clean, na.color = "transparent")
}

# Popups
make_popup <- function(hex) {
  sprintf(
    "<b>Hex #%d</b> | Dist metro: %d m<hr/>
    <b>Delitos (2021-2023):</b><br/>
    Hurto comercio: %d | Hurto personas: %d<br/>
    Extorsión: %d | Lesiones: %d<br/>
    <b>Cambio (antes/durante):</b> %+.1f%%<br/>
    <b>Percepción:</b> %s<br/>
    <b>Empresas:</b> %s | MiPyme: %s<br/>
    <b>Entorno:</b> Verde: %s%% | Edificios: %s | Vías: %s m",
    hex$hex_id, round(hex$dist_metro),
    ifelse("shoplifting" %in% names(hex), hex$shoplifting, NA),
    ifelse("theft" %in% names(hex), hex$theft, NA),
    ifelse("extortion" %in% names(hex), hex$extortion, NA),
    ifelse("assault" %in% names(hex), hex$assault, NA),
    ifelse("cambio_total" %in% names(hex), hex$cambio_total * 100, NA),
    ifelse("pred_percepcion" %in% names(hex) & !is.na(hex$pred_percepcion),
           sprintf("%.2f", hex$pred_percepcion), "N/A"),
    ifelse("n_empresas_2024" %in% names(hex) & !is.na(hex$n_empresas_2024),
           as.character(hex$n_empresas_2024), "N/A"),
    ifelse("pct_mipyme" %in% names(hex) & !is.na(hex$pct_mipyme),
           sprintf("%.0f%%", hex$pct_mipyme * 100), "N/A"),
    ifelse("pct_verde" %in% names(hex), sprintf("%.1f", hex$pct_verde * 100), "N/A"),
    ifelse("n_edificios" %in% names(hex), hex$n_edificios, "N/A"),
    ifelse("longitud_vias_m" %in% names(hex), round(hex$longitud_vias_m), "N/A")
  )
}

popups <- make_popup(hex_wgs)

m <- leaflet() |>
  addProviderTiles(providers$CartoDB.Positron)

# --- Capas de predicción co-kriging (del pipeline original) ---
if ("pred_shoplifting" %in% names(hex_wgs)) {
  pal <- make_pal(hex_wgs$pred_shoplifting)
  if (!is.null(pal)) {
    m <- m |> addPolygons(data = hex_wgs, fillColor = ~pal(pred_shoplifting),
      weight = 0.3, opacity = 0.4, color = "#999", fillOpacity = 0.7,
      popup = popups, group = "Hurto Comercio (kriging)")
  }
}

if ("pred_theft" %in% names(hex_wgs)) {
  pal <- make_pal(hex_wgs$pred_theft)
  if (!is.null(pal)) {
    m <- m |> addPolygons(data = hex_wgs, fillColor = ~pal(pred_theft),
      weight = 0.3, opacity = 0.4, color = "#999", fillOpacity = 0.7,
      popup = popups, group = "Hurto Personas (kriging)")
  }
}

if ("pred_percepcion" %in% names(hex_wgs)) {
  pal <- make_pal(hex_wgs$pred_percepcion, "RdYlGn")
  if (!is.null(pal)) {
    m <- m |> addPolygons(data = hex_wgs, fillColor = ~pal(pred_percepcion),
      weight = 0.3, opacity = 0.4, color = "#999", fillOpacity = 0.7,
      popup = popups, group = "Percepción (kriging)")
  }
}

# --- Capas nuevas: Antes/Durante ---
if ("cambio_total" %in% names(hex_wgs)) {
  pal_cambio <- colorNumeric("RdBu", domain = hex_wgs$cambio_total,
                              na.color = "transparent", reverse = TRUE)
  m <- m |> addPolygons(data = hex_wgs, fillColor = ~pal_cambio(cambio_total),
    weight = 0.3, opacity = 0.4, color = "#999", fillOpacity = 0.7,
    popup = popups, group = "Cambio Delitos (antes/durante)")
}

# --- Capas nuevas: Empresas ---
if ("densidad_empresas" %in% names(hex_wgs)) {
  pal_emp <- make_pal(hex_wgs$densidad_empresas, "YlGnBu")
  if (!is.null(pal_emp)) {
    m <- m |> addPolygons(data = hex_wgs, fillColor = ~pal_emp(densidad_empresas),
      weight = 0.3, opacity = 0.4, color = "#999", fillOpacity = 0.7,
      popup = popups, group = "Densidad Empresarial")
  }
}

# --- Capas nuevas: Entorno ---
if ("pct_verde" %in% names(hex_wgs)) {
  pal_verde <- colorNumeric("Greens", domain = hex_wgs$pct_verde,
                             na.color = "transparent")
  m <- m |> addPolygons(data = hex_wgs, fillColor = ~pal_verde(pct_verde),
    weight = 0.3, opacity = 0.4, color = "#999", fillOpacity = 0.7,
    popup = popups, group = "Cobertura Verde")
}

if ("n_edificios" %in% names(hex_wgs)) {
  pal_edif <- make_pal(hex_wgs$n_edificios, "Oranges")
  if (!is.null(pal_edif)) {
    m <- m |> addPolygons(data = hex_wgs, fillColor = ~pal_edif(n_edificios),
      weight = 0.3, opacity = 0.4, color = "#999", fillOpacity = 0.7,
      popup = popups, group = "Densidad Edificios")
  }
}

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
                "Metro L1", "Estaciones")

# Mantener visibles solo la primera capa + metro
hide_groups <- all_groups[!all_groups %in% c("Hurto Comercio (kriging)",
                                              "Metro L1", "Estaciones")]

m <- m |>
  addLayersControl(overlayGroups = all_groups,
    options = layersControlOptions(collapsed = FALSE))

for (g in hide_groups) {
  m <- m |> hideGroup(g)
}

# Leyenda principal
if ("pred_shoplifting" %in% names(hex_wgs)) {
  pal_legend <- make_pal(hex_wgs$pred_shoplifting)
  if (!is.null(pal_legend)) {
    m <- m |> addLegend(pal = pal_legend, values = hex_wgs$pred_shoplifting,
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
