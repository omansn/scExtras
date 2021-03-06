#'run Slingshot
#' @param object Seurat object
#' @param sds.name Name in hte Misc slot to save the Slingshot object
#' @param group,by groups
#' @param reduction Reduction method. Default is 'dm'
#' @param start.clus start cluster
#' @param end.clus end cluster
#' @param approx_points
#' @param allow.breaks logical, determines whether curves that branch very close to the origin should be allowed to have different starting points.
#' @param extend acter, how to handle root and leaf clusters of lineages when constructing the initial, piece-wise linear curve. Accepted values are 'y' (default), 'n', and 'pc1'. See 'Details' for more.
#' @param stretch numeric factor by which curves can be extrapolated beyond endpoints. Default is 2, see principal_curve.
#' @import dplyr tidyr Seurat slingshot
#' @export
#'
runSlingshot  <- function(object,sds.name='sds',reduction='dm',group.by=NULL, start.clus=NULL,end.clus=NULL, approx_points = FALSE, allow.breaks=TRUE, extend='n',stretch=0){
  rd <- Embeddings(object,reduction)

  #Set ident to groupby option
  if(!is.null(group.by)){
      Idents(object)<- group.by
  }

  cl <- Idents(object = object)
  ### Need to fix this not working
  #group.by <- group.by %||% 'ident'
  #cl <- FetchData(object = object, vars = group.by) %>% pull(`group.by`)

  object@misc[[sds.name]] <-  list("dr"=reduction,"data"=slingshot(rd,cl,start.clus=start.clus,end.clus=end.clus,approx_points=approx_points,allow.breaks=allow.breaks,extend=extend,stretch=stretch))
  #ps <- slingPseudotime(object@misc[['sds']]$data)
  #object@meta.data[,colnames(ps)] <- as.data.frame(ps)
  object <- LogSeuratCommand(object = object)
  return(object)
}

#'run Psuedotime Diff Expression
#' @param object Seurat object
#' @import dplyr tidyr Seurat gam
#' @export
#'
runPseudoTimeDGE <- function(object){
  var <- VariableFeatures(scrna)

  DGE <- list()
  for(c in names(object@misc$sds$data@curves)){
    object@misc$sds$dge[[c]] <- FetchData(object,append(var, c,0)) %>% tidyr::gather(gene,signal, -one_of(c)) %>% dplyr::rename(curve = 1) %>%
      tidyr::nest(-gene) %>%
      mutate(
        fit = purrr::map(data, ~ gam::gam(signal ~ lo(curve), data = .x)),
        tidied = purrr::map(fit, tidy)
      ) %>%
      tidyr::unnest(tidied) %>%
      filter(term !='Residuals')
  }
  object <- LogSeuratCommand(object = object)
  return(object)

}

#'CurvePlot Plot Slingshot Curves
#' @param object Seurat object
#' @param sds Slingshot Data object
#' @param group.by variable to group by
#' @param reduction Which dimensionality reduction to use, default UMAP
#' @param lineage Linage to plot or all to plot all lineages
#' @param dims Dimensions to plot, must be a two-length numeric vector specifying x- and y-dimensions
#' @param cols Color palette
#' @param label Label plots
#' @import dplyr tidyr Seurat ggplot2
#' @export
#'
CurvePlot = function(object,
                     sds = NULL,
                     group.by = NULL,
                     reduction = 'umap',
                     lineage='all',
                     dims = 1:2,
                     cols = NULL,
                     label = T) {

  object[['ident']] <- Idents(object = object)
  group.by <- group.by %||% 'ident'
  dims <- paste0(Key(object = object[[reduction]]), dims)

  if (lineage == 'all') {
    curved <-
      bind_rows(lapply(names(slingCurves(sds)), function(x) {
        c <- slingCurves(sds)[[x]]
        d <- as.data.frame(c$s[c$ord, dims])
        d$curve <- x
        return(d)
      }))

  } else{
    curve <- gsub('lineage','curve',lineage)
    c <- slingCurves(sds)[[curve]]
    curved <- as.data.frame(c$s[c$ord, dims])
    curved$curve <- lineage
  }



  DimPlot(object,cols=cols,label = label,group.by = group.by,reduction = reduction) +
    geom_path(aes_string(dims[1], dims[2], linetype = "curve"), curved, size =1)
}

#'CurvePlot Plot Slingshot Curves
#' @param object Seurat object
#' @param sds Slingshot Data object
#' @param reduction Which dimensionality reduction to use, default UMAP
#' @param dims Dimensions to plot, must be a two-length numeric vector specifying x- and y-dimensions
#' @param cols Color palette
#' @param group.by Cluster variable used in slingshot
#' @import dplyr tidyr Seurat ggplot2
#' @export
#'
LineageFeaturePlot <- function(object,sds,lineage='lineage1', reduction='umap',dims=1:2,cols='RdYlBu', group.by=NULL){
    qlineage <- quo(lineage)
    group.by<- sym(group.by)
    #group.by <- group.by %||% 'ident'
    if (is.null(x = group.by)) {
      stop("Please Enter the variable that was used to define groups in Slingshot, ie var_celltype, var_cluster etc.")
    }


    curve <- gsub('lineage','curve',lineage)
    clusterinlineage <- slingLineages(sds)[[stringr::str_to_title(lineage)]]

    object[['pseudotime']] <-
    slingPseudotime(sds, na = FALSE) %>% as.data.frame(.) %>%
      rownames_to_column('cellid') %>%
      setNames(gsub("curve", "lineage", names(.))) %>%
      left_join(object@meta.data %>% rownames_to_column('cellid'),.) %>%
      rename(pseudotime = !!qlineage) %>%
      mutate(pseudotime=ifelse(!!group.by %in% clusterinlineage,pseudotime,NA ))%>%
      pull(pseudotime)

    dims <- paste0(Key(object = object[[reduction]]), dims)

    # curved <-
    #   bind_rows(lapply(names(slingCurves(sds)), function(x) {
    #     c <- slingCurves(sds)[[x]]
    #     d <- as.data.frame(c$s[c$ord, dims])
    #     d$curve <- x
    #     return(d)
    #   }))
    #


    c <- slingCurves(sds)[[curve]]
    curved <- as.data.frame(c$s[c$ord, dims])
    curved$curve <- lineage


    FeaturePlot(object,features = 'pseudotime',order = T) +
      scale_color_distiller(palette = cols,  na.value = 'grey90') +
      geom_path(aes_string(dims[1], dims[2], linetype = "curve"), curved, size =1) +
      ggtitle(lineage) +
      coord_equal() + ggplot2::theme_void()

  }



#'Plot heatmap of the pseudotime data
#' @param object Seurat object
#' @param sdsname Name of Slingshot object stored in Seurat Object
#' @param features Vector of genes to be plotted
#' @param lineage THe linage to be plotted such as lineage1
#' @param col Color palette, this vector needs to have the names be the cell types or cluster names
#' @param group.by Cluster variable used in slingshot
#' @import dplyr Seurat
#' @export
#'
plotLineageHeatMap <- function(object,sdsname,features,lineage='lineage1',col, group.by=NULL){
  if (is.null(x = group.by)) {
    stop("Please Enter the variable that was used to define groups in Slingshot, ie var_celltype, var_cluster etc.")
  }

  ## Maybe add curve is user puts in integer

  sds <- object@misc[[sdsname]]$data
  clusterinlineage <- slingLineages(sds)[[stringr::str_to_title(lineage)]]
  ### Should add a check for lineages in model
  group.by <- sym(group.by)
  qlineage <- quo(lineage)

  cells <- inner_join(
    slingCurveWeights(sds,as.probs=T) %>% as.data.frame() %>%
      setNames(gsub('curve','lineage',names(.))) %>%
      rownames_to_column('cellid') %>%
      gather(curve,w,-cellid) %>%
      group_by(cellid) %>%
      top_n(n=1,wt=w) %>%
      filter(curve==!!lineage),
    slingPseudotime(sds) %>% as.data.frame %>%
      setNames(gsub('curve','lineage',names(.))) %>%
      rownames_to_column('cellid') %>%
      select(cellid,!!qlineage) %>%
      dplyr::rename('time'=lineage)
  ) %>% arrange(time) %>%
    inner_join(., object@meta.data %>% rownames_to_column('cellid')) %>%
    filter(!!group.by %in% clusterinlineage) %>%
    mutate(group_by=factor(group.by,levels=clusterinlineage))

  data <- FetchData(object=object, vars=features,cells=cells$cellid) %>% t(.)
  mat_scaled = t(scale(t(data)))

  f1=circlize::colorRamp2(c(-2,0,2), c('skyblue1', "grey10","yellow"))


  col_fun =circlize::colorRamp2(c(0, 20), c("blue", "red"))

  ha = HeatmapAnnotation(
    #pseudotime=anno_lines(cells$time),
    pseudotime=anno_barplot(cells$time, gp = gpar(col = "#296EFA"),border = F,bar_width = 1),
    celltype = cells %>% pull(group.by),
    col = list(celltype = col
    ))

  ht <- Heatmap(mat_scaled,
                 col=f1,
                 show_row_dend = F,
                 row_names_side='left',
                 show_column_names = F,
                 cluster_columns = F,
                 cluster_rows = F,
                 top_annotation = ha
  )
  return(ht)



}



#'Create feature plots of genes
#' @param object Seurat object
#' @param curve curve to be plotted
#' @param reduction Reduction method. Default is 'dm'
#' @param n number of genes to plot. Default is 25
#' @import dplyr tidyr Seurat
#' @export
#'
plotCurveDGEgenes <- function(object=NULL,curve=NULL,n=25,reduction='dm'){
  genes = object@misc$sds$dge[[curve]] %>% arrange(p.value) %>% head(n) %>% pull(gene)
  plot_grid(  plotlist = FeaturePlot(scrna,genes,reduction = reduction,cols = c('grey','purple')))

}

