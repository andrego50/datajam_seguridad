# ==============================================================================
# 00_setup.R - Definir municipios de estudio y cargar secciones DANE
#
# Centinelas Rosaristas - Reto 3: Seguridad Integral Region Metropolitana
# Municipios CCB + vecinos Queen de primer grado
# ==============================================================================

library(sf)
library(spdep)
library(dplyr)

# --- Rutas ---
SIEDCO_DIR <- file.path(dirname(getwd()),
                        "..", "Impact-evaluation-peace-process", "datasets")
# Archivo completo con secciones urbanas Y rurales
GPKG_PATH  <- file.path(SIEDCO_DIR, "polygons", "maps",
                        "urban_rural_sections_dane.gpkg")
OUT_DIR    <- file.path(getwd(), "data", "processed")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# ==============================================================================
# 1. Definir municipios de la jurisdiccion CCB
#    Bogota D.C. + 59 municipios de Cundinamarca
#    Fuente: https://www.ccb.org.co jurisdiccion
# ==============================================================================

ccb_municipios <- c(
  "11001",  # Bogota D.C.
  # --- Sabana Centro ---
  "25126",  # Cajica
  "25175",  # Chia
  "25183",  # Cogua
  "25200",  # Cota (corregido de web search)
  "25295",  # Gachancipa
  "25486",  # Nemocon
  "25758",  # Sopo
  "25785",  # Tabio
  "25799",  # Tenjo
  "25817",  # Tocancipa
  "25899",  # Zipaquira
  # --- Sabana Occidente (algunos bajo CCB) ---
  "25269",  # Facatativa
  "25286",  # Funza
  "25430",  # Madrid
  "25473",  # Mosquera
  "25099",  # Bojaca
  "25245",  # El Rosal
  "25769",  # Subachoque
  "25898",  # Zipacon
  # --- Soacha (nota: creo su propia CC en 2024, incluir para analisis) ---
  "25754",  # Soacha
  # --- Sumapaz ---
  "25053",  # Arbelaez
  "25120",  # Cabrera
  "25290",  # Fusagasuga
  "25312",  # Granada
  "25488",  # Pandi
  "25513",  # Pasca
  "25592",  # San Bernardo
  "25612",  # Silvania
  "25805",  # Tibacuy
  "25862",  # Venecia (Cundinamarca)
  # --- Oriente ---
  "25151",  # Caqueza
  "25168",  # Chipaque
  "25178",  # Choachi (nota: verificar - puede ser diferente de Chia)
  "25279",  # Fomeque
  "25281",  # Fosca
  "25328",  # Guayabetal
  "25335",  # Gutierrez
  "25535",  # Quetame
  "25839",  # Ubaque
  "25845",  # Une
  # --- Ubate ---
  "25148",  # Carmen de Carupa (verificar)
  "25214",  # Cucunuba
  "25293",  # Fuquene
  "25317",  # Guacheta
  "25402",  # Lenguazaque
  "25745",  # Simijaca
  "25779",  # Susa
  "25781",  # Sutatausa
  "25793",  # Tausa
  "25843",  # Ubate
  # --- Guavio ---
  "25297",  # Gachala
  "25299",  # Gacheta
  "25307",  # Gama
  "25322",  # Guasca
  "25326",  # Guatavita
  "25377",  # Junin
  "25372",  # La Calera
  "25841",  # Ubala
  # --- Almeidas ---
  "25169",  # (Chocontá - verificar codigo)
  "25407",  # Macheta
  "25436",  # Manta
  "25596",  # Sesquile
  "25645",  # Suesca
  "25807",  # Tibirita
  "25871"   # Villapinzon
)

# Deduplicar
ccb_municipios <- unique(ccb_municipios)
cat("Municipios CCB definidos:", length(ccb_municipios), "\n")

# ==============================================================================
# 2. Cargar secciones urbanas DANE (solo Bogota + Cundinamarca primero)
# ==============================================================================

cat("Cargando secciones urbanas DANE...\n")
secciones_all <- st_read(GPKG_PATH, quiet = TRUE)

# Filtrar Bogota (11) y Cundinamarca (25)
secciones_bc <- secciones_all %>%
  filter(dpto_ccdgo %in% c("11", "25"))

cat("Secciones urbanas Bogota+Cundinamarca:", nrow(secciones_bc), "\n")

# ==============================================================================
# 3. Disolver secciones a nivel de municipio para contigüidad Queen
# ==============================================================================

cat("Disolviendo a nivel de municipio para calcular contigüidad...\n")
municipios_poly <- secciones_bc %>%
  group_by(mpio_cdpmp) %>%
  summarise(geometry = st_union(geom), .groups = "drop")

# Reparar geometrias
municipios_poly <- st_make_valid(municipios_poly)

cat("Municipios con secciones urbanas:", nrow(municipios_poly), "\n")

# ==============================================================================
# 4. Calcular contigüidad Queen y encontrar vecinos de primer grado
# ==============================================================================

cat("Calculando contigüidad Queen...\n")
nb_queen <- poly2nb(municipios_poly, queen = TRUE)

# Identificar cuales de nuestros municipios CCB estan en el GeoPackage
ccb_presentes <- ccb_municipios[ccb_municipios %in% municipios_poly$mpio_cdpmp]
cat("Municipios CCB con secciones urbanas:", length(ccb_presentes), "\n")

# Encontrar indices de los municipios CCB
idx_ccb <- which(municipios_poly$mpio_cdpmp %in% ccb_presentes)

# Encontrar vecinos de primer grado
vecinos_idx <- unique(unlist(nb_queen[idx_ccb]))
vecinos_codes <- municipios_poly$mpio_cdpmp[vecinos_idx]

# Vecinos que NO estan en CCB (son los nuevos que agregamos)
vecinos_nuevos <- setdiff(vecinos_codes, ccb_presentes)
cat("Vecinos Queen de primer grado (fuera de CCB):", length(vecinos_nuevos), "\n")
cat("Codigos:", paste(vecinos_nuevos, collapse = ", "), "\n")

# Conjunto final: CCB + vecinos
municipios_estudio <- unique(c(ccb_presentes, vecinos_codes))
cat("\nTotal municipios de estudio (CCB + vecinos):", length(municipios_estudio), "\n")

# ==============================================================================
# 5. Filtrar secciones DANE para el area de estudio
# ==============================================================================

secciones_estudio <- secciones_bc %>%
  filter(mpio_cdpmp %in% municipios_estudio)

cat("Secciones urbanas en area de estudio:", nrow(secciones_estudio), "\n")

# Agregar flag de si es CCB o vecino
secciones_estudio <- secciones_estudio %>%
  mutate(es_ccb = ifelse(mpio_cdpmp %in% ccb_presentes, TRUE, FALSE))

# Resumen por municipio
resumen <- secciones_estudio %>%
  st_drop_geometry() %>%
  group_by(mpio_cdpmp, es_ccb) %>%
  summarise(n_secciones = n(), .groups = "drop") %>%
  arrange(desc(n_secciones))

cat("\nTop 20 municipios por secciones:\n")
print(head(resumen, 20))

# ==============================================================================
# 6. Guardar resultados
# ==============================================================================

# Guardar secciones de estudio
out_path <- file.path(OUT_DIR, "secciones_estudio.gpkg")
st_write(secciones_estudio, out_path, delete_dsn = TRUE, quiet = TRUE)
cat("\nSecciones guardadas en:", out_path, "\n")

# Guardar municipios disueltos (para mapas)
municipios_estudio_poly <- municipios_poly %>%
  filter(mpio_cdpmp %in% municipios_estudio) %>%
  mutate(es_ccb = ifelse(mpio_cdpmp %in% ccb_presentes, TRUE, FALSE))

out_muni <- file.path(OUT_DIR, "municipios_estudio.gpkg")
st_write(municipios_estudio_poly, out_muni, delete_dsn = TRUE, quiet = TRUE)
cat("Municipios guardados en:", out_muni, "\n")

# Guardar lista de codigos
saveRDS(list(
  ccb = ccb_presentes,
  vecinos = vecinos_nuevos,
  todos = municipios_estudio
), file.path(OUT_DIR, "municipios_codigos.rds"))

# Guardar bounding box para filtrado rapido de SIEDCO
bbox <- st_bbox(secciones_estudio)
saveRDS(bbox, file.path(OUT_DIR, "bbox_estudio.rds"))
cat("\nBounding box:", paste(round(bbox, 4), collapse = ", "), "\n")

cat("\n=== Setup completado ===\n")
