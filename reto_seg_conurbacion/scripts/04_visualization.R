# ==============================================================================
# 04_visualization.R - Mapas leaflet y graficos de ChroNNets
#
# Centinelas Rosaristas - Reto 3: Seguridad Integral Region Metropolitana
# Genera mapas interactivos de comunidades, hotspots multiplex y corredores.
# ==============================================================================

library(sf)
library(leaflet)
library(igraph)
library(dplyr)
library(htmlwidgets)
library(RColorBrewer)

# --- Rutas ---
PROC_DIR     <- file.path(getwd(), "data", "processed")
CHRONNET_DIR <- file.path(getwd(), "output", "chronnets")
MAP_DIR      <- file.path(getwd(), "output", "maps")
FIG_DIR      <- file.path(getwd(), "output", "figures")
dir.create(MAP_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

# --- Cargar datos ---
cat("Cargando datos procesados...\n")
secciones_multi <- st_read(file.path(PROC_DIR, "secciones_multiplex.gpkg"),
                           quiet = TRUE)
municipios      <- st_read(file.path(PROC_DIR, "municipios_estudio.gpkg"),
                           quiet = TRUE)
metricas_all    <- readRDS(file.path(PROC_DIR, "metricas_nodos_all.rds"))
hotspots        <- readRDS(file.path(PROC_DIR, "hotspots_multidelictivos.rds"))
cor_matrix      <- readRDS(file.path(PROC_DIR, "correlacion_capas.rds"))

# Transformar a WGS84 para leaflet
secciones_wgs <- st_transform(secciones_multi, 4326)
municipios_wgs <- st_transform(municipios, 4326)

delitos <- c("extorsion", "hurto_comercio", "hurto_personas", "lesiones",
             "hurto_autos", "homicidios", "hurto_motos", "hurto_residencias")

# ==============================================================================
# 1. Mapa de hotspots multi-delictivos
# ==============================================================================

cat("Generando mapa de hotspots multiplex...\n")

pal_multi <- colorNumeric(
  palette = "YlOrRd",
  domain  = secciones_wgs$n_delitos,
  na.color = "transparent"
)

map_multiplex <- leaflet(secciones_wgs) %>%
  addProviderTiles(providers$CartoDB.DarkMatter) %>%
  # Limites municipales
  addPolygons(
    data        = municipios_wgs,
    fillColor   = "transparent",
    color       = "#ffffff",
    weight      = 1.5,
    opacity     = 0.6,
    label       = ~mpio_cdpmp,
    group       = "Municipios"
  ) %>%
  # Secciones coloreadas por n_delitos
  addPolygons(
    fillColor   = ~pal_multi(n_delitos),
    fillOpacity = 0.7,
    color       = "#333333",
    weight      = 0.3,
    opacity     = 0.5,
    label       = ~paste0("Seccion: ", secu_ccnct,
                          " | Delitos: ", n_delitos,
                          " | Fuerza: ", round(fuerza_total, 0)),
    group       = "Hotspots multiplex"
  ) %>%
  addLegend(
    pal      = pal_multi,
    values   = ~n_delitos,
    title    = "N delitos en red",
    position = "bottomright"
  ) %>%
  addLayersControl(
    overlayGroups = c("Municipios", "Hotspots multiplex"),
    options       = layersControlOptions(collapsed = FALSE)
  )

saveWidget(map_multiplex,
           file.path(MAP_DIR, "mapa_hotspots_multiplex.html"),
           selfcontained = TRUE)
cat("  Guardado: mapa_hotspots_multiplex.html\n")

# ==============================================================================
# 2. Mapas de comunidades por delito
# ==============================================================================

cat("Generando mapas de comunidades por delito...\n")

for (nombre in delitos) {
  rds_path <- file.path(CHRONNET_DIR, paste0("chronnet_", nombre, ".rds"))
  if (!file.exists(rds_path)) next

  res <- readRDS(rds_path)
  if (is.null(res$comunidades)) next

  # Obtener membership
  mem <- data.frame(
    cell      = V(res$red_podada)$name,
    comunidad = as.integer(membership(res$comunidades)),
    grado     = degree(res$red_podada),
    stringsAsFactors = FALSE
  )

  # Join con secciones
  secc_com <- secciones_wgs %>%
    left_join(mem, by = c("secu_ccnct" = "cell"))

  # Solo secciones con comunidad asignada
  secc_activas <- secc_com %>% filter(!is.na(comunidad))

  if (nrow(secc_activas) == 0) next

  n_com <- n_distinct(secc_activas$comunidad)
  pal_com <- colorFactor(
    palette = if (n_com <= 12) "Set3" else "Spectral",
    domain  = secc_activas$comunidad
  )

  map_com <- leaflet(secc_activas) %>%
    addProviderTiles(providers$CartoDB.Positron) %>%
    addPolygons(
      data      = municipios_wgs,
      fillColor = "transparent",
      color     = "#666666",
      weight    = 1.5,
      opacity   = 0.6,
      group     = "Municipios"
    ) %>%
    addPolygons(
      fillColor   = ~pal_com(comunidad),
      fillOpacity = 0.7,
      color       = "#333333",
      weight      = 0.3,
      label       = ~paste0("Comunidad: ", comunidad,
                            " | Grado: ", grado,
                            " | Mpio: ", mpio_cdpmp),
      group       = nombre
    ) %>%
    addLegend(
      pal    = pal_com,
      values = ~comunidad,
      title  = paste("Comunidades\n", nombre),
      position = "bottomright"
    )

  saveWidget(map_com,
             file.path(MAP_DIR, paste0("mapa_comunidades_", nombre, ".html")),
             selfcontained = TRUE)
  cat("  Guardado: mapa_comunidades_", nombre, ".html\n")
}

# ==============================================================================
# 3. Grafico de distribucion de grado por delito
# ==============================================================================

cat("Generando graficos de distribucion de grado...\n")

png(file.path(FIG_DIR, "distribucion_grado.png"),
    width = 1200, height = 800, res = 150)
par(mfrow = c(2, 4), mar = c(4, 4, 2, 1))

for (nombre in delitos) {
  rds_path <- file.path(CHRONNET_DIR, paste0("chronnet_", nombre, ".rds"))
  if (!file.exists(rds_path)) {
    plot.new()
    next
  }
  res <- readRDS(rds_path)
  net <- res$red_podada
  if (vcount(net) == 0) {
    plot.new()
    next
  }
  deg <- degree(net)
  hist(deg, breaks = 30, col = "steelblue", border = "white",
       main = nombre, xlab = "Grado", ylab = "Frecuencia")
}
dev.off()
cat("  Guardado: distribucion_grado.png\n")

# ==============================================================================
# 4. Heatmap de correlacion entre capas
# ==============================================================================

cat("Generando heatmap de correlacion...\n")

png(file.path(FIG_DIR, "correlacion_capas.png"),
    width = 800, height = 700, res = 150)
par(mar = c(8, 8, 2, 2))

n <- nrow(cor_matrix)
image(1:n, 1:n, cor_matrix,
      axes = FALSE, xlab = "", ylab = "",
      col = colorRampPalette(c("#2166AC", "white", "#B2182B"))(100))

axis(1, at = 1:n, labels = rownames(cor_matrix), las = 2, cex.axis = 0.7)
axis(2, at = 1:n, labels = colnames(cor_matrix), las = 2, cex.axis = 0.7)

# Agregar valores
for (i in 1:n) {
  for (j in 1:n) {
    text(i, j, round(cor_matrix[i, j], 2), cex = 0.6)
  }
}
title("Correlacion Spearman entre capas ChroNNet")
dev.off()
cat("  Guardado: correlacion_capas.png\n")

# ==============================================================================
# 5. Resumen
# ==============================================================================

cat("\n=== Visualizaciones generadas ===\n")
cat("Mapas en:", MAP_DIR, "\n")
cat("Figuras en:", FIG_DIR, "\n")
cat("Archivos:\n")
cat(paste(" ", list.files(MAP_DIR)), sep = "\n")
cat(paste(" ", list.files(FIG_DIR)), sep = "\n")
