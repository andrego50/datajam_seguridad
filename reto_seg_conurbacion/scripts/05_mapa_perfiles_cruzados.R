# ==============================================================================
# 06_mapa_perfiles_cruzados.R - Mapa dinamico: Comunidades de Extorsion
#
# Centinelas Rosaristas - Reto 3: Seguridad Integral Region Metropolitana
# Popup con: tasas relativas, operativos, perfil empresarial por localidad/mpio
# Comunidades ordenadas por # poligonos (mayor a menor)
# ==============================================================================

library(sf)
library(dplyr)
library(leaflet)
library(htmlwidgets)
library(scales)

PROC_DIR <- file.path(getwd(), "data", "processed")
MAP_DIR  <- file.path(getwd(), "output", "maps")
dir.create(MAP_DIR, recursive = TRUE, showWarnings = FALSE)

# ==============================================================================
# 1. Cargar datos
# ==============================================================================

cat("Cargando datos...\n")
perfiles <- readRDS(file.path(PROC_DIR, "perfiles_extorsion_completo.rds"))
secciones <- st_read(file.path(PROC_DIR, "secciones_estudio.gpkg"), quiet = TRUE)
secciones <- st_transform(secciones, 4326)
cell_loc <- readRDS(file.path(PROC_DIR, "cell_localidad_bogota.rds"))

# ==============================================================================
# 2. Construir perfil empresarial HTML por comunidad
# ==============================================================================

ops_names <- c("capturas", "allanamientos", "incautaciones")

emp_html_list <- list()
for (nom in names(perfiles)) {
  p <- perfiles[[nom]]

  emp_parts <- c()

  # Localidades de Bogota
  if (nrow(p$emp_localidades) > 0) {
    loc_rows <- head(p$emp_localidades, 5)
    emp_parts <- c(emp_parts,
      "<b>Bogota por localidad:</b><br>",
      paste0(
        "<span style='font-size:11px;'>",
        loc_rows$LOCNOMBRE, ": ",
        format(loc_rows$n_empresas, big.mark = ","), " emp, ",
        format(loc_rows$personal_total, big.mark = ","), " empl, ",
        loc_rows$sector_1, "(", loc_rows$sector_1_pct, "%), ",
        loc_rows$micro_pct, "% micro",
        "</span>",
        collapse = "<br>"
      )
    )
  }

  # Municipios conurbados
  if (nrow(p$emp_mpios) > 0) {
    mpio_rows <- head(p$emp_mpios, 5)
    emp_parts <- c(emp_parts,
      "<br><b>Municipios conurbados:</b><br>",
      paste0(
        "<span style='font-size:11px;'>",
        sub(" \\(.*", "", mpio_rows$MunicipioComercial), ": ",
        format(mpio_rows$n_empresas, big.mark = ","), " emp, ",
        format(mpio_rows$personal_total, big.mark = ","), " empl, ",
        mpio_rows$sector_1, "(", mpio_rows$sector_1_pct, "%), ",
        mpio_rows$micro_pct, "% micro",
        "</span>",
        collapse = "<br>"
      )
    )
  }

  # Resumen
  emp_parts <- c(
    paste0("<b>Total: ", format(p$emp_total, big.mark = ","),
           " empresas, ", format(p$emp_personal, big.mark = ","),
           " empleados</b><br>"),
    emp_parts
  )

  emp_html_list[[nom]] <- paste(emp_parts, collapse = "")
}

# ==============================================================================
# 3. Construir dataframe por seccion
# ==============================================================================

cat("Construyendo registros...\n")

# Mapeo cell -> municipio
cell_mpio <- readRDS(file.path(PROC_DIR, "siedco_extorsion.rds")) %>%
  dplyr::distinct(cell, mpio_cdpmp)

mpio_nombres <- c(
  "11001"="Bogota", "25754"="Soacha", "25286"="Funza", "25473"="Mosquera",
  "25126"="Cajica", "25175"="Chia", "25269"="Facatativa", "25307"="Girardot",
  "25290"="Fusagasuga", "25899"="Zipaquira", "25377"="La Calera",
  "25214"="Cota", "25430"="Madrid", "25758"="Sopo", "25785"="Tabio",
  "25799"="Tenjo", "25817"="Tocancipa", "25740"="Sibate",
  "25260"="El Rosal", "25245"="El Colegio", "25486"="Nemocon",
  "25224"="Cogua", "25320"="Guaduas", "25040"="Anapoima", "25402"="La Vega"
)

filas <- list()
idx <- 1

for (nom in names(perfiles)) {
  p <- perfiles[[nom]]
  tasas <- p$tasas

  # Delitos con tasa relativa
  delitos <- tasas %>%
    filter(!capa %in% ops_names, capa != "extorsion") %>%
    head(5)
  delitos_str <- paste(
    paste0(delitos$capa, ": ",
           format(delitos$eventos_zona, big.mark = ","),
           " (<b>", delitos$pct_del_total_meses, "%</b>)"),
    collapse = "<br>"
  )

  # Operativos con tasa
  ops <- tasas %>% filter(capa %in% ops_names)
  ops_str <- if (nrow(ops) > 0) {
    paste(paste0(ops$capa, ": ",
                 format(ops$eventos_zona, big.mark = ","),
                 " (<b>", ops$pct_del_total_meses, "%</b>)"),
          collapse = "<br>")
  } else "Sin datos"

  grupo <- sprintf("Com %02d (%d secs, %d mpios)",
                   p$comunidad, p$n_secciones, p$n_municipios)

  for (cell_id in p$cells) {
    # Localidad de esta celda
    loc_info <- cell_loc %>% filter(secu_ccnct == cell_id)
    loc_nombre <- if (nrow(loc_info) > 0 && !is.na(loc_info$LOCNOMBRE[1])) {
      loc_info$LOCNOMBRE[1]
    } else {
      mpio_code <- cell_mpio %>% filter(cell == cell_id) %>% pull(mpio_cdpmp)
      if (length(mpio_code) > 0 && mpio_code %in% names(mpio_nombres)) {
        mpio_nombres[mpio_code]
      } else if (length(mpio_code) > 0) {
        mpio_code
      } else ""
    }

    filas[[idx]] <- data.frame(
      secu_ccnct     = cell_id,
      comunidad      = p$comunidad,
      grupo          = grupo,
      n_secciones    = p$n_secciones,
      n_municipios   = p$n_municipios,
      meses_pico     = p$meses_str,
      dias_pico      = p$dias_str,
      donde          = p$donde,
      ubicacion      = loc_nombre,
      eventos_ancla  = p$ancla_eventos,
      ancla_pct      = p$ancla_pct,
      delitos_co     = delitos_str,
      ops_co         = ops_str,
      total_delitos  = p$total_delitos,
      total_ops      = p$total_ops,
      ratio_policial = p$ratio_policial,
      emp_html       = emp_html_list[[nom]],
      stringsAsFactors = FALSE
    )
    idx <- idx + 1
  }
}

df_perfiles <- bind_rows(filas)
cat("Registros:", nrow(df_perfiles), "\n")

# ==============================================================================
# 4. Join con geometrias
# ==============================================================================

sec_slim <- secciones %>%
  filter(!is.na(secu_ccnct)) %>%
  select(secu_ccnct, geom)

geo <- sec_slim %>%
  inner_join(df_perfiles, by = "secu_ccnct")

rm(secciones, sec_slim, df_perfiles, filas); gc(verbose = FALSE)
cat("Secciones mapeadas:", nrow(geo), "\n")

# ==============================================================================
# 5. Colores y popup
# ==============================================================================

com_ids <- sort(unique(geo$comunidad))
pal_colors <- c("#e31a1c", "#1f78b4", "#33a02c", "#ff7f00", "#6a3d9a",
                "#b15928", "#a6cee3", "#fb9a99", "#b2df8a", "#fdbf6f",
                "#cab2d6", "#8dd3c7", "#bebada", "#fb8072", "#80b1d3",
                "#fdb462", "#ffff99")
paleta_com <- colorFactor(palette = pal_colors[seq_along(com_ids)],
                          domain = com_ids)

geo$color <- paleta_com(geo$comunidad)
geo$opacity <- rescale(1 - geo$ratio_policial, to = c(0.4, 0.85))

semaforo <- ifelse(geo$ratio_policial < 0.10,
  " <span style='color:red;font-weight:bold;'>&#9679; CRITICA</span>",
  ifelse(geo$ratio_policial < 0.13,
    " <span style='color:orange;font-weight:bold;'>&#9679; BAJA</span>",
    ifelse(geo$ratio_policial < 0.16,
      " <span style='color:#cccc00;font-weight:bold;'>&#9679; MEDIA</span>",
      " <span style='color:green;font-weight:bold;'>&#9679; ALTA</span>")))

geo$popup <- paste0(
  "<div style='font-family:Arial;font-size:12px;min-width:340px;max-width:420px;",
  "max-height:550px;overflow-y:auto;'>",

  # Titulo
  "<b style='font-size:15px;color:", geo$color, "'>",
  "Comunidad ", geo$comunidad, "</b>",
  " <span style='color:#888;font-size:11px;'>(",
  geo$n_secciones, " secciones, ", geo$n_municipios, " mpios)</span><br>",
  "<span style='color:#555;font-size:11px;'>Ubicacion: <b>", geo$ubicacion, "</b></span><br>",
  "<span style='color:#aaa;font-size:10px;'>", geo$secu_ccnct, "</span>",
  "<hr style='margin:4px 0;border-color:#ddd;'>",

  # Calendario
  "<b style='color:#ff7f00;'>Calendario</b><br>",
  "Meses: <b>", geo$meses_pico, "</b> | Dias: <b>", geo$dias_pico, "</b><br>",
  "<span style='font-size:10px;color:#666;'>", geo$donde, "</span>",
  "<hr style='margin:4px 0;border-color:#ddd;'>",

  # Extorsion
  "<b>Extorsion:</b> ", format(geo$eventos_ancla, big.mark = ","),
  " eventos (<b style='color:#ff7f00;'>", geo$ancla_pct,
  "%</b> del total regional en esos meses)<br>",
  "<hr style='margin:4px 0;border-color:#ddd;'>",

  # Tasas relativas delitos
  "<b>Concentracion de delitos (% del total regional):</b><br>",
  geo$delitos_co, "<br>",
  "<hr style='margin:4px 0;border-color:#ddd;'>",

  # Operativos
  "<b>Operativos policiales (% del total regional):</b><br>",
  geo$ops_co, "<br>",
  "<hr style='margin:4px 0;border-color:#ddd;'>",

  # Indice
  "<table style='width:100%;font-size:12px;'>",
  "<tr><td>Delitos zona/periodo:</td><td align='right'><b>",
  format(geo$total_delitos, big.mark = ","), "</b></td></tr>",
  "<tr><td>Operativos:</td><td align='right'><b>",
  format(geo$total_ops, big.mark = ","), "</b></td></tr>",
  "<tr><td><b>Respuesta policial:</b></td><td align='right'><b style='font-size:14px;'>",
  sprintf("%.1f%%", geo$ratio_policial * 100), "</b>",
  semaforo, "</td></tr></table>",
  "<hr style='margin:4px 0;border-color:#ddd;'>",

  # Perfil empresarial
  "<b style='color:#2ca02c;'>Contexto empresarial (RM 2024):</b><br>",
  geo$emp_html,

  "</div>"
)

# ==============================================================================
# 6. Mapa Leaflet
# ==============================================================================

cat("Construyendo mapa...\n")

# Cargar localidades como overlay
loc_poly <- st_read("data/raw/localidades_bogota.geojson", quiet = TRUE)

m <- leaflet() %>%
  addProviderTiles(providers$CartoDB.DarkMatter, group = "Oscuro") %>%
  addProviderTiles(providers$CartoDB.Positron, group = "Claro") %>%
  addProviderTiles(providers$OpenStreetMap, group = "OSM") %>%
  setView(lng = -74.1, lat = 4.6, zoom = 10)

# Localidades como contorno de referencia
m <- m %>%
  addPolygons(
    data = loc_poly,
    group = "Localidades Bogota",
    fillColor = "transparent",
    fillOpacity = 0,
    color = "#ffffff",
    weight = 1,
    opacity = 0.4,
    label = ~LOCNOMBRE,
    labelOptions = labelOptions(
      style = list("color" = "#aaa", "font-size" = "10px"),
      noHide = TRUE, direction = "center", textOnly = TRUE
    )
  )

# Comunidades ordenadas por # poligonos (mayor primero)
grupos_orden <- geo %>%
  st_drop_geometry() %>%
  distinct(grupo, n_secciones) %>%
  arrange(desc(n_secciones)) %>%
  pull(grupo)

for (g in grupos_orden) {
  subset_g <- geo[geo$grupo == g, ]
  m <- m %>%
    addPolygons(
      data = subset_g,
      group = g,
      fillColor = ~color,
      fillOpacity = ~opacity,
      color = ~color,
      weight = 1.5,
      opacity = 0.8,
      popup = ~popup,
      highlightOptions = highlightOptions(
        weight = 3, color = "#ffffff",
        fillOpacity = 0.9, bringToFront = TRUE
      )
    )
}

# Controles
m <- m %>%
  addLayersControl(
    baseGroups = c("Oscuro", "Claro", "OSM"),
    overlayGroups = c("Localidades Bogota", grupos_orden),
    options = layersControlOptions(collapsed = FALSE)
  )

# Ocultar comunidades pequeñas por defecto (mostrar top 5)
for (g in grupos_orden[6:length(grupos_orden)]) {
  m <- m %>% hideGroup(g)
}

# Leyenda
m <- m %>%
  addLegend(
    position = "bottomright",
    colors = c("red", "orange", "#cccc00", "green"),
    labels = c("Resp. CRITICA (<10%)",
               "Resp. BAJA (10-13%)",
               "Resp. MEDIA (13-16%)",
               "Resp. ALTA (>16%)"),
    title = "Respuesta policial",
    opacity = 0.8
  )

# Titulo
m <- m %>%
  addControl(
    html = paste0(
      "<div style='background:rgba(0,0,0,0.85);color:white;padding:12px 18px;",
      "border-radius:8px;font-family:Arial;max-width:360px;'>",
      "<b style='font-size:16px;color:#ff7f00;'>Comunidades de Extorsion</b><br>",
      "<span style='font-size:11px;'>ChroNNet diarias + Louvain (Q=0.38, 16 comunidades)<br>",
      "Tasas relativas de co-ocurrencia cruzada<br>",
      "Perfil empresarial por localidad (RM 2024)<br>",
      "Region Metropolitana 2021-2024</span>",
      "</div>"
    ),
    position = "topleft"
  )

# ==============================================================================
# 7. Guardar
# ==============================================================================

out_path <- file.path(MAP_DIR, "comunidades_extorsion.html")
saveWidget(m, out_path, selfcontained = FALSE)
cat("\nMapa guardado:", out_path, "\n")
cat("Orden de comunidades (por # poligonos):\n")
cat(paste(grupos_orden, collapse = "\n"), "\n")
