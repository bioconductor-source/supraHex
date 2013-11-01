#' Function to overlay additional data onto the trained map for viewing the distribution of that additional data
#'
#' \code{sMapOverlay} is supposed to overlay additional data onto the trained map for viewing the distribution of that additional data. It returns an object of class "sMap". It is realized by first estimating the hit histogram weighted by the neighborhood kernel, and then calculating the distribution of the additional data over the map (similarly weighted by the neighborhood kernel). The final overlaid distribution of additional data is normalised by the hit histogram.
#'
#' @param sMap an object of class "sMap"
#' @param data a data frame or matrix of input data
#' @param additional a numeric vector or numeric matrix used to overlay onto the trained map. It must have the length (if being vector) or row number (if matrix) being equal to the number of rows in input data
#' @return 
#' an object of class "sMap", a list with following components:
#'  \item{nHex}{the total number of hexagons/rectanges in the grid}
#'  \item{xdim}{x-dimension of the grid}
#'  \item{ydim}{y-dimension of the grid}
#'  \item{lattice}{the grid lattice}
#'  \item{shape}{the grid shape}
#'  \item{coord}{a matrix of nHex x 2, with rows corresponding to the coordinates of all hexagons/rectangles in the 2D map grid}
#'  \item{init}{an initialisation method}
#'  \item{neighKernel}{the training neighborhood kernel}
#'  \item{codebook}{a codebook matrix of nHex x ncol(additional), with rows corresponding to overlaid vectors}
#'  \item{hits}{a vector of nHex, each element meaning that a hexagon/rectangle contains the number of input data vectors being hit wherein}
#'  \item{mqe}{the mean quantization error for the "best" BMH}
#'  \item{call}{the call that produced this result}
#' @note To ensure the unique placement, each component plane mapped to the "sheet"-shape grid with rectangular lattice is determinied iteratively in an order from the best matched to the next compromised one. If multiple compoments are hit in the same rectangular lattice, the worse one is always sacrificed by moving to the next best one till all components are placed somewhere exclusively on their own.
#' @export
#' @seealso \code{\link{sPipeline}}, \code{\link{sBMH}}, \code{\link{sHexDist}}, \code{\link{visHexMulComp}}
#' @include sMapOverlay.r
#' @examples
#' # 1) generate an iid normal random matrix of 100x10 
#' data <- matrix( rnorm(100*10,mean=0,sd=1), nrow=100, ncol=10)
#' colnames(data) <- paste(rep('S',10), seq(1:10), sep="")
#'
#' # 2) get trained using by default setup
#' sMap <- sPipeline(data=data)
#'
#' # 3) overlay additional data onto the trained map
#' # here using the first two columns of the input "data" as "additional"
#' # codebook in "sOverlay" is the same as the first two columns of codebook in "sMap"
#' sOverlay <- sMapOverlay(sMap=sMap, data=data, additional=data[,1:2])
#' 
#' # 4) viewing the distribution of that additional data
#' visHexMulComp(sOverlay)

sMapOverlay <- function(sMap, data, additional)
{
    
    ## checking sMap
    if (class(sMap) != "sMap"){
        stop("The funciton must apply to 'sMap' object.\n")
    }
    neighKernel <- sMap$neighKernel
    nHex <- sMap$nHex

    ## checking data    
    if (is.vector(data)){
        data <- matrix(data, nrow=1, ncol=length(data))
    }else if(is.matrix(data) | is.data.frame(data)){
        data <- as.matrix(data)
    }else if(is.null(data)){
        stop("The input data must be not NULL.\n")
    }
    dlen <- nrow(data)

    ## checking additional    
    failed <- F
    if (is.vector(additional)){
        if(length(additional)==dlen){
            additional <- matrix(additional, nrow=length(additional), ncol=1)
        }else{
            failed <- T
        }
    }else if(is.matrix(additional) | is.data.frame(additional)){
        if(nrow(additional)==dlen){
            additional <- as.matrix(additional)
        }else{
            failed <- T
        }
    }else if(is.null(additional)){
        failed <- T
    }
    if(failed){
        stop("The input 'additional' must have the same rows/length as the input 'data'.\n")
    }
    if(!is.numeric(additional) | sum(is.na(additional))>0){
        stop("The input 'additional' must have only numeric values.\n")
    }
    
    ##################################################
    ## distances between hexagons/rectangles in a grid
    Ud <- sHexDist(sObj=sMap)
    Ud <- Ud^2 ## squared Ud (see notes radius below)
    
    ## identify the best-matching hexagons/rectangles (BMH) for the input data
    radius <- 1 ## always 1
    radius <- radius^2
    response <- sBMH(sMap=sMap, data=data, which_bmh="best")
    bmh <- response$bmh
    hits <- sapply(seq(1,sMap$nHex), function(x) sum(response$bmh==x))

    ## neighborhood kernel and radius
    ## notice: Ud and radius have been squared
    if(neighKernel == "bubble"){
        H <- (Ud <= radius)
    }else if(neighKernel == "gaussian"){
        H <- exp(-Ud/(2*radius))
    }else if(neighKernel == "cutgaussian"){
        H <- exp(-Ud/(2*radius)) * (Ud <= radius)
    }else if(neighKernel == "ep"){
        H <- (1-Ud/radius) * (Ud <= radius)
    }else if(neighKernel == "gamma"){
        H <- 1/gamma(Ud/(4*radius) +1+1)
    }
    Hi <- H[,bmh] # nHex X dlen to store the prob. of each data hitting the map

    ## overlay additional to the trained sMap
    ## It already takes into account the distribution of the input data in the trained sMap
    addtional_hits <- Hi %*% additional
    data_hits <- H %*% hits
    new <- matrix(0, nrow=nHex, ncol=ncol(additional))
    cnames <- colnames(additional)
    if(is.null(cnames)){
        cnames <- seq(1,ncol(additional))
    }
    colnames(new) <- cnames
    for(i in 1:ncol(additional)){
        new[,i] <- addtional_hits[,i]/data_hits
    }

    ######################################################################################
    
    sOverlay <- list(  nHex = sMap$nHex, 
                   xdim = sMap$xdim, 
                   ydim = sMap$ydim,
                   lattice = sMap$lattice,
                   shape = sMap$shape,
                   coord = sMap$coord,
                   init = sMap$init,
                   neighKernel = sMap$neighKernel,
                   codebook = new,
                   hits = hits,
                   mqe = response$mqe,
                   call = match.call(),
                   method = "suprahex")
    
    class(sOverlay) <- "sMap"
    
    invisible(sOverlay)
    
}