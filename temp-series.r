library(stats)
library(forecast)
library(lubridate)

# 2) Importación y exploración de datos
# -------------------------------------
# Ajusta tu directorio de trabajo a la carpeta donde estén los CSV:
# setwd("ruta/a/tu/carpeta")

whole_years  <- read.csv("Whole_years.csv", stringsAsFactors=FALSE)
series_data  <- read.csv("data_series.csv", stringsAsFactors=FALSE)

# Estructura inicial
str(whole_years)   # StationID: int, Year: int
str(series_data)   # StationID, SeriesNumber, Date (YYYY-MM), Temperature: num

# Comprobación básica de integridad
stopifnot(
  sum(is.na(whole_years)) == 0,
  sum(is.na(series_data)) == 0,
  !any(duplicated(whole_years)),
  !any(duplicated(series_data[,1:2]))
)

# 2.1) Parseo de la columna Date con lubridate y extracción de año/mes
# ---------------------------------------------------------------------
# series_data$Date viene en formato "YYYY-MM":
series_data$Date2  <- ymd(paste0(series_data$Date, "-01"))
series_data$Year   <- year(series_data$Date2)
series_data$Month  <- month(series_data$Date2)

# 3) Localizar estaciones con datos completos 2000–2019
# ------------------------------------------------------
target_years <- 2000:2019
ok_stations  <- with(whole_years,
  tapply(Year, StationID, function(v) all(target_years %in% v))
)
ok_stations  <- names(ok_stations)[ok_stations]
cat(length(ok_stations), "estaciones con registros completos 2000–2019\n")

# 4) Filtrado y construcción de series temporales (ts) por estación
# ----------------------------------------------------------------
series_cmpl <- subset(series_data, StationID %in% ok_stations)
ts_list     <- setNames(vector("list", length(ok_stations)), ok_stations)

for(st in ok_stations){
  tmp <- subset(series_cmpl, StationID == st)
  tmp <- tmp[order(tmp$Year, tmp$Month), ]
  ts_list[[st]] <- ts(tmp$Temperature,
                     start    = c(2000, 1),
                     frequency= 12)
}

# 5) Ajuste de modelos SARIMA para cada serie
# --------------------------------------------
fit_list <- ts_list  # mismo nombre de estaciones

for(st in names(ts_list)){
  x <- ts_list[[st]]
  # Tras examinar diff() & ACF/PACF, decidimos:
  d <- 1; D <- 1; s <- 12
  fit_list[[st]] <- Arima(x,
                          order     = c(1, d, 1),
                          seasonal  = c(1, D, 1))
  cat("== Estación:", st, "– SARIMA(1,1,1)(1,1,1)[12] ==\n")
  print(fit_list[[st]])
  cat("\n")
}

# 6) Predicción junio 2020 y comparación con media histórica 2000–2009
# --------------------------------------------------------------------
results <- data.frame(
  StationID       = character(),
  Forecast2020_06 = numeric(),
  Mean2000_09     = numeric(),
  PE              = numeric(),
  stringsAsFactors= FALSE
)

for(st in names(fit_list)){
  f    <- forecast(fit_list[[st]], h=18)
  pred <- as.numeric(f$mean[6])           # junio 2020
  x    <- ts_list[[st]]
  mh   <- window(x, start=c(2000,6), end=c(2009,6))
  avg  <- mean(mh)
  pe   <- 100*(pred - avg)/avg
  
  results <- rbind(results, data.frame(
    StationID       = st,
    Forecast2020_06 = pred,
    Mean2000_09     = avg,
    PE              = pe,
    stringsAsFactors= FALSE
  ))
}

# Guardar resultados
write.csv(results,
          "Resultados_Jun2020_vs_2000_09.csv",
          row.names=FALSE)

# 7) Ejemplo de diagnóstico gráfico para una estación
# ---------------------------------------------------
example_st <- names(fit_list)[1]
p <- autoplot(ts_list[[example_st]]) +
     autolayer(forecast(fit_list[[example_st]], h=18),
               PI=TRUE, series="Pronóstico") +
     ggtitle(paste("Estación", example_st, "– TAVG mensual")) +
     xlab("Tiempo") + ylab("Temperatura (ºC)")
print(p)

# 8) Resumen de errores porcentuales
# ----------------------------------
summary(results$PE)
