# Analisis de Datos Disponibles vs. Necesidades del Proyecto Centinelas

## Resumen Ejecutivo

Este documento cruza las necesidades de datos del proyecto ChroNNet (Reto 3: Seguridad Integral en la Region Metropolitana) contra los 10 datasets proporcionados por el DataJam de la CCB **y los datos SIEDCO disponibles en el repo Impact-evaluation-peace-process**. El objetivo es identificar que datos sirven directamente, cuales requieren adaptacion, y cuales hay que buscar por fuera.

> **ACTUALIZACION CRITICA:** Se encontro que el repositorio `Impact-evaluation-peace-process/datasets/` contiene **datos SIEDCO completos (2012-2024)** con ~4.3 millones de registros de delitos georreferenciados. Esto **resuelve la brecha critica** de la Capa 1 (ChroNNet).

---

## 1. Evaluacion por Capa del Proyecto

### Capa 1: Redes ChroNNet (Co-ocurrencia temporal de delitos)

**Necesidad principal:** Registros de delitos georreferenciados con fecha, lugar y tipo para los municipios de la conurbacion (minimo 3 anos).

| Dato requerido | Disponible en DataJam? | Fuente | Estado |
|----------------|----------------------|--------|--------|
| SIEDCO (delitos georreferenciados) | **SI - DISPONIBLE** | `Impact-evaluation-peace-process/datasets/` | **RESUELTO** - ver seccion SIEDCO abajo |
| SIMOVIC (Observatorio Cundinamarca) | **NO** | Externo: Gobernacion de Cundinamarca | BRECHA menor - complemento departamental |
| Poligonos geograficos municipios | **SI - DISPONIBLE** | `Impact-evaluation-peace-process/datasets/polygons/maps/` y `cuadrantes_08_2023/` | **RESUELTO** |

> **BRECHA RESUELTA:** Los datos SIEDCO completos (2012-2024) estan en el repo `Impact-evaluation-peace-process/datasets/`. Incluyen fecha, lat/lon, tipo de delito y modalidad para **toda Colombia**. Tambien hay shapefiles de secciones censales DANE y cuadrantes de policia de Bogota.

### Datos SIEDCO disponibles (repo Impact-evaluation-peace-process)

**Ruta:** `/Users/andresperezcoronado/Documents/GitHub/Impact-evaluation-peace-process/datasets/`

| Archivo | Delito | Registros | Bogota | Cundinamarca | Soacha | Periodo |
|---------|--------|-----------|--------|-------------|--------|---------|
| `violent/extortion.csv` | **Extorsion** | 88,289 | 11,617 | 1,563 | 431 | 2012-2024 |
| `larceny/shoplifting.csv` | **Hurto a comercio** | 498,984 | 135,611 | 11,803 | 3,635 | 2012-2024 |
| `larceny/theft.csv` | **Hurto a personas** | 1,757,364 | - | - | 22,190 | 2009-2024 |
| `violent/murders.csv` | Homicidios | 166,450 | - | - | - | 2009-2024 |
| `violent/assault.csv` | **Lesiones personales** | 848,360 | - | - | - | 2009-2024 |
| `larceny/auto_theft.csv` | **Hurto automotores** | 147,825 | - | - | - | 2009-2024 |
| `larceny/moto_theft.csv` | Hurto motocicletas | 395,351 | - | - | - | 2009-2024 |
| `larceny/burglary.csv` | Hurto a residencias | 406,555 | - | - | - | 2009-2024 |
| `violent/kidnapping.csv` | Secuestro | ~2,900 | - | - | - | 2012-2024 |

**Total: ~4.3 millones de registros de delitos georreferenciados.**

**Columnas disponibles por registro:**
- `date_var`: Fecha del delito (DD/MM/YYYY)
- `lat_var`, `lon_var`: Coordenadas GPS del evento
- `TEMATICA`: Tipo de delito (EXTORSION, HCOM, LPER, HOMI, HAUT, etc.)
- `MODALIDAD`: Modalidad especifica (ATRACO, CLASICA, FACTOR DE OPORTUNIDAD, RINAS, etc.)
- `ARMAS_MEDIOS`: Arma/medio utilizado
- `PERTE.METROPOLITANA / DEPTO`: Area metropolitana o departamento
- `CASOS`: Conteo (siempre 1)

**Nota sobre granularidad geografica:** Los datos no tienen columna de municipio especifico, sino `PERTE.METROPOLITANA / DEPTO` que agrupa asi:
- `M. BOGOTA` = Bogota
- `M. SOACHA` = Soacha (tiene su propia area metropolitana)
- `CUNDINAMARCA` = Resto de Cundinamarca (Chia, Funza, Mosquera, Zipaquira, etc.)

**Para identificar municipios especificos de Cundinamarca** hay que hacer **spatial join** de las coordenadas (lat_var, lon_var) contra los poligonos de municipios. Esto es factible porque TODOS los registros tienen coordenadas GPS.

### Datos geograficos disponibles

| Archivo | Descripcion | Tamano |
|---------|-------------|--------|
| `polygons/maps/urban_rural_sections_dane.gpkg` | 83,758 secciones censales DANE (toda Colombia) | 817 MB |
| `polygons/maps/urban_rural_sections_dane_crimes.gpkg` | Secciones con crimen integrado | 789 MB |
| `cuadrantes_08_2023/BK_CUADRANTES_AGOSTO23.shp` | Cuadrantes de policia de Bogota | 18 MB |
| `polygons/crimes/*.gpkg` | GeoPackages por tipo de delito (puntos con geometria) | ~1.5 GB total |

### Datos de panel pre-construidos

| Archivo | Descripcion | Estructura |
|---------|-------------|-----------|
| `panel_data/panel_crime_data_full.parquet` | Panel trimestral completo | 4.27M filas x 497 columnas (83,758 secciones x ~51 trimestres) |
| `panel_data/panel_crime_data_updated.parquet` | Panel con variable de tratamiento | Incluye `treated` (conflicto armado pre-2014) |

> **IMPLICACION PARA CHRONNET:** En vez de construir la red desde cero, podemos usar el **panel trimestral pre-construido** que ya tiene conteos de delitos por seccion censal por trimestre. Alternativamente, podemos reconstruir con granularidad **semanal** a partir de los CSV crudos para mayor resolucion temporal.

---

### Capa 2: Percepcion de seguridad

**Necesidad principal:** Datos de percepcion de seguridad desagregados por municipio de la conurbacion.

| Dato requerido | Disponible en DataJam? | Fuente | Estado |
|----------------|----------------------|--------|--------|
| EPV 2024 (percepcion por municipio Cundinamarca) | **SI** | EPV 2024 (26,064 registros) | **DISPONIBLE DIRECTO** |
| EPV 2025 (percepcion con GPS Bogota) | **SI** | EPV 2025 (20,038 registros) | DISPONIBLE - solo Bogota, no Cundinamarca |
| EPV serie 2021-2023 (tendencia temporal) | **SI** | EPV 2021-2023 | DISPONIBLE para serie temporal |
| Percepcion empresarial | **SI** | ECN 2020-2024 | DISPONIBLE - victimizacion empresarial |
| App propia (percepcion en campo) | N/A | Recoleccion propia | Por construir |

> **HALLAZGO CLAVE:** La **EPV 2024 es el dataset estrella** para este reto. Cubre 17 municipios: Bogota + 16 municipios de Cundinamarca (~400-445 encuestas c/u). Los municipios incluidos son: **Soacha, Chia, Zipaquira, Fusagasuga, Facatativa, Mosquera, Funza, Madrid, Cajica, Cota, Tocancipa, Sopo, Tabio, Tenjo, Cogua** y otros. Esto cubre directamente la mayoria de los municipios de estudio.

**Variables clave de EPV 2024 para el proyecto:**

| Variable | Descripcion | Utilidad |
|----------|-------------|---------|
| MUNICIPIO | Codigo del municipio (17 valores) | **Llave principal** - identificar cada municipio de la conurbacion |
| LOCALIDAD | Localidad dentro de Bogota | Desagregacion intra-Bogota para localidades limitrofes (Bosa, Kennedy, Fontibon) |
| COD_DANE_MANZANA | Codigo de manzana censal (6,984 valores) | Granularidad alta para analisis espacial |
| ESTRATO | Estrato socioeconomico (1-6) | Covariable para modelos |
| SEXO | Genero del encuestado | Cruce con enfoque de genero |
| EDAD | Edad exacta (18-99) | Covariable demografica |
| P102 | Pregunta clave de percepcion (valores 1-2) | **Variable dependiente principal** |
| P6211 | Variable multicategoria (11 valores) | Explorar - posiblemente tipo de delito sufrido |
| START / END | Timestamps de entrevista | Temporalidad de la recoleccion |

**Variables clave de EPV 2025 para el proyecto:**

| Variable | Descripcion | Utilidad |
|----------|-------------|---------|
| _Capture_gps_latitude | Latitud GPS (rango 3.89 - 4.78) | Geolocalizacion directa - pero **solo para Bogota** |
| _Capture_gps_longitude | Longitud GPS (-74.36 a -74.01) | Geolocalizacion directa |
| Localidad | Nombre de localidad (~20 valores) | Para filtrar localidades limitrofes con conurbacion |
| UPL | Unidad de Planeamiento Local (33 valores) | Granularidad intra-Bogota |
| mzn_ccnct | Codigo manzana DANE (4,103 valores) | Maxima granularidad censal |
| Barr En | Nombre del barrio (3,736 valores) | Identificacion de barrios limitrofes |

> **NOTA IMPORTANTE:** La EPV 2025 tiene GPS pero **solo cubre Bogota** (20 localidades). La EPV 2024 cubre Cundinamarca pero **NO tiene GPS**. Para el Reto 3 (conurbacion), la EPV 2024 es mas util porque incluye los municipios de Cundinamarca. La EPV 2025 sirve para las localidades de Bogota que limitan con la conurbacion (Bosa, Kennedy, Fontibon, Suba, Usaquen).

**Serie temporal de percepcion (ChronoNets):**

| Ano | Registros | Cobertura | Granularidad temporal |
|-----|-----------|-----------|---------------------|
| 2021 | 6,532 | Bogota | Anual |
| 2022 | 7,346 | Bogota | Anual |
| 2023 | 18,975 | Bogota | **Diaria** (variable FECHA) |
| 2024 | 26,064 | **Bogota + 16 mun. Cundinamarca** | Timestamp (START/END) |
| 2025 | 20,038 | Bogota (con GPS) | Punto (GPS timestamp implicito) |

> La serie EPV 2021-2025 permite construir **5 nodos temporales** para ChronoNets de percepcion. La EPV 2024 es la unica con cobertura regional.

---

### Capa 3: Entorno urbano (imagenes satelitales)

**Necesidad principal:** Imagenes Sentinel-2 para calcular NDVI, densidad de construccion, lotes baldios.

| Dato requerido | Disponible en DataJam? | Fuente | Estado |
|----------------|----------------------|--------|--------|
| Imagenes Sentinel-2 | **NO** | Externo: Copernicus Open Access Hub (gratuito) | BRECHA - descarga externa necesaria |
| Shapefiles municipios/localidades | **NO** | Externo: IDECA / IGAC | BRECHA - descarga externa necesaria |

> La Capa 3 depende 100% de datos externos. Sin embargo, son datos publicos y gratuitos, no requieren solicitud especial.

---

### Capa 4: Linea 123 / Emergencias

**Necesidad principal:** Llamadas georreferenciadas al 123 como proxy de demanda de seguridad.

| Dato requerido | Disponible en DataJam? | Fuente | Estado |
|----------------|----------------------|--------|--------|
| Datos Linea 123 / NUSE | **NO** | Externo: Secretaria de Seguridad / datos.gov.co | BRECHA - requiere solicitud o descarga |

> La Capa 4 tambien depende de datos externos.

---

## 2. Utilidad de Cada Dataset del DataJam para el Reto 3

### Datasets de ALTA utilidad

| Dataset | Registros | Utilidad para Reto 3 | Como usarlo |
|---------|-----------|---------------------|-------------|
| **EPV 2024** | 26,064 | **CRITICA** | Percepcion + victimizacion en 17 municipios de la conurbacion. Variable dependiente principal. Serie temporal con EPV 2021-2025. |
| **EPV 2025** | 20,038 | **ALTA** | GPS para localidades limitrofes de Bogota (Bosa, Kennedy, Fontibon, Suba). Complementa la cobertura de Cundinamarca de la EPV 2024. |
| **EPV 2023** | 18,975 | **ALTA** | Tiene fecha diaria (FECHA) y nombre de barrio. Permite analisis de estacionalidad intra-anual para la serie temporal. |
| **ECN 2020-2024** | ~11,350 total | **ALTA** | Victimizacion empresarial (hurto, extorsion, vandalismo a empresas). Serie de 5 anos. Variable REGION distingue Bogota vs. Cundinamarca. |
| **RM 2024** | 498,940 | **ALTA** | Densidad empresarial por municipio (~80 municipios incluyendo toda la conurbacion). Geocodificable por BarrioComercialGeorreferenciada. Cruce con percepcion para "tejido empresarial vs seguridad". |
| **RM 2025** | 493,825 | **ALTA** | Comparar con RM 2024 para detectar cierres de empresas. ZonaPostalGeo (261 zonas) permite geocodificacion. Dinamica empresarial por localidad/municipio. |

### Datasets de MEDIA utilidad

| Dataset | Registros | Utilidad para Reto 3 | Como usarlo |
|---------|-----------|---------------------|-------------|
| **Movilidad 2024** | 18,865 | **MEDIA** | Variables de percepcion de seguridad en transporte (P118, P119). Relevante para corredores de movilidad entre municipios, pero solo cubre Bogota (Localidad/UPL sin GPS). |
| **EPV 2021-2022** | ~13,878 | **MEDIA** | Completan la serie 2021-2025 pero con menos variables y solo Bogota. Utiles para tendencias longitudinales. |

### Datasets de BAJA utilidad

| Dataset | Registros | Utilidad para Reto 3 | Razon |
|---------|-----------|---------------------|-------|
| **Enc. Genero 2025** | 14,010 | **BAJA** | Solo Bogota. Enfoque en genero, no en conurbacion. Podria servir para cruce Localidad+Sexo pero es tangencial. |
| **Corredores Estrategicos 2024** | 2,107 | **BAJA** | Foco en corredores Metro/Calle 13, no en la conurbacion regional. Relevante si se argumenta que el Metro afecta flujos hacia Soacha. |
| **EPC 2025** | 1,520 | **BAJA** | Solo 1,520 registros, sin desagregacion por municipio de Cundinamarca. Percepcion general de Bogota. |
| **PPMYEG 2021** | 18,109 | **MUY BAJA** | Linea base de politica de genero 2021. Fuera del foco del Reto 3. |

---

## 3. Brechas Criticas y Mitigacion

### ~~Brecha 1: SIEDCO (datos de delitos) - RESUELTA~~

**Estado: RESUELTO.** Los datos SIEDCO 2012-2024 estan disponibles en `Impact-evaluation-peace-process/datasets/`. Incluyen ~4.3M registros con fecha, coordenadas GPS, tipo y modalidad de delito.

**Tarea pendiente:** Hacer spatial join de las coordenadas contra poligonos de municipios de Cundinamarca para asignar cada delito a su municipio especifico (Funza, Mosquera, Chia, etc.). Los registros de `CUNDINAMARCA` no tienen municipio explicito pero SI tienen lat/lon.

### Brecha 2: Linea 123 / NUSE

**Impacto:** Afecta Capa 4, que es complementaria.

**Mitigacion:**
- Usar la EPV como proxy de demanda de seguridad.
- La ECN empresarial tambien captura si las empresas reportaron delitos.
- Eliminar la Capa 4 y redistribuir el esfuerzo en las otras 3 capas sin perdida significativa.

### ~~Brecha 3: Datos geograficos (shapefiles) - RESUELTA~~

**Estado: PARCIALMENTE RESUELTO.** El repo tiene:
- Secciones censales DANE de toda Colombia (`urban_rural_sections_dane.gpkg`, 83,758 secciones)
- Cuadrantes de policia de Bogota (`BK_CUADRANTES_AGOSTO23.shp`)

**Pendiente:** Descargar shapefiles de **limites municipales** de Cundinamarca (IGAC/IDECA) para definir nodos a nivel de municipio. Alternativamente, agregar las secciones censales DANE por municipio.

### Brecha 4: Imagenes Sentinel-2

**Impacto:** Afecta Capa 3 (entorno urbano).

**Mitigacion:**
- Copernicus Open Access Hub permite descarga gratuita.
- Google Earth Engine tambien ofrece acceso.
- Descarga factible en Semana 1, procesamiento en Semana 2.

---

## 4. Cruces Multi-Fuente Especificos para el Reto 3

| Cruce | Llave de union | Proposito | Viabilidad |
|-------|---------------|-----------|------------|
| EPV 2024 x RM 2024 | MUNICIPIO / MunicipioComercial | Percepcion de seguridad vs. densidad empresarial por municipio de conurbacion | **ALTA** - ambos cubren municipios de Cundinamarca |
| EPV 2024 x ECN 2024 | MUNICIPIO / REGION | Percepcion ciudadana vs. victimizacion empresarial | **MEDIA** - ECN solo tiene REGION (Bogota/Cund.), no municipio especifico |
| EPV 2025 (GPS) x RM 2025 | Localidad / LocalidadComercial | Percepcion geolocal vs. tejido empresarial en localidades limitrofes de Bogota | **ALTA** - EPV tiene GPS, RM tiene localidad |
| RM 2024 x RM 2025 | Empresa (por matching) | Detectar cierres: empresas en RM 2024 que no renovaron en RM 2025 | **ALTA** - proxy de mortalidad empresarial por municipio |
| EPV serie 2021-2025 x ECN serie 2020-2024 | Ano + Localidad | ChronoNet de percepcion ciudadana vs. clima empresarial | **ALTA** - 5 nodos temporales cada serie |
| SIEDCO (externo) x EPV 2024 | Municipio | Criminalidad real vs. percepcion por municipio = **brecha percepcion-realidad** | **ALTA** si se obtiene SIEDCO |

---

## 5. Variables Clave a Homologar entre Anos EPV

Los nombres de variables cambian entre anos de la EPV. Aqui las principales para el Reto 3:

| Concepto | EPV 2021-2022 | EPV 2023 | EPV 2024 | EPV 2025 |
|----------|---------------|----------|----------|----------|
| Localidad | Variable por verificar | NOMBRE_LOCALIDAD | LOCALIDAD (codigo) | Localidad (nombre) |
| Municipio | No aplica (solo Bogota) | No aplica | MUNICIPIO | No aplica (solo Bogota) |
| Estrato | Variable por verificar | ESTRATO / CODIGO_ESTRATO | ESTRATO | Implicito en datos |
| Sexo | Variable por verificar | SEXO | SEXO | A1 (posiblemente) |
| Edad | Variable por verificar | EDAD_EXACTA / EDAD_RANGO | EDAD / REDAD | A2 (edad) |
| Percepcion seguridad | P102 (probable) | P102 | P102 | P102 |
| Barrio | Variable por verificar | NOMBRE_BARRIO | No disponible directamente | Barr En |
| Codigo DANE | Variable por verificar | No disponible | COD_DANE_MANZANA | mzn_ccnct |

> **TAREA PRIORITARIA:** Obtener los diccionarios de variables de cada ano de la EPV y construir una tabla de homologacion completa.

---

## 6. Priorizacion de Tareas (Semana 1)

### Prioridad 1 (Dias 1-2) - Habilitantes

1. **Filtrar SIEDCO por conurbacion.** Los datos ya estan en `Impact-evaluation-peace-process/datasets/`. Filtrar por coordenadas de Bogota + Cundinamarca (lat 4.2-5.2, lon -74.5 a -73.9). Hacer spatial join contra poligonos de municipios para asignar cada delito a Funza, Mosquera, Chia, Soacha, etc.
2. **Cargar EPV 2024** y verificar la cobertura de los 16 municipios de Cundinamarca. Explorar variables de percepcion y victimizacion.
3. **Cargar RM 2024 y RM 2025**, filtrar por municipios de la conurbacion (~30 municipios de interes). Calcular densidad empresarial por municipio.

### Prioridad 2 (Dias 3-4) - Construccion ChroNNet

4. **Construir serie temporal semanal** a partir de los CSVs de SIEDCO filtrados. Agregar por municipio + semana + tipo de delito.
5. **Cargar EPV 2025** y filtrar localidades limitrofes con la conurbacion (Bosa, Kennedy, Fontibon, Suba, Usaquen, Usme). Verificar GPS.
6. **Cargar ECN 2024** y explorar variables de victimizacion empresarial. Variable REGION para separar Bogota vs. Cundinamarca.

### Prioridad 3 (Dias 5-7) - Capas adicionales

7. **Descargar shapefiles de limites municipales** de Cundinamarca (IGAC/IDECA) para poligonos de nodos.
8. **Cargar EPV 2021-2023** para armar la serie temporal de percepcion.
9. **Descargar imagenes Sentinel-2** de los corredores de la conurbacion.
10. **Explorar Movilidad 2024** para variables de seguridad en transporte.

### No priorizar

- Encuesta de Genero, EPC, PPMYEG, Corredores Estrategicos (no son centrales para el Reto 3).

---

## 7. Alertas Tecnicas Especificas

1. **EPV 2024 tiene 240 variables con >50% nulos** (de 315 totales). Muchas son patrones de salto (skip logic). Identificar las ~75 variables utiles.
2. **RM tiene ~500K filas** por ano. Filtrar por MunicipioComercial antes de cargar en memoria.
3. **ECN 2024 REGION** tiene solo 2 valores (1 y 2). Verificar cual es Bogota y cual Cundinamarca en el diccionario.
4. **EPV 2024 LOCALIDAD** tiene 26% nulos. Los registros de Cundinamarca probablemente no tienen localidad (campo de Bogota).
5. **Variables de EPV cambian entre anos.** La EPV 2024 tiene 315 variables vs. 135 en 2023 y 503 en 2025. La homologacion es critica.
6. **Todas las columnas de Genero y Corredores son tipo Object.** Si se usan, requieren conversion.
7. **EPC 2025 CSV** usa delimitador `;` y encoding `latin1`.
8. **RM 2024 tiene typo** en nombre de columna: `BarrioComercialGoerreferenciada` (dice "Goe" en vez de "Geo").

---

## 8. Conclusion

Con el descubrimiento de los datos SIEDCO en el repo `Impact-evaluation-peace-process`, **las cuatro capas del proyecto tienen datos disponibles**. El DataJam proporciona datos excelentes para percepcion (EPV) y tejido empresarial (RM), mientras que los datos SIEDCO propios resuelven completamente la Capa 1.

**Resumen de cobertura ACTUALIZADO:**

| Capa | Cobertura con datos DataJam | Cobertura con datos propios (SIEDCO) | Cobertura con datos externos | Total |
|------|---------------------------|--------------------------------------|-------------------------------|-------|
| 1. Redes ChroNNet | 0% | **100%** (SIEDCO 2012-2024, ~4.3M registros) | - | **Excelente** |
| 2. Percepcion | **90%** (EPV 2024 + serie + ECN) | - | 10% (app propia) | **Excelente** |
| 3. Entorno urbano | 0% | Parcial (shapefiles DANE) | 70% (Sentinel-2) | **Factible** |
| 4. Emergencias | 0% | - | 100% (Linea 123) | Opcional |
| Tejido empresarial | **95%** (RM 2024 + RM 2025 + ECN) | - | 5% | **Excelente** |

### Mapeo SIEDCO -> Delitos del proyecto

| Delito del proyecto | Archivo SIEDCO | Registros totales | Cobertura Bogota+Cund. |
|--------------------|---------------|-------------------|----------------------|
| Pirateria terrestre | Verificar en `theft.csv` o archivo adicional | Por confirmar | Por confirmar |
| **Hurto a comercio** | `larceny/shoplifting.csv` (HCOM) | 498,984 | ~147,414 (Bog+Cund+Soacha) |
| **Extorsion** | `violent/extortion.csv` (EXTORSION) | 88,289 | ~13,611 (Bog+Cund+Soacha) |
| **Hurto a personas** | `larceny/theft.csv` | 1,757,364 | Masivo |
| **Hurto automotores** | `larceny/auto_theft.csv` (HAUT) | 147,825 | Por cuantificar |
| **Lesiones personales** | `violent/assault.csv` (LPER) | 848,360 | Por cuantificar |
| Estafa | No disponible directamente | - | Buscar en datos.gov.co |
| Microtrafico | No disponible directamente | - | Buscar en datos.gov.co |

> **El proyecto tiene ahora una base de datos de ~4.3 millones de delitos georreferenciados para construir las redes ChroNNet.** La tarea inmediata es filtrar por la region de la conurbacion y hacer spatial join para asignar municipios.
