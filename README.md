# Frubis-Lead-Segmentation-Clustering---R
Mini proyecto de segmentación de leads B2B usando K-Means en R.
# Frubis Lead Segmentation (Clustering) - R

Mini proyecto de segmentación de leads B2B usando K-Means en R.
La segmentación se basa en señales de interés por servicios típicos de una agencia de performance (CRO, Email/SMS, Media Activation, etc.)
y genera clusters accionables + "next best service" por segmento.

## Qué incluye
- Generación de dataset sintético (para demo)
- Escalado de features
- Selección de K (Elbow + Silhouette)
- K-means + visualización (PCA)
- Perfilado de clusters + naming
- Export: CSV + PNGs

## Requisitos
- R + RStudio
- Paquetes:
  - tidyverse, factoextra, cluster, scales

Instalación:
```r
install.packages(c("tidyverse","factoextra","cluster","scales"))
