# EQUIPO CYBERROSARIO

**Semillero de Investigación — Universidad del Rosario**

## DATAJAM DE SEGURIDAD

**Cámara de Comercio de Bogotá**

### Reto 2: Seguridad y Obras Públicas

*Análisis del impacto de las obras de transporte público en la percepción de seguridad y el tejido empresarial de Bogotá*

**Tutor:** Andrés Pérez Coronado, Ph.D.
**Fecha:** Febrero 2026

---

## 1. Resumen del Reto

Este documento es la guía completa del proyecto CyberRosario para el Datajam de Seguridad organizado por la Cámara de Comercio de Bogotá. Nuestro equipo, conformado por tres estudiantes del semillero de investigación de la Universidad del Rosario y un tutor, enfrenta el **Reto 2: Seguridad y Obras Públicas**.

### 1.1. ¿Qué nos piden?

El reto nos pide analizar cómo las grandes obras de transporte público que se construyen actualmente en Bogotá afectan la seguridad y la sensación de seguridad de los empresarios, especialmente de los negocios pequeños y medianos (MiPymes). En palabras simples: ¿las obras hacen que la zona sea más o menos segura? ¿Los dueños de negocios se sienten más o menos protegidos? ¿Han cambiado los delitos en esas zonas?

### 1.2. Los tres corredores de estudio

Vamos a estudiar tres grandes obras que están transformando la ciudad:

- **Primera Línea del Metro:** la obra más grande de la historia de Bogotá, que atraviesa la ciudad desde el suroccidente hasta el centro-norte.
- **TransMilenio Avenida 68:** un nuevo corredor de bus rápido que recorre una de las avenidas más transitadas de la ciudad de sur a norte.
- **TransMilenio Calle 13:** extensión del sistema de bus rápido hacia el occidente de la ciudad, conectando con municipios vecinos.

Cada uno de estos corredores genera impactos diferentes en su entorno: cierres viales, demoliciones, presencia de maquinaria, cambios en el flujo de personas y vehículos. Nuestro trabajo es medir esos impactos en términos de seguridad.

---

## 2. ¿Qué Vamos a Hacer? (Nuestra Propuesta)

Nuestra propuesta se basa en una idea central: el impacto de una obra de transporte en la seguridad no es igual en todos los puntos. Entre más cerca estés de la obra, más fuerte es el efecto, pero ¿hasta dónde llega ese efecto? Para responder esa pregunta, vamos a usar una herramienta matemática llamada **variograma**.

### 2.1. ¿Qué es un variograma? (Explicación sencilla)

Imaginen que están parados justo al lado de una obra del Metro. Probablemente se sienten bastante inseguros: hay huecos, el andén está roto, hay poca iluminación y poca gente. Ahora caminen 100 metros, 200 metros, 500 metros. En algún punto, la situación empieza a parecerse más a un barrio "normal".

El variograma es una herramienta que mide exactamente eso: cómo cambia una variable (por ejemplo, el número de robos o la sensación de inseguridad) a medida que nos alejamos de un punto. Nos permite responder preguntas como:

- ¿A qué distancia de la obra deja de sentirse el efecto negativo en seguridad?
- ¿El efecto es igual en todas las direcciones o es diferente si caminas paralelo a la obra vs. perpendicular?
- ¿Ese "alcance del impacto" cambió entre antes de la obra y ahora?

### 2.2. ¿Qué es el kriging? (Explicación sencilla)

Una vez que entendemos cómo se comporta la seguridad en el espacio (gracias al variograma), podemos hacer algo muy poderoso: predecir la seguridad en puntos donde no tenemos datos. Esto se llama **kriging** y nos permite crear un "mapa de calor" continuo de la percepción de seguridad o de los delitos alrededor de cada corredor.

En vez de tener puntos sueltos en un mapa, tenemos una superficie completa que muestra dónde están las zonas más problemáticas y dónde están las más seguras. Esto es muy útil para hacer recomendaciones concretas.

### 2.3. Anisotropía: el efecto no es igual en todas las direcciones

Las vías de transporte masivo funcionan como barreras físicas en la ciudad. De un lado de la avenida puede haber un barrio comercial activo y del otro lado puede haber lotes vacíos. Por eso, vamos a analizar si el impacto de la obra es diferente según la dirección: a lo largo del corredor (paralelo a la obra) vs. perpendicular al corredor (cruzando hacia los barrios). Si encontramos diferencias, eso se llama **anisotropía** y es un hallazgo muy importante porque demuestra que la infraestructura de transporte fragmenta el tejido urbano de seguridad.

### 2.4. Nuestras cuatro capas de análisis

El proyecto se organiza en cuatro grandes capas que se integran al final:

| Capa | Qué analizamos | Resultado esperado |
|------|---------------|-------------------|
| **1. Delitos** | Cómo cambiaron los delitos cerca de las obras, comparándolos antes y durante la construcción | Mapas que muestran si los delitos aumentaron o disminuyeron cerca de cada corredor |
| **2. Percepción** | Cómo se sienten los comerciantes y vecinos respecto a la seguridad actual | Superficie de percepción: un mapa continuo de cómo se siente la inseguridad alrededor de cada obra |
| **3. Empresas** | Qué negocios hay cerca de las obras, cuáles cerraron y cuáles abrieron | Tasas de apertura/cierre de negocios por distancia a la obra y por sector económico |
| **4. Entorno** | Cómo se ve el entorno físico desde imágenes satelitales | Variables del entorno urbano: vegetación, lotes vacíos, áreas en construcción |

---

## 3. Hipótesis a Probar

Estas son las preguntas concretas que vamos a responder con datos. Cada hipótesis se puede confirmar o rechazar con nuestro análisis:

| ID | Hipótesis |
|----|-----------|
| **H1** | A menor distancia de la obra, mayor tasa de delitos. Esperamos que el variograma muestre que la concentración de delitos es más alta cerca de las estaciones y disminuye con la distancia. |
| **H2** | La percepción de inseguridad es peor cerca de las obras. Los comerciantes más cercanos a las obras reportan mayor sensación de inseguridad que los que están lejos. |
| **H3** | El impacto de la obra es anisotrópico. El efecto en seguridad es diferente a lo largo del corredor vs. perpendicular a este, porque la vía actúa como barrera urbana. |
| **H4** | Los delitos cambiaron después de iniciadas las obras. Comparando la estructura espacial de los delitos antes y durante la obra, esperamos encontrar cambios significativos en el patrón de distribución. |
| **H5** | Las MiPymes son más vulnerables. Los negocios pequeños y medianos tienen tasas de cierre más altas cerca de las obras que las empresas grandes, y ciertos sectores económicos son más afectados que otros. |
| **H6** | El entorno físico deteriorado amplifica la inseguridad. Las zonas con menos vegetación, más lotes vacíos y más área en demolición presentan peor percepción de seguridad, independientemente de la distancia a la obra. |

---

## 4. Datos que Vamos a Usar

Trabajaremos con múltiples fuentes de datos. Algunas nos las dan los organizadores del datajam, otras las recolectamos nosotros y otras las descargamos de fuentes públicas.

### 4.1. Datos proporcionados por el Datajam

| Fuente | Qué contiene | Para qué la usamos |
|--------|-------------|-------------------|
| Encuesta de Movilidad y Entornos Urbanos | Opiniones sobre movilidad y entorno urbano en zonas de obra | Percepción de seguridad asociada a movilidad |
| Encuesta de Clima de los Negocios | Opinión de empresarios sobre el ambiente para hacer negocios | Impacto económico percibido por MiPymes |
| Encuesta Primera Línea | Percepción específica sobre la obra del Metro | Efectos directos de la obra más grande |

### 4.2. Datos que recolectamos nosotros

| Fuente | Qué contiene | Para qué la usamos |
|--------|-------------|-------------------|
| App de recolección de percepción | Respuestas en texto libre de comerciantes y vecinos, georreferenciadas | Variable principal de percepción de seguridad para el variograma y kriging |
| Google Places API | Negocios activos actualmente cerca de los corredores con nombre, tipo y ubicación exacta | Censo actual de empresas por distancia a la obra |

### 4.3. Datos de fuentes públicas

| Fuente | Qué contiene | Para qué la usamos |
|--------|-------------|-------------------|
| SIEDCO / Policía Nacional | Registros de delitos georreferenciados: extorsión, hurto a comercio, hurto a personas, daño a bien ajeno, lesiones personales, tráfico de estupefacientes | Capa 1: análisis delictual antes y durante la obra |
| Registro Mercantil CCB | Empresas registradas con fecha de apertura, cierre, ubicación y actividad económica | Capa 3: serie temporal del tejido empresarial |
| Línea de emergencias (123/NUSE) | Llamadas de emergencia georreferenciadas, con fecha y tipo | Proxy histórico de percepción de inseguridad (antes de la obra) |
| Imágenes Sentinel-2 (ESA) | Imágenes satelitales gratuitas con resolución de 10 metros por píxel | Capa 4: extraer variables del entorno urbano (vegetación, construcción, lotes vacíos) |
| Datos abiertos de Bogotá (IDECA) | Información geográfica de la ciudad: manzanas, localidades, usos del suelo | Contexto espacial para todos los análisis |

### 4.4. Delitos que vamos a modelar

Seleccionamos los delitos que tienen impacto directo en los negocios y el entorno comercial:

- **Extorsión:** el delito que más afecta directamente a los negocios. Los comerciantes son obligados a pagar "vacunas" o cuotas a grupos criminales.
- **Hurto a establecimiento comercial:** robos directos a los negocios, ya sea a la tienda física o a sus empleados.
- **Hurto a personas:** robos a peatones y clientes en la zona, lo cual afecta el flujo de clientes a los negocios.
- **Daño a bien ajeno (vandalismo):** destrucción de fachadas, vidrieras y equipos. Las obras generan zonas sin vigilancia natural que facilitan el vandalismo.
- **Lesiones personales:** agresiones físicas que reflejan conflictividad en el entorno.
- **Tráfico de estupefacientes:** las zonas en obra generan espacios oscuros y poco transitados que pueden ser aprovechados por el microtráfico.

---

## 5. Metodología Paso a Paso

### 5.1. Capa 1: Análisis de delitos (antes vs. durante la obra)

Esta capa usa los datos históricos de delitos de la Policía Nacional. La idea es comparar el patrón espacial de los delitos antes de que empezara la obra con el patrón actual.

**Pasos:**

1. **Descargar los datos:** obtener los registros de delitos georreferenciados del SIEDCO para los tres corredores. Necesitamos al menos dos años antes de la obra y los datos disponibles durante la obra.
2. **Definir las zonas de estudio:** crear un área de influencia alrededor de cada corredor (buffer). No fijamos un radio rígido; dejamos que el variograma nos diga hasta dónde llega el efecto. Inicialmente trabajamos con 1 km a cada lado del corredor.
3. **Calcular tasas de delitos:** para cada tipo de delito, calcular la densidad (delitos por hectárea) en una grilla regular sobre la zona de estudio.
4. **Construir variogramas:** para cada tipo de delito y cada periodo (antes/durante), calcular el variograma experimental. Esto nos dice cómo se relaciona la concentración de delitos entre puntos cercanos vs. lejanos.
5. **Analizar la anisotropía:** calcular variogramas en cuatro direcciones (0°, 45°, 90°, 135° respecto al corredor) para ver si el efecto de la obra es diferente según la dirección.
6. **Comparar antes vs. durante:** la diferencia entre los variogramas nos muestra cómo cambió la estructura espacial de los delitos con la obra.

### 5.2. Capa 2: Percepción de seguridad

Esta es la capa más innovadora. Recolectamos percepción de seguridad directamente de comerciantes y vecinos a través de nuestra app, y la convertimos en un mapa continuo.

**Pasos:**

1. **Recolectar datos en campo:** cada estudiante recorre un corredor con la app, entrevistando comerciantes y registrando respuestas en texto libre con ubicación GPS. Meta: al menos 100-150 puntos por corredor para que el variograma sea estable.
2. **Convertir texto a número:** usamos inteligencia artificial (un modelo de lenguaje) para analizar cada respuesta de texto y asignarle un puntaje de percepción de seguridad en una escala de 0 (muy inseguro) a 1 (muy seguro). También extraemos dimensiones específicas: percepción de iluminación, de presencia policial, de deterioro físico del entorno, de presencia de personas sospechosas.
3. **Construir el variograma de percepción:** con los puntajes georreferenciados, calculamos el variograma experimental. Esto nos dice hasta dónde "llega" el efecto de la obra en cómo se siente la gente.
4. **Generar la superficie de percepción:** usando kriging, interpolamos los puntajes para crear un mapa continuo de percepción de seguridad alrededor de cada corredor. Este mapa es el producto estrella del proyecto.

**Nota importante sobre limitaciones:**

No tenemos datos de percepción de antes de la obra, solo de ahora. Para compensar, usaremos las llamadas a la línea de emergencias como un indicador indirecto (proxy) de cómo se sentía la gente antes: más llamadas en una zona sugieren más percepción de inseguridad. También usaremos los datos de delitos como puente lógico: si demostramos que los delitos cambiaron con la obra y que la percepción actual se correlaciona con los delitos actuales, podemos inferir razonablemente que la percepción también cambió.

### 5.3. Capa 3: Tejido empresarial

Aquí analizamos qué pasó con los negocios de la zona: ¿cerraron? ¿abrieron nuevos? ¿Qué tipo de negocios se vieron más afectados?

**Pasos:**

1. **Censo actual con Google Places:** usando la API de Google, obtenemos todos los negocios activos actualmente en los corredores con su nombre, tipo de negocio (restaurante, tienda, peluquería, etc.) y ubicación exacta.
2. **Serie histórica con Registro Mercantil:** solicitamos a la Cámara de Comercio los datos de matrículas mercantiles con fecha de apertura y cancelación. Esto nos permite reconstruir cuántos negocios había antes de la obra.
3. **Calcular tasas de supervivencia:** por cada franja de distancia a la obra, calculamos qué porcentaje de negocios sobrevivió y qué porcentaje cerró. Analizamos si las MiPymes cierran más que las empresas grandes.
4. **Clasificar por sector económico:** identificamos qué tipos de negocio son más vulnerables (por ejemplo, restaurantes vs. ferreterías vs. servicios profesionales).

### 5.4. Capa 4: Entorno urbano desde imágenes satelitales

Las imágenes satelitales nos permiten "ver desde arriba" cómo ha cambiado el entorno físico. Usamos imágenes gratuitas del satélite Sentinel-2 de la Agencia Espacial Europea.

**Variables que extraemos:**

- **NDVI (vegetación):** un índice que mide cuánta vegetación hay. Las zonas con más árboles y parques tienden a ser percibidas como más seguras (esto viene de la teoría CPTED: Prevención del Crimen a través del Diseño Ambiental).
- **Áreas en construcción/demolición:** detectamos cambios en el uso del suelo comparando imágenes de antes y durante la obra.
- **Lotes vacíos:** identificamos terrenos sin construir que pueden convertirse en puntos críticos de inseguridad.
- **Cambios en la morfología urbana:** cómo cambió la forma física de la ciudad alrededor de cada corredor.

Estas variables se usan como complemento del modelo: nos ayudan a explicar por qué algunas zonas cerca de la obra son más inseguras que otras, más allá de la simple distancia.

### 5.5. Integración final

Al final, todo se une en un modelo de regresión espacial donde la percepción de seguridad se explica por la distancia a la obra, los delitos observados y las características físicas del entorno. Usamos co-kriging o kriging universal para respetar la estructura de correlación espacial de los datos. El resultado es un mapa integrado que muestra dónde están los puntos más críticos y qué factores los explican.

---

## 6. Herramientas que Vamos a Usar

Todo el análisis se hace en R, un lenguaje de programación estadístico muy potente y gratuito.

| Herramienta | Para qué sirve | Ejemplo en nuestro proyecto |
|-------------|----------------|---------------------------|
| R + RStudio | Lenguaje de programación para análisis estadístico | Todo el proyecto se programa aquí |
| gstat | Paquete de R para geoestadística | Calcular variogramas y hacer kriging |
| sf | Paquete para datos geográficos | Manejar las ubicaciones de negocios y delitos |
| terra | Paquete para imágenes satelitales | Extraer NDVI y variables del entorno |
| spdep | Paquete para análisis espacial | Modelos de regresión espacial |
| leaflet | Paquete para mapas interactivos | Mapas de la app Shiny |
| Shiny | Framework para aplicaciones web | La app interactiva final |
| plotly | Gráficos interactivos | Variogramas y gráficos en la app |
| tidyverse | Conjunto de paquetes para manipulación de datos | Limpiar y transformar todas las bases de datos |
| OpenAI API / Ollama | Modelos de inteligencia artificial | Convertir texto de percepción a puntajes numéricos |
| Google Places API | Servicio de Google para buscar negocios | Obtener el censo actual de empresas por corredor |

---

## 7. Cronograma: 4 Semanas

### Semana 1: Datos y recolección de campo

| Responsable | Tareas |
|-------------|--------|
| Estudiante 1 | Recolección de percepción en campo: Corredor Metro Línea 1. Meta: mínimo 100-150 encuestas georreferenciadas con la app. |
| Estudiante 2 | Recolección de percepción en campo: Corredor TransMilenio Av. 68. Misma meta de encuestas. |
| Estudiante 3 | Recolección de percepción en campo: Corredor TransMilenio Calle 13. Misma meta de encuestas. |
| Tutor | Descarga y limpieza de datos de delitos (SIEDCO). Configuración del scraping de Google Places API. Solicitud de registros mercantiles a la CCB. Descarga de imágenes Sentinel-2. |

### Semana 2: Procesamiento de datos

| Responsable | Tareas |
|-------------|--------|
| Estudiante 1 | Clasificar las respuestas de percepción de su corredor. Ejecutar el scoring con IA (el tutor prepara el script, el estudiante lo ejecuta y verifica resultados). |
| Estudiante 2 | Procesar las imágenes satelitales con el paquete terra en R: calcular NDVI, identificar cambios de uso del suelo. El tutor proporciona el código base. |
| Estudiante 3 | Estructurar la base de datos de delitos por corredor y periodo (antes/durante obra). Geocodificar negocios de Google Places. |
| Tutor | Programar el pipeline geoestadístico en R: funciones para variogramas, kriging, análisis de anisotropía. Preparar el script de scoring de percepción con IA. |

### Semana 3: Modelamiento y análisis

| Responsable | Tareas |
|-------------|--------|
| Estudiante 1 | Ayudar con visualizaciones: crear gráficos para cada hipótesis. Documentar hallazgos preliminares. |
| Estudiante 2 | Analizar resultados de la capa empresarial: tasas de apertura/cierre por distancia, gráficos comparativos por sector. |
| Estudiante 3 | Redactar las secciones de contexto y marco conceptual del documento final. |
| Tutor | Ejecutar variogramas, kriging, modelos de regresión espacial. Generar superficies de percepción. Integrar las cuatro capas. Empezar estructura de la app Shiny. |

### Semana 4: App Shiny y presentación

| Responsable | Tareas |
|-------------|--------|
| Estudiante 1 | Preparar las slides de presentación: sección de problema y contexto. |
| Estudiante 2 | Preparar slides: sección de resultados y hallazgos. |
| Estudiante 3 | Preparar slides: sección de recomendaciones y conclusiones. Ensayar la presentación oral. |
| Tutor | Construir y pulir la app Shiny. Integrar todos los mapas y gráficos interactivos. Revisar y ajustar slides. |

> **Fecha crítica:** dejar al menos 3 días al final de la semana 4 exclusivamente para pulir la app y ensayar la presentación.

---

## 8. Estructura del Proyecto en R

El proyecto en R se organiza en carpetas claras para que todos los miembros del equipo sepan dónde está cada cosa:

```
cyberrosario/
├── data/
│   ├── raw/                  # Datos originales sin modificar (nunca se tocan directamente)
│   ├── processed/            # Datos limpios y listos para analizar
│   ├── spatial/              # Archivos geográficos (shapefiles, GeoJSON)
│   └── raster/               # Imágenes satelitales Sentinel-2
├── scripts/
│   ├── 01_download.R         # Descarga automática de datos
│   ├── 02_clean.R            # Limpieza y preparación de datos
│   ├── 03_google_places.R    # Scraping de negocios con Google Places API
│   ├── 04_perception_nlp.R   # Scoring de percepción con IA (texto a número)
│   ├── 05_satellite.R        # Procesamiento de imágenes satelitales (NDVI, etc.)
│   ├── 06_variograms.R       # Cálculo de variogramas y análisis de anisotropía
│   ├── 07_kriging.R          # Interpolación kriging y generación de superficies
│   ├── 08_regression.R       # Modelos de regresión espacial
│   └── 09_enterprise.R       # Análisis del tejido empresarial
├── app/                      # Aplicación Shiny (app.R, ui.R, server.R)
├── output/
│   ├── maps/                 # Mapas generados
│   ├── figures/              # Gráficos y figuras
│   └── reports/              # Informes y documentos
└── docs/                     # Documentación del proyecto
```

---

## 9. Visión de la App Shiny

La aplicación Shiny es nuestro producto final interactivo. Permite a los jueces (y potencialmente a los tomadores de decisiones) explorar los resultados de forma dinámica.

### 9.1. Funcionalidades principales

- **Selector de corredor:** elegir entre Metro Línea 1, TransMilenio Av. 68 o TransMilenio Calle 13.
- **Selector de variable:** elegir qué ver en el mapa: percepción de seguridad (general o por dimensión), cada tipo de delito, densidad de negocios, o variables del entorno.
- **Selector de periodo:** cambiar entre antes de la obra y durante la obra para ver los cambios (disponible para delitos y tejido empresarial).
- **Mapa central interactivo:** mapa con la superficie krigeada de fondo y los negocios como puntos. Al hacer clic en un negocio, se muestra su información.
- **Panel de variograma:** muestra el variograma experimental y el modelo ajustado. Incluye el rango (alcance del impacto) como dato destacado.
- **Resumen estadístico:** panel con cifras clave: alcance del impacto en metros, porcentaje de cambio en delitos, tasa de cierre de negocios.
- **Comparador de anisotropía:** gráfico que muestra los variogramas en diferentes direcciones para visualizar el efecto barrera.

### 9.2. Diseño de la interfaz

La app tendrá un diseño limpio con tres paneles principales: un panel lateral izquierdo con los controles de selección, un panel central grande con el mapa interactivo (leaflet), y un panel inferior con los gráficos de variograma y estadísticas. Se usará el paquete `bslib` para un aspecto moderno y profesional.

---

## 10. Recomendaciones que Esperamos Producir

El reto nos pide generar recomendaciones basadas en datos. Estas son las líneas de recomendación que esperamos poder fundamentar con nuestros resultados:

- **Iluminación focalizada:** identificar los tramos específicos de cada corredor donde la percepción de seguridad es peor y recomendar intervenciones de iluminación basadas en el mapa de superficie.
- **Presencia policial optimizada:** usar los variogramas para determinar el radio óptimo de patrullaje alrededor de cada estación/parada en construcción.
- **Diseño urbano (CPTED):** recomendaciones específicas sobre manejo de fachadas tapiadas, lotes vacíos y zonas de demolición para reducir los espacios que facilitan el crimen.
- **Apoyo diferenciado a MiPymes:** identificar los sectores económicos y las franjas de distancia donde los negocios necesitan más apoyo durante la obra.
- **Mitigación del efecto barrera:** si confirmamos la anisotropía, recomendar pasos peatonales, señalización y conexiones transversales para reducir la fragmentación urbana.

---

## 11. Glosario de Términos

| Término | Qué significa (en simple) |
|---------|--------------------------|
| **Variograma** | Herramienta que mide cómo cambia una variable en el espacio. Nos dice si los puntos cercanos se parecen más entre sí que los lejanos, y hasta qué distancia se mantiene esa similitud. |
| **Kriging** | Técnica para predecir valores en lugares donde no tenemos datos, usando la información del variograma. Nos permite crear mapas continuos (superficies). |
| **Rango (alcance)** | La distancia a la cual ya no se detecta relación entre puntos. En nuestro caso: hasta qué distancia de la obra se siente su efecto. |
| **Nugget** | La variabilidad a distancia cero. Representa el "ruido" o la variación que no se explica por la distancia. |
| **Sill (meseta)** | El nivel máximo de variabilidad. Cuando el variograma llega a la meseta, los puntos ya no se influyen entre sí. |
| **Anisotropía** | Cuando el patrón espacial es diferente según la dirección. Ejemplo: el efecto de la obra llega más lejos a lo largo del corredor que perpendicular a este. |
| **CPTED** | Crime Prevention Through Environmental Design. Teoría que dice que el diseño del espacio físico (iluminación, visibilidad, vegetación) influye en el crimen. |
| **NDVI** | Índice de Vegetación. Un número que sale de las imágenes satelitales y mide cuánta vegetación hay en cada punto. |
| **Buffer** | Zona de influencia alrededor de un punto o línea. Ejemplo: un buffer de 500m alrededor de una estación del Metro. |
| **Lag** | La distancia entre pares de puntos que se comparan en el variograma. Vamos aumentando el lag para ver cómo cambia la relación. |
| **MiPymes** | Micro, Pequeñas y Medianas Empresas. El foco principal de nuestro análisis empresarial. |
| **SIEDCO** | Sistema de Información Estadístico, Delincuencial, Contravencional y Operativo de la Policía Nacional. De aquí salen los datos de delitos. |
| **Georreferenciación** | Asignar coordenadas geográficas (latitud y longitud) a un dato. Permite ponerlo en un mapa. |
| **Proxy** | Un indicador indirecto de algo que no podemos medir directamente. Ejemplo: usamos llamadas al 123 como proxy de percepción histórica. |
| **Sentinel-2** | Satélite de la Agencia Espacial Europea que toma fotos de toda la Tierra cada 5 días. Las imágenes son gratuitas. |
| **Shiny** | Framework de R para crear aplicaciones web interactivas sin necesidad de saber desarrollo web. |
| **Co-kriging** | Versión avanzada del kriging que usa varias variables al tiempo para mejorar la predicción. |

---

## 12. Consejos para el Equipo

### Para la recolección en campo

- Distribuirse espacialmente, no solo acumular encuestas en un solo punto. Es mejor tener 100 encuestas bien distribuidas que 200 todas en la misma cuadra.
- Registrar siempre la ubicación GPS antes de iniciar la encuesta. Si la app no captura bien la ubicación, anotar la dirección manualmente.
- Intentar cubrir ambos lados del corredor (esto es clave para el análisis de anisotropía).
- Ser respetuosos con los comerciantes. Explicar brevemente que es un ejercicio académico de la Universidad del Rosario en el marco del Datajam de la CCB.
- Ir en horarios variados: mañana, mediodía y tarde. La percepción puede cambiar según la hora.

### Para el procesamiento de datos

- Nunca modificar los datos originales. Siempre trabajar con copias en la carpeta `data/processed/`.
- Documentar todo lo que hacen: si limpian un dato, anotar por qué y cómo.
- Si algo no cuadra en los datos, preguntar antes de asumir. Es mejor perder 10 minutos preguntando que 2 horas arreglando un error.

### Para la presentación

- Empezar con el problema (la inseguridad en zonas de obra afecta a miles de negocios), luego la solución (nuestro enfoque geoestadístico), después los hallazgos (qué encontramos) y terminar con recomendaciones concretas.
- El mapa de superficie de percepción es nuestro producto estrella visual. Asegúrense de que se vea espectacular en las slides.
- Usar la app Shiny en vivo durante la presentación para mostrar la interactividad.
- Practicar la presentación al menos dos veces con todo el equipo.

---

**¡Vamos CyberRosario!**
