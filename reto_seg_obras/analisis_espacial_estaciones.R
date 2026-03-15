# ══════════════════════════════════════════════════════════════════════════════
# ANÁLISIS ESPACIAL POR ESTACIÓN — METRO LÍNEA 1
# Variogramas anisotrópicos (4 dir.) por variable + resumen isotrópico
# + Análisis: ¿el patrón de inseguridad de una estación alcanza a las vecinas?
# Salida: output/analisis_estaciones_metro.pdf (una página por estación)
# ══════════════════════════════════════════════════════════════════════════════

library(sf)
library(gstat)
library(grDevices)

# ── CONFIGURACIÓN ─────────────────────────────────────────────────────────────
RADIO   <- 1000     # buffer por estación (m)
CUTOFF  <- 800      # cutoff variograma (m)
WIDTH   <- 90       # ancho de lag (m)
ANGULOS <- c(0, 45, 90, 135)
TOL_HOR <- 22.5
MIN_PTS <- 20

DIR_COLS <- c("0"="#1565C0","45"="#2E7D32","90"="#C62828","135"="#E65100")
DIR_LABS <- c("0"="Norte-Sur","45"="NE-Suroeste",
              "90"="Este-Oeste (↔ Metro)","135"="Noroeste-Sureste")

# ── DATOS ─────────────────────────────────────────────────────────────────────
cat("Cargando datos...\n")
hex <- readRDS("data/hex_grid_metro.rds")
suppressWarnings(hex_pts <- st_centroid(hex))
hex_pts <- hex_pts[, c("pred_percepcion","log_shoplifting",
                        "log_theft","log_extortion","geometry")]

est    <- st_read("data/estaciones_metro_l1.geojson", quiet=TRUE)
suppressWarnings(st_crs(est) <- 6247)
est_3116 <- st_transform(est, 3116)
suppressWarnings(cents <- st_centroid(est_3116))
est_df   <- st_drop_geometry(est)
# Ordenar por número
ord      <- order(as.integer(est_df$NUMERO))
cents    <- cents[ord, ]
est_df   <- est_df[ord, ]
est_df$label <- paste0("Estación ", est_df$NUMERO, " — ", est_df$RefName)

# ── DISTANCIAS ENTRE ESTACIONES CONSECUTIVAS ──────────────────────────────────
coords_est <- st_coordinates(cents)
n_est      <- nrow(cents)
dist_prev  <- c(NA, as.numeric(st_distance(cents[-n_est,], cents[-1,],
                                            by_element=TRUE)))
dist_next  <- c(dist_prev[-1], NA)
est_df$dist_prev <- round(dist_prev)   # distancia a estación anterior (m)
est_df$dist_next <- round(dist_next)   # distancia a estación siguiente (m)

cat("Distancias inter-estación:\n")
for (i in seq_len(n_est)) {
  cat(sprintf("  E%s: prev=%.0fm | next=%.0fm\n",
              est_df$NUMERO[i],
              ifelse(is.na(dist_prev[i]),0,dist_prev[i]),
              ifelse(is.na(dist_next[i]),0,dist_next[i])))
}

# ── VARIABLES ─────────────────────────────────────────────────────────────────
VAR_IDS    <- c("perc","shop","theft","extor")
VAR_COLS   <- c(perc="pred_percepcion", shop="log_shoplifting",
                theft="log_theft",       extor="log_extortion")
VAR_LABELS <- c(perc="Percepción de Seguridad\n(1 = muy inseguro, 5 = muy seguro)",
                shop="Hurto a Comercios\n(log del número de casos)",
                theft="Hurto a Personas\n(log del número de casos)",
                extor="Extorsión\n(log del número de casos)")
VAR_COLORS <- c(perc="#5C6BC0",shop="#E53935",theft="#FB8C00",extor="#2E7D32")

# ── HELPERS ────────────────────────────────────────────────────────────────────
fit_sph <- function(v, init_var) {
  f <- tryCatch(suppressWarnings(
    fit.variogram(v, vgm(max(init_var*.75,1e-6),"Sph",
                         CUTOFF*.5,max(init_var*.25,1e-6)))),
    error=function(e) NULL)
  if (!is.null(f) && (f$range[2]<=0 || !all(is.finite(f$psill)))) f <- NULL
  f
}

# Dibuja variograma anisotrópico (4 direcciones) con curvas e interpretación
draw_aniso_panel <- function(pts_local, col_name, var_color, var_label,
                             x_max, y_max_fixed=NULL) {
  col_data <- pts_local[[col_name]]
  init_v   <- var(col_data, na.rm=TRUE)

  v_dir <- suppressWarnings(
    variogram(as.formula(paste(col_name,"~ 1")),
              data=pts_local, alpha=ANGULOS, tol.hor=TOL_HOR,
              cutoff=x_max, width=WIDTH))

  all_g <- v_dir$gamma
  y_max <- if (!is.null(y_max_fixed)) y_max_fixed
           else max(all_g, na.rm=TRUE) * 1.22

  # Ajustar modelos por dirección
  fits_dir   <- setNames(vector("list",4), as.character(ANGULOS))
  ranges_dir <- setNames(rep(NA_real_,4),  as.character(ANGULOS))
  for (a in ANGULOS) {
    v_a <- v_dir[v_dir$dir.hor==a,]
    if (nrow(v_a)>3) {
      f_a <- fit_sph(v_a, init_v)
      if (!is.null(f_a)) {
        fits_dir[[as.character(a)]]   <- f_a
        ranges_dir[as.character(a)]   <- round(f_a$range[2])
      }
    }
  }

  rv    <- ranges_dir[!is.na(ranges_dir) & ranges_dir>0]
  ratio <- if (length(rv)>=2) round(max(rv)/min(rv),1) else NA

  # Plot base
  plot(NULL, xlim=c(0,x_max), ylim=c(0,y_max),
       xlab="Distancia (m)", ylab="Semivarianza",
       las=1, cex.axis=0.72,
       main=var_label, cex.main=0.82, font.main=2, col.main=var_color)

  d_seq <- seq(1, x_max, len=350)
  for (a in ANGULOS) {
    a_ch <- as.character(a)
    v_a  <- v_dir[v_dir$dir.hor==a,]
    if (nrow(v_a)==0) next
    points(v_a$dist, v_a$gamma, pch=19, col=DIR_COLS[a_ch], cex=0.75)
    f <- fits_dir[[a_ch]]
    if (!is.null(f)) {
      gln <- variogramLine(f, dist_vector=d_seq)
      lines(gln$dist, gln$gamma, col=DIR_COLS[a_ch], lwd=2.0)
      # Línea vertical punteada en el range
      abline(v=ranges_dir[a_ch], lty=3,
             col=adjustcolor(DIR_COLS[a_ch],0.55), lwd=0.9)
    }
  }

  # Ratio
  if (!is.na(ratio)) {
    usr <- par("usr")
    col_r <- if (ratio>1.5) "#B71C1C" else "gray40"
    text(usr[2]-x_max*0.02, y_max*0.97,
         paste0("anisotropía: ",ratio,"x"),
         col=col_r, cex=0.65, pos=2, font=if(ratio>1.5) 2 else 1)
  }

  # Leyenda compacta
  leg_txt <- paste0(DIR_LABS[as.character(ANGULOS)], ": ",
                    ifelse(is.na(ranges_dir),"—",paste0(ranges_dir,"m")))
  legend("bottomright", legend=leg_txt,
         col=DIR_COLS[as.character(ANGULOS)],
         lwd=2.0, pch=19, pt.cex=0.8,
         bty="o", cex=0.55, bg="white", box.col="gray80",
         y.intersp=0.95, inset=c(0.01,0.02),
         title="Dirección — Range")

  invisible(list(ranges_dir=ranges_dir, ratio=ratio))
}

# Dibuja variograma isotrópico de resumen con 4 variables superpuestas
draw_iso_summary <- function(pts_local, fits_iso_all, y_maxes) {

  # Normalizar cada variable a [0,1] para poder compararlas
  plot(NULL, xlim=c(0,CUTOFF), ylim=c(0,1.08),
       xlab="Distancia (m)",
       ylab="Semivarianza normalizada\n(0 = sin variación | 1 = máx. alcanzado)",
       las=1, cex.axis=0.72,
       main="RESUMEN ISOTRÓPICO\n(promedio de todas las direcciones)",
       cex.main=0.82, font.main=2, col.main="gray20")

  abline(h=1.0, lty=2, col="gray75", lwd=1.0)
  abline(h=0.5, lty=3, col="gray90", lwd=0.8)

  d_seq <- seq(1, CUTOFF, len=350)

  for (vid in VAR_IDS) {
    col_nm  <- VAR_COLS[vid]
    col_data <- pts_local[[col_nm]]
    v_iso   <- variogram(as.formula(paste(col_nm,"~ 1")),
                         data=pts_local, cutoff=CUTOFF, width=WIDTH)
    f_iso   <- fit_sph(v_iso, var(col_data,na.rm=TRUE))

    if (!is.null(f_iso)) {
      sill_v <- sum(f_iso$psill)
      # Puntos normalizados
      points(v_iso$dist, v_iso$gamma/sill_v,
             pch=19, col=adjustcolor(VAR_COLORS[vid],0.4), cex=0.70)
      # Curva normalizada
      gln <- variogramLine(f_iso, dist_vector=d_seq)
      lines(gln$dist, gln$gamma/sill_v, col=VAR_COLORS[vid], lwd=2.2)
      # Marcar range
      rng <- f_iso$range[2]
      abline(v=rng, lty=3, col=adjustcolor(VAR_COLORS[vid],0.6), lwd=1.0)
    }
  }

  legend("bottomright",
         legend=c("Percepción Seguridad","Hurto Comercios",
                  "Hurto Personas","Extorsión"),
         col=VAR_COLORS, lwd=2.2, pch=19, pt.cex=0.85,
         bty="o", cex=0.60, bg="white", box.col="gray80",
         inset=c(0.01,0.02))
}

# Panel de interpretación: ¿alcanza estaciones vecinas?
draw_interpretacion <- function(ranges_por_var, dist_prev, dist_next,
                                est_prev_name, est_next_name, n_pts) {

  par(mar=c(0,0,0,0))
  plot.new()
  plot.window(xlim=c(0,1), ylim=c(0,1))
  rect(0,0,1,1, col="#FAFAFA", border="gray85")

  # Título del panel
  text(0.5, 0.96, "¿QUÉ NOS DICE EL ANÁLISIS?",
       cex=0.85, font=2, col="#1A237E", adj=0.5)

  # ── Sección 1: ¿alcanza estaciones vecinas? ─────────────────────────
  text(0.03, 0.87, "Alcance espacial vs. distancia a estaciones vecinas:",
       cex=0.70, font=2, col="gray20", adj=0)

  y_row <- 0.79
  for (vid in VAR_IDS) {
    rng_v <- ranges_por_var[[vid]]
    if (is.null(rng_v) || all(is.na(rng_v))) next

    # Usar el mayor range entre las 4 direcciones
    rng_max <- max(rng_v, na.rm=TRUE)
    if (is.na(rng_max) || rng_max <= 0) next

    # Determinar alcance
    alcanza_prev <- !is.na(dist_prev) && rng_max >= dist_prev
    alcanza_next <- !is.na(dist_next) && rng_max >= dist_next

    col_var <- VAR_COLORS[vid]
    label_v <- gsub("\n.*","",VAR_LABELS[vid])

    # Indicador de color
    rect(0.03, y_row-0.030, 0.085, y_row+0.018,
         col=col_var, border=NA)

    txt_prev <- if (!is.na(dist_prev))
      paste0(ifelse(alcanza_prev,"✓ SÍ alcanza ","✗ NO alcanza "),
             est_prev_name," (",round(dist_prev),"m)")
    else "Primera estación de la línea"

    txt_next <- if (!is.na(dist_next))
      paste0(ifelse(alcanza_next,"✓ SÍ alcanza ","✗ NO alcanza "),
             est_next_name," (",round(dist_next),"m)")
    else "Última estación de la línea"

    text(0.10, y_row+0.010,
         paste0(label_v," (range max: ",round(rng_max),"m)"),
         cex=0.60, col="gray15", adj=0, font=2)
    text(0.10, y_row-0.018,
         paste0("  → ",txt_prev,"   |   ",txt_next),
         cex=0.55,
         col=if(alcanza_prev||alcanza_next) "#1B5E20" else "gray40",
         adj=0)
    y_row <- y_row - 0.095
  }

  # ── Sección 2: ¿Comparten fenómeno las estaciones vecinas? ───────────
  y_sec2 <- y_row - 0.02
  rect(0.03, y_sec2-0.005, 0.97, y_sec2+0.025, col="#E8EAF6", border=NA)
  text(0.03, y_sec2+0.010,
       "¿Las estaciones vecinas comparten el mismo fenómeno de inseguridad?",
       cex=0.68, font=2, col="#1A237E", adj=0)

  y_row2 <- y_sec2 - 0.045
  for (vid in VAR_IDS) {
    rng_v <- ranges_por_var[[vid]]
    if (is.null(rng_v) || all(is.na(rng_v))) next
    rng_max <- max(rng_v, na.rm=TRUE)
    if (is.na(rng_max) || rng_max<=0) next

    alcanza_alg <- (!is.na(dist_prev) && rng_max >= dist_prev) ||
                   (!is.na(dist_next) && rng_max >= dist_next)
    label_v <- gsub("\n.*","",VAR_LABELS[vid])

    msg <- if (alcanza_alg)
      paste0("SÍ: el patrón de '",label_v,"' se extiende hasta la siguiente estación.",
             "\n  Las áreas comparten el mismo entorno de inseguridad.")
    else
      paste0("NO: '",label_v,"' es un fenómeno LOCAL de esta estación.",
             "\n  La siguiente estación tiene su propio patrón independiente.")

    text(0.05, y_row2,
         paste0("• ",msg),
         cex=0.57,
         col=if(alcanza_alg)"#1B5E20" else "#B71C1C",
         adj=0)
    y_row2 <- y_row2 - 0.085
  }

  # Nota de muestra
  text(0.5, 0.03, paste0("Basado en ",n_pts," zonas hexagonales (200×200m) en buffer de 1km"),
       cex=0.52, col="gray55", adj=0.5)
}

# ══════════════════════════════════════════════════════════════════════════════
# GENERAR PDF
# ══════════════════════════════════════════════════════════════════════════════
cat("\nGenerando PDF...\n")

pdf("output/analisis_estaciones_metro.pdf",
    width  = 16,   # pulgadas
    height = 11,
    title  = "Análisis espacial de inseguridad — Metro Línea 1")

for (i in seq_len(n_est)) {

  est_id    <- est_df$NUMERO[i]
  est_name  <- est_df$RefName[i]
  est_label <- est_df$label[i]
  d_prev    <- est_df$dist_prev[i]
  d_next    <- est_df$dist_next[i]
  prev_name <- if (!is.na(d_prev) && i>1) est_df$RefName[i-1] else NA
  next_name <- if (!is.na(d_next) && i<n_est) est_df$RefName[i+1] else NA

  cat(sprintf("  Página %d/%d: %s\n", i, n_est, est_label))

  # Hexágonos en buffer
  buf <- st_buffer(cents[i,], RADIO)
  suppressWarnings(idx <- st_intersects(hex_pts, buf, sparse=FALSE)[,1])
  pts_local <- hex_pts[idx,]

  if (nrow(pts_local) < MIN_PTS) {
    # Página en blanco con nota
    par(mar=c(0,0,0,0), bg="white")
    plot.new()
    text(0.5,0.5, paste0(est_label,"\nInsuficientes datos (n=",nrow(pts_local),")"),
         cex=1.2, col="gray50", adj=0.5)
    next
  }

  # ── LAYOUT: 2 filas × 3 col + 1 fila extra para iso+interp ──────────
  # Fila 1: [Perc-aniso] [Shop-aniso] [Theft-aniso]
  # Fila 2: [Extor-aniso] [ISO resumen] [Interpretación]
  layout(matrix(c(1,2,3,
                   4,5,6), 2, 3, byrow=TRUE),
         widths=c(1,1,1), heights=c(1,1))

  par(mar=c(3.8,4.5,5.0,1.2),
      oma=c(0.5,0,5.5,0),
      bg="white",
      mgp=c(2.5,0.7,0),
      tcl=-0.35)

  # Guardar ranges por variable para el panel de interpretación
  ranges_all <- setNames(vector("list",4), VAR_IDS)

  # Fila 1: Percepción, Hurto Comercio, Hurto Personas
  for (vi in 1:3) {
    vid  <- VAR_IDS[vi]
    res  <- draw_aniso_panel(pts_local, VAR_COLS[vid],
                              VAR_COLORS[vid], VAR_LABELS[vid], CUTOFF)
    ranges_all[[vid]] <- res$ranges_dir
  }

  # Fila 2: Extorsión, ISO resumen, Interpretación
  res_ex <- draw_aniso_panel(pts_local, VAR_COLS["extor"],
                              VAR_COLORS["extor"], VAR_LABELS["extor"], CUTOFF)
  ranges_all[["extor"]] <- res_ex$ranges_dir

  draw_iso_summary(pts_local, NULL, NULL)

  draw_interpretacion(ranges_all, d_prev, d_next,
                      prev_name, next_name, nrow(pts_local))

  # ── Títulos globales ──────────────────────────────────────────────────
  mtext(est_label,
        outer=TRUE, side=3, line=4.2, cex=1.35, font=2, col="#1A237E")
  mtext("Variogramas anisotrópicos (4 direcciones) + resumen isotrópico | Modelo Esférico (Sph)",
        outer=TRUE, side=3, line=3.0, cex=0.82, col="gray30")
  mtext(paste0("Percepción de Seguridad  ·  Hurto a Comercios  ·  Hurto a Personas  ·  Extorsión",
               "   |   Buffer: 1km  |  N = ",nrow(pts_local)," zonas"),
        outer=TRUE, side=3, line=1.8, cex=0.75, col="gray40")
  mtext(paste0("Estación ",i," de ",n_est," en la Línea 1 del Metro de Bogotá",
               "   |   Corredor 2021-2023"),
        outer=TRUE, side=3, line=0.7, cex=0.70, col="gray55")
}

dev.off()
cat("PDF guardado: output/analisis_estaciones_metro.pdf\n")

# Abrir el PDF
system("open output/analisis_estaciones_metro.pdf")
cat("Listo.\n")
