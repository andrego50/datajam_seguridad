# ══════════════════════════════════════════════════════════════════════════════
# VARIOGRAMAS POR ESTACIÓN — METRO LÍNEA 1
# Para cada estación y cada variable:
#   - Panel ISOTRÓPICO (todos los pares, sin distinguir dirección)
#   - Panel ANISOTRÓPICO (4 direcciones cardinales: 0°, 45°, 90°, 135°)
# Más: 6 cross-variogramas entre variables con interpretación
# Modelo: Esférico (Sph) ajustado por WLS
# ══════════════════════════════════════════════════════════════════════════════

library(sf)
library(gstat)
library(dplyr)

# ── CONFIGURACIÓN ─────────────────────────────────────────────────────────────
RADIO     <- 1000   # radio (m) del buffer por estación
CUTOFF    <- 750    # distancia máxima variograma (m)
WIDTH     <- 90     # ancho de cada lag (m)
MIN_PTS   <- 25     # mínimo de hexágonos
ANGULOS   <- c(0, 45, 90, 135)
TOL_HOR   <- 22.5
DIR_COLS  <- c("0"  = "#1565C0",   # Norte-Sur
               "45" = "#43A047",   # NE-SW
               "90" = "#E53935",   # Este-Oeste (≈ Metro)
               "135"= "#FB8C00")   # NO-SE
DIR_LABS  <- c("0"  = "N-S (0°)",
               "45" = "NE-SW (45°)",
               "90" = "E-O (90°) ← Metro",
               "135"= "NO-SE (135°)")

dir.create("output/variogramas_estaciones", showWarnings = FALSE, recursive = TRUE)

# ── DATOS ─────────────────────────────────────────────────────────────────────
cat("Cargando datos...\n")
hex     <- readRDS("data/hex_grid_metro.rds")
suppressWarnings(hex_pts <- st_centroid(hex))
hex_pts <- hex_pts[, c("pred_percepcion", "log_shoplifting",
                        "log_theft", "log_extortion", "geometry")]

# ── ESTACIONES ─────────────────────────────────────────────────────────────────
est <- st_read("data/estaciones_metro_l1.geojson", quiet = TRUE)
suppressWarnings(st_crs(est) <- 6247)
est_3116 <- st_transform(est, 3116)
suppressWarnings(cents <- st_centroid(est_3116))
est_df <- st_drop_geometry(est)
est_df$label <- paste0("E", formatC(as.integer(est_df$NUMERO), width=2, flag="0"),
                        " — ", est_df$RefName)

# ── VARIABLES ─────────────────────────────────────────────────────────────────
VAR_IDS    <- c("perc", "shop", "theft", "extor")
VAR_COLS   <- c(perc="pred_percepcion", shop="log_shoplifting",
                theft="log_theft",       extor="log_extortion")
VAR_LABELS <- c(perc="Percepción Seguridad (1-5)",
                shop="Hurto a Comercio (log)",
                theft="Hurto a Personas (log)",
                extor="Extorsión (log)")
VAR_COLORS <- c(perc="#5C6BC0", shop="#E53935", theft="#FB8C00", extor="#43A047")

CROSS_PAIRS  <- list(c("perc","shop"), c("perc","theft"), c("perc","extor"),
                     c("shop","theft"), c("shop","extor"), c("theft","extor"))
CROSS_LABELS <- c("Percepción × H.Comercio",
                  "Percepción × H.Personas",
                  "Percepción × Extorsión",
                  "H.Comercio × H.Personas",
                  "H.Comercio × Extorsión",
                  "H.Personas × Extorsión")
CROSS_COLORS <- c("#7E57C2","#7986CB","#66BB6A","#FF7043","#8D6E63","#FFCA28")

# ── HELPERS ───────────────────────────────────────────────────────────────────
fit_sph <- function(v, init_var) {
  # Silenciar warnings de convergencia (son informativos, no fatales)
  f <- tryCatch(
    suppressWarnings(
      fit.variogram(v, vgm(psill  = max(init_var * 0.75, 1e-6),
                           model  = "Sph",
                           range  = CUTOFF * 0.5,
                           nugget = max(init_var * 0.25, 1e-6)))
    ),
    error = function(e) NULL
  )
  # Validar que el fit sea usable (range > 0, psill finito)
  if (!is.null(f) && (f$range[2] <= 0 || !all(is.finite(f$psill)))) f <- NULL
  f
}

interp_cross <- function(val, id1, id2) {
  perc_inv <- (id1=="perc" || id2=="perc")
  if (is.na(val) || abs(val) < 1e-5) return("Sin estructura espacial compartida")
  if (val < 0) {
    if (perc_inv) "↓ Anti-corr: más crimen → peor percepción"
    else          "↓ Anti-corr: delitos NO co-ubicados"
  } else {
    if (perc_inv) "↑ Co-ubic: percepción y crimen juntos (paradójico)"
    else          "↑ Co-ubic: ambos delitos en las mismas zonas"
  }
}

# Dibuja un panel isotrópico
plot_iso <- function(v_iso, fit, col, var_label, x_max, y_max) {
  plot(v_iso$dist, v_iso$gamma,
       xlim=c(0,x_max), ylim=c(0,y_max),
       xlab="Distancia (m)", ylab="Semivarianza",
       pch=19, col=col, cex=0.85,
       las=1, cex.axis=0.68,
       main=paste0("ISO — ", var_label),
       cex.main=0.75, font.main=2, col.main=col)
  if (!is.null(fit)) {
    d <- seq(1e-3, x_max, len=300)
    gline <- variogramLine(fit, dist_vector=d)
    lines(gline$dist, gline$gamma, col=col, lwd=2.2)
    nug  <- fit$psill[1]; sill <- sum(fit$psill); rng <- fit$range[2]
    abline(h=sill, lty=2, col="gray60", lwd=0.9)
    abline(v=rng,  lty=3, col=col,     lwd=0.9)
    usr <- par("usr")
    text(usr[1]+(usr[2]-usr[1])*0.04, sill+y_max*0.07,
         paste0("S=",round(sill,2)), col="gray25", cex=0.58, pos=4)
    text(usr[1]+(usr[2]-usr[1])*0.04, nug+y_max*0.07,
         paste0("N=",round(nug,2)),  col="gray25", cex=0.58, pos=4)
    text(rng-x_max*0.03, y_max*0.25,
         paste0("R=",round(rng),"m"), col=col, cex=0.58, pos=2)
  } else {
    usr <- par("usr")
    text(mean(usr[1:2]), mean(usr[3:4]), "Sin ajuste", cex=0.7, col="gray50")
  }
}

# Dibuja un panel anisotrópico
plot_aniso <- function(v_dir, fits_dir, var_label, x_max, y_max, ratio_aniso) {
  plot(NULL, xlim=c(0,x_max), ylim=c(0,y_max),
       xlab="Distancia (m)", ylab="",
       las=1, cex.axis=0.68,
       main=paste0("ANISO — ", var_label),
       cex.main=0.75, font.main=2, col.main="#880000")

  for (a_ch in as.character(ANGULOS)) {
    v_i <- v_dir[v_dir$dir.hor == as.numeric(a_ch), ]
    if (nrow(v_i)==0) next
    points(v_i$dist, v_i$gamma, pch=19, col=DIR_COLS[a_ch], cex=0.75)
    f <- fits_dir[[a_ch]]
    if (!is.null(f)) {
      d <- seq(1e-3, x_max, len=300)
      gline <- variogramLine(f, dist_vector=d)
      lines(gline$dist, gline$gamma, col=DIR_COLS[a_ch], lwd=1.8)
    }
  }
  # Leyenda compacta
  leg_txt <- paste0(DIR_LABS[as.character(ANGULOS)])
  legend("bottomright", legend=leg_txt,
         col=DIR_COLS[as.character(ANGULOS)],
         lwd=1.8, pch=19, pt.cex=0.8, bty="o",
         cex=0.52, bg="white", box.col="gray80",
         y.intersp=0.95, inset=c(0.01,0.01))
  # Ratio de anisotropía en esquina superior derecha
  if (!is.na(ratio_aniso)) {
    usr <- par("usr")
    text(usr[2]-x_max*0.05, y_max*0.95,
         paste0("ratio=", ratio_aniso, "x"),
         col="#880000", cex=0.60, pos=2, font=2)
  }
}

# ── ALMACENAMIENTO DE RESULTADOS ──────────────────────────────────────────────
results <- data.frame(
  est_id=character(), est_name=character(), n_pts=integer(),
  range_perc=numeric(),  range_shop=numeric(),
  range_theft=numeric(), range_extor=numeric(),
  ratio_perc=numeric(),  ratio_shop=numeric(),
  ratio_theft=numeric(), ratio_extor=numeric(),
  nsr_perc=numeric(),    nsr_shop=numeric(),
  nsr_theft=numeric(),   nsr_extor=numeric(),
  cross_perc_shop=numeric(),  cross_perc_theft=numeric(),
  cross_perc_extor=numeric(), cross_shop_theft=numeric(),
  cross_shop_extor=numeric(), cross_theft_extor=numeric(),
  stringsAsFactors=FALSE
)

# ══════════════════════════════════════════════════════════════════════════════
# LOOP POR ESTACIÓN
# ══════════════════════════════════════════════════════════════════════════════
for (i in seq_len(nrow(cents))) {

  est_id    <- est_df$NUMERO[i]
  est_name  <- est_df$RefName[i]
  est_label <- est_df$label[i]
  cat(sprintf("\n[%02d/%02d] %s\n", i, nrow(cents), est_label))

  buf <- st_buffer(cents[i,], RADIO)
  suppressWarnings(idx <- st_intersects(hex_pts, buf, sparse=FALSE)[,1])
  pts <- hex_pts[idx,]

  if (nrow(pts) < MIN_PTS) {
    cat("  → Solo", nrow(pts), "pts — omitida\n"); next
  }
  cat("  N hexágonos:", nrow(pts), "\n")

  # ── VARIOGRAMAS DIRECTOS (iso + aniso por variable) ────────────────────
  v_iso_list  <- list()
  fit_iso_list <- list()
  v_dir_list  <- list()
  fits_dir_list <- list()
  ratio_list  <- setNames(rep(NA_real_, 4), VAR_IDS)

  for (vid in VAR_IDS) {
    col_nm <- VAR_COLS[vid]
    form   <- as.formula(paste(col_nm, "~ 1"))
    init_v <- var(pts[[col_nm]], na.rm=TRUE)

    # Isotrópico
    v_iso <- variogram(form, data=pts, cutoff=CUTOFF, width=WIDTH)
    v_iso_list[[vid]]   <- v_iso
    fit_iso_list[[vid]] <- fit_sph(v_iso, init_v)

    # Anisotrópico
    v_dir <- variogram(form, data=pts, alpha=ANGULOS,
                       tol.hor=TOL_HOR, cutoff=CUTOFF, width=WIDTH)
    v_dir_list[[vid]] <- v_dir

    fits_dir <- setNames(vector("list", 4), as.character(ANGULOS))
    ranges_d <- setNames(rep(NA_real_, 4), as.character(ANGULOS))
    for (a in ANGULOS) {
      a_ch <- as.character(a)
      v_a  <- v_dir[v_dir$dir.hor == a, ]
      if (nrow(v_a) > 3) {
        f <- tryCatch(fit_sph(v_a, init_v), error=function(e) NULL)
        if (!is.null(f)) { fits_dir[[a_ch]] <- f; ranges_d[a_ch] <- f$range[2] }
      }
    }
    fits_dir_list[[vid]] <- fits_dir

    rng_v <- ranges_d[!is.na(ranges_d) & ranges_d > 0]
    if (length(rng_v) >= 2)
      ratio_list[vid] <- round(max(rng_v) / min(rng_v), 1)
  }

  # ── CROSS-VARIOGRAMAS ──────────────────────────────────────────────────
  g_multi <- gstat(NULL, id="perc",  formula=pred_percepcion~1, data=pts)
  g_multi <- gstat(g_multi, id="shop",  formula=log_shoplifting~1, data=pts)
  g_multi <- gstat(g_multi, id="theft", formula=log_theft~1,       data=pts)
  g_multi <- gstat(g_multi, id="extor", formula=log_extortion~1,   data=pts)
  v_all <- suppressWarnings(variogram(g_multi, cutoff=CUTOFF, width=WIDTH))

  cross_results <- setNames(rep(NA_real_, 6), seq_along(CROSS_PAIRS))
  v_cross_list  <- list()
  fit_cross_list <- list()

  for (cp_i in seq_along(CROSS_PAIRS)) {
    id1 <- CROSS_PAIRS[[cp_i]][1]; id2 <- CROSS_PAIRS[[cp_i]][2]
    ckey <- paste0(id1,".",id2)
    v_c  <- v_all[v_all$id == ckey, ]
    v_cross_list[[cp_i]] <- v_c

    init_cov <- tryCatch(cov(pts[[VAR_COLS[id1]]], pts[[VAR_COLS[id2]]],
                              use="complete.obs"), error=function(e) 0)
    f_c <- tryCatch(
      suppressWarnings(
        fit.variogram(v_c,
                      vgm(psill=sign(init_cov)*max(abs(init_cov)*0.8,1e-6),
                          model="Sph", range=CUTOFF*0.5, nugget=0))
      ),
      error=function(e) NULL)
    if (!is.null(f_c) && (f_c$range[2] <= 0 || !all(is.finite(f_c$psill)))) f_c <- NULL
    fit_cross_list[[cp_i]] <- f_c

    if (!is.null(f_c)) cross_results[cp_i] <- sum(f_c$psill)
    else if (nrow(v_c)>0) cross_results[cp_i] <- mean(tail(v_c$gamma,3))
  }

  # ── ESCALAS COMUNES ────────────────────────────────────────────────────
  # Y_max para directos: por variable (cada par iso/aniso comparte escala)
  y_max_var <- setNames(numeric(4), VAR_IDS)
  for (vid in VAR_IDS) {
    y_max_var[vid] <- max(c(v_iso_list[[vid]]$gamma,
                             v_dir_list[[vid]]$gamma), na.rm=TRUE) * 1.15
  }

  # ── PLOT ──────────────────────────────────────────────────────────────
  png_path <- sprintf("output/variogramas_estaciones/%s_variogramas.png",
                      gsub("[^A-Za-z0-9]", "_", est_label))

  # Layout 4 × 4 = 16 celdas:
  # Fila 1: [Perc-iso] [Perc-aniso] [Shop-iso] [Shop-aniso]
  # Fila 2: [Theft-iso][Theft-aniso][Extor-iso][Extor-aniso]
  # Fila 3: [cross1]  [cross2]     [cross3]   [cross4]
  # Fila 4: [cross5]  [cross6]     [leyenda]  [notas]

  png(png_path, width=1800, height=1400, res=120)

  layout(matrix(1:16, 4, 4, byrow=TRUE),
         widths=rep(1,4), heights=c(1,1,1,1))

  par(mar=c(3.2,3.5,3.8,1.0), oma=c(1.5,0,5,0), bg="white",
      mgp=c(2.0,0.55,0), tcl=-0.3)

  # Fila 1: Percepción + Hurto Comercio
  for (vi in 1:2) {
    vid <- VAR_IDS[vi]
    ym  <- y_max_var[vid]
    plot_iso(v_iso_list[[vid]], fit_iso_list[[vid]],
             VAR_COLORS[vid], VAR_LABELS[vid], CUTOFF, ym)
    plot_aniso(v_dir_list[[vid]], fits_dir_list[[vid]],
               VAR_LABELS[vid], CUTOFF, ym, ratio_list[vid])
  }

  # Fila 2: Hurto Personas + Extorsión
  for (vi in 3:4) {
    vid <- VAR_IDS[vi]
    ym  <- y_max_var[vid]
    plot_iso(v_iso_list[[vid]], fit_iso_list[[vid]],
             VAR_COLORS[vid], VAR_LABELS[vid], CUTOFF, ym)
    plot_aniso(v_dir_list[[vid]], fits_dir_list[[vid]],
               VAR_LABELS[vid], CUTOFF, ym, ratio_list[vid])
  }

  # Normalizar cross-variogramas al rango [-1, +1]
  # ρ(h) = γ_cross(h) / sqrt(sill_v1 * sill_v2)
  # Esto los hace comparables como un coeficiente de correlación espacial
  get_sill <- function(fit, v_df) {
    if (!is.null(fit)) return(sum(fit$psill))
    if (nrow(v_df)>0) return(max(v_df$gamma, na.rm=TRUE))
    return(1)
  }

  # Filas 3-4: Cross-variogramas normalizados
  for (cp_i in seq_along(CROSS_PAIRS)) {
    id1 <- CROSS_PAIRS[[cp_i]][1]; id2 <- CROSS_PAIRS[[cp_i]][2]
    v_c   <- v_cross_list[[cp_i]]
    f_c   <- fit_cross_list[[cp_i]]
    col_c <- CROSS_COLORS[cp_i]

    # Denominador para normalización: sqrt(sill1 * sill2)
    s1 <- get_sill(fit_iso_list[[id1]], v_iso_list[[id1]])
    s2 <- get_sill(fit_iso_list[[id2]], v_iso_list[[id2]])
    denom <- sqrt(abs(s1) * abs(s2))
    if (is.na(denom) || denom == 0) denom <- 1

    # Normalizar puntos del variograma
    gamma_norm <- v_c$gamma / denom

    if (length(gamma_norm)>0 && any(is.finite(gamma_norm))) {
      ym_c <- min( max(abs(gamma_norm), na.rm=TRUE) * 1.3, 1.2)
      yn_c <- max(-ym_c, min(c(0, min(gamma_norm, na.rm=TRUE)*1.3)))
    } else { ym_c <- 1.0; yn_c <- -1.0 }

    # Etiqueta del eje Y explicita
    plot(v_c$dist, gamma_norm,
         xlim=c(0,CUTOFF), ylim=c(yn_c, ym_c),
         xlab="Distancia (m)",
         ylab="Correlación espacial\n(-1 a +1)",
         pch=17, col=col_c, cex=0.85, las=1, cex.axis=0.65,
         main=CROSS_LABELS[cp_i], cex.main=0.72, font.main=2, col.main=col_c)
    abline(h=0,    lty=1, col="gray70", lwd=1.2)
    abline(h= 0.5, lty=3, col="gray85", lwd=0.8)
    abline(h=-0.5, lty=3, col="gray85", lwd=0.8)

    if (!is.null(f_c)) {
      # Línea del modelo ajustado (también normalizada)
      d <- seq(1e-3, CUTOFF, len=300)
      gamma_model <- variogramLine(f_c, dist_vector=d)$gamma / denom
      lines(d, gamma_model, col=col_c, lwd=2)
      sc_norm <- sum(f_c$psill) / denom
      abline(h=sc_norm, lty=2, col="gray55", lwd=0.8)
      usr <- par("usr")
      text(usr[1]+(usr[2]-usr[1])*0.04, sc_norm,
           paste0("corr=", round(sc_norm,2)), col="gray25", cex=0.56, pos=3)
    } else if (nrow(v_c) >= 4) {
      # Si no hay modelo: línea LOESS de tendencia
      lo <- tryCatch(loess(gamma_norm ~ v_c$dist, span=0.75), error=function(e) NULL)
      if (!is.null(lo)) {
        d_pred <- seq(min(v_c$dist), max(v_c$dist), len=100)
        pred   <- predict(lo, newdata=data.frame(dist=d_pred))
        lines(d_pred, pred, col=col_c, lwd=2, lty=2)
        mtext("(tendencia loess — modelo no convergió)", side=3, line=-1.2,
              cex=0.50, col="gray55", adj=0.5)
      }
    }

    interp_txt <- interp_cross(cross_results[cp_i], id1, id2)
    mtext(interp_txt, side=1, line=-1.5, cex=0.54, col=col_c, font=3, adj=0.5)
  }

  # Celda 15 — Leyenda de colores de variables
  par(mar=c(0,0,0,0))
  plot.new()
  text(0.5, 0.95, "VARIABLES", cex=0.82, font=2, col="gray20")
  for (vi in seq_along(VAR_IDS)) {
    rect(0.05, 0.80-(vi-1)*0.16, 0.18, 0.88-(vi-1)*0.16,
         col=VAR_COLORS[VAR_IDS[vi]], border=NA)
    text(0.22, 0.84-(vi-1)*0.16, VAR_LABELS[VAR_IDS[vi]],
         cex=0.58, col="gray20", adj=0)
  }

  # Celda 16 — Notas metodológicas
  par(mar=c(0,0,0,0))
  plot.new()
  text(0.5, 0.97, "NOTAS", cex=0.80, font=2, col="gray20")
  notes <- c(
    "Modelo: Esférico (Sph)",
    "Ajuste: WLS ponderado",
    "  por n° de pares",
    paste0("Buffer: ", RADIO, "m | Cutoff: ", CUTOFF, "m"),
    paste0("Lag: ", WIDTH, "m | N=", nrow(pts), " hex"),
    "",
    "ISO = todos los pares",
    "ANISO = 4 dir. cardinales",
    "  tol. ±22.5°",
    "",
    "ratio > 1.5x = anisotropía",
    "  fuerte",
    "",
    "Cross + = co-ubicación",
    "Cross - = anti-correlación"
  )
  for (ni in seq_along(notes)) {
    text(0.08, 0.88-(ni-1)*0.057, notes[ni],
         cex=0.57, col=ifelse(notes[ni]=="","gray80","gray30"), adj=0)
  }

  # Título global
  mtext(est_label, outer=TRUE, side=3, line=3.5,
        cex=1.15, font=2, col="#1A237E")
  mtext("Variogramas isotrópicos y anisotrópicos — Corredor Metro L1, 2021-2023",
        outer=TRUE, side=3, line=2.2, cex=0.82, col="gray30")
  mtext("Fila 1-2: directos (ISO + 4 direcciones) | Fila 3-4: cross-variogramas entre variables",
        outer=TRUE, side=3, line=1.0, cex=0.70, col="gray50")

  dev.off()
  cat("  → Guardado:", basename(png_path), "\n")

  # ── GUARDAR RESULTADOS ────────────────────────────────────────────────
  get_r   <- function(f) if (!is.null(f)) round(f$range[2]) else NA_real_
  get_nsr <- function(f) if (!is.null(f)) round(f$psill[1]/sum(f$psill),3) else NA_real_

  results <- rbind(results, data.frame(
    est_id=est_id, est_name=est_name, n_pts=nrow(pts),
    range_perc =get_r(fit_iso_list[["perc"]]),
    range_shop =get_r(fit_iso_list[["shop"]]),
    range_theft=get_r(fit_iso_list[["theft"]]),
    range_extor=get_r(fit_iso_list[["extor"]]),
    ratio_perc =ratio_list["perc"],
    ratio_shop =ratio_list["shop"],
    ratio_theft=ratio_list["theft"],
    ratio_extor=ratio_list["extor"],
    nsr_perc =get_nsr(fit_iso_list[["perc"]]),
    nsr_shop =get_nsr(fit_iso_list[["shop"]]),
    nsr_theft=get_nsr(fit_iso_list[["theft"]]),
    nsr_extor=get_nsr(fit_iso_list[["extor"]]),
    cross_perc_shop  =round(cross_results[1],4),
    cross_perc_theft =round(cross_results[2],4),
    cross_perc_extor =round(cross_results[3],4),
    cross_shop_theft =round(cross_results[4],4),
    cross_shop_extor =round(cross_results[5],4),
    cross_theft_extor=round(cross_results[6],4),
    stringsAsFactors=FALSE
  ))
}

# ══════════════════════════════════════════════════════════════════════════════
# ANÁLISIS COMPARATIVO ENTRE ESTACIONES
# ══════════════════════════════════════════════════════════════════════════════
cat("\n\n══ ANÁLISIS COMPARATIVO ══\n\n")
if (nrow(results) == 0) { cat("Sin resultados.\n"); quit(save="no") }

sink("output/analisis_estaciones.txt")
cat("══════════════════════════════════════════════════════════════════════\n")
cat("ANÁLISIS DE VARIOGRAMAS POR ESTACIÓN — METRO LÍNEA 1\n")
cat("Modelo: Esférico (Sph) | WLS | Buffer:",RADIO,"m | Cutoff:",CUTOFF,"m\n")
cat("══════════════════════════════════════════════════════════════════════\n\n")

cat("══ RANGES ISOTRÓPICOS (m) ══\n")
cat(sprintf("%-30s %6s %8s %7s %7s\n","Estación","Perc","HComercio","HPers","Extors"))
cat(strrep("-",65),"\n")
for (j in seq_len(nrow(results))) {
  r <- results[j,]
  cat(sprintf("%-30s %6s %8s %7s %7s\n",
    substr(paste0("E",r$est_id," ",r$est_name),1,30),
    ifelse(is.na(r$range_perc)," NA",r$range_perc),
    ifelse(is.na(r$range_shop)," NA",r$range_shop),
    ifelse(is.na(r$range_theft)," NA",r$range_theft),
    ifelse(is.na(r$range_extor)," NA",r$range_extor)))
}
cat("\n")

cat("══ RATIO ANISOTROPÍA (range_max / range_min) ══\n")
cat("  > 1.5x = anisotropía fuerte | ≤ 1.5x = moderada\n\n")
cat(sprintf("%-30s %6s %8s %7s %7s\n","Estación","Perc","HComercio","HPers","Extors"))
cat(strrep("-",65),"\n")
for (j in seq_len(nrow(results))) {
  r <- results[j,]
  fmt <- function(x) ifelse(is.na(x)," NA",paste0(x,"x"))
  cat(sprintf("%-30s %6s %8s %7s %7s\n",
    substr(paste0("E",r$est_id," ",r$est_name),1,30),
    fmt(r$ratio_perc),fmt(r$ratio_shop),fmt(r$ratio_theft),fmt(r$ratio_extor)))
}
cat("\n")

cat("══ NUGGET/SILL (0=estructura pura, 1=ruido puro) ══\n")
cat(sprintf("%-30s %6s %8s %7s %7s\n","Estación","Perc","HComercio","HPers","Extors"))
cat(strrep("-",65),"\n")
for (j in seq_len(nrow(results))) {
  r <- results[j,]
  fmt <- function(x) ifelse(is.na(x)," NA",round(x,2))
  cat(sprintf("%-30s %6s %8s %7s %7s\n",
    substr(paste0("E",r$est_id," ",r$est_name),1,30),
    fmt(r$nsr_perc),fmt(r$nsr_shop),fmt(r$nsr_theft),fmt(r$nsr_extor)))
}
cat("\n")

cat("══ CROSS-VARIOGRAMAS (signo al sill) ══\n")
cat("  + = co-ubicación espacial | - = anti-correlación\n\n")
ccols <- c("cross_perc_shop","cross_perc_theft","cross_perc_extor",
           "cross_shop_theft","cross_shop_extor","cross_theft_extor")
cshor <- c("Pc×HC","Pc×HP","Pc×Ex","HC×HP","HC×Ex","HP×Ex")
cat(sprintf("%-30s", "Estación"))
for(cn in cshor) cat(sprintf("%8s",cn)); cat("\n",strrep("-",80),"\n")
for (j in seq_len(nrow(results))) {
  r <- results[j,]
  cat(sprintf("%-30s",substr(paste0("E",r$est_id," ",r$est_name),1,30)))
  for(cn in ccols) {
    v <- r[[cn]]
    cat(sprintf("%8s",ifelse(is.na(v)," NA",sprintf("%+.3f",v))))
  }
  cat("\n")
}
cat("\n")

# Hallazgos
cat("══ HALLAZGOS CLAVE ══\n\n")
avg_r <- colMeans(results[,c("range_perc","range_shop","range_theft","range_extor")],na.rm=TRUE)
cat("Range isotrópico promedio (m):\n")
cat(sprintf("  Percepción     : %5.0f m\n",avg_r[1]))
cat(sprintf("  Hurto Comercio : %5.0f m\n",avg_r[2]))
cat(sprintf("  Hurto Personas : %5.0f m\n",avg_r[3]))
cat(sprintf("  Extorsión      : %5.0f m\n\n",avg_r[4]))

aniso_strong <- function(col) sum(results[[col]] > 1.5, na.rm=TRUE)
cat("Estaciones con anisotropía FUERTE (ratio > 1.5x):\n")
cat(sprintf("  Percepción     : %d/16\n", aniso_strong("ratio_perc")))
cat(sprintf("  Hurto Comercio : %d/16\n", aniso_strong("ratio_shop")))
cat(sprintf("  Hurto Personas : %d/16\n", aniso_strong("ratio_theft")))
cat(sprintf("  Extorsión      : %d/16\n\n", aniso_strong("ratio_extor")))

n_neg_hp <- sum(results$cross_perc_theft < 0, na.rm=TRUE)
n_neg_hc <- sum(results$cross_perc_shop < 0, na.rm=TRUE)
cat(sprintf("Cross Percepción × H.Personas: %d/16 anti-corr | %d/16 co-ubic\n",
            n_neg_hp, nrow(results)-n_neg_hp))
cat(sprintf("Cross Percepción × H.Comercio: %d/16 anti-corr | %d/16 co-ubic\n\n",
            n_neg_hc, nrow(results)-n_neg_hc))

cat("══ EXPLICACIÓN DEL GRÁFICO ══\n\n")
cat("Cada PNG de estación tiene 4 filas y 4 columnas (16 paneles):\n\n")
cat("FILAS 1 y 2 — Variogramas directos por variable (8 paneles):\n")
cat("  Para cada variable (Percepción, H.Comercio, H.Personas, Extorsión)\n")
cat("  hay 2 paneles lado a lado:\n")
cat("  • Panel ISO (izquierda): variograma isotrópico — usa TODOS los pares\n")
cat("    de puntos sin importar la dirección. Da un resumen promedio de la\n")
cat("    correlación espacial. Muestra el range (R), sill (S) y nugget (N)\n")
cat("    del modelo esférico ajustado.\n")
cat("  • Panel ANISO (derecha): variograma direccional — calcula por separado\n")
cat("    los pares en 4 orientaciones (N-S=0°, NE-SW=45°, E-O=90°, NO-SE=135°)\n")
cat("    cada una con tolerancia ±22.5°. Si las curvas difieren entre sí,\n")
cat("    hay anisotropía: la correlación espacial varía según la dirección.\n")
cat("    El ratio en la esquina superior derecha = range_max/range_min.\n\n")
cat("FILAS 3 y 4 — Cross-variogramas (6 paneles + 2 de leyenda/notas):\n")
cat("  Miden la co-varianza espacial entre DOS variables distintas:\n")
cat("  • Signo POSITIVO (+): las variables tienden a ser altas (o bajas)\n")
cat("    en las mismas zonas → co-ubicación espacial.\n")
cat("  • Signo NEGATIVO (-): cuando una es alta, la otra tiende a ser baja\n")
cat("    en las mismas zonas → anti-correlación espacial.\n")
cat("  Para Percepción × Crimen: signo negativo es el esperado (donde hay\n")
cat("  más crimen, la percepción de seguridad es peor).\n")
sink()
cat("Análisis guardado: output/analisis_estaciones.txt\n")

# ── PLOT COMPARATIVO ──────────────────────────────────────────────────────────
if (nrow(results) >= 3) {
  png("output/analisis_estaciones.png", width=1500, height=950, res=120)
  par(mfrow=c(1,2), mar=c(5,8.5,4,1.5), oma=c(1,0,4,0), bg="white")

  # Panel 1: Ranges
  y_pos <- seq_len(nrow(results))
  lbs   <- paste0("E",results$est_id," ",substr(results$est_name,1,18))
  r_max <- max(c(results$range_perc,results$range_shop,
                  results$range_theft,results$range_extor), na.rm=TRUE)
  r_cap <- min(r_max, CUTOFF * 1.1)

  plot(NULL, xlim=c(0,r_cap), ylim=c(0.5,nrow(results)+0.5),
       xlab="Range isotrópico (m)", ylab="", las=1, yaxt="n")
  axis(2, at=y_pos, labels=rev(lbs), las=2, cex.axis=0.65)
  abline(h=y_pos, col="gray93", lwd=0.8)
  abline(v=CUTOFF, lty=2, col="gray60", lwd=1)
  text(CUTOFF+5, nrow(results)*0.5, "Cutoff", cex=0.55, col="gray50", srt=90, adj=0)

  vars4 <- c("range_perc","range_shop","range_theft","range_extor")
  offs  <- c(-0.3,-0.1,0.1,0.3)
  for (vi in seq_along(vars4)) {
    vals <- pmin(rev(results[[vars4[vi]]]), r_cap)
    points(vals, y_pos+offs[vi], pch=19, col=VAR_COLORS[VAR_IDS[vi]], cex=1.0)
    segments(0, y_pos+offs[vi], vals, y_pos+offs[vi],
             col=adjustcolor(VAR_COLORS[VAR_IDS[vi]],0.35), lwd=1.5)
  }
  legend("bottomright", inset=c(0.01,0.01),
         legend=VAR_LABELS, col=VAR_COLORS, pch=19, lwd=1.5,
         bty="o", cex=0.68, bg="white", box.col="gray80")
  title(main="Range isotrópico por estación", cex.main=0.95, font.main=2)

  # Panel 2: Heatmap cross-variogramas
  cc <- c("cross_perc_shop","cross_perc_theft","cross_perc_extor",
          "cross_shop_theft","cross_shop_extor","cross_theft_extor")
  cs <- c("Pc×HC","Pc×HP","Pc×Ex","HC×HP","HC×Ex","HP×Ex")
  mat <- as.matrix(results[,cc])
  rownames(mat) <- paste0("E",results$est_id)
  n_r <- nrow(mat); n_c <- ncol(mat)
  mx  <- max(abs(mat), na.rm=TRUE)

  ccol <- function(v) {
    if (is.na(v)) return("gray85")
    if (v<0) colorRampPalette(c("white","#1565C0"))(100)[round((-v/mx)*99)+1]
    else     colorRampPalette(c("white","#C62828"))(100)[round((v/mx)*99)+1]
  }

  plot(NULL, xlim=c(0.5,n_c+0.5), ylim=c(0.5,n_r+0.5),
       xlab="Par de variables", ylab="", xaxt="n", yaxt="n")
  axis(1, at=1:n_c, labels=cs, cex.axis=0.70, las=1)
  axis(2, at=1:n_r, labels=rev(paste0("E",results$est_id)), las=2, cex.axis=0.72)
  for (ri in 1:n_r) for (ci in 1:n_c) {
    v <- mat[ri,ci]
    rect(ci-.45,(n_r-ri+1)-.45,ci+.45,(n_r-ri+1)+.45,
         col=ccol(v), border="white", lwd=0.4)
    if (!is.na(v)) text(ci,n_r-ri+1,sprintf("%+.2f",v),cex=0.50,col="gray10")
  }
  mtext("Cross-variograma al sill\n(azul = anti-corr | rojo = co-ubic)",
        side=3, line=1.5, cex=0.75, font=2)

  mtext("Análisis comparativo — 16 Estaciones Metro L1",
        outer=TRUE, side=3, line=2.6, cex=1.05, font=2, col="#1A237E")
  mtext("Percepción + 3 tipos de delito | Modelo Esférico (Sph) | Buffer 1000m",
        outer=TRUE, side=3, line=1.3, cex=0.78, col="gray30")
  dev.off()
  cat("Plot comparativo: output/analisis_estaciones.png\n")
}

cat("\n══ FIN ══\n")
cat("Estaciones procesadas:", nrow(results), "/ 16\n")
cat("Plots en: output/variogramas_estaciones/\n")
