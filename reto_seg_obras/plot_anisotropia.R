# ══════════════════════════════════════════════════════════════════════════════
# PLOT COMPARATIVO: ISOTRÓPICO vs. ANISOTRÓPICO
# Usa datos reales del hex_grid — Hurto Personas durante la obra (2021-2023)
# ══════════════════════════════════════════════════════════════════════════════

library(sf)
library(gstat)

cat("Cargando datos...\n")
hex_grid <- readRDS("data/hex_grid_metro.rds")
hex_pts  <- st_centroid(hex_grid)
hex_pts  <- hex_pts[!is.na(hex_pts$log_theft), ]

# Convención gstat: ángulo desde Norte, horario, rango 0-180°
# 0°  = Norte-Sur | 45° = NE-SW | 90° = Este-Oeste | 135° = NO-SE
# Metro L1 ≈ 80° (casi Este-Oeste)
angulos    <- c(0, 45, 90, 135)
colores    <- c("#1565C0", "#43A047", "#E53935", "#FB8C00")
etiquetas  <- c("Norte-Sur  (0°)", "NE-Suroeste (45°)",
                "Este-Oeste (90°)  \u2190 Metro", "NO-Sureste (135°)")

CUTOFF <- 2500
WIDTH  <- 200

cat("Calculando variograma isotrópico...\n")
v_iso <- variogram(log_theft ~ 1, data = hex_pts, cutoff = CUTOFF, width = WIDTH)
fit_iso <- fit.variogram(v_iso,
  vgm(psill = var(hex_pts$log_theft) * 0.8, model = "Sph",
      range = 900, nugget = var(hex_pts$log_theft) * 0.2))
nugget_iso <- fit_iso$psill[1]
sill_iso   <- sum(fit_iso$psill)
range_iso  <- fit_iso$range[2]

cat("Calculando variogramas direccionales...\n")
v_dir <- variogram(log_theft ~ 1, data = hex_pts,
                   alpha = angulos, tol.hor = 22.5,
                   cutoff = CUTOFF, width = WIDTH)

ranges_dir <- setNames(numeric(4), as.character(angulos))
fits_dir   <- vector("list", 4)
for (i in seq_along(angulos)) {
  v_i <- v_dir[v_dir$dir.hor == angulos[i], ]
  if (nrow(v_i) > 3) {
    f <- tryCatch(
      fit.variogram(v_i, vgm(psill = var(hex_pts$log_theft) * 0.8,
                              model = "Sph", range = 900,
                              nugget = var(hex_pts$log_theft) * 0.2)),
      error = function(e) NULL)
    if (!is.null(f)) { fits_dir[[i]] <- f; ranges_dir[i] <- round(f$range[2]) }
  }
}
cat("  Ranges (m):", paste(etiquetas, "=", ranges_dir, collapse = " | "), "\n")

# ── ESCALA COMÚN ────────────────────────────────────────────────────────────
x_max  <- CUTOFF
y_max  <- max(c(v_iso$gamma, v_dir$gamma), na.rm = TRUE) * 1.10
d_seq  <- seq(0, x_max, length.out = 400)
ratio_aniso <- round(max(ranges_dir) / min(ranges_dir[ranges_dir > 0]), 1)

# ── PNG ─────────────────────────────────────────────────────────────────────
cat("Generando plot...\n")
png("output/comparacion_isotropia.png",
    width = 1600, height = 720, res = 130)

par(mfrow = c(1, 2),
    mar  = c(4.5, 5, 6, 2),
    oma  = c(4, 0, 3, 0),
    bg   = "white")

# ════════════════════════════════════════════════════════════════════════════
# Panel izquierdo — ISOTRÓPICO
# ════════════════════════════════════════════════════════════════════════════
plot(v_iso$dist, v_iso$gamma,
     xlim = c(0, x_max), ylim = c(0, y_max),
     xlab = "Distancia (m)", ylab = "Semivarianza",
     pch = 19, col = "#1565C0", cex = 1.1,
     las = 1, cex.axis = 0.85, main = "")

# Curva
g_iso <- variogramLine(fit_iso, dist_vector = d_seq)
lines(g_iso$dist, g_iso$gamma, col = "#1565C0", lwd = 2.5)

# Líneas Sill y Range
abline(h = sill_iso, lty = 2, col = "gray55", lwd = 1.3)
abline(v = range_iso, lty = 3, col = "gray55", lwd = 1.3)

# Etiquetas — parte superior izquierda
text(500, nugget_iso + y_max * 0.06,
     paste0("Nugget = ", round(nugget_iso, 2)),
     col = "gray30", cex = 0.80, pos = 4)
text(80, sill_iso + y_max * 0.05,
     paste0("Sill = ", round(sill_iso, 2)),
     col = "gray30", cex = 0.80, pos = 4)
# Range label a la izquierda de la línea punteada
text(range_iso - 50, y_max * 0.28,
     paste0("Range = ", round(range_iso), " m"),
     col = "#1565C0", cex = 0.80, pos = 2)

# Leyenda — esquina superior derecha (zona libre después del range)
legend("topright",
       legend = "Modelo esférico (todos los pares)",
       col = "#1565C0", lwd = 2.5, pch = 19,
       bty = "o", cex = 0.80, box.col = "gray80", bg = "white",
       pt.cex = 1.1, inset = c(0.02, 0.02))

# Títulos del panel
title(main = "ISOTRÓPICO", cex.main = 1.15,
      col.main = "#1565C0", font.main = 2, line = 4.5)
mtext("todos los pares, sin distinguir orientación",
      side = 3, line = 3.2, cex = 0.84, col = "#1565C0")

# ════════════════════════════════════════════════════════════════════════════
# Panel derecho — ANISOTRÓPICO
# ════════════════════════════════════════════════════════════════════════════
plot(NULL,
     xlim = c(0, x_max), ylim = c(0, y_max),
     xlab = "Distancia (m)", ylab = "Semivarianza",
     las = 1, cex.axis = 0.85, main = "")

# Línea del Sill de referencia (isotrópico)
abline(h = sill_iso, lty = 2, col = "gray70", lwd = 1.2)

# Curvas y puntos por dirección
for (i in seq_along(angulos)) {
  v_i <- v_dir[v_dir$dir.hor == angulos[i], ]
  if (nrow(v_i) == 0) next
  points(v_i$dist, v_i$gamma, pch = 19, col = colores[i], cex = 0.9)
  if (!is.null(fits_dir[[i]])) {
    g_i <- variogramLine(fits_dir[[i]], dist_vector = d_seq)
    lines(g_i$dist, g_i$gamma, col = colores[i], lwd = 2.2)
    abline(v = ranges_dir[i], lty = 3, col = colores[i], lwd = 1.1)
  }
}

# Leyenda única — bottomright
leg_txt <- paste0(etiquetas, "  range = ", ranges_dir, " m")
legend("bottomright",
       legend = leg_txt,
       col = colores, lwd = 2.2, pch = 19,
       bty = "o", cex = 0.72, box.col = "gray80", bg = "white",
       pt.cex = 1.0, y.intersp = 1.1, inset = c(0.01, 0.02),
       title = "Direccion (gstat: desde Norte, horario)")

# Títulos del panel
title(main = "ANISOTRÓPICO", cex.main = 1.15,
      col.main = "#880000", font.main = 2, line = 4.5)
mtext("4 sectores cardinales \u00b122.5\u00b0 de tolerancia",
      side = 3, line = 3.2, cex = 0.84, col = "#880000")

# ── Título global ────────────────────────────────────────────────────────────
mtext("Hurto Personas (log) \u2014 Corredor Metro L1, 2021\u20132023",
      outer = TRUE, side = 3, cex = 1.08, font = 2, line = 1.8)
mtext("\u00bfLa correlaci\u00f3n espacial depende de la direcci\u00f3n?",
      outer = TRUE, side = 3, cex = 0.9, line = 0.6)

# ── Nota al pie ───────────────────────────────────────────────────────────────
mtext(paste0(
  "Isotr\u00f3pico: un \u00fanico variograma promedia todas las orientaciones (range = ",
  round(range_iso), " m).   ",
  "Anisot\u00f3pico: cada direcci\u00f3n tiene su propio range."),
  outer = TRUE, side = 1, cex = 0.73, col = "gray25", line = 0.4)
mtext(paste0(
  "Ratio de anisotrop\u00eda = range m\u00e1ximo / range m\u00ednimo = ",
  max(ranges_dir), " / ", min(ranges_dir[ranges_dir > 0]), " = ", ratio_aniso, "x",
  "  \u2192  anisotrop\u00eda ", ifelse(ratio_aniso > 1.5, "FUERTE", "moderada"),
  " \u2014 la inseguridad se propaga m\u00e1s en direcci\u00f3n Norte-Sur que a lo largo del Metro."),
  outer = TRUE, side = 1, cex = 0.75, col = "#880000", font = 2, line = 1.8)

dev.off()
cat("Guardado: output/comparacion_isotropia.png\n")
