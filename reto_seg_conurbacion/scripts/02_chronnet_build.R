# ==============================================================================
# 02_chronnet_build.R - Construir ChroNNets para TODOS los delitos y operativos
#
# Centinelas Rosaristas - Reto 3: Seguridad Integral Region Metropolitana
# Usa SOLO pares (cell, t) — sin datos espaciales.
# Genera una ChroNNet por cada capa (8 delitos + 3 operativos = 11 redes).
# ==============================================================================

library(igraph)
library(plyr)
library(dplyr)
library(zoo)

# --- Rutas ---
PROC_DIR     <- file.path(getwd(), "data", "processed")
CHRONNET_DIR <- file.path(getwd(), "output", "chronnets")
dir.create(CHRONNET_DIR, recursive = TRUE, showWarnings = FALSE)

# Cargar funciones ChroNNet (Ferreira et al., 2020)
CHRONNETS_SRC <- file.path(dirname(getwd()), "..", "chronnets_ref", "code",
                           "chronnets.R")
if (!file.exists(CHRONNETS_SRC)) {
  stop("No se encuentra chronnets.R en: ", CHRONNETS_SRC,
       "\nClona el repo: git clone https://github.com/lnferreira/chronnets.git chronnets_ref")
}
source(CHRONNETS_SRC)

# --- Configuracion ---
NUM_CORES <- 4
cat("Usando", NUM_CORES, "cores\n")

# ==============================================================================
# Todas las capas: 8 delitos + 3 operativos
# ==============================================================================

capas <- c(
  # Delitos
  "extorsion", "hurto_comercio", "hurto_personas", "lesiones",
  "hurto_autos", "homicidios", "hurto_motos", "hurto_residencias",
  # Operativos de policia
  "capturas", "allanamientos", "incautaciones"
)

# ==============================================================================
# Funcion para construir UNA ChroNNet — solo usa (cell, t), sin espacial
# ==============================================================================

construir_chronnet <- function(nombre_capa, proc_dir, out_dir, num_cores) {
  cat("\n===", toupper(nombre_capa), "===\n")

  # Cargar datos del spatial join
  rds_path <- file.path(proc_dir, paste0("siedco_", nombre_capa, ".rds"))
  if (!file.exists(rds_path)) {
    cat("  Archivo no encontrado:", rds_path, "\n")
    return(NULL)
  }

  df <- readRDS(rds_path)
  cat("  Eventos:", nrow(df), "\n")
  cat("  Secciones unicas:", n_distinct(df$cell), "\n")
  cat("  Semanas unicas:", n_distinct(df$t), "\n")

  # Agregar a pares unicos (cell, t) y mapear t a secuencia continua
  semanas_unicas <- sort(unique(df$t))
  semana_map <- setNames(seq_along(semanas_unicas), semanas_unicas)
  df$t_seq <- semana_map[as.character(df$t)]

  # Input para chronnet_create: solo columnas t y cell (enteros)
  chronnet_input <- df %>%
    dplyr::distinct(cell, t_seq) %>%
    dplyr::select(t = t_seq, cell) %>%
    as.data.frame()

  cat("  Pares unicos (cell, t):", nrow(chronnet_input), "\n")
  cat("  Rango temporal: semana", min(chronnet_input$t),
      "a", max(chronnet_input$t), "\n")

  # Construir ChroNNet — solo usa IDs de celdas, sin coordenadas
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

  # Metricas basicas de la red cruda
  cat("  Nodos:", vcount(net), "\n")
  cat("  Aristas:", ecount(net), "\n")
  cat("  Grado medio:", round(mean(degree(net)), 2), "\n")
  cat("  Densidad:", round(edge_density(net), 6), "\n")

  # Podar aristas debiles (peso <= 1 = co-ocurrencia casual)
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

  # Guardar resultado (sin comunidades — se detectan en script aparte)
  resultado <- list(
    capa        = nombre_capa,
    red_cruda   = net,
    red_podada  = net_pruned,
    semana_map  = semana_map,
    metricas    = list(
      nodos_cruda    = vcount(net),
      aristas_cruda  = ecount(net),
      nodos_podada   = vcount(net_pruned),
      aristas_podada = ecount(net_pruned),
      grado_medio    = mean(degree(net)),
      densidad       = edge_density(net)
    )
  )

  out_path <- file.path(out_dir, paste0("chronnet_", nombre_capa, ".rds"))
  saveRDS(resultado, out_path)
  cat("  Guardado:", out_path, "\n")

  return(resultado)
}

# ==============================================================================
# Construir ChroNNet para cada capa
# ==============================================================================

resultados <- list()
for (capa in capas) {
  resultados[[capa]] <- construir_chronnet(capa, PROC_DIR, CHRONNET_DIR, NUM_CORES)
  gc()
}

# ==============================================================================
# Resumen comparativo
# ==============================================================================

cat("\n\n========== RESUMEN DE CHRONNETS ==========\n")
cat(sprintf("%-20s %7s %8s %7s %8s %8s %10s\n",
            "Capa", "Nodos", "Aristas", "Podados", "AristPod",
            "GradoMed", "Densidad"))
cat(paste(rep("-", 75), collapse = ""), "\n")

for (nombre in names(resultados)) {
  r <- resultados[[nombre]]
  if (!is.null(r)) {
    m <- r$metricas
    cat(sprintf("%-20s %7d %8d %7d %8d %8.2f %10.6f\n",
                nombre, m$nodos_cruda, m$aristas_cruda,
                m$nodos_podada, m$aristas_podada,
                m$grado_medio, m$densidad))
  }
}

cat("\n=== ChroNNets construidas (11 capas) ===\n")
cat("Deteccion de comunidades: ejecutar 03_community_detection.R\n")
