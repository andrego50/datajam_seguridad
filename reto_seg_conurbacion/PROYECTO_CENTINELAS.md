# EQUIPO CENTINELAS ROSARISTAS

**Semillero de Investigacion — Universidad del Rosario**

---

## DATAJAM DE SEGURIDAD

**Camara de Comercio de Bogota**

---

## Reto 3: Seguridad Integral en la Region Metropolitana

**Analisis de redes temporales de delitos (ChroNNet) para identificar corredores criminales y su relacion con la percepcion de seguridad en la conurbacion Bogota-Cundinamarca**

---

**Tutor:** Andres Perez Coronado, Ph.D.

**Fecha:** Febrero 2026

---

## 1. Resumen del Reto

Este documento es la guia completa del proyecto Centinelas Rosar*i*stas para el Datajam de Seguridad organizado por la Camara de Comercio de Bogota. Nuestro equipo, conformado por estudiantes del semillero de investigacion de la Universidad del Rosario y un tutor, enfrenta el **Reto 3: Seguridad Integral en la Region Metropolitana**.

### 1.1. Que nos piden?

El reto nos pide estudiar el impacto de las percepciones y experiencias de inseguridad en los municipios que comparten limites geograficos con Bogota y en aquellos municipios que, a pesar de no compartir limite, tienen dinamicas interrelacionadas de seguridad por la conurbacion. En palabras simples: los delitos que afectan a las empresas en Mosquera, Funza o Soacha se mueven sincronizados con los de Bogota? La gente que vive en estos municipios percibe la inseguridad de manera diferente a lo que muestran las cifras reales?

### 1.2. Los municipios y provincias de estudio

Vamos a estudiar dos grandes ejes geograficos de la Region Metropolitana, seleccionados porque concentran el 95% de los delitos de Cundinamarca:

- **Provincia Sabana de Occidente:** Funza, Mosquera, Madrid, Facatativa, Bojaca, El Rosal, Subachoque, Zipacon. Corredor logistico e industrial clave, conectado con Bogota por la Calle 80 y la Autopista Medellin.
- **Provincia Sabana Centro:** Chia, Cajica, Cota, Tenjo, Tabio, Sopo, Tocancipa, Gachancipa, Zipaquira, Cogua, Nemocon. Eje residencial y comercial al norte de Bogota, conectado por la Autopista Norte y la via Cota-Chia.
- **Municipios con conurbacion directa:** Soacha (completamente integrada a Bogota por el sur), Mosquera, Funza, Cota y Chia (distintos grados de integracion urbana).
- **Municipios sin frontera directa pero con dinamicas interrelacionadas:** Facatativa, Zipaquira, Tocancipa, Cajica, entre otros, que dependen economicamente de Bogota y comparten flujos de personas, mercancias y actividad criminal.

Cada uno de estos ejes genera dinamicas de seguridad diferentes: corredores de carga terrestre, zonas de expansion residencial sin consolidar, centros logisticos y zonas francas. Nuestro trabajo es descubrir las conexiones ocultas entre estas dinamicas.

---

## 2. Que Vamos a Hacer? (Nuestra Propuesta)

Nuestra propuesta se basa en una idea central: los delitos que afectan a las empresas en la Region Metropolitana no ocurren de manera aislada. Hay zonas que se "activan" al mismo tiempo del ano con los mismos tipos de delito, revelando corredores criminales invisibles para las estadisticas tradicionales. Para descubrir estos corredores, usaremos una tecnica llamada **ChroNNet (Redes Cronologicas)**.

### 2.1. Que es ChroNNet? (Explicacion sencilla)

Imaginen un mapa donde cada municipio (o zona dentro de un municipio grande como Soacha) es un punto. Cada semana observamos que delitos ocurren en cada punto. Si dos puntos presentan el mismo tipo de delito en la misma semana, los conectamos con una linea.

Despues de tres anos, esas lineas forman una red. Algunas conexiones seran fuertes (siempre se activan juntas) y otras debiles (coincidencias ocasionales). Las conexiones fuertes nos revelan **corredores criminales**: rutas o zonas que comparten dinamicas delictivas sincronizadas.

Lo poderoso de este enfoque es que descubre relaciones que no son obvias. Por ejemplo, podriamos encontrar que cuando sube la pirateria terrestre en Madrid, tambien sube el hurto a comercio en Funza y la extorsion en Fontibon (Bogota), revelando un posible corredor criminal que cruza tres jurisdicciones.

### 2.2. Red multiplex: varias capas de delitos

No construiremos una sola red, sino varias redes superpuestas (una **red multiplex**). Cada capa corresponde a un tipo de delito. Esto permite responder: en los sitios donde hay pirateria terrestre tambien hay extorsion? El hurto a comercio y el hurto a personas se activan en las mismas zonas? Cuando encontramos zonas conectadas en multiples capas simultaneamente, estamos frente a "hotspots multi-delictivos" que sugieren la presencia de estructuras criminales complejas.

### 2.3. El marco multinivel de problematicas

Para entender las conexiones que la red revele, clasificaremos los problemas en tres niveles, que pueden presentarse con correlacion espacial (zonas vecinas afectadas) o sin ella (zonas distantes que se activan al tiempo):

| Nivel | Con correlacion espacial | Sin correlacion espacial |
|-------|--------------------------|--------------------------|
| Local | Hurto a comercio que se propaga entre barrios vecinos de un municipio | Dos barrios distantes del mismo municipio con picos simultaneos de hurto |
| Subnacional | Corredor de pirateria terrestre Bogota-Facatativa por la Autopista Medellin | Extorsion sincronizada en Soacha y Zipaquira sin proximidad geografica |
| Nacional / Internacional | Redes transnacionales que usan corredores logisticos de la Sabana | Estructuras de extorsion operadas desde otras regiones/paises |

#### 2.3.1. Coordinacion espacial de problematicas

Una de las aplicaciones mas potentes del marco multinivel es que permite identificar que unidades de policia y que niveles de gobierno deben coordinarse para enfrentar cada tipo de problematica. Al clasificar un asunto en la red, determinamos si tiene correlacion espacial (es decir, si irradia a zonas vecinas) o no. Esto es fundamental porque un delito que no irradia se puede gestionar localmente, mientras que uno que si irradia exige coordinacion entre multiples jurisdicciones.

**Problematicas sin correlacion espacial (no irradian a otras zonas):**

| Alcance | Limites | Ejemplo | Unidades policiales |
|---------|---------|---------|---------------------|
| Local | Municipales definidos, unicos por municipio | Homicidios por intolerancia | Estaciones, distritos, seccionales de especialidades |
| Subnacional | Municipales difusos, entre unidades vecinas | Homicidios entre grupos armados | Metropolitanas y departamentos |
| Nacional / Internacional | Departamentales difusos, entre dptos. vecinos y no vecinos | Contrabando, mineria ilegal | Regiones de policia, direcciones, jefatura del servicio |

**Problematicas con correlacion espacial (irradian a otras zonas):**

| Alcance | Limites | Ejemplo | Unidades policiales |
|---------|---------|---------|---------------------|
| Local-Subnacional | Municipales y departamentales definidos, unidades vecinas | Abigeato | Metropolitanas y departamentos |
| Local-Nacional / Internacional | Municipales y departamentales definidos, unidades no vecinas | Turismo sexual | Comandantes de region, jefatura nacional |
| Local-Subnacional-Nacional / Internacional | Departamentales y municipales difusos | Trafico de armas de fuego, delitos informaticos | Direcciones operativas, jefatura nacional |

Este marco de coordinacion es especialmente relevante para nuestro proyecto porque la Region Metropolitana tiene multiples jurisdicciones policiales superpuestas: la Policia Metropolitana de Bogota, el Departamento de Policia Cundinamarca, y las estaciones locales de cada municipio. Cuando nuestra red ChroNNet detecte un corredor criminal que cruza varias jurisdicciones (por ejemplo, pirateria terrestre sincronizada entre Madrid, Funza y Fontibon), estas tablas nos permiten recomendar exactamente que nivel de coordinacion policial se necesita. Esto convierte nuestras recomendaciones en algo directamente accionable por las autoridades.

La distincion entre problematicas que irradian y las que no irradian es clave: si la red muestra que la extorsion en Soacha y la extorsion en Zipaquira se activan al mismo tiempo pero sin correlacion espacial (no son municipios vecinos), eso sugiere una estructura criminal de alcance subnacional o nacional que opera de forma remota, y la respuesta debe involucrar comandos de region o direcciones nacionales, no solo las estaciones locales. En cambio, si el hurto a comercio irradia de Mosquera a Funza (municipios vecinos), la coordinacion entre las dos estaciones locales bajo la Metropolitana puede ser suficiente.

### 2.4. Nuestras cuatro capas de analisis

El proyecto se organiza en cuatro grandes capas que se integran al final:

| Capa | Que analizamos | Resultado esperado |
|------|----------------|-------------------|
| 1. Redes de delitos | Co-ocurrencia temporal de delitos entre poligonos geograficos, semana a semana | Mapa de corredores criminales y comunidades sincronizadas |
| 2. Percepcion | Como se sienten los ciudadanos y comerciantes respecto a la seguridad (EPV + app propia) | Mapa de percepcion vs. criminalidad real: donde coinciden y donde divergen |
| 3. Entorno urbano | Imagenes satelitales: densidad urbana, lotes baldios, vias, zonas industriales | Variables del planeamiento urbano que explican activacion delictiva |
| 4. Emergencias | Llamadas a la Linea 123 georreferenciadas como proxy de demanda de seguridad | Complemento de la percepcion: lo que la gente reporta en tiempo real |

---

## 3. Hipotesis a Probar

Estas son las preguntas concretas que vamos a responder con datos. Cada hipotesis se puede confirmar o rechazar con nuestro analisis:

1. **Los municipios de la conurbacion se activan sincronicamente.** Esperamos que la red ChroNNet muestre comunidades de municipios que presentan los mismos delitos en las mismas semanas, revelando corredores criminales que cruzan limites administrativos.

2. **Existen conexiones sin proximidad geografica.** Municipios que no comparten frontera (como Soacha y Zipaquira) pueden estar conectados en la red temporal, sugiriendo operacion de estructuras criminales que operan en multiples territorios.

3. **Los hotspots multi-delictivos coinciden con nodos logisticos.** Las zonas donde confluyen multiples tipos de delito en la red multiplex corresponden a puntos criticos del corredor logistico: cruces de vias nacionales, zonas francas, centros de distribucion.

4. **La percepcion de inseguridad diverge de la criminalidad real en Cundinamarca.** Los datos de la EPV muestran que el 55,8% de los cundinamarqueses siente que la inseguridad aumento, pero solo el 8,3% fue victima. Esperamos demostrar que esta brecha se explica por la influencia mediatica (noticias nacionales) mas que por la realidad local.

5. **El entorno urbano predice la activacion delictiva.** Las zonas con menor consolidacion urbana (lotes baldios, baja densidad, ausencia de equipamientos), identificadas por imagenes satelitales, aparecen con mayor frecuencia como nodos activos en la red.

6. **La extorsion tiene dinamica de red diferente a los hurtos.** La extorsion, que crecio de 5,2% a 7,3% segun la EPV 2024, muestra conexiones de largo alcance (operacion remota), mientras que los hurtos muestran conexiones de corto alcance (contiguidad).

---

## 4. Datos que Vamos a Usar

Trabajaremos con multiples fuentes de datos. Algunas las entregan los organizadores del datajam, otras las recolectamos nosotros y otras las descargamos de fuentes publicas.

### 4.1. Datos proporcionados por el Datajam

| Fuente | Que contiene | Para que la usamos |
|--------|-------------|-------------------|
| EPV 2024 (CCB) | Encuesta a 26.055 hogares en 19 localidades de Bogota y 16 municipios de Cundinamarca sobre percepcion y victimizacion (95% confiabilidad) | Variable principal de percepcion; comparar con datos reales de la red |
| SIEDCO (Policia Nacional) | Registros de delitos georreferenciados con fecha, lugar y tipo para los municipios de estudio (minimo 3 anos) | Insumo principal para construir las redes ChroNNet |
| Observatorio de Cundinamarca (SIMOVIC) | Cruces de 8 fuentes oficiales para 116 municipios, 18 categorias delictivas, tendencias de 10 anos | Complementar SIEDCO con analisis departamental y tendencias historicas |

### 4.2. Datos que recolectamos nosotros

| Fuente | Que contiene | Para que la usamos |
|--------|-------------|-------------------|
| App de recoleccion de percepcion | Respuestas georreferenciadas de comerciantes y vecinos en municipios clave | Complementar la EPV con datos en tiempo real en zonas especificas de interes |

### 4.3. Datos de fuentes publicas

| Fuente | Que contiene | Para que la usamos |
|--------|-------------|-------------------|
| Linea 123 / NUSE | Llamadas de emergencia georreferenciadas con fecha y tipo | Proxy de percepcion de inseguridad y demanda de seguridad |
| Imagenes Sentinel-2 (ESA) | Imagenes satelitales gratuitas con resolucion de 10 metros | Variables del entorno urbano: vegetacion, construccion, lotes baldios |
| Datos abiertos (IDECA / IGAC) | Informacion geografica: manzanas, localidades, usos del suelo, vias | Poligonos base (nodos de la red) y contexto espacial |

### 4.4. Delitos que vamos a modelar

Seleccionamos los delitos que impactan directamente el tejido empresarial y la percepcion de seguridad:

- **Pirateria terrestre:** robo de carga en vias. Afecta directamente la logistica empresarial en los corredores Bogota-Facatativa y Bogota-Zipaquira. Bajo 41% en Cundinamarca en 2024.
- **Hurto a establecimiento comercial:** robos directos a negocios. Los 16 municipios que concentran el 95% de los delitos del departamento son precisamente los de la conurbacion.
- **Extorsion:** cobros ilegales a negocios ("vacunas"). Crecio de 5,2% a 7,3% segun la EPV 2024. Es el delito de mayor crecimiento y el que mas preocupa al sector empresarial.
- **Hurto a personas:** robos a peatones y clientes. Afecta la percepcion de seguridad de empleados y clientes que se desplazan entre municipios.
- **Hurto de automotores y autopartes:** impacto logistico fuerte en los corredores de conurbacion donde circulan flotas empresariales.
- **Lesiones personales:** indicador de violencia urbana que correlaciona fuertemente con percepcion de inseguridad.
- **Estafa:** creciente en contextos empresariales, especialmente en modalidad digital.
- **Microtrafico:** variable contextual que genera ecosistemas delictivos y activa zonas especificas de la red.

---

## 5. Metodologia Paso a Paso

### 5.1. Capa 1: Construccion de las redes ChroNNet

Esta capa es el corazon del proyecto. Usamos los datos historicos de delitos para construir redes que revelan conexiones temporales entre zonas geograficas.

**Pasos:**

1. **Definir los poligonos (nodos):** cada municipio, o cada zona dentro de municipios grandes como Soacha. Usamos los datos geograficos del IGAC/IDECA.
2. **Construir la serie temporal semanal:** para cada poligono y cada tipo de delito, contar cuantos eventos ocurren por semana durante los 3 anos de datos.
3. **Calcular co-ocurrencias:** si dos poligonos presentan eventos del mismo delito en la misma semana, se crea una conexion (arista). La fuerza de la conexion depende de cuantas semanas coinciden.
4. **Construir una red por cada tipo de delito (red multiplex):** una capa para pirateria, otra para extorsion, otra para hurto a comercio, etc.
5. **Identificar comunidades:** usar algoritmos de deteccion de comunidades en redes (Louvain, Infomap) para encontrar grupos de zonas que se activan juntas.
6. **Cruzar las capas:** detectar donde coinciden multiples delitos (hotspots multi-delictivos). Estos son los nodos criticos.

### 5.2. Capa 2: Percepcion de seguridad

Cruzamos los resultados de la red con los datos de percepcion para entender donde la realidad y la percepcion divergen.

**Pasos:**

1. **Mapear la percepcion de la EPV** sobre los mismos poligonos de la red. La EPV 2024 cubre 16 municipios de Cundinamarca con 6.710 hogares encuestados.
2. **Complementar con datos de la app propia:** recolectar encuestas rapidas en municipios especificos donde necesitemos mayor resolucion.
3. **Analizar la brecha percepcion-realidad:** las zonas con mayor activacion en la red son las que tienen peor percepcion? O hay zonas con baja criminalidad pero alta percepcion de inseguridad (influencia mediatica)?
4. **Identificar los factores que forman la percepcion:** la EPV muestra que en Cundinamarca las fuentes principales son el voz a voz, las redes sociales y los noticieros. Cuantificar este efecto.

### 5.3. Capa 3: Entorno urbano desde imagenes satelitales

Las imagenes satelitales nos permiten entender como el planeamiento urbano influye en la activacion delictiva.

**Variables que extraemos:**

- **NDVI (vegetacion):** indice que mide cuanta vegetacion hay. Las zonas con mas arboles tienden a ser percibidas como mas seguras (teoria CPTED).
- **Densidad de construccion:** zonas consolidadas vs. zonas en expansion sin planificacion adecuada.
- **Lotes baldios y zonas industriales abandonadas:** puntos criticos potenciales de inseguridad.
- **Red vial y conectividad:** los corredores viales que conectan municipios son tambien los corredores por donde circulan las dinamicas delictivas.

### 5.4. Capa 4: Linea 123 y demanda de seguridad

Las llamadas a la Linea 123 capturan eventos que no llegan a denuncia formal pero reflejan la inseguridad percibida. Las usamos como variable temporal complementaria: las llamadas se correlacionan con las activaciones de la red? Hay zonas con muchas llamadas pero pocos delitos registrados (cifra oculta)?

### 5.5. Integracion final y clasificacion multinivel

Al final, todos los hallazgos se clasifican segun el marco multinivel (local, subnacional, nacional/internacional), con y sin correlacion espacial. Esto permite que las recomendaciones sean pertinentes para cada nivel de gobierno: alcaldias municipales, gobernacion, gobierno nacional.

---

## 6. Herramientas que Vamos a Usar

Todo el analisis se hace en R. No necesitan ser expertos en programacion; el tutor se encarga del codigo. Pero es bueno que conozcan las herramientas:

| Herramienta | Para que sirve | Ejemplo en nuestro proyecto |
|-------------|---------------|---------------------------|
| R + RStudio | Lenguaje de programacion para analisis estadistico | Todo el proyecto se programa aqui |
| igraph | Paquete para construccion y analisis de redes | Construir las redes ChroNNet y detectar comunidades |
| sf | Paquete para datos geograficos | Manejar poligonos de municipios, ubicaciones de delitos |
| terra | Paquete para imagenes satelitales | Extraer NDVI y variables del entorno urbano |
| leaflet | Paquete para mapas interactivos | Mapas de la app Shiny con redes y corredores |
| Shiny | Framework para aplicaciones web | La app interactiva final |
| visNetwork | Visualizacion interactiva de redes | Visualizar la red ChroNNet de forma interactiva |
| tidyverse | Conjunto de paquetes para manipulacion de datos | Limpiar y transformar todas las bases de datos |

---

## 7. Cronograma: 4 Semanas

### Semana 1: Datos y recoleccion de campo

| Responsable | Tareas |
|-------------|--------|
| Estudiante 1 | Recoleccion de percepcion en campo: municipios del eje Sabana Occidente (Mosquera, Funza, Madrid). Meta: minimo 100-150 encuestas georreferenciadas con la app. |
| Estudiante 2 | Recoleccion de percepcion en campo: municipios del eje Sabana Centro (Chia, Cajica, Cota). Misma meta de encuestas. |
| Estudiante 3 | Recoleccion de percepcion en campo: Soacha y localidades limitrofes de Bogota (Bosa, Kennedy, Fontibon). Misma meta. |
| Tutor | Descarga y limpieza de datos SIEDCO y SIMOVIC. Descarga de imagenes Sentinel-2. Preparacion de poligonos base (nodos de la red). Solicitud de datos de Linea 123. |

### Semana 2: Construccion de redes y procesamiento

| Responsable | Tareas |
|-------------|--------|
| Estudiante 1 | Clasificar y verificar las respuestas de percepcion de su corredor. Apoyar al tutor en la interpretacion de las comunidades detectadas. |
| Estudiante 2 | Procesar imagenes satelitales con el paquete terra en R: calcular NDVI, identificar cambios de uso del suelo. El tutor proporciona el codigo base. |
| Estudiante 3 | Estructurar la base de datos de la EPV por municipio. Mapear la percepcion sobre los poligonos de la red. |
| Tutor | Programar las redes ChroNNet en R con igraph: co-ocurrencias semanales, deteccion de comunidades, analisis multiplex. Generar primeros mapas de corredores. |

### Semana 3: Analisis integrado

| Responsable | Tareas |
|-------------|--------|
| Estudiante 1 | Analizar la brecha percepcion-realidad por municipio. Documentar hallazgos preliminares. |
| Estudiante 2 | Cruzar variables de entorno urbano con los nodos de la red. Crear visualizaciones comparativas. |
| Estudiante 3 | Redactar secciones de contexto, marco conceptual y clasificacion multinivel del documento final. |
| Tutor | Integrar las cuatro capas. Clasificar hallazgos por marco multinivel. Empezar estructura de la app Shiny. |

### Semana 4: App Shiny y presentacion

| Responsable | Tareas |
|-------------|--------|
| Estudiante 1 | Preparar slides de presentacion: seccion de problema y contexto de la Region Metropolitana. |
| Estudiante 2 | Preparar slides: seccion de resultados de la red y hallazgos de percepcion. |
| Estudiante 3 | Preparar slides: seccion de recomendaciones y conclusiones. Ensayar la presentacion oral. |
| Tutor | Construir y pulir la app Shiny. Integrar mapas de redes, corredores y percepcion. Revisar y ajustar slides. |

> **Fecha critica:** dejar al menos 3 dias al final de la semana 4 exclusivamente para pulir la app y ensayar la presentacion.

---

## 8. Estructura del Proyecto en R

El proyecto en R se organiza en carpetas claras para que todos los miembros del equipo sepan donde esta cada cosa:

| Carpeta / Archivo | Que contiene |
|-------------------|-------------|
| `centinelas/` | Carpeta raiz del proyecto |
| `data/raw/` | Datos originales sin modificar (nunca se tocan directamente) |
| `data/processed/` | Datos limpios y listos para analizar |
| `data/spatial/` | Archivos geograficos (shapefiles, GeoJSON de poligonos) |
| `data/raster/` | Imagenes satelitales Sentinel-2 |
| `scripts/01_download.R` | Descarga automatica de datos |
| `scripts/02_clean.R` | Limpieza y preparacion de datos |
| `scripts/03_chronnet.R` | Construccion de redes ChroNNet y analisis multiplex |
| `scripts/04_communities.R` | Deteccion de comunidades y hotspots multi-delictivos |
| `scripts/05_perception.R` | Analisis de percepcion EPV y brecha con realidad |
| `scripts/06_satellite.R` | Procesamiento de imagenes satelitales (NDVI, etc.) |
| `scripts/07_integration.R` | Integracion de las cuatro capas y clasificacion multinivel |
| `app/` | Aplicacion Shiny (app.R, ui.R, server.R) |
| `output/maps/` | Mapas de corredores y redes generados |
| `output/figures/` | Graficos y figuras |
| `docs/` | Documentacion del proyecto (este documento, notas) |

---

## 9. Vision de la App Shiny

La aplicacion Shiny es nuestro producto final interactivo. Permite a los jueces y potencialmente a los tomadores de decisiones explorar los resultados de forma dinamica.

### 9.1. Funcionalidades principales

- **Selector de municipio/provincia:** elegir entre Sabana Occidente, Sabana Centro, Soacha o ver toda la region.
- **Selector de delito:** elegir que capa de la red multiplex visualizar: pirateria, extorsion, hurto a comercio, etc.
- **Mapa central interactivo:** mapa con la red ChroNNet superpuesta sobre los poligonos. Los nodos se colorean por comunidad y las aristas por fuerza de conexion.
- **Panel de percepcion:** mapa de calor con la percepcion de seguridad de la EPV, superpuesto a los corredores criminales detectados.
- **Comparador multiplex:** visualizacion que muestra que delitos coinciden en cada zona (hotspots multi-delictivos).
- **Panel de entorno:** imagenes satelitales con las variables de entorno urbano superpuestas a la red.
- **Resumen estadistico:** cifras clave por municipio: grado de conexion en la red, percepcion EPV, numero de delitos, brecha percepcion-realidad.

### 9.2. Diseno de la interfaz

La app tendra un diseno limpio con tres paneles principales: un panel lateral izquierdo con los controles de seleccion, un panel central grande con el mapa interactivo (leaflet + visNetwork), y un panel inferior con estadisticas y graficos. Se usara el paquete `bslib` para un aspecto moderno y profesional.

---

## 10. Recomendaciones que Esperamos Producir

El reto nos pide generar recomendaciones especificas, realizables y basadas en datos. Estas son las lineas que esperamos fundamentar:

- **Coordinacion intermunicipal en corredores criticos:** si la red revela que ciertos municipios se activan juntos, recomendar operaciones conjuntas de policia entre esas jurisdicciones especificas.
- **Monitoreo de extorsion como prioridad regional:** dado su crecimiento (5,2% a 7,3%), recomendar un sistema de alerta temprana basado en la dinamica de red de la extorsion.
- **Intervencion en hotspots multi-delictivos:** focalizar recursos en las zonas donde confluyen multiples delitos, que son las mas probables sedes de estructuras criminales organizadas.
- **Gestion de percepcion:** donde la brecha percepcion-realidad es grande (mucha percepcion, poca criminalidad), recomendar estrategias de comunicacion y visibilizacion de resultados de seguridad.
- **Planeamiento urbano preventivo:** usar las variables satelitales para recomendar intervenciones en lotes baldios, iluminacion y equipamientos en las zonas que la red identifique como vulnerables.
- **Proteccion de corredores logisticos:** recomendaciones especificas para las vias donde la red detecte sincronizacion de pirateria terrestre.

---

## 11. Glosario de Terminos

Para que todo el equipo hable el mismo idioma:

| Termino | Que significa (en simple) |
|---------|--------------------------|
| **ChroNNet** | Red Cronologica. Metodo que conecta zonas geograficas cuando sus eventos delictivos coinciden en el tiempo. |
| **Red multiplex** | Conjunto de redes superpuestas donde cada capa representa un tipo diferente de delito. |
| **Nodo** | Cada punto de la red: un municipio o una zona dentro de un municipio (poligono geografico). |
| **Arista** | La conexion entre dos nodos. Existe cuando ambos presentan delitos en el mismo periodo de tiempo. |
| **Comunidad (en redes)** | Grupo de nodos densamente conectados entre si. Revela cuales municipios comparten dinamicas delictivas. |
| **Conurbacion** | Cuando dos o mas ciudades crecen tanto que se fusionan fisicamente, formando un area urbana continua. |
| **Correlacion espacial** | Cuando zonas geograficamente cercanas presentan comportamientos similares. |
| **Hotspot multi-delictivo** | Zona donde coinciden multiples tipos de delito, sugiriendo estructuras criminales complejas. |
| **EPV** | Encuesta de Percepcion y Victimizacion de la Camara de Comercio de Bogota. |
| **SIEDCO** | Sistema de Informacion Estadistico Delincuencial, Contravencional y Operativo de la Policia Nacional. |
| **SIMOVIC** | Sistema de Informacion y Monitoreo de Violencias de Cundinamarca, del Observatorio de Seguridad. |
| **Pirateria terrestre** | Robo de mercancias transportadas por carretera. |
| **CPTED** | Prevencion del Crimen a traves del Diseno Ambiental. Teoria que dice que el diseno del espacio fisico influye en el crimen. |
| **NDVI** | Indice de Vegetacion. Numero de imagenes satelitales que mide cuanta vegetacion hay en cada punto. |
| **Proxy** | Indicador indirecto de algo que no podemos medir directamente. Ej: llamadas al 123 como proxy de percepcion. |
| **Shiny** | Framework de R para crear aplicaciones web interactivas sin necesidad de saber desarrollo web. |
| **Sentinel-2** | Satelite de la Agencia Espacial Europea que toma fotos de toda la Tierra cada 5 dias. Gratuitas. |
| **Georreferenciacion** | Asignar coordenadas geograficas (latitud y longitud) a un dato. Permite ponerlo en un mapa. |

---

## 12. Consejos para el Equipo

### Para la recoleccion en campo

- Distribuirse espacialmente por los municipios, no acumular encuestas en un solo punto. Es mejor tener 100 encuestas bien distribuidas que 200 en la misma cuadra.
- Registrar siempre la ubicacion GPS antes de iniciar la encuesta. Si la app no captura bien la ubicacion, anotar la direccion manualmente.
- Cubrir multiples municipios del eje asignado: no concentrarse solo en el casco urbano principal.
- Ser respetuosos con los comerciantes. Explicar que es un ejercicio academico de la Universidad del Rosario en el marco del Datajam de la CCB.
- Ir en horarios variados: manana, mediodia y tarde. La percepcion puede cambiar segun la hora.

### Para el procesamiento de datos

- Nunca modificar los datos originales. Siempre trabajar con copias en la carpeta `data/processed/`.
- Documentar todo lo que hacen: si limpian un dato, anotar por que y como.
- Si algo no cuadra en los datos, preguntar antes de asumir. Es mejor perder 10 minutos preguntando que 2 horas arreglando un error.

### Para la presentacion

- Empezar con el problema (la inseguridad en la conurbacion afecta a miles de empresas y no respeta limites municipales), luego la solucion (nuestro enfoque de redes temporales), despues los hallazgos y terminar con recomendaciones concretas.
- La visualizacion de la red ChroNNet con los corredores criminales es nuestro producto estrella visual. Asegurense de que se vea espectacular.
- Usar la app Shiny en vivo durante la presentacion para mostrar la interactividad.
- Practicar la presentacion al menos dos veces con todo el equipo.

---

**Vamos Centinelas Rosar*i*stas!**
