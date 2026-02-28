# Variogramas y Kriging: Explicación Detallada

## Para el equipo CyberRosario — Datajam Seguridad CCB

---

## 1. El problema que queremos resolver

Imagina que tienes un mapa de Bogotá con la línea del Metro dibujada. Ahora imagina que en algunos puntos del mapa tienes datos: sabes cuántos robos hubo en esa cuadra, o sabes qué tan inseguro se siente un comerciante ahí. Pero no tienes datos en TODOS los puntos — solo en algunos.

**La pregunta central es:** ¿Podemos estimar qué pasa en los puntos donde NO tenemos datos, usando la información de los puntos donde SÍ tenemos?

La respuesta intuitiva es "sí, porque los lugares cercanos se parecen entre sí". Si en una cuadra hay muchos robos, probablemente en la cuadra de al lado también hay bastantes. Esto se llama **autocorrelación espacial**: las cosas cercanas tienden a ser más parecidas que las lejanas.

Pero esa intuición necesita formalizarse matemáticamente para poder:
1. Medir exactamente **hasta qué distancia** se parecen los puntos cercanos
2. Hacer predicciones **óptimas** (las mejores posibles con los datos disponibles)
3. Saber **qué tan confiable** es cada predicción

Para eso existen el **variograma** y el **kriging**.

---

## 2. El variograma: midiendo cómo cambian las cosas en el espacio

### 2.1. La idea básica

Supongamos que tienes 500 hexágonos alrededor del Metro, cada uno con un conteo de robos. Ahora haz este ejercicio mental:

1. Toma dos hexágonos que están a 200 metros de distancia. Calcula la diferencia en robos entre ellos. Eleva esa diferencia al cuadrado (para que siempre sea positiva). Repite esto para TODOS los pares de hexágonos que están a 200m entre sí. Promedia.

2. Ahora haz lo mismo para pares a 400m. Luego a 600m. Luego a 800m. Y así sucesivamente.

Lo que obtienes es una tabla así:

| Distancia | Semivarianza (diferencia promedio al cuadrado) |
|-----------|------------------------------------------------|
| 200 m     | 0.05 (muy parecidos)                           |
| 400 m     | 0.15                                           |
| 600 m     | 0.28                                           |
| 800 m     | 0.38                                           |
| 1000 m    | 0.45                                           |
| 1200 m    | 0.48 (ya no se parecen mucho)                  |
| 1400 m    | 0.49                                           |
| 1600 m    | 0.50 (ya no se parecen nada)                   |

Si graficas esto (distancia en el eje X, semivarianza en el eje Y), obtienes el **variograma experimental**: una nube de puntos que sube desde abajo a la izquierda hasta estabilizarse arriba a la derecha.

### 2.2. La fórmula (simplificada)

La semivarianza a una distancia *h* se calcula así:

```
γ(h) = (1 / 2N) × Σ [Z(xᵢ) - Z(xᵢ + h)]²
```

Donde:
- `γ(h)` = semivarianza a la distancia h
- `N` = número de pares de puntos separados por la distancia h
- `Z(xᵢ)` = valor observado en el punto i (por ejemplo, número de robos)
- `Z(xᵢ + h)` = valor observado en un punto que está a distancia h del punto i

En palabras: "toma todos los pares de puntos separados por la distancia h, calcula la diferencia al cuadrado entre sus valores, promedia, y divide entre 2".

### 2.3. Los tres parámetros del variograma

Cuando graficas el variograma, la curva tiene una forma característica que se describe con tres números:

```
Semivarianza
     │
 Sill│─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─
     │                    ╱‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
     │                 ╱
     │              ╱
     │           ╱
     │        ╱
     │     ╱
Nugget│──╱
     │╱
     └──────────────────────────────────────────────
     0         Range                    Distancia (m)
```

**Nugget (pepita, ~0.15-0.20 en nuestro caso):**
Es el valor de semivarianza a distancia "cero". En teoría debería ser cero (un punto comparado consigo mismo tiene diferencia cero), pero en la práctica siempre hay algo de variabilidad que no se explica por la distancia. Esto puede ser por:
- Error de medición en los datos
- Variabilidad a escalas más pequeñas que nuestra grilla (cosas que pasan dentro de un mismo hexágono de 200m)
- Aleatoriedad inherente del fenómeno

Un nugget alto respecto al sill significa que hay mucho "ruido" y la predicción será menos precisa.

**Sill (meseta, ~0.50 para hurto comercio):**
Es el nivel donde la curva se estabiliza. Representa la varianza total del fenómeno. Una vez que llegas al sill, los puntos ya no se influyen entre sí — son estadísticamente independientes.

**Range (alcance, ~1100 metros en nuestro caso):**
Es la distancia a la cual se alcanza el sill. Este es probablemente el **parámetro más importante para nuestro proyecto** porque responde directamente a la pregunta: **¿hasta dónde llega el efecto de la obra del Metro en la seguridad?**

En nuestro caso, el range de 1100m nos dice que los patrones de delincuencia están correlacionados espacialmente hasta ~1.1 km. Más allá de esa distancia, lo que pasa en un punto no tiene relación estadística con lo que pasa en otro.

### 2.4. El modelo teórico: ¿por qué ajustar una curva?

Los puntos del variograma experimental son "ruidosos" — no caen perfectamente en una curva suave. Para poder usar el variograma en la predicción (kriging), necesitamos una función matemática suave que se ajuste a esos puntos.

Existen varios modelos teóricos. Nosotros usamos el **modelo esférico**:

```
         ┌ 0                                          si h = 0
         │
γ(h) =   ┤ c₀ + c₁ × [1.5(h/a) - 0.5(h/a)³]       si 0 < h ≤ a
         │
         └ c₀ + c₁                                   si h > a
```

Donde: c₀ = nugget, c₁ = sill - nugget, a = range.

**¿Por qué el modelo esférico y no otro?**

| Modelo | Comportamiento | Cuándo usarlo |
|--------|---------------|---------------|
| **Esférico** | Alcanza el sill exactamente en el range. La correlación llega a cero en un punto preciso. | Cuando el fenómeno tiene un "alcance" físico definido. Ejemplo: el efecto de una obra termina en algún punto. |
| Exponencial | Se acerca asintóticamente al sill (nunca llega exactamente). La correlación nunca es exactamente cero. | Fenómenos donde la influencia decae gradualmente sin un corte claro. |
| Gaussiano | Muy suave cerca del origen, luego sube rápido. | Fenómenos muy continuos y suaves espacialmente. Raro en datos urbanos. |

Elegimos el esférico porque:
1. Tiene sentido físico: el impacto de la obra del Metro no se extiende infinitamente. Hay una distancia concreta donde deja de sentirse.
2. Ajusta bien nuestros datos (los puntos experimentales siguen la curva teórica).
3. Es el modelo más estable numéricamente y el más usado en geoestadística urbana y ambiental.

---

## 3. El kriging: prediciendo en puntos sin datos

### 3.1. La idea básica

Ya tenemos el variograma que nos dice cómo se relacionan los puntos en el espacio. Ahora queremos predecir el valor en un punto donde NO tenemos datos.

El kriging dice: "la mejor predicción en un punto nuevo es un **promedio ponderado** de los valores observados cercanos, donde los pesos dependen de la estructura espacial capturada por el variograma".

```
Ẑ(x₀) = Σ wᵢ × Z(xᵢ)
```

Donde:
- `Ẑ(x₀)` = valor predicho en el punto nuevo x₀
- `Z(xᵢ)` = valores observados en los puntos de datos
- `wᵢ` = pesos (determinados por el variograma)

### 3.2. ¿Cómo se calculan los pesos?

Aquí es donde el kriging se diferencia de un simple promedio ponderado por distancia (como el Inverse Distance Weighting / IDW). Los pesos del kriging se calculan resolviendo un sistema de ecuaciones que garantiza dos cosas:

1. **La predicción es insesgada**: en promedio, no sobreestima ni subestima
2. **La varianza del error es mínima**: entre todas las predicciones posibles insesgadas, el kriging da la que tiene menor error

Para calcular los pesos, se arma un sistema de ecuaciones usando los valores del variograma entre todos los pares de puntos de datos, y entre cada punto de datos y el punto donde queremos predecir:

```
┌ γ(x₁,x₁)  γ(x₁,x₂)  ...  γ(x₁,xₙ)  1 ┐   ┌ w₁ ┐     ┌ γ(x₁,x₀) ┐
│ γ(x₂,x₁)  γ(x₂,x₂)  ...  γ(x₂,xₙ)  1 │   │ w₂ │     │ γ(x₂,x₀) │
│ ...                                       │ × │ .. │  =  │ ...       │
│ γ(xₙ,x₁)  γ(xₙ,x₂)  ...  γ(xₙ,xₙ)  1 │   │ wₙ │     │ γ(xₙ,x₀) │
└ 1          1          ...  1           0 ┘   └ μ  ┘     └ 1         ┘
```

Donde `γ(xᵢ, xⱼ)` es el valor del variograma (modelo teórico) evaluado en la distancia entre los puntos i y j.

No necesitas resolver esto a mano — el paquete `gstat` de R lo hace automáticamente. Pero es importante entender que los pesos NO dependen solo de la distancia al punto de predicción, sino también de la **configuración espacial** de todos los puntos de datos entre sí.

### 3.3. Un ejemplo concreto

Imagina que quieres predecir el número de robos en un hexágono vacío (sin datos). Tienes tres hexágonos vecinos con datos:

- Hexágono A: 15 robos, a 200m del punto de predicción
- Hexágono B: 12 robos, a 300m del punto de predicción
- Hexágono C: 14 robos, a 250m del punto de predicción

**IDW (método simple)** daría pesos solo por distancia inversa:
- wA = 1/200 = 0.005, wB = 1/300 = 0.0033, wC = 1/250 = 0.004
- Predicción ≈ 14.0

**Kriging** además tiene en cuenta que A y C están muy cerca entre sí (a 150m), así que aportan información redundante. Le da MÁS peso a B (que está solo y aporta información nueva) y MENOS peso a A y C (que se "pisan" entre sí):
- wA = 0.28, wB = 0.42, wC = 0.30
- Predicción ≈ 13.5

La diferencia numérica puede ser pequeña, pero el kriging es óptimo matemáticamente y además te da la **varianza de predicción** (qué tan seguro estás de tu predicción en cada punto).

### 3.4. Kriging ordinario vs. universal

Nosotros usamos **kriging ordinario**, que asume que la media del fenómeno es desconocida pero constante en toda el área. La fórmula en R es:

```r
formula = log_shoplifting ~ 1   # el ~ 1 significa "media constante"
```

La alternativa sería **kriging universal** (o con tendencia):
```r
formula = log_shoplifting ~ dist_metro   # incluye una tendencia con la distancia
```

Esto modelaría explícitamente que los robos disminuyen con la distancia al Metro. Pero nosotros preferimos dejarlo ordinario para que el variograma capture toda la estructura espacial sin imponer una forma particular a la tendencia. La relación con la distancia la analizamos después en la regresión espacial (script 06).

---

## 4. Co-kriging: usando varias variables a la vez

### 4.1. ¿Por qué no hacer kriging de cada variable por separado?

Podríamos hacer kriging de hurto comercio solo, luego kriging de hurto personas solo, luego extorsión solo. Pero estaríamos desperdiciando información, porque estos delitos están **correlacionados entre sí en el espacio**: donde hay mucho hurto comercio, también tiende a haber mucho hurto personas.

El **co-kriging** usa esta correlación cruzada para mejorar las predicciones. Predice todas las variables simultáneamente, aprovechando la información de unas para mejorar la predicción de las otras.

### 4.2. El co-variograma

En vez de un solo variograma, ahora necesitamos una **matriz de variogramas**:
- Variogramas directos: hurto comercio vs. hurto comercio, hurto personas vs. hurto personas, extorsión vs. extorsión (3 variogramas, la diagonal)
- Variogramas cruzados: hurto comercio vs. hurto personas, hurto comercio vs. extorsión, hurto personas vs. extorsión (3 variogramas cruzados, fuera de la diagonal)

Total: 6 variogramas que se ajustan **simultáneamente** con un solo modelo (el LMC — Linear Model of Coregionalization). Esto garantiza que la matriz de covarianza resultante sea matemáticamente válida (positiva definida).

### 4.3. El caso de la percepción

El co-kriging es especialmente poderoso para la percepción de seguridad. Tenemos encuestas de percepción (EPV 2025) solo en algunos hexágonos, pero tenemos datos de delitos en TODOS. Al hacer co-kriging de Percepción + Hurto Comercio:

- En hexágonos con encuesta: la predicción usa directamente el dato de percepción
- En hexágonos sin encuesta pero con datos de delitos: el co-kriging "infiere" la percepción usando la correlación espacial entre percepción y delitos

Esto permite crear un mapa continuo de percepción de seguridad incluso donde no se hicieron encuestas.

---

## 5. De puntos a superficie: la grilla fina

### 5.1. El problema visual

El kriging predice valores en puntos específicos. Si predecimos solo en los centroides de los hexágonos (200m entre sí), y coloreamos cada hexágono con su valor predicho, el mapa se ve "pixelado" — se notan los bordes de los hexágonos y los saltos de color.

### 5.2. La solución

En vez de predecir en ~2,000 centroides de hexágonos, creamos una **grilla fina** de puntos cada 50 metros (27,092 puntos) y predecimos en todos ellos. Luego convertimos esos puntos a un **raster** (una imagen georreferenciada donde cada píxel tiene un valor).

El resultado es una superficie continua y suavizada, como un "mapa de calor" que muestra gradientes suaves de color en vez de polígonos discretos.

La calidad de la predicción es exactamente la misma — solo cambia la resolución visual. El modelo (variograma + pesos de kriging) es idéntico; simplemente evaluamos la predicción en más puntos.

---

## 6. Ventajas del enfoque variograma + kriging

| Ventaja | Explicación |
|---------|-------------|
| **Predicción óptima** | Kriging es el Mejor Predictor Lineal Insesgado (BLUE). No existe otro método lineal que dé menos error con los mismos datos. |
| **Cuantifica la incertidumbre** | Cada predicción viene con su varianza. Sabemos dónde estamos seguros y dónde no. Esto es crucial para hacer recomendaciones responsables. |
| **El range responde directamente al reto** | "¿Hasta dónde llega el efecto de la obra?" → 1,100 metros. Este número sale directo del variograma y es el hallazgo central del proyecto. |
| **Maneja datos irregulares** | No necesitamos que los datos estén uniformemente distribuidos. Kriging se adapta automáticamente a la configuración espacial de los puntos. |
| **Integra múltiples variables** | El co-kriging aprovecha la correlación entre delitos y percepción para mejorar todas las predicciones simultáneamente. |
| **Detecta anisotropía** | Los variogramas direccionales nos permiten probar si el efecto del Metro es diferente a lo largo del corredor vs. perpendicular a este. |
| **Reproducible y transparente** | Todo el proceso es matemáticamente formalizado. No hay "cajas negras". Los parámetros del variograma son interpretables. |

---

## 7. Desventajas y limitaciones

| Desventaja | Explicación | Cómo la mitigamos |
|-----------|-------------|-------------------|
| **Asume estacionariedad** | El kriging ordinario asume que la estructura espacial (variograma) es la misma en toda el área de estudio. Esto puede no ser cierto: cerca del centro histórico el patrón puede ser diferente al de Kennedy. | Usamos un buffer relativamente estrecho (1.5 km) alrededor del Metro, lo cual limita la heterogeneidad. Si tuviéramos más datos, podríamos usar kriging con variograma local. |
| **Sensible al modelo de variograma** | Si eliges mal el modelo teórico (esférico vs. exponencial) o los parámetros iniciales, las predicciones pueden cambiar. | Probamos múltiples combinaciones en `01_cokriging_pipeline.R` (6 modelos) y verificamos visualmente que los puntos experimentales sigan la curva. |
| **No captura relaciones no lineales** | Kriging es un método lineal. Si la relación entre delitos y distancia al Metro fuera exponencial o con umbrales, el kriging no la captura directamente. | La transformación logarítmica (`log(robos + 1)`) linealiza relaciones multiplicativas. Relaciones más complejas se analizan en la regresión espacial (script 06). |
| **Suaviza los extremos** | Kriging tiende a predecir valores cercanos a la media en zonas con pocos datos. Los picos y valles extremos se "amortiguan". Esto es inherente a cualquier método de interpolación. | Es una limitación conocida. La varianza de predicción (mapa de incertidumbre) muestra dónde las predicciones son menos confiables. |
| **Computacionalmente costoso** | El co-kriging sobre 27,000 puntos requiere resolver sistemas de ecuaciones grandes. En nuestro caso tomó varios minutos. | Usamos la grilla fina solo para visualización. El análisis estadístico se hace sobre los hexágonos (2,100 puntos), que es mucho más rápido. |
| **Requiere suficientes datos** | Para estimar un variograma estable se necesitan al menos ~50-100 puntos. Con menos, el variograma es inestable y las predicciones poco confiables. | Tenemos ~2,100 hexágonos con datos de delitos, lo cual es más que suficiente. Para percepción, depende de cuántas encuestas EPV caigan en el buffer. |
| **Asume distribución gaussiana** | El kriging asume (implícitamente) que los datos siguen una distribución normal. Los conteos de delitos no son normales (son discretos y asimétricos). | Usamos la transformación `log(x + 1)` que normaliza las distribuciones de conteo y estabiliza la varianza. |

---

## 8. ¿Por qué esta técnica y no otra?

### 8.1. Alternativas que NO elegimos

**IDW (Inverse Distance Weighting):**
- Pro: Sencillo, rápido, no requiere ajustar variograma
- Contra: No da varianza de predicción, no es óptimo, no aprovecha correlación entre variables, no tiene interpretación del "range" (alcance del efecto)
- Veredicto: demasiado simple para un proyecto que busca medir el alcance espacial del impacto

**Modelos de regresión espacial (SAR/SEM):**
- Pro: Modelan directamente la relación entre variables explicativas y respuesta
- Contra: No generan superficies continuas, requieren especificar la matriz de vecindad, no capturan la estructura espacial tan finamente como el variograma
- Veredicto: los usamos ADEMÁS del kriging (script 06) para la integración final, pero no como sustituto

**Machine Learning espacial (Random Forest + coordenadas):**
- Pro: Captura relaciones no lineales, no asume distribución
- Contra: No da varianza de predicción formal, no tiene interpretación del range, es una "caja negra", tiende a sobreajustar con datos espaciales
- Veredicto: inadecuado para un proyecto donde la interpretabilidad y la medición del alcance espacial son centrales

**Kernel Density Estimation (KDE):**
- Pro: Muy usado en criminología para "mapas de calor" de delitos
- Contra: Solo estima densidad (dónde hay más puntos), no predice magnitudes, no integra múltiples variables, el bandwidth es arbitrario (vs. el range del variograma que se estima de los datos)
- Veredicto: útil para exploración visual pero no para el análisis riguroso que requiere el reto

### 8.2. ¿Por qué kriging es la mejor opción para ESTE proyecto?

1. **El reto pregunta "¿hasta dónde llega el efecto?"** → El range del variograma responde directamente esta pregunta con un número en metros derivado de los datos.

2. **Necesitamos mapas continuos de percepción** → El co-kriging permite predecir percepción en todo el corredor incluso donde no hay encuestas, usando la correlación con delitos.

3. **Necesitamos cuantificar la incertidumbre** → El mapa de varianza de kriging muestra dónde son confiables nuestras predicciones y dónde no. Esto es fundamental para hacer recomendaciones responsables.

4. **Queremos comparar antes vs. durante** → Comparar los variogramas de ambos periodos muestra si la estructura espacial de los delitos cambió con la obra.

5. **Queremos detectar el efecto barrera** → Los variogramas direccionales permiten probar si el Metro fragmenta el tejido urbano de seguridad (anisotropía).

---

## 9. Resumen visual del flujo completo

```
DATOS CRUDOS                    VARIOGRAMA                     SUPERFICIE
(puntos dispersos)              (estructura espacial)          (mapa continuo)

  •    •                        γ │         ___________
    •      •                      │        /                    ████████████
  •   •  •    •     ──────►       │      /             ──────►  ██████░░████
    •    •   •                    │    /                         ███░░░░░███
  •    •                          │  /                           ██░░░░░░██
    •   •  •                      │/________________________     █░░░░░░░█
                                  0    Range    Distancia

1. Conteos de delitos         2. Medir cómo cambia la      3. Predecir en todos los
   por hexágono                  semivarianza con la           puntos del mapa usando
   (datos observados)            distancia (variograma)        los pesos óptimos (kriging)
                                 y ajustar modelo teórico
```

---

## 10. Glosario rápido

| Término | Definición en una línea |
|---------|------------------------|
| Semivarianza | Mitad de la diferencia al cuadrado promedio entre pares de puntos a cierta distancia |
| Variograma experimental | Gráfico de semivarianza vs. distancia calculado directamente de los datos |
| Variograma teórico | Función matemática (esférica, exponencial, etc.) ajustada al variograma experimental |
| Nugget | Semivarianza a distancia cero (ruido + microescala) |
| Sill | Semivarianza máxima (varianza total) |
| Range | Distancia a la que se alcanza el sill (alcance de la correlación espacial) |
| Lag | Intervalo de distancia usado para agrupar pares de puntos al calcular el variograma |
| Kriging ordinario | Predicción óptima asumiendo media constante desconocida |
| Co-kriging | Kriging multivariable que aprovecha la correlación entre varias variables |
| LMC | Linear Model of Coregionalization — el modelo que ajusta todos los variogramas (directos + cruzados) simultáneamente |
| BLUE | Best Linear Unbiased Estimator — propiedad que garantiza que kriging es óptimo entre los métodos lineales |
| Estacionariedad | Supuesto de que la estructura espacial (variograma) es la misma en toda el área |
| Anisotropía | Cuando la estructura espacial varía según la dirección (ejemplo: más correlación a lo largo del Metro que perpendicular) |
