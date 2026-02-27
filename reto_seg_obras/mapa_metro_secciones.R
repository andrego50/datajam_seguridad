library(sf)
library(leaflet)
library(htmlwidgets)

# 1. Leer estaciones Metro L1 (EPSG:6247 - MAGNA-SIRGAS Origen Bogotá)
est <- st_read("data/estaciones_metro_l1.geojson", quiet = TRUE)
st_crs(est) <- 6247

# Centroides de estaciones en WGS84
centroids <- st_centroid(est)
centroids_wgs <- st_transform(centroids, 4326)
coords <- st_coordinates(centroids_wgs)

# 2. Leer secciones censales urbanas - filtrar Bogotá
sections <- st_read(
  "~/Documents/GitHub/Impact-evaluation-peace-process/datasets/polygons/urban_rural_sections_dane_urban.gpkg",
  quiet = TRUE
)
bog <- sections[sections$dpto_ccdgo == "11" & sections$mpio_ccdgo == "001", ]

# 3. Crear línea del Metro para buffer (en EPSG:3116 para metros)
est_3116 <- st_transform(est, 3116)
centroids_3116 <- st_centroid(est_3116)

# Ordenar estaciones por número
orden <- order(as.integer(est$NUMERO))
coords_3116 <- st_coordinates(centroids_3116[orden, ])
metro_line <- st_sfc(st_linestring(coords_3116[, 1:2]), crs = 3116)

# Buffer de 1km alrededor de la línea del metro
buffer_metro <- st_buffer(metro_line, 1000)

# 4. Filtrar secciones que intersectan el buffer
bog_3116 <- st_transform(bog, 3116)
idx <- st_intersects(bog_3116, buffer_metro, sparse = FALSE)[, 1]
bog_metro <- bog[idx, ]

cat("Secciones censales cerca del Metro:", nrow(bog_metro), "\n")

# 5. Calcular total de delitos por sección para colorear
crime_cols <- c("extortion", "shoplifting", "theft", "burglary", 
                "auto_theft", "moto_theft", "murders", "arrests")
# Usar las que existan
crime_cols <- crime_cols[crime_cols %in% names(bog_metro)]
cat("Columnas de delitos encontradas:", paste(crime_cols, collapse=", "), "\n")

bog_metro$total_crimes <- rowSums(st_drop_geometry(bog_metro[, crime_cols]), na.rm = TRUE)

# 6. Transformar a WGS84 para leaflet
bog_metro_wgs <- st_transform(bog_metro, 4326)
buffer_wgs <- st_transform(buffer_metro, 4326)

# 7. Paleta de colores para delitos
pal <- colorNumeric(
  palette = "YlOrRd",
  domain = bog_metro_wgs$total_crimes
)

# 8. Popups para los polígonos (HTML rico) y labels simples
popups <- sprintf(
  "<strong>Sección: %s-%s-%s</strong><br/>Total delitos: %s<br/>Extorsión: %s | Hurto comercio: %s<br/>Hurto personas: %s | Homicidios: %s",
  bog_metro_wgs$dpto_ccdgo, bog_metro_wgs$mpio_ccdgo,
  bog_metro_wgs$secc_ccdgo,
  format(bog_metro_wgs$total_crimes, big.mark = ","),
  ifelse("extortion" %in% names(bog_metro_wgs), bog_metro_wgs$extortion, "N/A"),
  ifelse("shoplifting" %in% names(bog_metro_wgs), bog_metro_wgs$shoplifting, "N/A"),
  ifelse("theft" %in% names(bog_metro_wgs), bog_metro_wgs$theft, "N/A"),
  ifelse("murders" %in% names(bog_metro_wgs), bog_metro_wgs$murders, "N/A")
)

simple_labels <- paste0("Sec ", bog_metro_wgs$secc_ccdgo, " | Delitos: ", bog_metro_wgs$total_crimes)

# 9. Línea del metro para el mapa
metro_line_wgs <- st_transform(metro_line, 4326)
metro_coords <- st_coordinates(metro_line_wgs)

# 10. Construir mapa leaflet
m <- leaflet() |>
  addProviderTiles(providers$CartoDB.Positron) |>
  
  # Polígonos censales coloreados por total de delitos
  addPolygons(
    data = bog_metro_wgs,
    fillColor = ~pal(total_crimes),
    weight = 1,
    opacity = 0.7,
    color = "#555",
    fillOpacity = 0.5,
    label = simple_labels,
    popup = popups,
    highlightOptions = highlightOptions(
      weight = 3, color = "#333", fillOpacity = 0.7, bringToFront = FALSE
    ),
    group = "Secciones Censales"
  ) |>
  
  # Buffer del metro (referencia)
  addPolygons(
    data = buffer_wgs,
    fillColor = "transparent",
    weight = 2,
    opacity = 0.5,
    color = "#2196F3",
    dashArray = "5,5",
    group = "Buffer 1km Metro"
  ) |>
  
  # Línea del metro
  addPolylines(
    lng = coords[orden, 1], lat = coords[orden, 2],
    color = "#1565C0", weight = 4, opacity = 0.9,
    group = "Línea Metro L1"
  ) |>
  
  # Estaciones del metro
  addCircleMarkers(
    lng = coords[, 1], lat = coords[, 2],
    radius = 7, color = "#D32F2F", fillColor = "#F44336",
    fillOpacity = 0.9, weight = 2,
    label = as.character(paste0(est$NOMBRE, " - ", est$RefName)),
    group = "Estaciones Metro"
  ) |>
  
  # Nombres de estaciones
  addLabelOnlyMarkers(
    lng = coords[, 1], lat = coords[, 2],
    label = as.character(est$NOMBRE),
    labelOptions = labelOptions(
      noHide = TRUE, direction = "top",
      style = list("font-size" = "10px", "font-weight" = "bold",
                    "color" = "#1565C0"),
      offset = c(0, -12)
    ),
    group = "Etiquetas"
  ) |>
  
  # Leyenda
  addLegend(
    pal = pal, values = bog_metro_wgs$total_crimes,
    title = "Total delitos<br/>(2012-2023)",
    position = "bottomright"
  ) |>
  
  # Control de capas
  addLayersControl(
    overlayGroups = c("Secciones Censales", "Buffer 1km Metro", 
                      "Línea Metro L1", "Estaciones Metro", "Etiquetas"),
    options = layersControlOptions(collapsed = FALSE)
  )

# 11. Guardar
saveWidget(m, "mapa_metro_secciones.html", selfcontained = FALSE)
cat("Mapa guardado: mapa_metro_secciones.html\n")
