# ==============================================================================
# 02b_chronnet_build_operativos.R - ChroNNets para datos operativos de policia
#
# Centinelas Rosaristas - Reto 3: Seguridad Integral Region Metropolitana
# Construye ChroNNets para capturas, allanamientos e incautaciones.
# ==============================================================================

library(igraph)
library(plyr)
library(dplyr)
library(zoo)

# --- Rutas ---
PROC_DIR     <- file.path(getwd(), "data", "processed")
CHRONNET_DIR <- file.path(getwd(), "output", "chronnets")
dir.create(CHRONNET_DIR, recursive = TRUE, showWarnings = FALSE)

# Cargar funciones ChroNNet
CHRONNETS_SRC <- file.path(dirname(getwd()), "..", "chronnets_ref", "code",
                           "chronnets.R")
source(CHRONNETS_SRC)

# --- Configuracion ---
NUM_CORES <- 2
cat("Usando", NUM_CORES, "cores\n")

# Operativos a procesar
operativos <- c("capturas", "allanamientos", "incautaciones")

# ==============================================================================
# Funcion para construir ChroNNet (misma que 02)
# ==============================================================================

construir_chronnet <- function(nombre, proc_dir, out_dir, num_cores) {
  cat("\n===", toupper(nombre), "===\n")

  rds_path <- file.path(proc_dir, paste0("siedco_", nombre, ".rds"))
  if (!file.exists(rds_path)) {
    cat("  Archivo no encontrado:", rds_path, "\n")
    return(NULL)
  }

  df <- readRDS(rds_path)
  cat("  Eventos:", nrow(df), "\n")
  cat("  Secciones unicas:", dplyr::n_distinct(df$cell), "\n")
  cat("  Semanas unicas:", dplyr::n_distinct(df$t), "\n")

  # Agregar a pares unicos (cell, t) y mapear t secuencial
  semanas_unicas <- sort(unique(df$t))
  semana_map <- setNames(seq_along(semanas_unicas), semanas_unicas)
  df$t_seq <- semana_map[as.character(df$t)]

  chronnet_input <- df %>%
    dplyr::distinct(cell, t_seq) %>%
    dplyr::select(t = t_seq, cell) %>%
    as.data.frame()

  cat("  Pares unicos (cell, t):", nrow(chronnet_input), "\n")
  cat("  Rango temporal: semana", min(chronnet_input$t),
      "a", max(chronnet_input$t), "\n")

  # Construir ChroNNet
  cat("  Construyendo ChroNNet...\n")
  t0 <- Sys.time()
  net <- chronnet_create(
    dataset    = chronnet_input,
    self_loops = FALSE,
    mode       = "undirected",
    num_cores  = num_cores
  )
  t1 <- Sys.time()
  cat("  Tiempo:", round(difftime(t1, t0, units = "secs"), 1), "segundos\n")

  cat("  Nodos:", vcount(net), "\n")
  cat("  Aristas:", ecount(net), "\n")
  cat("  Grado medio:", round(mean(degree(net)), 2), "\n")
  cat("  Densidad:", round(edge_density(net), 6), "\n")

  # Podar aristas debiles (peso <= 1)
  if (ecount(net) > 0) {
    net_pruned <- delete.edges(net, which(E(net)$weight <= 1))
    net_pruned <- delete.vertices(net_pruned,
                                  which(degree(net_pruned) == 0))
    cat("  Despues de poda (peso > 1):\n")
    cat("    Nodos:", vcount(net_pruned), "\n")
    cat("    Aristas:", ecount(net_pruned), "\n")
  } else {
    net_pruned <- net
  }

  # Detectar comunidades (Louvain)
  if (vcount(net_pruned) > 0 && ecount(net_pruned) > 0) {
    cat("  Detectando comunidades (Louvain)...\n")
    comunidades <- cluster_louvain(net_pruned, weights = E(net_pruned)$weight)
    cat("  Comunidades encontradas:", length(unique(membership(comunidades))), "\n")
    cat("  Modularidad:", round(modularity(comunidades), 4), "\n")
  } else {
    comunidades <- NULL
    cat("  Red vacia despues de poda, sin comunidades\n")
  }

  resultado <- list(
    delito      = nombre,
    red_cruda   = net,
    red_podada  = net_pruned,
    comunidades = comunidades,
    semana_map  = semana_map,
    metricas    = list(
      nodos_cruda    = vcount(net),
      aristas_cruda  = ecount(net),
      nodos_podada   = vcount(net_pruned),
      aristas_podada = ecount(net_pruned),
      grado_medio    = mean(degree(net)),
      densidad       = edge_density(net),
      n_comunidades  = ifelse(!is.null(comunidades),
                              length(unique(membership(comunidades))), 0),
      modularidad    = ifelse(!is.null(comunidades),
                              modularity(comunidades), NA)
    )
  )

  out_path <- file.path(out_dir, paste0("chronnet_", nombre, ".rds"))
  saveRDS(resultado, out_path)
  cat("  Guardado:", out_path, "\n")

  return(resultado)
}

# ==============================================================================
# Construir ChroNNet para cada operativo
# ==============================================================================

resultados <- list()
for (op in operativos) {
  resultados[[op]] <- construir_chronnet(op, PROC_DIR, CHRONNET_DIR, NUM_CORES)
  gc()
}

# ==============================================================================
# Resumen comparativo
# ==============================================================================

cat("\n\n========== RESUMEN CHRONNETS OPERATIVOS ==========\n")
cat(sprintf("%-20s %7s %8s %7s %8s %5s %8s\n",
            "Operativo", "Nodos", "Aristas", "Podados", "AristPod",
            "Comun", "Modul"))
cat(paste(rep("-", 70), collapse = ""), "\n")

for (nombre in names(resultados)) {
  r <- resultados[[nombre]]
  if (!is.null(r)) {
    m <- r$metricas
    cat(sprintf("%-20s %7d %8d %7d %8d %5d %8.4f\n",
                nombre, m$nodos_cruda, m$aristas_cruda,
                m$nodos_podada, m$aristas_podada,
                m$n_comunidades, m$modularidad))
  }
}

cat("\n=== ChroNNets operativos construidas ===\n")
