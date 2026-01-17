# QIIME2 Atacama Soils Pipeline

Este repositorio contiene un **pipeline reproducible en Bash** para el análisis de datos metagenómicos con **QIIME2**, basado en la actividad de Secuenciación y Ómicas del máster de bioinformática*.

## Objetivo

El pipeline permite:

- Importar datos de secuenciación a QIIME2  
- Demultiplexar y filtrar secuencias  
- Realizar control de calidad y *denoising* con **DADA2**  
- Construir un árbol filogenético  
- Calcular diversidad alfa y beta  
- Realizar análisis taxonómico  
- Ejecutar análisis diferencial de abundancia con **ANCOM**

## Preparación
PAra poder ejecutar el script pipeline.sh, antes hay que crear el entorno de la siguiente manera:
conda create -n qiime2-2023.9 qiime2=2023.9
conda activate qiime2-2023.9
