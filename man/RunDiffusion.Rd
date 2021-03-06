% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/RunDiffusion.R
\name{RunDiffusion}
\alias{RunDiffusion}
\title{Run Diffusion map}
\usage{
RunDiffusion(
  object,
  dims = 1:5,
  reduction = "pca",
  features = NULL,
  max.dim = 3L,
  sigma = "local",
  distance = "euclidean",
  reduction.name = "dm",
  reduction.key = "DM_",
  ...
)
}
\arguments{
\item{object}{Seurat object}

\item{dims}{number of dimensions}

\item{reduction}{reductionm method. Defaults to pca}

\item{features}{vector of gene names}

\item{max.dim}{maximum dimensions}

\item{sigma}{Diffusion scale parameter of the Gaussian kernel. One of 'local', 'global', a (numeric) global sigma or a Sigmas object. When choosing 'global', a global sigma will be calculated using find_sigmas. (Optional. default: 'local') A larger sigma might be necessary if the eigenvalues can not be found because of a singularity in the matrix}

\item{distance}{Distance measurement method applied to data or a distance matrix/dist. For the allowed values, see find_knn. If this is a sparseMatrix, zeros are interpreted as "not a close neighbors", which allows the use of kNN-sparsified matrices (see the return value of find_knn.}

\item{reduction.name}{Dimension Reduction method}

\item{reduction.key}{Dimension Reduction key}
}
\description{
Run Diffusion map
}
