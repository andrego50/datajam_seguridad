# ══════════════════════════════════════════════════════════════════════════════
# CAPA 4: ENTORNO URBANO VÍA OPENSTREETMAP — Metro Línea 1
# Equipo CyberRosario — Datajam Seguridad CCB
# ══════════════════════════════════════════════════════════════════════════════

library(sf)
library(dplyr)
library(osmdata)

cat("═══ CAPA 4: ENTORNO URBANO (OSM) ═══\n\n")

# ── 1. CARGAR HEX GRID Y PREPARAR BBOX ──────────────────────────────────────
cat("1. Cargando hex_grid y preparando bbox para OSM...\n")
hex_grid <- readRDS("data/hex_grid_metro.rds")
cat("   Hexágonos:", nrow(hex_grid), "\n")

# Reconstruir buffer del metro
est <- st_read("data/estaciones_metro_l1.geojson", quiet = TRUE)
st_crs(est) <- 6247
est_3116 <- st_transform(est, 3116)
centroids_3116 <- st_centroid(est_3116)
orden <- order(as.integer(est$NUMERO))
coords_3116 <- st_coordinates(centroids_3116[orden, ])
metro_line <- st_sfc(st_linestring(coords_3116[, 1:2]), crs = 3116)
buffer_metro <- st_buffer(metro_line, 1500)

# Bbox en WGS84 para queries OSM
buffer_wgs <- st_transform(buffer_metro, 4326)
bb <- as.numeric(st_bbox(buffer_wgs))
cat("   Bbox OSM:", paste(round(bb, 4), collapse = ", "), "\n")

# ── 2. QUERY OSM: ÁREAS VERDES ──────────────────────────────────────────────
cat("\n2. Descargando áreas verdes desde OSM...\n")

verde <- tryCatch({
  # Parks, gardens, recreation areas
  q1 <- opq(bbox = bb) |>
    add_osm_feature(key = "leisure", value = c("park", "garden", "playground",
                                                "nature_reserve"))
  r1 <- osmdata_sf(q1)

  # Green land use
  q2 <- opq(bbox = bb) |>
    add_osm_feature(key = "landuse", value = c("grass", "forest", "meadow",
                                                 "recreation_ground", "village_green"))
  r2 <- osmdata_sf(q2)

  # Natural areas
  q3 <- opq(bbox = bb) |>
    add_osm_feature(key = "natural", value = c("wood", "scrub", "grassland"))
  r3 <- osmdata_sf(q3)

  # Combinar polígonos
  polys <- list()
  for (r in list(r1, r2, r3)) {
    if (!is.null(r$osm_polygons) && nrow(r$osm_polygons) > 0)
      polys <- c(polys, list(st_geometry(r$osm_polygons)))
    if (!is.null(r$osm_multipolygons) && nrow(r$osm_multipolygons) > 0)
      polys <- c(polys, list(st_geometry(r$osm_multipolygons)))
  }

  if (length(polys) > 0) {
    verde_geom <- do.call(c, polys)
    verde_sf <- st_sf(geometry = verde_geom, crs = 4326)
    verde_sf <- st_transform(verde_sf, 3116)
    verde_sf <- verde_sf[st_intersects(verde_sf, buffer_metro, sparse = FALSE)[, 1], ]
    verde_sf <- st_make_valid(verde_sf)
    cat("   Áreas verdes encontradas:", nrow(verde_sf), "\n")
    verde_sf
  } else {
    cat("   Sin áreas verdes encontradas\n")
    NULL
  }
}, error = function(e) {
  cat("   Error descargando áreas verdes:", e$message, "\n")
  NULL
})

# ── 3. QUERY OSM: EDIFICIOS ─────────────────────────────────────────────────
cat("\n3. Descargando edificios desde OSM...\n")

edificios <- tryCatch({
  q <- opq(bbox = bb, timeout = 120) |>
    add_osm_feature(key = "building")
  r <- osmdata_sf(q)

  polys <- list()
  if (!is.null(r$osm_polygons) && nrow(r$osm_polygons) > 0)
    polys <- c(polys, list(st_geometry(r$osm_polygons)))
  if (!is.null(r$osm_multipolygons) && nrow(r$osm_multipolygons) > 0)
    polys <- c(polys, list(st_geometry(r$osm_multipolygons)))

  if (length(polys) > 0) {
    edif_geom <- do.call(c, polys)
    edif_sf <- st_sf(geometry = edif_geom, crs = 4326)
    edif_sf <- st_transform(edif_sf, 3116)
    edif_sf <- edif_sf[st_intersects(edif_sf, buffer_metro, sparse = FALSE)[, 1], ]
    edif_sf <- st_make_valid(edif_sf)
    cat("   Edificios encontrados:", nrow(edif_sf), "\n")
    edif_sf
  } else {
    cat("   Sin edificios encontrados\n")
    NULL
  }
}, error = function(e) {
  cat("   Error descargando edificios:", e$message, "\n")
  NULL
})

# ── 4. QUERY OSM: RED VIAL ──────────────────────────────────────────────────
cat("\n4. Descargando red vial desde OSM...\n")

vias <- tryCatch({
  q <- opq(bbox = bb, timeout = 120) |>
    add_osm_feature(key = "highway",
                    value = c("primary", "secondary", "tertiary", "residential",
                              "living_street", "pedestrian", "footway", "cycleway",
                              "service", "unclassified"))
  r <- osmdata_sf(q)

  if (!is.null(r$osm_lines) && nrow(r$osm_lines) > 0) {
    vias_sf <- r$osm_lines[, c("highway", "geometry")]
    vias_sf <- st_transform(vias_sf, 3116)
    vias_sf <- vias_sf[st_intersects(vias_sf, buffer_metro, sparse = FALSE)[, 1], ]
    vias_sf <- st_make_valid(vias_sf)
    cat("   Segmentos viales encontrados:", nrow(vias_sf), "\n")
    vias_sf
  } else {
    cat("   Sin vías encontradas\n")
    NULL
  }
}, error = function(e) {
  cat("   Error descargando vías:", e$message, "\n")
  NULL
})

# ── 5. QUERY OSM: USO DE SUELO ──────────────────────────────────────────────
cat("\n5. Descargando uso de suelo desde OSM...\n")

uso_suelo <- tryCatch({
  q <- opq(bbox = bb) |>
    add_osm_feature(key = "landuse",
                    value = c("commercial", "retail", "industrial", "residential"))
  r <- osmdata_sf(q)

  polys <- list()
  if (!is.null(r$osm_polygons) && nrow(r$osm_polygons) > 0) {
    p <- r$osm_polygons[, c("landuse", "geometry")]
    polys <- c(polys, list(p))
  }
  if (!is.null(r$osm_multipolygons) && nrow(r$osm_multipolygons) > 0) {
    p <- r$osm_multipolygons[, c("landuse", "geometry")]
    polys <- c(polys, list(p))
  }

  if (length(polys) > 0) {
    uso_sf <- do.call(rbind, polys)
    uso_sf <- st_transform(uso_sf, 3116)
    uso_sf <- uso_sf[st_intersects(uso_sf, buffer_metro, sparse = FALSE)[, 1], ]
    uso_sf <- st_make_valid(uso_sf)
    cat("   Polígonos de uso de suelo:", nrow(uso_sf), "\n")
    if (nrow(uso_sf) > 0) {
      cat("   Tipos:", paste(table(uso_sf$landuse), collapse = ", "), "\n")
    }
    uso_sf
  } else {
    cat("   Sin uso de suelo encontrado\n")
    NULL
  }
}, error = function(e) {
  cat("   Error descargando uso de suelo:", e$message, "\n")
  NULL
})

# ── 6. CALCULAR MÉTRICAS POR HEXÁGONO ───────────────────────────────────────
cat("\n6. Calculando métricas por hexágono...\n")

hex_grid_valid <- st_make_valid(hex_grid)
hex_area <- as.numeric(st_area(hex_grid_valid[1, ]))  # área de un hexágono en m²

# 6a. Áreas verdes
if (!is.null(verde) && nrow(verde) > 0) {
  cat("   Calculando cobertura verde...\n")
  verde_union <- st_union(verde)
  hex_verde <- st_intersection(hex_grid_valid, verde_union)
  hex_verde$area_verde_m2 <- as.numeric(st_area(hex_verde))
  verde_df <- hex_verde |> st_drop_geometry() |>
    group_by(hex_id) |>
    summarise(area_verde_m2 = sum(area_verde_m2), .groups = "drop")
  hex_grid <- hex_grid |> left_join(verde_df, by = "hex_id")
  hex_grid$area_verde_m2[is.na(hex_grid$area_verde_m2)] <- 0
  hex_grid$pct_verde <- hex_grid$area_verde_m2 / hex_area
  hex_grid$pct_verde <- pmin(hex_grid$pct_verde, 1)  # cap at 1
  cat("   Pct verde promedio:", round(mean(hex_grid$pct_verde) * 100, 1), "%\n")
} else {
  hex_grid$area_verde_m2 <- 0
  hex_grid$pct_verde <- 0
  cat("   Sin datos de verde — columnas en 0\n")
}

# 6b. Edificios
if (!is.null(edificios) && nrow(edificios) > 0) {
  cat("   Calculando densidad de edificios...\n")
  # Contar edificios por hexágono (por centroide del edificio)
  edif_centroids <- st_centroid(edificios)
  edif_in_hex <- st_join(hex_grid_valid["hex_id"], edif_centroids, left = FALSE)
  edif_count <- edif_in_hex |> st_drop_geometry() |>
    count(hex_id, name = "n_edificios")
  hex_grid <- hex_grid |> left_join(edif_count, by = "hex_id")
  hex_grid$n_edificios[is.na(hex_grid$n_edificios)] <- 0

  # Área construida
  edif_union <- st_union(edificios)
  hex_edif <- tryCatch({
    int <- st_intersection(hex_grid_valid, edif_union)
    int$area_construida_m2 <- as.numeric(st_area(int))
    int |> st_drop_geometry() |>
      group_by(hex_id) |>
      summarise(area_construida_m2 = sum(area_construida_m2), .groups = "drop")
  }, error = function(e) {
    cat("   Error calculando área construida:", e$message, "\n")
    data.frame(hex_id = integer(0), area_construida_m2 = numeric(0))
  })
  hex_grid <- hex_grid |> left_join(hex_edif, by = "hex_id")
  hex_grid$area_construida_m2[is.na(hex_grid$area_construida_m2)] <- 0
  cat("   Edificios promedio por hex:", round(mean(hex_grid$n_edificios), 1), "\n")
} else {
  hex_grid$n_edificios <- 0
  hex_grid$area_construida_m2 <- 0
  cat("   Sin datos de edificios — columnas en 0\n")
}

# 6c. Red vial
if (!is.null(vias) && nrow(vias) > 0) {
  cat("   Calculando longitud de vías...\n")
  vias_clipped <- tryCatch({
    st_intersection(vias, hex_grid_valid["hex_id"])
  }, error = function(e) {
    cat("   Error recortando vías:", e$message, "\n")
    NULL
  })
  if (!is.null(vias_clipped) && nrow(vias_clipped) > 0) {
    vias_clipped$longitud_m <- as.numeric(st_length(vias_clipped))
    vias_df <- vias_clipped |> st_drop_geometry() |>
      group_by(hex_id) |>
      summarise(longitud_vias_m = sum(longitud_m), .groups = "drop")
    hex_grid <- hex_grid |> left_join(vias_df, by = "hex_id")
  }
  hex_grid$longitud_vias_m[is.na(hex_grid$longitud_vias_m)] <- 0
  cat("   Longitud vial promedio por hex:", round(mean(hex_grid$longitud_vias_m)), "m\n")
} else {
  hex_grid$longitud_vias_m <- 0
  cat("   Sin datos de vías — columna en 0\n")
}

# 6d. Uso de suelo comercial
if (!is.null(uso_suelo) && nrow(uso_suelo) > 0) {
  cat("   Calculando uso de suelo...\n")
  # Identificar hexágonos con uso comercial/retail
  uso_com <- uso_suelo[uso_suelo$landuse %in% c("commercial", "retail"), ]
  if (nrow(uso_com) > 0) {
    uso_com_union <- st_union(uso_com)
    hex_grid$uso_comercial <- as.integer(
      st_intersects(hex_grid_valid, uso_com_union, sparse = FALSE)[, 1]
    )
  } else {
    hex_grid$uso_comercial <- 0L
  }
  # Uso industrial
  uso_ind <- uso_suelo[uso_suelo$landuse == "industrial", ]
  if (nrow(uso_ind) > 0) {
    uso_ind_union <- st_union(uso_ind)
    hex_grid$uso_industrial <- as.integer(
      st_intersects(hex_grid_valid, uso_ind_union, sparse = FALSE)[, 1]
    )
  } else {
    hex_grid$uso_industrial <- 0L
  }
  # Uso residencial
  uso_res <- uso_suelo[uso_suelo$landuse == "residential", ]
  if (nrow(uso_res) > 0) {
    uso_res_union <- st_union(uso_res)
    hex_grid$uso_residencial <- as.integer(
      st_intersects(hex_grid_valid, uso_res_union, sparse = FALSE)[, 1]
    )
  } else {
    hex_grid$uso_residencial <- 0L
  }
  cat("   Comercial:", sum(hex_grid$uso_comercial),
      "| Industrial:", sum(hex_grid$uso_industrial),
      "| Residencial:", sum(hex_grid$uso_residencial), "hexágonos\n")
} else {
  hex_grid$uso_comercial <- 0L
  hex_grid$uso_industrial <- 0L
  hex_grid$uso_residencial <- 0L
  cat("   Sin datos de uso de suelo — columnas en 0\n")
}

# ── 7. RESUMEN ──────────────────────────────────────────────────────────────
cat("\n7. Resumen de variables de entorno:\n")
cat("   area_verde_m2    — rango:", round(range(hex_grid$area_verde_m2)), "\n")
cat("   pct_verde        — rango:", round(range(hex_grid$pct_verde), 3), "\n")
cat("   n_edificios      — rango:", range(hex_grid$n_edificios), "\n")
cat("   area_construida  — rango:", round(range(hex_grid$area_construida_m2)), "\n")
cat("   longitud_vias_m  — rango:", round(range(hex_grid$longitud_vias_m)), "\n")
cat("   uso_comercial    — sum:", sum(hex_grid$uso_comercial), "\n")
cat("   uso_industrial   — sum:", sum(hex_grid$uso_industrial), "\n")
cat("   uso_residencial  — sum:", sum(hex_grid$uso_residencial), "\n")

# ── 8. GUARDAR ──────────────────────────────────────────────────────────────
cat("\n8. Guardando hex_grid actualizado...\n")
saveRDS(hex_grid, "data/hex_grid_metro.rds")
cat("   Guardado: data/hex_grid_metro.rds\n")

# Liberar memoria
rm(verde, edificios, vias, uso_suelo)
gc(verbose = FALSE)

cat("\n═══ CAPA 4: ENTORNO URBANO COMPLETADO ═══\n")
