import pandas as pd
import geopandas as gpd
import psycopg2
from sqlalchemy import create_engine
import geoalchemy2
import os

# 1. Configuración de Conexión a la Base de Datos
def conectar_bd():
    try:
        conexion = psycopg2.connect(
            dbname="PEP2", # Agregar Base de datos llamada PEP2 en pgAdmin
            user="postgres", 
            password="admin" #Cambiar contraseña
        )
        print("Conexión a la base de datos exitosa")
        return conexion
    except Exception as e:
        print(f"Error al conectar a la base de datos: {e}")
        exit()

# Crear el motor de SQLAlchemy para cargar datos
def crear_motor_sqlalchemy():
    try:
        motor = create_engine(
            "postgresql+psycopg2://postgres:admin@localhost/PEP2"
        )
        return motor
    except Exception as e:
        print(f"Error al crear el motor de conexión SQLAlchemy: {e}")
        exit()

# 2. Crear Esquemas en la Base de Datos
def crear_esquema(conexion, esquema):
    cursor = conexion.cursor()
    try:
        cursor.execute(f"CREATE SCHEMA IF NOT EXISTS {esquema};")
        conexion.commit()
        print(f"Esquema '{esquema}' creado correctamente")
    except Exception as e:
        print(f"Error al crear esquema: {e}")
    finally:
        cursor.close()

def habilitar_postgis(conexion):
    try:
        cursor = conexion.cursor()
        cursor.execute("CREATE EXTENSION IF NOT EXISTS postgis;")
        conexion.commit()
        print("Extensión PostGIS habilitada correctamente")
    except Exception as e:
        print(f"Error al habilitar la extensión PostGIS: {e}")
        conexion.rollback()

def poblar_datos_desde_shp(conexion, motor, archivo_shp, esquema, tabla):
    try:
        # Habilitar PostGIS
        habilitar_postgis(conexion)
        
        # Leer el shapefile usando geopandas
        gdf = gpd.read_file(archivo_shp, encoding='latin1')
        
        # Limpiar columnas y valores con caracteres problemáticos
        gdf.columns = gdf.columns.str.encode('latin1', 'ignore').str.decode('utf-8')
        for col in gdf.select_dtypes(include=['object']).columns:
            gdf[col] = gdf[col].str.encode('latin1', 'ignore').str.decode('utf-8')
        
        # Verificar el sistema de coordenadas
        if gdf.crs is None or gdf.crs.to_epsg() != 4326:
            print("Reproyectando datos a EPSG:4326")
            gdf = gdf.to_crs(epsg=4326)
        
        # Crear la tabla en la base de datos con SQLAlchemy
        nombre_tabla = f"{esquema}.{tabla}"
        print(f"Poblando datos en la tabla {nombre_tabla}...")
        gdf.to_postgis(name=tabla, con=motor, schema=esquema, if_exists='replace')
        print(f"Datos poblaron correctamente en la tabla {nombre_tabla}")
    except Exception as e:
        print(f"Error al poblar datos desde shapefile: {e}")

# 4. Ejecutar un Script SQL
def ejecutar_sql(conexion, ruta_sql):
    cursor = conexion.cursor()
    try:
        with open(ruta_sql, 'r', encoding='UTF8') as archivo_sql:
            script_sql = archivo_sql.read()
        cursor.execute(script_sql)
        conexion.commit()
        print(f"Script SQL '{ruta_sql}' ejecutado correctamente")
    except Exception as e:
        print(f"Error al ejecutar el script SQL '{ruta_sql}': {e}")
        conexion.rollback()
    finally:
        cursor.close()

# 5. Script Principal
def main():
    conexion = conectar_bd()
    motor = crear_motor_sqlalchemy()
    
    # Crear esquemas
    esquema_entrada = "entradas"
    esquema_resultados = "resultados"
    crear_esquema(conexion, esquema_entrada)
    crear_esquema(conexion, esquema_resultados)
    
    # Poblar datos desde un shapefile
    #PREDIOS
    sitioeriazo_shp = r"./PrediosEstacionCentral/SITIOERIAZO_13106.shp"
    poblar_datos_desde_shp(conexion, motor, sitioeriazo_shp, esquema_entrada, "SITIOERIAZO_13106")
    #PRC
    prc_shp = r"./PRC/PRC13106.shp" 
    poblar_datos_desde_shp(conexion, motor, prc_shp, esquema_entrada, "PRC13106")

    #GASOLINERA
    GASOLINERA_shp = r"./SERVICIO/GASOLINERA.shp"
    poblar_datos_desde_shp(conexion, motor, GASOLINERA_shp, esquema_entrada, "GASOLINERA")
    #MANZANA CENSO
    MANZANA_shp= r"./MANZANAS/MANZANA13106.shp"
    poblar_datos_desde_shp(conexion, motor, MANZANA_shp, esquema_entrada, "MANZANA13106")

    # Ejecutar script SQL
    ruta_sql = r"./CONSULTAS/GEOPROCESOS.sql"
    ejecutar_sql(conexion, ruta_sql)

    
    conexion.close()

if __name__ == "__main__":
    main()