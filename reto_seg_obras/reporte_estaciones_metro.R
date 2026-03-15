# ══════════════════════════════════════════════════════════════════════════════
# REPORTE ESPACIAL POR ESTACIÓN — METRO LÍNEA 1, BOGOTÁ
# Comparación ANTES (2018-2020) vs DURANTE construcción (2021-2023)
# Variables: Hurto Comercio, Hurto Personas, Extorsión, Percepción de Seguridad
# Salida: output/reporte_metro_l1.pdf  (5 páginas por estación + 2 resumen)
# ══════════════════════════════════════════════════════════════════════════════

library(sf)
library(gstat)
library(grDevices)

# ── CONFIGURACIÓN ─────────────────────────────────────────────────────────────
RADIO   <- 1000    # buffer por estación (m)
CUTOFF  <- 1000    # cutoff variograma (m)
WIDTH   <- 100     # ancho de lag (~10 bins)
ANGULOS <- c(0, 45, 90, 135)
TOL_HOR <- 22.5
MIN_PTS <- 20

# Colores de dirección
DC <- c("0"="#1565C0","45"="#2E7D32","90"="#C62828","135"="#E65100")
DL <- c("0"="Norte-Sur","45"="NE-Suroeste",
        "90"="Este-Oeste (sentido Metro)","135"="Noroeste-Sureste")

# Colores de variable
VC <- c(shop="#E53935", theft="#FB8C00", extor="#2E7D32", perc="#5C6BC0")

# Transmilenio en la zona de cada estación (actualizar si hay más info)
TM <- c("01"=FALSE,"02"=TRUE, "03"=FALSE,"04"=FALSE,"05"=TRUE,
        "06"=TRUE, "07"=TRUE, "08"=FALSE,"09"=TRUE, "10"=FALSE,
        "11"=FALSE,"12"=FALSE,"13"=TRUE, "14"=FALSE,"15"=FALSE,"16"=FALSE)

# ── DATOS ─────────────────────────────────────────────────────────────────────
cat("Cargando datos...\n")
hex <- readRDS("data/hex_grid_metro.rds")
suppressWarnings(hex_pts <- st_centroid(hex))

# Variables log transformadas
hex_pts$log_shop_pre  <- log(hex_pts$shoplifting_pre + 1)
hex_pts$log_theft_pre <- log(hex_pts$theft_pre       + 1)
hex_pts$log_extor_pre <- log(hex_pts$extortion_pre   + 1)

# Solo columnas necesarias
hex_pts <- hex_pts[, c("log_shop_pre","log_theft_pre","log_extor_pre",
                        "log_shoplifting","log_theft","log_extortion",
                        "percepcion","percepcion_sat","pred_percepcion","geometry")]

# percepcion_sat = encuesta real donde existe + imputacion espectral (Sentinel-2)
# donde no hay encuesta. Variables espectrales son exogenas al crimen (sin endogeneidad).
# Donde tampoco hay satelite -> NA (igual que percepcion cruda)
cat(sprintf("percepcion_sat: %d con dato, %d sin dato\n",
            sum(!is.na(hex_pts$percepcion_sat)),
            sum(is.na(hex_pts$percepcion_sat))))

# ── ESTACIONES ────────────────────────────────────────────────────────────────
est    <- st_read("data/estaciones_metro_l1.geojson", quiet=TRUE)
suppressWarnings(st_crs(est) <- 6247)
est_3116 <- st_transform(est, 3116)
suppressWarnings(cents <- st_centroid(est_3116))
est_df   <- st_drop_geometry(est)
ord      <- order(as.integer(est_df$NUMERO))
cents    <- cents[ord,]; est_df <- est_df[ord,]
n_est    <- nrow(cents)

# Distancias inter-estación
coords_e  <- st_coordinates(cents)
dist_all  <- as.numeric(st_distance(cents[-n_est,], cents[-1,], by_element=TRUE))
d_prev    <- c(NA, dist_all)
d_next    <- c(dist_all, NA)

# ── HELPERS ───────────────────────────────────────────────────────────────────
fit_sph <- function(v, init_v) {
  f <- tryCatch(suppressWarnings(
    fit.variogram(v, vgm(max(init_v*.75,1e-6),"Sph",
                         CUTOFF*.5,max(init_v*.25,1e-6)))),
    error=function(e) NULL)
  if (!is.null(f) && (f$range[2]<=0 || !all(is.finite(f$psill)))) f <- NULL
  # Si el range excede 1.5x el cutoff, el variograma empirico no muestra sill
  # visible dentro de la ventana de observacion -> el modelo extrapola sin soporte
  # en los datos -> descartamos el ajuste (se reportara como "Sin ajuste")
  if (!is.null(f) && f$range[2] > CUTOFF * 1.5) f <- NULL
  f
}

range_display <- function(rng, na_open=FALSE) {
  if (is.na(rng)||rng<=0) return(if(na_open) ">1km*" else "N/D")
  if (rng > CUTOFF*.92) return(paste0(">",round(CUTOFF*.9),"m"))
  paste0(round(rng),"m")
}

# Dibuja panel de variograma (isotrópico o una dirección)
draw_vgm <- function(v_df, fit, col, titulo, x_max=CUTOFF, y_max=NULL,
                     show_y=TRUE, cex_main=0.88) {
  if (is.null(y_max)) y_max <- max(v_df$gamma,na.rm=TRUE)*1.22
  plot(v_df$dist, v_df$gamma,
       xlim=c(0,x_max), ylim=c(0,y_max),
       xlab="Distancia (m)", ylab=if(show_y)"Semivarianza" else "",
       pch=19, col=col, cex=0.9, las=1, cex.axis=0.72,
       main=titulo, cex.main=cex_main, font.main=2, col.main=col)
  if (!is.null(fit)) {
    d <- seq(1,x_max,len=350)
    gln <- variogramLine(fit, dist_vector=d)
    lines(gln$dist, gln$gamma, col=col, lwd=2.3)
    nug <- fit$psill[1]; sill <- sum(fit$psill); rng <- fit$range[2]
    nsr <- if (sill > 0) round(nug / sill, 2) else NA_real_
    abline(h=sill, lty=2, col="gray55", lwd=1.0)
    abline(v=rng,  lty=3, col=col,      lwd=1.0)
    usr <- par("usr")
    text(x_max*.02, sill+y_max*.065,
         paste0("Sill=",round(sill,2)), col="gray20", cex=0.65, pos=4)
    text(x_max*.02, nug+y_max*.065,
         paste0("Nug=",round(nug,2)),  col="gray20", cex=0.65, pos=4)
    text(rng-x_max*.02, y_max*.22,
         paste0(round(rng),"m"), col=col, cex=0.68, pos=2, font=2)
    # NSR = Nugget/Sill: <0.25 = estructura fuerte, >0.75 = ruido puro
    if (!is.na(nsr)) {
      col_nsr <- if(nsr < 0.25)"#1B5E20" else if(nsr < 0.5)"#E65100" else "#C62828"
      text(x_max*.98, y_max*.12,
           paste0("NSR=",nsr), col=col_nsr, cex=0.60, pos=2, font=2)
    }
  } else {
    usr <- par("usr")
    text(mean(usr[1:2]),mean(usr[3:4]),
         "Sin ajuste", cex=0.80, col="gray55", font=3)
  }
}

# Dibuja panel anisotrópico (4 direcciones superpuestas)
draw_aniso <- function(pts_l, col_nm, col_var, titulo,
                       x_max=CUTOFF, periodo="", y_max=NULL) {
  init_v <- var(pts_l[[col_nm]], na.rm=TRUE)
  v_dir  <- suppressWarnings(
    variogram(as.formula(paste(col_nm,"~ 1")),
              data=pts_l, alpha=ANGULOS, tol.hor=TOL_HOR,
              cutoff=x_max, width=WIDTH))
  if (is.null(y_max)) y_max <- max(v_dir$gamma, na.rm=TRUE)*1.22

  fits_d <- setNames(vector("list",4), as.character(ANGULOS))
  rng_d  <- setNames(rep(NA_real_,4),  as.character(ANGULOS))
  for (a in ANGULOS) {
    va <- v_dir[v_dir$dir.hor==a,]
    if (nrow(va)>3) {
      f <- fit_sph(va, init_v)
      if (!is.null(f)) { fits_d[[as.character(a)]]=f
                         rng_d[as.character(a)]=round(f$range[2]) }
    }
  }
  rv    <- rng_d[!is.na(rng_d)&rng_d>0]
  ratio <- if(length(rv)>=2) round(max(rv)/min(rv),1) else NA

  plot(NULL, xlim=c(0,x_max), ylim=c(0,y_max),
       xlab="Distancia (m)", ylab="Semivarianza",
       las=1, cex.axis=0.72,
       main=titulo, cex.main=0.88, font.main=2, col.main=col_var)
  if (periodo!="")
    mtext(periodo, side=3, line=0.15, cex=0.68, col="gray40", font=2)

  d_seq <- seq(1,x_max,len=350)
  for (a in ANGULOS) {
    ach <- as.character(a)
    va  <- v_dir[v_dir$dir.hor==a,]
    if (nrow(va)==0) next
    points(va$dist, va$gamma, pch=19, col=DC[ach], cex=0.75)
    if (!is.null(fits_d[[ach]])) {
      gln <- variogramLine(fits_d[[ach]], dist_vector=d_seq)
      lines(gln$dist, gln$gamma, col=DC[ach], lwd=2.0)
      abline(v=rng_d[ach], lty=3,
             col=adjustcolor(DC[ach],.55), lwd=0.9)
    }
  }
  if (!is.na(ratio)) {
    usr  <- par("usr")
    colr <- if(ratio>1.5)"#B71C1C" else "gray40"
    text(usr[2]-x_max*.03, y_max*.97,
         paste0("ratio=",ratio,"x"), col=colr, cex=0.65, pos=2,
         font=if(ratio>1.5)2 else 1)
  }
  leg <- paste0(DL[as.character(ANGULOS)],": ",
                ifelse(is.na(rng_d),"N/D",paste0(rng_d,"m")))
  legend("bottomright", legend=leg,
         col=DC[as.character(ANGULOS)], lwd=2.0, pch=19, pt.cex=0.85,
         bty="o", cex=0.54, bg="white", box.col="gray80",
         y.intersp=0.95, inset=c(0.01,0.02), title="Direccion - Range")

  invisible(list(rng_d=rng_d, ratio=ratio))
}

# ── ALMACENAR RESULTADOS PARA RESUMEN FINAL ───────────────────────────────────
summary_df <- data.frame(
  est_id=character(), est_name=character(),
  n_pts=integer(), tiene_tm=logical(),
  # Ranges isotrópicos ANTES
  r_ant_shop=numeric(), r_ant_theft=numeric(), r_ant_extor=numeric(),
  # Ranges isotrópicos DURANTE
  r_dur_shop=numeric(), r_dur_theft=numeric(),
  r_dur_extor=numeric(), r_dur_perc=numeric(),
  # Ratios de anisotropía DURANTE
  rat_shop=numeric(), rat_theft=numeric(),
  rat_extor=numeric(), rat_perc=numeric(),
  # Categoría
  categoria=character(),
  stringsAsFactors=FALSE
)

# ══════════════════════════════════════════════════════════════════════════════
# FUNCIÓN AUXILIAR: calcular todos los variogramas de una estación
# ══════════════════════════════════════════════════════════════════════════════
calc_vgms <- function(pts_l) {
  out <- list()
  for (per in c("ant","dur")) {
    vars <- if(per=="ant") c(shop="log_shop_pre",theft="log_theft_pre",extor="log_extor_pre")
            else           c(shop="log_shoplifting",theft="log_theft",
                              extor="log_extortion",perc="percepcion_sat")
    for (vid in names(vars)) {
      col_nm <- vars[vid]
      # Para percepcion: usar solo hexagonos con dato (encuesta real o imputacion satelital)
      pts_v  <- if(vid=="perc") pts_l[!is.na(pts_l$percepcion_sat),] else pts_l
      col_d  <- pts_v[[col_nm]]

      if (length(col_d) < MIN_PTS) {
        out[[paste0(per,"_",vid)]] <- list(v_iso=NULL, f_iso=NULL, v_dir=NULL,
                                           rng_d=setNames(rep(NA_real_,4),as.character(ANGULOS)),
                                           ratio=NA)
        next
      }

      v_iso  <- variogram(as.formula(paste(col_nm,"~ 1")),
                          data=pts_v, cutoff=CUTOFF, width=WIDTH)
      f_iso  <- fit_sph(v_iso, var(col_d,na.rm=TRUE))

      v_dir <- suppressWarnings(
        variogram(as.formula(paste(col_nm,"~ 1")),
                  data=pts_v, alpha=ANGULOS, tol.hor=TOL_HOR,
                  cutoff=CUTOFF, width=WIDTH))
      rng_d <- setNames(rep(NA_real_,4),as.character(ANGULOS))
      for (a in ANGULOS) {
        va <- v_dir[v_dir$dir.hor==a,]
        if (nrow(va)>3) {
          fa <- fit_sph(va, var(col_d,na.rm=TRUE))
          if (!is.null(fa)) rng_d[as.character(a)] <- round(fa$range[2])
        }
      }
      rv    <- rng_d[!is.na(rng_d)&rng_d>0]
      ratio <- if(length(rv)>=2) round(max(rv)/min(rv),1) else NA

      key <- paste0(per,"_",vid)
      out[[key]] <- list(v_iso=v_iso, f_iso=f_iso, v_dir=v_dir,
                         rng_d=rng_d, ratio=ratio)
    }
  }
  out
}

# ── CATEGORIZACIÓN ────────────────────────────────────────────────────────────
categorizar <- function(r_dur_theft, r_dur_shop, r_ant_theft, r_ant_shop,
                        rat_theft, rat_perc) {
  # NA range = sin sill visible = patrón al menos tan difuso como CUTOFF
  r_dur_theft2 <- ifelse(is.na(r_dur_theft), CUTOFF, r_dur_theft)
  r_dur_shop2  <- ifelse(is.na(r_dur_shop),  CUTOFF, r_dur_shop)
  r_ant_theft2 <- ifelse(is.na(r_ant_theft), CUTOFF, r_ant_theft)
  r_ant_shop2  <- ifelse(is.na(r_ant_shop),  CUTOFF, r_ant_shop)
  r_avg_dur <- mean(c(r_dur_theft2, r_dur_shop2), na.rm=TRUE)
  r_avg_ant <- mean(c(r_ant_theft2, r_ant_shop2), na.rm=TRUE)
  cambio    <- if (!is.na(r_avg_ant) && r_avg_ant>0) r_avg_dur/r_avg_ant else NA

  if (is.na(r_avg_dur)) return("Sin datos suficientes")

  if (r_avg_dur > CUTOFF*.85) {
    if (!is.na(cambio) && cambio > 1.2)
      return("🔴 ALERTA ALTA — inseguridad difusa y creciente")
    return("🟠 ALERTA MEDIA-ALTA — inseguridad muy extendida")
  }
  if (r_avg_dur > CUTOFF*.5) {
    if (!is.na(rat_theft) && rat_theft > 1.5)
      return("🟠 ALERTA MEDIA — patrón direccional moderado")
    return("🟡 VIGILANCIA — inseguridad moderada")
  }
  if (!is.na(cambio) && cambio < 0.7)
    return("🟢 MEJORA — inseguridad se redujo con la obra")
  return("🟢 CONTROLADA — inseguridad localizada")
}

# ══════════════════════════════════════════════════════════════════════════════
# GENERAR PDF
# ══════════════════════════════════════════════════════════════════════════════
cat("Generando PDF...\n")

pdf("output/reporte_metro_l1.pdf",
    width=16, height=10,
    title="Reporte Espacial — Metro Línea 1, Bogotá")

for (i in seq_len(n_est)) {

  est_id   <- est_df$NUMERO[i]
  est_name <- est_df$RefName[i]
  dp       <- d_prev[i]; dn <- d_next[i]
  prev_nm  <- if(i>1)     est_df$RefName[i-1] else NA
  next_nm  <- if(i<n_est) est_df$RefName[i+1] else NA
  tiene_tm <- isTRUE(TM[est_id])

  cat(sprintf("  E%s — %s\n", est_id, est_name))

  # Hexágonos en buffer
  buf <- st_buffer(cents[i,], RADIO)
  suppressWarnings(idx <- st_intersects(hex_pts, buf, sparse=FALSE)[,1])
  pts_l <- hex_pts[idx,]
  n_pts <- nrow(pts_l)

  if (n_pts < MIN_PTS) {
    par(mar=c(0,0,0,0), bg="white", oma=c(0,0,0,0))
    plot.new(); text(0.5,0.5,"Datos insuficientes",cex=2,col="gray50")
    next
  }

  # Calcular todos los variogramas
  vgms <- calc_vgms(pts_l)

  # Extraer ranges isotrópicos
  # NULL fit = sin sill visible dentro del buffer (range > 1.5*CUTOFF o datos insuficientes)
  # Para categorización: NA se trata como CUTOFF (patrón al menos tan difuso como el buffer)
  get_r <- function(key) {
    f <- vgms[[key]]$f_iso
    if (!is.null(f)) f$range[2] else NA_real_
  }
  r_ant_shop  <- get_r("ant_shop");  r_ant_theft <- get_r("ant_theft")
  r_ant_extor <- get_r("ant_extor")
  r_dur_shop  <- get_r("dur_shop");  r_dur_theft <- get_r("dur_theft")
  r_dur_extor <- get_r("dur_extor"); r_dur_perc  <- get_r("dur_perc")
  rat_theft   <- vgms[["dur_theft"]]$ratio
  rat_shop    <- vgms[["dur_shop"]]$ratio
  rat_extor   <- vgms[["dur_extor"]]$ratio
  rat_perc    <- vgms[["dur_perc"]]$ratio

  categoria <- categorizar(r_dur_theft, r_dur_shop,
                            r_ant_theft, r_ant_shop, rat_theft, rat_perc)

  # ──────────────────────────────────────────────────────────────────────
  # PÁGINA 1 — PORTADA DE ESTACIÓN
  # ──────────────────────────────────────────────────────────────────────
  par(mar=c(0,0,0,0), oma=c(0,0,0,0), bg="white")
  plot.new(); plot.window(xlim=c(0,1), ylim=c(0,1))

  # Cabecera azul
  rect(0,.88,1,1, col="#1A237E", border=NA)
  text(.5,.96, paste0("ESTACIÓN ", est_id, " — ", est_name),
       cex=1.8, font=2, col="white", adj=.5)
  text(.5,.90, "Metro Línea 1 de Bogotá — Análisis Espacial de Seguridad",
       cex=1.0, col="#90CAF9", adj=.5)

  # Categoría
  col_cat <- switch(substr(categoria,1,2),
                    "🔴"="#FFEBEE","🟠"="#FFF3E0",
                    "🟡"="#FFFDE7","🟢"="#E8F5E9","#F5F5F5")
  rect(.05,.76,.95,.86, col=col_cat, border="gray70")
  text(.5,.81, paste0("CATEGORÍA: ", categoria),
       cex=1.25, font=2, col="gray10", adj=.5)

  # Dos columnas de info
  # Columna izquierda
  text(.05,.72,"INFORMACIÓN DE LA ESTACIÓN",
       cex=0.85, font=2, col="#1A237E", adj=0)
  info_l <- c(
    paste0("Posición en la línea: estación ", i, " de ", n_est),
    paste0("Transmilenio en la zona: ",
           if(tiene_tm)"SÍ — corredor existente" else "NO — área sin TM"),
    paste0("Hexágonos analizados (buffer 1km): ", n_pts),
    paste0("Estación anterior: ",
           if(!is.na(prev_nm)) paste0(prev_nm," (",round(dp),"m)") else "—"),
    paste0("Estación siguiente: ",
           if(!is.na(next_nm)) paste0(next_nm," (",round(dn),"m)") else "—")
  )
  for (k in seq_along(info_l))
    text(.07,.66-(k-1)*.072, paste0("• ",info_l[k]),
         cex=0.78, col="gray15", adj=0)

  # Columna derecha — tabla de ranges
  text(.52,.72,"RANGES DE AUTOCORRELACIÓN ESPACIAL (metros)",
       cex=0.85, font=2, col="#1A237E", adj=0)
  # Encabezados
  text(.54,.66,"Variable",          cex=0.75,font=2,col="gray20",adj=0)
  text(.78,.66,"Antes (2018-20)",   cex=0.75,font=2,col="#37474F",adj=0.5)
  text(.93,.66,"Durante (2021-23)", cex=0.75,font=2,col="#1A237E",adj=0.5)

  rows_t <- list(
    c("Hurto a Comercios", range_display(r_ant_shop),  range_display(r_dur_shop,  na_open=TRUE)),
    c("Hurto a Personas",  range_display(r_ant_theft), range_display(r_dur_theft, na_open=TRUE)),
    c("Extorsión",         range_display(r_ant_extor), range_display(r_dur_extor, na_open=TRUE)),
    c("Percepción Seguridad","—(sin dato)",            range_display(r_dur_perc,  na_open=TRUE))
  )
  col_var4 <- c(VC["shop"],VC["theft"],VC["extor"],VC["perc"])
  for (k in seq_along(rows_t)) {
    yy <- .58-(k-1)*.072
    rect(.53,yy-.03,.97,yy+.025,
         col=if(k%%2==0)"#F9F9F9" else "white", border=NA)
    text(.54,yy, rows_t[[k]][1], cex=0.74, col=col_var4[k], adj=0, font=2)
    text(.82,yy, rows_t[[k]][2], cex=0.74, col="#37474F",    adj=0.5)

    # Colorear el "durante" según cambio
    r_ant_n <- suppressWarnings(as.numeric(gsub("[^0-9.]","",rows_t[[k]][2])))
    r_dur_n <- suppressWarnings(as.numeric(gsub("[^0-9.]","",rows_t[[k]][3])))
    col_dur <- if(!is.na(r_ant_n)&&!is.na(r_dur_n)) {
      if(r_dur_n>r_ant_n*1.15)"#C62828" else if(r_dur_n<r_ant_n*.85)"#2E7D32"
      else "gray20"
    } else "gray20"
    text(.97,yy, rows_t[[k]][3], cex=0.74, col=col_dur, adj=0.5, font=2)
  }
  text(.97,.20,"Rojo = aumentó | Verde = disminuyó",
       cex=0.60, col="gray50", adj=1)

  # Nota metodológica
  rect(.05,.05,.95,.17, col="#EEF2FF", border="gray80")
  text(.50,.13,
       paste0("Modelo esferico (Sph) ajustado por minimos cuadrados ponderados (WLS). ",
              "Buffer circular de 1km. Cutoff: ",CUTOFF,"m | Lags: ",WIDTH,"m. ",
              "NSR (Nugget/Sill): <0.25 = estructura espacial fuerte, >0.75 = mayormente ruido aleatorio."),
       cex=0.68, col="gray35", adj=0.5)
  text(.50,.07,
       paste0("'Sin ajuste' = variograma sin sill visible (patron > 1km). ",
              "Percepcion: encuesta CCB 2025 (real) + imputacion Sentinel-2 L2A (exogena) ",
              "donde no hay encuesta. Variables satelitales son exogenas al crimen (sin endogeneidad)."),
       cex=0.64, col="gray45", adj=0.5)

  # ──────────────────────────────────────────────────────────────────────
  # Escala Y compartida por variable (para comparar ANTES vs DURANTE)
  # ──────────────────────────────────────────────────────────────────────
  safe_max_iso <- function(key) {
    v <- vgms[[key]]$v_iso
    if (is.null(v)) return(0)
    max(v$gamma, na.rm=TRUE)
  }
  ymax_iso <- sapply(c("shop","theft","extor"), function(vid) {
    ya <- safe_max_iso(paste0("ant_",vid))
    yd <- safe_max_iso(paste0("dur_",vid))
    max(ya, yd, 1e-6) * 1.22
  })
  names(ymax_iso) <- c("shop","theft","extor")
  ymax_iso["perc"] <- if (!is.null(vgms[["dur_perc"]]$v_iso))
    max(vgms[["dur_perc"]]$v_iso$gamma, na.rm=TRUE) * 1.22 else 1

  # Escala Y compartida para anisotrópicos por variable
  safe_max_dir <- function(key) {
    v <- vgms[[key]]$v_dir
    if (is.null(v)) return(0)
    max(v$gamma, na.rm=TRUE)
  }
  ymax_aniso <- sapply(c("shop","theft","extor"), function(vid) {
    ya <- safe_max_dir(paste0("ant_",vid))
    yd <- safe_max_dir(paste0("dur_",vid))
    max(ya, yd, 1e-6) * 1.22
  })
  names(ymax_aniso) <- c("shop","theft","extor")
  ymax_aniso["perc"] <- if (!is.null(vgms[["dur_perc"]]$v_dir))
    max(vgms[["dur_perc"]]$v_dir$gamma, na.rm=TRUE) * 1.22 else 1

  # ──────────────────────────────────────────────────────────────────────
  # PÁGINA 2 — ISOTRÓPICOS: ANTES vs DURANTE
  # ──────────────────────────────────────────────────────────────────────
  par(mfrow=c(2,4), mar=c(3.8,4.5,4.8,1.0),
      oma=c(0.5,0,5.0,0), bg="white")

  # Fila 1 — ANTES (misma escala Y que DURANTE para comparar)
  for (vid in c("shop","theft","extor")) {
    key  <- paste0("ant_",vid)
    vgm  <- vgms[[key]]
    etiq <- c(shop="Hurto a Comercios\n(antes de la obra)",
              theft="Hurto a Personas\n(antes de la obra)",
              extor="Extorsion\n(antes de la obra)")[vid]
    draw_vgm(vgm$v_iso, vgm$f_iso, adjustcolor(VC[vid],.75),
             etiq, show_y=(vid=="shop"), y_max=ymax_iso[vid])
  }
  # Percepción no tiene "antes"
  par(mar=c(3.8,1.5,4.8,1.0))
  plot.new(); plot.window(xlim=c(0,1),ylim=c(0,1))
  rect(0,0,1,1,col="#EEF2FF",border="gray80")
  text(.5,.60,"Percepcion de Seguridad",cex=0.85,font=2,col=VC["perc"],adj=.5)
  text(.5,.45,"Sin datos para el\nperiodo pre-obra",cex=0.80,col="gray50",adj=.5)
  text(.5,.28,"La encuesta de percepcion\nse realizo en 2025",
       cex=0.68,col="gray55",adj=.5)

  # Fila 2 — DURANTE (misma escala Y que ANTES para comparar)
  par(mar=c(3.8,4.5,4.8,1.0))
  for (vid in c("shop","theft","extor","perc")) {
    key  <- paste0("dur_",vid)
    vgm  <- vgms[[key]]
    etiq <- c(shop="Hurto a Comercios\n(durante la obra)",
              theft="Hurto a Personas\n(durante la obra)",
              extor="Extorsion\n(durante la obra)",
              perc="Percepcion de Seguridad\n(durante la obra)")[vid]
    draw_vgm(vgm$v_iso, vgm$f_iso, VC[vid], etiq,
             show_y=(vid=="shop"), y_max=ymax_iso[vid])
  }

  mtext(paste0("ESTACIÓN ",est_id," — ",est_name,
               "   |   Variogramas ISOTRÓPICOS (promedio de todas las direcciones)"),
        outer=TRUE,side=3,line=3.8,cex=1.10,font=2,col="#1A237E")
  mtext("Fila superior: ANTES de la obra (2018-2020)  |  Fila inferior: DURANTE la obra (2021-2023)",
        outer=TRUE,side=3,line=2.5,cex=0.82,col="gray30",font=2)
  mtext(paste0("Un variograma isotrópico promedia todos los pares de puntos sin importar la ",
               "dirección geográfica. La curva sube hasta el SILL (varianza máxima) en el RANGE ",
               "(distancia a partir de la cual los puntos ya no están correlacionados)."),
        outer=TRUE,side=3,line=1.2,cex=0.70,col="gray50")

  # ──────────────────────────────────────────────────────────────────────
  # PÁGINA 3 — ANISOTRÓPICOS ANTES (fila 1) vs DURANTE (fila 2)
  # Cada columna = misma variable, misma escala Y → directamente comparable
  # ──────────────────────────────────────────────────────────────────────
  par(mfrow=c(2,3), mar=c(4.0,4.5,5.2,1.0),
      oma=c(0.5,0,5.8,0), bg="white")

  # Fila 1 — ANTES
  for (vid in c("shop","theft","extor")) {
    etiq <- c(shop="Hurto a Comercios",
              theft="Hurto a Personas",
              extor="Extorsion")[vid]
    col_ante <- c(shop="log_shop_pre",theft="log_theft_pre",
                  extor="log_extor_pre")[vid]
    draw_aniso(pts_l, col_ante, adjustcolor(VC[vid],.80),
               etiq, periodo="ANTES  (2018-2020)",
               y_max=ymax_aniso[vid])
  }

  # Fila 2 — DURANTE (misma Y que fila 1 por columna)
  for (vid in c("shop","theft","extor")) {
    etiq <- c(shop="Hurto a Comercios",
              theft="Hurto a Personas",
              extor="Extorsion")[vid]
    col_dur2 <- c(shop="log_shoplifting",theft="log_theft",
                  extor="log_extortion")[vid]
    draw_aniso(pts_l, col_dur2, VC[vid],
               etiq, periodo="DURANTE  (2021-2023)",
               y_max=ymax_aniso[vid])
  }

  mtext(paste0("ESTACION ",est_id," - ",est_name,
               "   |   Variogramas ANISOTROPICOS - ANTES vs DURANTE"),
        outer=TRUE,side=3,line=4.5,cex=1.10,font=2,col="#1A237E")
  mtext("Fila superior: ANTES (2018-2020)  |  Fila inferior: DURANTE (2021-2023). Cada columna tiene el mismo eje Y para comparar directamente.",
        outer=TRUE,side=3,line=3.1,cex=0.80,col="gray20",font=2)
  mtext("Cada color es una direccion geografica (ver leyenda). Si las curvas difieren -> ANISOTROPIA (el fenomeno se propaga mas en una direccion).",
        outer=TRUE,side=3,line=1.8,cex=0.72,col="gray40")
  mtext("ratio = range maximo / range minimo. Ratio > 1.5x = anisotropia fuerte. La direccion E-O coincide con el trazado del Metro.",
        outer=TRUE,side=3,line=0.7,cex=0.68,col="gray55")

  # ──────────────────────────────────────────────────────────────────────
  # PÁGINA 4 — PERCEPCIÓN: TOTAL vs RESIDUAL (controlando por delitos)
  # Usa percepcion CRUDA (encuesta real) — solo hexagonos con dato de encuesta
  # Variograma residual = percepcion ~ crimes → ¿explica el crimen la percepción?
  # ──────────────────────────────────────────────────────────────────────

  # Filtrar hexagonos con percepcion_sat (encuesta real + imputacion satelital)
  pts_perc <- pts_l[!is.na(pts_l$percepcion_sat),]
  n_perc   <- nrow(pts_perc)
  tiene_perc <- n_perc >= MIN_PTS

  # Variograma residual isotrópico: percepcion_sat ~ crimes
  # percepcion_sat usa predictores exogenos (Sentinel-2) -> sin endogeneidad
  v_perc_res <- if (tiene_perc) tryCatch(
    variogram(percepcion_sat ~ log_shoplifting + log_theft + log_extortion,
              data=pts_perc, cutoff=CUTOFF, width=WIDTH),
    error=function(e) NULL) else NULL
  f_perc_res <- if (!is.null(v_perc_res))
    fit_sph(v_perc_res, var(pts_perc$percepcion_sat, na.rm=TRUE)) else NULL

  # Escala Y compartida entre total y residual (para comparar)
  vgm_perc <- vgms[["dur_perc"]]
  y_tot <- if (!is.null(vgm_perc$v_iso)) max(vgm_perc$v_iso$gamma, na.rm=TRUE) else 1
  y_res <- if (!is.null(v_perc_res)) max(v_perc_res$gamma, na.rm=TRUE) else y_tot
  ymax_p4 <- max(y_tot, y_res) * 1.22

  par(mfrow=c(2,2), mar=c(3.8,4.8,5.0,1.2),
      oma=c(0.5,0,5.5,0), bg="white")

  # (1,1) — Isotrópico TOTAL (percepcion cruda, sin controlar)
  if (tiene_perc && !is.null(vgm_perc$v_iso)) {
    draw_vgm(vgm_perc$v_iso, vgm_perc$f_iso, VC["perc"],
             paste0("Percepcion TOTAL\n(encuesta+satelite, n=",n_perc," hex)"),
             show_y=TRUE, y_max=ymax_p4, cex_main=0.85)
  } else {
    par(mar=c(3.8,4.8,5.0,1.2))
    plot.new(); plot.window(xlim=c(0,1),ylim=c(0,1))
    rect(0,0,1,1,col="#EEF2FF",border="gray80")
    text(.5,.55,"Datos insuficientes\npara variograma de percepcion",
         cex=0.82,col="gray50",adj=.5)
    text(.5,.35,paste0("(solo ",n_perc," hex con encuesta\nen este buffer)"),
         cex=0.70,col="gray60",adj=.5)
  }

  # (1,2) — Isotrópico RESIDUAL (controlando por delitos)
  if (!is.null(v_perc_res)) {
    draw_vgm(v_perc_res, f_perc_res, "#7B1FA2",
             "Percepcion RESIDUAL\n(controlando por Hurto y Extorsion)",
             show_y=FALSE, y_max=ymax_p4, cex_main=0.85)
  } else {
    plot.new(); plot.window(xlim=c(0,1),ylim=c(0,1))
    text(.5,.5,if(!tiene_perc)"Datos insuficientes\npara esta estacion"
               else "Sin ajuste en\nvariograma residual",
         cex=0.85,col="gray55",adj=.5)
  }

  # (2,1) — Anisotrópico TOTAL (percepcion cruda)
  if (tiene_perc) {
    draw_aniso(pts_perc, "percepcion_sat", VC["perc"],
               "Percepcion TOTAL (anisotr.)",
               periodo=paste0("Encuesta+satelite (n=",n_perc," hex)"),
               y_max=ymax_aniso["perc"])
  } else {
    plot.new(); plot.window(xlim=c(0,1),ylim=c(0,1))
    text(.5,.5,"Datos insuficientes",cex=0.85,col="gray55",adj=.5)
  }

  # (2,2) — Panel interpretación de cuánto explica el crimen
  par(mar=c(0,0,0,0))
  plot.new(); plot.window(xlim=c(0,1),ylim=c(0,1))
  rect(0,0,1,1,col="#F3E5F5",border="gray75")

  f_tot <- vgm_perc$f_iso
  sill_t <- if(!is.null(f_tot)) sum(f_tot$psill) else NA
  rng_t  <- if(!is.null(f_tot)) f_tot$range[2]  else NA
  sill_r <- if(!is.null(f_perc_res)) sum(f_perc_res$psill) else NA
  rng_r  <- if(!is.null(f_perc_res)) f_perc_res$range[2]  else NA

  text(.5,.93,"CUANTO EXPLICA EL CRIMEN\nLA PERCEPCION DE SEGURIDAD?",
       cex=0.80,font=2,col="#4A148C",adj=.5)

  # Reduccion de Sill = varianza explicada por crimen
  if (!is.na(sill_t) && !is.na(sill_r) && sill_t > 0) {
    pct_sill <- round((sill_t - sill_r) / sill_t * 100)
    col_s <- if(pct_sill > 30)"#1B5E20" else if(pct_sill > 10)"#E65100" else "gray30"
    text(.5,.76,paste0("Varianza explicada por crimen:"),
         cex=0.72,col="gray20",adj=.5,font=2)
    text(.5,.68,paste0(pct_sill,"%  (Sill: ",round(sill_t,2)," -> ",round(sill_r,2),")"),
         cex=0.80,col=col_s,adj=.5,font=2)
    interp_s <- if(pct_sill > 40) "El crimen explica una parte IMPORTANTE\nde como se siente la inseguridad"
                else if(pct_sill > 15) "El crimen explica una parte MODERADA\nde la percepcion"
                else "El crimen explica POCO de la percepcion;\nhay otros factores en juego"
    text(.5,.58,interp_s,cex=0.68,col=col_s,adj=.5)
  } else {
    text(.5,.72,"Sin modelo ajustado\npara comparar",cex=0.75,col="gray50",adj=.5)
  }

  # Reduccion de Range = si el crimen explica la autocorrelacion espacial
  if (!is.na(rng_t) && !is.na(rng_r) && rng_t > 0) {
    pct_rng <- round((rng_t - rng_r) / rng_t * 100)
    col_r2 <- if(pct_rng > 25)"#1B5E20" else if(pct_rng > 0)"#E65100" else "#C62828"
    text(.5,.43,paste0("Alcance espacial residual:"),
         cex=0.72,col="gray20",adj=.5,font=2)
    text(.5,.35,paste0(round(rng_r),"m (era ",round(rng_t),"m, ",
                       if(pct_rng>0)paste0("-",pct_rng,"%") else paste0("+",abs(pct_rng),"%"),")"),
         cex=0.78,col=col_r2,adj=.5,font=2)
    interp_r <- if(pct_rng > 25) "El crimen explica la estructura\nespacial de la percepcion"
                else if(pct_rng > 0) "Queda algo de estructura espacial\nno explicada por el crimen"
                else "La percepcion tiene estructura\nindependiente del crimen"
    text(.5,.25,interp_r,cex=0.65,col=col_r2,adj=.5)
  }

  text(.5,.08,"Nota: variograma residual = percepcion ~ hurto.comercio +\nhurto.personas + extorsion (modelo OLS interno de gstat)",
       cex=0.55,col="gray50",adj=.5)

  mtext(paste0("ESTACION ",est_id," - ",est_name,
               "   |   Percepcion de Seguridad: Total vs Residual controlando por delitos"),
        outer=TRUE,side=3,line=4.2,cex=1.05,font=2,col="#4A148C")
  mtext("Fila superior: variogramas ISOTROPICOS (ambos con mismo eje Y). Rojo=total, Morado=residual tras quitar el efecto lineal del crimen.",
        outer=TRUE,side=3,line=2.8,cex=0.78,col="gray25",font=2)
  mtext("Si el Sill y el Range del RESIDUAL son menores: el crimen explica la percepcion. Si son iguales: hay otros factores (iluminacion, densidad, etc).",
        outer=TRUE,side=3,line=1.5,cex=0.70,col="gray45")

  # ──────────────────────────────────────────────────────────────────────
  # PÁGINA 5 — ANÁLISIS DE IMPACTO Y RECOMENDACIÓN
  # ──────────────────────────────────────────────────────────────────────
  par(mar=c(0,0,0,0), oma=c(0,0,0,0), bg="white")
  plot.new(); plot.window(xlim=c(0,1),ylim=c(0,1))

  # Cabecera
  rect(0,.93,1,1,col="#1A237E",border=NA)
  text(.5,.97,paste0("ANÁLISIS DE IMPACTO — Estación ",est_id," — ",est_name),
       cex=1.30,font=2,col="white",adj=.5)

  # Categoría destacada
  col_cat2 <- switch(substr(categoria,1,2),
                     "🔴"="#FFCDD2","🟠"="#FFE0B2",
                     "🟡"="#FFF9C4","🟢"="#C8E6C9","#F5F5F5")
  rect(.03,.86,.97,.92,col=col_cat2,border="gray70")
  text(.5,.89,categoria,cex=1.15,font=2,col="gray10",adj=.5)

  # ── Sección A: Cambio antes→durante ─────────────────────────────────
  rect(.03,.82,.97,.855,col="#E8EAF6",border=NA)
  text(.05,.838,"¿Cambió la inseguridad con la obra?",
       cex=0.82,font=2,col="#1A237E",adj=0)

  cambios <- list(
    c("Hurto a Comercios", r_ant_shop,  r_dur_shop,  VC["shop"]),
    c("Hurto a Personas",  r_ant_theft, r_dur_theft, VC["theft"]),
    c("Extorsión",         r_ant_extor, r_dur_extor, VC["extor"])
  )
  y_c <- .78
  for (ch in cambios) {
    r_a <- as.numeric(ch[2]); r_d <- as.numeric(ch[3]); col_v <- ch[4]
    if (is.na(r_a)||is.na(r_d)||r_a<=0) {
      msg <- paste0(ch[1],": datos insuficientes")
      col_msg <- "gray50"
    } else {
      pct <- round((r_d-r_a)/r_a*100)
      if (pct > 15) {
        msg <- paste0(ch[1],": el alcance AUMENTÓ un ",pct,
                      "% (",round(r_a),"m → ",round(r_d),
                      "m) — la obra amplificó el problema")
        col_msg <- "#C62828"
      } else if (pct < -15) {
        msg <- paste0(ch[1],": el alcance DISMINUYÓ un ",abs(pct),
                      "% (",round(r_a),"m → ",round(r_d),
                      "m) — la obra ayudó a contener")
        col_msg <- "#2E7D32"
      } else {
        msg <- paste0(ch[1],": sin cambio significativo (",
                      round(r_a),"m → ",round(r_d),"m)")
        col_msg <- "gray30"
      }
    }
    rect(.04,y_c-.025,.10,y_c+.015,col=col_v,border=NA)
    text(.12,y_c, msg, cex=0.72, col=col_msg, adj=0)
    y_c <- y_c - .055
  }

  # ── Sección B: ¿Alcanza estaciones vecinas? ───────────────────────────
  y_b <- y_c - .02
  rect(.03,y_b-.005,.97,y_b+.028,col="#FFF8E1",border=NA)
  text(.05,y_b+.013,"¿El patrón de inseguridad se extiende hasta las estaciones vecinas?",
       cex=0.80,font=2,col="#E65100",adj=0)

  y_b2 <- y_b-.045
  for (ch in cambios) {
    r_d <- as.numeric(ch[3]); col_v <- ch[4]
    if (is.na(r_d)||r_d<=0) next
    # Usamos el mayor range (iso), si supera 80% del cutoff asumimos que alcanza
    r_eff <- min(r_d, CUTOFF)
    alc_p <- !is.na(dp) && r_eff >= dp*.80
    alc_n <- !is.na(dn) && r_eff >= dn*.80
    if (!alc_p && !alc_n) {
      msg2 <- paste0(ch[1],": LOCALIZADO — no alcanza estaciones vecinas (",round(r_eff),"m)")
      col2 <- "#2E7D32"
    } else {
      partes <- c()
      if(alc_p&&!is.na(prev_nm)) partes <- c(partes,paste0(prev_nm," (",round(dp),"m)"))
      if(alc_n&&!is.na(next_nm)) partes <- c(partes,paste0(next_nm," (",round(dn),"m)"))
      msg2 <- paste0(ch[1],": COMPARTIDO con ",paste(partes,collapse=" y ")," — zona de riesgo extendida")
      col2 <- "#C62828"
    }
    rect(.04,y_b2-.02,.10,y_b2+.015,col=col_v,border=NA)
    text(.12,y_b2, msg2, cex=0.70, col=col2, adj=0)
    y_b2 <- y_b2-.052
  }

  # ── Sección C: Anisotropía y dirección dominante ──────────────────────
  y_an <- y_b2 - .02
  rect(.03,y_an-.005,.97,y_an+.028,col="#E8F5E9",border=NA)
  text(.05,y_an+.013,"¿La inseguridad tiene una dirección dominante?",
       cex=0.80,font=2,col="#1B5E20",adj=0)

  y_an2 <- y_an-.045
  for (vid in c("shop","theft","extor","perc")) {
    rat <- list(shop=rat_shop,theft=rat_theft,
                extor=rat_extor,perc=rat_perc)[[vid]]
    etiq <- c(shop="Hurto a Comercios",theft="Hurto a Personas",
              extor="Extorsión",perc="Percepción")[vid]
    if (is.na(rat)) next
    if (rat > 1.8)
      msg3 <- paste0(etiq,": anisotropía FUERTE (ratio=",rat,
                     "x) — hay una dirección donde el problema se propaga mucho más")
    else if (rat > 1.3)
      msg3 <- paste0(etiq,": anisotropía moderada (ratio=",rat,"x)")
    else
      msg3 <- paste0(etiq,": comportamiento uniforme en todas las direcciones (ratio=",rat,"x)")
    col3 <- if(rat>1.8)"#C62828" else if(rat>1.3)"#E65100" else "gray35"
    text(.05,y_an2, paste0("• ",msg3), cex=0.68, col=col3, adj=0)
    y_an2 <- y_an2-.048
  }

  # ── Sección D: Recomendación de política ─────────────────────────────
  y_rec <- max(y_an2-.025, .04)
  rect(.03,y_rec-.005,.97,y_rec+.028,col="#FAFAFA",border="gray80")
  text(.05,y_rec+.013,"RECOMENDACIÓN DE POLÍTICA",
       cex=0.80,font=2,col="#1A237E",adj=0)

  rec <- if (grepl("ALTA",categoria)) {
    paste0("Implementar operativos preventivos de seguridad antes de la apertura. ",
           if(tiene_tm)"Articular con la estrategia de seguridad del corredor de Transmilenio existente. "
           else"Diseñar un modelo de seguridad desde cero (no hay TM como referencia). ",
           "La inseguridad ya supera los ",round(max(r_dur_theft,r_dur_shop,na.rm=TRUE)),"m de alcance.")
  } else if (grepl("MEDIA",categoria)) {
    paste0("Monitoreo reforzado. ",
           if(tiene_tm)"Aprovechar la infraestructura de seguridad del TM para extender la cobertura. "
           else"Despliegue preventivo antes de apertura. ",
           "Foco en los delitos con mayor alcance espacial.")
  } else if (grepl("MEJORA",categoria)) {
    paste0("La obra ha tenido efecto positivo en la reducción espacial del delito. ",
           "Mantener y reforzar las estrategias actuales antes de la apertura.")
  } else {
    paste0("Inseguridad contenida. ",
           if(tiene_tm)"La experiencia del TM puede servir de modelo. "
           else"Preparar protocolos estándar de seguridad. ",
           "Seguimiento rutinario.")
  }
  text(.05,y_rec-.030, paste0(">> ",rec),
       cex=0.68,col="gray15",adj=0)

  # ══════════════════════════════════════════════════════════════════════
  # Guardar en resumen
  summary_df <<- rbind(summary_df, data.frame(
    est_id=est_id, est_name=est_name, n_pts=n_pts, tiene_tm=tiene_tm,
    r_ant_shop=round(r_ant_shop), r_ant_theft=round(r_ant_theft),
    r_ant_extor=round(r_ant_extor),
    r_dur_shop=round(r_dur_shop),  r_dur_theft=round(r_dur_theft),
    r_dur_extor=round(r_dur_extor),r_dur_perc=round(r_dur_perc),
    rat_shop=rat_shop, rat_theft=rat_theft,
    rat_extor=rat_extor, rat_perc=rat_perc,
    categoria=categoria, stringsAsFactors=FALSE
  ))
}

# ══════════════════════════════════════════════════════════════════════════════
# PÁGINA RESUMEN 1 — Tabla comparativa de todas las estaciones
# ══════════════════════════════════════════════════════════════════════════════
par(mar=c(0,0,0,0), oma=c(0,0,0,0), bg="white")
plot.new(); plot.window(xlim=c(0,1),ylim=c(0,1))

rect(0,.93,1,1,col="#1A237E",border=NA)
text(.5,.967,"RESUMEN COMPARATIVO - 16 Estaciones Metro Linea 1",
     cex=1.40,font=2,col="white",adj=.5)
text(.5,.935,"Ranges de autocorrelacion espacial (metros) - Antes vs. Durante la obra",
     cex=0.88,col="#90CAF9",adj=.5)

# Encabezados de la tabla
ys <- seq(.88,.04,len=nrow(summary_df)+2)
y_hdr <- ys[1]
hdrs <- c("Estacion","TM","N","H.Comercio\nAntes->Dur",
          "H.Personas\nAntes->Dur","Extorsion\nAntes->Dur",
          "Perc.\nDur","Categoria")
xs <- c(.02,.18,.25,.33,.46,.59,.70,.80)
for (h in seq_along(hdrs))
  text(xs[h], y_hdr, hdrs[h], cex=0.62, font=2, col="#1A237E", adj=0)
abline(h=y_hdr-.015, col="gray60", lwd=0.8)

for (j in seq_len(nrow(summary_df))) {
  r   <- summary_df[j,]
  yy  <- ys[j+1]
  bg  <- if(j%%2==0)"#F5F5F5" else "white"
  rect(0,yy-.022,1,yy+.018,col=bg,border=NA)

  # Color de categoría
  col_cat_r <- switch(substr(r$categoria,1,2),
                      "🔴"="#FFCDD2","🟠"="#FFE0B2",
                      "🟡"="#FFF9C4","🟢"="#C8E6C9","white")

  # Función para flecha de cambio
  # Si "durante" es NA (sin sill visible), se muestra como ">1km*"
  flecha <- function(a,d) {
    if(is.na(a)||a<=0) return("—")
    if(is.na(d)) return(paste0(range_display(a),"->",">1km*"))
    pct <- round((d-a)/a*100)
    paste0(range_display(a),"->",range_display(d),
           if(pct>15)"(+)" else if(pct< -15)"(-)" else "=")
  }

  vals <- c(
    paste0("E",r$est_id," ",substr(r$est_name,1,18)),
    if(r$tiene_tm)"✓" else "—",
    as.character(r$n_pts),
    flecha(r$r_ant_shop, r$r_dur_shop),
    flecha(r$r_ant_theft,r$r_dur_theft),
    flecha(r$r_ant_extor,r$r_dur_extor),
    range_display(r$r_dur_perc),
    substr(r$categoria,3,nchar(r$categoria))
  )

  col_val <- c(rep("gray15",7),
               switch(substr(r$categoria,1,2),
                      "🔴"="#C62828","🟠"="#E65100",
                      "🟡"="#F57F17","🟢"="#2E7D32","gray20"))
  rect(.78,yy-.022,1,yy+.018,col=col_cat_r,border=NA)

  for (h in seq_along(vals))
    text(xs[h], yy, vals[h], cex=0.60,
         col=col_val[h], adj=0,
         font=if(h==8)2 else 1)
}

text(.5,.01,paste0("(+) = aumento >15% | (-) = disminucion >15% | = sin cambio significativo | ",
                   ">1km* = sin sill visible: la correlacion espacial supera el buffer de 1km (patron muy difuso)"),
     cex=0.57,col="gray50",adj=.5)

# ══════════════════════════════════════════════════════════════════════════════
# PÁGINA RESUMEN 2 — Categorías y recomendaciones globales
# ══════════════════════════════════════════════════════════════════════════════
par(mar=c(0,0,0,0), oma=c(0,0,0,0), bg="white")
plot.new(); plot.window(xlim=c(0,1),ylim=c(0,1))

rect(0,.93,1,1,col="#1A237E",border=NA)
text(.5,.967,"CATEGORÍAS DE ALERTA Y RECOMENDACIONES DE POLÍTICA",
     cex=1.35,font=2,col="white",adj=.5)
text(.5,.935,"Metro Linea 1 de Bogota - Analisis pre-apertura",
     cex=0.88,col="#90CAF9",adj=.5)

cats <- table(summary_df$categoria)
col_cats <- c("🔴 ALERTA ALTA — inseguridad difusa y creciente"="#FFCDD2",
              "🟠 ALERTA MEDIA-ALTA — inseguridad muy extendida"="#FFE0B2",
              "🟠 ALERTA MEDIA — patrón direccional moderado"="#FFE0B2",
              "🟡 VIGILANCIA — inseguridad moderada"="#FFF9C4",
              "🟢 MEJORA — inseguridad se redujo con la obra"="#C8E6C9",
              "🟢 CONTROLADA — inseguridad localizada"="#C8E6C9")

text(.5,.90,"Distribución de estaciones por categoría:",
     cex=0.90,font=2,col="#1A237E",adj=.5)

y_cats <- .84
for (ct in names(cats)) {
  bg_c <- col_cats[ct]; if(is.na(bg_c)) bg_c <- "#F5F5F5"
  rect(.10,y_cats-.022,.90,y_cats+.022,col=bg_c,border="gray70")
  text(.12,y_cats, ct, cex=0.78, font=2, col="gray15", adj=0)
  text(.89,y_cats, paste0(cats[ct]," estación(es)"),
       cex=0.75, col="gray30", adj=1)
  y_cats <- y_cats - .055
}

# Estaciones con TM
n_tm  <- sum(summary_df$tiene_tm, na.rm=TRUE)
n_ntm <- sum(!summary_df$tiene_tm, na.rm=TRUE)
y_tm  <- y_cats - .025
rect(.10,y_tm-.05,.90,y_tm+.02,col="#E8EAF6",border="gray80")
text(.12,y_tm,"Transmilenio en la zona:",
     cex=0.80,font=2,col="#283593",adj=0)
text(.12,y_tm-.038,
     paste0("- ",n_tm," estaciones SI tienen TM -> pueden articular estrategias de seguridad existentes"),
     cex=0.70,col="#1B5E20",adj=0)
text(.12,y_tm-.065,
     paste0("- ",n_ntm," estaciones NO tienen TM -> requieren diseno de politica desde cero"),
     cex=0.70,col="#C62828",adj=0)

# Recomendaciones globales
y_rec2 <- y_tm - .10
rect(.05,y_rec2-.005,.95,y_rec2+.028,col="#E3F2FD",border=NA)
text(.07,y_rec2+.014,"RECOMENDACIONES GLOBALES PARA LAS AUTORIDADES",
     cex=0.85,font=2,col="#0D47A1",adj=0)

recs_g <- list(
  c("🔴/🟠","Priorizar operativos preventivos en estaciones de alta alerta ANTES de la apertura. El patrón espacial amplio indica que una sola estación puede irradiar inseguridad hacia las vecinas."),
  c("📍","Para estaciones donde el alcance isotrópico supera 600m: el radio de vigilancia debe ser mayor al estándar. Un solo punto de control en la estación NO es suficiente."),
  c("🧭","Donde se detectó anisotropía (dirección dominante): concentrar recursos en la dirección de mayor alcance, no distribuirlos uniformemente."),
  c("🚌","En estaciones sin TM: establecer un modelo de seguridad antes de la apertura con base en estos datos. No esperar al primer mes de operación."),
  c("📊","Los variogramas de percepción muestran si los ciudadanos ya sienten inseguridad en la zona. Combinar esta información con los datos de crimen para priorizar comunicación y presencia institucional.")
)
y_r <- y_rec2 - .050
for (rc in recs_g) {
  text(.07,y_r, paste0(rc[1]," ",rc[2]), cex=0.65, col="gray15", adj=0)
  y_r <- y_r - .068
}

text(.5,.02,
     paste0("Analisis elaborado por el equipo CyberRosario - Datajam Seguridad CCB | ",
            "Fuentes: Datos de delitos SIEDCO, Encuesta de Percepcion CCB 2025"),
     cex=0.58,col="gray55",adj=.5)

dev.off()
cat("PDF guardado: output/reporte_metro_l1.pdf\n")
system("open output/reporte_metro_l1.pdf")
cat("Listo. 5 páginas por estación + 2 de resumen =",n_est*5+2,"páginas totales.\n")
