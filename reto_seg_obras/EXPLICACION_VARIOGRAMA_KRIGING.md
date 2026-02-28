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

## 10. Regression Kriging: combinando regresión con geoestadística

### 10.1. ¿Por qué no basta con el kriging ordinario?

El kriging ordinario (scripts 01-02) es excelente para interpolar una variable en el espacio. Pero tiene una limitación: **no incorpora variables explicativas**. Solo dice "el hurto aquí es alto porque los hurtos cercanos también son altos" — no dice *por qué*.

Por otro lado, una regresión OLS clásica (`hurto ~ distancia_metro + pct_verde + ...`) sí incorpora predictores, pero **ignora la estructura espacial**: asume que los residuos son independientes, lo cual casi nunca es cierto en datos geográficos.

La **Regression Kriging** (RK) combina lo mejor de ambos mundos:

```
Predicción final = Tendencia (OLS) + Residuo espacial (Kriging)
                   └── lo que explican     └── lo que queda
                       los predictores         sin explicar, pero
                                               tiene patrón espacial
```

### 10.2. Los tres pasos del Regression Kriging

**Paso 1: Regresión OLS (la tendencia)**

Primero ajustamos una regresión lineal ordinaria:

```
percepción = β₀ + β₁(dist_metro) + β₂(allanamientos) + β₃(pct_mipyme) + ... + ε
```

Esto nos da:
- **Coeficientes (β)** que dicen cuánto influye cada variable sobre la percepción de seguridad
- **Residuos (ε)** = lo que el modelo OLS NO pudo explicar

**Paso 2: Variograma de los residuos**

Tomamos los residuos del OLS y les calculamos un variograma, exactamente como hicimos con los delitos en la sección 2. Si el variograma muestra estructura (no es plano), significa que hay patrones geográficos que los predictores no capturaron.

En nuestro caso obtuvimos:
- Nugget: 0.0497
- Sill total: 0.1566
- Range: 999 m
- **Ratio nugget/sill: 0.317** (estructura espacial moderada)

Esto significa que el 68.3% de la varianza de los residuos tiene estructura espacial — hay patrones geográficos que las 12 variables explicativas no capturan.

**Paso 3: Kriging de los residuos**

Usamos kriging ordinario para interpolar los residuos sobre la grilla fina de 50m. Esto crea una superficie suave que muestra dónde la percepción es **mejor** o **peor** de lo que los predictores predicen.

**Resultado final:** Sumamos la predicción del OLS + el residuo krigeado en cada punto.

### 10.3. ¿En qué se diferencia del SAR/SEM?

| | Regression Kriging | SAR / SEM (econometría espacial) |
|---|---|---|
| **Estructura espacial** | Continua (variograma — distancias reales en metros) | Discreta (matriz de vecindad binaria: vecino sí/no) |
| **Coeficientes** | Idénticos al OLS estándar — se interpretan igual | Modificados por el parámetro espacial ρ o λ, más difíciles de interpretar |
| **Alcance espacial** | El range del variograma de residuos da una distancia exacta (999 m) | No hay equivalente directo — el efecto se difunde por la red de vecinos |
| **Genera mapas continuos** | Sí — predice en cualquier punto del espacio | No — solo predice en las unidades originales (hexágonos) |
| **Visualiza "errores"** | Sí — el mapa de residuos krigeados muestra zonas anómalas | No directamente |
| **Coherencia con co-kriging** | Total — usa el mismo marco geoestadístico (variogramas, kriging) | Diferente marco teórico (econometría espacial) |
| **Cuándo usarlo** | Cuando quieres predecir Y explicar, y tienes datos puntuales | Cuando tienes datos agregados en áreas y priorizas inferencia causal |

Para este proyecto, la Regression Kriging es más natural porque:
1. Ya estamos usando variogramas y kriging (scripts 01-02)
2. Los coeficientes OLS son directamente interpretables
3. El mapa de residuos espaciales revela información adicional valiosa
4. Produce superficies continuas compatibles con los mapas de co-kriging

### 10.4. Los cuatro mapas que genera

El script `07_regression_kriging.R` produce un mapa interactivo con cuatro capas:

1. **Regression Kriging (final):** La predicción completa = OLS + kriging residuos. Este es el mapa principal.

2. **Solo OLS (tendencia):** Qué predice la regresión sin considerar el espacio. Muestra los gradientes que explican las variables (distancia al metro, allanamientos, empresas, etc.).

3. **Residuo espacial (kriged):** Lo más interesante analíticamente. Muestra dónde la realidad difiere de lo que los predictores predicen:
   - **Azul** = percepción MEJOR de lo esperado (residuo negativo = el valor real es menor que la predicción OLS, es decir, menos inseguridad de la esperada)
   - **Rojo** = percepción PEOR de lo esperado (residuo positivo = más inseguridad de la esperada)

   Las zonas rojas y azules merecen investigación: ¿qué factor no medido explica que esa zona sea diferente?

4. **Incertidumbre (varianza):** Muestra dónde la predicción es más o menos confiable. Mayor varianza (azul más oscuro) = menos confianza. Típicamente la incertidumbre es mayor en los bordes del área de estudio y donde hay menos datos.

---

## 11. Interpretación de los resultados

### 11.1. Variable dependiente

La variable que estamos prediciendo es la **percepción de seguridad co-krigeada** (de los scripts 01-02). Esta superficie combina datos directos de la Encuesta de Percepción y Victimización (EPV) 2025 con datos de delitos, mediante co-kriging. Valores más altos = mayor percepción de inseguridad.

### 11.2. Los coeficientes OLS y qué significan

El modelo OLS tiene un R² ajustado de 0.1216 — es decir, las 12 variables explican el 12.2% de la variación en percepción. Esto puede parecer bajo, pero es normal en datos espaciales urbanos donde hay muchos factores no observados. Lo importante es que el variograma de residuos captura otro ~68% de la varianza restante como estructura espacial.

**Variables significativas (p < 0.05):**

| Variable | β | p-valor | Interpretación |
|----------|---|---------|----------------|
| **log_raids** (allanamientos, log) | −0.1287 | < 0.001 | Donde hay más allanamientos policiales, la percepción de inseguridad es MENOR. Un aumento de 1 unidad en log(allanamientos) se asocia con una reducción de 0.13 en el índice de percepción. Esto sugiere que la presencia policial activa (operativos) tiene un efecto disuasivo visible para los ciudadanos. |
| **pct_mipyme** (% micro, pequeñas y medianas empresas) | −13.81 | < 0.001 | Donde hay mayor proporción de MiPymes, la percepción de inseguridad es MENOR. El coeficiente es grande porque pct_mipyme va de 0 a 1 — un aumento de 10 puntos porcentuales en la participación MiPyme se asocia con una reducción de 1.38 en el índice. Esto refleja que las zonas con tejido empresarial denso y diverso (tiendas, talleres, servicios) generan mayor vigilancia natural y sentimiento de seguridad. |

**Variables marginalmente significativas (p < 0.10):**

| Variable | β | p-valor | Interpretación |
|----------|---|---------|----------------|
| **dist_metro_km** | +0.0375 | 0.066 | Tendencia (no conclusiva) a mayor inseguridad percibida lejos del metro. |
| **log_arrests** (capturas) | −0.0363 | 0.091 | Tendencia similar a allanamientos — más capturas, menos inseguridad percibida. |
| **cambio_ops_total** (cambio en operativos antes/durante) | +0.0150 | 0.075 | Donde los operativos aumentaron más durante la obra, la percepción de inseguridad tiende a ser ligeramente mayor. Esto podría reflejar que la policía reforzó presencia precisamente en las zonas más problemáticas (causalidad inversa). |
| **n_edificios** | +0.0009 | 0.051 | Leve tendencia a mayor inseguridad en zonas con más edificaciones. |

**Variables no significativas (p > 0.10):**

| Variable | β | p-valor | Nota |
|----------|---|---------|------|
| cambio_total (delitos) | −0.0003 | 0.48 | El cambio en delitos antes/durante la obra no predice la percepción |
| log_seizures (incautaciones) | −0.0370 | 0.14 | Dirección esperada (negativa) pero no significativa |
| densidad_empresas | +0.00004 | 0.72 | La cantidad bruta de empresas no importa — importa la composición (% MiPyme) |
| pct_verde | +0.0601 | 0.18 | Las áreas verdes no se asocian significativamente con percepción |
| uso_comercial | −0.0688 | 0.10 | Cerca del umbral — tendencia a menor inseguridad en zonas comerciales |
| longitud_vias_m | +0.000008 | 0.70 | La densidad vial no predice percepción |

### 11.3. El variograma de los residuos

El variograma de residuos OLS nos dice algo fundamental: **¿qué tanto de la variación "no explicada" tiene un patrón geográfico?**

```
Variograma de residuos OLS:
  Nugget = 0.0497   (31.7% del sill — ruido aleatorio)
  Sill   = 0.1566   (varianza total de los residuos)
  Range  = 999 m    (alcance de la correlación espacial)
```

**¿Qué significa el range de 999 m en los residuos?**

Después de descontar el efecto de los 12 predictores, los residuos aún están correlacionados espacialmente hasta ~1 km. Esto significa que hay factores no medidos que influyen en la percepción de seguridad y que operan a escala de ~1 km. Posibles candidatos:
- Dinámicas sociales de barrio (cohesión social, redes vecinales)
- Presencia de actores específicos (bandas, vendedores ambulantes, habitantes de calle)
- Historia del lugar (zonas con tradición de inseguridad)
- Infraestructura de iluminación y vigilancia
- Configuración urbanística (calles sin salida, lotes baldíos, puentes peatonales)

**¿Qué significa el ratio nugget/sill de 0.317?**

- El 31.7% de la varianza residual es ruido puro (sin estructura espacial)
- El 68.3% restante tiene estructura espacial que el kriging puede capturar
- Esto es una estructura **moderada**: los predictores capturan algo, pero no todo

Si el ratio fuera mayor a 0.75, significaría que el OLS ya captura bien la variación espacial y el kriging de residuos aportaría poco. Si fuera menor a 0.25, significaría que hay patrones espaciales muy fuertes que los predictores no capturan.

### 11.4. El mapa de residuos espaciales: dónde investigar

El mapa del residuo krigeado es quizás el producto más valioso del análisis, porque señala **dónde hay anomalías** que merecen investigación de campo:

- **Zonas azules (residuo negativo):** La percepción de inseguridad es mejor de lo que predicen las variables. Algo no medido está funcionando bien en esas zonas: ¿una JAC activa? ¿un comercio ancla que genera vigilancia natural? ¿un parque bien mantenido?

- **Zonas rojas (residuo positivo):** La percepción de inseguridad es peor de lo esperado. Aunque las variables "dicen" que debería estar bien, algo está mal: ¿un punto de venta de drogas? ¿un lote baldío? ¿un tramo de obra particularmente invasivo?

Estas zonas son insumo directo para **recomendaciones de política pública**: las zonas rojas son prioridad de intervención, y las zonas azules son modelos para replicar.

### 11.5. Hallazgos principales para el Reto 2

1. **Los allanamientos policiales son el predictor más fuerte** (β = −0.13, p < 0.001). Los operativos activos de la policía se asocian con mejor percepción de seguridad. Esto es un hallazgo accionable: reforzar operativos en el corredor del Metro puede mejorar la percepción.

2. **El tejido MiPyme protege** (β = −13.81, p < 0.001). Las zonas con mayor proporción de micro, pequeñas y medianas empresas tienen mejor percepción de seguridad. Las MiPymes generan "ojos en la calle" (vigilancia natural). Proteger este tejido empresarial durante la obra es crucial.

3. **La distancia al Metro no es significativa al 5%**, aunque hay una tendencia (p = 0.066). Esto no significa que la obra no tenga impacto — puede significar que los efectos operan a través de canales indirectos (cierre de negocios, cambio en operativos policiales) más que por proximidad directa.

4. **El cambio en delitos antes/durante NO predice la percepción** (p = 0.48). La percepción no se mueve mecánicamente con los delitos. Esto es consistente con la literatura criminológica: la percepción de seguridad depende más de factores ambientales y sociales que de las tasas de delitos reales.

5. **Hay estructura espacial no explicada** (range = 999 m, ratio n/s = 0.317). Factores no medidos influyen en la percepción hasta ~1 km de distancia. El mapa de residuos señala exactamente dónde están estas anomalías.

---

## 12. Resumen del flujo completo del proyecto

```
DATOS CRUDOS          VARIOGRAMA           CO-KRIGING          REGRESSION KRIGING
(6 fuentes)           (estructura)         (superficie)        (modelo + mapa)

Delitos ─────┐
Percepción ──┤        ┌─ Variograma ─┐     ┌─ Superficie ─┐
Operativos ──┤───────►│  directo +   │────►│  continua de │    ┌─ OLS: β's ──┐
Empresas ────┤        │  cruzado     │     │  cada tipo   │    │ (por qué)   │
Entorno OSM ─┤        └──────────────┘     └──────────────┘    │             │
Secciones ───┘                                                 │ + Kriging   │
                                                               │ residuos    │
                                            Hexágonos con ────►│ (dónde)     │
                                            69 variables       │             │
                                                               └─ Mapa final─┘
                                                                  4 capas
```

**Scripts del pipeline:**
1. `01_cokriging_pipeline.R` — Variogramas + co-kriging de delitos y percepción
2. `02_cokriging_maps.R` — Mapas raster de superficies co-krigeadas
3. `03_antes_durante_metro.R` — Delitos y operativos antes/durante + anisotropía
4. `04_empresas_metro.R` — Tejido empresarial (Registro Mercantil)
5. `05_entorno_metro.R` — Entorno urbano (OpenStreetMap)
6. `06_integracion_metro.R` — Regresión SAR/SEM + mapa integrado
7. `07_regression_kriging.R` — Regression kriging + mapa de 4 capas

---

## 13. Glosario rápido

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
| Regression Kriging | Método que combina regresión OLS (tendencia) + kriging de residuos (estructura espacial remanente) |
| Residuo espacial | La diferencia entre el valor observado y lo que predice la regresión OLS, interpolada espacialmente por kriging |
| Ratio nugget/sill | Proporción de varianza sin estructura espacial. Bajo (<0.25) = fuerte estructura; alto (>0.75) = poca estructura |
| SAR | Spatial Autoregressive Model — modelo de econometría espacial que incorpora un rezago espacial de la variable dependiente |
| SEM | Spatial Error Model — modelo de econometría espacial que incorpora autocorrelación en los errores |
| OLS | Ordinary Least Squares — regresión lineal clásica sin componente espacial |
