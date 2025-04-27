# ENTREGA PROYECTO CIENCIA DE DATOS

## Clustering

### Enunciado
El enunciado para el ejercicio de clustering dictaba lo siguiente:

Se les ha pedido a dos conductores que realizaran el mismo trayecto con el mismo vehı́culo tres veces de modo que cada vez aplicasen uno de estos modelos de conducción: 0 un estilo de conducción tranquila, 1 un estilo de conducción normal, y 2 un estilo de conducción agresiva. Durante estas pruebas se han registrado varias métricas del coche, que están registradas en el fichero ”Datosconduccion”. Se nos ha informado que durante la toma de muestras se ha visto que los datos de velocidad angular en los ejes X, Y y Z del giroscopio no están siendo bien registrados y muestran valores anómalos. No sabemos si debemos descartarlos.



**Introducción y objetivos**  
El objetivo de este ejercicio es aplicar un algoritmo de **K‐means** para segmentar las observaciones de un vehículo en función de distintas métricas de conducción, y luego comparar estos **clusters** con los tres estilos de conducción subjetivos (0: tranquila, 1: normal, 2: agresiva) que se registraron durante la toma de datos. Además, evaluaremos la relevancia de cada variable en la definición de los grupos y comprobaremos hasta qué punto el resultado del K‐means reproduce las etiquetas “a priori”.

---

### 1. Librerías y entorno de trabajo  
Para este análisis he empleado exclusivamente componentes de la instalación base de R y una biblioteca adicional para la lectura del Excel:

- **`stats`** (base): contiene la implementación de `kmeans()`, `prcomp()` y las funciones de generación de distribuciones y cálculos estadísticos fundamentales.  
- **`graphics`** (base): proporciona la funcionalidad de trazado de gráficos (`plot()`, `boxplot()`, etc.).  
- **`readxl`**: permite importar directamente el archivo `.xlsx` sin necesidad de conversión previa a CSV. Su instalación y carga se realiza con:

  ```r
  install.packages("readxl")
  library(readxl)
  ```

Finalmente, establezco un **directorio de trabajo** (con `setwd()`) que alberga el fichero `datosconduccion.xlsx`.

---

### 2. Importación y exploración de los datos  
El conjunto “Datosconduccion” se importa saltando las filas de encabezado que no contienen la tabla propiamente dicha (usamos `skip = 11`). A continuación renombro explícitamente las **16 columnas** conforme al enunciado, ya que contienen espacios que pueden causar problemas a la hora de referenciarlas, y por claridad personal:

```r
datos <- read_excel("datosconduccion.xlsx",
                    sheet = "vehicle_data",
                    skip  = 11)
names(datos) <- c("Conductor","Estilo","TouchCount","RPM","FuelTrim",
                  "Speed","ThrottlePos","EngineLoad","MaxSpeed","Gear",
                  "GyroX","GyroY","GyroZ","AccelX","AccelY","AccelZ")
```

Con `head(datos)` y `summary(datos)` confirmo que:
1. **Todas las columnas** salvo `Estilo` son numéricas (dbl).  
2. No existen **valores faltantes** (NA).  
3. Los giroscopios (`GyroX`, `GyroY`, `GyroZ`) muestran **outliers** muy pronunciados en sus diagramas de caja, asi que he decidido **no incluirlos** en el análisis, ya que no aportan información relevante y pueden distorsionar los resultados.

Estos son los valores antes de la limpieza:

![alt text](image.png)

![alt text](image-1.png)

![alt text](image-2.png)

![alt text](image-3.png)

Estos son los valores después de la limpieza:

![alt text](image-4.png)

![alt text](image-5.png)

![alt text](image-6.png)

Aunque podemos ver que todavía hay algunos outliers, no son tan extremadamente pronunciados como los anteriores.


---

### 3. Preprocesado de variables  
Para el **K‐means** solo selecciono todas las variables numéricas. Si no hubiesemos descartado los giroscopios, habría que haberlos excluido explícitamente. En este caso, selecciono las variables relevantes:

```r
vars <- c("TouchCount","RPM","FuelTrim","Speed",
          "ThrottlePos","EngineLoad","MaxSpeed","Gear",
          "AccelX","AccelY","AccelZ", "GyroX","GyroY","GyroZ")
X    <- datos[, vars]
```

Puesto que K‐means optimiza la **distancia euclídea**, es imprescindible normalizar las variables para equiparar sus rangos. Aplico una **transformación Z‐score** (media 0, varianza 1) mediante:

```r
X.sc <- scale(X)
```

---

### 4. Determinación del número de clusters (k)  
Para estimar el valor de **k** uso el **método del codo**: calculo la suma de inercia intra‐cluster (Within‐Sum‐of‐Squares) para `k` de 1 a 10, repitiendo cada ajuste 25 veces (`nstart = 25`) para minimizar la probabilidad de caer en mínimos locales:

```r
wss <- numeric(10)
for (k in 1:10) {
  wss[k] <- sum(kmeans(X.sc, centers = k, nstart = 25)$withinss)
}
plot(1:10, wss, type="b",
     xlab="Número de clusters (k)",
     ylab="Inercia intra‐cluster",
     main="Método del codo")
```

![alt text](image-7.png)

Se ve un codo muy acusado entre k=1 y k=2 (la mayor bajada de inercia), y a continuación la curva se relaja y desciende de forma más suave a partir de ahí. Si descartásemos el caso trivial de k=1, el siguiente punto de inflexión menor aparece alrededor de k=3. Por tanto, elijo **k=3** como el número óptimo de clusters.

---

### 5. Ajuste del modelo K‐means  
Fijo una **semilla aleatoria** (`set.seed(42)`) para que el resultado sea reproducible y lanzo el algoritmo K‐means con **50 inicializaciones** (`nstart = 50`).

```r
set.seed(42)
km <- kmeans(X.sc, centers = 3, nstart = 50)
```
A continuación, imprimo el resultado de los tamaños de los clusters y los centroides:

- **`km$size`** me indica cuántas observaciones asigna cada cluster.  
- **`km$centers`** contiene los **centroides** en el espacio escalado, revelando en qué variables difieren más los grupos.

![alt text](image-8.png)

Asigno finalmente cada etiqueta de cluster al data.frame original:

```r
datos$Cluster <- factor(km$cluster)
```

---

### 6. Evaluación cuantitativa y visual  
1. **Tabla de contingencia** `Cluster vs. Estilo` con:

   ```r
   table(Cluster = datos$Cluster,
         Estilo  = datos$Estilo)
   ```

   ![alt text](image-9.png)
   
   Esto mide la concordancia bruta:  
   - El **cluster 1** coincide mayoritariamente con el estilo 0 (“tranquila”).
   - El **cluster 3** coincide mayoritariamente con el estilo 2 (“agresiva”).  
   - El **cluster 2** agrupa casi equitativamente los 3 estilos.
   
2. **Análisis de Componentes Principales** (PCA) para visualizar la separación y cuantificar la contribución de cada variable:

   ```r
   pc <- prcomp(X.sc)
   plot(pc$x[,1:2], col=datos$Cluster, pch=16,
        xlab="PC1", ylab="PC2",
        main="PC1 vs PC2 coloreado por cluster")
   ```

   ![alt text](image-10.png)
   
   - Los **loadings** (`pc$rotation[,1:2]`) evidencian que `Speed`, `RPM` y `AccelX/Y` son las variables de mayor peso en la primera componente, y por tanto las que más influyen en la partición.

3. **Centroides**:

   ```r
   round(km$centers, 2)
   ```

   ![alt text](image-11.png)
   
   Comparar los valores de los centroides en escala Z muestra que variables tienen las mayores diferencias medias entre clusters.

---

**Conclusión**  
Este análisis, apoyado en un **agrupamiento K‐means** teóricamente bien calibrado (k = 3), demuestra que las variables que más pesan en la distinción de estilos de conducción son principalmente la velocidad (`Speed`), las revoluciones por minuto del motor (`RPM`) y las aceleraciones longitudinales (`AccelX`). Con los resultados anteriormente obtenidos, podemos concluir que los clusters no referencian bien los estilos que pretenden, ya que pese a que en el cluster 1 y 3 encontramos prevalencia de algunos estilos, en el 2 hay un gran solapamiento. Además, las diferencias de estilos en los clusters 1 y 2 no son muy pronunciadas.