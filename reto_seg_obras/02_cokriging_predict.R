# ══════════════════════════════════════════════════════════════════════════════
# CO-KRIGING PREDICCIÓN + MAPA LEAFLET (SUPERFICIE SUAVIZADA)
# Predice sobre grilla fina (50m) → raster continuo para leaflet
# ══════════════════════════════════════════════════════════════════════════════

library(sf)
library(gstat)
library(dplyr)
library(terra)
library(raster)
library(leaflet)
library(htmlwidgets)

cat("═══ CO-KRIGING PREDICCIÓN (SUPERFICIE SUAVIZADA) ═══\n\n")

# ── 1. CARGAR DATOS ──────────────────────────────────────────────────────────
hex_grid <- readRDS("data/hex_grid_metro.rds")
cat("Hexágonos:", nrow(hex_grid), "\n")

est <- st_read("data/estaciones_metro_l1.geojson", quiet = TRUE)
st_crs(est) <- 6247
est_wgs <- st_transform(est, 4326)
coords_est <- st_coordinates(st_centroid(est_wgs))
orden <- order(as.integer(est$NUMERO))

# Reconstruir buffer
est_3116 <- st_transform(est, 3116)
centroids_3116 <- st_centroid(est_3116)
coords_3116 <- st_coordinates(centroids_3116[orden, ])
metro_line <- st_sfc(st_linestring(coords_3116[, 1:2]), crs = 3116)
buffer_metro <- st_buffer(metro_line, 1500)

hex_pts <- st_centroid(hex_grid)

# ── 2. RE-AJUSTAR LMC CON RANGE COMPARTIDO ──────────────────────────────────
cat("\n2. Ajustando LMC con range compartido...\n")

g <- gstat(id = "HurtoComercio", formula = log_shoplifting ~ 1, data = hex_pts)
g <- gstat(g, id = "HurtoPersonas", formula = log_theft ~ 1, data = hex_pts)
g <- gstat(g, id = "Extorsion", formula = log_extortion ~ 1, data = hex_pts)

v_exp <- variogram(g, cutoff = 2500, width = 125)
v_model <- vgm(psill = 0.4, model = "Sph", range = 1100, nugget = 0.15)
v_fit <- fit.lmc(v_exp, g, model = v_model, correct.diagonal = 1.01)

for (lab in c("HurtoComercio", "HurtoPersonas", "Extorsion")) {
  vm <- v_fit$model[[lab]]
  cat("  ", lab, "— nugget:", round(vm$psill[1], 3),
      "| sill:", round(sum(vm$psill), 3),
      "| range:", round(vm$range[2]), "m\n")
}

# ── 3. CREAR GRILLA FINA (50m) PARA PREDICCIÓN SUAVIZADA ────────────────────
cat("\n3. Creando grilla fina de 50m para superficie suavizada...\n")

# Grilla regular de puntos cada 50m dentro del buffer
grid_fine <- st_make_grid(buffer_metro, cellsize = 50, what = "centers")
grid_fine <- st_as_sf(data.frame(id = seq_along(grid_fine)), geometry = grid_fine)
st_crs(grid_fine) <- 3116

# Filtrar solo puntos dentro del buffer
grid_fine <- grid_fine[st_intersects(grid_fine, buffer_metro, sparse = FALSE)[, 1], ]
grid_fine$id <- seq_len(nrow(grid_fine))
cat("   Puntos en grilla fina:", nrow(grid_fine), "\n")

# ── 4. PREDICCIÓN CO-KRIGING SOBRE GRILLA FINA ──────────────────────────────
cat("\n4. Ejecutando co-kriging sobre grilla fina (esto toma varios minutos)...\n")

pred_fine <- predict(v_fit, newdata = grid_fine)
cat("   Predicción completada\n")

# Asignar predicciones
grid_fine$pred_shoplifting <- pred_fine$HurtoComercio.pred
grid_fine$pred_theft       <- pred_fine$HurtoPersonas.pred
grid_fine$pred_extortion   <- pred_fine$Extorsion.pred
grid_fine$var_shoplifting  <- pred_fine$HurtoComercio.var

# También guardar predicciones en hex_grid (para otros scripts)
pred_hex <- predict(v_fit, newdata = hex_pts)
hex_grid$pred_shoplifting <- pred_hex$HurtoComercio.pred
hex_grid$pred_theft       <- pred_hex$HurtoPersonas.pred
hex_grid$pred_extortion   <- pred_hex$Extorsion.pred
hex_grid$var_shoplifting  <- pred_hex$HurtoComercio.var
hex_grid$var_theft        <- pred_hex$HurtoPersonas.var

# ── 5. PREDICCIÓN PERCEPCIÓN (si hay datos) ──────────────────────────────────
has_perc <- "percepcion" %in% names(hex_pts) && sum(!is.na(hex_pts$percepcion)) >= 30

if (has_perc) {
  cat("\n5. Ajustando co-kriging: Percepcion + HurtoComercio...\n")

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

  # Predecir percepción en grilla fina
  pred_perc_fine <- tryCatch({
    predict(vp_fit, newdata = grid_fine)
  }, error = function(e) {
    cat("   Error predicción percepción en grilla fina:", e$message, "\n")
    NULL
  })

  if (!is.null(pred_perc_fine)) {
    grid_fine$pred_percepcion <- pred_perc_fine$Percepcion.pred
    cat("   Percepción predicha en grilla fina:", sum(!is.na(grid_fine$pred_percepcion)), "puntos\n")
  }

  # También en hex_grid
  pred_perc_hex <- tryCatch(predict(vp_fit, newdata = hex_pts), error = function(e) NULL)
  if (!is.null(pred_perc_hex)) {
    hex_grid$pred_percepcion <- pred_perc_hex$Percepcion.pred
    hex_grid$var_percepcion  <- pred_perc_hex$Percepcion.var
  }

  dir.create("output", showWarnings = FALSE)
  png("output/variograma_perc_hurto.png", width = 700, height = 500, res = 120)
  plot(vp_exp, model = vp_fit$model,
       main = "Co-variograma: Percepción + Hurto Comercio")
  dev.off()
  cat("   Plot guardado: output/variograma_perc_hurto.png\n")
}

# ── 6. CONVERTIR PREDICCIONES A RASTER ───────────────────────────────────────
cat("\n6. Convirtiendo predicciones a raster...\n")

# Coordenadas de la grilla fina
coords_fine <- st_coordinates(grid_fine)

# Función para crear raster desde puntos
points_to_raster <- function(coords, values, res = 50, crs_code = 3116) {
  df <- data.frame(x = coords[, 1], y = coords[, 2], z = values)
  df <- df[!is.na(df$z), ]
  v <- vect(df, geom = c("x", "y"), crs = paste0("EPSG:", crs_code))
  # Crear raster vacío con la resolución deseada
  ext_buf <- ext(v) + res  # un poco de margen
  r <- rast(ext_buf, res = res, crs = paste0("EPSG:", crs_code))
  # Rasterizar
  r <- rasterize(v, r, field = "z", fun = "mean")
  return(r)
}

rast_shoplifting <- points_to_raster(coords_fine, grid_fine$pred_shoplifting)
rast_theft       <- points_to_raster(coords_fine, grid_fine$pred_theft)
rast_extortion   <- points_to_raster(coords_fine, grid_fine$pred_extortion)
rast_var         <- points_to_raster(coords_fine, grid_fine$var_shoplifting)

cat("   Rasters creados — resolución:", res(rast_shoplifting), "m\n")

# Reproyectar rasters a WGS84 para leaflet
rast_shop_wgs <- project(rast_shoplifting, "EPSG:4326", method = "bilinear")
rast_thft_wgs <- project(rast_theft, "EPSG:4326", method = "bilinear")
rast_ext_wgs  <- project(rast_extortion, "EPSG:4326", method = "bilinear")
rast_var_wgs  <- project(rast_var, "EPSG:4326", method = "bilinear")

# Convertir a raster::RasterLayer para leaflet (addRasterImage necesita esto)
rl_shop <- raster(rast_shop_wgs)
rl_thft <- raster(rast_thft_wgs)
rl_ext  <- raster(rast_ext_wgs)
rl_var  <- raster(rast_var_wgs)

# Percepción si existe
has_perc_fine <- "pred_percepcion" %in% names(grid_fine) &&
                  sum(!is.na(grid_fine$pred_percepcion)) > 0
if (has_perc_fine) {
  rast_perc     <- points_to_raster(coords_fine, grid_fine$pred_percepcion)
  rast_perc_wgs <- project(rast_perc, "EPSG:4326", method = "bilinear")
  rl_perc       <- raster(rast_perc_wgs)
}

cat("   Rasters reproyectados a WGS84\n")

# ── 7. MAPA LEAFLET CON SUPERFICIES SUAVIZADAS ──────────────────────────────
cat("\n7. Generando mapa leaflet con superficies suavizadas...\n")

hex_wgs <- st_transform(hex_grid, 4326)
metro_line_wgs <- st_sfc(st_linestring(coords_est[orden, 1:2]), crs = 4326)

# Paletas para rasters
pal_shop <- colorNumeric("YlOrRd", values(rl_shop), na.color = "transparent")
pal_thft <- colorNumeric("YlOrRd", values(rl_thft), na.color = "transparent")
pal_ext  <- colorNumeric("Reds", values(rl_ext), na.color = "transparent")
pal_var  <- colorNumeric("Blues", values(rl_var), na.color = "transparent")

# Popups para hexágonos de referencia
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

  # ── Superficies suavizadas (raster) ──
  addRasterImage(rl_shop, colors = pal_shop, opacity = 0.75,
    group = "Hurto Comercio") |>

  addRasterImage(rl_thft, colors = pal_thft, opacity = 0.75,
    group = "Hurto Personas") |>

  addRasterImage(rl_ext, colors = pal_ext, opacity = 0.75,
    group = "Extorsión") |>

  addRasterImage(rl_var, colors = pal_var, opacity = 0.75,
    group = "Incertidumbre") |>

  # ── Hexágonos de referencia (solo bordes) ──
  addPolygons(data = hex_wgs,
    fillColor = "transparent", fillOpacity = 0,
    weight = 0.8, opacity = 0.5, color = "#666",
    popup = popups_hex,
    group = "Grilla hexagonal (ref)") |>

  # ── Infraestructura metro ──
  addPolylines(data = metro_line_wgs,
    color = "#1565C0", weight = 4, opacity = 0.9, group = "Metro L1") |>

  addCircleMarkers(lng = coords_est[, 1], lat = coords_est[, 2],
    radius = 6, color = "#D32F2F", fillColor = "#F44336",
    fillOpacity = 0.9, weight = 2,
    label = paste0(est$NOMBRE, " (#", est$NUMERO, ")"),
    group = "Estaciones")

# Percepción suavizada si existe
if (has_perc_fine) {
  pal_perc <- colorNumeric("RdYlGn", values(rl_perc), na.color = "transparent")
  m <- m |> addRasterImage(rl_perc, colors = pal_perc, opacity = 0.75,
    group = "Percepción")
}

# Control de capas
groups <- c("Hurto Comercio", "Hurto Personas", "Extorsión",
            "Incertidumbre", "Grilla hexagonal (ref)", "Metro L1", "Estaciones")
if (has_perc_fine) groups <- c("Percepción", groups)

m <- m |>
  addLayersControl(overlayGroups = groups,
    options = layersControlOptions(collapsed = FALSE)) |>
  hideGroup("Hurto Personas") |>
  hideGroup("Extorsión") |>
  hideGroup("Incertidumbre") |>
  hideGroup("Grilla hexagonal (ref)")

if (has_perc_fine) m <- m |> hideGroup("Percepción")

# Leyenda
m <- m |> addLegend(pal = pal_shop, values = values(rl_shop),
  title = "Hurto comercio<br/>(log co-kriging)", position = "bottomright")

saveWidget(m, "mapa_cokriging_metro.html", selfcontained = FALSE)
cat("Mapa guardado: mapa_cokriging_metro.html\n")

# ── 8. GUARDAR ───────────────────────────────────────────────────────────────
saveRDS(hex_grid, "data/hex_grid_metro.rds")
saveRDS(grid_fine, "data/grid_fine_metro.rds")
cat("Grilla fina guardada: data/grid_fine_metro.rds\n")
cat("═══ COMPLETADO ═══\n")
