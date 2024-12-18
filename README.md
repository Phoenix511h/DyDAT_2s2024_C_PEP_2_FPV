<h2 align="center">
  <img width="200" src="https://upload.wikimedia.org/wikipedia/commons/d/d9/Usach_P1.png" alt="logo Usach" >
  <img width="500" src="https://www.digea.usach.cl/digea/site/artic/20230110/imag/foto_0000000620230110165150/LOGO_DIGEA_MAIN_01.png" alt="logo DIGEA">
</h2>

# Manual de Usuario: Selección de Sitio para Nueva Gasolinera en Estación Central
<p>Desarrollo de Script para ejecutar procesos en una Base de Datos Espacial</p>
<p><strong>DyDAT_2s2024_C_PEP_2_FPV</strong></p>

## Resumen
Este manual describe el procedimiento para ejecutar un script SQL que emplea una base de datos espacial PostGIS con el objetivo de identificar los sitios eriazos más idóneos en la comuna de Estación Central. La selección de los sitios se realiza considerando criterios como la zonificación, la proximidad a gasolineras existentes, el área mínima requerida para su instalación y habitantes en el área de influencia del predio. A partir de estos factores, se genera un indicador que permite jerarquizar las mejores ubicaciones para la construcción de una nueva gasolinera.



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

  ## 3. Tablas Necesarias en la Base de Datos

## 3. Tablas Ingresadas en la Base de Datos en el Esquema "entrada"

### `SITIOERIAZO_13106`
Contiene los polígonos correspondientes a los sitios eriazos ubicados en la comuna de Estación Central.
### `PRC13106`
Incluye el Plan Regulador Comunal de Estación Central, proporcionando información sobre la zonificación de uso de suelo en la comuna.
### `GASOLINERA`
Almacena la ubicación geográfica de las gasolineras existentes en la comuna de Estación Central.
### `MANZANA13106`
Contiene datos demográficos a nivel de manzana, basados en el censo, ofreciendo información relevante sobre la población en cada manzana de la comuna.



