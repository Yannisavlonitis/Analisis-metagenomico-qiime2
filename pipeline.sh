#!/usr/bin/env bash
# ============================================================
# PIPELINE QIIME2 - ATACAMA SOILS (2023.9)
# Flujo de trabajo reproducible en Bash
# OJO: para poder ejecutarlo, hay que utilizar el comando "chmod u+x pipeline.sh" o "chmod 100 pipeline.sh" :)
# ============================================================

set -e  # Detiene el script si ocurre un error

# ------------------------------
# PASO 1: Preparar entorno y descargar datos
# ------------------------------
mkdir -p qiime2-atacama # Crear el directorio de trabajo
cd qiime2-atacama

echo "Descargando metadatos..."
wget -O sample-metadata.tsv \
https://data.qiime2.org/2023.9/tutorials/atacama-soils/sample_metadata.tsv

echo "Descargando secuencias..."
mkdir -p emp-paired-end-sequences

wget -O emp-paired-end-sequences/forward.fastq.gz \
https://data.qiime2.org/2023.9/tutorials/atacama-soils/10p/forward.fastq.gz

wget -O emp-paired-end-sequences/reverse.fastq.gz \
https://data.qiime2.org/2023.9/tutorials/atacama-soils/10p/reverse.fastq.gz

wget -O emp-paired-end-sequences/barcodes.fastq.gz \
https://data.qiime2.org/2023.9/tutorials/atacama-soils/10p/barcodes.fastq.gz

# ------------------------------
# PASO 2: Importar datos en QIIME2
# ------------------------------
echo "Importando secuencias a QIIME2..."
qiime tools import \
  --type EMPPairedEndSequences \
  --input-path emp-paired-end-sequences \
  --output-path emp-paired-end-sequences.qza

# ------------------------------
# PASO 3: Demultiplexado
# ------------------------------
echo "Demultiplexando secuencias..."
qiime demux emp-paired \
  --m-barcodes-file sample-metadata.tsv \
  --m-barcodes-column barcode-sequence \
  --p-rev-comp-mapping-barcodes \
  --i-seqs emp-paired-end-sequences.qza \
  --o-per-sample-sequences demux-full.qza \
  --o-error-correction-details demux-details.qza

# ------------------------------
# PASO 4: Submuestreo (30%)
# ------------------------------
echo "Submuestreando el 30% de las lecturas..."
qiime demux subsample-paired \
  --i-sequences demux-full.qza \
  --p-fraction 0.3 \
  --o-subsampled-sequences demux-subsample.qza

qiime demux summarize \
  --i-data demux-subsample.qza \
  --o-visualization demux-subsample.qzv

# ------------------------------
# PASO 5: Filtrar muestras con < 100 reads
# ------------------------------
echo "Filtrando muestras con menos de 100 lecturas..."
mkdir -p demux-subsample

qiime tools export \
  --input-path demux-subsample.qzv \
  --output-path demux-subsample/

qiime demux filter-samples \
  --i-demux demux-subsample.qza \
  --m-metadata-file demux-subsample/per-sample-fastq-counts.tsv \
  --p-where 'CAST([forward sequence count] AS INT) > 100' \
  --o-filtered-demux demux.qza

# ------------------------------
# PASO 6: Denoising con DADA2
# ------------------------------
echo "Ejecutando DADA2..."
qiime dada2 denoise-paired \
  --i-demultiplexed-seqs demux.qza \
  --p-trim-left-f 13 \
  --p-trim-left-r 13 \
  --p-trunc-len-f 150 \
  --p-trunc-len-r 150 \
  --o-table table.qza \
  --o-representative-sequences rep-seqs.qza \
  --o-denoising-stats denoising-stats.qza

qiime feature-table summarize \
  --i-table table.qza \
  --o-visualization table.qzv \
  --m-sample-metadata-file sample-metadata.tsv

qiime feature-table tabulate-seqs \
  --i-data rep-seqs.qza \
  --o-visualization rep-seqs.qzv

qiime metadata tabulate \
  --m-input-file denoising-stats.qza \
  --o-visualization denoising-stats.qzv

# ------------------------------
# PASO 7: Árbol filogenético
# ------------------------------
echo "Construyendo árbol filogenético..."
qiime phylogeny align-to-tree-mafft-fasttree \
  --i-sequences rep-seqs.qza \
  --o-alignment aligned-rep-seqs.qza \
  --o-masked-alignment masked-aligned-rep-seqs.qza \
  --o-tree unrooted-tree.qza \
  --o-rooted-tree rooted-tree.qza

mkdir -p visualizacion
qiime tools export \
  --input-path rooted-tree.qza \
  --output-path visualizacion/

# ------------------------------
# PASO 8: Diversidad alfa y beta
# ------------------------------
echo "Calculando métricas de diversidad (profundidad = 47)..." # Puedes cambiar la profundidad 
qiime diversity core-metrics-phylogenetic \
  --i-phylogeny rooted-tree.qza \
  --i-table table.qza \
  --p-sampling-depth 47 \
  --m-metadata-file sample-metadata.tsv \
  --output-dir core-metrics-results

qiime diversity alpha-group-significance \
  --i-alpha-diversity core-metrics-results/faith_pd_vector.qza \
  --m-metadata-file sample-metadata.tsv \
  --o-visualization core-metrics-results/faith-pd-group-significance.qzv

qiime diversity beta-group-significance \
  --i-distance-matrix core-metrics-results/unweighted_unifrac_distance_matrix.qza \
  --m-metadata-file sample-metadata.tsv \
  --m-metadata-column transect-name \
  --o-visualization core-metrics-results/unweighted-unifrac-transect-name-significance.qzv \
  --p-pairwise

qiime emperor plot \
  --i-pcoa core-metrics-results/unweighted_unifrac_pcoa_results.qza \
  --m-metadata-file sample-metadata.tsv \
  --p-custom-axes depth \
  --o-visualization core-metrics-results/unweighted-unifrac-emperor-depth.qzv

# ------------------------------
# PASO 9: Clasificación taxonómica
# ------------------------------
echo "Descargando clasificador Greengenes..."
wget -O gg-13-8-99-515-806-nb-classifier.qza \
https://data.qiime2.org/2023.9/common/gg-13-8-99-515-806-nb-classifier.qza

echo "Clasificando taxonomía..."
qiime feature-classifier classify-sklearn \
  --i-classifier gg-13-8-99-515-806-nb-classifier.qza \
  --i-reads rep-seqs.qza \
  --o-classification taxonomy.qza

qiime metadata tabulate \
  --m-input-file taxonomy.qza \
  --o-visualization taxonomy.qzv

qiime taxa barplot \
  --i-table table.qza \
  --i-taxonomy taxonomy.qza \
  --m-metadata-file sample-metadata.tsv \
  --o-visualization taxa-bar-plots.qzv

# ------------------------------
# PASO 10: ANCOM (abundancia diferencial)
# ------------------------------
echo "Ejecutando ANCOM..."
qiime composition add-pseudocount \
  --i-table table.qza \
  --o-composition-table comp-table.qza

qiime composition ancom \
  --i-table comp-table.qza \
  --m-metadata-file sample-metadata.tsv \
  --m-metadata-column extract-group-no \
  --o-visualization ancom-extract-group-no.qzv

qiime taxa collapse \
  --i-table table.qza \
  --i-taxonomy taxonomy.qza \
  --p-level 6 \
  --o-collapsed-table table-l6.qza

qiime composition add-pseudocount \
  --i-table table-l6.qza \
  --o-composition-table comp-table-l6.qza

qiime composition ancom \
  --i-table comp-table-l6.qza \
  --m-metadata-file sample-metadata.tsv \
  --m-metadata-column extract-group-no \
  --o-visualization l6-ancom-extract-group-no.qzv
