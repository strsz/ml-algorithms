rm(list=ls())
library(ggplot2)
library(animation)
library(gganimate)
library(R6)

NNRegressor <- R6Class("NNRegressor",
  public = list(
    X = NULL,
    y = NULL,
    eta = NULL,
    layers = NULL,
    w = NULL,
    wSteps = NULL,
    errorSteps = NULL,
    epoch = NULL,
    
    train = function(X, y, layers, epoch = 10, eta = 0.5){
      xB <- cbind(rep(1, dim(X)[1]), X)
      layers <- c(dim(X)[2], layers, dim(y)[2])
      w <- private$initializeWeights(layers)
      self$eta <- eta
      self$X <- xB
      self$y <- y
      self$layers <- layers
      self$wSteps = list()
      self$errorSteps <- c()
      self$epoch <- epoch
      
      wTemp <- list()
      
      for(i in 1:epoch){ # iterate over epochs
        set.seed(i)
        
        for(k in sample(dim(xB)[1])){ # iterate over points randomly
          # feedforward
          
          layerSum <- list()
          layerOutput <- list()
          layerOutput[[1]] <- xB[k,]
          
          for(j in seq(length(layers) - 2)){ # only for hidden layers
            layerHSum <- t(t(layerOutput[[j]]) %*% w[[j]])
            layerSum[[j]] <- layerHSum
            layerHOutput <- private$transferF(layerHSum)
            layerOutput[[j + 1]] <- matrix(c(1,layerHOutput)) 
          }
          
          # output layer
          lastLayerOutput <- layerOutput[[length(layerOutput)]] # (n-1)st layer
          layerOSum <- t(t(lastLayerOutput) %*% w[[length(w)]]) # output layer sum
          # layerOOutput <- private$transferF(layerOSum) # output of the output layer
          layerOOutput <- layerOSum # linear output for regression
          # end output layer
          
          # calculate error
          layerOOutputError <- y[k,] - layerOOutput
          layerOOutputErrorTotal <- 0.5*sum(layerOOutputError^2) # SSE
          # cat("Individual error: ",layerOOutputError, "  SSE: ", layerOOutputErrorTotal, "\n")
          # end calculate error
          # end feedforward
          
          # backpropagation
          # output layer
          lastLayerOutputWoB <- matrix(lastLayerOutput[-1]) # output of the (n-1)st layer without bias
          # deltaOutput <- (-layerOOutputError) * private$transferFDer(layerOSum) # local gradient of the output layer
          deltaOutput <- (-layerOOutputError) 
          gradWOutput <- deltaOutput %*% t(lastLayerOutputWoB)
          gradWOutput <- rbind(t(deltaOutput), t(gradWOutput))
          
          wTemp[[length(w)]] <- w[[length(w)]] - eta*gradWOutput
          # end output layer
          
          # hidden layer
          for(j in (length(layers)-2):1){
            deltaH <- private$transferFDer(layerSum[[j]]) * t(t(deltaOutput) %*% t(w[[j + 1]][-1,]))
            gradWH <- deltaH %*% t(matrix(layerOutput[[j]][-1]))
            gradWH <- rbind(t(deltaH), t(gradWH))
            wTemp[[j]] <- w[[j]] - eta*gradWH
            deltaOutput <- deltaH
          }
          # hl end
          # end backpropagation
          
          w <- wTemp
        }
        
        self$wSteps[[i]] <- w
        
        pred <- private$predictWithSteps(matrix(self$X[,-1]), w)
        self$errorSteps <- c(self$errorSteps, 0.5*sum(self$y - pred)^2)
      }
      
      self$w <- w
      
      return(w)
    },
    
    predict = function(X){
      return(private$predictWithSteps(X, self$w))
    },
    
    plotSteps = function(step){ # the function plot every stepth epoch
      xMin <- min(self$X)
      xMax <- max(self$X)
      dfPred <- data.frame(x = seq(xMin, xMax, (xMax - xMin) / 100))
      
      for(i in seq(1, length(self$wSteps), step)){
        pred <- private$predictStep(matrix(dfPred$x), i)
        dfPred$y <- pred[[1]]
        mse <- pred[[2]]
        dfX <- data.frame(x = self$X[,2], y = self$y)
        
        p <- ggplot(dfPred, aes(x = x, y = y)) +
          geom_line() + 
          geom_point(data = dfX, aes(x = x, y = y)) + 
          ggtitle(paste("epoch = ", i, ", MSE = ", formatC(mse, digits = 2, format = "f"), sep = ""))
        
        print(p)
      }
    },
    
    plotError = function(){
      errDf <- data.frame(sse = nn$errorSteps, epoch = 1:self$epoch)
      print(ggplot(errDf, aes(x = epoch, y = sse)) + geom_line())
    }
  ),
  
  private = list(
    initializeWeights = function(layers){
      w <- list()
      
      for(i in seq(length(layers) - 1)){
        wNo <- (layers[i] + 1) * layers[i + 1] # number of weights between the i-th and i+1-th layer
        nNo <- (layers[i] + 1) + layers[i + 1] # number of neurons in the i-th and i+1-th layer
        wTemp <- matrix(runif(wNo, min = -sqrt(6/nNo), max = sqrt(6/nNo)), ncol = layers[i + 1]) # Glorot initialization of weights
        w[[i]] <- wTemp
      }
      
      return(w)
    },
    
    predictStep = function(X, step){
      X <- cbind(rep(1, dim(X)[1]), X)
      hiddenLayerNo <- length(self$layers) - 2
      w <- self$wSteps[[step]]
      
      for(i in 1:hiddenLayerNo){
        X <- cbind(1, private$transferF(X %*% w[[i]]))
      }
      
      y = X %*% w[[hiddenLayerNo + 1]]
      pred <- private$predictWithSteps(matrix(self$X[,-1]), w)
      mse = 0.5*sum((self$y - pred)^2)
      
      return(list(y, mse))
    },
    
    predictWithSteps = function(X, w){
      xB <- cbind(rep(1, dim(X)[1]), X)
      hiddenLayerNo <- length(self$layers) - 2
      for(i in 1:hiddenLayerNo){
        xB <- cbind(1, private$transferF(xB %*% w[[i]]))
      }
      
      return(xB %*% w[[hiddenLayerNo + 1]])
    },
    
    transferF = function(x){
      return(1/(1+exp(-x)))
    },
    
    transferFDer = function(x){
      return(private$transferF(x)*(1-private$transferF(x)))
    }
  )
)

set.seed(0)

N <- 200
X <- matrix(rnorm(N, mean=0, sd=1), ncol = 1)
xB <- cbind(rep(1, N), X)
beta <- 3 + 0.4*rnorm(N)
y <- matrix(1 + X * beta + .75*rnorm(N), ncol = 1)
layers <- c(10)

nn <- NNRegressor$new()
weights <- nn$train(X, y, layers, epoch = 101, eta = 0.001)
# print(weights)

pred <- nn$predict(X)
print(0.5*sum((y-pred)^2))

nn$plotSteps(20)
nn$plotError()
