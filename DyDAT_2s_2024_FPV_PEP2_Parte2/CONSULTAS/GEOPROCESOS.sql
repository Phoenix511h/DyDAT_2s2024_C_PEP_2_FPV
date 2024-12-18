
-- Este script realiza una serie de geoprocesos y análisis espaciales sobre la tabla SITIOERIAZO_13106.
-- El objetivo es identificar sitios eriazos que cumplen con ciertas condiciones y jerarquizarlos según un indicador compuesto.

-- 1. Agregar Identificador Único a SITIOERIAZO_13106
-- Verifica si la columna 'gid' existe en la tabla 'SITIOERIAZO_13106' y, si no, la agrega como una columna SERIAL PRIMARY KEY.

-- 2. Crear tabla con predios eriazos en zonas permitidas (PRC13106)
-- Crea una nueva tabla 'SITIO_ERIAZO_GEOPROCESO' que contiene los predios eriazos que intersectan con las zonas permitidas definidas en 'PRC13106'.

-- 3. Agregar columna de distancia mínima a gasolineras
-- Añade una columna 'distancia_gasolinera' a la tabla 'SITIO_ERIAZO_GEOPROCESO' para almacenar la distancia mínima a las gasolineras.

-- 4. Calcular la distancia mínima desde cada predio eriazo a gasolineras existentes
-- Actualiza la columna 'distancia_gasolinera' con la distancia mínima calculada desde cada predio eriazo a las gasolineras en un radio de 10 km.

-- 5. Calcular área en km2
-- Añade una columna 'area_km2' a la tabla 'SITIO_ERIAZO_GEOPROCESO' y la actualiza con el área de cada predio en kilómetros cuadrados.

-- 6. Contar la cantidad de personas en un área de influencia respecto a los Sitios Eriazos
-- a. Crear buffers de 1.5 km alrededor de cada predio eriazo.
-- b. Realizar un spatial join entre los buffers y las manzanas censales para contar la población.
-- c. Disolver por 'gid' y sumar la población total.
-- d. Agregar una columna 'poblacion_total' a la tabla 'SITIO_ERIAZO_GEOPROCESO' y actualizarla con los resultados.

-- 7. Elegir los sitios eriazos que cumplen con las condiciones de PRC, área, distancia a gasolinera y población en el área de influencia
-- Crea una nueva tabla 'SITIO_ERIAZO_SELECCIONADO' con los sitios eriazos que cumplen con las condiciones especificadas:
--    - ZONA en ('IPI', 'IPH', 'IPA', 'IPB', 'IPC', 'IPD', 'IPE', 'IPF', 'IPX', 'Z-LBO', 'Z-RB', 'Z-RI')
--    - área mayor a 0.000002 km2
--    - distancia a gasolinera mayor a 1000 metros
--    - población total mayor a 50000 personas

-- 8. Calcular Min-Max Normalization para cada columna
-- a. Añadir columnas para Min-Max normalization si no existen.
-- b. Calcular la normalización Min-Max para 'area_km2', 'distancia_gasolinera' y 'poblacion_total'.

-- 9. Añadir columna a SITIO_ERIAZO_SELECCIONADO jerarquizando según un indicador de cual es mejor opción
-- a. Añadir una columna 'indicador' a la tabla 'SITIO_ERIAZO_SELECCIONADO'.
-- b. Calcular el indicador usando las columnas normalizadas con los siguientes pesos:
--    - 40% para 'area_km2_minmax'
--    - 30% para 'distancia_gasolinera_minmax'
--    - 30% para 'poblacion_total_minmax'

-- 10. Seleccionar los 10 mejores sitios eriazos según el indicador
-- Realiza una consulta para seleccionar los 10 sitios eriazos con el mayor valor de 'indicador' y los ordena de forma descendente.

---- agregar Identificador Unico a SITIOERIAZO 13106
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'entradas' 
          AND table_name = 'SITIOERIAZO_13106' 
          AND column_name = 'gid'
    ) THEN
        ALTER TABLE entradas."SITIOERIAZO_13106"
        ADD COLUMN gid SERIAL PRIMARY KEY;
    END IF;
END$$;
-- Crear tabla con predios eriazos en zonas permitidas
CREATE TABLE IF NOT EXISTS resultados."SITIO_ERIAZO_GEOPROCESO" AS
SELECT DISTINCT ON (p.gid)
    p.*,
    prc."ZONA"
FROM entradas."SITIOERIAZO_13106" AS p
JOIN entradas."PRC13106" AS prc
ON ST_Intersects(p.geometry, prc.geometry);


-- Agregar columna de distancia mínima a gasolineras
ALTER TABLE resultados."SITIO_ERIAZO_GEOPROCESO"
ADD COLUMN IF NOT EXISTS distancia_gasolinera DOUBLE PRECISION;

-- Calcular la distancia mínima desde cada predio eriazo a gasolineras existentes
UPDATE resultados."SITIO_ERIAZO_GEOPROCESO" AS pz
SET distancia_gasolinera = subquery.distancia_min
FROM (
    SELECT 
        pz.gid, 
        MIN(
            ST_Distance(
                ST_Transform(pz.geometry, 3857), -- Transformación a EPSG:3857
                ST_Transform(g.geometry, 3857)  -- Transformación a EPSG:3857
            )
        ) AS distancia_min
    FROM resultados."SITIO_ERIAZO_GEOPROCESO" AS pz
    JOIN entradas."GASOLINERA" AS g
    ON ST_DWithin(
        ST_Transform(pz.geometry, 3857),
        ST_Transform(g.geometry, 3857),
        10000 -- Umbral de 10 km en metros
    )
    GROUP BY pz.gid
) AS subquery
WHERE pz.gid = subquery.gid;

--__________________________________________________________________________--
-- Calcular area en km2
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'resultados' 
          AND table_name = 'SITIO_ERIAZO_GEOPROCESO' 
          AND column_name = 'area_km2'
    ) THEN
        ALTER TABLE resultados."SITIO_ERIAZO_GEOPROCESO"
        ADD COLUMN area_km2 DOUBLE PRECISION;
    END IF;
END$$;

UPDATE resultados."SITIO_ERIAZO_GEOPROCESO"
SET area_km2 = ST_Area(geometry::geography)/1000000;




-----------------------------------------
--	Contar la cantidad de personas en un area de influencia respecto a los Sitios Eriazos

-- 1. Crear buffers de 1.5 km alrededor de cada predio eriazo
CREATE TABLE IF NOT EXISTS resultados."SITIO_ERIAZO_BUFFER_1_5KM" AS
SELECT 
    gid, 
    ST_Buffer(geometry::geography, 1500)::geometry AS buffer_geometry
FROM resultados."SITIO_ERIAZO_GEOPROCESO";

-- 2. Realizar el spatial join entre buffers y manzanas censales
CREATE TABLE IF NOT EXISTS resultados."SPATIAL_JOIN_BUFFER_MANZANA" AS
SELECT 
    pz.gid AS sitio_gid,
    mz."TOTAL_PERS"
FROM resultados."SITIO_ERIAZO_BUFFER_1_5KM" AS pz
JOIN entradas."MANZANA13106" AS mz
ON ST_Intersects(pz.buffer_geometry, mz.geometry);

-- 3. Disolver por gid y sumar la población
CREATE TABLE IF NOT EXISTS resultados."POPULATION_DISSOLVED" AS
SELECT 
    sitio_gid,
    SUM("TOTAL_PERS") AS poblacion_total
FROM resultados."SPATIAL_JOIN_BUFFER_MANZANA"
GROUP BY sitio_gid;



-- 4. Agregar columna de población en SITIO_ERIAZO_GEOPROCESO
ALTER TABLE resultados."SITIO_ERIAZO_GEOPROCESO"
ADD COLUMN IF NOT EXISTS poblacion_total BIGINT;

-- 5. Actualizar SITIO_ERIAZO_GEOPROCESO con los resultados
UPDATE resultados."SITIO_ERIAZO_GEOPROCESO" AS pz
SET poblacion_total = pd.poblacion_total
FROM resultados."POPULATION_DISSOLVED" AS pd
WHERE pz.gid = pd.sitio_gid;

-- Eliminar tablas auxiliares
DROP TABLE IF EXISTS resultados."SITIO_ERIAZO_BUFFER_1_5KM";
DROP TABLE IF EXISTS resultados."SPATIAL_JOIN_BUFFER_MANZANA";
DROP TABLE IF EXISTS resultados."POPULATION_DISSOLVED";





------  Elegir los sitios eriazos que cumplen con las condiciones de PRC, AREA, DISTANCIA A GASOLINERA Y POBLACION en la area de influencia
CREATE TABLE IF NOT EXISTS resultados."SITIO_ERIAZO_SELECCIONADO" AS
SELECT 
    pz.*
FROM resultados."SITIO_ERIAZO_GEOPROCESO" AS pz
-- ZONA = IPI o IPH o IPA o IPB o IPC o IPD o IPE o IPF o IPX o Z-LBO o Z-RB o Z-RI
-- area_km2 > 0.000002
-- distancia_gasolinera > 1000
-- poblacion_total > 50000
WHERE pz."ZONA" IN ('IPI', 'IPH', 'IPA', 'IPB', 'IPC', 'IPD', 'IPE', 'IPF', 'IPX', 'Z-LBO', 'Z-RB', 'Z-RI')
AND pz.area_km2 > 0.000002
AND pz.distancia_gasolinera > 1000
AND pz.poblacion_total > 50000;


-- 1. Crear columnas para Min-Max si no existen
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'resultados' 
          AND table_name = 'SITIO_ERIAZO_SELECCIONADO' 
          AND column_name = 'area_km2_minmax'
    ) THEN
        ALTER TABLE resultados."SITIO_ERIAZO_SELECCIONADO" 
        ADD COLUMN area_km2_minmax DOUBLE PRECISION;
    END IF;
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'resultados' 
          AND table_name = 'SITIO_ERIAZO_SELECCIONADO' 
          AND column_name = 'distancia_gasolinera_minmax'
    ) THEN
        ALTER TABLE resultados."SITIO_ERIAZO_SELECCIONADO" 
        ADD COLUMN distancia_gasolinera_minmax DOUBLE PRECISION;
    END IF;
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'resultados' 
          AND table_name = 'SITIO_ERIAZO_SELECCIONADO' 
          AND column_name = 'poblacion_total_minmax'
    ) THEN
        ALTER TABLE resultados."SITIO_ERIAZO_SELECCIONADO" 
        ADD COLUMN poblacion_total_minmax DOUBLE PRECISION;
    END IF;
END$$;

-- 2. Calcular Min-Max Normalization para cada columna
-- Min-Max de área
UPDATE resultados."SITIO_ERIAZO_SELECCIONADO"
SET area_km2_minmax = (area_km2 - (SELECT MIN(area_km2) FROM resultados."SITIO_ERIAZO_SELECCIONADO")) 
                       / ((SELECT MAX(area_km2) FROM resultados."SITIO_ERIAZO_SELECCIONADO") - (SELECT MIN(area_km2) FROM resultados."SITIO_ERIAZO_SELECCIONADO"));

-- Min-Max de distancia a gasolineras
UPDATE resultados."SITIO_ERIAZO_SELECCIONADO"
SET distancia_gasolinera_minmax = (distancia_gasolinera - (SELECT MIN(distancia_gasolinera) FROM resultados."SITIO_ERIAZO_SELECCIONADO")) 
                                   / ((SELECT MAX(distancia_gasolinera) FROM resultados."SITIO_ERIAZO_SELECCIONADO") - (SELECT MIN(distancia_gasolinera) FROM resultados."SITIO_ERIAZO_SELECCIONADO"));

-- Normalización Min-Max para población total con conversión a DOUBLE PRECISION
UPDATE resultados."SITIO_ERIAZO_SELECCIONADO"
SET poblacion_total_minmax = (
    (poblacion_total::DOUBLE PRECISION - (SELECT MIN(poblacion_total) FROM resultados."SITIO_ERIAZO_SELECCIONADO")::DOUBLE PRECISION)
    / ((SELECT MAX(poblacion_total) FROM resultados."SITIO_ERIAZO_SELECCIONADO")::DOUBLE PRECISION - (SELECT MIN(poblacion_total) FROM resultados."SITIO_ERIAZO_SELECCIONADO")::DOUBLE PRECISION)
);



-- Añadir columna a SITIO_ERIAZO_SELECCIONADO jerarquizando segun un indicador de cual es mejor opcion
ALTER TABLE resultados."SITIO_ERIAZO_SELECCIONADO"
ADD COLUMN IF NOT EXISTS indicador DOUBLE PRECISION;

-- Calcular el indicador usando las columnas normalizadas y ajustando la distancia
UPDATE resultados."SITIO_ERIAZO_SELECCIONADO"
SET indicador = (
    (0.4 * area_km2_minmax) +                             
    (0.3 * (distancia_gasolinera_minmax)) +        
    (0.3 * (poblacion_total_minmax))          
);


-- VISUALIZACION DE LAS 10 mejores opciones respecto al indicador
SELECT *
FROM resultados."SITIO_ERIAZO_SELECCIONADO"
ORDER BY indicador DESC
LIMIT 10;