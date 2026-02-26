# ==============================================================================
# 03_chronnet_analysis.R - Analisis de comunidades y red multiplex
#
# Centinelas Rosaristas - Reto 3: Seguridad Integral Region Metropolitana
# Extrae metricas de cada ChroNNet, identifica hotspots multi-delictivos,
# y clasifica hallazgos segun el marco multinivel.
# ==============================================================================

library(igraph)
library(sf)
library(dplyr)
library(tidyr)

# --- Rutas ---
PROC_DIR     <- file.path(getwd(), "data", "processed")
CHRONNET_DIR <- file.path(getwd(), "output", "chronnets")
OUT_DIR      <- file.path(getwd(), "output")

# --- Cargar secciones de estudio ---
cat("Cargando secciones de estudio...\n")
secciones <- st_read(file.path(PROC_DIR, "secciones_estudio.gpkg"), quiet = TRUE)
codigos_muni <- readRDS(file.path(PROC_DIR, "municipios_codigos.rds"))

# --- Lista de delitos ---
delitos <- c("extorsion", "hurto_comercio", "hurto_personas", "lesiones",
             "hurto_autos", "homicidios", "hurto_motos", "hurto_residencias")

# ==============================================================================
# 1. Extraer metricas de nodo por delito
# ==============================================================================

cat("\n=== Extrayendo metricas de nodo por delito ===\n")

metricas_nodos <- list()

for (nombre in delitos) {
  rds_path <- file.path(CHRONNET_DIR, paste0("chronnet_", nombre, ".rds"))
  if (!file.exists(rds_path)) {
    cat("  No encontrado:", nombre, "\n")
    next
  }

  res <- readRDS(rds_path)
  net <- res$red_podada

  if (vcount(net) == 0) {
    cat("  Red vacia:", nombre, "\n")
    next
  }

  # Extraer metricas por nodo
  nodos_df <- data.frame(
    cell            = V(net)$name,
    delito          = nombre,
    grado           = degree(net),
    fuerza          = strength(net),  # suma de pesos
    betweenness     = betweenness(net, weights = 1 / E(net)$weight),
    closeness       = closeness(net, weights = 1 / E(net)$weight),
    comunidad       = if (!is.null(res$comunidades))
                        membership(res$comunidades) else NA_integer_,
    stringsAsFactors = FALSE
  )

  metricas_nodos[[nombre]] <- nodos_df
  cat(sprintf("  %-20s %5d nodos con metricas\n", nombre, nrow(nodos_df)))
}

# Combinar todo
metricas_all <- bind_rows(metricas_nodos)
cat("\nTotal registros nodo-delito:", nrow(metricas_all), "\n")

# ==============================================================================
# 2. Identificar hotspots multi-delictivos
#    Secciones que aparecen como nodos fuertes en multiples redes
# ==============================================================================

cat("\n=== Analisis multiplex: hotspots multi-delictivos ===\n")

# Contar en cuantas redes aparece cada seccion
multiplex_presencia <- metricas_all %>%
  group_by(cell) %>%
  summarise(
    n_delitos     = n_distinct(delito),
    delitos       = paste(sort(unique(delito)), collapse = "; "),
    grado_total   = sum(grado),
    fuerza_total  = sum(fuerza),
    max_between   = max(betweenness),
    .groups       = "drop"
  ) %>%
  arrange(desc(n_delitos), desc(fuerza_total))

cat("Secciones por numero de delitos en los que aparecen:\n")
print(table(multiplex_presencia$n_delitos))

# Hotspots: secciones presentes en 4+ redes de delitos
hotspots <- multiplex_presencia %>%
  filter(n_delitos >= 4)

cat("\nHotspots multi-delictivos (4+ delitos):", nrow(hotspots), "\n")
if (nrow(hotspots) > 0) {
  cat("\nTop 20 hotspots:\n")
  print(head(hotspots, 20))
}

# ==============================================================================
# 3. Mapear sobre secciones DANE
# ==============================================================================

cat("\n=== Mapeando sobre secciones DANE ===\n")

# Join de multiplex con secciones
secciones_multiplex <- secciones %>%
  left_join(multiplex_presencia, by = c("secu_ccnct" = "cell"))

# Rellenar NAs (secciones sin delitos en la red)
secciones_multiplex <- secciones_multiplex %>%
  mutate(
    n_delitos    = ifelse(is.na(n_delitos), 0, n_delitos),
    grado_total  = ifelse(is.na(grado_total), 0, grado_total),
    fuerza_total = ifelse(is.na(fuerza_total), 0, fuerza_total)
  )

# Guardar geodatos con metricas multiplex
out_multi <- file.path(PROC_DIR, "secciones_multiplex.gpkg")
st_write(secciones_multiplex, out_multi, delete_dsn = TRUE, quiet = TRUE)
cat("Secciones con metricas multiplex guardadas en:", out_multi, "\n")

# ==============================================================================
# 4. Analisis por municipio
# ==============================================================================

cat("\n=== Resumen por municipio ===\n")

resumen_muni <- secciones_multiplex %>%
  st_drop_geometry() %>%
  group_by(mpio_cdpmp, es_ccb) %>%
  summarise(
    n_secciones       = n(),
    secciones_activas = sum(n_delitos > 0),
    pct_activas       = round(100 * sum(n_delitos > 0) / n(), 1),
    hotspots_4plus    = sum(n_delitos >= 4),
    grado_total_muni  = sum(grado_total),
    fuerza_total_muni = sum(fuerza_total),
    .groups = "drop"
  ) %>%
  arrange(desc(hotspots_4plus))

cat("\nTop 20 municipios por hotspots multi-delictivos:\n")
print(head(resumen_muni, 20))

# Guardar
saveRDS(resumen_muni, file.path(PROC_DIR, "resumen_municipios.rds"))

# ==============================================================================
# 5. Correlacion entre capas de la red multiplex
# ==============================================================================

cat("\n=== Correlacion entre capas del multiplex ===\n")

# Crear matriz seccion x delito con grado como valor
matriz_grado <- metricas_all %>%
  select(cell, delito, grado) %>%
  pivot_wider(names_from = delito, values_from = grado, values_fill = 0)

# Correlacion entre capas
if (ncol(matriz_grado) > 2) {
  cor_matrix <- cor(matriz_grado[, -1], method = "spearman")
  cat("\nCorrelacion de Spearman entre capas de delitos (por grado):\n")
  print(round(cor_matrix, 3))

  # Guardar
  saveRDS(cor_matrix, file.path(PROC_DIR, "correlacion_capas.rds"))
}

# ==============================================================================
# 6. Comunidades por delito - mapear a municipios
# ==============================================================================

cat("\n=== Comunidades por delito ===\n")

for (nombre in names(metricas_nodos)) {
  df_nodos <- metricas_nodos[[nombre]]
  if (is.null(df_nodos) || all(is.na(df_nodos$comunidad))) next

  # Join con secciones para obtener municipio
  df_com <- df_nodos %>%
    left_join(
      st_drop_geometry(secciones) %>% select(secu_ccnct, mpio_cdpmp),
      by = c("cell" = "secu_ccnct")
    )

  # Municipios por comunidad
  com_muni <- df_com %>%
    group_by(comunidad) %>%
    summarise(
      n_nodos    = n(),
      municipios = paste(sort(unique(mpio_cdpmp)), collapse = ", "),
      n_munis    = n_distinct(mpio_cdpmp),
      .groups    = "drop"
    ) %>%
    arrange(desc(n_nodos))

  cat(sprintf("\n  %s: %d comunidades\n", nombre, nrow(com_muni)))
  # Mostrar comunidades multi-municipales (corredores inter-jurisdiccionales)
  corredores <- com_muni %>% filter(n_munis > 1)
  if (nrow(corredores) > 0) {
    cat("  Comunidades multi-municipales (corredores):", nrow(corredores), "\n")
    print(head(corredores, 5))
  }
}

# ==============================================================================
# 7. Guardar tablas para la app Shiny
# ==============================================================================

saveRDS(metricas_all, file.path(PROC_DIR, "metricas_nodos_all.rds"))
saveRDS(multiplex_presencia, file.path(PROC_DIR, "multiplex_presencia.rds"))
saveRDS(hotspots, file.path(PROC_DIR, "hotspots_multidelictivos.rds"))

cat("\n=== Analisis completado ===\n")
