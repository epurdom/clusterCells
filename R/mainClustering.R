#' @title Cluster distance matrix from subsampling
#'   
#' @description Given input data, this function will try to find the clusters
#'   based on the given ClusterFunction object.
#' @name mainClustering
#'   
#' @param orderBy how to order the cluster (either by size or by maximum alpha 
#'   value). If orderBy="size" the numbering of the clusters are reordered by 
#'   the size of the cluster, instead of by the internal ordering of the 
#'   \code{clusterFUN} defined in the \code{ClusterFunction} object (an internal
#'   ordering is only possible if slot \code{outputType} of the
#'   \code{ClusterFunction} is \code{"list"}).
#' @param minSize the minimum number of samples in a cluster. Clusters found 
#'   below this size will be discarded and samples in the cluster will be given 
#'   a cluster assignment of "-1" to indicate that they were not clustered.
#' @param format whether to return a list of indices in a cluster or a vector of
#'   clustering assignments. List is mainly for compatibility with sequential 
#'   part.
#' @param clusterArgs arguments to be passed directly to the \code{clusterFUN}
#'   slot of the \code{ClusterFunction} object
#' @param warnings logical as to whether should give warning if arguments given
#'   that don't match clustering choices given. Otherwise, inapplicable 
#'   arguments will be ignored without warning.
#' @param returnData logical as to whether to return the \code{diss} or \code{x}
#'   matrix in the output. If \code{FALSE} only the clustering vector is
#'   returned.
#' @param ... arguments passed to the post-processing steps of the clustering.
#'   The available post-processing arguments for a \code{ClusterFunction} object
#'   depend on it's algorithm type and can be found by calling
#'   \code{getPostProcessingArgs}. See details below for documentation.
#' @inheritParams subsampleClustering
#' @inheritParams clusterSingle
#' @details \code{mainClustering} is not meant to be called by the user. It is
#'   only an exported function so as to be able to clearly document the
#'   arguments for \code{mainClustering} which can be passed via the argument
#'   \code{mainClusterArgs} in functions like \code{\link{clusterSingle}} and
#'   \code{\link{clusterMany}}.
#'   
#' @return If \code{returnData=FALSE}, mainClustering returns a vector of cluster assignments (if
#'   format="vector") or a list of indices for each cluster (if format="list").
#'   Clusters less than minSize are removed. If \code{returnData=TRUE}, then mainClustering returns a list
#' \itemize{
#' \item{results}{The clusterings of each sample.}
#' \item{inputMatrix}{The input matrix given to argument \code{inputMatrix}. Useful if input is result of subsampling, in which case input is the set of clusterings found over subsampling.}
#' }
#'
#' @examples
#' data(simData)
#' cl1<-mainClustering(inputMatrix=simData, inputType="X", 
#'     clusterFunction="pam",clusterArgs=list(k=3))
#' #supply a dissimilarity, use algorithm type "01"
#' diss<-as.matrix(dist(t(simData),method="manhattan"))
#' cl2<-mainClustering(diss, inputType="diss", clusterFunction="hierarchical01",
#'     clusterArgs=list(alpha=.1))
#' cl3<-mainClustering(inputMatrix=diss, inputType="diss", clusterFunction="pam",
#'     clusterArgs=list(k=3))
#' 
#' # run hierarchical method for finding blocks, with method of evaluating
#' # coherence of block set to evalClusterMethod="average", and the hierarchical
#' # clustering using single linkage:
#' # (clustering function requires type 'diss'),
#' clustSubHier <- mainClustering(diss, inputType="diss",
#'     clusterFunction="hierarchical01", minSize=5,
#'     clusterArgs=list(alpha=0.1,evalClusterMethod="average", method="single"))
#'
#' #post-process results of pam -- must pass diss for silhouette calculation
#' clustSubPamK <- mainClustering(simData, inputType="X", clusterFunction="pam", 
#'     silCutoff=0, minSize=5, diss=diss, removeSil=TRUE, clusterArgs=list(k=3))
#' clustSubPamBestK <- mainClustering(simData, inputType="X", clusterFunction="pam", silCutoff=0,
#'     minSize=5, diss=diss, removeSil=TRUE, findBestK=TRUE, kRange=2:10)
#'
#' # note that passing the wrong arguments for an algorithm results in warnings
#' # (which can be turned off with warnings=FALSE)
#' clustSubTight_test <- mainClustering(diss, inputType="diss", 
#'    clusterFunction="tight", 
#'    clusterArgs=list(alpha=0.1), minSize=5, removeSil=TRUE)
#' clustSubTight_test2 <- mainClustering(diss, inputType="diss",
#'    clusterFunction="tight",
#'    clusterArgs=list(alpha=0.1,evalClusterMethod="average"))
#' @rdname mainClustering
#' @aliases mainClustering,character-method
#' @export
setMethod(
    f = "mainClustering",
    signature = signature(clusterFunction = "character"),
    definition = function(clusterFunction,...){
        mainClustering(getBuiltInFunction(clusterFunction),...)
        
    }
)
#' @rdname mainClustering
#' @export
setMethod(
    f = "mainClustering",
    signature = signature(clusterFunction = "ClusterFunction"),
    definition=function(clusterFunction,inputMatrix, inputType,
                        clusterArgs=NULL,
                        minSize=1, 
                        orderBy=c("size","best"),
                        format=c("vector","list"),
                        returnData=FALSE,
												warnings=TRUE,...){
        if(missing(inputType)) stop("Internal error: inputType was not passed to mainClustering step")
        orderBy<-match.arg(orderBy)
        format<-match.arg(format)
        #######################
        ### Check arguments.
        #######################
        postProcessArgs<-list(...)
        # remove those based added by checkArgs
        # from clusterMany/clusterSingle/seqCluster
		if("doKPostProcess" %in% names(postProcessArgs)) 
            postProcessArgs <- postProcessArgs[-grep("doKPostProcess", names(postProcessArgs))]
        mainArgs<-c(list(clusterFunction=clusterFunction,
                         clusterArgs=clusterArgs,
                         minSize=minSize, orderBy=orderBy,
						 extraArguments=names(postProcessArgs),
                         format=format),postProcessArgs)
        checkOut<-.checkArgs(inputType=inputType, main=TRUE, subsample=FALSE, sequential=FALSE, mainClusterArgs=mainArgs, subsampleArgs=NULL,warn=warnings)		
        if(is.character(checkOut)) stop(checkOut)
		mainClusterArgs<-checkOut$mainClusterArgs
		inputType<-mainClusterArgs[["inputType"]]
        doKPostProcess<-mainClusterArgs[["doKPostProcess"]]
        clusterFunction=mainClusterArgs[["clusterFunction"]]
        clusterArgs=mainClusterArgs[["clusterArgs"]]
        minSize=mainClusterArgs[["minSize"]] 
        orderBy=mainClusterArgs[["orderBy"]]
        format=mainClusterArgs[["format"]]
        postProcessArgs=mainClusterArgs[mainClusterArgs[["extraArguments"]]]
        
        #######################
        ####Run clustering:
        #######################
        N <- dim(inputMatrix)[2]
        argsClusterList<-c(clusterArgs, list("cluster.only"=TRUE,
					inputMatrix=inputMatrix,inputType=inputType))
        # if(doKPostProcess & inputType!="diss") stop("Cannot do the post-processing (findBestK or remove due to silhouette score) without input Matrix that is dissimilarity.")
        if(doKPostProcess) {
            res<-do.call(".postProcessClusterK", c(list(clusterFunction=clusterFunction, clusterArgs=argsClusterList, N=N, orderBy=orderBy), postProcessArgs))
            ###Note to self: .postProcessClusterK returns clusters in list form.
        }
        else{
            res<-do.call(clusterFunction@clusterFUN,argsClusterList)
        }
        
        #######################
        #Now format into desired output, order
        #######################
        ## FIXME: need to get rid of this, unless needed/requested (though it is requested by sequential)
        #this is perhaps not efficient. For now will do this, then consider going back and only converting when, where needed.
        if(clusterFunction@outputType=="vector" & !doKPostProcess){
            res<-.clusterVectorToList(res)
        }
        clusterSize<-sapply(res, length)
        if(length(res)>0) res <- res[clusterSize>=minSize]
        if(length(res)!=0 & orderBy=="size"){ #i.e. there exist clusters found that passed minSize
            clusterSize<-sapply(res, length) #redo because dropped small clusters earlier
            res <- res[order(clusterSize,decreasing=TRUE)]
        }
        if(format=="vector"){
            res<-.clusterListToVector(res,N)
			#FIXME can't I take colnames of a diss too?
            names(res)<-if(inputType!="diss") colnames(inputMatrix) else rownames(inputMatrix)
        }
        if(!returnData) return(res)
        else return(list(results=res,inputMatrix=inputMatrix))
    }
)



#' @rdname mainClustering
#' @aliases getPostProcessingArgs
#' @details Post-processing Arguments: For post-processing the clustering,
#'   currently only type 'K' algorithms have a defined post-processing.
#'   Specifically
#' \itemize{
#'  \item{"findBestK"}{logical, whether should find best K based on average
#'   silhouette width (only used if clusterFunction of type "K").}
#'  \item{"kRange"}{vector of integers to try for k values if findBestK=TRUE. If
#'  \code{k} is given in \code{clusterArgs}, then default is k-2 to k+20,
#'  subject to those values being greater than 2; if not the default is
#'  \code{2:20}. Note that default values depend on the input k, so running for
#'  different choices of k and findBestK=TRUE can give different answers unless
#'  kRange is set to be the same.}
#'  \item{"removeSil"}{logical as to whether remove the assignment of a sample
#'  to a cluster when the sample's silhouette value is less than
#'  \code{silCutoff}}
#'  \item{"silCutoff"}{Cutoff on the minimum silhouette width to be included in
#'   cluster (only used if removeSil=TRUE).}
#' }
#' @export
setMethod(
    f = "getPostProcessingArgs",
    signature = c("ClusterFunction"),
    definition = function(clusterFunction) {
        switch(algorithmType(clusterFunction),"01"=.argsPostCluster01,"K"=.argsPostClusterK)
    }
)

### Provide the post-processing args that can be provided by user
.argsPostCluster01<-c("")
.argsPostClusterK<-c("findBestK","kRange","removeSil","silCutoff","diss")

#' @importFrom cluster silhouette
.postProcessClusterK<-function(clusterFunction,findBestK=FALSE,  kRange,removeSil=FALSE,silCutoff=0,diss=NULL,clusterArgs,N,orderBy)
{
    if(is.null(diss)){
        if(clusterArgs[["inputType"]]!="diss") stop("Internal error: ran post-processing without a dissimilarity matrix being provided")
    }
    k<-clusterArgs[["k"]]
    if(!findBestK && is.null(k)) stop("If findBestK=FALSE, must provide k")
    if(!is.null(k)) clusterArgs<-clusterArgs[-which(names(clusterArgs)=="k")]
    if(findBestK){
        if(missing(kRange)){
            if(!is.null(k)) kRange<-(k-2):(k+20)
            else kRange<-2:20
        }
        if(any(kRange<2)){
            kRange<-kRange[kRange>=2]
            if(length(kRange)==0) stop("Undefined values for kRange; must be greater than or equal to 2")
        }
        ks<-kRange 
    }
    else ks<-k
    if(any(ks>= N)) ks<-ks[ks<N]
    clusters<-lapply(ks,FUN=function(currk){
        cl<-do.call(clusterFunction@clusterFUN,c(list(k=currk),clusterArgs))
        if(clusterFunction@outputType=="list") cl<-.clusterListToVector(cl,N=N)
        return(cl)
    })
    if(is.null(diss)) diss<-clusterArgs[["inputMatrix"]]
    silClusters<-lapply(clusters,function(cl){
        cluster::silhouette(cl,
            dmatrix=diss
        )
    })
    if(length(ks)>1){
        whichBest<-which.max(sapply(silClusters, mean))
        finalCluster<-clusters[[whichBest]]
        sil<-silClusters[[whichBest]][,"sil_width"]
    }
    else{
        finalCluster<-clusters[[1]]
        sil<-silClusters[[1]][,"sil_width"]
    }
    if(removeSil){
        cl<-as.numeric(sil>silCutoff)
        cl[cl==0]<- -1
        cl[cl>0]<-finalCluster[cl>0]
        sil[cl == -1] <- -Inf #make the -1 cluster the last one in order
    }
    else{
        cl<-finalCluster
    }
    
    #make list of indices and put in order of silhouette width (of positive)
    clList<-tapply(seq_along(cl),cl,function(x){x},simplify=FALSE)
    if(orderBy=="best"){
        clAveWidth<-tapply(sil,cl,mean,na.rm=TRUE)
        clList[order(clAveWidth,decreasing=TRUE)]
    }
    #remove -1 group
    if(removeSil){
        whNotAssign<-which(sapply(clList,function(x){all(cl[x]== -1)}))
        if(length(whNotAssign)>1) stop("Coding error in removing unclustered samples")
        if(length(whNotAssign)>0) clList<-clList[-whNotAssign]
    }    
    return(clList)
    
}


