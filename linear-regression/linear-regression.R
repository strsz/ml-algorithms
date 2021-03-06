rm(list=ls())
library(ggplot2)
library(animation)
library(gganimate)
library(R6)

lineFunction <- function(x, w , b){
  return(b + x * w)
}

LinearRegression <- R6Class("LinearRegression",
  public = list(
    X = NULL,
    Y = NULL,
    weightSteps = NULL,
    
    train = function(X, Y, eta = 0.01, maxit = 5){
      X <- data.matrix(data.frame(b = 1,X))
      self$X = X
      self$Y = Y
      self$weightSteps <- matrix(0, ncol = dim(X)[2])
      w <- rep(0, dim(X)[2])
      
      for(i in seq(maxit)){
        w <- w + eta * (Y - w %*% t(X)) %*% X
        self$weightSteps <- rbind(self$weightSteps, w)
      }
      
      return(w)
    },
    
    plotSteps = function(){
      x1Min <- min(self$X[,2])
      x1Max <- max(self$X[,2])
      x2Min <- min(self$Y)
      x2Max <- max(self$Y)
      
      for(i in seq(dim(self$weightSteps)[1])){
        w <- self$weightSteps[i,]
        
        dfLine <- data.frame(x = c(x1Min, x1Max),
                             y = c(lineFunction(x1Min, w = w[2], b = w[1]), lineFunction(x1Max, w = w[2], b = w[1])))

        dfX = data.frame(self$X, self$Y)
        colnames(dfX) <- c("b", "x", "y")
        
        p <- ggplot(dfX, aes(x=x, y=y)) +
          geom_point(size = 2) + theme(legend.position="none") +
          geom_line(data = dfLine, mapping = aes(x = x, y = y), inherit.aes = FALSE) +
          coord_cartesian(ylim=c(x2Min, x2Max))
        
        print(p)
      }
    },
    
    plotAnimation = function(){
      x1Min <- min(self$X[,2])
      x1Max <- max(self$X[,2])
      x2Min <- min(self$Y)
      x2Max <- max(self$Y)
      
      w <- self$weightSteps
      rowNum <- dim(w)[1]
      
      dfLine <- data.frame(x = c(rep(x1Min, rowNum), rep(x1Max, rowNum)),
                           y = c(lineFunction(rep(x1Min, rowNum), w = w[,2], b = w[,1]), lineFunction(rep(x1Max, rowNum), w = w[,2], b = w[,1])),
                           time = seq(dim(w)[1]))
      
      dfX = data.frame(self$X, self$Y)
      colnames(dfX) <- c("b", "x", "y")
      
      p <- ggplot(dfX, aes(x=x, y=y)) +
        geom_point(size = 2) + theme(legend.position="none") +
        geom_line(data = dfLine, mapping = aes(x = x, y = y, frame = time), inherit.aes = FALSE) +
        coord_cartesian(ylim=c(x2Min, x2Max))
      
      gganimate(p)
    },
    
    plotTrajectorySteps = function(){
      bMin <- min(self$weightSteps[,1])
      bMax <- max(self$weightSteps[,1])
      xMin <- min(self$weightSteps[,2])
      xMax <- max(self$weightSteps[,2])
      bDiff <- bMax - bMin
      xDiff <- xMax - xMin
      
      rangeB = seq(bMin-bDiff*0.3, bMax+bDiff*0.3, by = bDiff / 200)
      rangeX = seq(xMin-xDiff*0.3, xMax+xDiff*0.3, by = xDiff / 200)
      contour <- expand.grid(b = rangeB, x = rangeX)
      contour$z <- apply(contour[,1:2], 1, self$predictCost)
      
      dfX = data.frame(self$X, self$Y)
      colnames(dfX) <- c("b", "x", "y")
      dfW <- data.frame(matrix(0,ncol = 5))[-1,]
      colnames(dfW) <- c("x", "y", "xend", "yend", "time")
      
      for(i in seq(dim(self$weightSteps)[1]-1)){
        w1 <- self$weightSteps[i,]
        w2 <- self$weightSteps[i+1,]
        
        dfW <- rbind(dfW,data.frame(b=w1[1], x=w1[2], bend=w2[1], xend=w2[2]))
        
        p <- ggplot(contour, aes(x = b, y = x, z = z)) +
          theme(legend.position="none") +
          geom_contour(binwidth = 0.15) + 
          geom_segment(data=dfW, mapping=aes(x=b, y=x, xend=bend, yend=xend), arrow=arrow(length = unit(0.2, "cm")), size=0.5, color="red", inherit.aes = FALSE)
        
        print(p)
      }
    },
    
    plotTrajectoryAnimation = function(){
      bMin <- min(self$weightSteps[,1])
      bMax <- max(self$weightSteps[,1])
      xMin <- min(self$weightSteps[,2])
      xMax <- max(self$weightSteps[,2])
      bDiff <- bMax - bMin
      xDiff <- xMax - xMin
      
      rangeB = seq(bMin-bDiff*0.1, bMax+bDiff*0.1, by = bDiff / 200)
      rangeX = seq(xMin-xDiff*0.1, xMax+xDiff*0.1, by = xDiff / 200)
      contour <- expand.grid(b = rangeB, x = rangeX)
      contour$z <- apply(contour[,1:2], 1, self$predictCost)
      
      dfX = data.frame(self$X, self$Y)
      colnames(dfX) <- c("b", "x", "y")
      dfW <- data.frame(matrix(0,ncol = 5))[-1,]
      colnames(dfW) <- c("x", "y", "xend", "yend", "time")
      
      w1 <- self$weightSteps[1,]
      w2 <- self$weightSteps[2,]
      dfW <- rbind(dfW,data.frame(b=w1[1], x=w1[2], bend=w2[1], xend=w2[2], time=1))
      
      for(i in seq(2, dim(self$weightSteps)[1]-1)){
        w1 <- self$weightSteps[i,]
        w2 <- self$weightSteps[i+1,]
        
        dfW <- rbind(rbind(dfW,data.frame(dfW[,1:4], time=i)), data.frame(b=w1[1], x=w1[2], bend=w2[1], xend=w2[2], time=i))
      }
      
      p <- ggplot(contour, aes(x = b, y = x, z = z)) +
        theme(legend.position="none") +
        geom_contour(binwidth = 0.15) + 
        geom_segment(data=dfW, mapping=aes(x=b, y=x, xend=bend, yend=xend, frame = time), arrow=arrow(length = unit(0.2, "cm")), size=0.5, color="red", inherit.aes = FALSE)
      
      gganimate(p)
      
    },
    
    predictCost = function(w){
      return(0.5*sum((w %*% t(self$X) - self$Y)^2))
    }
  )
)

set.seed(0)

# generate data with r = 0.8 correlation
N <- 30
X <- data.frame(matrix(rnorm(N, mean=0, sd=1), N, 1))
r <- 0.5
X[,2] <- r*X[,1] + rnorm(length(X[,1]), mean=0, sd=sqrt(1 - r^2))
cor(X[,1], X[,2])
colnames(X) <- c('x', 'y')
ggplot(X, aes(x = x, y = y)) + geom_point()

linReg <- LinearRegression$new()
weight <- linReg$train(X[,1], X[,2], eta = 0.01, maxit = 15)
print(weight)

# linReg$plotSteps()
linReg$plotTrajectorySteps()
