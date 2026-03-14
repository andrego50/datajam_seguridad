# ==============================================================================
# 01b_spatial_join_operativos.R - Datos operativos de policia (capturas,
# allanamientos, incautaciones) asignados a secciones censales por semana
#
# Centinelas Rosaristas - Reto 3: Seguridad Integral Region Metropolitana
# Misma logica que 01_spatial_join.R pero para datos operativos SIEDCO.
# ==============================================================================

library(sf)
library(dplyr)
library(lubridate)
library(readr)

# --- Rutas ---
SIEDCO_DIR <- file.path(dirname(getwd()),
                        "..", "Impact-evaluation-peace-process", "datasets")
PROC_DIR   <- file.path(getwd(), "data", "processed")

# --- Cargar secciones y bbox (ya generados por 00_setup.R) ---
cat("Cargando secciones de estudio...\n")
secciones <- st_read(file.path(PROC_DIR, "secciones_estudio.gpkg"), quiet = TRUE)
bbox <- readRDS(file.path(PROC_DIR, "bbox_estudio.rds"))

cat("Secciones:", nrow(secciones), "\n")
cat("Bbox:", paste(round(bbox, 4), collapse = ", "), "\n")

# --- Archivos operativos a procesar ---
operativos <- list(
  capturas       = file.path(SIEDCO_DIR, "arrest", "arrests.csv"),
  allanamientos  = file.path(SIEDCO_DIR, "arrest", "raids.csv"),
  incautaciones  = file.path(SIEDCO_DIR, "arrest", "seizures.csv")
)

# ==============================================================================
# Funcion para procesar un archivo operativo SIEDCO
# ==============================================================================

procesar_operativo <- function(filepath, nombre, secciones, bbox) {
  cat("\n===", toupper(nombre), "===\n")
  cat("Leyendo:", basename(filepath), "...\n")

  # Detectar separador decimal
  primera_linea <- readLines(filepath, n = 2)[2]
  usa_coma_decimal <- grepl("[0-9],[0-9]", primera_linea) &&
                      !grepl("[0-9]\\.[0-9]", primera_linea)

  if (usa_coma_decimal) {
    df <- read_delim(filepath, delim = ";", show_col_types = FALSE,
                     col_types = cols(lat_var = col_character(),
                                      lon_var = col_character(),
                                      .default = col_guess()))
    df$lat_var <- as.numeric(gsub(",", ".", df$lat_var))
    df$lon_var <- as.numeric(gsub(",", ".", df$lon_var))
    cat("  (Formato: coma como decimal)\n")
  } else {
    df <- read_delim(filepath, delim = ";", show_col_types = FALSE)
    cat("  (Formato: punto como decimal)\n")
  }

  cat("  Registros totales:", nrow(df), "\n")

  if (!("lat_var" %in% names(df) && "lon_var" %in% names(df))) {
    cat("  ERROR: No se encontraron columnas lat_var/lon_var\n")
    return(NULL)
  }

  # Asegurar numerico
  if (is.character(df$lat_var)) {
    df$lat_var <- as.numeric(gsub(",", ".", df$lat_var))
  }
  if (is.character(df$lon_var)) {
    df$lon_var <- as.numeric(gsub(",", ".", df$lon_var))
  }

  # Filtrar NAs y coordenadas invalidas
  df <- df %>% filter(!is.na(lat_var), !is.na(lon_var),
                       lat_var != 0, lon_var != 0)

  # Filtrar por bounding box
  df <- df %>%
    filter(
      lon_var >= bbox["xmin"] - 0.1,
      lon_var <= bbox["xmax"] + 0.1,
      lat_var >= bbox["ymin"] - 0.1,
      lat_var <= bbox["ymax"] + 0.1
    )
  cat("  Despues de filtro bbox:", nrow(df), "\n")

  if (nrow(df) == 0) {
    cat("  Sin registros en el area de estudio\n")
    return(NULL)
  }

  # Parsear fecha — baseline unificado desde 2021
  FECHA_MIN <- as.Date("2021-01-01")
  ANIO_BASE <- 2021L

  df <- df %>%
    mutate(
      fecha = dmy(date_var),
      anio  = year(fecha),
      semana_iso = isoweek(fecha),
      t = as.integer((anio - ANIO_BASE) * 52 + semana_iso)
    ) %>%
    filter(!is.na(fecha), fecha >= FECHA_MIN)

  cat("  Rango de fechas:", as.character(min(df$fecha)),
      "a", as.character(max(df$fecha)), "\n")

  # Convertir a sf
  puntos <- st_as_sf(df, coords = c("lon_var", "lat_var"), crs = 4686)

  # Spatial join contra secciones DANE
  cat("  Haciendo spatial join...\n")
  joined <- st_join(puntos, secciones[, c("secu_ccnct", "mpio_cdpmp", "es_ccb")],
                    join = st_within)

  joined <- joined %>%
    filter(!is.na(secu_ccnct)) %>%
    st_drop_geometry()

  cat("  Asignados a secciones:", nrow(joined), "\n")

  # Crear tabla para ChroNNet: cell + t
  chronnet_input <- joined %>%
    select(cell = secu_ccnct, t, fecha, anio, semana_iso, mpio_cdpmp) %>%
    as.data.frame()

  cat("  Secciones unicas con eventos:", n_distinct(chronnet_input$cell), "\n")
  cat("  Semanas unicas:", n_distinct(chronnet_input$t), "\n")

  # Guardar
  out_path <- file.path(PROC_DIR, paste0("siedco_", nombre, ".rds"))
  saveRDS(chronnet_input, out_path)
  cat("  Guardado en:", out_path, "\n")

  return(chronnet_input)
}

# ==============================================================================
# Procesar todos los operativos
# ==============================================================================

resultados <- list()
for (nombre in names(operativos)) {
  filepath <- operativos[[nombre]]
  if (file.exists(filepath)) {
    resultados[[nombre]] <- procesar_operativo(filepath, nombre, secciones, bbox)
    gc()  # Liberar memoria entre archivos
  } else {
    cat("\nARCHIVO NO ENCONTRADO:", filepath, "\n")
  }
}

# ==============================================================================
# Resumen final
# ==============================================================================

cat("\n\n========== RESUMEN OPERATIVOS ==========\n")
for (nombre in names(resultados)) {
  if (!is.null(resultados[[nombre]])) {
    r <- resultados[[nombre]]
    cat(sprintf("%-20s %8d eventos | %5d secciones | %4d semanas\n",
                nombre, nrow(r), n_distinct(r$cell), n_distinct(r$t)))
  }
}

cat("\n=== Spatial join operativos completado ===\n")
