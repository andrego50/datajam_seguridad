# ══════════════════════════════════════════════════════════════════════════════
# VARIOGRAMAS ANTES vs DURANTE LA OBRA — METRO LÍNEA 1
# Estructura por variable:
#   Col izquierda : ANTES (2018-2020) — 4 direcciones cardinales
#   Col derecha   : DURANTE (2021-2023) — 4 direcciones cardinales
# Último panel   : ISOTRÓPICO de resumen (promedio de todas las direcciones)
# ══════════════════════════════════════════════════════════════════════════════

library(sf)
library(gstat)

CUTOFF  <- 2500   # metros — corredor completo
WIDTH   <- 220    # ancho de lag
ANGULOS <- c(0, 45, 90, 135)
TOL_HOR <- 22.5

DIR_COLS <- c("0"="#1565C0", "45"="#43A047", "90"="#E53935", "135"="#FB8C00")
DIR_LABS <- c("0"="N-S (0°)", "45"="NE-SO (45°)",
              "90"="E-O (90°) ← Metro", "135"="NO-SE (135°)")

cat("Cargando datos...\n")
hex <- readRDS("data/hex_grid_metro.rds")
suppressWarnings(pts <- st_centroid(hex))

# Log del período antes
pts$log_shop_pre  <- log(pts$shoplifting_pre + 1)
pts$log_theft_pre <- log(pts$theft_pre       + 1)
pts$log_extor_pre <- log(pts$extortion_pre   + 1)

# ── Definición de variables ────────────────────────────────────────────────────
VARS <- list(
  list(label="Hurto a Comercio",  antes="log_shop_pre",
       durante="log_shoplifting", color="#E53935"),
  list(label="Hurto a Personas",  antes="log_theft_pre",
       durante="log_theft",       color="#FB8C00"),
  list(label="Extorsión",         antes="log_extor_pre",
       durante="log_extortion",   color="#43A047"),
  list(label="Percepción de Seguridad (1-5)",
       antes=NULL, durante="pred_percepcion", color="#5C6BC0")
)

# ── Helpers ────────────────────────────────────────────────────────────────────
fit_sph <- function(v, init_var) {
  f <- tryCatch(suppressWarnings(
    fit.variogram(v, vgm(max(init_var*.75,1e-6), "Sph",
                         CUTOFF*.45, max(init_var*.25,1e-6)))),
    error=function(e) NULL)
  if (!is.null(f) && (f$range[2]<=0 || !all(is.finite(f$psill)))) f <- NULL
  f
}

# Dibuja un panel con 4 curvas direccionales superpuestas
draw_aniso <- function(pts, col_name, var_color, titulo, periodo_label) {

  col_data <- pts[[col_name]]
  init_v   <- var(col_data, na.rm=TRUE)

  # Variograma isotrópico (para escala Y)
  v_iso <- variogram(as.formula(paste(col_name,"~ 1")),
                     data=pts, cutoff=CUTOFF, width=WIDTH)
  f_iso <- fit_sph(v_iso, init_v)
  y_max <- max(v_iso$gamma, na.rm=TRUE) * 1.20

  # Variograma direccional
  v_dir <- suppressWarnings(
    variogram(as.formula(paste(col_name,"~ 1")),
              data=pts, alpha=ANGULOS, tol.hor=TOL_HOR,
              cutoff=CUTOFF, width=WIDTH))

  # Ajustar modelo por dirección
  fits_dir <- setNames(vector("list",4), as.character(ANGULOS))
  ranges_d <- setNames(rep(NA_real_,4),  as.character(ANGULOS))
  for (a in ANGULOS) {
    v_a <- v_dir[v_dir$dir.hor==a,]
    if (nrow(v_a)>3) {
      f_a <- fit_sph(v_a, init_v)
      if (!is.null(f_a)) { fits_dir[[as.character(a)]] <- f_a
                           ranges_d[as.character(a)]   <- round(f_a$range[2]) }
    }
  }

  # Ratio de anisotropía
  rv <- ranges_d[!is.na(ranges_d) & ranges_d > 0]
  ratio <- if (length(rv)>=2) round(max(rv)/min(rv),1) else NA

  # ── PLOT ────────────────────────────────────────────────────────────────
  plot(NULL,
       xlim=c(0,CUTOFF), ylim=c(0,y_max),
       xlab="Distancia (m)", ylab="Semivarianza",
       las=1, cex.axis=0.75,
       main=titulo, cex.main=0.90, font.main=2, col.main="#880000")

  mtext(periodo_label, side=3, line=0.1, cex=0.72,
        col=ifelse(grepl("ANTES",periodo_label),"#37474F","#1A237E"), font=2)

  # Puntos y curvas por dirección
  d_seq <- seq(1, CUTOFF, len=400)
  for (a in ANGULOS) {
    a_ch <- as.character(a)
    v_a  <- v_dir[v_dir$dir.hor==a,]
    if (nrow(v_a)==0) next
    points(v_a$dist, v_a$gamma, pch=19, col=DIR_COLS[a_ch], cex=0.80)
    f <- fits_dir[[a_ch]]
    if (!is.null(f)) {
      gln <- variogramLine(f, dist_vector=d_seq)
      lines(gln$dist, gln$gamma, col=DIR_COLS[a_ch], lwd=2.2)
      # Marcar range con línea vertical punteada
      abline(v=ranges_d[a_ch], lty=3, col=adjustcolor(DIR_COLS[a_ch],0.7), lwd=1)
    }
  }

  # Ratio en esquina superior derecha
  if (!is.na(ratio)) {
    usr <- par("usr")
    label_ratio <- paste0("ratio=",ratio,"x")
    col_ratio   <- if (ratio>1.5) "#C62828" else "gray40"
    text(usr[2]-CUTOFF*0.03, y_max*0.96, label_ratio,
         col=col_ratio, cex=0.72, pos=2, font=2)
  }

  # Leyenda compacta con ranges
  leg_txt <- paste0(DIR_LABS[as.character(ANGULOS)],
                    " — ", ifelse(is.na(ranges_d), "?", paste0(ranges_d,"m")))
  legend("bottomright", legend=leg_txt,
         col=DIR_COLS[as.character(ANGULOS)], lwd=2.2, pch=19, pt.cex=0.9,
         bty="o", cex=0.58, bg="white", box.col="gray80",
         y.intersp=1.0, inset=c(0.01,0.01))

  invisible(list(f_iso=f_iso, ranges_d=ranges_d, ratio=ratio, y_max=y_max))
}

# Dibuja panel isotrópico de resumen
draw_iso_resumen <- function(pts, col_name, var_color, var_label, periodo) {
  col_data <- pts[[col_name]]
  init_v   <- var(col_data, na.rm=TRUE)
  v_iso    <- variogram(as.formula(paste(col_name,"~ 1")),
                        data=pts, cutoff=CUTOFF, width=WIDTH)
  f_iso    <- fit_sph(v_iso, init_v)
  y_max    <- max(v_iso$gamma, na.rm=TRUE) * 1.20

  plot(v_iso$dist, v_iso$gamma,
       xlim=c(0,CUTOFF), ylim=c(0,y_max),
       xlab="Distancia (m)", ylab="Semivarianza",
       pch=19, col=var_color, cex=1.0, las=1, cex.axis=0.75,
       main=paste0(var_label,"\n(ISOTRÓPICO — promedio de todas las direcciones)"),
       cex.main=0.78, font.main=2, col.main=var_color)

  mtext(paste0("Período: ",periodo), side=3, line=0.1, cex=0.70, col="gray40")

  if (!is.null(f_iso)) {
    d_seq <- seq(1, CUTOFF, len=400)
    gln   <- variogramLine(f_iso, dist_vector=d_seq)
    lines(gln$dist, gln$gamma, col=var_color, lwd=2.5)
    nug  <- f_iso$psill[1]; sill <- sum(f_iso$psill); rng <- f_iso$range[2]
    abline(h=sill, lty=2, col="gray55", lwd=1.2)
    abline(v=rng,  lty=3, col=var_color, lwd=1.2)
    usr <- par("usr")
    text(CUTOFF*.02, sill+y_max*.06, paste0("Sill=",round(sill,2)),
         col="gray25", cex=0.70, pos=4)
    text(CUTOFF*.02, nug+y_max*.06, paste0("Nugget=",round(nug,2)),
         col="gray25", cex=0.70, pos=4)
    text(rng-CUTOFF*.02, y_max*.22, paste0(round(rng),"m"),
         col=var_color, cex=0.72, pos=2, font=2)
  } else {
    usr <- par("usr")
    text(mean(usr[1:2]), mean(usr[3:4]),
         "Sin datos para este período", cex=0.80, col="gray55", font=3)
  }
}

# ══════════════════════════════════════════════════════════════════════════════
# GENERAR PLOTS POR VARIABLE
# Cada variable → 1 PNG con: ANTES-aniso | DURANTE-aniso | ISO resumen
# ══════════════════════════════════════════════════════════════════════════════
cat("Generando plots por variable...\n")

for (vv in VARS) {
  cat("  →", vv$label, "\n")

  # Determinar layout: 3 paneles si hay antes, 2 si no
  tiene_antes <- !is.null(vv$antes)
  n_col <- if (tiene_antes) 3 else 2

  png_name <- paste0("output/var_",
                     gsub("[^A-Za-z0-9]","_",
                          gsub("\n.*","",vv$label)), ".png")

  png(png_name,
      width  = if (tiene_antes) 1900 else 1300,
      height = 680, res = 125)

  par(mfrow=c(1, n_col),
      mar=c(4.2, 4.8, 5.5, 1.5),
      oma=c(1, 0, 4.5, 0),
      bg="white")

  if (tiene_antes)
    draw_aniso(pts, vv$antes,   vv$color, vv$label, "ANTES  (2018 – 2020)")
  draw_aniso(pts, vv$durante, vv$color, vv$label, "DURANTE  (2021 – 2023)")
  draw_iso_resumen(pts, vv$durante, vv$color,
                   gsub("\n.*","",vv$label), "DURANTE (2021–2023)")

  mtext(paste0(gsub("\n.*","",vv$label),
               " — Variogramas esféricos, Corredor Metro L1"),
        outer=TRUE, side=3, line=3.2, cex=1.05, font=2, col="#1A237E")
  mtext(if (tiene_antes)
          "Izq: ANTES (anisotrópico) | Centro: DURANTE (anisotrópico) | Der: DURANTE (isotrópico = promedio)"
        else
          "Izq: DURANTE (anisotrópico) | Der: DURANTE (isotrópico = promedio de todas las direcciones)",
        outer=TRUE, side=3, line=1.8, cex=0.75, col="gray35")
  mtext("Modelo Esférico (Sph) | WLS | 4 dir.: N-S, NE-SO, E-O, NO-SE (tol ±22.5°) | Cutoff: 2500m",
        outer=TRUE, side=3, line=0.7, cex=0.68, col="gray55")

  dev.off()
  cat("    Guardado:", png_name, "\n")
}

# ══════════════════════════════════════════════════════════════════════════════
# RESUMEN FINAL: isotrópicos de todas las variables en un solo plot
# ══════════════════════════════════════════════════════════════════════════════
cat("Generando resumen final...\n")

png("output/variograma_resumen_iso.png", width=1600, height=800, res=125)

par(mfrow=c(2,4),
    mar=c(4, 4.5, 4.5, 1),
    oma=c(1,0,5,0),
    bg="white")

for (vv in VARS) {
  # Antes (si existe)
  if (!is.null(vv$antes)) {
    draw_iso_resumen(pts, vv$antes, adjustcolor(vv$color,0.6),
                     gsub("\n.*","",vv$label), "ANTES (2018–2020)")
  } else {
    plot.new(); plot.window(xlim=c(0,1), ylim=c(0,1))
    rect(0,0,1,1,col="#F5F5F5",border=NA)
    text(0.5,0.55, gsub("\n.*","",vv$label), cex=0.80, font=2,
         col=vv$color, adj=0.5)
    text(0.5,0.35,"Sin datos pre-obra",cex=0.72,col="gray50",adj=0.5)
  }
  # Durante
  draw_iso_resumen(pts, vv$durante, vv$color,
                   gsub("\n.*","",vv$label), "DURANTE (2021–2023)")
}

mtext("RESUMEN — Variogramas isotrópicos (promedio de todas las direcciones)",
      outer=TRUE, side=3, line=3.5, cex=1.05, font=2, col="#1A237E")
mtext("Cada variograma promedia los pares de puntos sin importar la orientación geográfica",
      outer=TRUE, side=3, line=2.2, cex=0.82, col="gray30")
mtext("Fila superior: ANTES de la obra (2018–2020) | Fila inferior: DURANTE la obra (2021–2023)",
      outer=TRUE, side=3, line=1.0, cex=0.75, col="gray45", font=2)

dev.off()
cat("Guardado: output/variograma_resumen_iso.png\n")
cat("\n══ FIN ══\n")
cat("Plots individuales: output/var_*.png\n")
cat("Resumen isotrópico: output/variograma_resumen_iso.png\n")
