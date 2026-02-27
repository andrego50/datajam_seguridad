library(sf)
library(leaflet)
library(htmlwidgets)

# ── 1. Leer estaciones Metro L1 ──────────────────────────────────────────────
est <- st_read("data/estaciones_metro_l1.geojson", quiet = TRUE)
st_crs(est) <- 6247
est_wgs <- st_transform(est, 4326)
coords <- st_coordinates(st_centroid(est_wgs))

# Ordenar por número de estación
orden <- order(as.integer(est$NUMERO))

# ── 2. Leer secciones censales urbanas — solo Bogotá ─────────────────────────
cat("Leyendo secciones censales urbanas...\n")
bog <- st_read(
  "~/Documents/GitHub/Impact-evaluation-peace-process/datasets/polygons/urban_rural_sections_dane_urban.gpkg",
  query = "SELECT * FROM urban_rural_sections_dane_urban WHERE dpto_ccdgo = '11' AND mpio_ccdgo = '001'",
  quiet = TRUE
)
cat("Secciones Bogotá cargadas:", nrow(bog), "\n")

# Transformar a WGS84
bog_wgs <- st_transform(bog, 4326)

# ── 3. Trazar línea del Metro (conectar estaciones en orden) ──────────────────
metro_line <- st_sfc(
  st_linestring(coords[orden, 1:2]),
  crs = 4326
)

# ── 4. Columnas de delitos (si existen) ───────────────────────────────────────
crime_cols <- c("extortion", "shoplifting", "theft", "burglary",
                "auto_theft", "moto_theft", "murders")
crime_cols <- crime_cols[crime_cols %in% names(bog_wgs)]

if (length(crime_cols) > 0) {
  bog_wgs$total_crimes <- rowSums(st_drop_geometry(bog_wgs[, crime_cols]), na.rm = TRUE)
  pal <- colorNumeric("YlOrRd", domain = bog_wgs$total_crimes, na.color = "#f0f0f0")
  fill_col <- ~pal(total_crimes)
  has_crimes <- TRUE
  cat("Columnas de delitos:", paste(crime_cols, collapse = ", "), "\n")
} else {
  fill_col <- "#cccccc"
  has_crimes <- FALSE
  cat("Sin columnas de delitos — polígonos en gris\n")
}

# ── 5. Popups para secciones ──────────────────────────────────────────────────
if (has_crimes) {
  popups <- sprintf(
    "<b>Sección: %s</b><br/>Total delitos: %s",
    bog_wgs$secc_ccdgo,
    format(bog_wgs$total_crimes, big.mark = ",")
  )
  labels <- paste0("Sec ", bog_wgs$secc_ccdgo, " | ", bog_wgs$total_crimes, " delitos")
} else {
  popups <- sprintf("<b>Sección: %s</b>", bog_wgs$secc_ccdgo)
  labels <- paste0("Sec ", bog_wgs$secc_ccdgo)
}

# ── 6. Construir mapa leaflet ────────────────────────────────────────────────
m <- leaflet() |>
  addProviderTiles(providers$CartoDB.Positron) |>

  # Polígonos censales de Bogotá
  addPolygons(
    data = bog_wgs,
    fillColor = fill_col,
    weight = 0.5,
    opacity = 0.6,
    color = "#888",
    fillOpacity = 0.45,
    label = labels,
    popup = popups,
    highlightOptions = highlightOptions(
      weight = 2, color = "#333", fillOpacity = 0.7, bringToFront = FALSE
    ),
    group = "Secciones Censales"
  ) |>

  # Línea del Metro L1
  addPolylines(
    data = metro_line,
    color = "#1565C0", weight = 5, opacity = 0.9,
    group = "Línea Metro L1"
  ) |>

  # Estaciones como círculos
  addCircleMarkers(
    lng = coords[, 1], lat = coords[, 2],
    radius = 7, color = "#D32F2F", fillColor = "#F44336",
    fillOpacity = 0.9, weight = 2,
    label = paste0(est$NOMBRE, " (#", est$NUMERO, ")"),
    popup = paste0("<b>", est$NOMBRE, "</b><br/>Ref: ", est$RefName,
                   "<br/>Estación #", est$NUMERO),
    group = "Estaciones Metro"
  ) |>

  # Etiquetas de estaciones
  addLabelOnlyMarkers(
    lng = coords[, 1], lat = coords[, 2],
    label = as.character(est$NOMBRE),
    labelOptions = labelOptions(
      noHide = TRUE, direction = "top",
      style = list("font-size" = "9px", "font-weight" = "bold",
                    "color" = "#1565C0"),
      offset = c(0, -12)
    ),
    group = "Etiquetas"
  ) |>

  # Control de capas
  addLayersControl(
    overlayGroups = c("Secciones Censales", "Línea Metro L1",
                      "Estaciones Metro", "Etiquetas"),
    options = layersControlOptions(collapsed = FALSE)
  )

# Agregar leyenda solo si hay delitos
if (has_crimes) {
  m <- m |> addLegend(
    pal = pal, values = bog_wgs$total_crimes,
    title = "Total delitos<br/>(2012-2023)",
    position = "bottomright"
  )
}

# ── 7. Guardar ────────────────────────────────────────────────────────────────
saveWidget(m, "mapa_bogota_metro_l1.html", selfcontained = FALSE)
cat("Mapa guardado: mapa_bogota_metro_l1.html\n")
