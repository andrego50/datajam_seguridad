# ==============================================================================
# 04b_mapas_operativos.R - Mapas leaflet de redes operativas de policia
#
# Centinelas Rosaristas - Reto 3: Seguridad Integral Region Metropolitana
# Genera mapas individuales para capturas, allanamientos e incautaciones.
# ==============================================================================

library(sf)
library(leaflet)
library(igraph)
library(dplyr)
library(htmlwidgets)

# --- Rutas ---
PROC_DIR     <- file.path(getwd(), "data", "processed")
CHRONNET_DIR <- file.path(getwd(), "output", "chronnets")
MAP_DIR      <- file.path(getwd(), "output", "maps")
dir.create(MAP_DIR, recursive = TRUE, showWarnings = FALSE)

# --- Cargar secciones ---
cat("Cargando secciones...\n")
secciones <- st_read(file.path(PROC_DIR, "secciones_estudio.gpkg"), quiet = TRUE)

# Centroides en WGS84
centroids <- st_centroid(secciones)
centroids_wgs <- st_transform(centroids, 4326)
coords <- st_coordinates(centroids_wgs)
centroid_df <- data.frame(
  cell = secciones$secu_ccnct,
  lon  = coords[, 1],
  lat  = coords[, 2],
  stringsAsFactors = FALSE
) %>% filter(!is.na(cell))

# Colores por operativo
colores <- list(
  capturas      = "#e41a1c",
  allanamientos = "#377eb8",
  incautaciones = "#4daf4a"
)

operativos <- c("capturas", "allanamientos", "incautaciones")

# Maximo de aristas a mostrar en mapa (para redes densas)
MAX_EDGES <- 500

# ==============================================================================
# Generar mapa para cada operativo
# ==============================================================================

for (nombre in operativos) {
  cat("\n===", toupper(nombre), "===\n")

  rds_path <- file.path(CHRONNET_DIR, paste0("chronnet_", nombre, ".rds"))
  if (!file.exists(rds_path)) {
    cat("  No encontrado\n")
    next
  }

  res <- readRDS(rds_path)
  net <- res$red_podada

  if (vcount(net) == 0 || ecount(net) == 0) {
    cat("  Red vacia\n")
    next
  }

  cat("  Nodos:", vcount(net), "| Aristas:", ecount(net), "\n")

  # Obtener edge list
  el <- igraph::as_data_frame(net, what = "edges")
  el$weight <- as.numeric(el$weight)

  # Para redes densas, tomar solo las top aristas por peso
  if (nrow(el) > MAX_EDGES) {
    cat("  Limitando a top", MAX_EDGES, "aristas por peso\n")
    el <- el %>% arrange(desc(weight)) %>% head(MAX_EDGES)
  }

  # Coordenadas de nodos
  el <- el %>%
    left_join(centroid_df, by = c("from" = "cell")) %>%
    rename(lon1 = lon, lat1 = lat) %>%
    left_join(centroid_df, by = c("to" = "cell")) %>%
    rename(lon2 = lon, lat2 = lat) %>%
    filter(!is.na(lon1), !is.na(lat1), !is.na(lon2), !is.na(lat2))

  cat("  Aristas con coordenadas:", nrow(el), "\n")

  if (nrow(el) == 0) {
    cat("  Sin aristas geolocalizadas\n")
    next
  }

  # Nodos unicos
  nodos_from <- el %>% select(cell = from, lon = lon1, lat = lat1)
  nodos_to   <- el %>% select(cell = to, lon = lon2, lat = lat2)
  nodos <- bind_rows(nodos_from, nodos_to) %>% distinct(cell, .keep_all = TRUE)

  # Grado en la sub-red mostrada
  nodos$grado <- sapply(nodos$cell, function(c) {
    sum(el$from == c | el$to == c)
  })

  # Crear lineas sf
  lines <- lapply(1:nrow(el), function(i) {
    st_linestring(matrix(c(el$lon1[i], el$lat1[i],
                           el$lon2[i], el$lat2[i]),
                         ncol = 2, byrow = TRUE))
  })

  edges_sf <- st_sf(
    weight = el$weight,
    geometry = st_sfc(lines, crs = 4326)
  )

  # Normalizar grosor de linea
  w_min <- min(edges_sf$weight)
  w_max <- max(edges_sf$weight)
  edges_sf$line_width <- if (w_max > w_min) {
    1 + 4 * (edges_sf$weight - w_min) / (w_max - w_min)
  } else {
    2
  }

  color <- colores[[nombre]]

  # Mapa
  m <- leaflet() %>%
    addProviderTiles(providers$CartoDB.Positron) %>%
    addPolylines(
      data    = edges_sf,
      color   = color,
      weight  = ~line_width,
      opacity = 0.6,
      label   = ~paste("Peso:", weight),
      group   = "Aristas"
    ) %>%
    addCircleMarkers(
      data    = nodos,
      lng     = ~lon,
      lat     = ~lat,
      radius  = ~pmin(3 + sqrt(grado), 12),
      color   = color,
      fillColor   = color,
      fillOpacity = 0.8,
      weight  = 1,
      label   = ~paste0("Seccion: ", cell, " | Grado: ", grado),
      group   = "Nodos"
    ) %>%
    addLayersControl(
      overlayGroups = c("Aristas", "Nodos"),
      options       = layersControlOptions(collapsed = FALSE)
    ) %>%
    addLegend(
      position = "topright",
      colors   = color,
      labels   = paste0(toupper(nombre), " (top ", nrow(el), " aristas)"),
      title    = "Red ChroNNet"
    )

  out_file <- file.path(MAP_DIR, paste0("red_", nombre, ".html"))
  saveWidget(m, out_file, selfcontained = FALSE)
  cat("  Guardado:", out_file, "\n")

  # Limpiar memoria
  rm(el, edges_sf, lines, nodos, m, net, res)
  gc()
}

cat("\n=== Mapas operativos generados ===\n")
cat("Archivos en:", MAP_DIR, "\n")
