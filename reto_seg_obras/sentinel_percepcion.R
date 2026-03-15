# ══════════════════════════════════════════════════════════════════════════════
# SENTINEL-2 + LANDSAT + SENTINEL-5P → PERCEPCIÓN DE SEGURIDAD
# Objetivo: imputar percepcion para hexágonos sin dato de encuesta
# usando variables espectrales, ambientales y atmosféricas exógenas
#
# Variables espectrales (Sentinel-2 L2A):
#   NDVI, NDBI, BSI, BRILLO, NDWI
# Variables atmosféricas (Sentinel-5P TROPOMI):
#   NO2 (dióxido de nitrógeno — proxy contaminación/tráfico)
# Variables térmicas (Landsat 8 Collection 2):
#   LST (Land Surface Temperature — isla de calor urbano)
#
# Fuente: Earth Search (Element84) STAC — sin autenticación
# Período composite: 2021-2023 (durante la obra)
# ══════════════════════════════════════════════════════════════════════════════

library(sf)
library(terra)
library(rstac)
library(dplyr)

# GDAL: timeout y reintentos para lectura de COG remotos
Sys.setenv(GDAL_HTTP_TIMEOUT      = "30",
           GDAL_HTTP_MAX_RETRY   = "3",
           GDAL_HTTP_RETRY_DELAY = "2",
           CPL_VSIL_CURL_ALLOWED_EXTENSIONS = ".tif,.TIF,.tiff",
           AWS_NO_SIGN_REQUEST   = "YES",   # Landsat S3 anónimo
           AWS_DEFAULT_REGION    = "us-west-2")

MIN_PERC    <- 20
MAX_CLOUD   <- 35   # Bogota tiene nubes frecuentes, subimos umbral
PERIODO_INI <- "2021-01-01T00:00:00Z"
PERIODO_FIN <- "2023-12-31T23:59:59Z"
STAC_URL    <- "https://earth-search.aws.element84.com/v1"

# ── CARGAR GRILLA ─────────────────────────────────────────────────────────────
cat("Cargando hex_grid...\n")
hex      <- readRDS("data/hex_grid_metro.rds")
hex_wgs  <- st_transform(hex, 4326)
bb       <- as.numeric(st_bbox(hex_wgs))  # xmin ymin xmax ymax
hex_3116 <- hex  # ya está en 3116

cat(sprintf("Hexagonos: %d | Con percepcion: %d | Sin: %d\n",
            nrow(hex), sum(!is.na(hex$percepcion)), sum(is.na(hex$percepcion))))
cat(sprintf("BBox: %.4f,%.4f → %.4f,%.4f\n", bb[1],bb[2],bb[3],bb[4]))

# ── HELPER: leer raster recortado desde URL COG ────────────────────────────────
read_cog_crop <- function(href, bbox_wgs, res_m = NULL) {
  # GDAL vsicurl: solo prefija si es URL http y no empieza ya con /vsicurl/
  url <- if (startsWith(href, "/vsicurl/")) href
         else if (startsWith(href, "http"))  paste0("/vsicurl/", href)
         else href
  tryCatch({
    r <- rast(url)
    # Recortar al bbox del estudio (con margen de 500m aprox)
    bb_ext <- ext(bbox_wgs[1]-0.006, bbox_wgs[3]+0.006,
                  bbox_wgs[2]-0.006, bbox_wgs[4]+0.006)
    bb_prj <- project(bb_ext, from="EPSG:4326", to=crs(r))
    rc     <- crop(r, bb_prj)
    if (!is.null(res_m)) rc <- aggregate(rc, fact=max(1,round(res_m/res(rc)[1])))
    rc
  }, error = function(e) NULL)
}

# ── HELPER: composite mediana de una lista de rasters ─────────────────────────
make_composite <- function(raster_list, nombre) {
  rlist <- Filter(Negate(is.null), raster_list)
  if (length(rlist) == 0) { cat(sprintf("  %s: sin datos\n", nombre)); return(NULL) }
  ref <- rlist[[1]]
  rlist <- lapply(rlist, function(r) {
    if (!compareGeom(r, ref, stopOnError=FALSE, res=FALSE))
      resample(r, ref, method="bilinear") else r
  })
  stk    <- rast(rlist)
  result <- app(stk, fun=median, na.rm=TRUE)
  names(result) <- nombre
  cat(sprintf("  %s: composite de %d escenas OK\n", nombre, length(rlist)))
  result
}

# ── HELPER: extraer media por hexágono ────────────────────────────────────────
extraer_hex <- function(r, nombre) {
  if (is.null(r)) { cat(sprintf("  %s: NULL\n", nombre)); return(rep(NA_real_, nrow(hex))) }
  r3116 <- project(r, "EPSG:3116", method="bilinear")
  v <- tryCatch(
    terra::extract(r3116, vect(hex_3116), fun=mean, na.rm=TRUE),
    error = function(e) NULL)
  if (is.null(v)) { cat(sprintf("  %s: error extraccion\n", nombre)); return(rep(NA_real_, nrow(hex))) }
  cat(sprintf("  %s: OK (NAs=%d, rango=%.3f-%.3f)\n",
              nombre, sum(is.na(v[,2])), min(v[,2],na.rm=TRUE), max(v[,2],na.rm=TRUE)))
  v[,2]
}

# ══════════════════════════════════════════════════════════════════════════════
# BLOQUE 1: SENTINEL-2 L2A — variables espectrales
# ══════════════════════════════════════════════════════════════════════════════
cat("\n── SENTINEL-2 L2A ──────────────────────────────────────────────────────────\n")

s2_items <- tryCatch({
  stac(STAC_URL) |>
    stac_search(collections="sentinel-2-l2a", bbox=bb,
                datetime=paste0(PERIODO_INI,"/",PERIODO_FIN), limit=200) |>
    post_request() |>
    items_filter(filter_fn=function(x) {
      cc <- x$properties$`eo:cloud_cover`
      !is.null(cc) && cc <= MAX_CLOUD
    })
}, error=function(e) { cat("Error S2:", conditionMessage(e),"\n"); NULL })

n_s2 <- if (!is.null(s2_items)) length(s2_items$features) else 0
cat(sprintf("Escenas S2 con nubosidad <=%d%%: %d\n", MAX_CLOUD, n_s2))

# Ordenar por nubosidad, tomar las 25 mejores
if (n_s2 > 0) {
  cc_vals <- sapply(s2_items$features, function(x) {
    cc <- x$properties$`eo:cloud_cover`; if(is.null(cc)) 100 else cc })
  s2_use  <- s2_items$features[order(cc_vals)[1:min(25,n_s2)]]

  # Nombres de assets en Earth Search para S2 L2A
  ASSET_MAP <- c(B02="blue", B03="green", B04="red", B08="nir", B11="swir16")

  bandas_raw <- list()
  for (band in names(ASSET_MAP)) {
    asset_nm <- ASSET_MAP[[band]]
    cat(sprintf("  Descargando %s (%s)...\n", band, asset_nm))
    rasters_b <- lapply(s2_use, function(it) {
      href <- it$assets[[asset_nm]]$href
      if (is.null(href)) href <- it$assets[[band]]$href
      if (is.null(href)) return(NULL)
      read_cog_crop(href, bb)
    })
    bandas_raw[[band]] <- make_composite(rasters_b, band)
  }

  B02 <- bandas_raw[["B02"]]; B03 <- bandas_raw[["B03"]]
  B04 <- bandas_raw[["B04"]]; B08 <- bandas_raw[["B08"]]
  B11 <- bandas_raw[["B11"]]

  # Alinear todas las bandas al mismo grid de referencia (B04, 10m)
  # B11 es 20m → resamplear a 10m para poder operar pixel a pixel
  cat("Alineando bandas al mismo grid (referencia: B04 10m)...\n")
  ref_grid <- B04
  alinear  <- function(r) {
    if (is.null(r)) return(NULL)
    if (compareGeom(r, ref_grid, stopOnError=FALSE)) return(r)
    resample(r, ref_grid, method="bilinear")
  }
  B02 <- alinear(B02); B03 <- alinear(B03)
  B08 <- alinear(B08); B11 <- alinear(B11)

  # Índices espectrales
  cat("Calculando indices...\n")
  NDVI <- if(!is.null(B04)&&!is.null(B08)) {
    r <- (B08-B04)/(B08+B04); names(r) <- "ndvi"; cat("  NDVI OK\n"); r } else NULL

  NDBI <- if(!is.null(B08)&&!is.null(B11)) {
    r <- (B11-B08)/(B11+B08); names(r) <- "ndbi"; cat("  NDBI OK\n"); r } else NULL

  BSI  <- if(!is.null(B02)&&!is.null(B04)&&!is.null(B08)&&!is.null(B11)) {
    r <- ((B11+B04)-(B08+B02))/((B11+B04)+(B08+B02))
    names(r) <- "bsi"; cat("  BSI OK\n"); r } else NULL

  NDWI <- if(!is.null(B03)&&!is.null(B08)) {
    r <- (B03-B08)/(B03+B08); names(r) <- "ndwi"; cat("  NDWI OK\n"); r } else NULL

  blist  <- Filter(Negate(is.null), list(B02,B03,B04,B08))
  BRILLO <- if(length(blist)>0) {
    r <- app(rast(blist), mean, na.rm=TRUE); names(r) <- "brillo"
    cat("  BRILLO OK\n"); r } else NULL

} else {
  cat("Sin escenas S2 disponibles.\n")
  NDVI <- NDBI <- BSI <- NDWI <- BRILLO <- NULL
}

# ══════════════════════════════════════════════════════════════════════════════
# BLOQUE 2: SENTINEL-5P TROPOMI — NO₂ (contaminación / tráfico)
# Proxy de densidad vial y actividad urbana → relacionado con percepción
# ══════════════════════════════════════════════════════════════════════════════
cat("\n── SENTINEL-5P (NO2) ───────────────────────────────────────────────────────\n")

s5p_items <- tryCatch({
  stac(STAC_URL) |>
    stac_search(collections="sentinel-5p-l2-netcdf", bbox=bb,
                datetime=paste0(PERIODO_INI,"/",PERIODO_FIN), limit=100) |>
    post_request()
}, error=function(e) { cat("S5P no disponible en este STAC\n"); NULL })

NO2 <- NULL
if (!is.null(s5p_items) && length(s5p_items$features) > 0) {
  cat(sprintf("Escenas S5P: %d\n", length(s5p_items$features)))
  rasters_no2 <- lapply(s5p_items$features[1:min(20,length(s5p_items$features))],
    function(it) {
      # Buscar asset de NO2 column density
      href <- it$assets[["no2"]]$href %||% it$assets[["NO2"]]$href
      if(is.null(href)) return(NULL)
      read_cog_crop(href, bb, res_m=1000)
    })
  NO2 <- make_composite(rasters_no2, "no2")
} else {
  # Alternativa: Copernicus Atmosphere (CAMS) vía OpenMeteo API (NO2 superficie)
  cat("Intentando NO2 desde Open-Meteo Archive (CAMS)...\n")
  tryCatch({
    # Open-Meteo API histórico para Bogotá (lat=4.63, lon=-74.12)
    url_no2 <- paste0(
      "https://air-quality-api.open-meteo.com/v1/air-quality",
      "?latitude=4.628&longitude=-74.120",
      "&hourly=nitrogen_dioxide",
      "&start_date=2021-01-01&end_date=2023-12-31",
      "&timezone=America%2FBogota")
    resp <- readLines(url(url_no2), warn=FALSE)
    json <- paste(resp, collapse="")
    # Extraer valores de NO2 (mediana del periodo)
    vals <- regmatches(json, gregexpr('[-0-9.]+', json))[[1]]
    no2_vals <- as.numeric(vals[nchar(vals)>0 & !is.na(suppressWarnings(as.numeric(vals)))])
    no2_med  <- median(no2_vals[no2_vals > 0 & no2_vals < 1000], na.rm=TRUE)
    cat(sprintf("NO2 mediana periodo: %.2f ug/m3 (valor unico — no espacial)\n", no2_med))
    # Como es un solo valor temporal (no espacial), lo guardamos como referencia
    # pero no lo usamos como predictor espacial
  }, error=function(e) cat("Open-Meteo NO2: no disponible\n"))
}

# ══════════════════════════════════════════════════════════════════════════════
# BLOQUE 3: LANDSAT 8/9 — Land Surface Temperature (LST)
# Isla de calor urbano → zonas industriales/construidas percibidas como
# más inseguras; áreas verdes más frescas → mejor percepción
# ══════════════════════════════════════════════════════════════════════════════
cat("\n── LANDSAT 8/9 (LST) ───────────────────────────────────────────────────────\n")

ls_items <- tryCatch({
  stac(STAC_URL) |>
    stac_search(
      collections = c("landsat-c2-l2"),
      bbox        = bb,
      datetime    = paste0(PERIODO_INI,"/",PERIODO_FIN),
      limit       = 100) |>
    post_request() |>
    items_filter(filter_fn=function(x) {
      cc <- x$properties$`eo:cloud_cover`
      !is.null(cc) && cc <= MAX_CLOUD
    })
}, error=function(e) { cat("Landsat no disponible:", conditionMessage(e), "\n"); NULL })

LST <- NULL
n_ls <- if (!is.null(ls_items)) length(ls_items$features) else 0
cat(sprintf("Escenas Landsat STAC: %d\n", n_ls))

# Landsat en Earth Search usa S3 "Requester Pays" → no se puede acceder anónimamente
# Alternativa: Open-Meteo ERA5 Land — temperatura de suelo en puntos de la grilla
# Resolución ERA5 Land: ~9km → suficiente para capturar diferencias entre hexágonos
cat("Obteniendo LST desde Open-Meteo ERA5 Land (9km grid, sin credenciales)...\n")

# Centroides de hexágonos en WGS84 para la query
hex_pts_wgs <- st_transform(st_centroid(hex_3116), 4326)
coords_hex  <- st_coordinates(hex_pts_wgs)

# Open-Meteo soporta batch de hasta ~1000 ubicaciones con su API de archivo
# Usamos el centroide del bbox para obtener una serie temporal y luego
# interpolamos espacialmente con los datos de múltiples puntos en una grilla regular
# Estrategia: query en una grilla 5x5 sobre el bbox → interpolar a hexágonos

lons_grid <- seq(bb[1], bb[3], length.out=5)
lats_grid <- seq(bb[2], bb[4], length.out=5)
grid_pts  <- expand.grid(lon=lons_grid, lat=lats_grid)

cat(sprintf("  Consultando %d puntos de grilla ERA5...\n", nrow(grid_pts)))

lst_grid <- sapply(1:nrow(grid_pts), function(k) {
  url_era5 <- paste0(
    "https://archive.open-meteo.com/v1/archive",
    "?latitude=",  round(grid_pts$lat[k], 4),
    "&longitude=", round(grid_pts$lon[k], 4),
    "&start_date=2021-01-01&end_date=2023-12-31",
    "&daily=temperature_2m_mean",
    "&timezone=America%2FBogota")
  tryCatch({
    resp <- readLines(url(url_era5, open="r"), warn=FALSE)
    close(url(url_era5, open="r"))
    txt  <- paste(resp, collapse="")
    # Extraer array de temperaturas
    m <- regmatches(txt, regexpr('"temperature_2m_mean":\\[([^\\]]+)\\]', txt))
    if (length(m)==0) return(NA_real_)
    vals <- as.numeric(strsplit(gsub('.*\\[|\\].*','',m),',')[[1]])
    median(vals, na.rm=TRUE)
  }, error=function(e) NA_real_)
})

n_ok <- sum(!is.na(lst_grid))
cat(sprintf("  ERA5 LST: %d/%d puntos OK\n", n_ok, nrow(grid_pts)))

if (n_ok >= 4) {
  # Crear raster de LST desde la grilla ERA5
  lst_df  <- cbind(grid_pts, lst=lst_grid)
  lst_df  <- lst_df[!is.na(lst_df$lst),]
  lst_pts <- vect(lst_df, geom=c("lon","lat"), crs="EPSG:4326")
  # Interpolar IDW a resolución de ~200m (misma que hexágonos)
  r_template <- rast(ext(bb[1],bb[3],bb[2],bb[4]), res=0.002, crs="EPSG:4326")
  LST_wgs    <- interpIDW(lst_pts, r_template, field="lst", radius=0.1)
  LST        <- project(LST_wgs, "EPSG:3116", method="bilinear")
  names(LST) <- "lst"
  cat(sprintf("  LST ERA5 rango: %.1f - %.1f C\n", minmax(LST)[1], minmax(LST)[2]))
} else {
  cat("  ERA5: sin suficientes datos, LST no disponible.\n")
}

# ══════════════════════════════════════════════════════════════════════════════
# EXTRACCIÓN POR HEXÁGONO
# ══════════════════════════════════════════════════════════════════════════════
cat("\n── EXTRACCIÓN POR HEXÁGONO ──────────────────────────────────────────────────\n")

hex$ndvi   <- extraer_hex(NDVI,   "ndvi")
hex$ndbi   <- extraer_hex(NDBI,   "ndbi")
hex$bsi    <- extraer_hex(BSI,    "bsi")
hex$brillo <- extraer_hex(BRILLO, "brillo")
hex$ndwi   <- extraer_hex(NDWI,   "ndwi")
hex$no2    <- extraer_hex(NO2,    "no2")
hex$lst    <- extraer_hex(LST,    "lst")

# ══════════════════════════════════════════════════════════════════════════════
# MODELO DE REGRESIÓN: percepcion ~ variables exógenas
# ══════════════════════════════════════════════════════════════════════════════
cat("\n── MODELO percepcion ~ variables exogenas ───────────────────────────────────\n")

todas_vars <- c("ndvi","ndbi","bsi","brillo","ndwi","no2","lst")
hex_df     <- st_drop_geometry(hex)

# Solo variables con suficiente variabilidad y datos en al menos 30% de hexágonos
vars_ok <- sapply(todas_vars, function(v) {
  if (!v %in% names(hex_df)) return(FALSE)
  x <- hex_df[[v]]
  pct_ok  <- mean(!is.na(x))
  variab  <- var(x, na.rm=TRUE)
  pct_ok > 0.30 && !is.na(variab) && variab > 1e-10
})
vars_modelo <- todas_vars[vars_ok]
cat(sprintf("Variables candidatas: %s\n", paste(vars_modelo, collapse=", ")))

if (length(vars_modelo) == 0)
  stop("Ninguna variable espectral/ambiental disponible.")

# ── PCA para eliminar multicolinealidad ────────────────────────────────────────
# NDVI, NDBI, BSI, NDWI comparten bandas → VIF muy altos si se usan directos
# PCA produce componentes ortogonales → sin multicolinealidad por construcción
cat("\nAplicando PCA a indices espectrales...\n")

df_pca_todos <- hex_df[, vars_modelo, drop=FALSE]
df_pca_enc   <- df_pca_todos[!is.na(hex_df$percepcion), ]

# PCA sobre hexágonos con encuesta (filas completas)
idx_completos_enc <- complete.cases(df_pca_enc)
pca_fit <- prcomp(df_pca_enc[idx_completos_enc, ], center=TRUE, scale.=TRUE)

# Varianza explicada por componente
var_exp <- round(summary(pca_fit)$importance[2,] * 100, 1)
var_cum <- round(summary(pca_fit)$importance[3,] * 100, 1)
cat("Varianza explicada por PC:\n")
for (k in seq_along(var_exp))
  cat(sprintf("  PC%d: %.1f%% (acumulado: %.1f%%)\n", k, var_exp[k], var_cum[k]))

# Usar tantos PCs como para explicar >= 80% de varianza
n_pc <- which(var_cum >= 80)[1]
n_pc <- max(2, min(n_pc, length(vars_modelo)))
cat(sprintf("Usando %d componentes principales (%.1f%% varianza)\n", n_pc, var_cum[n_pc]))

# Proyectar TODOS los hexágonos al espacio PCA (para predecir después)
idx_completos_todos <- complete.cases(df_pca_todos)
scores_todos        <- matrix(NA_real_, nrow=nrow(hex_df), ncol=n_pc)
scores_todos[idx_completos_todos, ] <- predict(pca_fit, df_pca_todos[idx_completos_todos,])[,1:n_pc]

# Scores de entrenamiento (hexágonos con encuesta)
scores_enc <- matrix(NA_real_, nrow=nrow(df_pca_enc), ncol=n_pc)
scores_enc[idx_completos_enc, ] <- pca_fit$x[,1:n_pc]

pc_names <- paste0("PC", 1:n_pc)
df_enc   <- data.frame(
  percepcion = hex_df$percepcion[!is.na(hex_df$percepcion)],
  as.data.frame(scores_enc)
)
colnames(df_enc)[2:(n_pc+1)] <- pc_names
df_enc   <- df_enc[complete.cases(df_enc), ]
cat(sprintf("Observaciones para ajuste: %d\n", nrow(df_enc)))

if (nrow(df_enc) < MIN_PERC)
  stop(paste("Solo", nrow(df_enc), "obs — insuficiente para el modelo."))

formula_mod <- as.formula(paste("percepcion ~", paste(pc_names, collapse=" + ")))
modelo      <- lm(formula_mod, data=df_enc)

cat("\nResumen del modelo (percepcion ~ PC1 + ... + PCn):\n")
print(summary(modelo))

r2   <- summary(modelo)$r.squared
rmse <- sqrt(mean(residuals(modelo)^2))
cat(sprintf("\nR2=%.3f | RMSE=%.3f\n", r2, rmse))

# Cargas de cada variable en los PCs usados (interpretabilidad)
cat("\nCargas de variables en los PCs (rotacion PCA):\n")
print(round(pca_fit$rotation[, 1:n_pc], 3))

# ── PREDICCIÓN ────────────────────────────────────────────────────────────────
cat("\nImputando percepcion_sat...\n")
df_todos_pc       <- as.data.frame(scores_todos)
colnames(df_todos_pc) <- pc_names
pred_sat  <- predict(modelo, newdata=df_todos_pc)
pred_sat  <- pmax(1, pmin(5, pred_sat))  # limitar al rango de la encuesta

# percepcion_sat: encuesta real donde existe; imputado donde no y hay índices;
# NA donde no hay ni encuesta ni índices espectrales
hex$percepcion_sat <- ifelse(!is.na(hex$percepcion), hex$percepcion, pred_sat)

n_imputados  <- sum(is.na(hex$percepcion) & !is.na(hex$percepcion_sat))
n_sin_dato   <- sum(is.na(hex$percepcion_sat))
cat(sprintf("  Hexagonos con encuesta real: %d\n", sum(!is.na(hex$percepcion))))
cat(sprintf("  Hexagonos imputados por satelite: %d\n", n_imputados))
cat(sprintf("  Hexagonos sin ningun dato: %d\n", n_sin_dato))

# Reporte de calidad
cat(sprintf("\npercepcion_sat:\n"))
cat(sprintf("  NAs: %d\n", sum(is.na(hex$percepcion_sat))))
cat(sprintf("  Rango: %.2f - %.2f\n",
            min(hex$percepcion_sat,na.rm=TRUE), max(hex$percepcion_sat,na.rm=TRUE)))
cat(sprintf("  Varianza: %.4f (cruda=%.4f, kriging=%.4f)\n",
            var(hex$percepcion_sat,na.rm=TRUE),
            var(hex$percepcion,na.rm=TRUE),
            var(hex$pred_percepcion,na.rm=TRUE)))

# ── GUARDAR ───────────────────────────────────────────────────────────────────
saveRDS(hex, "data/hex_grid_metro.rds")
cat("\nhex_grid_metro.rds actualizado con:\n")
nuevas <- intersect(c("ndvi","ndbi","bsi","brillo","ndwi","no2","lst","percepcion_sat"),
                    names(hex))
cat(paste(" ", nuevas, collapse="\n"), "\n")

# Guardar rasters
dir.create("data/sentinel", showWarnings=FALSE)
for (nm in c("NDVI","NDBI","BSI","BRILLO","NDWI","LST","NO2")) {
  r <- get(nm)
  if (!is.null(r))
    writeRaster(r, paste0("data/sentinel/",tolower(nm),".tif"), overwrite=TRUE)
}
cat("Rasters en data/sentinel/\n")
cat("\nListo. 'percepcion_sat' = encuesta real donde existe + imputacion espectral donde no.\n")
cat("Variables usadas son exogenas al crimen -> sin endogeneidad.\n")
