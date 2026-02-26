# Análisis de Datos Disponibles vs. Necesidades del Proyecto CyberRosario

## Resumen Ejecutivo

Este documento cruza lo que el proyecto CyberRosario necesita (Reto 2: Seguridad y Obras Públicas) contra los datos que realmente proporciona el DataJam de Seguridad de la CCB. Se identifican coincidencias, brechas y oportunidades.

---

## 1. Mapeo: Datos del Proyecto vs. Datos del DataJam

### CAPA 1: Delitos (antes vs. durante la obra)

| Lo que necesitamos | ¿Lo tiene el DataJam? | Fuente alternativa | Estado |
|---|---|---|---|
| Registros de delitos georreferenciados (SIEDCO) | **NO** en DataJam | **SÍ en repo Impact-evaluation** | DISPONIBLE (ver abajo) |
| Datos de línea de emergencias 123/NUSE | **NO** | No disponible | BRECHA menor |
| Delitos por tipo (extorsión, hurto, etc.) con lat/lon | **NO** en DataJam | **SÍ en repo Impact-evaluation** | DISPONIBLE (ver abajo) |

#### DATOS DE DELITOS ENCONTRADOS: Repo `Impact-evaluation-peace-process/datasets/`

Se encontró un repositorio propio con **4.3 millones de registros de crímenes georreferenciados de Colombia (2012-2023)** provenientes del SIEDCO. Todos tienen `lat_var`, `lon_var`, `date_var`, `MODALIDAD`, `ARMAS_MEDIOS` y `PERTE.METROPOLITANA / DEPTO`. También existen como **GeoPackage (.gpkg)** con geometría ya construida.

**Inventario de datos de delitos disponibles:**

| Tipo de delito | Archivo | Registros totales | Registros Bogotá (M. BOGOTÁ) | Periodo | Relevancia para Reto 2 |
|---|---|---|---|---|---|
| **Hurto a personas (theft)** | `larceny/theft.csv` | 1,757,364 | **633,546** | 2012-2023 | ALTA - Delito más frecuente |
| **Lesiones personales (assault)** | `violent/assault.csv` | 848,360 | **169,680** | 2012-2023 | ALTA |
| **Hurto a comercio (shoplifting)** | `larceny/shoplifting.csv` | 498,984 | **135,611** | 2012-2023 | ALTA - Directo sobre comercios |
| **Hurto a residencias (burglary)** | `larceny/burglary.csv` | 406,555 | **86,519** | 2012-2023 | MEDIA |
| **Extorsión** | `violent/extortion.csv` | 88,289 | **11,617** | 2012-2023 | ALTA - Clave para MiPymes |
| **Hurto autos** | `larceny/auto_theft.csv` | 147,825 | **49,080** | 2012-2023 | MEDIA |
| **Hurto motos** | `larceny/moto_theft.csv` | 395,351 | **47,247** | 2012-2023 | MEDIA |
| **Homicidios** | `violent/murders.csv` | 166,450 | **14,711** | 2012-2023 | MEDIA-BAJA (para contexto) |
| **TOTAL Bogotá** | | | **~1,148,011** | | |

**Columnas disponibles (estructura común):**
- `date_var`: fecha del delito (DD/MM/YYYY)
- `lat_var`, `lon_var`: coordenadas GPS (float)
- `MODALIDAD`: tipo específico del delito
- `MODALIDAD_GRUPO`: agrupación de modalidad
- `ARMAS_MEDIOS`: arma o medio utilizado
- `PERTE.METROPOLITANA / DEPTO`: área metropolitana o departamento
- `CASOS`: conteo (generalmente 1)

**Archivos GeoPackage (.gpkg) también disponibles** en `polygons/crimes/` con geometría ya construida para análisis espacial directo en R (sf/gstat).

**Recurso adicional:** Shapefile de **cuadrantes de policía de Bogotá** (`cuadrantes_08_2023/BK_CUADRANTES_AGOSTO23.shp`) para agregar delitos por cuadrante.

**Recurso adicional:** GeoPackage de **secciones urbanas/rurales DANE con crímenes** (`polygons/urban_rural_sections_dane_crimes.gpkg`, 819 MB) — polígonos censales con conteo de crímenes ya integrado.

**Veredicto Capa 1: BRECHA RESUELTA.** Tenemos ~1.15 millones de delitos georreferenciados en Bogotá (2012-2023) con lat/lon, fecha y tipo de delito. Esto cubre perfectamente el análisis antes vs. durante la obra. El periodo 2012-2023 permite tener una línea base sólida antes de las obras del Metro (iniciadas ~2021) y TransMilenio.

> **Nota:** Los datos llegan hasta dic 2023. Para datos más recientes (2024-2025), se puede complementar con datos abiertos de la Policía.

> **Acción:** Filtrar por coordenadas de Bogotá (lat 4.4-4.85, lon -74.25 a -73.95) o usar el polígono de Bogotá para un filtrado preciso. Los .gpkg ya están listos para uso con `sf::st_read()` en R.

---

### CAPA 2: Percepción de seguridad

| Lo que necesitamos | ¿Lo tiene el DataJam? | Fuente en el DataJam | Estado |
|---|---|---|---|
| Percepción de seguridad georreferenciada | **SÍ (parcial)** | EPV 2025 (20,038 registros con GPS lat/lon) | DISPONIBLE - Solo para 2025, solo Bogotá |
| Percepción en corredores específicos (Metro, Av68, Calle13) | **SÍ** | Encuesta Corredores Estratégicos 2024 (2,107 registros) | DISPONIBLE - Cubre Metro y Calle 13 |
| Percepción por localidad (serie temporal) | **SÍ** | EPV 2021-2025 (~79K registros totales) | DISPONIBLE |
| Percepción de seguridad en transporte | **SÍ** | Encuesta de Movilidad 2024 (18,865 x 843 variables) | DISPONIBLE |
| Percepción diferenciada por género | **SÍ** | Encuesta de Género 2025 (14,010 registros) | COMPLEMENTARIO |
| App propia de recolección en campo | **N/A** | Dato propio del equipo | POR RECOLECTAR |

**Veredicto Capa 2:** Esta es la capa **mejor cubierta** por el DataJam. La EPV 2025 con GPS es el dato estrella. La Encuesta de Corredores Estratégicos es directamente sobre los corredores del Metro y Calle 13. **Falta cobertura para Av. 68**.

**Hallazgos clave:**
- La **EPV 2025 tiene coordenadas GPS** (`_Capture_gps_latitude`, `_Capture_gps_longitude`) con ~20,000 puntos únicos y 0% nulos. Esto permite hacer variogramas y kriging directamente.
- La **Encuesta de Corredores Estratégicos** pregunta directamente: *"¿usted considera que la percepción de seguridad..."* (variable P43.1) con 5 opciones de respuesta. Esto es exactamente lo que necesitamos para los corredores Metro y Calle 13.
- La **Encuesta de Movilidad** tiene 843 variables incluyendo seguridad en transporte, desagregada por Localidad y UPL.

---

### CAPA 3: Tejido empresarial

| Lo que necesitamos | ¿Lo tiene el DataJam? | Fuente en el DataJam | Estado |
|---|---|---|---|
| Registro Mercantil con aperturas/cierres | **SÍ** | RM 2024 (498,940 emp.) y RM 2025 (493,825 emp.) | DISPONIBLE |
| Ubicación de empresas por localidad/barrio | **SÍ** | RM tiene LocalidadComercial, BarrioComercial, BarrioComercialGeorreferenciada | DISPONIBLE |
| Fecha de matrícula y renovación | **SÍ** | FechaMatricula (desde 1972), FechaRenova | DISPONIBLE |
| Sector económico y tamaño | **SÍ** | CIIU, SECTOR_ECONOMICO, TamañoEmpresa | DISPONIBLE |
| Género del propietario | **SÍ** | Variable Genero en RM | DISPONIBLE |
| Victimización empresarial | **SÍ** | ECN 2020-2024 (serie de 5 años) | DISPONIBLE |
| Google Places (censo actual) | **N/A** | Dato propio vía API | POR RECOLECTAR |
| Fecha de cancelación/cierre | **PARCIAL** | RM 2024 tiene FechaCancelación pero casi todo es "-" (solo 1 valor único en muestra) | LIMITADO |

**Veredicto Capa 3:** Muy buena cobertura. El RM es la base más grande (~500K registros). Sin embargo, hay una **limitación importante**: la variable `FechaCancelación` parece estar casi vacía (todos "-"), lo que dificulta calcular tasas de cierre directamente. Se puede inferir indirectamente comparando RM 2024 vs RM 2025 (empresas que aparecen en 2024 pero no en 2025 = posibles cierres).

**Hallazgos clave:**
- El RM tiene **BarrioComercialGeorreferenciada** que permite geocodificación indirecta
- El RM 2025 incluye **ZonaPostalGeo** (261 zonas postales) para geocodificación
- La **ECN 2024** mide directamente victimización empresarial (P11__1: ¿fue víctima de delito?) y costos de seguridad
- Variables financieras (Activos, Pasivos, Ingresos, Utilidad) permiten medir impacto económico

---

### CAPA 4: Entorno urbano (imágenes satelitales)

| Lo que necesitamos | ¿Lo tiene el DataJam? | Fuente en el DataJam | Estado |
|---|---|---|---|
| Imágenes Sentinel-2 | **NO** | No incluido | EXTERNO - Descargar de Copernicus |
| NDVI, cambio de uso de suelo | **NO** | No incluido | EXTERNO - Procesar a partir de Sentinel-2 |
| Datos geográficos de Bogotá (IDECA) | **NO** | No incluido | EXTERNO - Descargar de IDECA |

**Veredicto Capa 4:** Totalmente externa al DataJam. Esto es esperado y está bien; estos son datos abiertos y gratuitos.

---

## 2. Datos del DataJam que SÍ Usamos Directamente

| Dataset DataJam | Capa del Proyecto | Variables Clave | Prioridad |
|---|---|---|---|
| **EPV 2025** (20,038 x 503) | Capa 2 (Percepción) | GPS lat/lon, Localidad, UPL, Barrio, percepción (P102+), Estrato, Sexo, Edad | **ALTA** - Dato estrella para variogramas/kriging |
| **Encuesta Corredores Estratégicos 2024** (2,107 x 312) | Capa 2 (Percepción) | P43.1 percepción seguridad, sector económico (F5), empleados (P1), tamaño local (P13), arriendo (P47), FECHA | **ALTA** - Dato directo sobre corredores Metro y Calle 13 |
| **Registro Mercantil 2024** (498,940 x 66) | Capa 3 (Empresas) | LocalidadComercial, BarrioComercialGeorreferenciada, FechaMatricula, CIIU, Genero, Activos, SECTOR_ECONOMICO | **ALTA** |
| **Registro Mercantil 2025** (493,825 x 51) | Capa 3 (Empresas) | Mismo + ZonaPostalGeo, Añomatrícula | **ALTA** |
| **ECN 2024** (2,549 x 324) | Capa 3 (Empresas) | P11__1 (víctima de delito), P17 (percepción entorno), P12, REGION, F2-F5 | **MEDIA** |
| **Enc. Movilidad 2024** (18,865 x 843) | Capa 2 (Percepción) | Localidad, UPL, P118 (seguridad), P119_x, F1-F2 | **MEDIA** |
| **EPV 2024** (26,064 x 315) | Capa 2 (Percepción) | MUNICIPIO (17 municipios), LOCALIDAD, P102, SEXO, ESTRATO, COD_DANE_MANZANA | **MEDIA** - Serie temporal (sin GPS) |
| **EPV 2023** (18,975 x 135) | Capa 2 (Serie temporal) | NOMBRE_LOCALIDAD, NOMBRE_BARRIO, FECHA, P102, SEXO | **MEDIA** - Estacionalidad con fecha diaria |
| **EPV 2021-2022** | Capa 2 (Serie temporal) | Variables de percepción base | **BAJA** - Solo para tendencias |

## 3. Datos del DataJam que NO Usamos (o uso marginal)

| Dataset | Razón de exclusión |
|---|---|
| **Encuesta de Género 2025** (14,010 x 312) | Interesante pero tangencial al reto de obras. Podría usarse para análisis de género si hay tiempo. Todas las variables son Object (requiere limpieza pesada). |
| **EPC 2025 Microdatos** (1,520 x 177) | Pocos registros (1,520), sin GPS, enfoque muy general (gobierno, economía, salud). No es específica de seguridad cerca de obras. |
| **PPMYEG 2021** (18,109 x 351) | Línea base de política de género. Fuera del alcance del reto. |
| **EPC Suprema / Tablas** | Datos agregados, no individuales. Menos útil para análisis espacial. |
| **ECN 2020-2023** | Útil para serie temporal pero no prioritario si el tiempo es limitado. |

---

## 4. Brechas Críticas y Plan de Mitigación

### ~~BRECHA 1: No hay datos de delitos georreferenciados~~ RESUELTA
- **Estado:** Se encontraron **~1.15 millones de delitos georreferenciados de Bogotá (2012-2023)** en el repo `Impact-evaluation-peace-process/datasets/`
- **Ruta:** `~/Documents/GitHub/Impact-evaluation-peace-process/datasets/` (subcarpetas `larceny/`, `violent/`, `polygons/crimes/`)
- **Formato:** CSV (separador `;`) y GeoPackage (.gpkg) listo para R
- **Limitación residual:** Datos hasta dic 2023. Para 2024-2025 consultar datos abiertos de la Policía
- **Acción inmediata:** Filtrar por bounding box de Bogotá o usar polígono. Los tipos de delito necesarios (extorsión, hurto a comercio, hurto a personas, lesiones personales) están todos disponibles

### BRECHA 2: No hay datos de línea 123/NUSE
- **Impacto:** Se pierde el proxy histórico de percepción (antes de la obra)
- **Mitigación:** Usar la serie EPV 2021-2025 como proxy temporal. La EPV 2023 tiene FECHA diaria que permite análisis pre/durante obra
- **Alternativa:** La victimización reportada en EPV por año sirve como indicador del cambio temporal

### BRECHA 3: La Encuesta de Corredores Estratégicos solo cubre Metro y Calle 13, NO Av. 68
- **Impacto:** El corredor TransMilenio Av. 68 no tiene datos específicos del DataJam
- **Mitigación:** Usar la EPV 2025 (con GPS) filtrando puntos cercanos al corredor de la Av. 68. Complementar con la Encuesta de Movilidad por localidad.
- **Alternativa:** Priorizar los corredores Metro y Calle 13 y usar Av. 68 como contraste con datos menos granulares

### BRECHA 4: FechaCancelación del RM está casi vacía
- **Impacto:** No se puede calcular directamente la tasa de cierre de negocios
- **Mitigación:** Comparar RM 2024 vs RM 2025 por matching de matrículas. Empresas en 2024 que no renovaron en 2025 = posibles cierres
- **Nota:** El campo `FechaRenova` sí tiene datos buenos y permite identificar quién no renovó

### BRECHA 5: No hay georreferenciación de la Encuesta de Corredores Estratégicos
- **Impacto:** Los 2,107 registros de corredores no tienen lat/lon, solo Tramo (Metro/Calle 13)
- **Mitigación:** Usar la variable FECHA (que tiene timestamp) y el Tramo para segmentar, pero no se puede hacer kriging directamente con esta encuesta
- **Alternativa:** Los datos de campo propios (app) llenarán este vacío con GPS

---

## 5. Oportunidades No Previstas en el Proyecto Original

### 5.1. GPS de EPV 2025 para variogramas directos
El proyecto original planea recolectar datos propios con la app como fuente principal de percepción georreferenciada. Sin embargo, la **EPV 2025 ya tiene 20,000 puntos con GPS** y variables de percepción de seguridad. Esto significa que:
- Se puede hacer kriging **inmediatamente** con datos existentes, sin esperar la recolección de campo
- La recolección propia complementa y densifica en los corredores específicos, pero no es el único insumo
- Se pueden hacer variogramas con la EPV 2025 como primera iteración y luego refinar con datos propios

### 5.2. Código de manzana DANE (mzn_ccnct) en EPV 2025
La variable `mzn_ccnct` tiene 4,103 manzanas únicas. Esto permite enlazar con datos DANE de población, estratificación y uso de suelo a nivel de manzana sin necesidad de GPS.

### 5.3. Serie temporal EPV 2021-2025 para análisis antes/durante obra
La EPV 2023 tiene FECHA diaria y la EPV 2024 tiene timestamps START/END. Las obras del Metro comenzaron en 2021. Esto significa que la serie EPV 2021-2025 **ya captura el periodo antes y durante la obra**, al menos a nivel de localidad. No es necesario depender solo de datos de delitos para el análisis temporal.

### 5.4. ECN como complemento directo para H5 (MiPymes vulnerables)
La ECN pregunta directamente sobre victimización empresarial, tamaño de empresa (F5: micro/pequeña/mediana/grande), y sector económico. Esto valida H5 directamente sin necesidad de inferirlo solo del RM.

### 5.5. Encuesta de Movilidad para H3 (Anisotropía)
La Encuesta de Movilidad tiene variables de percepción de seguridad por modo de transporte. Las personas que cruzan perpendicularmente el corredor (en bus, a pie) vs. las que se mueven paralelo (en TransMilenio) pueden tener percepciones diferentes. Esto complementa el análisis de anisotropía.

---

## 6. Recomendación de Priorización de Datos

### Prioridad 1 (Semana 1 - Inmediato)
1. **EPV 2025** → Cargar, limpiar, verificar GPS. Hacer variograma exploratorio.
2. **Encuesta Corredores Estratégicos 2024** → Cargar, limpiar (todo es Object), extraer P43.1 y variables clave.
3. **Registro Mercantil 2024 y 2025** → Cargar (OJO: ~500K filas cada uno, pesados). Filtrar por localidades de los corredores.

### Prioridad 2 (Semana 1-2)
4. **Datos de delitos SIEDCO** → YA DISPONIBLES en `Impact-evaluation-peace-process/datasets/`. Filtrar Bogotá de los CSV/GPKG.
5. **Encuesta de Movilidad 2024** → Cargar, identificar variables de seguridad con diccionario (1,512 variables).
6. **ECN 2024** → Cargar para análisis de victimización empresarial.

### Prioridad 3 (Semana 2-3)
7. **EPV 2023-2024** → Para serie temporal de percepción.
8. **Imágenes Sentinel-2** → Descargar y procesar.
9. **ECN serie 2020-2023** → Si hay tiempo, para tendencias empresariales.

### No prioritario (solo si hay tiempo)
10. Encuesta de Género 2025
11. EPC 2025
12. PPMYEG 2021

---

## 7. Alertas Técnicas para el Procesamiento

| Alerta | Dataset | Detalle |
|---|---|---|
| Todas las columnas son Object | Corredores Estratégicos, Género | Requieren conversión a numérico antes de cualquier análisis |
| Archivos muy pesados (~500K filas) | RM 2024, RM 2025 | Filtrar por localidad antes de cargar completo. Usar `read_csv` con `col_select` o similar |
| Nombres de variables cambian entre años | EPV 2021-2025, ECN 2020-2024 | Necesaria tabla de homologación |
| >50% de variables con nulos | EPV (334/503), Movilidad (675/843) | Muchas variables de filtro/skip pattern. Seleccionar variables útiles primero |
| EPV 2025 tiene 503 columnas | EPV 2025 | Seleccionar solo las ~25-50 variables relevantes para el proyecto |
| RM tiene BarrioComercialG**oe**rreferenciada | RM 2024/2025 | Ojo con el typo en el nombre de la columna (dice "Goe" en lugar de "Geo") |
| ECN 2023 puede tener estructura diferente | ECN 2023 | Datos posiblemente en hojas secundarias del Excel |

---

## 8. Resumen Visual

```
DATOS DEL DATAJAM                          CAPAS DEL PROYECTO
─────────────────                          ──────────────────

EPV 2025 (GPS!) ──────────────────────────→ CAPA 2: Percepción (★ dato estrella)
EPV 2021-2024 ────────────────────────────→ CAPA 2: Serie temporal percepción
Corredores Estratégicos ──────────────────→ CAPA 2: Percepción en Metro y Calle 13
Enc. Movilidad ───────────────────────────→ CAPA 2: Seguridad en transporte

RM 2024 + RM 2025 ───────────────────────→ CAPA 3: Tejido empresarial
ECN 2024 ─────────────────────────────────→ CAPA 3: Victimización empresarial

Repo Impact-eval (SIEDCO) ────────────────→ CAPA 1: Delitos ★ 1.15M registros Bogotá
[NO DISPONIBLE: Sentinel-2] ── ✗ ────────→ CAPA 4: Entorno (EXTERNO)
[NO DISPONIBLE: 123/NUSE] ──── ✗ ────────→ CAPA 2: Proxy histórico (BRECHA)

Género, EPC, PPMYEG ─────────────────────→ (Complementarios, no prioritarios)
```
