############################################
## Methods for the Results from cfboost() ##
############################################

## methods: subset for cfboost objects
## (adapted from mboost)
"[.cfboost" <- function(object, i, ...) {
    mstop <- mstop(object, opt=FALSE)
    if (i == mstop) return(object)
    if (length(i) != 1)
        stop("not a positive integer")
    if (i < 1 || i > mstop)
        warning("invalid number of boosting iterations")
    indx <- 1:min(max(i, 1), mstop)
    object$ensemble <- ens <- object$ensemble[indx] # , , drop = FALSE]
    object$ensembless <- ensembless <- object$ensembless[indx]
    object$fit <- object$predict(mstop = max(indx))
    dummy <- class(object$risk)
    object$risk <- object$risk[indx]
    class(object$risk) <- dummy
    object$df <- object$df[indx,]

    tmp <- object$data$input
    class(tmp) <- "list"
    foo <- function(object){
        attr(object, "coefs")
    }
    object$coefs <- lapply(tmp, foo)
    nu <- object$control$nu
    for (i in indx){
        object$coefs[[ens[i]]] <- object$coefs[[ens[i]]] + nu * ensembless[[i]]
    }
    object
}

## methods: print for cfboost objects
print.cfboost <- function(x, ...) {
    cat("\n")
    cat("\t CoxFlexBoost: \n")
    cat("\t Additive Survival Models with Time-Varying Effects\n")
    cat("\t Fitted via Likelihood-Based Boosting\n")
    cat("\n")
    if (!is.null(x$call))
    cat("Call:\n")
    print(x$call)
    cat("\nNumber of boosting iterations: mstop =", mstop(x, opt = FALSE), "\n")
    cat("Step size: ", x$control$nu, "\n")
    cat("Offset: ", x$offset, "\n\n")
    if (!is.null(x$weights)){
        cat("Size of learning sample:", sum(x$weights),"\n")
        if (x$control$risk == "oobag"){
            cat("\tof test sample:", sum(1 - x$weights), "\n\n")
            cat("minimum risk:", min(x$risk), "\n")
            cat("\tin iteration ", mstop(x), "\n\n")
        }
    }
    invisible(x)
}

## methods: plot for cfboost objects
plot.cfboost <- function(x, which = NULL, ask = TRUE && dev.interactive(),
                          type = "b", ylab = expression(f[partial]), add_rug = TRUE, ...){
    tmp <- x$data$input
    class(tmp) <- "list"

    if (is.null(which))
        which <- (1:length(tmp))[tabulate(x$ensemble,nbins = length(tmp)) > 0]
    if (ask) {
        op <- par(ask = TRUE)
        on.exit(par(op))
    }
    for (i in which){
        x <- get("x", environment(attr(tmp[[i]],"predict")))
        xname <- get("xname", environment(attr(tmp[[i]],"predict")))
        zname <- get("zname", environment(attr(tmp[[i]],"predict")))
        if (!is.null(zname) & zname != "NULL")
            xname <- paste(xname, " (as interaction with ", zname, ")", sep="")
        xorder <- order(x)
        plot(x[xorder], attr(tmp[[i]], "predict")(x$coefs[[i]])[xorder], type = type, ylab = ylab, xlab = xname)
        abline(h = 0, lty = 3)
        if (add_rug) rug(x)
    }
}

## methods: extract coefficients from cfboost objects
coef.cfboost <- function(object, ...){
    RET <- object$coefs
    RET$offset <- object$offset
    return(RET)
}

## methods: prediction
predict.cfboost <- function(object, newdata = NULL, type = c("hazard", "log-hazard"), trace = TRUE, ...) {
    type <- match.arg(type)
    if (type == "hazard"){
        hazard <- exp(object$predict(newdata = newdata, mstop = mstop(object, opt=FALSE), ...))
        return(hazard)
    }

    if (type == "log-hazard"){
        loghazard <- object$predict(newdata = newdata, mstop = mstop(object, opt=FALSE), ...)
        return(loghazard)
    }
}

## methods: fitted
fitted.cfboost <- function(object, type = c("hazard", "log-hazard"), ...) {
    type <- match.arg(type)
    if (type == "hazard"){
        hazard <- exp(object$fit)
        return(hazard)
    }
    if (type == "log-hazard"){
        return(object$fit)
    }
}

## methods: summary for cfboost objects
summary.cfboost <- function(object, ...){
    cat("\t", sQuote("summary.cfboost"), "is a.t.m. a wrapper to", sQuote("print.cfboost"), "\n")
    print(object)
    print(freq.sel(object))
}


## function to extract selection frequencies of base-learners
freq.sel <- function(object){
    x <- object$data$input
    class(x) <- "list"

    classes <-  xnames <- znames <- vector(mode = "character", length = length(x))
    timesSel <- rep(0, length(x))
    for (i in 1:length(x)){
        classes[i] <- class(x[[i]])[2]
        xnames[i] <- get("xname", environment(attr(x[[i]], "predict")))
        znames[i] <- get("zname", environment(attr(x[[i]], "predict")))
        timesSel[i] <- sum(object$ensemble == i)
    }
    RET <- data.frame(classes, xnames, znames, timesSel)

    class(RET) <- c("fs")
    return(RET)
}

## print frequency of selection
print.fs <- function(x, ...){
    class(x) <- "data.frame"
    x <- x[order(x[,4], decreasing = TRUE),]
    cat("Number of selections in", sum(x[,4]), "iterations:\n")
    x <- as.matrix(x)
    for (i in 1:nrow(x)){
        if (x[i,3] != "NULL")
            cat("\t", x[i,1], "(", x[i,2], ",", x[i,3],"):\t", x[i,4] ,"\n", sep="")
        else
            cat("\t", x[i,1], "(", x[i,2],"):\t", x[i,4] ,"\n", sep="")
    }
    invisible(x)
}