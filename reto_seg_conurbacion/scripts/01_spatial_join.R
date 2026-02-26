# ==============================================================================
# 01_spatial_join.R - Asignar delitos SIEDCO a secciones censales por semana
#
# Centinelas Rosaristas - Reto 3: Seguridad Integral Region Metropolitana
# Lee cada CSV de SIEDCO, filtra por bbox del area de estudio,
# hace spatial join contra secciones DANE y genera tabla (cell, t)
# para cada tipo de delito.
# ==============================================================================

library(sf)
library(dplyr)
library(lubridate)
library(readr)

# --- Rutas ---
SIEDCO_DIR <- file.path(dirname(getwd()),
                        "..", "Impact-evaluation-peace-process", "datasets")
PROC_DIR   <- file.path(getwd(), "data", "processed")

# --- Cargar secciones y bbox ---
cat("Cargando secciones de estudio...\n")
secciones <- st_read(file.path(PROC_DIR, "secciones_estudio.gpkg"), quiet = TRUE)
bbox <- readRDS(file.path(PROC_DIR, "bbox_estudio.rds"))

cat("Secciones:", nrow(secciones), "\n")
cat("Bbox:", paste(round(bbox, 4), collapse = ", "), "\n")

# --- Definir los archivos SIEDCO a procesar ---
delitos <- list(
  extorsion       = file.path(SIEDCO_DIR, "violent", "extortion.csv"),
  hurto_comercio  = file.path(SIEDCO_DIR, "larceny", "shoplifting.csv"),
  hurto_personas  = file.path(SIEDCO_DIR, "larceny", "theft.csv"),
  lesiones        = file.path(SIEDCO_DIR, "violent", "assault.csv"),
  hurto_autos     = file.path(SIEDCO_DIR, "larceny", "auto_theft.csv"),
  homicidios      = file.path(SIEDCO_DIR, "violent", "murders.csv"),
  hurto_motos     = file.path(SIEDCO_DIR, "larceny", "moto_theft.csv"),
  hurto_residencias = file.path(SIEDCO_DIR, "larceny", "burglary.csv")
)

# ==============================================================================
# Funcion para procesar un archivo SIEDCO
# ==============================================================================

procesar_siedco <- function(filepath, nombre_delito, secciones, bbox) {
  cat("\n===", toupper(nombre_delito), "===\n")
  cat("Leyendo:", basename(filepath), "...\n")

  # Detectar separador decimal leyendo primera linea del archivo
  primera_linea <- readLines(filepath, n = 2)[2]  # segunda linea = primer dato
  usa_coma_decimal <- grepl("[0-9],[0-9]", primera_linea) &&
                      !grepl("[0-9]\\.[0-9]", primera_linea)

  if (usa_coma_decimal) {
    # Archivos como theft.csv, assault.csv usan "," como decimal
    df <- read_delim(filepath, delim = ";", show_col_types = FALSE,
                     col_types = cols(lat_var = col_character(),
                                      lon_var = col_character(),
                                      .default = col_guess()))
    df$lat_var <- as.numeric(gsub(",", ".", df$lat_var))
    df$lon_var <- as.numeric(gsub(",", ".", df$lon_var))
    cat("  (Formato: coma como decimal)\n")
  } else {
    # Archivos como extortion.csv, burglary.csv usan "." como decimal
    df <- read_delim(filepath, delim = ";", show_col_types = FALSE)
    cat("  (Formato: punto como decimal)\n")
  }

  cat("  Registros totales:", nrow(df), "\n")

  if (!("lat_var" %in% names(df) && "lon_var" %in% names(df))) {
    cat("  ERROR: No se encontraron columnas lat_var/lon_var\n")
    return(NULL)
  }

  # Asegurar que lat/lon son numericos
  if (is.character(df$lat_var)) {
    df$lat_var <- as.numeric(gsub(",", ".", df$lat_var))
  }
  if (is.character(df$lon_var)) {
    df$lon_var <- as.numeric(gsub(",", ".", df$lon_var))
  }

  # Filtrar NAs en coordenadas
  df <- df %>% filter(!is.na(lat_var), !is.na(lon_var))

  # Filtrar por bounding box (rapido, antes del spatial join)
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

  # Parsear fecha
  df <- df %>%
    mutate(
      fecha = dmy(date_var),
      anio  = year(fecha),
      semana_iso = isoweek(fecha),
      # Crear identificador unico de semana: anio * 100 + semana
      t = as.integer((anio - min(anio, na.rm = TRUE)) * 52 + semana_iso)
    ) %>%
    filter(!is.na(fecha))

  cat("  Rango de fechas:", as.character(min(df$fecha)),
      "a", as.character(max(df$fecha)), "\n")

  # Convertir a sf
  puntos <- st_as_sf(df, coords = c("lon_var", "lat_var"), crs = 4686)

  # Spatial join contra secciones DANE
  cat("  Haciendo spatial join...\n")
  joined <- st_join(puntos, secciones[, c("secu_ccnct", "mpio_cdpmp", "es_ccb")],
                    join = st_within)

  # Filtrar los que cayeron dentro de alguna seccion
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
  out_path <- file.path(PROC_DIR, paste0("siedco_", nombre_delito, ".rds"))
  saveRDS(chronnet_input, out_path)
  cat("  Guardado en:", out_path, "\n")

  return(chronnet_input)
}

# ==============================================================================
# Procesar todos los delitos
# ==============================================================================

resultados <- list()
for (nombre in names(delitos)) {
  filepath <- delitos[[nombre]]
  if (file.exists(filepath)) {
    resultados[[nombre]] <- procesar_siedco(filepath, nombre, secciones, bbox)
  } else {
    cat("\nARCHIVO NO ENCONTRADO:", filepath, "\n")
  }
}

# ==============================================================================
# Resumen final
# ==============================================================================

cat("\n\n========== RESUMEN ==========\n")
for (nombre in names(resultados)) {
  if (!is.null(resultados[[nombre]])) {
    r <- resultados[[nombre]]
    cat(sprintf("%-20s %8d eventos | %5d secciones | %4d semanas\n",
                nombre, nrow(r), n_distinct(r$cell), n_distinct(r$t)))
  }
}

cat("\n=== Spatial join completado ===\n")
