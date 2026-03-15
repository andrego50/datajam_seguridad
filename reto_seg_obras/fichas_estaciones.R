# ══════════════════════════════════════════════════════════════════════════════
# FICHAS DE ESTACIÓN — versión para politólogos
# Sin jerga estadística. Responde 3 preguntas por estación:
#   1. ¿A cuántos metros se propaga la inseguridad?
#   2. ¿El crimen y la percepción van de la mano?
#   3. ¿El problema se extiende más a lo largo del metro o de forma perpendicular?
# ══════════════════════════════════════════════════════════════════════════════

library(sf)
library(gstat)
library(dplyr)

RADIO   <- 1000
CUTOFF  <- 750
WIDTH   <- 90
MIN_PTS <- 25
ANGULOS <- c(0, 45, 90, 135)
TOL_HOR <- 22.5

dir.create("output/fichas_estaciones", showWarnings = FALSE, recursive = TRUE)

# ── DATOS ─────────────────────────────────────────────────────────────────────
cat("Cargando datos...\n")
hex <- readRDS("data/hex_grid_metro.rds")
suppressWarnings(hex_pts <- st_centroid(hex))
hex_pts <- hex_pts[, c("pred_percepcion","log_shoplifting","log_theft","log_extortion","geometry")]

est <- st_read("data/estaciones_metro_l1.geojson", quiet=TRUE)
suppressWarnings(st_crs(est) <- 6247)
est_3116 <- st_transform(est, 3116)
suppressWarnings(cents <- st_centroid(est_3116))
est_df <- st_drop_geometry(est)
est_df$label <- paste0("E", formatC(as.integer(est_df$NUMERO), width=2, flag="0"),
                        " — ", est_df$RefName)

# ── PALETAS Y ETIQUETAS ───────────────────────────────────────────────────────
VAR_IDS    <- c("perc","shop","theft","extor")
VAR_COLS_D <- c(perc="pred_percepcion", shop="log_shoplifting",
                theft="log_theft",       extor="log_extortion")
VAR_LABELS <- c(perc ="Percepción de seguridad",
                shop ="Hurto a comercios",
                theft="Hurto a personas",
                extor="Extorsión")
VAR_COLORS <- c(perc="#5C6BC0", shop="#E53935", theft="#FB8C00", extor="#43A047")

CROSS_PAIRS  <- list(c("perc","shop"), c("perc","theft"), c("perc","extor"),
                     c("shop","theft"), c("shop","extor"), c("theft","extor"))
CROSS_LABELS <- c("Percepción ↔ Hurto comercios",
                  "Percepción ↔ Hurto personas",
                  "Percepción ↔ Extorsión",
                  "Hurto comercios ↔ Hurto personas",
                  "Hurto comercios ↔ Extorsión",
                  "Hurto personas ↔ Extorsión")

DIR_LABELS <- c("0"="N-S", "45"="NE-SO", "90"="E-O\n(Metro)", "135"="NO-SE")

# ── HELPER: AJUSTAR VARIOGRAMA ────────────────────────────────────────────────
fit_sph <- function(v, init_var) {
  f <- tryCatch(suppressWarnings(
    fit.variogram(v, vgm(max(init_var*.75,1e-6), "Sph",
                         CUTOFF*.5, max(init_var*.25,1e-6)))),
    error=function(e) NULL)
  if (!is.null(f) && (f$range[2]<=0 || !all(is.finite(f$psill)))) f <- NULL
  f
}

# Convierte el range a un texto legible y una señal de "qué tan lejos"
alcance_texto <- function(range_m, cutoff) {
  if (is.na(range_m)) return(list(txt="Sin patrón claro", col="gray60", bar=0))
  r <- min(range_m, cutoff)
  pct <- r / cutoff
  if (pct > 0.85) {
    list(txt=paste0(">", round(r), " m — muy amplio"), col="#C62828", bar=pct)
  } else if (pct > 0.5) {
    list(txt=paste0(round(r), " m — moderado"),        col="#EF6C00", bar=pct)
  } else {
    list(txt=paste0(round(r), " m — localizado"),      col="#2E7D32", bar=pct)
  }
}

# ── RESULTADOS GLOBALES ───────────────────────────────────────────────────────
all_results <- list()

# ══════════════════════════════════════════════════════════════════════════════
# LOOP POR ESTACIÓN
# ══════════════════════════════════════════════════════════════════════════════
for (i in seq_len(nrow(cents))) {

  est_id    <- est_df$NUMERO[i]
  est_name  <- est_df$RefName[i]
  est_label <- est_df$label[i]
  cat(sprintf("\n[%02d/16] %s\n", i, est_label))

  buf <- st_buffer(cents[i,], RADIO)
  suppressWarnings(idx <- st_intersects(hex_pts, buf, sparse=FALSE)[,1])
  pts <- hex_pts[idx,]
  if (nrow(pts) < MIN_PTS) { cat("  → Omitida\n"); next }
  cat("  N =", nrow(pts), "hexágonos\n")

  # ── Calcular variogramas ──────────────────────────────────────────────
  ranges_iso  <- setNames(rep(NA_real_,4), VAR_IDS)
  nsr_iso     <- setNames(rep(NA_real_,4), VAR_IDS)
  ranges_dir  <- setNames(vector("list",4), VAR_IDS)  # por variable: 4 rangos
  fit_iso_all <- list()

  for (vid in VAR_IDS) {
    form   <- as.formula(paste(VAR_COLS_D[vid], "~ 1"))
    init_v <- var(pts[[VAR_COLS_D[vid]]], na.rm=TRUE)

    v_iso <- variogram(form, data=pts, cutoff=CUTOFF, width=WIDTH)
    f_iso <- fit_sph(v_iso, init_v)
    fit_iso_all[[vid]] <- f_iso
    if (!is.null(f_iso)) {
      ranges_iso[vid] <- f_iso$range[2]
      nsr_iso[vid]    <- f_iso$psill[1] / sum(f_iso$psill)
    }

    # Direccional
    v_dir <- suppressWarnings(
      variogram(form, data=pts, alpha=ANGULOS, tol.hor=TOL_HOR,
                cutoff=CUTOFF, width=WIDTH))
    rd <- setNames(rep(NA_real_,4), as.character(ANGULOS))
    for (a in ANGULOS) {
      v_a <- v_dir[v_dir$dir.hor==a,]
      if (nrow(v_a)>3) {
        f_a <- fit_sph(v_a, init_v)
        if (!is.null(f_a)) rd[as.character(a)] <- f_a$range[2]
      }
    }
    ranges_dir[[vid]] <- rd
  }

  # ── Cross-variogramas ─────────────────────────────────────────────────
  g_multi <- gstat(NULL, id="perc",  formula=pred_percepcion~1, data=pts)
  g_multi <- gstat(g_multi, id="shop",  formula=log_shoplifting~1, data=pts)
  g_multi <- gstat(g_multi, id="theft", formula=log_theft~1,       data=pts)
  g_multi <- gstat(g_multi, id="extor", formula=log_extortion~1,   data=pts)
  v_all <- suppressWarnings(variogram(g_multi, cutoff=CUTOFF, width=WIDTH))

  cross_sign  <- setNames(rep(NA_real_,6), seq_along(CROSS_PAIRS))
  cross_label <- character(6)

  for (cp_i in seq_along(CROSS_PAIRS)) {
    id1 <- CROSS_PAIRS[[cp_i]][1]; id2 <- CROSS_PAIRS[[cp_i]][2]
    v_c <- v_all[v_all$id==paste0(id1,".",id2),]
    init_cov <- tryCatch(cov(pts[[VAR_COLS_D[id1]]], pts[[VAR_COLS_D[id2]]],
                              use="complete.obs"), error=function(e) 0)
    f_c <- tryCatch(suppressWarnings(
      fit.variogram(v_c, vgm(sign(init_cov)*max(abs(init_cov)*.8,1e-6),
                              "Sph", CUTOFF*.5, 0))),
      error=function(e) NULL)
    if (!is.null(f_c) && (f_c$range[2]<=0 || !all(is.finite(f_c$psill)))) f_c <- NULL
    if (!is.null(f_c)) cross_sign[cp_i] <- sum(f_c$psill)
    else if (nrow(v_c)>0) cross_sign[cp_i] <- mean(tail(v_c$gamma,3))

    # Texto para el gráfico
    v <- cross_sign[cp_i]
    perc_inv <- (id1=="perc"||id2=="perc")
    if (is.na(v) || abs(v)<1e-4) {
      cross_label[cp_i] <- "Sin relación espacial"
    } else if (v < 0) {
      if (perc_inv) cross_label[cp_i] <- "Inversa ✓\n(más crimen, peor percepción)"
      else          cross_label[cp_i] <- "Inversa\n(no ocurren en las mismas zonas)"
    } else {
      if (perc_inv) cross_label[cp_i] <- "Directa !\n(crimen alto donde perc. alta)"
      else          cross_label[cp_i] <- "Directa ✓\n(ocurren en las mismas zonas)"
    }
  }

  # ── FICHA ────────────────────────────────────────────────────────────
  # Layout: 3 filas × 3 columnas
  # [1] Alcance (barras)   [2] Relación vars   [3] Dirección (barras)
  # [4-6] Interpretación texto (fila completa)

  png_path <- sprintf("output/fichas_estaciones/%s_ficha.png",
                      gsub("[^A-Za-z0-9]", "_", est_label))

  png(png_path, width=1600, height=1050, res=130)

  layout(matrix(c(1,2,3, 4,4,4), 2, 3, byrow=TRUE),
         heights=c(3.5, 1.5))

  par(bg="white", oma=c(0,0,5,0))

  # ════════════════════════════════════════════════════════════════════
  # Panel 1 — ALCANCE: barras horizontales
  # ════════════════════════════════════════════════════════════════════
  par(mar=c(4,9.5,4,2))

  # Cap ranges at CUTOFF for display
  ranges_display <- pmin(ranges_iso, CUTOFF, na.rm=TRUE)
  ranges_display[is.na(ranges_iso)] <- 0

  bp <- barplot(rev(ranges_display),
                horiz=TRUE,
                xlim=c(0, CUTOFF*1.15),
                col=rev(VAR_COLORS[VAR_IDS]),
                border=NA,
                las=1, axes=FALSE,
                names.arg=rev(VAR_LABELS[VAR_IDS]),
                cex.names=0.78, space=0.6)

  axis(1, at=seq(0, CUTOFF, 150),
       labels=paste0(seq(0, CUTOFF, 150),"m"),
       cex.axis=0.72, col="gray60")

  # Línea de cutoff
  abline(v=CUTOFF, lty=2, col="gray70", lwd=1.2)
  text(CUTOFF+10, max(bp)*0.15, "límite\nanálisis",
       cex=0.58, col="gray55", adj=0)

  # Etiquetas de valor en cada barra
  for (vi in seq_along(VAR_IDS)) {
    vid <- VAR_IDS[vi]
    r   <- ranges_iso[vid]
    rd  <- ranges_display[vid]
    bpi <- bp[length(VAR_IDS)-vi+1]
    if (!is.na(r) && r > 0) {
      lbl <- ifelse(r >= CUTOFF*0.95, paste0(">",round(rd),"m"), paste0(round(rd),"m"))
      text(rd + CUTOFF*0.03, bpi, lbl, cex=0.70, col="gray20", adj=0, font=2)
    } else {
      text(CUTOFF*0.05, bpi, "sin patrón", cex=0.65, col="gray50", adj=0)
    }
  }

  title(main="¿A qué distancia se propaga?",
        sub="Zona de influencia espacial de cada variable (metros)",
        cex.main=0.95, font.main=2, cex.sub=0.72, col.sub="gray40")

  # ════════════════════════════════════════════════════════════════════
  # Panel 2 — RELACIÓN ENTRE VARIABLES: tabla visual
  # ════════════════════════════════════════════════════════════════════
  par(mar=c(4,2,4,2))
  plot.new()
  plot.window(xlim=c(0,1), ylim=c(0,1))

  title(main="¿Las variables van de la mano?",
        sub="Relación espacial entre pares de variables",
        cex.main=0.95, font.main=2, cex.sub=0.72, col.sub="gray40")

  # Fondo de cada celda
  n_cross <- length(CROSS_PAIRS)
  cell_h  <- 0.82 / n_cross
  y_top   <- 0.93

  for (cp_i in seq_len(n_cross)) {
    yc <- y_top - (cp_i-1)*cell_h - cell_h/2

    v <- cross_sign[cp_i]
    id1 <- CROSS_PAIRS[[cp_i]][1]; id2 <- CROSS_PAIRS[[cp_i]][2]

    # Color de fondo según signo
    if (is.na(v) || abs(v)<1e-4) {
      bg_col <- "gray93"; icon_col <- "gray55"; icon <- "~"
    } else if (v < 0) {
      bg_col <- "#E3F2FD"; icon_col <- "#1565C0"; icon <- "−"
    } else {
      bg_col <- "#FFEBEE"; icon_col <- "#C62828"; icon <- "+"
    }

    rect(0.01, yc-cell_h/2+0.005, 0.99, yc+cell_h/2-0.005,
         col=bg_col, border="white", lwd=0)

    # Puntos de color de las dos variables
    c1 <- VAR_COLORS[id1]; c2 <- VAR_COLORS[id2]
    points(0.06, yc, pch=19, col=c1, cex=1.6)
    points(0.14, yc, pch=19, col=c2, cex=1.6)

    # Texto
    text(0.22, yc+0.015, CROSS_LABELS[cp_i], cex=0.62, adj=0, font=2, col="gray20")
    text(0.22, yc-0.022, cross_label[cp_i],  cex=0.58, adj=0, col=icon_col)

    # Icono grande derecha
    text(0.94, yc, icon, cex=1.5, col=icon_col, font=2)
  }

  # Leyenda de íconos
  text(0.5, 0.04,
       "  +  = ocurren en las mismas zonas   |   −  = una alta donde la otra baja   |   ~  = sin relación",
       cex=0.56, col="gray40", adj=0.5)

  # ════════════════════════════════════════════════════════════════════
  # Panel 3 — DIRECCIÓN: ¿se propaga más a lo largo del metro?
  # ════════════════════════════════════════════════════════════════════
  par(mar=c(4,3,4,2))

  # Construir matriz: 4 variables × 4 direcciones
  dir_mat <- matrix(NA, nrow=4, ncol=4,
                    dimnames=list(VAR_IDS, as.character(ANGULOS)))
  for (vid in VAR_IDS)
    dir_mat[vid,] <- pmin(ranges_dir[[vid]], CUTOFF, na.rm=TRUE)
  dir_mat[is.na(dir_mat)] <- 0

  # Plot: grouped bars
  x_seq  <- c(1, 2.2, 3.4, 4.6)
  bar_w  <- 0.22
  offsets <- c(-1.5,-0.5,0.5,1.5) * bar_w

  plot(NULL, xlim=c(0.5, 5.1), ylim=c(0, CUTOFF*1.2),
       xlab="", ylab="Metros", las=1, xaxt="n",
       cex.axis=0.70)
  axis(1, at=x_seq, labels=VAR_LABELS[VAR_IDS], cex.axis=0.68, las=1)
  abline(h=CUTOFF, lty=2, col="gray70", lwd=1)
  abline(h=0, col="gray80", lwd=0.7)

  dir_cols_plot <- c("0"="#1565C0","45"="#43A047","90"="#E53935","135"="#FB8C00")
  dir_names <- c("0"="N-S","45"="NE-SO","90"="E-O (Metro)","135"="NO-SE")

  for (vi in seq_along(VAR_IDS)) {
    vid <- VAR_IDS[vi]
    for (di in seq_along(ANGULOS)) {
      a_ch <- as.character(ANGULOS[di])
      xpos <- x_seq[vi] + offsets[di]
      h    <- dir_mat[vid, a_ch]
      rect(xpos-bar_w/2, 0, xpos+bar_w/2, h,
           col=adjustcolor(dir_cols_plot[a_ch], 0.85), border="white", lwd=0.3)
    }
  }

  legend("topright",
         legend=dir_names, fill=dir_cols_plot,
         border=NA, bty="o", cex=0.62, box.col="gray80", bg="white",
         title="Dirección")

  title(main="¿Hay una dirección dominante?",
        sub="Range por variable y dirección cardinal",
        cex.main=0.95, font.main=2, cex.sub=0.72, col.sub="gray40")

  # ════════════════════════════════════════════════════════════════════
  # Panel 4 — INTERPRETACIÓN EN LENGUAJE SIMPLE
  # ════════════════════════════════════════════════════════════════════
  par(mar=c(0.5,1,1,1))
  plot.new()
  plot.window(xlim=c(0,1), ylim=c(0,1))

  # Calcular ratio de anisotropía para Percepción (la más relevante)
  rd_perc <- ranges_dir[["perc"]]
  rd_v <- rd_perc[!is.na(rd_perc) & rd_perc > 0]
  ratio_perc <- if (length(rd_v)>=2) round(max(rd_v)/min(rd_v),1) else NA

  # Construir bullets interpretativos
  bullet1 <- {
    r_hp <- ranges_iso["theft"]
    r_perc <- ranges_iso["perc"]
    if (!is.na(r_hp) && r_hp > 400)
      paste0("El hurto a personas se propaga hasta ~",round(r_hp),"m: ",
             "hexágonos más alejados de la estación aún están correlacionados.")
    else
      "El hurto a personas tiene un patrón muy localizado (< 400m): cada punto es casi independiente."
  }
  bullet2 <- {
    n_neg <- sum(cross_sign[1:3] < 0, na.rm=TRUE)
    if (n_neg >= 2)
      "La percepción de seguridad tiende a ser PEOR donde hay más crimen (relación inversa esperada)."
    else if (n_neg == 1)
      "Relación mixta: solo para algunos delitos la percepción empeora donde hay más crimen."
    else
      "Paradoja: la percepción de seguridad NO empeora claramente donde hay más crimen registrado."
  }
  bullet3 <- {
    if (!is.na(ratio_perc) && ratio_perc > 1.8)
      paste0("Anisotropía FUERTE (ratio ",ratio_perc,"x): la percepción varía mucho más ",
             "en una dirección. Un eje concentra el problema.")
    else if (!is.na(ratio_perc) && ratio_perc > 1.3)
      paste0("Anisotropía MODERADA (ratio ",ratio_perc,"x): hay cierta dirección dominante.")
    else
      "El patrón es isotrópico: la inseguridad se propaga por igual en todas las direcciones."
  }
  bullet4 <- {
    e_hi <- names(which(cross_sign[4:6] > 0.3))
    if (length(e_hi)>0)
      "Hurtos a comercios y a personas se concentran en las mismas zonas (co-localización)."
    else
      "Los distintos tipos de delito no necesariamente ocurren en los mismos puntos."
  }

  rect(0,0,1,1, col="#F8F9FA", border=NA)
  text(0.5, 0.95, "INTERPRETACIÓN PARA DECISIÓN DE POLÍTICA",
       cex=0.78, font=2, col="#1A237E", adj=0.5)

  bullets <- list(
    list(icon="→", txt=bullet1, y=0.76),
    list(icon="→", txt=bullet2, y=0.55),
    list(icon="→", txt=bullet3, y=0.34),
    list(icon="→", txt=bullet4, y=0.13)
  )
  for (b in bullets) {
    text(0.025, b$y, b$icon, cex=1.0, col="#1565C0", font=2, adj=0)
    text(0.055, b$y, b$txt,  cex=0.65, col="gray15", adj=0)
  }

  # Título global
  mtext(est_label, outer=TRUE, side=3, line=3.5,
        cex=1.20, font=2, col="#1A237E")
  mtext("Análisis espacial de seguridad — Corredor Metro L1, 2021-2023",
        outer=TRUE, side=3, line=2.2, cex=0.82, col="gray35")
  mtext(paste0("Buffer: ",RADIO,"m alrededor de la estación | ",
               nrow(pts)," zonas analizadas | Modelo Esférico (WLS)"),
        outer=TRUE, side=3, line=1.1, cex=0.68, col="gray55")

  dev.off()
  cat("  → Guardado:", basename(png_path), "\n")

  # Guardar resultado
  all_results[[i]] <- data.frame(
    est_id=est_id, est_name=est_name, n_pts=nrow(pts),
    range_perc=ranges_iso["perc"],   range_shop=ranges_iso["shop"],
    range_theft=ranges_iso["theft"], range_extor=ranges_iso["extor"],
    ratio_perc=ratio_perc,
    cross_perc_theft=cross_sign[2],
    stringsAsFactors=FALSE, row.names=NULL
  )
}

# ══════════════════════════════════════════════════════════════════════════════
# RESUMEN COMPARATIVO — poster de todas las estaciones
# ══════════════════════════════════════════════════════════════════════════════
results <- do.call(rbind, all_results[!sapply(all_results, is.null)])

if (!is.null(results) && nrow(results) > 0) {

  png("output/resumen_estaciones.png", width=1800, height=1100, res=130)
  par(mfrow=c(1,2), mar=c(5,9,4,1.5), oma=c(1,0,5,0), bg="white")

  # ── Panel 1: "¿A qué distancia llega la inseguridad?" ────────────────
  y_pos <- seq_len(nrow(results))
  lbs   <- paste0("E", results$est_id, "  ", substr(results$est_name,1,20))
  r_cap <- CUTOFF

  plot(NULL, xlim=c(0,r_cap*1.08), ylim=c(0.5, nrow(results)+0.5),
       xlab="Alcance espacial (metros)", ylab="", las=1, yaxt="n",
       main="Zona de influencia por estación", cex.main=1.0, font.main=2)
  axis(2, at=y_pos, labels=rev(lbs), las=2, cex.axis=0.68)
  abline(h=y_pos, col="gray94", lwd=0.8)
  abline(v=r_cap, lty=2, col="gray65", lwd=1.1)
  text(r_cap+8, nrow(results)*0.08, "límite\nanálisis",
       cex=0.52, col="gray55", srt=90, adj=0)

  # Puntos por variable
  var_off <- c(-0.3,-0.1,0.1,0.3)
  for (vi in seq_along(VAR_IDS)) {
    vid  <- VAR_IDS[vi]
    col_v <- VAR_COLS_D[vid]  # column name in results
    # column names in results are range_perc, range_shop, etc.
    rcol <- paste0("range_", vid)
    vals <- pmin(rev(results[[rcol]]), r_cap, na.rm=TRUE)
    vals[is.na(vals)] <- 0
    segments(0, y_pos+var_off[vi], vals, y_pos+var_off[vi],
             col=adjustcolor(VAR_COLORS[vid], 0.4), lwd=2.0)
    points(vals, y_pos+var_off[vi], pch=19, col=VAR_COLORS[vid], cex=1.0)
  }
  legend("bottomright", legend=VAR_LABELS, col=VAR_COLORS,
         pch=19, lwd=2, bty="o", cex=0.70, bg="white", box.col="gray80",
         inset=c(0.01,0.01))

  # ── Panel 2: semáforo Percepción ↔ Crimen ────────────────────────────
  n_r <- nrow(results); n_c <- 3
  var_cross <- c("cross_perc_theft",
                 if("cross_perc_shop" %in% names(results)) "cross_perc_shop" else NA,
                 if("range_extor" %in% names(results)) "range_extor" else NA)

  # Recalcular columnas necesarias
  # Agregamos cross_perc_shop a results si no está
  # (ya está guardado en results con los nombres originales?)
  # En all_results solo guardamos: range_perc, range_shop, range_theft, range_extor, ratio_perc, cross_perc_theft
  # Necesitamos el cross_perc_theft para el semáforo

  # Plot simplificado: semáforo de 3 métricas por estación
  # (1) Alcance percepción, (2) relación perc-hurtopers, (3) ratio anisotropía
  mets <- c("Alcance\npercepción", "Percepción\n↔ Crimen", "Anisotropía\npercepción")
  n_met <- length(mets)

  plot(NULL, xlim=c(0.5, n_met+0.5), ylim=c(0.5, n_r+0.5),
       xlab="", ylab="", xaxt="n", yaxt="n",
       main="Semáforo de alertas por estación", cex.main=1.0, font.main=2)
  axis(1, at=1:n_met, labels=mets, cex.axis=0.72, las=1)
  axis(2, at=1:n_r, labels=rev(lbs), las=2, cex.axis=0.68)

  for (ri in 1:n_r) {
    r <- results[ri,]
    yi <- n_r - ri + 1

    # Métrica 1: alcance percepción
    alc <- r$range_perc
    if (is.na(alc) || alc==0)     col1 <- "gray80"
    else if (alc > r_cap*0.85)    col1 <- "#C62828"   # rojo: muy amplio
    else if (alc > r_cap*0.5)     col1 <- "#EF6C00"   # naranja: moderado
    else                           col1 <- "#2E7D32"   # verde: localizado

    # Métrica 2: relación percepción ↔ hurto personas
    cv <- r$cross_perc_theft
    if (is.na(cv))                col2 <- "gray80"
    else if (cv < -0.05)          col2 <- "#2E7D32"   # verde: anti-corr (esperado)
    else if (cv > 0.1)            col2 <- "#C62828"   # rojo: co-ubic (paradoja)
    else                           col2 <- "#F9A825"   # amarillo: ambiguo

    # Métrica 3: anisotropía percepción
    ra <- r$ratio_perc
    if (is.na(ra))                col3 <- "gray80"
    else if (ra > 1.8)            col3 <- "#C62828"   # rojo: fuerte
    else if (ra > 1.3)            col3 <- "#EF6C00"   # naranja
    else                           col3 <- "#2E7D32"   # verde: isotrópico

    for (ci in 1:n_met) {
      coli <- c(col1,col2,col3)[ci]
      rect(ci-.40, yi-.38, ci+.40, yi+.38,
           col=coli, border="white", lwd=0.4)
      # Valor numérico
      vals_txt <- c(
        ifelse(is.na(alc)||alc==0," NA",paste0(round(min(alc,r_cap)),"m")),
        ifelse(is.na(cv)," NA",sprintf("%+.2f",cv)),
        ifelse(is.na(ra)," NA",paste0(ra,"x"))
      )
      text(ci, yi, vals_txt[ci], cex=0.58, col="white", font=2)
    }
  }

  # Leyenda del semáforo
  legend("bottomright",
         legend=c("Verde: favorable / bajo riesgo",
                  "Naranja: moderado",
                  "Rojo: alto riesgo / alerta"),
         fill=c("#2E7D32","#EF6C00","#C62828"), border=NA,
         bty="o", cex=0.65, bg="white", box.col="gray80", inset=c(0.01,0.01))

  mtext("Resumen comparativo — 16 Estaciones Metro Línea 1",
        outer=TRUE, side=3, line=3.5, cex=1.10, font=2, col="#1A237E")
  mtext("Análisis espacial: percepción de seguridad + delitos — Corredor 2021-2023",
        outer=TRUE, side=3, line=2.2, cex=0.82, col="gray35")
  mtext(paste0("Rojo=preocupante | Naranja=moderado | Verde=favorable | ",
               "Buffer ",RADIO,"m | Modelo Esférico"),
        outer=TRUE, side=3, line=1.1, cex=0.68, col="gray55")

  dev.off()
  cat("\nResumen comparativo: output/resumen_estaciones.png\n")
}

cat("\n══ FIN ══\n")
cat("Fichas en: output/fichas_estaciones/\n")
cat("Resumen en: output/resumen_estaciones.png\n")
