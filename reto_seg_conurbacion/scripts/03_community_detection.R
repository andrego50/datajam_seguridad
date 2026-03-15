# ==============================================================================
# 03_community_detection.R - Deteccion de comunidades con multiples algoritmos
#
# Centinelas Rosaristas - Reto 3: Seguridad Integral Region Metropolitana
# Carga cada ChroNNet generada por 02_chronnet_build.R y aplica:
#   1. Louvain
#   2. Infomap
#   3. Fast Greedy
#   4. Walktrap
# Genera tabla comparativa de modularidad y numero de comunidades.
# ==============================================================================

library(igraph)
library(dplyr)

# --- Rutas ---
CHRONNET_DIR <- file.path(getwd(), "output", "chronnets")
FIG_DIR      <- file.path(getwd(), "output", "figures")
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

# ==============================================================================
# Todas las capas
# ==============================================================================

capas <- c(
  "extorsion", "hurto_comercio", "hurto_personas", "lesiones",
  "hurto_autos", "homicidios", "hurto_motos", "hurto_residencias",
  "capturas", "allanamientos", "incautaciones"
)

# ==============================================================================
# Funcion: aplicar multiples algoritmos a una red
# ==============================================================================

detectar_comunidades <- function(net, nombre_capa) {
  cat("\n===", toupper(nombre_capa), "===\n")
  cat("  Nodos:", vcount(net), "| Aristas:", ecount(net), "\n")

  if (vcount(net) == 0 || ecount(net) == 0) {
    cat("  Red vacia, saltando\n")
    return(NULL)
  }

  resultados <- list()
  pesos <- E(net)$weight

  # --- 1. Louvain ---
  cat("  Louvain...")
  tryCatch({
    com <- cluster_louvain(net, weights = pesos)
    resultados[["Louvain"]] <- list(
      comunidades   = com,
      n_comunidades = length(unique(membership(com))),
      modularidad   = modularity(com)
    )
    cat(" Q =", round(modularity(com), 4),
        "| K =", length(unique(membership(com))), "\n")
  }, error = function(e) cat(" ERROR:", e$message, "\n"))

  # --- 2. Infomap ---
  cat("  Infomap...")
  tryCatch({
    com <- cluster_infomap(net, e.weights = pesos)
    resultados[["Infomap"]] <- list(
      comunidades   = com,
      n_comunidades = length(unique(membership(com))),
      modularidad   = modularity(net, membership(com), weights = pesos)
    )
    cat(" Q =", round(resultados[["Infomap"]]$modularidad, 4),
        "| K =", length(unique(membership(com))), "\n")
  }, error = function(e) cat(" ERROR:", e$message, "\n"))

  # --- 3. Fast Greedy ---
  cat("  Fast Greedy...")
  tryCatch({
    # Fast Greedy requiere grafo simple y conexo
    net_simple <- simplify(net)
    comps <- components(net_simple)
    giant <- induced_subgraph(net_simple,
                              which(comps$membership == which.max(comps$csize)))
    if (vcount(giant) > 1 && ecount(giant) > 0) {
      com <- cluster_fast_greedy(giant, weights = E(giant)$weight)
      mod_val <- modularity(com)
      resultados[["Fast_Greedy"]] <- list(
        comunidades   = com,
        n_comunidades = length(unique(membership(com))),
        modularidad   = mod_val,
        nota          = paste0("componente gigante: ", vcount(giant), " nodos")
      )
      cat(" Q =", round(mod_val, 4),
          "| K =", length(unique(membership(com))),
          "(comp. gigante:", vcount(giant), "nodos)\n")
    } else {
      cat(" componente gigante muy pequeno\n")
    }
  }, error = function(e) cat(" ERROR:", e$message, "\n"))

  # --- 4. Walktrap ---
  cat("  Walktrap...")
  tryCatch({
    com <- cluster_walktrap(net, weights = pesos, steps = 4)
    com_cut <- cut_at(com, no = which.max(com$modularity))
    mod_val <- modularity(net, com_cut, weights = pesos)
    n_com <- length(unique(com_cut))
    # Si el corte optimo no funciona bien, usar el membership directo
    if (n_com <= 1) {
      com_membership <- membership(com)
      mod_val <- modularity(net, com_membership, weights = pesos)
      n_com <- length(unique(com_membership))
    }
    resultados[["Walktrap"]] <- list(
      comunidades   = com,
      n_comunidades = n_com,
      modularidad   = mod_val
    )
    cat(" Q =", round(mod_val, 4), "| K =", n_com, "\n")
  }, error = function(e) cat(" ERROR:", e$message, "\n"))

  return(resultados)
}

# ==============================================================================
# Ejecutar deteccion en todas las capas
# ==============================================================================

todos_resultados <- list()
tabla_comparativa <- data.frame()
tabla_componentes <- data.frame()

# ==============================================================================
# Paso 1: Diagnostico de componentes de cada red
# ==============================================================================

cat("\n\n================================================================\n")
cat("       DIAGNOSTICO DE COMPONENTES POR CAPA\n")
cat("================================================================\n\n")

cat(sprintf("%-20s %7s %8s %8s %10s %10s\n",
            "Capa", "Nodos", "Aristas", "Comps", "Gigante", "% Gigante"))
cat(paste(rep("-", 67), collapse = ""), "\n")

for (capa in capas) {
  rds_path <- file.path(CHRONNET_DIR, paste0("chronnet_", capa, ".rds"))
  if (!file.exists(rds_path)) next

  res <- readRDS(rds_path)
  net <- res$red_podada

  if (vcount(net) == 0) {
    cat(sprintf("%-20s %7d %8d %8s %10s %10s\n",
                capa, 0, 0, "-", "-", "-"))
    next
  }

  comps <- components(net)
  n_comps <- comps$no
  giant_size <- max(comps$csize)
  pct_giant <- round(100 * giant_size / vcount(net), 1)

  tabla_componentes <- rbind(tabla_componentes, data.frame(
    Capa            = capa,
    Nodos           = vcount(net),
    Aristas         = ecount(net),
    Componentes     = n_comps,
    Nodos_Gigante   = giant_size,
    Pct_Gigante     = pct_giant,
    stringsAsFactors = FALSE
  ))

  cat(sprintf("%-20s %7d %8d %8d %10d %9.1f%%\n",
              capa, vcount(net), ecount(net), n_comps, giant_size, pct_giant))
}

cat("\n")

# ==============================================================================
# Paso 2: Deteccion de comunidades
# ==============================================================================

for (capa in capas) {
  rds_path <- file.path(CHRONNET_DIR, paste0("chronnet_", capa, ".rds"))
  if (!file.exists(rds_path)) {
    cat("\nNo encontrado:", rds_path, "\n")
    next
  }

  res <- readRDS(rds_path)
  net <- res$red_podada

  comunidades <- detectar_comunidades(net, capa)
  todos_resultados[[capa]] <- comunidades

  # Agregar a tabla comparativa
  if (!is.null(comunidades)) {
    for (algo in names(comunidades)) {
      tabla_comparativa <- rbind(tabla_comparativa, data.frame(
        Capa         = capa,
        Algoritmo    = algo,
        Comunidades  = comunidades[[algo]]$n_comunidades,
        Modularidad  = round(comunidades[[algo]]$modularidad, 4),
        stringsAsFactors = FALSE
      ))
    }
  }

  # Guardar comunidades junto con la ChroNNet
  res$comunidades <- comunidades
  saveRDS(res, rds_path)

  gc()
}

# ==============================================================================
# Tabla comparativa
# ==============================================================================

cat("\n\n")
cat("================================================================\n")
cat("       TABLA COMPARATIVA DE DETECCION DE COMUNIDADES\n")
cat("================================================================\n\n")

cat(sprintf("%-20s %-14s %12s %12s\n",
            "Capa", "Algoritmo", "Comunidades", "Modularidad"))
cat(paste(rep("-", 62), collapse = ""), "\n")

for (i in seq_len(nrow(tabla_comparativa))) {
  r <- tabla_comparativa[i, ]
  cat(sprintf("%-20s %-14s %12d %12.4f\n",
              r$Capa, r$Algoritmo, r$Comunidades, r$Modularidad))
}

# ==============================================================================
# Mejor algoritmo por capa
# ==============================================================================

cat("\n\n--- MEJOR ALGORITMO POR CAPA (mayor modularidad) ---\n\n")

mejores <- tabla_comparativa %>%
  group_by(Capa) %>%
  slice_max(Modularidad, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  arrange(desc(Modularidad))

cat(sprintf("%-20s %-14s %12s %12s\n",
            "Capa", "Mejor Algo", "Comunidades", "Modularidad"))
cat(paste(rep("-", 62), collapse = ""), "\n")

for (i in seq_len(nrow(mejores))) {
  r <- mejores[i, ]
  cat(sprintf("%-20s %-14s %12d %12.4f\n",
              r$Capa, r$Algoritmo, r$Comunidades, r$Modularidad))
}

# Guardar tablas
saveRDS(tabla_comparativa,
        file.path(CHRONNET_DIR, "tabla_comparativa_comunidades.rds"))
write.csv(tabla_comparativa,
          file.path(CHRONNET_DIR, "tabla_comparativa_comunidades.csv"),
          row.names = FALSE)
saveRDS(tabla_componentes,
        file.path(CHRONNET_DIR, "tabla_componentes.rds"))
write.csv(tabla_componentes,
          file.path(CHRONNET_DIR, "tabla_componentes.csv"),
          row.names = FALSE)

cat("\n\nTablas guardadas en:\n")
cat("  ", file.path(CHRONNET_DIR, "tabla_comparativa_comunidades.csv"), "\n")
cat("  ", file.path(CHRONNET_DIR, "tabla_componentes.csv"), "\n")

cat("\n=== Deteccion de comunidades completada ===\n")
