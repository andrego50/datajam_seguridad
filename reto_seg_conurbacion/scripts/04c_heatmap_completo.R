# ==============================================================================
# 04c_heatmap_completo.R - Heatmap de correlacion delitos + operativos
#
# Centinelas Rosaristas - Reto 3: Seguridad Integral Region Metropolitana
# ==============================================================================

library(dplyr)

PROC_DIR <- file.path(getwd(), "data", "processed")
FIG_DIR  <- file.path(getwd(), "output", "figures")
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

# Cargar correlacion completa
cor_matrix <- readRDS(file.path(PROC_DIR, "correlacion_capas_completa.rds"))

# Heatmap
png(file.path(FIG_DIR, "correlacion_delitos_operativos.png"),
    width = 1000, height = 900, res = 150)
par(mar = c(10, 10, 3, 2))

n <- nrow(cor_matrix)
image(1:n, 1:n, cor_matrix,
      axes = FALSE, xlab = "", ylab = "",
      col = colorRampPalette(c("#2166AC", "white", "#B2182B"))(100))

axis(1, at = 1:n, labels = rownames(cor_matrix), las = 2, cex.axis = 0.65)
axis(2, at = 1:n, labels = colnames(cor_matrix), las = 2, cex.axis = 0.65)

for (i in 1:n) {
  for (j in 1:n) {
    text(i, j, round(cor_matrix[i, j], 2), cex = 0.5)
  }
}
title("Correlacion Spearman: Delitos + Operativos (ChroNNet)")
dev.off()

cat("Guardado: correlacion_delitos_operativos.png\n")
