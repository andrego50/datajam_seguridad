# ==============================================================================
# 02_chronnet_build.R - Construir una ChroNNet por tipo de delito
#
# Centinelas Rosaristas - Reto 3: Seguridad Integral Region Metropolitana
# Usa el formato (cell, t) generado por 01_spatial_join.R y la funcion
# chronnet_create() del paquete chronnets (Ferreira et al., 2020).
# ==============================================================================

library(igraph)
library(dplyr)
library(plyr)
library(zoo)
library(parallel)

# --- Rutas ---
PROC_DIR     <- file.path(getwd(), "data", "processed")
CHRONNET_DIR <- file.path(getwd(), "output", "chronnets")
dir.create(CHRONNET_DIR, recursive = TRUE, showWarnings = FALSE)

# Cargar funciones ChroNNet
CHRONNETS_SRC <- file.path(dirname(getwd()), "..", "chronnets_ref", "code",
                           "chronnets.R")
if (!file.exists(CHRONNETS_SRC)) {
  stop("No se encuentra chronnets.R en: ", CHRONNETS_SRC,
       "\nClona el repo: git clone https://github.com/lnferreira/chronnets.git chronnets_ref")
}
source(CHRONNETS_SRC)

# --- Configuracion ---
NUM_CORES <- max(1, detectCores() - 2)
cat("Usando", NUM_CORES, "cores\n")

# Lista de delitos procesados
delitos <- c("extorsion", "hurto_comercio", "hurto_personas", "lesiones",
             "hurto_autos", "homicidios", "hurto_motos", "hurto_residencias")

# ==============================================================================
# Funcion para construir ChroNNet para un delito
# ==============================================================================

construir_chronnet <- function(nombre_delito, proc_dir, out_dir, num_cores) {
  cat("\n===", toupper(nombre_delito), "===\n")

  # Cargar datos del spatial join
  rds_path <- file.path(proc_dir, paste0("siedco_", nombre_delito, ".rds"))
  if (!file.exists(rds_path)) {
    cat("  Archivo no encontrado:", rds_path, "\n")
    return(NULL)
  }

  df <- readRDS(rds_path)
  cat("  Eventos:", nrow(df), "\n")
  cat("  Secciones unicas:", n_distinct(df$cell), "\n")
  cat("  Semanas unicas:", n_distinct(df$t), "\n")

  # Preparar input para chronnet_create: data.frame(cell, t)
  # t debe ser entero secuencial
  semanas_unicas <- sort(unique(df$t))
  semana_map <- setNames(seq_along(semanas_unicas), semanas_unicas)
  df$t_seq <- semana_map[as.character(df$t)]

  chronnet_input <- data.frame(
    cell = df$cell,
    t    = df$t_seq
  )

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

  # Metricas basicas
  cat("  Nodos:", vcount(net), "\n")
  cat("  Aristas:", ecount(net), "\n")
  cat("  Grado medio:", round(mean(degree(net)), 2), "\n")
  cat("  Densidad:", round(edge_density(net), 6), "\n")

  # Podar aristas debiles (peso <= 1 = coincidencia casual)
  # Umbral: al menos 2 co-ocurrencias para mantener la arista
  if (ecount(net) > 0) {
    net_pruned <- delete.edges(net, which(E(net)$weight <= 1))
    # Remover nodos aislados
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

  # Guardar resultado
  resultado <- list(
    delito      = nombre_delito,
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

  out_path <- file.path(out_dir, paste0("chronnet_", nombre_delito, ".rds"))
  saveRDS(resultado, out_path)
  cat("  Guardado:", out_path, "\n")

  return(resultado)
}

# ==============================================================================
# Construir ChroNNet para cada delito
# ==============================================================================

resultados <- list()
for (delito in delitos) {
  resultados[[delito]] <- construir_chronnet(
    delito, PROC_DIR, CHRONNET_DIR, NUM_CORES
  )
}

# ==============================================================================
# Resumen comparativo
# ==============================================================================

cat("\n\n========== RESUMEN DE CHRONNETS ==========\n")
cat(sprintf("%-20s %7s %8s %7s %8s %5s %8s\n",
            "Delito", "Nodos", "Aristas", "Podados", "AristPod",
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

cat("\n=== ChroNNets construidas ===\n")
