<h2 align="center">
  <img width="200" src="https://upload.wikimedia.org/wikipedia/commons/d/d9/Usach_P1.png" alt="logo Usach" >
  <img width="450" src="https://www.digea.usach.cl/digea/site/artic/20230110/imag/foto_0000000620230110165150/LOGO_DIGEA_MAIN_01.png" alt="logo DIGEA">
</h2>

# Manual de Usuario: Selección de Sitio para Nueva Gasolinera en Estación Central
<p>Desarrollo de Script para ejecutar procesos en una Base de Datos Espacial</p>
<p><strong>DyDAT_2s2024_C_PEP_2_FPV</strong></p>

## Resumen
Este manual describe el procedimiento para ejecutar un script SQL que emplea una base de datos espacial PostGIS con el objetivo de identificar los sitios eriazos más idóneos en la comuna de Estación Central para colocar una **GASOLINERA**. La selección de los sitios se realiza considerando criterios como la zonificación, la proximidad a gasolineras existentes, el área mínima requerida para su instalación y habitantes en el área de influencia del predio. A partir de estos factores, se genera un indicador que permite jerarquizar las mejores ubicaciones para la construcción de una nueva gasolinera.



---

## 1. Requisitos Previos

### 1.1. Software Necesario
Para ejecutar el script correctamente, asegúrese de tener instalados los siguientes programas y herramientas:

- **VS Code** con la extensión de Python (versión 2024.22.0 o superior).
- **PostgreSQL** (versión 13 o superior).
- **PostGIS** (extensión espacial habilitada en la base de datos).
- **pgAdmin 4** (interfaz gráfica para interactuar con la base de datos).

### 1.2. Configuración de la Base de Datos
- Asegúrese de que la base de datos esté configurada con **PostGIS** habilitado.
- Verifique que la extensión espacial esté instalada y activada en la base de datos con el siguiente comando:

  ```sql
  CREATE EXTENSION postgis;
## 2. Resumen del proceso completo
### Tablas Utilizadas en el Esquema "entradas"

- **`SITIOERIAZO_13106`**: Contiene información poligonal sobre los sitios eriazos de la comuna de Estación Central.
- **`PRC13106`**: Contiene el Plan Regulador Comunal de Estación Central, que define las zonas permitidas para la instalación de gasolineras.
- **`GASOLINERA`**: Contiene la ubicación de las gasolineras existentes en la comuna.
- **`MANZANA13106`**: Contiene datos demográficos a nivel de manzana, utilizados para calcular la población en el área de influencia.

### Pasos del Análisis

1. **Agregar Identificador Único a `SITIOERIAZO_13106`**:
   - Se agrega una columna `gid` como clave primaria de tipo SERIAL si no existe.

2. **Crear Tabla con Predios Eriazos en Zonas Permitidas (`PRC13106`)**:
   - Se crea la tabla `SITIO_ERIAZO_GEOPROCESO` en el esquema de `resultados` con los predios eriazos que intersectan con las zonas permitidas de acuerdo con la zonificación de `PRC13106`.

3. **Agregar Columna de Distancia a Gasolineras**:
   - Se añade la columna `distancia_gasolinera` en la tabla `SITIO_ERIAZO_GEOPROCESO`, que almacena la distancia mínima a las gasolineras existentes.

4. **Calcular la Distancia Mínima a Gasolineras**:
   - Se calcula y actualiza la columna `distancia_gasolinera` con la distancia mínima desde cada predio eriazo a las gasolineras existentes, en un radio de 10 km.

5. **Calcular el Área en km²**:
   - Se añade la columna `area_km2` a la tabla `SITIO_ERIAZO_GEOPROCESO`, calculando el área de cada predio en kilómetros cuadrados.

6. **Contar la Población en el Área de Influencia**:
   - Se crean buffers de 1.5 km alrededor de cada predio eriazo y se realiza un spatial join con las manzanas censales (`MANZANA13106`) para contar la población total en el área de influencia.

7. **Seleccionar los Sitios Eriazos Cumpliendo las Condiciones**:
   - Se crea una nueva tabla `SITIO_ERIAZO_SELECCIONADO` en el esquema de `resultados` con los predios que cumplen las condiciones de zonificación, área mínima, distancia a gasolinera y población total.

8. **Calcular la Normalización Min-Max**:
   - Se normalizan las columnas `area_km2`, `distancia_gasolinera` y `poblacion_total` mediante Min-Max normalization.

9. **Jerarquizar Según un Indicador**:
   - Se añade la columna `indicador` a la tabla `SITIO_ERIAZO_SELECCIONADO`, calculando un indicador ponderado con los siguientes pesos:
     - 40% para `area_km2_minmax`
     - 30% para `distancia_gasolinera_minmax`
     - 30% para `poblacion_total_minmax`

10. **Seleccionar los 10 Mejores Sitios Eriazos**:
    - Se seleccionan los 10 sitios eriazos con los valores más altos del `indicador`, ordenados de manera descendente.

Realizados todos los procesos anteriores, la tabla geografica queda almacenada en el esquema `resultados` con el nombre de `SITIO_ERIAZO_SELECCIONADO`

## 3. Instrucciones
### Paso 1: Configurar el servidor PostgreSQL
1. Abre **pgAdmin 4** y asegúrate de que el servidor PostgreSQL esté en ejecución.
2. Crea una base de datos llamada **PEP2** si aún no existe.

### Paso 2: Preparar el entorno del proyecto
1. Abre **Visual Studio Code (VSCode)** y carga la carpeta del proyecto:  
   `DyDAT_2s_2024_FPV_PEP2_Parte2`.
2. En la carpeta del proyecto, instala las librerías necesarias ejecutando el siguiente comando en la terminal:  
   ```bash
   pip install -r"./requeriments.txt"

### Paso 3: Configurar los parámetros de conexión
Abre el archivo Conexion.py y localiza las funciones conectar_bd() y crear_motor_sqlalchemy().
Modifica los parámetros según tu configuración:
```py
def conectar_bd():
    try:
        conexion = psycopg2.connect(
            dbname="PEP2", # Agregar Base de datos llamada PEP2 en pgAdmin 4
            user="postgres", 
            password="admin" #### Cambiar contraseña #####
        )
        print("Conexión a la base de datos exitosa")
        return conexion
    except Exception as e:
        print(f"Error al conectar a la base de datos: {e}")
        exit()
```
```py
from sqlalchemy import create_engine

def crear_motor_sqlalchemy(): 
    # ¡IMPORTANTE! Asegúrate de colocar la contraseña correcta en los caracteres ####Contraseña######
    try:
        motor = create_engine(
            "postgresql+psycopg2://postgres:####Contraseña######@localhost/PEP2"
        )
        return motor
    except Exception as e:
        print(f"Error al crear el motor de conexión SQLAlchemy: {e}")
        exit()
```
## 4. Arranque del Proyecto

### Ejecución de `Conexion.py`
El script `Conexion.py` se encarga de:

1. **Conectar a la base de datos en PostgreSQL**: Utiliza las credenciales configuradas previamente para establecer una conexión con la base de datos **PEP2**.
2. **Creación de esquemas**:
   - **`entradas`**: Contendrá los datos de entrada para el análisis.
   - **`resultados`**: Almacenará los resultados generados por los procesos SQL.
3. **Carga de archivos**: Los siguientes archivos shapefile (`.shp`) se cargan en el esquema `entradas` con sus respectivos campos de geometría:
   - **`SITIOERIAZO_13106`**: Información sobre sitios eriazos en la comuna de Estación Central.
   - **`PRC13106`**: Plan Regulador Comunal con datos de zonificación.
   - **`GASOLINERA`**: Ubicación de gasolineras existentes.
   - **`MANZANA13106`**: Información demográfica por manzana censal.

### Proceso SQL
El archivo `./CONSULTAS/GEOPROCESOS.sql` contiene todas las consultas necesarias para el análisis y procesamiento de los datos. Estas consultas realizan operaciones de geoprocesamiento, incluyendo:

1. Identificación y selección de sitios eriazos que cumplen con los criterios definidos.
2. Cálculo de indicadores espaciales y jerarquización de sitios.

### Resultados Generados
Al final del proceso, se obtendrán las siguientes tablas en el esquema `resultados`:
- **`SITIO_ERIAZO_GEOPROCESO`**: Contiene los sitios eriazos procesados con datos intermedios como área, distancia a gasolineras y población en el área de influencia.
- **`SITIO_ERIAZO_SELECCIONADO`**: Lista final de sitios eriazos seleccionados, jerarquizados según un indicador compuesto que evalúa su idoneidad para la instalación de una nueva gasolinera.


