# ══════════════════════════════════════════════════════════════════════════════
# CO-KRIGING PREDICCIÓN + MAPA LEAFLET
# Re-ajusta el LMC con range compartido y genera superficies krigeadas
# ══════════════════════════════════════════════════════════════════════════════

library(sf)
library(gstat)
library(dplyr)
library(leaflet)
library(htmlwidgets)

cat("═══ CO-KRIGING PREDICCIÓN ═══\n\n")

# ── 1. CARGAR DATOS ──────────────────────────────────────────────────────────
hex_grid <- readRDS("data/hex_grid_metro.rds")
cat("Hexágonos:", nrow(hex_grid), "\n")

est <- st_read("data/estaciones_metro_l1.geojson", quiet = TRUE)
st_crs(est) <- 6247
est_wgs <- st_transform(est, 4326)
coords_est <- st_coordinates(st_centroid(est_wgs))
orden <- order(as.integer(est$NUMERO))

hex_pts <- st_centroid(hex_grid)

# ── 2. RE-AJUSTAR LMC CON RANGE COMPARTIDO (crimes_3) ───────────────────────
cat("\n2. Ajustando LMC con range compartido...\n")

# Crear objeto gstat
g <- gstat(id = "HurtoComercio", formula = log_shoplifting ~ 1, data = hex_pts)
g <- gstat(g, id = "HurtoPersonas", formula = log_theft ~ 1, data = hex_pts)
g <- gstat(g, id = "Extorsion", formula = log_extortion ~ 1, data = hex_pts)

# Variograma experimental
v_exp <- variogram(g, cutoff = 2500, width = 125)

# Ajustar LMC con range compartido (fit.ranges = FALSE)
# Usar range = 1100m (promedio de lo que estimamos con fit.ranges=TRUE)
v_model <- vgm(psill = 0.4, model = "Sph", range = 1100, nugget = 0.15)
v_fit <- fit.lmc(v_exp, g, model = v_model, correct.diagonal = 1.01)

# Reportar
for (lab in c("HurtoComercio", "HurtoPersonas", "Extorsion")) {
  vm <- v_fit$model[[lab]]
  cat("  ", lab, "— nugget:", round(vm$psill[1], 3),
      "| sill:", round(sum(vm$psill), 3),
      "| range:", round(vm$range[2]), "m\n")
}

# ── 3. PREDICCIÓN CO-KRIGING ────────────────────────────────────────────────
cat("\n3. Ejecutando co-kriging (esto puede tomar un minuto)...\n")
pred <- predict(v_fit, newdata = hex_pts)
cat("   Predicción completada\n")

hex_grid$pred_shoplifting <- pred$HurtoComercio.pred
hex_grid$pred_theft       <- pred$HurtoPersonas.pred
hex_grid$pred_extortion   <- pred$Extorsion.pred
hex_grid$var_shoplifting  <- pred$HurtoComercio.var
hex_grid$var_theft        <- pred$HurtoPersonas.var

# ── 4. PREDICCIÓN PERCEPCIÓN (si hay datos) ──────────────────────────────────
has_perc <- "percepcion" %in% names(hex_pts) && sum(!is.na(hex_pts$percepcion)) >= 30

if (has_perc) {
  cat("\n4. Ajustando co-kriging: Percepcion + HurtoComercio...\n")

  hex_perc <- hex_pts[!is.na(hex_pts$percepcion), ]

  gp <- gstat(id = "Percepcion", formula = percepcion ~ 1, data = hex_perc)
  gp <- gstat(gp, id = "HurtoComercio", formula = log_shoplifting ~ 1, data = hex_perc)

  vp_exp <- variogram(gp, cutoff = 2500, width = 125)
  vp_model <- vgm(psill = 0.3, model = "Sph", range = 900, nugget = 0.15)
  vp_fit <- fit.lmc(vp_exp, gp, model = vp_model, correct.diagonal = 1.01)

  for (lab in c("Percepcion", "HurtoComercio")) {
    vm <- vp_fit$model[[lab]]
    cat("  ", lab, "— nugget:", round(vm$psill[1], 3),
        "| sill:", round(sum(vm$psill), 3),
        "| range:", round(vm$range[2]), "m\n")
  }

  # Predecir en TODOS los hexágonos (co-kriging usa hurto comercio para mejorar
  # la predicción de percepción en hexágonos sin encuestas)
  pred_perc <- tryCatch({
    predict(vp_fit, newdata = hex_pts)
  }, error = function(e) {
    cat("   Error predicción percepción:", e$message, "\n")
    NULL
  })

  if (!is.null(pred_perc)) {
    hex_grid$pred_percepcion <- pred_perc$Percepcion.pred
    hex_grid$var_percepcion  <- pred_perc$Percepcion.var
    cat("   Percepción predicha en", sum(!is.na(hex_grid$pred_percepcion)), "hexágonos\n")
  }

  # Plot del variograma percepción
  png("output/variograma_perc_hurto.png", width = 700, height = 500, res = 120)
  plot(vp_exp, model = vp_fit$model,
       main = "Co-variograma: Percepción + Hurto Comercio")
  dev.off()
  cat("   Plot guardado: output/variograma_perc_hurto.png\n")
}

# ── 5. MAPA LEAFLET ─────────────────────────────────────────────────────────
cat("\n5. Generando mapa leaflet...\n")

hex_wgs <- st_transform(hex_grid, 4326)
metro_line_wgs <- st_sfc(st_linestring(coords_est[orden, 1:2]), crs = 4326)

# Paletas
pal_shop <- colorNumeric("YlOrRd", domain = hex_wgs$pred_shoplifting, na.color = "transparent")
pal_theft <- colorNumeric("YlOrRd", domain = hex_wgs$pred_theft, na.color = "transparent")
pal_ext <- colorNumeric("Reds", domain = hex_wgs$pred_extortion, na.color = "transparent")
pal_var <- colorNumeric("Blues", domain = hex_wgs$var_shoplifting, na.color = "transparent")

# Popups
popups_hex <- sprintf(
  "<b>Hex #%d</b> | Dist metro: %d m<br/><hr/>
  <b>Co-kriging (log):</b><br/>
  Hurto comercio: %.2f<br/>Hurto personas: %.2f<br/>Extorsión: %.2f%s",
  hex_wgs$hex_id, round(hex_wgs$dist_metro),
  hex_wgs$pred_shoplifting, hex_wgs$pred_theft, hex_wgs$pred_extortion,
  ifelse("pred_percepcion" %in% names(hex_wgs) & !is.na(hex_wgs$pred_percepcion),
         sprintf("<br/><b>Percepción: %.2f</b> (1-5)", hex_wgs$pred_percepcion), "")
)

m <- leaflet() |>
  addProviderTiles(providers$CartoDB.Positron) |>

  addPolygons(data = hex_wgs, fillColor = ~pal_shop(pred_shoplifting),
    weight = 0.3, opacity = 0.4, color = "#999", fillOpacity = 0.7,
    popup = popups_hex, group = "Hurto Comercio") |>

  addPolygons(data = hex_wgs, fillColor = ~pal_theft(pred_theft),
    weight = 0.3, opacity = 0.4, color = "#999", fillOpacity = 0.7,
    popup = popups_hex, group = "Hurto Personas") |>

  addPolygons(data = hex_wgs, fillColor = ~pal_ext(pred_extortion),
    weight = 0.3, opacity = 0.4, color = "#999", fillOpacity = 0.7,
    popup = popups_hex, group = "Extorsión") |>

  addPolygons(data = hex_wgs, fillColor = ~pal_var(var_shoplifting),
    weight = 0.3, opacity = 0.4, color = "#999", fillOpacity = 0.7,
    popup = popups_hex, group = "Incertidumbre") |>

  addPolylines(data = metro_line_wgs,
    color = "#1565C0", weight = 4, opacity = 0.9, group = "Metro L1") |>

  addCircleMarkers(lng = coords_est[, 1], lat = coords_est[, 2],
    radius = 6, color = "#D32F2F", fillColor = "#F44336",
    fillOpacity = 0.9, weight = 2,
    label = paste0(est$NOMBRE, " (#", est$NUMERO, ")"),
    group = "Estaciones")

# Percepción si existe
has_pred_perc <- "pred_percepcion" %in% names(hex_wgs) && sum(!is.na(hex_wgs$pred_percepcion)) > 0
if (has_pred_perc) {
  pal_perc <- colorNumeric("RdYlGn", domain = hex_wgs$pred_percepcion, na.color = "transparent")
  m <- m |> addPolygons(data = hex_wgs, fillColor = ~pal_perc(pred_percepcion),
    weight = 0.3, opacity = 0.4, color = "#999", fillOpacity = 0.7,
    popup = popups_hex, group = "Percepción")
}

groups <- c("Hurto Comercio", "Hurto Personas", "Extorsión",
            "Incertidumbre", "Metro L1", "Estaciones")
if (has_pred_perc) groups <- c("Percepción", groups)

m <- m |>
  addLayersControl(overlayGroups = groups,
    options = layersControlOptions(collapsed = FALSE)) |>
  hideGroup("Hurto Personas") |>
  hideGroup("Extorsión") |>
  hideGroup("Incertidumbre")

if (has_pred_perc) m <- m |> hideGroup("Percepción")

m <- m |> addLegend(pal = pal_shop, values = hex_wgs$pred_shoplifting,
  title = "Hurto comercio<br/>(log co-kriging)", position = "bottomright")

saveWidget(m, "mapa_cokriging_metro.html", selfcontained = FALSE)
cat("Mapa guardado: mapa_cokriging_metro.html\n")

# Guardar grilla actualizada
saveRDS(hex_grid, "data/hex_grid_metro.rds")
cat("═══ COMPLETADO ═══\n")
