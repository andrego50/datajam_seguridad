# ==============================================================================
# 03b_analisis_operativos.R - Integrar operativos al analisis multiplex
#
# Centinelas Rosaristas - Reto 3: Seguridad Integral Region Metropolitana
# Extrae metricas de las ChroNNets operativas y las integra con los delitos.
# ==============================================================================

library(igraph)
library(sf)
library(dplyr)
library(tidyr)

# --- Rutas ---
PROC_DIR     <- file.path(getwd(), "data", "processed")
CHRONNET_DIR <- file.path(getwd(), "output", "chronnets")

# --- Cargar secciones ---
cat("Cargando secciones de estudio...\n")
secciones <- st_read(file.path(PROC_DIR, "secciones_estudio.gpkg"), quiet = TRUE)

# --- Todas las capas (delitos + operativos) ---
delitos <- c("extorsion", "hurto_comercio", "hurto_personas", "lesiones",
             "hurto_autos", "homicidios", "hurto_motos", "hurto_residencias")
operativos <- c("capturas", "allanamientos", "incautaciones")
todas_capas <- c(delitos, operativos)

# ==============================================================================
# 1. Extraer metricas de nodo para operativos
# ==============================================================================

cat("\n=== Extrayendo metricas de nodo para operativos ===\n")

metricas_operativos <- list()

for (nombre in operativos) {
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

  nodos_df <- data.frame(
    cell            = V(net)$name,
    delito          = nombre,
    grado           = degree(net),
    fuerza          = strength(net),
    betweenness     = betweenness(net, weights = 1 / E(net)$weight),
    closeness       = closeness(net, weights = 1 / E(net)$weight),
    comunidad       = if (!is.null(res$comunidades))
                        membership(res$comunidades) else NA_integer_,
    stringsAsFactors = FALSE
  )

  metricas_operativos[[nombre]] <- nodos_df
  cat(sprintf("  %-20s %5d nodos con metricas\n", nombre, nrow(nodos_df)))
}

metricas_op_all <- bind_rows(metricas_operativos)
cat("\nTotal registros nodo-operativo:", nrow(metricas_op_all), "\n")

# ==============================================================================
# 2. Cargar metricas de delitos y combinar
# ==============================================================================

cat("\n=== Combinando delitos + operativos ===\n")

metricas_delitos <- readRDS(file.path(PROC_DIR, "metricas_nodos_all.rds"))
metricas_todo <- bind_rows(metricas_delitos, metricas_op_all)
cat("Total registros nodo-capa (delitos + operativos):", nrow(metricas_todo), "\n")

# ==============================================================================
# 3. Analisis multiplex ampliado
# ==============================================================================

cat("\n=== Analisis multiplex ampliado (delitos + operativos) ===\n")

multiplex_ampliado <- metricas_todo %>%
  group_by(cell) %>%
  summarise(
    n_capas        = n_distinct(delito),
    n_delitos      = sum(delito %in% delitos),
    n_operativos   = sum(delito %in% operativos),
    capas          = paste(sort(unique(delito)), collapse = "; "),
    grado_total    = sum(grado),
    fuerza_total   = sum(fuerza),
    max_between    = max(betweenness),
    .groups        = "drop"
  ) %>%
  arrange(desc(n_capas), desc(fuerza_total))

cat("Secciones por numero de capas totales:\n")
print(table(multiplex_ampliado$n_capas))

cat("\nSecciones con presencia en delitos Y operativos:\n")
ambos <- multiplex_ampliado %>% filter(n_delitos > 0 & n_operativos > 0)
cat("  Total:", nrow(ambos), "\n")

# ==============================================================================
# 4. Correlacion delitos vs operativos
# ==============================================================================

cat("\n=== Correlacion Spearman: delitos vs operativos ===\n")

matriz_grado <- metricas_todo %>%
  select(cell, delito, grado) %>%
  pivot_wider(names_from = delito, values_from = grado, values_fill = 0)

if (ncol(matriz_grado) > 2) {
  cor_full <- cor(matriz_grado[, -1], method = "spearman")
  cat("\nCorrelacion completa (delitos + operativos):\n")
  print(round(cor_full, 3))

  # Guardar
  saveRDS(cor_full, file.path(PROC_DIR, "correlacion_capas_completa.rds"))

  # Extraer correlaciones delito-operativo
  cat("\n--- Correlaciones DELITO vs OPERATIVO ---\n")
  for (op in operativos) {
    if (op %in% colnames(cor_full)) {
      cors_op <- cor_full[delitos[delitos %in% rownames(cor_full)], op]
      cors_op <- sort(cors_op, decreasing = TRUE)
      cat(sprintf("\n  %s:\n", toupper(op)))
      for (d in names(cors_op)) {
        cat(sprintf("    %-20s %.3f\n", d, cors_op[d]))
      }
    }
  }
}

# ==============================================================================
# 5. Mapear sobre secciones DANE
# ==============================================================================

cat("\n=== Mapeando multiplex ampliado sobre secciones ===\n")

secciones_ampliado <- secciones %>%
  left_join(multiplex_ampliado, by = c("secu_ccnct" = "cell")) %>%
  mutate(
    n_capas      = ifelse(is.na(n_capas), 0, n_capas),
    n_delitos    = ifelse(is.na(n_delitos), 0, n_delitos),
    n_operativos = ifelse(is.na(n_operativos), 0, n_operativos),
    grado_total  = ifelse(is.na(grado_total), 0, grado_total),
    fuerza_total = ifelse(is.na(fuerza_total), 0, fuerza_total)
  )

out_path <- file.path(PROC_DIR, "secciones_multiplex_completo.gpkg")
st_write(secciones_ampliado, out_path, delete_dsn = TRUE, quiet = TRUE)
cat("Guardado:", out_path, "\n")

# ==============================================================================
# 6. Resumen por municipio ampliado
# ==============================================================================

cat("\n=== Resumen por municipio (delitos + operativos) ===\n")

resumen_ampliado <- secciones_ampliado %>%
  st_drop_geometry() %>%
  group_by(mpio_cdpmp, es_ccb) %>%
  summarise(
    n_secciones       = n(),
    secciones_activas = sum(n_capas > 0),
    pct_activas       = round(100 * sum(n_capas > 0) / n(), 1),
    hotspots_8plus    = sum(n_capas >= 8),
    con_operativos    = sum(n_operativos > 0),
    grado_total_muni  = sum(grado_total),
    fuerza_total_muni = sum(fuerza_total),
    .groups = "drop"
  ) %>%
  arrange(desc(hotspots_8plus))

cat("\nTop 20 municipios:\n")
print(head(resumen_ampliado, 20))

# Guardar
saveRDS(resumen_ampliado, file.path(PROC_DIR, "resumen_municipios_completo.rds"))
saveRDS(metricas_op_all, file.path(PROC_DIR, "metricas_nodos_operativos.rds"))
saveRDS(multiplex_ampliado, file.path(PROC_DIR, "multiplex_ampliado.rds"))

cat("\n=== Analisis operativos integrado completado ===\n")
