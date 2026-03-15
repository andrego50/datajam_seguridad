# ==============================================================================
# 05_cross_crime_profiling.R - Perfilado cruzado: tasas relativas + empresas
#
# Centinelas Rosaristas - Reto 3: Seguridad Integral Region Metropolitana
#
# Para cada comunidad Louvain de extorsion:
#   1. Tasas relativas: % del total de cada delito concentrado en la zona/periodo
#   2. Misma logica para operativos policiales
#   3. Perfil empresarial por LOCALIDAD (Bogota) y MUNICIPIO (conurbacion)
# ==============================================================================

library(igraph)
library(dplyr)
library(lubridate)
library(readxl)

PROC_DIR     <- file.path(getwd(), "data", "processed")
CHRONNET_DIR <- file.path(getwd(), "output", "chronnets")

# ==============================================================================
# 1. Cargar red de extorsion y comunidades Louvain
# ==============================================================================

cat("=== Cargando ChroNNet de extorsion ===\n")
res <- readRDS(file.path(CHRONNET_DIR, "chronnet_extorsion.rds"))
net <- res$red_podada
rm(res); gc(verbose = FALSE)

com <- cluster_louvain(net, weights = E(net)$weight)
mem <- membership(com)
nodes <- V(net)$name
rm(net); gc(verbose = FALSE)

# ==============================================================================
# 2. Cargar eventos (ligero: solo columnas necesarias)
# ==============================================================================

capas <- c("extorsion", "hurto_comercio", "hurto_personas", "lesiones",
           "hurto_autos", "homicidios", "hurto_motos", "hurto_residencias",
           "capturas", "allanamientos", "incautaciones")

cat("=== Cargando eventos ===\n")
eventos_list <- list()
for (capa in capas) {
  rds <- file.path(PROC_DIR, paste0("siedco_", capa, ".rds"))
  if (!file.exists(rds)) next
  df <- readRDS(rds) %>%
    transmute(cell, mes = month(fecha), dow = wday(fecha, label = FALSE),
              mpio_cdpmp, capa = !!capa)
  eventos_list[[capa]] <- df
  cat("  ", capa, ":", nrow(df), "\n")
}
eventos_all <- bind_rows(eventos_list)
rm(eventos_list); gc(verbose = FALSE)

# Baseline: totales por capa por mes
totales_mes <- eventos_all %>%
  count(capa, mes, name = "total_global")
totales_abs <- eventos_all %>%
  count(capa, name = "total_absoluto")

cat("Total eventos:", nrow(eventos_all), "\n")

# ==============================================================================
# 3. Mapeos geograficos
# ==============================================================================

cell_mpio <- eventos_all %>%
  filter(capa == "extorsion") %>%
  distinct(cell, mpio_cdpmp)

# Cell -> localidad (Bogota)
cell_loc <- readRDS(file.path(PROC_DIR, "cell_localidad_bogota.rds"))

mpio_nombres <- c(
  "11001"="Bogota", "25754"="Soacha", "25286"="Funza", "25473"="Mosquera",
  "25126"="Cajica", "25175"="Chia", "25269"="Facatativa", "25307"="Girardot",
  "25290"="Fusagasuga", "25899"="Zipaquira", "25377"="La Calera",
  "25214"="Cota", "25430"="Madrid", "25758"="Sopo", "25785"="Tabio",
  "25799"="Tenjo", "25817"="Tocancipa", "25740"="Sibate",
  "25260"="El Rosal", "25245"="El Colegio", "25486"="Nemocon",
  "25224"="Cogua", "25320"="Guaduas", "25040"="Anapoima", "25402"="La Vega"
)

mes_nombres <- c("Ene","Feb","Mar","Abr","May","Jun",
                 "Jul","Ago","Sep","Oct","Nov","Dic")
dow_nombres <- c("Dom","Lun","Mar","Mie","Jue","Vie","Sab")

# ==============================================================================
# 4. Cargar RM filtrando por localidad (Bogota) y municipio (conurbacion)
# ==============================================================================

cat("\n=== Cargando Registro Mercantil ===\n")

rm_path <- "~/Documents/FastAnalytics/Proyectos/datajam_seguridad_ccb/Base Registro Mercantil 2024/Base total activas 2024 - anonimizada.xlsx"

rm_full <- read_excel(rm_path, col_types = "text")
cat("RM total:", nrow(rm_full), "filas\n")

# Extraer codigo localidad (primeros 2 chars de LocalidadComercial)
rm_full <- rm_full %>%
  mutate(
    loc_code = substr(LocalidadComercial, 1, 2),
    personal = as.numeric(PersonalOcupado)
  )

# Mapeo DANE -> nombre RM para municipios conurbados
dane_to_rm <- c(
  "25754"="SOACHA (CUNDINAMARCA)", "25286"="FUNZA (CUNDINAMARCA)",
  "25473"="MOSQUERA (CUNDINAMARCA)", "25126"="CAJICÁ (CUNDINAMARCA)",
  "25175"="CHÍA (CUNDINAMARCA)", "25269"="FACATATIVÁ (CUNDINAMARCA)",
  "25307"="GIRARDOT (CUNDINAMARCA)", "25290"="FUSAGASUGÁ (CUNDINAMARCA)",
  "25899"="ZIPAQUIRÁ (CUNDINAMARCA)", "25377"="LA CALERA (CUNDINAMARCA)",
  "25214"="COTA (CUNDINAMARCA)", "25430"="MADRID (CUNDINAMARCA)",
  "25758"="SOPÓ (CUNDINAMARCA)", "25785"="TABIO (CUNDINAMARCA)",
  "25799"="TENJO (CUNDINAMARCA)", "25817"="TOCANCIPÁ (CUNDINAMARCA)",
  "25740"="SIBATÉ (CUNDINAMARCA)", "25260"="EL ROSAL (CUNDINAMARCA)",
  "25245"="EL COLEGIO (CUNDINAMARCA)", "25486"="NEMOCÓN (CUNDINAMARCA)",
  "25224"="COGUA (CUNDINAMARCA)", "25320"="GUADUAS (CUNDINAMARCA)",
  "25040"="ANAPOIMA (CUNDINAMARCA)", "25402"="LA VEGA (CUNDINAMARCA)"
)

# Pre-calcular perfil RM por localidad de Bogota
rm_bogota <- rm_full %>%
  filter(MunicipioComercial == "BOGOTÁ D.C.", loc_code != "-",
         !is.na(loc_code), loc_code != "Si")

cat("RM Bogota por localidad:", nrow(rm_bogota), "\n")

rm_por_localidad <- rm_bogota %>%
  group_by(loc_code) %>%
  summarise(
    n_empresas = n(),
    personal_total = sum(personal, na.rm = TRUE),
    sector_1 = names(sort(table(SECTOR_ECONOMICO), decreasing = TRUE))[1],
    sector_1_pct = round(max(table(SECTOR_ECONOMICO)) / n() * 100, 1),
    sector_2 = names(sort(table(SECTOR_ECONOMICO), decreasing = TRUE))[2],
    micro_pct = round(sum(`TamañoEmpresa` == "1. Microempresa", na.rm = TRUE) / n() * 100, 1),
    .groups = "drop"
  )

rm(rm_bogota); gc(verbose = FALSE)

# Pre-calcular perfil RM por municipio conurbado
rm_conurbados <- rm_full %>%
  filter(MunicipioComercial %in% unname(dane_to_rm))

cat("RM conurbados:", nrow(rm_conurbados), "\n")

rm_to_dane <- setNames(names(dane_to_rm), dane_to_rm)

rm_por_mpio <- rm_conurbados %>%
  mutate(mpio_dane = rm_to_dane[MunicipioComercial]) %>%
  group_by(mpio_dane, MunicipioComercial) %>%
  summarise(
    n_empresas = n(),
    personal_total = sum(personal, na.rm = TRUE),
    sector_1 = names(sort(table(SECTOR_ECONOMICO), decreasing = TRUE))[1],
    sector_1_pct = round(max(table(SECTOR_ECONOMICO)) / n() * 100, 1),
    micro_pct = round(sum(`TamañoEmpresa` == "1. Microempresa", na.rm = TRUE) / n() * 100, 1),
    .groups = "drop"
  )

rm(rm_full, rm_conurbados); gc(verbose = FALSE)
cat("Perfiles RM listos\n")

# ==============================================================================
# 5. Perfilar cada comunidad
# ==============================================================================

cat("\n=== Perfilado por comunidad ===\n\n")
ops_names <- c("capturas", "allanamientos", "incautaciones")
resultados <- list()

for (k in sort(unique(mem))) {
  cells <- nodes[mem == k]
  if (length(cells) < 2) next

  ext_ev <- eventos_all %>% filter(capa == "extorsion", cell %in% cells)
  if (nrow(ext_ev) == 0) next

  # Meses pico (top 3)
  mes_freq <- sort(table(ext_ev$mes), decreasing = TRUE)
  meses_pico <- as.integer(names(mes_freq)[1:min(3, length(mes_freq))])
  meses_str <- paste(mes_nombres[meses_pico], collapse = "-")

  # Dias pico (top 2)
  dow_freq <- sort(table(ext_ev$dow), decreasing = TRUE)
  dias_pico <- as.integer(names(dow_freq)[1:min(2, length(dow_freq))])
  dias_str <- paste(dow_nombres[dias_pico], collapse = "-")

  # Municipios
  mpios_com <- cell_mpio %>% filter(cell %in% cells) %>%
    mutate(nombre = ifelse(mpio_cdpmp %in% names(mpio_nombres),
                           mpio_nombres[mpio_cdpmp], mpio_cdpmp)) %>%
    count(nombre, sort = TRUE)
  donde <- paste0(mpios_com$nombre, "(", mpios_com$n, ")", collapse = ", ")
  n_mpios <- nrow(mpios_com)
  mpios_codes <- cell_mpio %>% filter(cell %in% cells) %>%
    pull(mpio_cdpmp) %>% unique()

  # --- TASAS RELATIVAS ---
  ev_zona <- eventos_all %>% filter(cell %in% cells, mes %in% meses_pico)

  conteo_zona <- ev_zona %>%
    group_by(capa) %>%
    summarise(eventos_zona = n(), .groups = "drop")

  baseline_meses <- totales_mes %>%
    filter(mes %in% meses_pico) %>%
    group_by(capa) %>%
    summarise(total_meses = sum(total_global), .groups = "drop")

  tasas <- conteo_zona %>%
    left_join(baseline_meses, by = "capa") %>%
    left_join(totales_abs, by = "capa") %>%
    mutate(
      pct_del_total_meses = round(eventos_zona / total_meses * 100, 2),
      pct_del_total_abs = round(eventos_zona / total_absoluto * 100, 2)
    ) %>%
    arrange(desc(pct_del_total_meses))

  ancla <- tasas %>% filter(capa == "extorsion")
  total_del <- sum(tasas$eventos_zona[!tasas$capa %in% ops_names])
  total_ops <- sum(tasas$eventos_zona[tasas$capa %in% ops_names])
  ratio <- if (total_del > 0) round(total_ops / total_del, 3) else 0

  # --- PERFIL EMPRESARIAL ---
  # Localidades de Bogota en esta comunidad
  cells_bog <- cells[cells %in% cell_loc$secu_ccnct]
  locs_com <- cell_loc %>% filter(secu_ccnct %in% cells_bog) %>%
    distinct(LOCCODIGO, LOCNOMBRE) %>%
    filter(!is.na(LOCCODIGO))

  emp_localidades <- rm_por_localidad %>%
    filter(loc_code %in% locs_com$LOCCODIGO) %>%
    left_join(locs_com %>% select(LOCCODIGO, LOCNOMBRE),
              by = c("loc_code" = "LOCCODIGO")) %>%
    arrange(desc(n_empresas))

  # Municipios conurbados
  mpios_no_bog <- setdiff(mpios_codes, "11001")
  emp_mpios <- rm_por_mpio %>%
    filter(mpio_dane %in% mpios_no_bog) %>%
    arrange(desc(n_empresas))

  emp_total <- sum(emp_localidades$n_empresas, na.rm = TRUE) +
               sum(emp_mpios$n_empresas, na.rm = TRUE)
  emp_personal <- sum(emp_localidades$personal_total, na.rm = TRUE) +
                  sum(emp_mpios$personal_total, na.rm = TRUE)

  cat(sprintf("Com %2d | %3d secs | %2d mpios | Ext: %3d ev (%.1f%%) | Ratio: %.1f%% | Empresas: %s\n",
              k, length(cells), n_mpios,
              ifelse(nrow(ancla) > 0, ancla$eventos_zona, 0),
              ifelse(nrow(ancla) > 0, ancla$pct_del_total_meses, 0),
              ratio * 100,
              format(emp_total, big.mark = ",")))

  resultados[[paste0("extorsion_", k)]] <- list(
    comunidad        = k,
    n_secciones      = length(cells),
    cells            = cells,
    meses_pico       = meses_pico,
    meses_str        = meses_str,
    dias_pico        = dias_pico,
    dias_str         = dias_str,
    donde            = donde,
    n_municipios     = n_mpios,
    mpios_codes      = mpios_codes,
    tasas            = tasas,
    ancla_eventos    = ifelse(nrow(ancla) > 0, ancla$eventos_zona, 0),
    ancla_pct        = ifelse(nrow(ancla) > 0, ancla$pct_del_total_meses, 0),
    total_delitos    = total_del,
    total_ops        = total_ops,
    ratio_policial   = ratio,
    emp_localidades  = emp_localidades,
    emp_mpios        = emp_mpios,
    emp_total        = emp_total,
    emp_personal     = emp_personal
  )
}

rm(eventos_all, ev_zona, ext_ev); gc(verbose = FALSE)

# ==============================================================================
# 6. Guardar
# ==============================================================================

saveRDS(resultados, file.path(PROC_DIR, "perfiles_extorsion_completo.rds"))
cat("\nGuardado:", file.path(PROC_DIR, "perfiles_extorsion_completo.rds"), "\n")
cat("Comunidades:", length(resultados), "\n")
cat("=== Perfilado completo ===\n")
