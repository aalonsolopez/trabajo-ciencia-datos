library(readxl)


setwd("/home/aalonso/Personal/Master/CCDD/trabajo-ciencia-datos")


datos <- read_excel("datosconduccion.xlsx",
                    sheet = "vehicle_data",
                    skip  = 11,       # salta las 10 primeras filas
                    col_types = rep("numeric", 16))     # todas numéricas salvo Conductor
names(datos) <- c("Conductor", "Estilo", "TouchCount", "RPM", "FuelTrim",
                  "Speed", "ThrottlePos", "EngineLoad", "MaxSpeed", "Gear",
                  "GyroX", "GyroY", "GyroZ", "AccelX", "AccelY", "AccelZ")

head(datos)
summary(datos)
anyNA(datos)

boxplot(datos$GyroX, main="GyroX")
boxplot(datos$GyroY, main="GyroY")
boxplot(datos$GyroZ, main="GyroZ")

# Filtrar outliers de los giroscopios eliminando valores extremos
umbral <- 3  # Definir un umbral de 3 desviaciones estándar
filtro <- abs(datos$GyroX) < umbral & abs(datos$GyroY) < umbral & abs(datos$GyroZ) < umbral
datos <- datos[filtro, ]

boxplot(datos$GyroX, main="GyroX")
boxplot(datos$GyroY, main="GyroY")
boxplot(datos$GyroZ, main="GyroZ")


# Nos quedamos sólo con las variables numéricas que tengan sentido:
vars  <- c("TouchCount","RPM","FuelTrim","Speed","ThrottlePos",
           "EngineLoad","MaxSpeed","Gear","AccelX","AccelY","AccelZ", "GyroX","GyroY","GyroZ")
X     <- datos[ , vars ]

X.sc  <- scale(X)
X.sc[is.na(X.sc)] <- 0  

# Eliminar columnas con varianza cero antes de realizar el PCA
X.sc <- X.sc[, apply(X.sc, 2, var) > 0]

# Búsqueda de k óptimo
wss <- numeric(10)
for (k in 1:10) {
  wss[k] <- sum(kmeans(X.sc, centers=k, nstart=25)$withinss)
}
plot(1:10, wss, type="b", xlab="Número de clusters k", ylab="Within-Sum-of-Squares",
     main="Método del codo (Elbow)")

# Ajuste de K-means con k = 3
set.seed(42)
km <- kmeans(X.sc, centers=3, nstart=50)
km$size    # número de datos en cada cluster
km$centers # centroides (en escala)

# Añadimos el cluster al data.frame original
datos$Cluster <- factor(km$cluster)

# Evaluación de resultados
table(Cluster = datos$Cluster,
      Estilo  = datos$Estilo)

# PCA para ver qué variables explican más separación
pc <- prcomp(X.sc)

# Proyecciones coloreadas por cluster
plot(pc$x[,1:2], col=datos$Cluster, pch=16,
     xlab="PC1", ylab="PC2",
     main="PCA coloreada por cluster")
legend("topright", legend=levels(datos$Cluster),
       col=1:3, pch=16)

# Miramos los centroides en escala original
round(km$centers, 2)
